"""(P250 §2) Ödeme kodu e-postası — 7 dilde HTML + düz metin.

İçerik (kullanıcının istediği): kişinin adı, daire, ödeme kodu, banka/IBAN,
havale açıklamasına ne yazılacağı, kısa açıklama. Kurumsal kabuk
`eposta_kabugu.py`de (logolu başlık, davet e-postasıyla aynı görünüm).

Saf fonksiyon: DB/ağ/saat yok; yıl ve bütün değerler çağırandan gelir.
"""
from __future__ import annotations

from . import eposta_kabugu as K

_M: dict[str, dict[str, str]] = {
    "tr": {
        "konu": "{tesis} — ödeme kodunuz",
        "selam": "Merhaba {ad},",
        "giris": "{tesis} yönetimi, aidat ve diğer ödemelerinizin hesabınıza otomatik işlenmesi için size kişisel bir ödeme kodu tanımladı.",
        "kod": "Ödeme kodunuz",
        "kod_ipucu": "Bu kod size özeldir.",
        "daire": "Daire", "banka": "Banka", "iban": "IBAN", "alici": "Alıcı",
        "talimat_baslik": "Havale / EFT yaparken",
        "talimat": "Açıklama alanına yalnızca ödeme kodunuzu yazın: {kod}",
        "aciklama": "Ödemeniz bu kod sayesinde dairenize otomatik olarak işlenir. Kodu yazmazsanız eşleştirme yönetim tarafından elle yapılır ve gecikebilir.",
        "uygulama": "Kodunuzu, borcunuzu ve ödemelerinizi Yönetiyor uygulamasından da görebilirsiniz.",
    },
    "en": {
        "konu": "{tesis} — your payment code",
        "selam": "Hello {ad},",
        "giris": "The management of {tesis} has assigned you a personal payment code so that your dues and other payments are recorded to your account automatically.",
        "kod": "Your payment code",
        "kod_ipucu": "This code is personal to you.",
        "daire": "Unit", "banka": "Bank", "iban": "IBAN", "alici": "Beneficiary",
        "talimat_baslik": "When making a bank transfer",
        "talimat": "Write only your payment code in the description field: {kod}",
        "aciklama": "Thanks to this code, your payment is recorded to your unit automatically. Without it, management matches the payment by hand, which may take longer.",
        "uygulama": "You can also see your code, balance and payments in the Yönetiyor app.",
    },
    "de": {
        "konu": "{tesis} — Ihr Zahlungscode",
        "selam": "Hallo {ad},",
        "giris": "Die Verwaltung von {tesis} hat Ihnen einen persönlichen Zahlungscode zugewiesen, damit Ihr Hausgeld und andere Zahlungen automatisch Ihrem Konto zugeordnet werden.",
        "kod": "Ihr Zahlungscode",
        "kod_ipucu": "Dieser Code gilt nur für Sie.",
        "daire": "Wohnung", "banka": "Bank", "iban": "IBAN", "alici": "Empfänger",
        "talimat_baslik": "Bei einer Überweisung",
        "talimat": "Geben Sie im Verwendungszweck nur Ihren Zahlungscode an: {kod}",
        "aciklama": "Mit diesem Code wird Ihre Zahlung automatisch Ihrer Wohnung zugeordnet. Ohne Code ordnet die Verwaltung sie manuell zu, was länger dauern kann.",
        "uygulama": "Ihren Code, Ihren Saldo und Ihre Zahlungen sehen Sie auch in der Yönetiyor-App.",
    },
    "fr": {
        "konu": "{tesis} — votre code de paiement",
        "selam": "Bonjour {ad},",
        "giris": "La gestion de {tesis} vous a attribué un code de paiement personnel afin que vos charges et autres paiements soient enregistrés automatiquement sur votre compte.",
        "kod": "Votre code de paiement",
        "kod_ipucu": "Ce code vous est personnel.",
        "daire": "Logement", "banka": "Banque", "iban": "IBAN", "alici": "Bénéficiaire",
        "talimat_baslik": "Lors d'un virement",
        "talimat": "Indiquez uniquement votre code de paiement dans le libellé : {kod}",
        "aciklama": "Grâce à ce code, votre paiement est affecté automatiquement à votre logement. Sans lui, la gestion le rapproche manuellement, ce qui peut prendre plus de temps.",
        "uygulama": "Vous pouvez aussi voir votre code, votre solde et vos paiements dans l'application Yönetiyor.",
    },
    "es": {
        "konu": "{tesis} — su código de pago",
        "selam": "Hola {ad}:",
        "giris": "La administración de {tesis} le ha asignado un código de pago personal para que sus cuotas y otros pagos se registren automáticamente en su cuenta.",
        "kod": "Su código de pago",
        "kod_ipucu": "Este código es personal.",
        "daire": "Vivienda", "banka": "Banco", "iban": "IBAN", "alici": "Beneficiario",
        "talimat_baslik": "Al hacer una transferencia",
        "talimat": "Escriba solo su código de pago en el concepto: {kod}",
        "aciklama": "Gracias a este código, su pago se asigna automáticamente a su vivienda. Sin él, la administración lo concilia a mano y puede tardar más.",
        "uygulama": "También puede ver su código, su saldo y sus pagos en la aplicación Yönetiyor.",
    },
    "ar": {
        "konu": "{tesis} — رمز الدفع الخاص بك",
        "selam": "مرحبًا {ad}،",
        "giris": "خصصت إدارة {tesis} لك رمز دفع شخصيًا لكي تُسجَّل رسومك ومدفوعاتك الأخرى في حسابك تلقائيًا.",
        "kod": "رمز الدفع الخاص بك",
        "kod_ipucu": "هذا الرمز خاص بك.",
        "daire": "الوحدة", "banka": "البنك", "iban": "IBAN", "alici": "المستفيد",
        "talimat_baslik": "عند إجراء تحويل بنكي",
        "talimat": "اكتب رمز الدفع فقط في خانة الوصف: {kod}",
        "aciklama": "بفضل هذا الرمز تُسجَّل دفعتك لوحدتك تلقائيًا. بدونه تطابقها الإدارة يدويًا وقد يستغرق ذلك وقتًا أطول.",
        "uygulama": "يمكنك أيضًا رؤية رمزك ورصيدك ومدفوعاتك في تطبيق Yönetiyor.",
    },
    "ru": {
        "konu": "{tesis} — ваш платёжный код",
        "selam": "Здравствуйте, {ad}!",
        "giris": "Управление {tesis} присвоило вам личный платёжный код, чтобы ваши взносы и другие платежи автоматически зачислялись на ваш счёт.",
        "kod": "Ваш платёжный код",
        "kod_ipucu": "Этот код только для вас.",
        "daire": "Квартира", "banka": "Банк", "iban": "IBAN", "alici": "Получатель",
        "talimat_baslik": "При банковском переводе",
        "talimat": "В назначении платежа укажите только ваш платёжный код: {kod}",
        "aciklama": "Благодаря этому коду платёж автоматически зачисляется на вашу квартиру. Без кода управление сопоставляет его вручную, и это может занять больше времени.",
        "uygulama": "Код, баланс и платежи также видны в приложении Yönetiyor.",
    },
}


def odeme_kodu_eposta(
    *,
    dil: str | None,
    tesis_ad: str,
    ad: str,
    daire: str | None,
    odeme_kodu: str,
    banka_adi: str | None,
    iban: str | None,
    alici: str | None,
    yil: int,
) -> tuple[str, str, str]:
    """(konu, düz metin, html). IBAN yoksa banka satırları çizilmez."""
    d = K.dil_coz(dil)
    m = _M[d]
    h = K.Hizalama(d)
    konu = m["konu"].format(tesis=tesis_ad)

    bilgiler: list[tuple[str, str]] = []
    if daire:
        bilgiler.append((m["daire"], daire))
    if iban:
        if banka_adi:
            bilgiler.append((m["banka"], banka_adi))
        if alici:
            bilgiler.append((m["alici"], alici))
        bilgiler.append((m["iban"], iban))

    govde = (
        K.paragraf(h, K.e(m["selam"].format(ad=ad)), kalin=True, boyut=16)
        + K.paragraf(h, K.e(m["giris"].format(tesis=tesis_ad)))
        + K.kod_cipi(m["kod"], odeme_kodu, m["kod_ipucu"])
        + K.bilgi_tablosu(h, bilgiler)
        + K.paragraf(h, K.e(m["talimat_baslik"]), kalin=True)
        + K.paragraf(h, K.e(m["talimat"].format(kod=odeme_kodu)))
        + K.paragraf(h, K.e(m["aciklama"]), boyut=14)
        + K.paragraf(h, K.e(m["uygulama"]), boyut=14)
        + K.magaza_butonlari()
    )
    html_govde = K.kabuk(dil=d, konu=konu, govde_html=govde, yil=yil)

    satirlar = [m["selam"].format(ad=ad), "", m["giris"].format(tesis=tesis_ad), ""]
    satirlar.append(f"{m['kod']}: {odeme_kodu}")
    for etiket, deger in bilgiler:
        satirlar.append(f"{etiket}: {deger}")
    satirlar += [
        "",
        m["talimat_baslik"],
        m["talimat"].format(kod=odeme_kodu),
        "",
        m["aciklama"],
        "",
        m["uygulama"],
    ]
    if K.settings.play_store_url:
        satirlar.append(f"Google Play: {K.settings.play_store_url}")
    if K.settings.app_store_url:
        satirlar.append(f"App Store: {K.settings.app_store_url}")
    satirlar += ["", K.altbilgi_metni(d, yil)]
    return konu, "\n".join(satirlar), html_govde
