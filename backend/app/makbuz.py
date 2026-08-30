"""(P191 §4) MAKBUZ PDF'i — tek sayfa, kurumsal, TÜRKÇE DOĞRU.

===========================================================================
YAZI TİPİ NEDEN ÖNEMLİ
===========================================================================
ReportLab'ın gömülü `Helvetica`sı WinAnsi kodlamasıdır ve `ş`, `ğ`, `İ`
harfleri O KÜMEDE YOKTUR: hata vermez, sessizce yanlış/boş glif çizer.
Makbuz resmi bir belgedir; sakinin adının "GÜLŞAH" yerine "GLAH" çıkması
kabul edilebilir değil. Bu yüzden imajda bulunan DejaVuSans TTF'i kayıt
edilir; dosya yoksa Helvetica'ya DÜŞÜLÜR (belge yine üretilir — makbuzu
hiç üretmemek, yazı tipi yüzünden tahsilatı belgesiz bırakmak olurdu).
"""
from __future__ import annotations

import io
import os
from datetime import date

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas as pdf_canvas

_TTF = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
_TTF_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
_KAYITLI: bool | None = None


def _fontlar() -> tuple[str, str]:
    """(normal, kalın) font adları — TTF varsa DejaVu, yoksa Helvetica."""
    global _KAYITLI
    if _KAYITLI is None:
        try:
            if os.path.exists(_TTF):
                pdfmetrics.registerFont(TTFont("Yonetio", _TTF))
                pdfmetrics.registerFont(TTFont("Yonetio-Bold", _TTF_BOLD if os.path.exists(_TTF_BOLD) else _TTF))
                _KAYITLI = True
            else:
                _KAYITLI = False
        except Exception:  # noqa: BLE001 — yazi tipi makbuzu DUSURMEZ
            _KAYITLI = False
    return ("Yonetio", "Yonetio-Bold") if _KAYITLI else ("Helvetica", "Helvetica-Bold")


def _tl(kurus: int) -> str:
    """Kuruş -> `1.234,56 ₺` (Türkçe biçim: binlik nokta, ondalık virgül)."""
    tam, kalan = divmod(int(kurus), 100)
    return f"{tam:,}".replace(",", ".") + f",{kalan:02d} ₺"


def makbuz_pdf(
    *,
    site_ad: str,
    belge_no: str,
    tarih: date,
    odeyen_ad: str,
    daire_no: str | None,
    tutar_kurus: int,
    aciklama: str | None,
    kalemler: list[tuple[str, int]],
) -> bytes:
    """Tek sayfalık tahsilat makbuzu.

    `kalemler`: (dönem/açıklama, tutar) — bir transfer üç ayı kapattıysa
    üçü de görünür. Makbuzun işi "ne kadar aldık" değil "NEYİ kapattık"
    sorusunu da cevaplamaktır; aksi halde sakin hangi ayın kapandığını
    yönetime sormak zorunda kalır.
    """
    normal, kalin = _fontlar()
    tampon = io.BytesIO()
    c = pdf_canvas.Canvas(tampon, pagesize=A4)
    genislik, yukseklik = A4
    kenar = 20 * mm
    y = yukseklik - kenar

    c.setFont(kalin, 16)
    c.drawString(kenar, y, site_ad)
    y -= 8 * mm
    c.setFont(kalin, 13)
    c.drawString(kenar, y, "TAHSİLAT MAKBUZU")
    c.setFont(normal, 10)
    c.drawRightString(genislik - kenar, y, f"Belge No: {belge_no}")
    y -= 6 * mm
    c.drawRightString(genislik - kenar, y, f"Tarih: {tarih.strftime('%d.%m.%Y')}")
    y -= 10 * mm
    c.line(kenar, y, genislik - kenar, y)
    y -= 10 * mm

    c.setFont(normal, 11)
    for etiket, deger in (
        ("Ödeyen", odeyen_ad),
        ("Daire", daire_no or "—"),
        ("Açıklama", (aciklama or "—")[:80]),
    ):
        c.setFont(kalin, 11)
        c.drawString(kenar, y, f"{etiket}:")
        c.setFont(normal, 11)
        c.drawString(kenar + 30 * mm, y, str(deger))
        y -= 7 * mm

    y -= 5 * mm
    c.setFont(kalin, 11)
    c.drawString(kenar, y, "Kapatılan borçlar")
    c.drawRightString(genislik - kenar, y, "Tutar")
    y -= 4 * mm
    c.line(kenar, y, genislik - kenar, y)
    y -= 7 * mm
    c.setFont(normal, 11)
    for etiket, tutar in kalemler:
        c.drawString(kenar, y, etiket)
        c.drawRightString(genislik - kenar, y, _tl(tutar))
        y -= 6 * mm
        if y < kenar + 40 * mm:  # tek sayfa yeter; taşarsa kalanı özetle
            c.drawString(kenar, y, "…")
            y -= 6 * mm
            break

    y -= 4 * mm
    c.line(kenar, y, genislik - kenar, y)
    y -= 8 * mm
    c.setFont(kalin, 12)
    c.drawString(kenar, y, "TOPLAM")
    c.drawRightString(genislik - kenar, y, _tl(tutar_kurus))

    c.setFont(normal, 8)
    c.drawString(
        kenar,
        kenar,
        "Bu makbuz banka ekstresiyle otomatik eşleştirmeden üretilmiştir.",
    )
    c.showPage()
    c.save()
    return tampon.getvalue()
