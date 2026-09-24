"""SSRF-korumali giden HTTP (C1b entegrasyon tetikleyicisi).

Kullanici-tanimli URL'ler ic ag / bulut metadata ucuna ULASAMAZ. Kapi:
  1. Yalniz http/https semasi (digerleri reddedilir).
  2. Host cozulur (DNS) ve DONEN HER IP kontrol edilir — hostname string'ine
     GUVENILMEZ (DNS-rebinding: hostname public gorunup private'a cozulebilir;
     biz cozup IP'yi denetleriz). Ozel/loopback/link-local (169.254 metadata
     dahil)/reserved/multicast/ULA/unspecified IP -> REDDEDILIR.
  3. Redirect TAKIP EDILMEZ (redirect-tabanli SSRF yok).
  4. Timeout + yanit boyutu siniri.

Gizlilik/guvenlik notu: bu, kullanici-URL'li giden isteklerin cekirdek riskidir;
kapi non-negotiable. Baglanti-anindaki TOCTOU icin cozulen IP'ye pinleme ileri
sertlestirme olarak belgelenmistir (bkz. NOT); mevcut kapi cozup-denetler.
"""
from __future__ import annotations

import ipaddress
import socket
import threading
from collections.abc import Iterator, Sequence
from contextlib import contextmanager
from dataclasses import dataclass
from urllib.parse import urlparse

import httpx

# Varsayilan sinirlar (tetik ucu override edebilir).
DEFAULT_TIMEOUT = 8.0
DEFAULT_MAX_BYTES = 64 * 1024

_BLOCK_MSG = "Hedef adres engellendi (ozel/ic ag veya cozulemedi)."


class SSRFBlocked(Exception):
    """URL ic/ozel bir hedefe isaret ediyor (veya sema/cozum gecersiz)."""


def _ip_is_blocked(ip: ipaddress.IPv4Address | ipaddress.IPv6Address) -> bool:
    # is_private: 10/8, 172.16/12, 192.168/16, fc00::/7 (ULA), vb.
    # is_link_local: 169.254/16 (bulut metadata 169.254.169.254 dahil), fe80::/10.
    return (
        ip.is_private
        or ip.is_loopback
        or ip.is_link_local
        or ip.is_reserved
        or ip.is_multicast
        or ip.is_unspecified
    )


def _resolved_ips(host: str, port: int) -> list[str]:
    """IP literal ise dogrudan; degilse getaddrinfo ile TUM A/AAAA kayitlari."""
    try:
        return [str(ipaddress.ip_address(host))]
    except ValueError:
        pass
    try:
        infos = socket.getaddrinfo(host, port, proto=socket.IPPROTO_TCP)
    except socket.gaierror as exc:
        raise SSRFBlocked(_BLOCK_MSG) from exc
    ips = list({info[4][0] for info in infos})
    if not ips:
        raise SSRFBlocked(_BLOCK_MSG)
    return ips


def validate_public_url(url: str) -> list[str]:
    """URL public bir http(s) ucu mu? Degilse SSRFBlocked. Cozulen IP'leri doner.

    DNS-rebinding: hostname'e degil, COZULEN IP'lere bakar — public gorunup
    private'a cozulen adresler de reddedilir.
    """
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https"):
        raise SSRFBlocked("Yalnizca http/https desteklenir.")
    host = parsed.hostname
    if not host:
        raise SSRFBlocked("Gecersiz URL (host yok).")
    port = parsed.port or (443 if parsed.scheme == "https" else 80)
    ips = _resolved_ips(host, port)
    for ipstr in ips:
        if _ip_is_blocked(ipaddress.ip_address(ipstr)):
            raise SSRFBlocked(_BLOCK_MSG)
    return ips


# DNS-pinleme process-global getaddrinfo'yu gecici degistirdiginden, giden
# webhook gonderimleri seri yapilir (dusuk-hacimli tetik yolu; korektlik >
# eszamanlilik). Pin YALNIZ hedef host icin devrededir; diger cozumler gercek
# resolver'a duser.
_send_lock = threading.Lock()


@contextmanager
def _pin_host_to_ips(host: str, ips: Sequence[str]) -> Iterator[None]:
    """[host] icin DNS cozumunu YALNIZ dogrulanmis [ips]'e sabitle (TOCTOU/
    DNS-rebinding kapatma). URL host'u DEGISMEZ -> TLS SNI + sertifika dogrulama
    orijinal hostname'e gore calisir; yalniz TCP baglantisi dogrulanmis IP'ye
    gider. Rebind ile private'a donen ikinci cozum DEVREYE GIRMEZ (yeniden
    cozmeyiz — dogrulanmis IP'leri dondururuz)."""
    real = socket.getaddrinfo

    def _patched(h, port, family=0, type=0, proto=0, flags=0):  # noqa: A002
        if h != host:
            return real(h, port, family, type, proto, flags)
        out = []
        for ip in ips:
            is6 = ":" in ip
            fam = socket.AF_INET6 if is6 else socket.AF_INET
            sockaddr = (ip, port, 0, 0) if is6 else (ip, port)
            out.append((fam, socket.SOCK_STREAM, socket.IPPROTO_TCP, "", sockaddr))
        return out

    with _send_lock:
        socket.getaddrinfo = _patched
        try:
            yield
        finally:
            socket.getaddrinfo = real


@dataclass(frozen=True)
class WebhookResult:
    ok: bool
    status: int | None
    error: str | None = None


def send_webhook(
    method: str,
    url: str,
    *,
    headers: dict[str, str] | None = None,
    content: bytes | None = None,
    timeout: float = DEFAULT_TIMEOUT,
    max_bytes: int = DEFAULT_MAX_BYTES,
) -> WebhookResult:
    """SSRF kapisindan gecir, sonra istegi gonder. 2xx -> ok=True. Ag/HTTP
    hatasi -> ok=False + error (kisa). SSRFBlocked cagirana firlatilir (tetik
    ucu bunu {ok:false, error} olarak dondurur — numara/ic-hata sizmaz).

    DNS-rebinding/TOCTOU: cozulen IP'ler baglantida PINLENIR (bkz.
    _pin_host_to_ips) — dogrula-sonra-baglan araligindaki rebind kapatilir.
    Redirect TAKIP EDILMEZ; yanit `max_bytes`e kadar okunur.
    """
    ips = validate_public_url(url)  # raises SSRFBlocked
    host = urlparse(url).hostname or ""
    try:
        with _pin_host_to_ips(host, ips):
            with httpx.Client(timeout=timeout, follow_redirects=False) as client:
                with client.stream(
                    method.upper(),
                    url,
                    headers=headers or {},
                    content=content,
                ) as resp:
                    read = 0
                    for chunk in resp.iter_bytes():
                        read += len(chunk)
                        if read >= max_bytes:
                            break
                    status = resp.status_code
        return WebhookResult(ok=200 <= status < 300, status=status)
    except httpx.HTTPError as exc:
        return WebhookResult(ok=False, status=None, error=str(exc)[:200])


# =========================================================================== #
# (E2E 2026-09) SAHA CIHAZI HEDEF KAPISI — diyafon + akilli ev koprusu
# =========================================================================== #
# OLCULEN KUSUR (TESIS-11): diyafon/kopru "baglanti testi" SSRF kapisindan
# hic gecmiyordu (P240: "ic ag serbest — cihaz zaten ic agda"). Bir tesis
# yoneticisi `host=redis port=6379`, `db:5432`, `minio:9000`, `api:8000`
# yazip `ok:true`, `localhost:1` yazip "ulasilamiyor" aliyordu: cok
# kiracili platformda MUSTERI rolunun elinde bir PORT TARAYICISI. P240
# karari yalniz yanit GOVDESINI dusunmustu; `ok` bayragi tek basina
# yeterli bir kahin (oracle).
#
# NEDEN `validate_public_url` DEGIL: diyafon paneli ve HA kutusu gercekten
# SITENIN YEREL AGINDA yasar (192.168.x.x, 10.x — VPN/site baglantisi
# arkasinda). RFC1918'in tamamini kapatmak ozelligi oldururdu (P213 K3.2
# kameralarda ayni gerekceyle ayni karari verdi).
#
# BU KAPI NEYI KESIN KAPATIR:
#   1. TEK ETIKETLI ADLAR (`redis`, `db`, `api`, `minio`, `localhost`) —
#      konteyner agindaki servis adlari tam olarak budur ve saha cihazi
#      hicbir zaman noktasiz bir adla tanimlanmaz. COZULMEDEN reddedilir:
#      cozup bakmak "boyle bir servis var mi" sorusunu yanitlardi.
#   2. `*.localhost`, `*.internal` (host.docker.internal, bulut meta-veri).
#   3. Cozulen adreslerden: loopback, link-local (169.254 — bulut
#      meta-veri), belirtilmemis, cok-noktaya yayin, bilinen meta-veri IP'leri.
#   4. SUNUCUNUN KENDI BAGLI AGLARI (`/proc/net/route`): konteynerin
#      bulundugu docker agi (db/redis/minio'nun IP'leri) burada. Dogrudan
#      bagli aglar route tablosundan okunur — ag adresini ELLE yazmak
#      compose alt agi degistiginde sessizce eskirdi.
#
# ACIK KALAN (bilincli): sunucunun disindaki RFC1918 adresleri. Prod
# sunucusunun kendi LAN IP'si konteyner icinden gorunmez; o adresin
# yayinlanmis portlari hala yoklanabilir. Kalici cozum yoklamayi sitedeki
# kopru ajanina tasimaktir (docs'a not).
#
# YANIT AYIRT EDILEMEZ: engellenen hedef, kapali bir portla AYNI kimligi
# dondurur (`*_ulasilamiyor`) ve ayrinti tekduzedir; "engellendi" ile
# "kapali" farki da bir bilgi olurdu.
_SAHA_YASAK_AGLAR = tuple(
    ipaddress.ip_network(a)
    for a in (
        "0.0.0.0/8",
        "127.0.0.0/8",
        "169.254.0.0/16",
        "224.0.0.0/4",
        "255.255.255.255/32",
        "100.100.100.200/32",  # Alibaba meta-veri
        "192.0.0.192/32",      # Oracle meta-veri
        "::/128",
        "::1/128",
        "fe80::/10",
        "ff00::/8",
        "fd00:ec2::254/128",   # AWS IMDS IPv6
    )
)
_LOOPBACK_AGLAR = (
    ipaddress.ip_network("127.0.0.0/8"),
    ipaddress.ip_network("::1/128"),
)

#: Tekduze ayrinti — kaydedilen `son_hata_ayrinti` de ayni.
SAHA_ENGEL_AYRINTI = "hedef ulasilamiyor"


def _loopback_serbest() -> bool:
    """YALNIZ GELISTIRME/TEST: dev compose `SAHA_LOOPBACK_SERBEST=1` verir.

    Test takimi sahte SIP/HA sunucusunu pytest surecinde 127.0.0.1'de
    acar ve CANLI API'ye (ayni konteyner) oraya baglanmasini soyler;
    loopback'i kapatmak o testleri olcum yapamaz hale getirirdi. Prod
    compose bu degiskeni TANIMLAMAZ -> kapali. Tek etiketli adlar ve
    konteyner agi bayraktan BAGIMSIZ olarak kapalidir (E2E olcumundeki
    `localhost:8000`, `redis:6379` dev'de de reddedilir).
    """
    import os

    return os.environ.get("SAHA_LOOPBACK_SERBEST", "").strip() in ("1", "true")


def _bagli_aglar() -> list[ipaddress.IPv4Network]:
    """Sunucunun DOGRUDAN BAGLI IPv4 aglari (`/proc/net/route`, gateway=0).

    Varsayilan rota (0.0.0.0/0) atlanir — o "her yer" demek. Okunamazsa
    (Linux degil) bos liste: kapinin geri kalani yine calisir.
    """
    aglar: list[ipaddress.IPv4Network] = []
    try:
        with open("/proc/net/route", encoding="ascii") as f:
            next(f, None)
            for satir in f:
                p = satir.split()
                if len(p) < 8:
                    continue
                hedef, gecit, maske = p[1], p[2], p[7]
                if gecit != "00000000" or hedef == "00000000":
                    continue
                ag = ipaddress.IPv4Address(bytes.fromhex(hedef)[::-1])
                m = ipaddress.IPv4Address(bytes.fromhex(maske)[::-1])
                try:
                    aglar.append(ipaddress.IPv4Network(f"{ag}/{m}", strict=False))
                except ValueError:
                    continue
    except (OSError, ValueError):
        return []
    return aglar


def saha_hedefi_engelli(host: str | None) -> bool:
    """Diyafon/kopru hedefi platformun KENDI agina mi isaret ediyor?"""
    ad = (host or "").strip().rstrip(".").lower()
    if ad.startswith("[") and ad.endswith("]"):
        ad = ad[1:-1]
    if not ad:
        return True
    ip_literal: ipaddress.IPv4Address | ipaddress.IPv6Address | None
    try:
        ip_literal = ipaddress.ip_address(ad.split("%")[0])
    except ValueError:
        ip_literal = None
    if ip_literal is None:
        if "." not in ad:
            return True  # servis adi / localhost — COZULMEDEN
        if ad.endswith((".localhost", ".internal")):
            return True
        # Sayisal kodlamalar (`2852039166`, `0177.0.0.1`) getaddrinfo'da
        # IP'ye cevrilir; asagidaki adres denetimi onlari da yakalar.
        try:
            adresler = [
                b[4][0] for b in socket.getaddrinfo(ad, None, proto=socket.IPPROTO_TCP)
            ]
        except OSError:
            # Cozulemeyen ad: baglanti zaten kurulamaz; "engelli" demek
            # yazim hatasini guvenlik sorunu gibi gosterirdi.
            return False
    else:
        adresler = [str(ip_literal)]
    bagli = _bagli_aglar()
    serbest_loop = _loopback_serbest()
    for ham in adresler:
        try:
            ip = ipaddress.ip_address(ham.split("%")[0])
        except ValueError:
            return True
        if getattr(ip, "ipv4_mapped", None):
            ip = ip.ipv4_mapped
        if serbest_loop and any(ip in a for a in _LOOPBACK_AGLAR):
            continue
        if any(ip in a for a in _SAHA_YASAK_AGLAR):
            return True
        if ip.version == 4 and any(ip in a for a in bagli):
            return True
    return False
