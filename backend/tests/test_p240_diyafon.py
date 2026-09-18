"""(P240 §2) DIYAFON — uc yontem, tek soyutlama.

===========================================================================
NE OLCULUYOR — ve ne OLCULMUYOR
===========================================================================
GERCEK DIYAFON CIHAZI YOK. Bu dosya PROTOKOL DUZEYINDE olcer: testin
kendi icinde bir TAKLIT SIP SUNUCUSU (UDP) ve bir TAKLIT ROLE MODULU
(HTTP) acilir; sunucumuz onlara gercek paket gonderir ve yanit isler.

Yani kanit sudur: "SIP OPTIONS/MESSAGE'i RFC'ye uygun kurdum ve dogru
yorumladim". "Bu marka panelde calisiyor" iddiasi YAPILMIYOR — hangi
cihazlarda denenmesi gerektigi docs'ta yazili.
"""
from __future__ import annotations

import socket
import threading
import uuid

from app.diyafon import saglayici, yetenekler
from app.diyafon.kuru_kontak import KuruKontakDiyafon
from app.diyafon.sip import SipDiyafon


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


# ====================== TAKLIT SIP SUNUCUSU (UDP) ========================= #
class SahteSip:
    """Tek pakete tek yanit veren minik SIP sunucusu.

    `yanit_kodu` ile 200 / 405 / 403 gibi durumlar denenir; `alinan`
    listesinde sunucumuzun GONDERDIGI ham paket durur — yani protokolu
    dogru kurdugumuzu iddia degil OLCUM ile soyluyoruz.
    """

    def __init__(self, yanit_kodu: int | None = 200) -> None:
        self.yanit_kodu = yanit_kodu
        self.alinan: list[bytes] = []
        self.sok = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sok.bind(("127.0.0.1", 0))
        self.sok.settimeout(5)
        self.port = self.sok.getsockname()[1]
        self._calis = True
        self.is_parcacigi = threading.Thread(target=self._dongu, daemon=True)
        self.is_parcacigi.start()

    def _dongu(self) -> None:
        while self._calis:
            try:
                veri, adres = self.sok.recvfrom(8192)
            except (socket.timeout, OSError):
                return
            self.alinan.append(veri)
            if self.yanit_kodu is None:
                continue  # SESSIZ: zaman asimi olculur
            ilk = veri.split(b"\r\n", 1)[0].decode("utf-8", "replace")
            cseq = "1 OPTIONS"
            for satir in veri.decode("utf-8", "replace").split("\r\n"):
                if satir.lower().startswith("cseq:"):
                    cseq = satir.split(":", 1)[1].strip()
            metin = (
                f"SIP/2.0 {self.yanit_kodu} Test\r\n"
                f"Via: SIP/2.0/UDP 127.0.0.1:5060\r\n"
                f"CSeq: {cseq}\r\n"
                f"Content-Length: 0\r\n\r\n"
            )
            try:
                self.sok.sendto(metin.encode("utf-8"), adres)
            except OSError:
                return
        _ = ilk  # okunurluk; yanit icerigi testte kullanilmiyor

    def kapat(self) -> None:
        self._calis = False
        self.sok.close()


# ==================== TAKLIT ROLE MODULU (HTTP) =========================== #
class SahteRole:
    """`GET /rele1` gibi cagrilari kaydeden minik HTTP sunucusu."""

    def __init__(self, kod: int = 200) -> None:
        self.kod = kod
        self.yollar: list[str] = []
        self.sok = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sok.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sok.bind(("127.0.0.1", 0))
        self.sok.listen(8)
        self.sok.settimeout(5)
        self.port = self.sok.getsockname()[1]
        self._calis = True
        threading.Thread(target=self._dongu, daemon=True).start()

    def _dongu(self) -> None:
        while self._calis:
            try:
                baglanti, _ = self.sok.accept()
            except (socket.timeout, OSError):
                return
            try:
                veri = baglanti.recv(2048).decode("utf-8", "replace")
                ilk = veri.split("\r\n", 1)[0]
                parcalar = ilk.split(" ")
                if len(parcalar) >= 2:
                    self.yollar.append(parcalar[1])
                baglanti.sendall(
                    f"HTTP/1.1 {self.kod} Test\r\nContent-Length: 0\r\n\r\n".encode()
                )
            except OSError:
                pass
            finally:
                baglanti.close()

    def kapat(self) -> None:
        self._calis = False
        self.sok.close()


# ========================== YETENEK MATRISI =============================== #
def test_YETENEKLER_yonteme_gore_SABIT():
    # Kuru kontak SES/METIN TASIYAMAZ — bu bir veri degil, yontemin
    # YAPISAL siniri. Tabloya yazilsaydi yanlis isaretlendiginde sunucu
    # olmayan bir yetenegi denerdi.
    assert yetenekler("kuru_kontak").metin_anons is False
    assert yetenekler("kuru_kontak").kapi_ac is True
    assert yetenekler("sip").metin_anons is True
    assert yetenekler("sip").kapi_ac is False
    assert yetenekler("sip_kopru").metin_anons is True
    # SESLI ANONS HICBIR YONTEMDE YOK — medya yigini bu turda yazilmadi
    # ve "yazdim ama denemedim" demektense ACIKCA false donuyor.
    for y in ("sip", "sip_kopru", "kuru_kontak"):
        assert yetenekler(y).sesli_anons is False


# ============================ SIP PROTOKOLU =============================== #
def test_SIP_OPTIONS_saglik_ve_PROTOKOL_BICIMI():
    sunucu = SahteSip(200)
    try:
        d = SipDiyafon(host="127.0.0.1", port=sunucu.port, hedef="100")
        sonuc = d.saglik()
        assert sonuc.ok is True
    finally:
        sunucu.kapat()

    # GONDERILEN PAKET RFC 3261 bicimini tasimali: istek satiri, Via,
    # Call-ID, CSeq, Content-Length. Eksik bir baslik, gercek bir
    # cihazda "400 Bad Request" demekti ve bunu ancak sahada gorurduk.
    ham = sunucu.alinan[0].decode()
    assert ham.startswith("OPTIONS sip:")
    for baslik in ("Via:", "From:", "To:", "Call-ID:", "CSeq:", "Content-Length:"):
        assert baslik in ham, baslik
    assert "SIP/2.0/UDP" in ham


def test_SIP_405_de_AYAKTA_sayilir():
    # "Method Not Allowed" diyen bir cihaz YANIT VERIYOR demektir; bunu
    # "kopuk" saymak calisan bir kurulumu kirmizi gostermek olurdu.
    sunucu = SahteSip(405)
    try:
        d = SipDiyafon(host="127.0.0.1", port=sunucu.port, hedef="100")
        assert d.saglik().ok is True
    finally:
        sunucu.kapat()


def test_SIP_YANIT_YOKSA_ULASILAMIYOR():
    sunucu = SahteSip(None)  # sessiz
    try:
        d = SipDiyafon(host="127.0.0.1", port=sunucu.port, hedef="100")
        sonuc = d.saglik()
        assert sonuc.ok is False
        assert sonuc.kod == "diyafon_ulasilamiyor"
    finally:
        sunucu.kapat()


def test_SIP_MESSAGE_metin_GOVDEDE_gider():
    sunucu = SahteSip(200)
    try:
        d = SipDiyafon(host="127.0.0.1", port=sunucu.port, hedef="100")
        assert d.metin_anons("TAHLIYE").ok is True
    finally:
        sunucu.kapat()
    ham = sunucu.alinan[0].decode()
    assert ham.startswith("MESSAGE sip:100@")
    assert "Content-Type: text/plain" in ham
    # Govde GERCEKTEN gitti ve uzunluk DOGRU yazildi.
    assert ham.endswith("TAHLIYE")
    assert "Content-Length: 7" in ham


def test_SIP_4xx_MESSAGE_REDDEDILDI_sayilir():
    # OPTIONS'ta 405 "ayakta" demek; MESSAGE'ta 4xx "mesaj GITMEDI"
    # demektir. Ayni kodu iki yerde ayni saymak, gitmeyen bir anonsu
    # basarili gostermek olurdu.
    sunucu = SahteSip(403)
    try:
        d = SipDiyafon(host="127.0.0.1", port=sunucu.port, hedef="100")
        sonuc = d.metin_anons("x")
        assert sonuc.ok is False
        assert sonuc.kod == "diyafon_reddedildi"
    finally:
        sunucu.kapat()


def test_SIP_kapi_ac_YAPILANDIRILMAMIS_dondurur():
    d = SipDiyafon(host="127.0.0.1", port=1, hedef="100")
    assert d.kapi_ac().ok is False


# =========================== KURU KONTAK ================================== #
def test_KURU_KONTAK_zil_ve_kapi_AYRI_yollar():
    role = SahteRole(200)
    try:
        d = KuruKontakDiyafon(
            host="127.0.0.1", port=role.port, kullanici=None, sifre=None,
            zil_yolu="/rele1", kapi_yolu="/rele2",
        )
        assert d.zil_cal().ok is True
        assert d.kapi_ac().ok is True
    finally:
        role.kapat()
    # Tek yol olsaydi "zil cal" ile "kapi ac" AYIRT EDILEMEZDI.
    assert role.yollar == ["/rele1", "/rele2"]


def test_KURU_KONTAK_SAGLIK_ROLE_TETIKLEMEZ():
    # P240 §4'un kurali: izleme, izledigi seyi calistirmaz. Zil yolunu
    # "test icin" cagirmak, 15 dakikada bir zil calmak olurdu.
    role = SahteRole(200)
    try:
        d = KuruKontakDiyafon(
            host="127.0.0.1", port=role.port, kullanici=None, sifre=None,
            zil_yolu="/rele1", kapi_yolu="/rele2",
        )
        assert d.saglik().ok is True
    finally:
        role.kapat()
    assert role.yollar == [], "saglik kontrolu HICBIR yolu cagirmamali"


def test_KURU_KONTAK_metin_anons_DESTEKLEMEZ():
    d = KuruKontakDiyafon(
        host="127.0.0.1", port=1, kullanici=None, sifre=None,
        zil_yolu=None, kapi_yolu=None,
    )
    sonuc = d.metin_anons("x")
    assert sonuc.ok is False
    assert sonuc.kod == "diyafon_yontem_desteklemiyor"


def test_KURU_KONTAK_TEMEL_KIMLIK_gonderir():
    role = SahteRole(200)
    try:
        d = KuruKontakDiyafon(
            host="127.0.0.1", port=role.port, kullanici="admin", sifre="1234",
            zil_yolu="/rele1", kapi_yolu=None,
        )
        assert d.zil_cal().ok is True
    finally:
        role.kapat()


# ============================== UC (API) ================================== #
def _mk(client, admin, **over):
    body = {
        "ad": f"Diyafon {uuid.uuid4().hex[:6]}",
        "yontem": "sip",
        "host": "127.0.0.1",
        "hedef": "100",
    }
    body.update(over)
    r = client.post("/diyafon", headers=admin, json=body)
    assert r.status_code == 201, r.text
    return r.json()


def test_SIFRE_YAZILIR_ama_ASLA_DONMEZ(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kayit = _mk(client, admin, kullanici="admin", sifre="gizli123")
    assert kayit["sifre_set"] is True
    assert "sifre" not in kayit and "sifre_enc" not in kayit

    detay = client.get(f"/diyafon/{kayit['id']}", headers=admin).json()
    assert "sifre" not in detay and "sifre_enc" not in detay
    assert detay["sifre_set"] is True


def test_YETENEKLER_YANITTA_DONER(client, world):
    # Istegin maddesi: "hangi yöntemin ne yapabildiği listelensin;
    # musteri secerken bilsin".
    admin = _headers(client, world["slug_a"], world["admin_a"])
    sip = _mk(client, admin, yontem="sip")
    assert sip["yetenekler"]["metin_anons"] is True
    assert sip["yetenekler"]["sesli_anons"] is False

    kuru = _mk(client, admin, yontem="kuru_kontak", hedef=None, zil_yolu="/r1")
    assert kuru["yetenekler"]["metin_anons"] is False
    assert kuru["yetenekler"]["zil_cal"] is True


def test_DESTEKLENMEYEN_EYLEM_422(client, world):
    # "Denedim, olmadi" ile "bu yontem bunu YAPAMAZ" ayri seylerdir.
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kuru = _mk(client, admin, yontem="kuru_kontak", hedef=None, zil_yolu="/r1")
    r = client.post(f"/diyafon/{kuru['id']}/anons", headers=admin, json={"mesaj": "x"})
    assert r.status_code == 422

    sip = _mk(client, admin, yontem="sip")
    assert client.post(f"/diyafon/{sip['id']}/kapi-ac", headers=admin).status_code == 422


def test_SAGLIK_UCU_durumu_yazar(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    # 1 numarali port: kimse dinlemiyor -> ulasilamiyor.
    kayit = _mk(client, admin, host="127.0.0.1", port=1)
    r = client.post(f"/diyafon/{kayit['id']}/saglik", headers=admin)
    assert r.status_code == 200, r.text
    assert r.json()["ok"] is False
    detay = client.get(f"/diyafon/{kayit['id']}", headers=admin).json()
    assert detay["saglik"] == "hata"
    assert detay["son_hata_kod"] == "diyafon_ulasilamiyor"


def test_RBAC_yalniz_YONETIM(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    kayit = _mk(client, admin)
    for rol in ("guard_a", "resident_a", "gorevli_a"):
        h = _headers(client, world["slug_a"], world[rol])
        assert client.get("/diyafon", headers=h).status_code == 403, rol
        assert client.post(
            f"/diyafon/{kayit['id']}/kapi-ac", headers=h
        ).status_code == 403, rol


def test_YOL_TAM_URL_KABUL_ETMEZ(client, world):
    # Tam URL, `host` alanini ANLAMSIZ kilar ve iki farkli hedefi ayni
    # kayda sikistirirdi.
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/diyafon", headers=admin,
        json={"ad": "X", "yontem": "kuru_kontak", "host": "127.0.0.1",
              "zil_yolu": "http://baska/rele"},
    )
    assert r.status_code == 422


# ===================== PANIK -> DIYAFON BAGLANTISI ======================== #
def test_DIYAFON_YOKKEN_PANIK_CALISIR(client, world):
    """Istegin acik maddesi: "panik butonu diyafon olmadan da calismali".

    Yapilandirilmamis bir diyafon bir HATA DEGIL, bir SECIMDIR.
    """
    from app.tasks import panik_yayinla

    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])
    alarm = client.post("/panik", headers=yon, json={"tip": "yonetici_anons"}).json()
    tid = client.get("/me", headers=admin).json()["tenant_id"]

    sonuc = panik_yayinla(alarm["id"], tid)
    assert sonuc["durum"] == "acik"
    assert sonuc["alici"] > 0, "diyafon yokken de alarm GITMELI"


def test_ANONS_DIYAFONA_GIDER_ve_SAKIN_PANIGI_GITMEZ(client, world):
    """TUM-SITE anonsu diyafona gider; SAKIN panigi GITMEZ.

    Bir sakinin evindeki acil durumu butun bloklara duyurmak, o kisinin
    sagligini herkese ilan etmek olurdu.
    """
    from app.tasks import panik_yayinla

    sunucu = SahteSip(200)
    try:
        admin = _headers(client, world["slug_a"], world["admin_a"])
        yon = _headers(client, world["slug_a"], world["yonetici_a"])
        sakin = _headers(client, world["slug_a"], world["resident_a"])
        _mk(client, admin, yontem="sip", host="127.0.0.1", port=sunucu.port,
            hedef="100")
        tid = client.get("/me", headers=admin).json()["tenant_id"]

        # 1) SAKIN PANIGI -> diyafona HICBIR SEY gitmemeli.
        a1 = client.post("/panik", headers=sakin, json={"tip": "sakin"}).json()
        panik_yayinla(a1["id"], tid)
        assert sunucu.alinan == [], "sakin panigi diyafona GITMEMELI"

        # 2) TUM-SITE ANONSU -> MESSAGE gitmeli.
        a2 = client.post(
            "/panik", headers=yon, json={"tip": "yonetici_anons"}
        ).json()
        panik_yayinla(a2["id"], tid)
        assert sunucu.alinan, "anons diyafona GITMELI"
        assert sunucu.alinan[0].decode().startswith("MESSAGE sip:100@")
    finally:
        sunucu.kapat()
