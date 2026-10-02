"""(P250 §7) Aidat hatırlatma e-postası — 7 dil, nazik dil, HTML + düz metin.

İçerik: borç tutarı, dönem(ler), son ödeme günü, ödeme kodu, IBAN, havale
açıklamasına ne yazılacağı. "Ödediyseniz dikkate almayın" cümlesi
ZORUNLU: banka eşleşmesi gecikebilir ve ödeyen sakini suçlayan bir dil
güveni bozar.

Saf fonksiyon: DB/ağ/saat yok. Kabuk `eposta_kabugu.py`de.
"""
from __future__ import annotations

from . import eposta_kabugu as K

_M: dict[str, dict[str, str]] = {
    "tr": {
        "konu": "{tesis} — aidat hatırlatması",
        "selam": "Merhaba {ad},",
        "giris": "{tesis} kayıtlarına göre aşağıdaki aidat ödemeniz henüz görünmüyor. Hatırlatmak isteriz.",
        "tutar": "Ödenmemiş tutar", "donem": "Dönem", "vade": "Son ödeme günü",
        "kod": "Ödeme kodunuz", "banka": "Banka", "iban": "IBAN",
        "talimat": "Havale / EFT açıklamasına yalnızca ödeme kodunuzu yazın: {kod}",
        "odediyseniz": "Ödemenizi yaptıysanız bu mesajı dikkate almayın; ödemenin kayıtlara yansıması birkaç gün sürebilir.",
        "soru": "Bir sorunuz varsa yönetimle Yönetiyor uygulamasından iletişime geçebilirsiniz.",
        "tesekkur": "Teşekkür ederiz.",
    },
    "en": {
        "konu": "{tesis} — dues reminder",
        "selam": "Hello {ad},",
        "giris": "According to the records of {tesis}, the dues payment below has not been received yet. This is a friendly reminder.",
        "tutar": "Amount due", "donem": "Period", "vade": "Due date",
        "kod": "Your payment code", "banka": "Bank", "iban": "IBAN",
        "talimat": "Write only your payment code in the transfer description: {kod}",
        "odediyseniz": "If you have already paid, please disregard this message; it may take a few days for the payment to appear in the records.",
        "soru": "If you have any questions, you can contact management in the Yönetiyor app.",
        "tesekkur": "Thank you.",
    },
    "de": {
        "konu": "{tesis} — Erinnerung an das Hausgeld",
        "selam": "Hallo {ad},",
        "giris": "Laut den Unterlagen von {tesis} ist die folgende Hausgeldzahlung noch nicht eingegangen. Wir möchten Sie freundlich daran erinnern.",
        "tutar": "Offener Betrag", "donem": "Zeitraum", "vade": "Fälligkeitsdatum",
        "kod": "Ihr Zahlungscode", "banka": "Bank", "iban": "IBAN",
        "talimat": "Geben Sie im Verwendungszweck nur Ihren Zahlungscode an: {kod}",
        "odediyseniz": "Falls Sie bereits gezahlt haben, betrachten Sie diese Nachricht bitte als gegenstandslos; die Buchung kann einige Tage dauern.",
        "soru": "Bei Fragen erreichen Sie die Verwaltung in der Yönetiyor-App.",
        "tesekkur": "Vielen Dank.",
    },
    "fr": {
        "konu": "{tesis} — rappel de charges",
        "selam": "Bonjour {ad},",
        "giris": "D'après les registres de {tesis}, le paiement de charges ci-dessous n'a pas encore été reçu. Nous nous permettons de vous le rappeler.",
        "tutar": "Montant dû", "donem": "Période", "vade": "Date d'échéance",
        "kod": "Votre code de paiement", "banka": "Banque", "iban": "IBAN",
        "talimat": "Indiquez uniquement votre code de paiement dans le libellé du virement : {kod}",
        "odediyseniz": "Si vous avez déjà payé, merci de ne pas tenir compte de ce message ; l'enregistrement peut prendre quelques jours.",
        "soru": "Pour toute question, vous pouvez contacter la gestion dans l'application Yönetiyor.",
        "tesekkur": "Merci.",
    },
    "es": {
        "konu": "{tesis} — recordatorio de cuota",
        "selam": "Hola {ad}:",
        "giris": "Según los registros de {tesis}, aún no consta el pago de la cuota que figura abajo. Le enviamos este amable recordatorio.",
        "tutar": "Importe pendiente", "donem": "Periodo", "vade": "Fecha de vencimiento",
        "kod": "Su código de pago", "banka": "Banco", "iban": "IBAN",
        "talimat": "Escriba solo su código de pago en el concepto de la transferencia: {kod}",
        "odediyseniz": "Si ya ha pagado, no tenga en cuenta este mensaje; el registro del pago puede tardar unos días.",
        "soru": "Si tiene alguna pregunta, puede contactar con la administración en la app Yönetiyor.",
        "tesekkur": "Gracias.",
    },
    "ar": {
        "konu": "{tesis} — تذكير بالرسوم",
        "selam": "مرحبًا {ad}،",
        "giris": "وفقًا لسجلات {tesis} لم يتم استلام دفعة الرسوم أدناه بعد. نود تذكيرك بلطف.",
        "tutar": "المبلغ المستحق", "donem": "الفترة", "vade": "تاريخ الاستحقاق",
        "kod": "رمز الدفع الخاص بك", "banka": "البنك", "iban": "IBAN",
        "talimat": "اكتب رمز الدفع فقط في وصف التحويل: {kod}",
        "odediyseniz": "إذا كنت قد دفعت بالفعل فتجاهل هذه الرسالة؛ قد يستغرق ظهور الدفعة في السجلات بضعة أيام.",
        "soru": "إذا كان لديك أي سؤال يمكنك التواصل مع الإدارة عبر تطبيق Yönetiyor.",
        "tesekkur": "شكرًا لك.",
    },
    "ru": {
        "konu": "{tesis} — напоминание о взносе",
        "selam": "Здравствуйте, {ad}!",
        "giris": "По данным {tesis}, указанный ниже взнос ещё не поступил. Напоминаем об этом.",
        "tutar": "Сумма к оплате", "donem": "Период", "vade": "Срок оплаты",
        "kod": "Ваш платёжный код", "banka": "Банк", "iban": "IBAN",
        "talimat": "В назначении платежа укажите только ваш платёжный код: {kod}",
        "odediyseniz": "Если вы уже оплатили, не обращайте внимания на это письмо: отражение платежа может занять несколько дней.",
        "soru": "Если у вас есть вопросы, свяжитесь с управлением в приложении Yönetiyor.",
        "tesekkur": "Спасибо.",
    },
}


def aidat_hatirlatma_eposta(
    *,
    dil: str | None,
    tesis_ad: str,
    ad: str,
    tutar: str,
    donemler: list[str],
    vade: str,
    odeme_kodu: str | None,
    banka_adi: str | None,
    iban: str | None,
    yil: int,
) -> tuple[str, str, str]:
    """(konu, düz metin, html). `tutar` ve `vade` çağıran tarafından
    biçimlenmiş metindir (push hatırlatmasıyla AYNI biçim)."""
    d = K.dil_coz(dil)
    m = _M[d]
    h = K.Hizalama(d)
    konu = m["konu"].format(tesis=tesis_ad)

    bilgi = [(m["tutar"], tutar), (m["donem"], ", ".join(donemler)), (m["vade"], vade)]
    if iban:
        if banka_adi:
            bilgi.append((m["banka"], banka_adi))
        bilgi.append((m["iban"], iban))

    govde = (
        K.paragraf(h, K.e(m["selam"].format(ad=ad)), kalin=True, boyut=16)
        + K.paragraf(h, K.e(m["giris"].format(tesis=tesis_ad)))
        + K.bilgi_tablosu(h, bilgi)
    )
    if odeme_kodu:
        govde += K.kod_cipi(m["kod"], odeme_kodu) + K.paragraf(
            h, K.e(m["talimat"].format(kod=odeme_kodu))
        )
    govde += (
        K.paragraf(h, K.e(m["odediyseniz"]), boyut=14)
        + K.paragraf(h, K.e(m["soru"]), boyut=14)
        + K.paragraf(h, K.e(m["tesekkur"]), boyut=14)
    )
    html_govde = K.kabuk(dil=d, konu=konu, govde_html=govde, yil=yil)

    satirlar = [m["selam"].format(ad=ad), "", m["giris"].format(tesis=tesis_ad), ""]
    satirlar += [f"{e}: {v}" for e, v in bilgi]
    if odeme_kodu:
        satirlar += ["", f"{m['kod']}: {odeme_kodu}", m["talimat"].format(kod=odeme_kodu)]
    satirlar += ["", m["odediyseniz"], m["soru"], "", m["tesekkur"], "", K.altbilgi_metni(d, yil)]
    return konu, "\n".join(satirlar), html_govde
