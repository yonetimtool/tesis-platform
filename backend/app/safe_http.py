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
