"""(P185) Tenant-davet ("davet") e-postası — 7 dilde HTML + düz metin çift.

Mevcut `eposta_sablonlari.py` üslubunu izler: modül docstring, Türkçe yorumlar
serbest (i18n sızıntı dedektörleri YALNIZ admin-web JSX + Flutter'a bakar,
backend'e DEĞİL), `from __future__ import annotations`, saf fonksiyonlar,
yan etki YOK, DB/ağ YOK, `datetime` çağrısı YOK (yıl dışarıdan gelir).

`davet.py::davet_mesaji` (tek satır düz metin) yerine geçen ZENGİN içeriği
üretir; wiring başka biri tarafından yapılacak — burada yalnız builder var.

E-posta istemci sağlamlığı: TABLO tabanlı yerleşim, satır-içi stil, MSO
koşullu blok, koyu mod @media + bgcolor öznitelikleri (Outlook). Web-panel
(app.yonetiyor.com) bağlantısı HİÇBİR YERDE yok — tek bağlantılar: davet bağı,
iki mağaza URL'si ve isteğe bağlı logo görseli.
"""
from __future__ import annotations

import html

MARKA = "Yönetiyor"

#: Desteklenen davet dilleri; bilinmeyen/None -> "tr".
DAVET_DILLERI: tuple[str, ...] = ("tr", "en", "ar", "ru", "de", "fr", "es")

#: Marka renkleri (kart + başlık + vurgu).
_NAVY = "#102060"      # birincil / başlık arka planı
_MAVI = "#2060A0"      # vurgu / bağlantı / buton
_SAYFA_BG = "#f2f4f8"  # açık nötr sayfa arka planı
_KART_BG = "#ffffff"   # beyaz kart
_METIN = "#1a2233"     # ana metin
_SOLUK = "#5a6472"     # ikincil metin
_CIP_BG = "#eef2fb"    # tesis kodu çipi arka planı


#: dil -> tüm metin parçaları. Marka sözcüğü "Yönetiyor" çevrilmez.
_METINLER: dict[str, dict[str, str]] = {
    "tr": {
        "konu": "{tenant} — tesis erişim bilgileriniz",
        "selam": "Merhaba,",
        "paragraf": (
            "<b>{tenant}</b> sizi Yönetiyor tesis yönetim hesabına ekledi. "
            "Başlamak için mobil uygulamayı indirin ve <b>bu e-posta adresiyle</b> "
            "kayıt olun."
        ),
        "kod_etiket": "Tesis Kimliği",
        "kod_ipucu": "Kayıt sırasında bu kodu gireceksiniz.",
        "davet_buton": "Daveti Aç",
        "adimlar_baslik": "Nasıl başlarım?",
        "adim1": "Mobil uygulamayı indirin.",
        "adim2": "Uygulamayı açın.",
        "adim3": "\"Kayıt ol\" adımını seçin ve bu e-posta ile devam edin.",
        "adim4": "Tesis Kimliğini girin ve e-postanızı doğrulayın.",
        "footer_oto": "Bu otomatik bir mesajdır; lütfen yanıtlamayın.",
        "t_selam": "Merhaba,",
        "t_ekleme": "{tenant} sizi Yönetiyor tesis yönetim hesabına ekledi.",
        "t_bu_eposta": "Bu e-posta adresiyle kayıt olun.",
        "t_kod": "Tesis Kimliği",
        "t_davet": "Davet bağlantısı",
        "t_android": "Android",
        "t_ios": "iOS",
        "t_adimlar": "Adımlar: Uygulamayı indirin, açın, \"Kayıt ol\" seçin, "
                     "kodu girin ve e-postanızı doğrulayın.",
    },
    "en": {
        "konu": "{tenant} — your facility access details",
        "selam": "Hello,",
        "paragraf": (
            "<b>{tenant}</b> has added you to their Yönetiyor facility "
            "management account. To get started, download the mobile app and "
            "register with <b>this email address</b>."
        ),
        "kod_etiket": "Facility ID",
        "kod_ipucu": "You will enter this code during registration.",
        "davet_buton": "Open Invitation",
        "adimlar_baslik": "How to get started",
        "adim1": "Download the mobile app.",
        "adim2": "Open the app.",
        "adim3": "Choose \"Register\" and continue with this email.",
        "adim4": "Enter the Facility ID and verify your email.",
        "footer_oto": "This is an automated message; please do not reply.",
        "t_selam": "Hello,",
        "t_ekleme": "{tenant} has added you to their Yönetiyor facility "
                    "management account.",
        "t_bu_eposta": "Register with this email address.",
        "t_kod": "Facility ID",
        "t_davet": "Invitation link",
        "t_android": "Android",
        "t_ios": "iOS",
        "t_adimlar": "Steps: download the app, open it, choose \"Register\", "
                     "enter the code and verify your email.",
    },
    "ar": {
        "konu": "{tenant} — تفاصيل الوصول إلى المنشأة",
        "selam": "مرحباً،",
        "paragraf": (
            "أضافك <b>{tenant}</b> إلى حساب إدارة المنشأة على Yönetiyor. "
            "للبدء، نزّل تطبيق الجوال وسجّل باستخدام <b>عنوان البريد الإلكتروني هذا</b>."
        ),
        "kod_etiket": "معرّف المنشأة",
        "kod_ipucu": "ستُدخل هذا الرمز أثناء التسجيل.",
        "davet_buton": "فتح الدعوة",
        "adimlar_baslik": "كيف تبدأ",
        "adim1": "نزّل تطبيق الجوال.",
        "adim2": "افتح التطبيق.",
        "adim3": "اختر \"تسجيل\" وتابع باستخدام هذا البريد الإلكتروني.",
        "adim4": "أدخل معرّف المنشأة وتحقق من بريدك الإلكتروني.",
        "footer_oto": "هذه رسالة آلية؛ يُرجى عدم الرد.",
        "t_selam": "مرحباً،",
        "t_ekleme": "أضافك {tenant} إلى حساب إدارة المنشأة على Yönetiyor.",
        "t_bu_eposta": "سجّل باستخدام عنوان البريد الإلكتروني هذا.",
        "t_kod": "معرّف المنشأة",
        "t_davet": "رابط الدعوة",
        "t_android": "أندرويد",
        "t_ios": "iOS",
        "t_adimlar": "الخطوات: نزّل التطبيق، افتحه، اختر \"تسجيل\"، "
                     "أدخل الرمز وتحقق من بريدك الإلكتروني.",
    },
    "ru": {
        "konu": "{tenant} — данные доступа к объекту",
        "selam": "Здравствуйте,",
        "paragraf": (
            "<b>{tenant}</b> добавил вас в свою учётную запись управления "
            "объектом в Yönetiyor. Чтобы начать, скачайте мобильное приложение "
            "и зарегистрируйтесь с <b>этим адресом электронной почты</b>."
        ),
        "kod_etiket": "Идентификатор объекта",
        "kod_ipucu": "Вы введёте этот код при регистрации.",
        "davet_buton": "Открыть приглашение",
        "adimlar_baslik": "Как начать",
        "adim1": "Скачайте мобильное приложение.",
        "adim2": "Откройте приложение.",
        "adim3": "Выберите «Регистрация» и продолжите с этим адресом почты.",
        "adim4": "Введите идентификатор объекта и подтвердите почту.",
        "footer_oto": "Это автоматическое сообщение; пожалуйста, не отвечайте.",
        "t_selam": "Здравствуйте,",
        "t_ekleme": "{tenant} добавил вас в свою учётную запись управления "
                    "объектом в Yönetiyor.",
        "t_bu_eposta": "Зарегистрируйтесь с этим адресом электронной почты.",
        "t_kod": "Идентификатор объекта",
        "t_davet": "Ссылка на приглашение",
        "t_android": "Android",
        "t_ios": "iOS",
        "t_adimlar": "Шаги: скачайте приложение, откройте его, выберите "
                     "«Регистрация», введите код и подтвердите почту.",
    },
    "de": {
        "konu": "{tenant} — Ihre Zugangsdaten für die Anlage",
        "selam": "Hallo,",
        "paragraf": (
            "<b>{tenant}</b> hat Sie zu seinem Yönetiyor-Konto für die "
            "Objektverwaltung hinzugefügt. Laden Sie zum Starten die mobile App "
            "herunter und registrieren Sie sich mit <b>dieser E-Mail-Adresse</b>."
        ),
        "kod_etiket": "Objekt-ID",
        "kod_ipucu": "Diesen Code geben Sie bei der Registrierung ein.",
        "davet_buton": "Einladung öffnen",
        "adimlar_baslik": "So starten Sie",
        "adim1": "Laden Sie die mobile App herunter.",
        "adim2": "Öffnen Sie die App.",
        "adim3": "Wählen Sie \"Registrieren\" und fahren Sie mit dieser E-Mail fort.",
        "adim4": "Geben Sie die Objekt-ID ein und bestätigen Sie Ihre E-Mail.",
        "footer_oto": "Dies ist eine automatische Nachricht; bitte nicht antworten.",
        "t_selam": "Hallo,",
        "t_ekleme": "{tenant} hat Sie zu seinem Yönetiyor-Konto für die "
                    "Objektverwaltung hinzugefügt.",
        "t_bu_eposta": "Registrieren Sie sich mit dieser E-Mail-Adresse.",
        "t_kod": "Objekt-ID",
        "t_davet": "Einladungslink",
        "t_android": "Android",
        "t_ios": "iOS",
        "t_adimlar": "Schritte: App herunterladen, öffnen, \"Registrieren\" "
                     "wählen, Code eingeben und E-Mail bestätigen.",
    },
    "fr": {
        "konu": "{tenant} — vos identifiants d'accès à l'établissement",
        "selam": "Bonjour,",
        "paragraf": (
            "<b>{tenant}</b> vous a ajouté à son compte de gestion "
            "d'établissement Yönetiyor. Pour commencer, téléchargez "
            "l'application mobile et inscrivez-vous avec <b>cette adresse e-mail</b>."
        ),
        "kod_etiket": "Identifiant de l'établissement",
        "kod_ipucu": "Vous saisirez ce code lors de l'inscription.",
        "davet_buton": "Ouvrir l'invitation",
        "adimlar_baslik": "Comment commencer",
        "adim1": "Téléchargez l'application mobile.",
        "adim2": "Ouvrez l'application.",
        "adim3": "Choisissez « S'inscrire » et continuez avec cet e-mail.",
        "adim4": "Saisissez l'identifiant et vérifiez votre e-mail.",
        "footer_oto": "Ceci est un message automatique ; merci de ne pas répondre.",
        "t_selam": "Bonjour,",
        "t_ekleme": "{tenant} vous a ajouté à son compte de gestion "
                    "d'établissement Yönetiyor.",
        "t_bu_eposta": "Inscrivez-vous avec cette adresse e-mail.",
        "t_kod": "Identifiant de l'établissement",
        "t_davet": "Lien d'invitation",
        "t_android": "Android",
        "t_ios": "iOS",
        "t_adimlar": "Étapes : téléchargez l'application, ouvrez-la, choisissez "
                     "« S'inscrire », saisissez le code et vérifiez votre e-mail.",
    },
    "es": {
        "konu": "{tenant} — sus datos de acceso a la instalación",
        "selam": "Hola,",
        "paragraf": (
            "<b>{tenant}</b> te ha añadido a su cuenta de gestión de "
            "instalaciones de Yönetiyor. Para empezar, descarga la aplicación "
            "móvil y regístrate con <b>esta dirección de correo</b>."
        ),
        "kod_etiket": "ID de la instalación",
        "kod_ipucu": "Introducirás este código durante el registro.",
        "davet_buton": "Abrir invitación",
        "adimlar_baslik": "Cómo empezar",
        "adim1": "Descarga la aplicación móvil.",
        "adim2": "Abre la aplicación.",
        "adim3": "Elige \"Registrarse\" y continúa con este correo.",
        "adim4": "Introduce el ID de la instalación y verifica tu correo.",
        "footer_oto": "Este es un mensaje automático; por favor no respondas.",
        "t_selam": "Hola,",
        "t_ekleme": "{tenant} te ha añadido a su cuenta de gestión de "
                    "instalaciones de Yönetiyor.",
        "t_bu_eposta": "Regístrate con esta dirección de correo.",
        "t_kod": "ID de la instalación",
        "t_davet": "Enlace de invitación",
        "t_android": "Android",
        "t_ios": "iOS",
        "t_adimlar": "Pasos: descarga la aplicación, ábrela, elige "
                     "\"Registrarse\", introduce el código y verifica tu correo.",
    },
}


def _magaza_buton(url: str, etiket: str) -> str:
    """Metin-tabanlı mağaza butonu (bordürlü tablo hücresi + bgcolor).

    Görsel referansı YOK (logo dışında dış görsel yasak); metin bloklansa bile
    okunur kalsın diye net METİN taşır ("Google Play" / "App Store").
    """
    u = html.escape(url, quote=True)
    e = html.escape(etiket)
    return (
        f'<table role="presentation" cellpadding="0" cellspacing="0" border="0" '
        f'style="display:inline-block;margin:6px 4px;">'
        f'<tr><td bgcolor="{_MAVI}" style="border-radius:6px;background-color:{_MAVI};">'
        f'<a href="{u}" target="_blank" '
        f'style="display:inline-block;padding:12px 22px;font-family:Arial,Helvetica,sans-serif;'
        f'font-size:15px;font-weight:bold;color:#ffffff;text-decoration:none;'
        f'border-radius:6px;">{e}</a>'
        f'</td></tr></table>'
    )


def davet_eposta(
    *,
    dil: str,
    tenant_ad: str,
    tesis_kodu: str | None,
    bag: str,
    play_store_url: str | None,
    app_store_url: str | None,
    yil: int,
    logo_url: str | None = None,
) -> tuple[str, str, str]:
    """(konu, metin_govde, html_govde) davet e-postası döndürür.

    - dil: DAVET_DILLERI'nden biri; bilinmeyen/None -> "tr".
    - tenant_ad: tesis adı (selam/konuya girer).
    - tesis_kodu: Tesis Kimliği (kayıt kodu); None ise bloğu atlanır.
    - bag: tek-kullanımlık davet URL'si (https://yönetiyor.com/davet/<jeton>).
    - play_store_url / app_store_url: mağaza bağları; boş/None ise o buton
      HİÇ oluşturulmaz (kırık/boş bağlantı YOK).
    - yil: telif yılı (çağıran verir; burada datetime çağrılmaz — saf kalır).
    - logo_url: markanın mutlak logo URL'si; None ise <img> yerine "Yönetiyor"
      metin işareti gösterilir.
    """
    m = _METINLER.get(dil if dil in _METINLER else "tr")
    if m is None:  # tr her zaman var; savunma amaçlı
        m = _METINLER["tr"]
    rtl = dil == "ar"
    lang_attr = dil if dil in _METINLER else "tr"

    tenant_e = html.escape(tenant_ad)
    bag_e = html.escape(bag, quote=True)
    kod_e = html.escape(tesis_kodu) if tesis_kodu else None

    konu = m["konu"].format(tenant=tenant_ad)

    # ---- HTML ----
    dir_attr = ' dir="rtl"' if rtl else ""
    text_align = "right" if rtl else "left"

    if logo_url:
        logo_html = (
            f'<img src="{html.escape(logo_url, quote=True)}" alt="{MARKA}" '
            f'width="150" style="display:block;border:0;max-width:150px;height:auto;" />'
        )
    else:
        logo_html = (
            f'<span style="font-family:Arial,Helvetica,sans-serif;font-size:24px;'
            f'font-weight:bold;color:#ffffff;letter-spacing:0.5px;">{MARKA}</span>'
        )

    # Tesis Kimliği çipi — büyük, tek-aralıklı, SEÇİLEBİLİR (seçimi engelleyen
    # sarmalayıcı yok). None ise blok tümüyle atlanır.
    if kod_e:
        kod_blok = (
            f'<tr><td align="center" style="padding:8px 24px 4px 24px;">'
            f'<div style="font-family:Arial,Helvetica,sans-serif;font-size:13px;'
            f'color:{_SOLUK};text-transform:uppercase;letter-spacing:1px;">'
            f'{html.escape(m["kod_etiket"])}</div></td></tr>'
            f'<tr><td align="center" style="padding:4px 24px 4px 24px;">'
            f'<table role="presentation" cellpadding="0" cellspacing="0" border="0" '
            f'style="margin:0 auto;"><tr>'
            f'<td bgcolor="{_CIP_BG}" style="background-color:{_CIP_BG};'
            f'border-radius:8px;padding:14px 24px;'
            f'font-family:\'Courier New\',Courier,monospace;font-size:30px;'
            f'font-weight:bold;letter-spacing:4px;color:{_NAVY};">{kod_e}</td>'
            f'</tr></table></td></tr>'
            f'<tr><td align="center" style="padding:2px 24px 12px 24px;'
            f'font-family:Arial,Helvetica,sans-serif;font-size:13px;color:{_SOLUK};">'
            f'{html.escape(m["kod_ipucu"])}</td></tr>'
        )
    else:
        kod_blok = ""

    # Mağaza butonları — yalnız verilen URL'ler.
    butonlar = ""
    if play_store_url:
        butonlar += _magaza_buton(play_store_url, "Google Play")
    if app_store_url:
        butonlar += _magaza_buton(app_store_url, "App Store")
    if butonlar:
        butonlar = (
            f'<tr><td align="center" style="padding:8px 24px 16px 24px;">'
            f'{butonlar}</td></tr>'
        )

    adimlar = "".join(
        f'<tr><td style="padding:2px 0;font-family:Arial,Helvetica,sans-serif;'
        f'font-size:14px;line-height:1.5;color:{_METIN};" align="{text_align}">'
        f'{i}. {html.escape(m[f"adim{i}"])}</td></tr>'
        for i in (1, 2, 3, 4)
    )

    html_govde = f"""<!DOCTYPE html>
<html lang="{lang_attr}"{dir_attr} xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<meta http-equiv="X-UA-Compatible" content="IE=edge" />
<meta name="color-scheme" content="light dark" />
<meta name="supported-color-schemes" content="light dark" />
<title>{html.escape(konu)}</title>
<!--[if mso]>
<style type="text/css">
  body, table, td, a {{ font-family: Arial, Helvetica, sans-serif !important; }}
</style>
<![endif]-->
<style type="text/css">
  body {{ margin:0; padding:0; background-color:{_SAYFA_BG}; }}
  a {{ color:{_MAVI}; }}
  @media (prefers-color-scheme: dark) {{
    body, .yn-page {{ background-color:#0b1020 !important; }}
    .yn-card {{ background-color:#151b2e !important; }}
    .yn-text {{ color:#e6e9f2 !important; }}
    .yn-muted {{ color:#a8b0c2 !important; }}
    .yn-chip {{ background-color:#1e263f !important; }}
    .yn-code {{ color:#9db8ff !important; }}
  }}
</style>
</head>
<body style="margin:0;padding:0;background-color:{_SAYFA_BG};">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">{html.escape(konu)}</div>
<table role="presentation" class="yn-page" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="{_SAYFA_BG}" style="background-color:{_SAYFA_BG};">
<tr><td align="center" style="padding:24px 12px;">
<!--[if mso]>
<table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0"><tr><td>
<![endif]-->
<table role="presentation" class="yn-card" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="{_KART_BG}" style="max-width:600px;width:100%;background-color:{_KART_BG};border-radius:12px;overflow:hidden;">
  <tr>
    <td align="center" bgcolor="{_NAVY}" style="background-color:{_NAVY};padding:28px 24px;">
      {logo_html}
    </td>
  </tr>
  <tr>
    <td class="yn-text" align="{text_align}" style="padding:24px 24px 8px 24px;font-family:Arial,Helvetica,sans-serif;font-size:16px;font-weight:bold;color:{_METIN};">
      {html.escape(m["selam"])}
    </td>
  </tr>
  <tr>
    <td class="yn-text" align="{text_align}" style="padding:4px 24px 16px 24px;font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.6;color:{_METIN};">
      {m["paragraf"].format(tenant=tenant_e)}
    </td>
  </tr>
  {kod_blok}
  <tr>
    <td align="center" style="padding:8px 24px 8px 24px;">
      <!--[if mso]>
      <v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" xmlns:w="urn:schemas-microsoft-com:office:word" href="{bag_e}" style="height:44px;v-text-anchor:middle;width:220px;" arcsize="14%" strokecolor="{_NAVY}" fillcolor="{_NAVY}">
      <w:anchorlock/><center style="color:#ffffff;font-family:Arial,sans-serif;font-size:16px;font-weight:bold;">{html.escape(m["davet_buton"])}</center>
      </v:roundrect>
      <![endif]-->
      <!--[if !mso]><!-- -->
      <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:0 auto;">
        <tr><td bgcolor="{_NAVY}" style="border-radius:8px;background-color:{_NAVY};">
          <a href="{bag_e}" target="_blank" style="display:inline-block;padding:14px 32px;font-family:Arial,Helvetica,sans-serif;font-size:16px;font-weight:bold;color:#ffffff;text-decoration:none;border-radius:8px;">{html.escape(m["davet_buton"])}</a>
        </td></tr>
      </table>
      <!--<![endif]-->
    </td>
  </tr>
  <tr>
    <td class="yn-text" align="{text_align}" style="padding:16px 24px 4px 24px;font-family:Arial,Helvetica,sans-serif;font-size:15px;font-weight:bold;color:{_METIN};">
      {html.escape(m["adimlar_baslik"])}
    </td>
  </tr>
  <tr><td style="padding:0 24px 12px 24px;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="yn-text">{adimlar}</table>
  </td></tr>
  {butonlar}
  <tr>
    <td class="yn-muted" align="center" bgcolor="{_SAYFA_BG}" style="background-color:{_SAYFA_BG};padding:20px 24px;font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:1.6;color:{_SOLUK};">
      &copy; {yil} {MARKA}<br />
      {html.escape(m["footer_oto"])}
    </td>
  </tr>
</table>
<!--[if mso]>
</td></tr></table>
<![endif]-->
</td></tr>
</table>
</body>
</html>"""

    # ---- Düz metin ----
    t_satirlar: list[str] = []
    t_satirlar.append(m["t_selam"])
    t_satirlar.append("")
    t_satirlar.append(m["t_ekleme"].format(tenant=tenant_ad))
    t_satirlar.append(m["t_bu_eposta"])
    t_satirlar.append("")
    if tesis_kodu:
        t_satirlar.append(f"{m['t_kod']}: {tesis_kodu}")
        t_satirlar.append("")
    t_satirlar.append(f"{m['t_davet']}: {bag}")
    if play_store_url:
        t_satirlar.append(f"{m['t_android']}: {play_store_url}")
    if app_store_url:
        t_satirlar.append(f"{m['t_ios']}: {app_store_url}")
    t_satirlar.append("")
    t_satirlar.append(m["t_adimlar"])
    t_satirlar.append("")
    t_satirlar.append(f"© {yil} {MARKA}")
    t_satirlar.append(m["footer_oto"])
    metin_govde = "\n".join(t_satirlar)

    return konu, metin_govde, html_govde
