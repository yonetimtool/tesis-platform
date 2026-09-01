"""(P181 Bölüm 5) Kimlik-doğrulama e-posta şablonları — AMAÇ BAŞINA ayrı.

Bugüne dek TÜM amaç için TEK sabit metin gidiyordu ("Yönetiyor doğrulama
kodunuz: ..."). Artık her amaç kendi konu + gövdesini alır: kullanıcı kodun
NE İÇİN olduğunu görür (kayıt / giriş / e-posta doğrulama / parola sıfırlama /
hesap silme) ve bir kimlik-avı savunma satırı içerir ("siz istemediyseniz yok
sayın").

E-POSTA TABANLI, SMS YOK. Düz metin (mevcut SMTP `set_content` ile uyumlu);
markalama başlık + imza satırıyla. i18n: şimdilik yalnız Türkçe (backend tek
dilli; kullanıcı/tenant dil alanı yok — bkz. P181-kararlar Bölüm 5).
"""
from __future__ import annotations

MARKA = "Yönetiyor"
GONDEREN = "noreply@yonetiyor.com"

#: amaç -> (konu, açıklama paragrafı). Konu MARKA ile başlar; gövde ortak
#: iskelette (kod + süre + kimlik-avı satırı + imza) sarılır.
_SABLONLAR: dict[str, tuple[str, str]] = {
    "kayit": (
        f"{MARKA} — Hesap doğrulama kodu",
        f"{MARKA} hesabınızı oluşturmak için doğrulama kodunuz aşağıdadır.",
    ),
    "giris": (
        f"{MARKA} — Giriş kodu",
        f"{MARKA}'a parolasız giriş için tek kullanımlık kodunuz aşağıdadır.",
    ),
    "eposta_ekle": (
        f"{MARKA} — E-posta doğrulama kodu",
        "E-posta adresinizi doğrulamak için kodunuz aşağıdadır.",
    ),
    "sifre_sifirla": (
        f"{MARKA} — Parola sıfırlama kodu",
        "Parolanızı sıfırlamak için doğrulama kodunuz aşağıdadır.",
    ),
    "hesap_silme": (
        f"{MARKA} — Hesap silme onay kodu",
        "Hesabınızı silme işlemini onaylamak için kodunuz aşağıdadır.",
    ),
}

_VARSAYILAN: tuple[str, str] = (
    f"{MARKA} — Doğrulama kodu",
    "Doğrulama kodunuz aşağıdadır.",
)


def eposta_degistirme_bildirimi_metni() -> tuple[str, str]:
    """(P184-ek §9) ESKİ adrese giden değiştirme BİLDİRİMİ — kod DEĞİL.

    Kullanıcı e-postasını değiştirmek istediğinde ESKİ (doğrulanmış) adrese
    gider: hesap ele geçirilmişse sahibi fark etsin. YENİ adres burada YAZILMAZ
    (o adres bir sırdır ve eski gelen kutusuna yazmak gereksiz bilgi sızdırırdı).
    """
    konu = f"{MARKA} — E-posta değiştirme talebi"
    govde = (
        "Hesabınızın e-posta adresini değiştirme talebi aldık. Yeni adres "
        "doğrulanana kadar BU adres geçerli kalır ve hesabınız kilitlenmez.\n\n"
        "Bu talebi SİZ yapmadıysanız hesabınız tehlikede olabilir: "
        "parolanızı hemen değiştirin ve yöneticinize başvurun.\n\n"
        f"— {MARKA}\n{GONDEREN}"
    )
    return konu, govde


def eposta_kod_metni(amac: str, kod: str, dk: int) -> tuple[str, str]:
    """Amaca göre markalı e-posta (konu, gövde) döndürür — düz metin.

    Bilinmeyen amaç güvenli VARSAYILANa düşer (asla boş konu/gövde göndermez).
    """
    konu, aciklama = _SABLONLAR.get(amac, _VARSAYILAN)
    govde = (
        f"{aciklama}\n\n"
        f"Kod: {kod}\n"
        f"Bu kod {dk} dakika geçerlidir.\n\n"
        "Bu isteği siz yapmadıysanız bu e-postayı yok sayabilirsiniz; "
        "hesabınız güvende kalır.\n\n"
        f"— {MARKA}\n{GONDEREN}"
    )
    return konu, govde


# --------------------------------------------------------------------------- #
# (P192 §4.4) MAKBUZ E-POSTASI
#
# Push ANLIK, e-posta KALICIDIR: sakin telefonunu degistirse, uygulamayi
# silse ya da bildirimi kacirsa bile makbuzun bir kopyasi posta kutusunda
# durur. Ikisi birlikte gonderilir; biri otekinin yerine gecmez.
#
# PDF EKLENMEZ, BAGLANTI VERILIR: ek olarak gonderilen bir PDF, e-posta
# saglayicilarinin boyut sinirlarina ve spam suzgeclerine takilir; ayrica
# baglanti KISA OMURLUDUR (presign) ve posta kutusu ele gecse bile
# suresiz erisim vermez.
# --------------------------------------------------------------------------- #
def makbuz_metni(
    *, site_ad: str, belge_no: str, tutar: str, baglanti: str | None
) -> tuple[str, str]:
    """(konu, govde) — sade metin.

    HTML YOK: makbuz bildirimi bicimlendirmeye ihtiyac duymayan uc
    satirlik bir bilgidir ve HTML surumu ikinci bir bakim yuku olurdu.
    """
    konu = f"{site_ad} — Ödeme makbuzunuz ({belge_no})"
    satirlar = [
        f"Sayın site sakini,",
        "",
        f"{tutar} tutarındaki ödemeniz alınmıştır.",
        f"Makbuz no: {belge_no}",
    ]
    if baglanti:
        satirlar += [
            "",
            "Makbuzun PDF kopyası (bağlantı kısa ömürlüdür):",
            baglanti,
        ]
    satirlar += ["", f"{site_ad}"]
    return konu, "\n".join(satirlar)
