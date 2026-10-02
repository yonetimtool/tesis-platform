"""(P250) Kurumsal e-posta KABUGU — logolu başlık, kart, altbilgi.

P250'de üç yeni e-posta geldi: ödeme kodu (§2), hoş geldiniz (§3) ve aidat
hatırlatma (§7). Üçü de davet e-postasıyla (`davet_eposta.py`, P185) AYNI
görünmeli. Davet şablonu kendi yerleşimini satır satır yazıyor; üç kopya
daha üretmek, bir renk/altbilgi düzeltmesinin dört yerde unutulması
demekti. Kabuk burada; içerik çağıranda.

Kurallar `davet_eposta.py` ile aynı: TABLO tabanlı yerleşim, satır-içi
stil, MSO koşullu blok, koyu mod @media, saf fonksiyonlar (DB/ağ/saat
YOK — yıl dışarıdan gelir). Kullanıcıdan gelen HER metin `html.escape`
ile kaçırılır; çağıran yalnız bu modülün parça üreticilerini birleştirir.
"""
from __future__ import annotations

import html

from .config import settings

MARKA = "Yönetiyor"
DILLER: tuple[str, ...] = ("tr", "en", "ar", "ru", "de", "fr", "es")

_NAVY = "#102060"
_MAVI = "#2060A0"
_SAYFA_BG = "#f2f4f8"
_KART_BG = "#ffffff"
_METIN = "#1a2233"
_SOLUK = "#5a6472"
_CIP_BG = "#eef2fb"
_FONT = "font-family:Arial,Helvetica,sans-serif;"

#: Altbilgi — her dilde.
_ALTBILGI = {
    "tr": "Bu otomatik bir mesajdır; lütfen yanıtlamayın.",
    "en": "This is an automated message; please do not reply.",
    "de": "Dies ist eine automatische Nachricht; bitte nicht antworten.",
    "fr": "Ceci est un message automatique ; merci de ne pas y répondre.",
    "es": "Este es un mensaje automático; por favor, no responda.",
    "ar": "هذه رسالة تلقائية؛ يرجى عدم الرد عليها.",
    "ru": "Это автоматическое сообщение; пожалуйста, не отвечайте на него.",
}


def dil_coz(dil: str | None) -> str:
    return dil if dil in DILLER else "tr"


def logo_url() -> str | None:
    """Başlıktaki logo. Boşsa metin işareti çizilir (görsel engelli
    istemcide de marka okunur)."""
    return settings.eposta_logo_url or None


def e(metin: str) -> str:
    return html.escape(metin, quote=True)


class Hizalama:
    def __init__(self, dil: str) -> None:
        self.rtl = dil == "ar"
        self.yon = "right" if self.rtl else "left"


def paragraf(h: Hizalama, guvenli_html: str, *, kalin: bool = False, boyut: int = 15) -> str:
    """`guvenli_html`: ÇAĞIRAN kaçırmış olmalı (`e()`), ya da yalnız <b>."""
    agirlik = "font-weight:bold;" if kalin else ""
    return (
        f'<tr><td class="yn-text" align="{h.yon}" style="padding:6px 24px;{_FONT}'
        f'font-size:{boyut}px;line-height:1.6;color:{_METIN};{agirlik}">'
        f"{guvenli_html}</td></tr>"
    )


def kod_cipi(etiket: str, kod: str, ipucu: str | None = None) -> str:
    """Büyük, tek-aralıklı, SEÇİLEBİLİR kod çipi (ödeme kodu, tesis kodu)."""
    alt = (
        f'<tr><td align="center" class="yn-muted" style="padding:2px 24px 12px 24px;{_FONT}'
        f'font-size:13px;color:{_SOLUK};">{e(ipucu)}</td></tr>'
        if ipucu else ""
    )
    return (
        f'<tr><td align="center" class="yn-muted" style="padding:10px 24px 4px 24px;{_FONT}'
        f'font-size:13px;color:{_SOLUK};text-transform:uppercase;letter-spacing:1px;">'
        f"{e(etiket)}</td></tr>"
        f'<tr><td align="center" style="padding:4px 24px;">'
        f'<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:0 auto;"><tr>'
        f'<td class="yn-chip" bgcolor="{_CIP_BG}" style="background-color:{_CIP_BG};border-radius:8px;'
        f"padding:14px 24px;font-family:'Courier New',Courier,monospace;font-size:28px;"
        f'font-weight:bold;letter-spacing:3px;color:{_NAVY};"><span class="yn-code">{e(kod)}</span></td>'
        f"</tr></table></td></tr>{alt}"
    )


def bilgi_tablosu(h: Hizalama, satirlar: list[tuple[str, str]]) -> str:
    """Etiket/değer satırları (daire, IBAN, tutar...). Değerler kaçırılır."""
    if not satirlar:
        return ""
    ic = "".join(
        f'<tr><td class="yn-muted" align="{h.yon}" style="padding:6px 12px 6px 0;{_FONT}'
        f'font-size:13px;color:{_SOLUK};white-space:nowrap;vertical-align:top;">{e(etiket)}</td>'
        f'<td class="yn-text" align="{h.yon}" style="padding:6px 0;{_FONT}font-size:15px;'
        f'color:{_METIN};font-weight:bold;word-break:break-all;">{e(deger)}</td></tr>'
        for etiket, deger in satirlar
    )
    return (
        f'<tr><td style="padding:8px 24px;"><table role="presentation" width="100%" '
        f'cellpadding="0" cellspacing="0" border="0">{ic}</table></td></tr>'
    )


def madde_listesi(h: Hizalama, maddeler: list[str]) -> str:
    if not maddeler:
        return ""
    ic = "".join(
        f'<tr><td class="yn-text" align="{h.yon}" style="padding:3px 0;{_FONT}font-size:14px;'
        f'line-height:1.5;color:{_METIN};">&bull;&nbsp;{e(m)}</td></tr>'
        for m in maddeler
    )
    return (
        f'<tr><td style="padding:4px 24px 12px 24px;"><table role="presentation" width="100%" '
        f'cellpadding="0" cellspacing="0" border="0">{ic}</table></td></tr>'
    )


def _buton(url: str, etiket: str) -> str:
    return (
        f'<table role="presentation" cellpadding="0" cellspacing="0" border="0" '
        f'style="display:inline-block;margin:6px 4px;">'
        f'<tr><td bgcolor="{_MAVI}" style="border-radius:6px;background-color:{_MAVI};">'
        f'<a href="{e(url)}" target="_blank" style="display:inline-block;padding:12px 22px;{_FONT}'
        f'font-size:15px;font-weight:bold;color:#ffffff;text-decoration:none;border-radius:6px;">'
        f"{e(etiket)}</a></td></tr></table>"
    )


def magaza_butonlari() -> str:
    """Yalnız tanımlı mağaza URL'leri (boş URL'ye düğme ÇİZİLMEZ)."""
    b = ""
    if settings.play_store_url:
        b += _buton(settings.play_store_url, "Google Play")
    if settings.app_store_url:
        b += _buton(settings.app_store_url, "App Store")
    return f'<tr><td align="center" style="padding:8px 24px 16px 24px;">{b}</td></tr>' if b else ""


def kabuk(*, dil: str, konu: str, govde_html: str, yil: int) -> str:
    """Tam HTML belge. `govde_html` = bu modülün parçalarından <tr> satırları."""
    dil = dil_coz(dil)
    rtl = dil == "ar"
    dir_attr = ' dir="rtl"' if rtl else ""
    lu = logo_url()
    logo = (
        f'<img src="{e(lu)}" alt="{MARKA}" width="180" '
        f'style="display:block;border:0;max-width:180px;height:auto;" />'
        if lu else
        f'<span style="{_FONT}font-size:24px;font-weight:bold;color:#ffffff;'
        f'letter-spacing:0.5px;">{MARKA}</span>'
    )
    return f"""<!DOCTYPE html>
<html lang="{dil}"{dir_attr} xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<meta name="color-scheme" content="light dark" />
<meta name="supported-color-schemes" content="light dark" />
<title>{e(konu)}</title>
<!--[if mso]><style type="text/css">body, table, td, a {{ font-family: Arial, Helvetica, sans-serif !important; }}</style><![endif]-->
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
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">{e(konu)}</div>
<table role="presentation" class="yn-page" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="{_SAYFA_BG}" style="background-color:{_SAYFA_BG};">
<tr><td align="center" style="padding:24px 12px;">
<!--[if mso]><table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0"><tr><td><![endif]-->
<table role="presentation" class="yn-card" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="{_KART_BG}" style="max-width:600px;width:100%;background-color:{_KART_BG};border-radius:12px;overflow:hidden;">
  <tr><td align="center" bgcolor="{_NAVY}" style="background-color:{_NAVY};padding:24px;">{logo}</td></tr>
  <tr><td style="height:12px;line-height:12px;font-size:0;">&nbsp;</td></tr>
  {govde_html}
  <tr><td style="height:12px;line-height:12px;font-size:0;">&nbsp;</td></tr>
  <tr><td class="yn-muted" align="center" bgcolor="{_SAYFA_BG}" style="background-color:{_SAYFA_BG};padding:20px 24px;{_FONT}font-size:12px;line-height:1.6;color:{_SOLUK};">
    &copy; {yil} {MARKA}<br />{e(_ALTBILGI[dil])}
  </td></tr>
</table>
<!--[if mso]></td></tr></table><![endif]-->
</td></tr>
</table>
</body>
</html>"""


def altbilgi_metni(dil: str, yil: int) -> str:
    return f"© {yil} {MARKA}\n{_ALTBILGI[dil_coz(dil)]}"
