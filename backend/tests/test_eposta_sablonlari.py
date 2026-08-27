"""(P181 Bölüm 5) Kimlik-doğrulama e-posta şablonları — amaç başına ayrı metin.

Saf fonksiyon testi (SMTP yok): her amaç kendi konu+gövdesini üretir, kod + süre
+ marka + kimlik-avı satırı içerir, bilinmeyen amaç güvenli varsayılana düşer.
"""
from app.eposta_sablonlari import GONDEREN, MARKA, eposta_kod_metni

AMACLAR = ["kayit", "giris", "eposta_ekle", "sifre_sifirla", "hesap_silme"]


def test_BES_amac_AYRI_konu():
    konular = [eposta_kod_metni(a, "123456", 10)[0] for a in AMACLAR]
    assert len(set(konular)) == 5, "amaçlar aynı konuyu paylaşıyor"


def test_BES_amac_AYRI_govde():
    govdeler = [eposta_kod_metni(a, "123456", 10)[1] for a in AMACLAR]
    assert len(set(govdeler)) == 5, "amaçlar aynı gövdeyi paylaşıyor"


def test_govde_KOD_SURE_MARKA_ve_kimlik_avi_satiri():
    for a in AMACLAR:
        konu, govde = eposta_kod_metni(a, "654321", 10)
        assert "654321" in govde, f"{a}: kod yok"
        assert "10 dakika" in govde, f"{a}: süre yok"
        assert MARKA in konu, f"{a}: konuda marka yok"
        assert MARKA in govde, f"{a}: gövdede marka yok"
        assert GONDEREN in govde, f"{a}: gönderen imzası yok"
        assert "yok sayabilirsiniz" in govde, f"{a}: kimlik-avı satırı yok"


def test_sure_govdeye_yansir():
    _, govde = eposta_kod_metni("giris", "111111", 3)
    assert "3 dakika" in govde


def test_bilinmeyen_amac_VARSAYILANA_duser():
    konu, govde = eposta_kod_metni("bilinmeyen_amac", "222333", 10)
    assert MARKA in konu
    assert "222333" in govde
    assert govde  # asla boş değil
