"""(P234 §1) RESEND + TESLIM GERI BILDIRIMI.

Bu dosyanin asil isi ZINCIRI olcmek: saglayici bir mesaj kimligi
uretiyor mu, o kimlik `mesaj_gonderim`e yaziliyor mu, webhook geldiginde
DOGRU satiri buluyor mu. P226/P229 dersi — iki ucu dogru olan bir zincir
ortadan kopuk olabilir.

Saglayicinin kendisi HTTP ADAPTORUNDEN taklit ediliyor (P200 dersi:
taklit repo/API sinifi duzeyine konursa govdeyi kuran katman HIC
olculmez).
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import pathlib
import time
import uuid

import pytest

from app.errors import APIError
from app.gonderim import eposta_saglayicisi
from app.mesajlasma import ResendEpostaSaglayici, SaglayiciAyari
from app.routers.eposta_webhook import OLAY_ESLEME, imza_dogrula


# ===================== 1) SECIM — TASIYICI ADI OLARAK ===================== #

def test_smtp_host_resend_ISE_resend_saglayicisi_doner():
    """`konsol` ile AYNI KALIP: yeni bir secim mekanizmasi acilmadi."""
    a = SaglayiciAyari(smtp_host="resend", smtp_parola="re_test",
                       smtp_gonderen="bildirim@ornek.com")
    s = eposta_saglayicisi(a)
    assert isinstance(s, ResendEpostaSaglayici)
    assert s.ad == "resend"


def test_KENDI_SMTPSINI_giren_tesis_ETKILENMEZ():
    """Gecisin bozmamasi gereken sey: tesis bazli SMTP."""
    a = SaglayiciAyari(smtp_host="posta.tesis.com", smtp_parola="x",
                       smtp_gonderen="a@b.com")
    assert eposta_saglayicisi(a).ad == "smtp"


def test_ANAHTAR_YOKSA_gonderildi_DEMEZ():
    """(P168 §4) Urunun cekirdek garantisi."""
    s = ResendEpostaSaglayici(None, "bildirim@ornek.com")
    sonuc = s.gonder("ali@ornek.com", "Konu", "Govde")
    assert sonuc.durum == "yapilandirilmadi"
    assert sonuc.saglayici_mesaj_id is None


# ===================== 2) GONDERIM — HTTP ADAPTORUNDE ===================== #

class _SahteYanit:
    def __init__(self, kod: int, govde: dict | None = None):
        self.status_code = kod
        self._govde = govde or {}

    def json(self):
        return self._govde


def test_BASARILI_gonderimde_SAGLAYICI_MESAJ_KIMLIGI_doner(monkeypatch):
    """Kimlik OLMADAN bounce webhook'u hicbir satira yazilamaz."""
    cagrilar = []

    def sahte_post(url, **kw):
        cagrilar.append((url, kw))
        return _SahteYanit(200, {"id": "abc-123"})

    import httpx
    monkeypatch.setattr(httpx, "post", sahte_post)

    s = ResendEpostaSaglayici("re_test", "bildirim@ornek.com")
    sonuc = s.gonder("ali@ornek.com", "Konu", "Govde", html="<p>Govde</p>")

    assert sonuc.durum == "gonderildi"
    assert sonuc.saglayici_mesaj_id == "abc-123"
    # GOVDE GERCEKTEN KURULUYOR MU (P200: adaptor duzeyinde olculur).
    url, kw = cagrilar[0]
    assert url == "https://api.resend.com/emails"
    assert kw["headers"]["Authorization"] == "Bearer re_test"
    assert kw["json"]["from"] == "bildirim@ornek.com"
    assert kw["json"]["to"] == ["ali@ornek.com"]
    assert kw["json"]["html"] == "<p>Govde</p>"


def test_ILETILDI_DEMEZ_gonderildi_der(monkeypatch):
    """Teslim bilgisi WEBHOOK'tan gelir; uydurmak panelde yanlis kanit."""
    import httpx
    monkeypatch.setattr(httpx, "post", lambda *a, **k: _SahteYanit(200, {"id": "x"}))
    sonuc = ResendEpostaSaglayici("re_test", "a@b.com").gonder("c@d.com", "K", "G")
    assert sonuc.durum == "gonderildi"


@pytest.mark.parametrize(
    "kod,beklenen",
    [(401, "kimlik_gecersiz"), (403, "alan_adi_dogrulanmadi"),
     (422, "gecersiz_istek"), (429, "hiz_siniri"), (500, "http_500")],
)
def test_SAGLAYICI_HATALARI_ANLAMLI_KODA_cevrilir(monkeypatch, kod, beklenen):
    import httpx
    monkeypatch.setattr(httpx, "post", lambda *a, **k: _SahteYanit(kod))
    sonuc = ResendEpostaSaglayici("re_test", "a@b.com").gonder("c@d.com", "K", "G")
    assert sonuc.durum == "basarisiz"
    assert sonuc.hata == beklenen


def test_AG_HATASI_istegi_DUSURMEZ(monkeypatch):
    """Toplu gonderimde tek adresin hatasi kalan 200 kisiyi dusurmemeli."""
    import httpx

    def patlat(*a, **k):
        raise httpx.ConnectError("yok")

    monkeypatch.setattr(httpx, "post", patlat)
    sonuc = ResendEpostaSaglayici("re_test", "a@b.com").gonder("c@d.com", "K", "G")
    assert sonuc.durum == "basarisiz"
    assert sonuc.hata == "baglanti"


def test_YANIT_GOVDESI_COZULEMESE_DE_gonderim_BASARILI(monkeypatch):
    """Kimlik okunamazsa kaybedilen sey yalniz TAKIP; gonderim oldu."""
    class _Bozuk(_SahteYanit):
        def json(self):
            raise ValueError("bozuk")

    import httpx
    monkeypatch.setattr(httpx, "post", lambda *a, **k: _Bozuk(200))
    sonuc = ResendEpostaSaglayici("re_test", "a@b.com").gonder("c@d.com", "K", "G")
    assert sonuc.durum == "gonderildi"
    assert sonuc.saglayici_mesaj_id is None


# ========================= 3) WEBHOOK IMZA KAPISI ========================= #

SIR = "whsec_" + base64.b64encode(b"cok-gizli-anahtar").decode()


def _imzali(govde: bytes, sir: str = SIR, olay_id: str = "msg_1",
            zaman: int | None = None) -> dict:
    zaman = zaman if zaman is not None else int(time.time())
    anahtar = base64.b64decode(sir[len("whsec_"):])
    imza = base64.b64encode(
        hmac.new(anahtar, f"{olay_id}.{zaman}.".encode() + govde,
                 hashlib.sha256).digest()
    ).decode()
    return {
        "svix-id": olay_id,
        "svix-timestamp": str(zaman),
        "svix-signature": f"v1,{imza}",
    }


def test_GECERLI_IMZA_olay_kimligini_doner():
    govde = b'{"type":"email.delivered"}'
    assert imza_dogrula(govde, _imzali(govde), SIR) == "msg_1"


def test_SIR_YOKSA_401():
    """Yapilandirilmamis webhook'u 'gecerli' saymak ucu herkese acmakti."""
    govde = b"{}"
    with pytest.raises(APIError) as e:
        imza_dogrula(govde, _imzali(govde), None)
    assert e.value.status_code == 401


def test_GOVDE_DEGISTIRILIRSE_401():
    """Sahte bir 'bounce', yoneticiyi sakininin adresini silmeye iterdi."""
    govde = b'{"type":"email.delivered"}'
    basliklar = _imzali(govde)
    with pytest.raises(APIError):
        imza_dogrula(b'{"type":"email.bounced"}', basliklar, SIR)


def test_ESKI_IMZA_REDDEDILIR_tekrar_oynatma():
    govde = b"{}"
    eski = int(time.time()) - 3600
    with pytest.raises(APIError):
        imza_dogrula(govde, _imzali(govde, zaman=eski), SIR)


def test_BIRDEN_COK_IMZA_taninir():
    """Anahtar donusumu sirasinda saglayici iki imza birden yollar."""
    govde = b"{}"
    b = _imzali(govde)
    b["svix-signature"] = "v1,eskianahtarimzasi " + b["svix-signature"]
    assert imza_dogrula(govde, b, SIR) == "msg_1"


# ====================== 4) OLAY ESLEMESI — SOZLESME ====================== #

def test_BOUNCE_ve_SIKAYET_basarisiz_sayilir():
    assert OLAY_ESLEME["email.bounced"] == ("basarisiz", "bounce")
    assert OLAY_ESLEME["email.complained"] == ("basarisiz", "spam_sikayeti")


def test_GECIKME_durumu_DEGISTIRMEZ():
    """Mesaj hala yolda; `basarisiz` demek kullaniciyi bosuna tekrar
    gondermeye iterdi."""
    assert OLAY_ESLEME["email.delivery_delayed"][0] == ""


def test_TESLIM_ve_ACILMA_mevcut_enum_degerlerine_eslenir():
    """Yeni enum degeri ACILMADI: enum'a eklemek geri alinamaz."""
    assert OLAY_ESLEME["email.delivered"][0] == "iletildi"
    assert OLAY_ESLEME["email.opened"][0] == "okundu"


# ================== 5) UCTAN UCA — CANLI UC, GERCEK ZINCIR ================= #
#
# Yukaridaki testler parcalari olcuyor. Burasi ARADAKI HALKAYI olcuyor:
# istek gercekten `/webhooks/eposta/resend`e gidiyor mu, imza kapisi canli
# uctada calisiyor mu, ve DOGRU `mesaj_gonderim` satiri guncelleniyor mu.
# (P226/P229 dersi: iki ucu dogru olan zincir ortadan kopuk olabilir.)


#: UCTAN UCA testler SUNUCUNUN sirriyla imzalamali.
#:
#: Yukaridaki `SIR` yerel bir sabittir ve imza fonksiyonunu tek basina
#: olcer; canli uc ise env'deki sirri kullanir. Ilk yazimda bunu
#: karistirdim ve alti uctan uca test 401 aldi — test kendi sirriyla
#: imzalayip sunucunun sirriyla dogrulanmasini bekliyordu.
SUNUCU_SIRRI = os.environ.get("RESEND_WEBHOOK_SIRRI") or ""


def _webhook_gonder(client, govde_dict: dict, *, olay_id: str,
                    sir: str | None = None):
    sir = sir or SUNUCU_SIRRI
    ham = json.dumps(govde_dict).encode()
    return client.post(
        "/webhooks/eposta/resend",
        content=ham,
        headers={**_imzali(ham, sir, olay_id), "content-type": "application/json"},
    )


pytestmark_sir = pytest.mark.skipif(
    not SUNUCU_SIRRI,
    reason="RESEND_WEBHOOK_SIRRI yok — uctan uca webhook olculemiyor",
)


def test_UCTAN_UCA_imzasiz_istek_401(client):
    r = client.post("/webhooks/eposta/resend", json={"type": "email.delivered"})
    assert r.status_code == 401


def test_UCTAN_UCA_bilinmeyen_olay_200_doner(client):
    """4xx donmek saglayiciyi webhook'u kapatmaya iter."""
    r = _webhook_gonder(
        client, {"type": "email.something_new", "data": {"email_id": "x"}},
        olay_id=f"olay-{uuid.uuid4()}",
    )
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "yoksayildi"


def test_UCTAN_UCA_YANLIS_SIRLA_imzalanan_istek_401(client):
    r = _webhook_gonder(
        client, {"type": "email.delivered", "data": {"email_id": "x"}},
        olay_id=f"olay-{uuid.uuid4()}",
        sir="whsec_" + base64.b64encode(b"yanlis-anahtar").decode(),
    )
    assert r.status_code == 401


def _gonderim_satiri(owner_conn, tenant_id, mesaj_id: str) -> uuid.UUID:
    """Gercek bir `mesaj_gonderim` satiri yazar (durum=gonderildi)."""
    sid = uuid.uuid4()
    with owner_conn.cursor() as c:
        c.execute(
            "INSERT INTO mesaj_gonderim "
            "(id, tenant_id, kanal, amac, hedef, konu, govde, durum, "
            " saglayici, saglayici_mesaj_id, deneme) "
            "VALUES (%s,%s,'eposta','operasyonel',%s,'K','G','gonderildi',"
            "        'resend',%s,1)",
            (sid, tenant_id, "alici@ornek.com", mesaj_id),
        )
    return sid


def _durum(owner_conn, sid) -> tuple[str, str | None]:
    with owner_conn.cursor() as c:
        c.execute("SELECT durum, hata FROM mesaj_gonderim WHERE id=%s", (sid,))
        return c.fetchone()


def test_UCTAN_UCA_BOUNCE_satiri_basarisiz_yapar(client, owner_conn, world):
    """ASIL OLCUM: panel 'gonderildi' yaziyordu, bounce goruunmuyordu."""
    mid = f"resend-{uuid.uuid4()}"
    sid = _gonderim_satiri(owner_conn, world["a"], mid)

    r = _webhook_gonder(
        client, {"type": "email.bounced", "data": {"email_id": mid}},
        olay_id=f"olay-{uuid.uuid4()}",
    )
    assert r.status_code == 200, r.text
    assert r.json()["durum"] == "islendi"
    assert _durum(owner_conn, sid) == ("basarisiz", "bounce")


def test_UCTAN_UCA_TESLIM_ve_ACILMA_ILERLER(client, owner_conn, world):
    mid = f"resend-{uuid.uuid4()}"
    sid = _gonderim_satiri(owner_conn, world["a"], mid)

    for tur, beklenen in (("email.delivered", "iletildi"),
                          ("email.opened", "okundu")):
        r = _webhook_gonder(client, {"type": tur, "data": {"email_id": mid}},
                            olay_id=f"olay-{uuid.uuid4()}")
        assert r.status_code == 200, r.text
        assert _durum(owner_conn, sid)[0] == beklenen


def test_UCTAN_UCA_DURUM_GERI_GITMEZ(client, owner_conn, world):
    """Olaylar SIRASIZ gelebilir; 'okundu' sonradan 'gonderildi'ye donmemeli."""
    mid = f"resend-{uuid.uuid4()}"
    sid = _gonderim_satiri(owner_conn, world["a"], mid)

    _webhook_gonder(client, {"type": "email.opened", "data": {"email_id": mid}},
                    olay_id=f"olay-{uuid.uuid4()}")
    assert _durum(owner_conn, sid)[0] == "okundu"

    _webhook_gonder(client, {"type": "email.delivered", "data": {"email_id": mid}},
                    olay_id=f"olay-{uuid.uuid4()}")
    assert _durum(owner_conn, sid)[0] == "okundu"


def test_UCTAN_UCA_AYNI_OLAY_IKI_KEZ_ISLENMEZ(client, owner_conn, world):
    """Saglayici teslim garantisi 'en az bir kez'dir."""
    mid = f"resend-{uuid.uuid4()}"
    sid = _gonderim_satiri(owner_conn, world["a"], mid)
    olay = f"olay-{uuid.uuid4()}"

    govde = {"type": "email.bounced", "data": {"email_id": mid}}
    assert _webhook_gonder(client, govde, olay_id=olay).json()["durum"] == "islendi"
    assert _webhook_gonder(client, govde, olay_id=olay).json()["durum"] == "tekrar"


def test_UCTAN_UCA_BIZE_AIT_OLMAYAN_MESAJ_404_DONMEZ(client):
    """404 donmek saglayiciyi tekrar denemeye ve sonunda webhook'u
    kapatmaya iter — BILDIGIMIZ olaylari da kaybederiz."""
    r = _webhook_gonder(
        client,
        {"type": "email.bounced", "data": {"email_id": f"yok-{uuid.uuid4()}"}},
        olay_id=f"olay-{uuid.uuid4()}",
    )
    assert r.status_code == 200
    assert r.json()["durum"] == "eslesmedi"



# ================== 6) KAPSAM KILIDI — UNUTULAN YOL YOK ================== #
#
# KIRARAK DOGRULANDI: `davet.py`den `saglayici_mesaj_id=` satirini
# SILDIM ve yukaridaki 28 testin HICBIRI dusmedi. Yani davet e-postasi
# bounce olsa panelde yine "gonderildi" yazardi — turun duzeltmeye
# calistigi kusurun ta kendisi, yalnizca baska bir yolda.
#
# Davranis testiyle yakalanamiyor: konsol/log saglayicilari kimlik
# uretmiyor ve gercek Resend cagrisi yapilamaz. Bu yuzden kilit KAYNAGA
# bakiyor — P233'teki telefon/e-posta kapsam kilitleriyle ayni sinif.

_KOK = pathlib.Path(__file__).resolve().parent.parent / "app"


def _yorumsuz(metin: str) -> str:
    return "\n".join(
        satir.split("#")[0] for satir in metin.splitlines()
    )


def eposta_satiri_ihlalleri(kaynak: str, yol: str) -> list[str]:
    """`MesajGonderim(...)` kurup `saglayici_mesaj_id` GECMEYEN yerler.

    Mantik AYRI fonksiyonda: kasitli kusurlu bir ornekle sinanabilsin.
    """
    temiz = _yorumsuz(kaynak)
    bulgular = []
    i = 0
    while True:
        i = temiz.find("MesajGonderim(", i)
        if i < 0:
            break
        # Dengeli parantezle blogu bul.
        d, j = 0, temiz.index("(", i)
        for j in range(temiz.index("(", i), len(temiz)):
            if temiz[j] == "(":
                d += 1
            elif temiz[j] == ")":
                d -= 1
                if d == 0:
                    break
        blok = temiz[i:j + 1]
        # YALNIZ E-POSTA yollari: SMS/push satirlarinda saglayici mesaj
        # kimligi diye bir sey YOK ve istemek anlamsiz olurdu.
        if '"eposta"' in blok or "'eposta'" in blok:
            if "saglayici_mesaj_id" not in blok:
                satir = temiz[:i].count("\n") + 1
                bulgular.append(f"{yol}:{satir}  saglayici_mesaj_id YAZILMIYOR")
        i = j + 1
    return bulgular


def test_DEDEKTOR_tarama_KASITLI_kusuru_gorur():
    kusurlu = 'MesajGonderim(kanal="eposta", durum=sonuc.durum)'
    assert len(eposta_satiri_ihlalleri(kusurlu, "ornek.py")) == 1
    saglam = (
        'MesajGonderim(kanal="eposta", durum=sonuc.durum, '
        "saglayici_mesaj_id=sonuc.saglayici_mesaj_id)"
    )
    assert eposta_satiri_ihlalleri(saglam, "ornek.py") == []
    # SMS satiri ihlal DEGIL.
    assert eposta_satiri_ihlalleri('MesajGonderim(kanal="sms")', "o.py") == []
    # YORUMDAKI ornek bulgu sayilmaz.
    assert eposta_satiri_ihlalleri('# MesajGonderim(kanal="eposta")', "o.py") == []


def test_HER_EPOSTA_YOLU_saglayici_mesaj_kimligini_yaziyor():
    bulgular = []
    for yol in _KOK.rglob("*.py"):
        bulgular += eposta_satiri_ihlalleri(
            yol.read_text(encoding="utf-8"), str(yol.relative_to(_KOK))
        )
    assert bulgular == [], (
        "Teslim geri bildirimi bu yollarda BAGLANMIYOR — bounce panelde "
        "gorunmez:\n" + "\n".join(bulgular)
    )
