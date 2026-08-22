"""(P150) SMS gecidi — saglayici SECIMI ve guvenli varsayilan.

En kritik olcum: YARIM YAPILANDIRMA "calisiyor" SAYILMAMALI. Sayilsaydi
kodlar sessizce hicbir yere gitmezdi; kullanici giris yapamaz, sebebi de
gorunmezdi.
"""
import app.mesajlasma as m


class _Ayar:
    """(P177) `sms_aktif` VARSAYILAN `True` — ve bu bilincli.

    Bu dosyanin olctugu sey SAGLAYICI SECIMIDIR: yarim yapilandirma
    "calisiyor" sayilmamali, bilinmeyen saglayici log'a dusmeli. O soru
    ancak SMS KANALI ACIKKEN anlamlidir.

    P177'de kanalin onune bir ANA SALTER kondu (`SMS_AKTIF`, varsayilan
    kapali — onayli gonderici basligimiz yok). Salter kapaliyken
    `sms_saglayicisi()` saglayici ne olursa olsun `KapaliSmsSaglayici`
    doner; yani bu dosyadaki her test "sms-kapali" gorurdu ve secim
    mantigi BIR DAHA HIC OLCULMEZDI.

    Salterin KENDISI `test_p177_sms_ve_ileti.py`de olculuyor (tesis
    ayarini bile ezdigi dahil). Burada acik birakiliyor ki iki soru
    birbirini kormesin.
    """

    def __init__(self, **kw):
        self.sms_aktif = kw.get("aktif", True)
        self.sms_saglayici = kw.get("saglayici")
        self.sms_kullanici = kw.get("kullanici")
        self.sms_parola = kw.get("parola")
        self.sms_baslik = kw.get("baslik")
        self.sms_url = "https://ornek/api"


def _sec(monkeypatch, ayar):
    monkeypatch.setattr("app.config.settings", ayar, raising=False)
    return m.sms_saglayicisi()


def test_YAPILANDIRILMAMIS_ise_LOG_saglayici(monkeypatch):
    """Guvenli varsayilan: yanlislikla gondermektense HIC gondermemek."""
    assert _sec(monkeypatch, _Ayar()).ad == "log-sms"


def test_YARIM_yapilandirma_LOGA_DUSER(monkeypatch):
    """Parola/baslik eksikken 'netgsm' secili olmasi calisiyor DEMEK DEGIL."""
    s = _sec(monkeypatch, _Ayar(saglayici="netgsm", kullanici="u"))
    assert s.ad == "log-sms"


def test_BILINMEYEN_saglayici_LOGA_DUSER(monkeypatch):
    assert _sec(monkeypatch, _Ayar(saglayici="hayali")).ad == "log-sms"


def test_TAM_yapilandirma_GERCEK_saglayiciyi_secer(monkeypatch):
    s = _sec(monkeypatch, _Ayar(
        saglayici="netgsm", kullanici="u", parola="p", baslik="YONETIO"))
    assert s.ad == "netgsm"


def test_saglayici_HATASI_istisna_FIRLATMAZ(monkeypatch):
    """Gonderim hatasi kaydi KIRMAMALI: kod yazilmistir, kullanici
    'tekrar gonder' diyebilir. Istisna yukselseydi kayit geri sarilirdi."""
    s = m.NetgsmSmsSaglayici("u", "p", "H", "http://127.0.0.1:9/yok")
    sonuc = s.gonder("+905000000000", None, "kod")
    assert sonuc.durum == "hata"
    assert sonuc.saglayici == "netgsm"
