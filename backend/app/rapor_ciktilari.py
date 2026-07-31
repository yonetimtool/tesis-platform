"""Rapor CIKTILARI (P31) — Excel (xlsx) ve PDF uretimi.

UCU DE AYNI `RaporSonuc`TAN uretilir; tablo ciktisi zaten o nesnenin
kendisidir. Ayri ayri uretmek, ayni raporun uc yerde farkli rakam
gostermesine yol acardi.

KURUMSAL SABLON (PDF): site adi + aralik + zaman damgasi + sayfa altbilgisi
her sayfada. Logo OPSIYONELDIR ve YOKSA baslik metni kayar — logoyu zorunlu
kilmak, logo yuklememis bir siteye rapor urettirmemek olurdu.
"""
from __future__ import annotations

import io
from datetime import date, datetime, timezone

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font
from openpyxl.utils import get_column_letter
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas as pdf_canvas

from .raporlar import RaporSonuc, kurus_metin

#: PDF'te tek satira sigmayan sutun sayisi — ustunde YATAY sayfa kullanilir.
#: Dikey sayfada 9 sutun okunaksiz kucuk yaziya duser.
YATAY_ESIK = 6


def _damga() -> str:
    return datetime.now(timezone.utc).strftime("%d.%m.%Y %H:%M UTC")


def _aralik_metni(baslangic: date | None, bitis: date | None) -> str:
    if baslangic and bitis:
        return f"{baslangic.strftime('%d.%m.%Y')} – {bitis.strftime('%d.%m.%Y')}"
    if bitis:
        return f"… – {bitis.strftime('%d.%m.%Y')}"
    if baslangic:
        return f"{baslangic.strftime('%d.%m.%Y')} – …"
    return "Tüm zamanlar"


# ================================= EXCEL ==================================== #
def excel_uret(
    sonuc: RaporSonuc, site_ad: str, baslangic: date | None, bitis: date | None
) -> bytes:
    """XLSX uret — PARA HUCRELERI SAYIDIR, metin degil.

    Kurusu metin olarak yazmak, kullanicinin Excel'de toplam almasini
    engellerdi; rapor zaten Excel'e "uzerinde calisilsin" diye verilir.
    Hucre TL cinsinden `float` degil, KURUS/100 ondalikli sayidir ve
    bicimlendirme Excel'in kendi sayi bicimiyle yapilir.
    """
    wb = Workbook()
    ws = wb.active
    ws.title = sonuc.kod[:31] or "Rapor"

    ws.append([site_ad])
    ws["A1"].font = Font(bold=True, size=14)
    ws.append([sonuc.baslik])
    ws["A2"].font = Font(bold=True, size=12)
    ws.append([f"Dönem: {_aralik_metni(baslangic, bitis)}", f"Oluşturma: {_damga()}"])
    ws.append([])

    basliklar = [s.baslik for s in sonuc.sutunlar]
    ws.append(basliklar)
    for hucre in ws[ws.max_row]:
        hucre.font = Font(bold=True)
        hucre.alignment = Alignment(wrap_text=True, vertical="center")

    for satir in sonuc.satirlar:
        ws.append([_excel_deger(s, satir.get(s.anahtar)) for s in sonuc.sutunlar])

    if sonuc.toplamlar:
        ws.append([])
        toplam_satiri = []
        for i, s in enumerate(sonuc.sutunlar):
            if i == 0:
                toplam_satiri.append("TOPLAM")
            else:
                toplam_satiri.append(_excel_deger(s, sonuc.toplamlar.get(s.anahtar)))
        ws.append(toplam_satiri)
        for hucre in ws[ws.max_row]:
            hucre.font = Font(bold=True)

    # Para sutunlarina Turkce gruplama bicimi.
    for i, s in enumerate(sonuc.sutunlar, start=1):
        harf = get_column_letter(i)
        ws.column_dimensions[harf].width = max(12, min(len(s.baslik) + 4, 40))
        if s.tip == "kurus":
            for hucre in ws[harf]:
                if isinstance(hucre.value, (int, float)):
                    hucre.number_format = "#,##0.00"

    if sonuc.metin:
        ws.append([])
        ws.append([sonuc.metin])

    tampon = io.BytesIO()
    wb.save(tampon)
    return tampon.getvalue()


def _excel_deger(sutun, ham):
    if ham is None:
        return None
    if sutun.tip == "kurus":
        # SAYI olarak yaz (TL cinsinden) — kullanici toplam alabilsin.
        return int(ham) / 100
    if sutun.tip == "tarih" and isinstance(ham, date):
        return ham
    return ham


# ================================== PDF ===================================== #
def pdf_uret(
    sonuc: RaporSonuc,
    site_ad: str,
    baslangic: date | None,
    bitis: date | None,
    logo_png: bytes | None = None,
) -> bytes:
    """Kurumsal sablonlu PDF.

    Sablon: site adi (+ logo varsa) · rapor adi · donem · zaman damgasi ·
    her sayfada "Sayfa n / m" altbilgisi. Sayfa sayisi ONCEDEN bilinmedigi
    icin iki gecisli uretim yapilir — "n / ?" yazmak resmi bir cikti icin
    kabul edilebilir degil.
    """
    yatay = len(sonuc.sutunlar) > YATAY_ESIK
    sayfa = landscape(A4) if yatay else A4

    # 1. GECIS: sayfa sayisini ogren.
    toplam_sayfa = _ciz(sonuc, site_ad, baslangic, bitis, sayfa, logo_png, None)
    # 2. GECIS: altbilgide gercek sayiyi yaz.
    tampon = io.BytesIO()
    _ciz(sonuc, site_ad, baslangic, bitis, sayfa, logo_png, tampon, toplam_sayfa)
    return tampon.getvalue()


def _ciz(sonuc, site_ad, baslangic, bitis, sayfa, logo_png, tampon, toplam=None):
    hedef = tampon or io.BytesIO()
    c = pdf_canvas.Canvas(hedef, pagesize=sayfa)
    genislik, yukseklik = sayfa
    kenar = 15 * mm
    satir_yuksekligi = 6 * mm

    sutunlar = sonuc.sutunlar
    birim = (genislik - 2 * kenar) / max(sum(s.genislik for s in sutunlar), 1)
    xler = []
    x = kenar
    for s in sutunlar:
        xler.append(x)
        x += s.genislik * birim

    sayfa_no = 0

    def _baslik() -> float:
        nonlocal sayfa_no
        sayfa_no += 1
        y = yukseklik - kenar
        if logo_png:
            try:
                from reportlab.lib.utils import ImageReader

                c.drawImage(
                    ImageReader(io.BytesIO(logo_png)), kenar, y - 14 * mm,
                    width=18 * mm, height=14 * mm, mask="auto",
                )
                sol = kenar + 22 * mm
            except Exception:
                # Bozuk/desteklenmeyen logo raporu DUSURMEZ: logo sussuz bir
                # ayrintidir, rapor ise gerekli.
                sol = kenar
        else:
            sol = kenar
        c.setFont("Helvetica-Bold", 14)
        c.drawString(sol, y - 5 * mm, site_ad)
        c.setFont("Helvetica-Bold", 11)
        c.drawString(sol, y - 11 * mm, sonuc.baslik)
        c.setFont("Helvetica", 8)
        c.drawString(sol, y - 16 * mm, f"Dönem: {_aralik_metni(baslangic, bitis)}")
        c.drawRightString(genislik - kenar, y - 16 * mm, f"Oluşturma: {_damga()}")
        y -= 22 * mm
        c.setFont("Helvetica-Bold", 8)
        for s, sx in zip(sutunlar, xler):
            c.drawString(sx, y, s.baslik[:28])
        y -= 2 * mm
        c.line(kenar, y, genislik - kenar, y)
        return y - satir_yuksekligi

    def _altbilgi() -> None:
        c.setFont("Helvetica", 7)
        c.setFillColor(colors.grey)
        etiket = f"Sayfa {sayfa_no}" + (f" / {toplam}" if toplam else "")
        c.drawCentredString(genislik / 2, kenar / 2, etiket)
        c.setFillColor(colors.black)

    y = _baslik()
    c.setFont("Helvetica", 8)
    for satir in sonuc.satirlar:
        if y < kenar + 20 * mm:
            _altbilgi()
            c.showPage()
            y = _baslik()
            c.setFont("Helvetica", 8)
        for s, sx in zip(sutunlar, xler):
            ham = satir.get(s.anahtar)
            metin = (
                kurus_metin(ham) if s.tip == "kurus"
                else ("" if ham is None else str(ham))
            )
            if s.tip == "kurus":
                c.drawRightString(sx + s.genislik * birim - 3 * mm, y, metin)
            else:
                c.drawString(sx, y, metin[:40])
        y -= satir_yuksekligi

    if sonuc.toplamlar:
        y -= 2 * mm
        c.line(kenar, y + 4 * mm, genislik - kenar, y + 4 * mm)
        c.setFont("Helvetica-Bold", 8)
        for i, (s, sx) in enumerate(zip(sutunlar, xler)):
            if i == 0:
                c.drawString(sx, y, "TOPLAM")
            elif s.tip == "kurus":
                c.drawRightString(
                    sx + s.genislik * birim - 3 * mm, y,
                    kurus_metin(sonuc.toplamlar.get(s.anahtar)),
                )
        y -= satir_yuksekligi

    if sonuc.metin:
        c.setFont("Helvetica", 8)
        for parca in sonuc.metin.split("\n"):
            if y < kenar + 20 * mm:
                _altbilgi()
                c.showPage()
                y = _baslik()
                c.setFont("Helvetica", 8)
            c.drawString(kenar, y, parca[:160])
            y -= satir_yuksekligi

    _altbilgi()
    c.save()
    return sayfa_no


def metin_pdf(baslik: str, govde: str, site_ad: str) -> bytes:
    """Serbest metin PDF (ihtar yazisi, denetim raporu).

    Tablo sablonundan AYRI: ihtar bir yazidir, sutunlu bir liste degil;
    tablo sablonuna sikistirmak metni hucrelere bolerdi.
    """
    tampon = io.BytesIO()
    c = pdf_canvas.Canvas(tampon, pagesize=A4)
    genislik, yukseklik = A4
    kenar = 20 * mm
    stil = getSampleStyleSheet()["BodyText"]
    y = yukseklik - kenar
    c.setFont("Helvetica-Bold", 12)
    c.drawString(kenar, y, baslik)
    y -= 10 * mm
    c.setFont("Helvetica", 10)
    for parca in govde.split("\n"):
        if y < kenar + 15 * mm:
            c.showPage()
            y = yukseklik - kenar
            c.setFont("Helvetica", 10)
        # Uzun satirlari kir: PDF kendiliginden sarmaz ve metin sayfadan
        # tasip GORUNMEZ olurdu.
        while len(parca) > 95:
            kes = parca.rfind(" ", 0, 95)
            kes = kes if kes > 40 else 95
            c.drawString(kenar, y, parca[:kes])
            parca = parca[kes:].lstrip()
            y -= 5 * mm
        c.drawString(kenar, y, parca)
        y -= 5 * mm
    c.setFont("Helvetica", 7)
    c.setFillColor(colors.grey)
    c.drawCentredString(genislik / 2, kenar / 2, f"{site_ad} · {_damga()}")
    c.save()
    _ = stil  # stil sayfasi ileride zengin metin icin; simdilik duz cizim.
    return tampon.getvalue()
