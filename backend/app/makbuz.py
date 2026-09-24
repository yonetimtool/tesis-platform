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


def adres_satiri(
    adres: str | None, ilce: str | None, il: str | None, posta_kodu: str | None
) -> str:
    """(P193 §4) Adres alanlarindan TEK SATIR — bos alanlar atlanir.

    Bicim: "Ornek Mah. 1. Sk. No:5, Kadikoy, 34710 Istanbul". Bos alan
    bos bir virgul ya da sarkan bir bosluk birakmaz; yarim girilmis bir
    adres, hic girilmemis gibi cirkin gorunmemeli.
    """
    ilce_il = " ".join(p for p in ((posta_kodu or "").strip(), (il or "").strip()) if p)
    parcalar = [
        (adres or "").strip(),
        (ilce or "").strip(),
        ilce_il,
    ]
    return ", ".join(p for p in parcalar if p)


def makbuz_pdf(
    *,
    site_ad: str,
    site_adres: str | None = None,
    belge_no: str,
    tarih: date,
    odeyen_ad: str,
    daire_no: str | None,
    tutar_kurus: int,
    aciklama: str | None,
    kalemler: list[tuple[str, int]],
    dipnot: str = "Bu makbuz banka ekstresiyle otomatik eşleştirmeden üretilmiştir.",
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
    # (P193 §4) ADRES VARSA yazilir. Yoksa SATIR HIC ACILMAZ: bos bir
    # satir birakmak, makbuzda "adres girilmemis" mesajini kullaniciya
    # degil sakine gostermek olurdu.
    if site_adres:
        c.setFont(normal, 9)
        c.drawString(kenar, y, site_adres[:120])
        y -= 7 * mm
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
    c.drawString(kenar, kenar, dipnot)
    c.showPage()
    c.save()
    return tampon.getvalue()


# --------------------------------------------------------------------------- #
#          (E2E 2026-09, FINANS-02) TAHSILAT MAKBUZU + BILDIRIM — TEK YOL      #
# --------------------------------------------------------------------------- #
#
# OLCULEN KUSUR: makbuz ve "odemeniz alindi" bildirimi YALNIZ banka
# eslesmesinde uretiliyordu. Vezne (`/finans/tahsilat`) ve aidat ucu
# (`/dues/payments`) makbuz URETMIYOR, sakine bildirim GITMIYORDU; mobil
# ekran ise "makbuz numarasi ve sakine giden bildirim sunucuda uretilir"
# diyordu. Sakinin `/me/makbuzlar` arsivi vezneden odediginde bostu.
#
# Artik uc tahsilat yolu da (vezne, aidat ucu, banka) bu iki yardimciyi
# cagirir. Makbuz YAN ISTIR: PDF/depo/e-posta/bildirim aksakligi
# tahsilati DUSURMEZ — para hareketi zaten yazildi.
VEZNE_DIPNOT = "Bu makbuz tahsilat kaydından otomatik üretilmiştir."


async def tahsilat_makbuzu(
    db,
    *,
    tenant_id,
    satirlar: list,
    user_id,
    unit_id,
    tarih: date,
    aciklama: str | None,
    dipnot: str = VEZNE_DIPNOT,
):
    """Tahsilat satirlari icin makbuz yaz + PDF + e-posta + bildirim.

    Makbuz belge numarasi ILK defter satirininkidir (makbuz o kaydi
    belgeler). Belge numarasi yoksa (virman gibi) makbuz yazilmaz.
    Doner: `Receipt` ya da None.
    """
    from sqlalchemy import select

    from .models import DuesAssessment, Receipt

    from .models import UnitResident

    gercek = [s for s in satirlar if getattr(s, "durum", "odendi") == "odendi"]
    if not gercek or not gercek[0].belge_no:
        return None
    if user_id is None and unit_id is not None:
        # Odeyen belirtilmediyse dairenin TEK aktif sakini odeyendir; birden
        # cok sakin varsa TAHMIN EDILMEZ (makbuz yine yazilir, bildirim
        # gitmez) — yanlis kisiye "odemeniz alindi" demek, dogru kisiyi
        # habersiz birakmaktan kotudur.
        sakinler = list(
            dict.fromkeys(
                (
                    await db.execute(
                        select(UnitResident.user_id).where(
                            UnitResident.unit_id == unit_id,
                            UnitResident.bitis.is_(None),
                        )
                    )
                ).scalars().all()
            )
        )
        if len(sakinler) == 1:
            user_id = sakinler[0]
    makbuz = Receipt(
        tenant_id=tenant_id,
        user_id=user_id,
        unit_id=unit_id,
        belge_no=gercek[0].belge_no,
        tutar_kurus=sum(int(s.tutar_kurus) for s in gercek),
    )
    try:
        async with db.begin_nested():
            db.add(makbuz)
            await db.flush()
    except Exception:  # noqa: BLE001 — makbuz YAN IS; tahsilat DUSMEZ
        return None
    kalemler: list[tuple[str, int]] = []
    for s in gercek:
        etiket = s.donem or "-"
        if s.assessment_id is not None:
            donem = (
                await db.execute(
                    select(DuesAssessment.donem).where(
                        DuesAssessment.id == s.assessment_id
                    )
                )
            ).scalar_one_or_none()
            etiket = donem or etiket
        kalemler.append((etiket, int(s.tutar_kurus)))
    await makbuz_yayinla(
        db, tenant_id=tenant_id, makbuz=makbuz, kalemler=kalemler,
        tarih=tarih, aciklama=aciklama, dipnot=dipnot,
    )
    return makbuz


async def makbuz_yayinla(
    db,
    *,
    tenant_id,
    makbuz,
    kalemler: list[tuple[str, int]],
    tarih: date,
    aciklama: str | None,
    dipnot: str,
) -> None:
    """Makbuz PDF'i uret + e-posta + sakine bildirim. HEPSI YAN IS."""
    import logging

    from sqlalchemy import select

    from . import storage
    from .models import AppUser, Tenant, Unit
    from .sakin_bildirimi import sakin_bildirimi_yaz
    from .scheduler.notify import dispatch_external

    logger = logging.getLogger(__name__)
    odeyen = None
    if makbuz.user_id is not None:
        odeyen = (
            await db.execute(select(AppUser).where(AppUser.id == makbuz.user_id))
        ).scalar_one_or_none()
    tesis = (
        await db.execute(select(Tenant).where(Tenant.id == tenant_id))
    ).scalar_one_or_none()
    site_ad = (tesis.ad if tesis else "") or ""
    # (P193 §4) Makbuz TESISIN belgesidir: adi kadar adresi de tasimali.
    site_adres = (
        adres_satiri(tesis.adres, tesis.ilce, tesis.il, tesis.posta_kodu)
        if tesis
        else ""
    )
    daire_no = None
    if makbuz.unit_id:
        daire_no = (
            await db.execute(select(Unit.no).where(Unit.id == makbuz.unit_id))
        ).scalar_one_or_none()
    try:
        pdf = makbuz_pdf(
            site_ad=site_ad,
            site_adres=site_adres,
            belge_no=makbuz.belge_no,
            tarih=tarih,
            odeyen_ad=(odeyen.ad if odeyen else "") or "",
            daire_no=daire_no,
            tutar_kurus=int(makbuz.tutar_kurus),
            aciklama=aciklama,
            kalemler=kalemler,
            dipnot=dipnot,
        )
        key = f"{tenant_id}/makbuz/{makbuz.id.hex}.pdf"
        storage.sunucudan_yukle(key, pdf, "application/pdf")
        makbuz.pdf_key = key
        await db.flush()
    except Exception:  # noqa: BLE001 — makbuz YAN IS; tahsilati dusurmez
        logger.warning("[makbuz] PDF uretilemedi (makbuz=%s)", makbuz.id)

    # (P192 §4.4) E-POSTA — push'un KALICI ikizi. YAN IS.
    if odeyen is not None and odeyen.email:
        try:
            from .eposta_sablonlari import makbuz_metni
            from .gonderim import saglayici as kanal_saglayicisi, tenant_ayari
            from .raporlar import kurus_metin

            baglanti = (
                storage.presign_get(makbuz.pdf_key) if makbuz.pdf_key else None
            )
            konu, govde = makbuz_metni(
                site_ad=site_ad,
                belge_no=makbuz.belge_no,
                tutar=kurus_metin(int(makbuz.tutar_kurus)),
                baglanti=baglanti,
            )
            ayar = await tenant_ayari(db, tenant_id)
            kanal_saglayicisi("eposta", ayar).gonder(odeyen.email, konu, govde)
        except Exception:  # noqa: BLE001 — e-posta YAN IS
            logger.warning("[makbuz] e-posta gonderilemedi (makbuz=%s)", makbuz.id)

    if makbuz.user_id:
        veri = {
            "donem": kalemler[0][0] if kalemler else "-",
            # (E2E 2026-09, BILDIRIM-14 ile ayni kural) Turkce para bicimi.
            "tutar": _tl(int(makbuz.tutar_kurus)),
        }
        try:
            dispatch_external(
                "aidat_odendi",
                tenant_id=tenant_id,
                target_user_ids=(makbuz.user_id,),
                params=veri,
                data={"tip": "aidat_odendi", "receipt_id": str(makbuz.id)},
            )
        except Exception:  # noqa: BLE001 — push YAN IS
            logger.warning("[makbuz] push kuyruga alinamadi (makbuz=%s)", makbuz.id)
        sakin_bildirimi_yaz(
            db, tenant_id=tenant_id, tip="aidat_odendi",
            user_ids=(makbuz.user_id,), veri=veri,
        )
