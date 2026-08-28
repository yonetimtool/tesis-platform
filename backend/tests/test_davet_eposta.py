"""(P185) Davet e-postası builder testleri — saf birim, canlı sunucu YOK.

Düz `def test_...()` fonksiyonları, doğrudan assert (mevcut
`test_eposta_sablonlari.py` üslubu). SMTP/DB/ağ yok.
"""
from app.davet_eposta import DAVET_DILLERI, davet_eposta

BAG = "https://yönetiyor.com/davet/abc123token"
PLAY = "https://play.google.com/store/apps/details?id=com.app.yonetiyor"
APPSTORE = "https://apps.apple.com/app/id123456789"


def _cagir(**kw):
    varsayilan = dict(
        dil="tr",
        tenant_ad="Yeşil Vadi Sitesi",
        tesis_kodu="TES-4821",
        bag=BAG,
        play_store_url=PLAY,
        app_store_url=APPSTORE,
        yil=2026,
    )
    varsayilan.update(kw)
    return davet_eposta(**varsayilan)


def test_yedi_dil_bos_degil_ve_doctype():
    for dil in DAVET_DILLERI:
        konu, metin, html_govde = _cagir(dil=dil)
        assert konu, f"{dil}: konu boş"
        assert metin, f"{dil}: metin boş"
        assert html_govde, f"{dil}: html boş"
        assert html_govde.startswith("<!DOCTYPE"), f"{dil}: DOCTYPE ile başlamıyor"


def test_yedi_dil_hepsi_var():
    assert DAVET_DILLERI == ("tr", "en", "ar", "ru", "de", "fr", "es")


def test_bilinmeyen_dil_tr_ye_duser():
    tr = _cagir(dil="tr")
    bilinmeyen = _cagir(dil="klingon")
    assert bilinmeyen == tr
    yok = _cagir(dil=None)
    assert yok == tr


def test_arapca_rtl():
    _, _, html_govde = _cagir(dil="ar")
    assert 'dir="rtl"' in html_govde
    assert 'lang="ar"' in html_govde


def test_app_store_yoksa_buton_yok_ama_play_var():
    for bos in ("", None):
        _, metin, html_govde = _cagir(app_store_url=bos)
        assert "App Store" not in html_govde
        assert "App Store" not in metin
        assert "Google Play" in html_govde
        assert PLAY in html_govde
        assert PLAY in metin


def test_play_yoksa_buton_yok_ama_appstore_var():
    for bos in ("", None):
        _, metin, html_govde = _cagir(play_store_url=bos)
        assert "Google Play" not in html_govde
        assert "Google Play" not in metin
        assert "App Store" in html_govde
        assert APPSTORE in html_govde
        assert APPSTORE in metin


def test_tesis_kodu_verbatim_html_ve_metin():
    for dil in DAVET_DILLERI:
        _, metin, html_govde = _cagir(dil=dil, tesis_kodu="TES-9999")
        assert "TES-9999" in html_govde, f"{dil}: html'de kod yok"
        assert "TES-9999" in metin, f"{dil}: metinde kod yok"


def test_tesis_kodu_none_ise_etiket_bloku_yok():
    for dil in DAVET_DILLERI:
        _, metin, html_govde = _cagir(dil=dil, tesis_kodu=None)
        # kod etiketi (dile özgü) HTML çip bloğunda görünmemeli
        assert "TES-4821" not in html_govde
        assert "TES-4821" not in metin


def test_app_yonetiyor_hicbir_yerde_yok():
    # NOT: bare "app.yonetiyor" YANLIS pozitiftir — Play paket id'si
    # `com.app.yonetiyor` bu alt-diziyi TASIR (bkz. P177 davet 'app.' bug'i).
    # Yasaklanan sey WEB-PANEL alanidir: `app.yonetiyor.com` / `//app.yonetiyor`.
    for dil in DAVET_DILLERI:
        _, metin, html_govde = _cagir(dil=dil)
        for yasak in ("app.yonetiyor.com", "//app.yonetiyor"):
            assert yasak not in html_govde, f"{dil}: html'de web-panel bağı var ({yasak})"
            assert yasak not in metin, f"{dil}: metinde web-panel bağı var ({yasak})"


def test_html_escape_uygulanir():
    _, _, html_govde = _cagir(tenant_ad="<b>x&y</b>")
    assert "<b>x&y</b>" not in html_govde
    assert "&lt;b&gt;x&amp;y&lt;/b&gt;" in html_govde


def test_davet_bagi_html_ve_metinde():
    for dil in DAVET_DILLERI:
        _, metin, html_govde = _cagir(dil=dil)
        assert BAG in metin, f"{dil}: metinde davet bağı yok"
        assert BAG in html_govde, f"{dil}: html'de davet bağı yok"


def test_yil_footerda():
    for dil in DAVET_DILLERI:
        _, metin, html_govde = _cagir(dil=dil, yil=2026)
        assert "2026" in metin, f"{dil}: metin footer yıl yok"
        assert "2026" in html_govde, f"{dil}: html footer yıl yok"


def test_logo_url_yoksa_metin_isareti():
    _, _, html_govde = _cagir(logo_url=None)
    assert "<img" not in html_govde or 'alt="Yönetiyor"' not in html_govde
    assert "Yönetiyor" in html_govde


def test_logo_url_varsa_img():
    logo = "https://cdn.yonetiyor.com/logo.png"
    _, _, html_govde = _cagir(logo_url=logo)
    assert "<img" in html_govde
    assert logo in html_govde
