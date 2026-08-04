"""Rapor MOTORU + KATALOG (P31) — `/raporlar/...`.

TEK UC, UC BICIM: `POST /raporlar/{kod}?bicim=tablo|excel|pdf`. Bicim basina
ayri uc acmak, ayni parametre modelini uc kez dogrulamak ve uc yerde
degistirmek demekti.

PARAMETRE MODALI TEK MODEL (`RaporParametre`): her rapor bu kumenin bir alt
kumesini kullanir. Rapor basina ayri model, modal bileseninin her rapor icin
yeniden yazilmasi olurdu.

RBAC: admin + yonetici. Raporlar site finansini ve kisi adlarini tasir;
saha ve sakin ERISEMEZ. (`ismi_goster=false` KVKK icin ayrica vardir:
kapiya asilacak listede ad OLMAMALI.)
"""
from __future__ import annotations

import uuid
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, literal_column, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..borclandirma import gecikme_kurus
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import (
    AppUser,
    DuesAssessment,
    FinansalHareket,
    GelirGiderTanim,
    IcraDosyasi,
    Kasa,
    Tenant,
    Unit,
    UnitResident,
)
from ..rapor_ciktilari import excel_uret, metin_pdf, pdf_uret
from ..raporlar import (
    RaporParam,
    RaporSonuc,
    Sutun,
    borc_alacak_satirlari,
    detayli_borc_satirlari,
    ihtar_metni,
    kurus_metin,
    sirala,
    tahsilat_performansi,
)
from ..schemas import RaporKatalogOgesi, RaporKatalogResponse, RaporParametre, RaporTablo

router = APIRouter(tags=["raporlar"])

_YONETIM = require_role("admin", "yonetici")
# (P128) RAPOR URETIMI BIR OKUMADIR — HTTP fiili POST olsa da.
# `POST /raporlar/{kod}` hicbir satir yazmaz (dosyada tek bir `db.add`
# yoktur); POST secilmesinin sebebi rapor PARAMETRELERININ bir govde
# istemesidir. Denetciyi bu ucun disinda birakmak, ona gorevinin ana
# aracini (katalogdaki "Denetci bicimi" raporu dahil) kapatmak olurdu.
# Kural "fiil GET olsun" degil "MUTASYON olmasin"dir.
_RAPOR_OKUR = require_role("admin", "yonetici", "denetci")

#: Donem anahtari (YYYY-MM). `func.to_char` BIND PARAMETRESI uretir ve
#: Postgres GROUP BY'daki ifadeyle eslestiremez; `literal_column` ifadeyi
#: oldugu gibi gomer (repo genelinde bilinen tuzak).
_DONEM_IFADESI = literal_column("to_char(finansal_hareket.tarih, 'YYYY-MM')")

#: Katalog — kod -> (baslik, aciklama). Tek dogruluk kaynagi: hem `/katalog`
#: ucu hem yonlendirme buradan okur, yani listede gorunup calismayan bir
#: rapor OLAMAZ.
KATALOG: dict[str, tuple[str, str]] = {
    "borc_alacak": ("Borç-Alacak Listesi",
                    "Dönem başı / dönem içi hareket / bakiye"),
    "detayli_borc": ("Detaylı Borç Listesi",
                     "Gider kalemi başına DİNAMİK sütunlar"),
    "site_sakinleri": ("Site Sakinleri Listesi", "Daire + sakin + ilişki tipi"),
    "donemsel_bakiye": ("Dönemsel Bakiye", "Dönem bazında borç/tahsilat/bakiye"),
    "kasa_ekstresi": ("Kasa/Hesap Ekstresi", "Kasa bazında hareket dökümü"),
    "isletme_defteri": ("İşletme Defteri", "Tarih sıralı gelir/gider defteri"),
    "finansal_hareketler": ("Finansal Hareketler", "Tüm hareket tipleri"),
    "makbuz_dokumu": ("Makbuz Dökümü", "Tahsilat makbuzları listesi"),
    "gelir_gider_ozet": ("Gelir-Gider Özet", "Kalem bazında gelir/gider toplamı"),
    "tahsilat_performansi": ("Tahsilat Performansı",
                             "Tahsilat oranı + yaşlandırma + eğilim"),
    "ihtar_yazisi": ("İhtar Yazısı", "Daire başına resmi uyarı (PDF)"),
    "denetim_raporu": ("Denetim Raporu",
                       "Denetçi biçimi: dönem gelir-gider + kasa mutabakatı"),
}


@router.get("/raporlar/katalog", response_model=RaporKatalogResponse)
async def katalog(_: AppUser = Depends(_RAPOR_OKUR)) -> RaporKatalogResponse:
    return RaporKatalogResponse(items=[
        RaporKatalogOgesi(kod=k, baslik=v[0], aciklama=v[1])
        for k, v in KATALOG.items()
    ])


# ------------------------------ veri toplama -------------------------------- #
async def _tenant(db: AsyncSession, user: AppUser) -> Tenant:
    return (
        await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    ).scalar_one()


async def _kisi_borclari(
    db: AsyncSession, p: RaporParam, oran
) -> list[dict]:
    """Kisi/daire bazinda donem basi + donem ici toplamlar.

    HEDEFSIZ (daireye yazilmis) tahakkuklar da sayilir ve DAIRE satirinda
    gorunur: P28 oncesi kayitlar hedefsizdir ve raporda kaybolmalari,
    toplamlarin defterle tutmamasi demekti.
    """
    tazminat_gunu = p.tazminat_tarihi or p.bitis or datetime.now(timezone.utc).date()

    q = select(
        DuesAssessment.unit_id,
        Unit.no,
        Unit.blok,
        DuesAssessment.hedef_user_id,
        DuesAssessment.tutar_kurus,
        DuesAssessment.son_odeme_tarihi,
        DuesAssessment.gecikme_uygula,
        DuesAssessment.tarih,
        DuesAssessment.gelir_gider_tanim_id,
    ).join(Unit, Unit.id == DuesAssessment.unit_id)
    if p.blok:
        q = q.where(Unit.blok == p.blok)
    if p.gelir_gider_tanim_id:
        q = q.where(
            DuesAssessment.gelir_gider_tanim_id == uuid.UUID(p.gelir_gider_tanim_id)
        )
    tahakkuklar = (await db.execute(q)).all()

    hq = select(
        FinansalHareket.unit_id,
        FinansalHareket.user_id,
        FinansalHareket.tip,
        FinansalHareket.tutar_kurus,
        FinansalHareket.tarih,
    ).where(FinansalHareket.tip.in_(["tahsilat", "iade"]))
    hareketler = (await db.execute(hq)).all()

    adlar = dict(
        (await db.execute(select(AppUser.id, AppUser.ad))).all()
    )
    icradakiler = set(
        (await db.execute(select(IcraDosyasi.user_id))).scalars().all()
    )

    kisiler: dict[tuple, dict] = {}

    def _kutu(unit_id, unit_no, user_id):
        anahtar = (unit_id, user_id)
        if anahtar not in kisiler:
            kisiler[anahtar] = {
                "unit_no": unit_no,
                "ad": adlar.get(user_id) if user_id else None,
                "bas_ana_para": 0, "bas_gecikme": 0,
                "ici_borc": 0, "ici_gecikme": 0,
                "ici_iade": 0, "ici_tahsilat": 0,
                "icrada": user_id in icradakiler if user_id else False,
                "kalemler": {},
            }
        return kisiler[anahtar]

    for uid, no, _blok, hedef, tutar, vade, gec_uygula, tarih, tanim in tahakkuklar:
        k = _kutu(uid, no, hedef)
        gec = gecikme_kurus(
            int(tutar), vade, tazminat_gunu, oran, uygula=bool(gec_uygula)
        )
        oncesi = p.baslangic is not None and tarih is not None and tarih < p.baslangic
        sonrasi = p.bitis is not None and tarih is not None and tarih > p.bitis
        if sonrasi:
            continue
        if oncesi:
            k["bas_ana_para"] += int(tutar)
            k["bas_gecikme"] += gec
        else:
            k["ici_borc"] += int(tutar)
            k["ici_gecikme"] += gec
        anahtar = str(tanim) if tanim else "diger"
        k["kalemler"][anahtar] = k["kalemler"].get(anahtar, 0) + int(tutar)

    for uid, kullanici, tip, tutar, tarih in hareketler:
        if p.baslangic and tarih and tarih < p.baslangic:
            continue
        if p.bitis and tarih and tarih > p.bitis:
            continue
        k = _kutu(uid, None, kullanici)
        if tip == "tahsilat":
            k["ici_tahsilat"] += int(tutar)
        else:
            k["ici_iade"] += int(tutar)

    return list(kisiler.values())


# --------------------------------- katalog ---------------------------------- #
async def _uret(
    db: AsyncSession, user: AppUser, kod: str, p: RaporParam
) -> RaporSonuc:
    tenant = await _tenant(db, user)
    oran = tenant.gecikme_aylik_yuzde

    if kod == "borc_alacak":
        return borc_alacak_satirlari(await _kisi_borclari(db, p, oran), [], p)

    if kod == "detayli_borc":
        kalemler = [
            {"id": str(i), "ad": a}
            for i, a in (
                await db.execute(
                    select(GelirGiderTanim.id, GelirGiderTanim.ad)
                    .where(GelirGiderTanim.tip != "gelir")
                    .order_by(GelirGiderTanim.ad)
                )
            ).all()
        ]
        return detayli_borc_satirlari(
            await _kisi_borclari(db, p, oran), kalemler, p
        )

    if kod == "site_sakinleri":
        rows = (
            await db.execute(
                select(Unit.no, Unit.blok, AppUser.ad, UnitResident.rol_tipi)
                .join(UnitResident, UnitResident.unit_id == Unit.id)
                .join(AppUser, AppUser.id == UnitResident.user_id)
                .where(UnitResident.bitis.is_(None))
                .order_by(Unit.no)
            )
        ).all()
        sutunlar = [
            Sutun("unit_no", "Bağımsız Bölüm", genislik=2),
            Sutun("blok", "Blok"),
            Sutun("ad", "Ad Soyad", genislik=3),
            Sutun("rol_tipi", "İlişki Tipi", genislik=2),
        ]
        if not p.ismi_goster:
            sutunlar = [s for s in sutunlar if s.anahtar != "ad"]
        satirlar = [
            {"unit_no": no, "blok": blok,
             **({"ad": ad} if p.ismi_goster else {}),
             "rol_tipi": rol or "—"}
            for no, blok, ad, rol in rows
            if not p.blok or blok == p.blok
        ]
        return RaporSonuc(kod, KATALOG[kod][0], sutunlar,
                          sirala(satirlar, p.siralama, "unit_no"))

    if kod == "donemsel_bakiye":
        borc = dict(
            (await db.execute(
                select(DuesAssessment.donem, func.sum(DuesAssessment.tutar_kurus))
                .group_by(DuesAssessment.donem)
            )).all()
        )
        tahsil = dict(
            (await db.execute(
                # `func.to_char(...)` BIND PARAMETRESI uretir ve Postgres
                # GROUP BY'daki ifadeyle eslestiremez (GroupingError —
                # seffaflik panosunda da yasanmisti). `literal_column`
                # ifadeyi OLDUGU GIBI gomer.
                select(
                    _DONEM_IFADESI,
                    func.sum(FinansalHareket.tutar_kurus),
                )
                .where(FinansalHareket.tip == "tahsilat")
                .group_by(_DONEM_IFADESI)
            )).all()
        )
        donemler = sorted(set(borc) | set(tahsil))
        satirlar = []
        birikimli = 0
        for d in donemler:
            b, t = int(borc.get(d, 0)), int(tahsil.get(d, 0))
            birikimli += b - t
            satirlar.append({"donem": d, "borc": b, "tahsilat": t,
                             "bakiye": birikimli})
        return RaporSonuc(kod, KATALOG[kod][0], [
            Sutun("donem", "Dönem", genislik=2),
            Sutun("borc", "Borçlandırma", "kurus", 2),
            Sutun("tahsilat", "Tahsilat", "kurus", 2),
            Sutun("bakiye", "Birikimli Bakiye", "kurus", 2),
        ], satirlar)

    if kod in ("kasa_ekstresi", "isletme_defteri", "finansal_hareketler",
               "makbuz_dokumu"):
        return await _hareket_raporu(db, kod, p)

    if kod == "gelir_gider_ozet":
        rows = (
            await db.execute(
                select(
                    GelirGiderTanim.ad,
                    FinansalHareket.tip,
                    func.sum(FinansalHareket.tutar_kurus),
                )
                .join(
                    GelirGiderTanim,
                    GelirGiderTanim.id == FinansalHareket.gelir_gider_tanim_id,
                )
                .where(FinansalHareket.tip.in_(["gelir", "gider"]))
                .group_by(GelirGiderTanim.ad, FinansalHareket.tip)
            )
        ).all()
        birlesik: dict[str, dict] = {}
        for ad, tip, toplam in rows:
            kutu = birlesik.setdefault(ad, {"kalem": ad, "gelir": 0, "gider": 0})
            kutu[tip] += int(toplam)
        satirlar = list(birlesik.values())
        for s in satirlar:
            s["fark"] = s["gelir"] - s["gider"]
        sutunlar = [
            Sutun("kalem", "Kalem", genislik=3),
            Sutun("gelir", "Gelir", "kurus", 2),
            Sutun("gider", "Gider", "kurus", 2),
            Sutun("fark", "Fark", "kurus", 2),
        ]
        return RaporSonuc(kod, KATALOG[kod][0], sutunlar, satirlar, {
            a: sum(s[a] for s in satirlar) for a in ("gelir", "gider", "fark")
        })

    if kod == "tahsilat_performansi":
        return await _tahsilat_performansi(db, p, oran)

    if kod == "denetim_raporu":
        return await _denetim(db, p)

    if kod == "ihtar_yazisi":
        return await _ihtar(db, user, p)

    raise APIError(404, "not_found", "rapor_bulunamadi")


async def _hareket_raporu(db: AsyncSession, kod: str, p: RaporParam) -> RaporSonuc:
    """Dort hareket raporu AYNI sorgudan, farkli SUZGECLE cikar.

    Dort ayri sorgu yazmak, "işletme defterinde gorunen tutar finansal
    hareketlerde neden yok" tipi sessiz farklar uretirdi.
    """
    q = select(
        FinansalHareket.tarih, FinansalHareket.tip, FinansalHareket.yon,
        FinansalHareket.tutar_kurus, FinansalHareket.belge_no,
        FinansalHareket.aciklama, Kasa.ad, AppUser.ad,
    ).join(Kasa, Kasa.id == FinansalHareket.kasa_id, isouter=True) \
     .join(AppUser, AppUser.id == FinansalHareket.user_id, isouter=True)

    if kod == "makbuz_dokumu":
        q = q.where(FinansalHareket.tip == "tahsilat")
    elif kod == "isletme_defteri":
        q = q.where(FinansalHareket.tip.in_(["gelir", "gider"]))
    if p.baslangic:
        q = q.where(FinansalHareket.tarih >= p.baslangic)
    if p.bitis:
        q = q.where(FinansalHareket.tarih <= p.bitis)

    satirlar = [
        {"tarih": t.isoformat() if t else "", "tip": tip, "yon": yon,
         "tutar_kurus": int(tutar), "belge_no": belge or "",
         "aciklama": acik or "", "kasa": kasa or "",
         **({"kisi": kisi or ""} if p.ismi_goster else {})}
        for t, tip, yon, tutar, belge, acik, kasa, kisi in
        (await db.execute(q.order_by(FinansalHareket.tarih))).all()
    ]
    sutunlar = [
        Sutun("tarih", "Tarih", "tarih", 2),
        Sutun("tip", "Tip", genislik=2),
        Sutun("yon", "Yön"),
        Sutun("kasa", "Kasa", genislik=2),
    ]
    if p.ismi_goster:
        sutunlar.append(Sutun("kisi", "Kişi", genislik=3))
    sutunlar += [
        Sutun("belge_no", "Belge No", genislik=2),
        Sutun("aciklama", "Açıklama", genislik=4),
        Sutun("tutar_kurus", "Tutar", "kurus", 2),
    ]
    return RaporSonuc(kod, KATALOG[kod][0], sutunlar, satirlar, {
        "tutar_kurus": sum(s["tutar_kurus"] for s in satirlar)
    })


async def _tahsilat_performansi(
    db: AsyncSession, p: RaporParam, oran
) -> RaporSonuc:
    borc = dict(
        (await db.execute(
            select(DuesAssessment.donem, func.sum(DuesAssessment.tutar_kurus))
            .group_by(DuesAssessment.donem)
        )).all()
    )
    tahsil = dict(
        (await db.execute(
            select(
                _DONEM_IFADESI,
                func.sum(FinansalHareket.tutar_kurus),
            )
            .where(FinansalHareket.tip == "tahsilat")
            .group_by(_DONEM_IFADESI)
        )).all()
    )
    donemler = [
        {"donem": d, "borclandirilan": int(borc.get(d, 0)),
         "tahsil": int(tahsil.get(d, 0))}
        for d in sorted(set(borc) | set(tahsil))
    ]

    # YASLANDIRMA: vadesi gecmis borclarin kova dagilimi.
    bugun = p.tazminat_tarihi or datetime.now(timezone.utc).date()
    vadeli = (
        await db.execute(
            select(DuesAssessment.son_odeme_tarihi, DuesAssessment.tutar_kurus)
            .where(DuesAssessment.son_odeme_tarihi.is_not(None))
        )
    ).all()
    kovalar = {"0-30 gün": 0, "31-60 gün": 0, "61-90 gün": 0, "90+ gün": 0}
    for vade, tutar in vadeli:
        gun = (bugun - vade).days
        if gun <= 0:
            continue
        if gun <= 30:
            kovalar["0-30 gün"] += int(tutar)
        elif gun <= 60:
            kovalar["31-60 gün"] += int(tutar)
        elif gun <= 90:
            kovalar["61-90 gün"] += int(tutar)
        else:
            kovalar["90+ gün"] += int(tutar)
    _ = oran
    return tahsilat_performansi(
        donemler, [{"kova": k, "tutar_kurus": v} for k, v in kovalar.items()]
    )


async def _denetim(db: AsyncSession, p: RaporParam) -> RaporSonuc:
    """**Denetim Raporu** — denetci bicimi.

    Kasa MUTABAKATI raporun cekirdegidir: acilis + hareketler = bakiye
    esitligini SATIR SATIR gosterir. Denetci "rakam nereden geliyor"
    sorusunu bu tabloda cevaplayabilmeli; tek bir toplam yazmak
    mutabakat degil beyandir.
    """
    kasalar = (await db.execute(select(Kasa).order_by(Kasa.kod))).scalars().all()
    hareket = dict(
        (await db.execute(
            select(FinansalHareket.kasa_id, FinansalHareket.yon,
                   func.sum(FinansalHareket.tutar_kurus))
            .group_by(FinansalHareket.kasa_id, FinansalHareket.yon)
        )).all() and []
    )
    ham = (
        await db.execute(
            select(FinansalHareket.kasa_id, FinansalHareket.yon,
                   func.sum(FinansalHareket.tutar_kurus))
            .group_by(FinansalHareket.kasa_id, FinansalHareket.yon)
        )
    ).all()
    for kid, yon, toplam in ham:
        hareket.setdefault(kid, {"giris": 0, "cikis": 0})[yon] = int(toplam)

    satirlar = []
    for k in kasalar:
        h = hareket.get(k.id, {"giris": 0, "cikis": 0})
        giris, cikis = h.get("giris", 0), h.get("cikis", 0)
        satirlar.append({
            "kasa": f"{k.kod} · {k.ad}",
            "acilis": k.acilis_bakiye_kurus,
            "giris": giris, "cikis": cikis,
            "bakiye": k.acilis_bakiye_kurus + giris - cikis,
        })
    sutunlar = [
        Sutun("kasa", "Kasa", genislik=3),
        Sutun("acilis", "Açılış", "kurus", 2),
        Sutun("giris", "Giriş", "kurus", 2),
        Sutun("cikis", "Çıkış", "kurus", 2),
        Sutun("bakiye", "Bakiye", "kurus", 2),
    ]
    sonuc = RaporSonuc("denetim_raporu", KATALOG["denetim_raporu"][0],
                       sutunlar, satirlar, {
        a: sum(s[a] for s in satirlar)
        for a in ("acilis", "giris", "cikis", "bakiye")
    })
    gelir = sum(s["giris"] for s in satirlar)
    gider = sum(s["cikis"] for s in satirlar)
    sonuc.metin = (
        f"Dönem gelir toplamı: {kurus_metin(gelir)} TL · "
        f"Dönem gider toplamı: {kurus_metin(gider)} TL · "
        f"Fark: {kurus_metin(gelir - gider)} TL\n"
        "Karar defteri referansları: yönetim kurulu karar numaraları bu "
        "rapora EKLENMEZ; karar defteri ayrı bir kayıttır ve denetçiye "
        "aslı ile sunulur."
    )
    return sonuc


async def _ihtar(db: AsyncSession, user: AppUser, p: RaporParam) -> RaporSonuc:
    """**İhtar Yazısı** — borclu daire basina resmi metin.

    Tek bir PDF'te ARDI ARDINA uretilir: daire basina ayri dosya, 40 daireli
    bir sitede 40 indirme demekti.
    """
    tenant = await _tenant(db, user)
    kisiler = await _kisi_borclari(db, p, tenant.gecikme_aylik_yuzde)
    bugun = p.tazminat_tarihi or datetime.now(timezone.utc).date()
    parcalar = []
    for k in kisiler:
        borc = (k["bas_ana_para"] + k["ici_borc"]) - k["ici_tahsilat"]
        gec = k["bas_gecikme"] + k["ici_gecikme"]
        if borc <= 0:
            continue
        if p.min_tutar_kurus is not None and borc < p.min_tutar_kurus:
            continue
        parcalar.append(ihtar_metni(
            tenant.ad, k.get("ad") or "İlgili Bağımsız Bölüm Maliki",
            k.get("unit_no") or "—", borc, gec, bugun,
        ))
    sonuc = RaporSonuc("ihtar_yazisi", KATALOG["ihtar_yazisi"][0], [], [])
    sonuc.metin = ("\n\n" + "-" * 60 + "\n\n").join(parcalar) or \
        "Ödenmemiş borcu olan bağımsız bölüm bulunmamaktadır."
    return sonuc


# --------------------------------- uc --------------------------------------- #
@router.post("/raporlar/{kod}")
async def rapor_uret(
    kod: str,
    body: RaporParametre,
    bicim: str = Query("tablo", description="tablo | excel | pdf"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_RAPOR_OKUR),
):
    """Raporu UC BICIMDEN biriyle uret.

    Bicim basina ayri uc acmak, ayni parametre modelini uc kez dogrulamak
    ve uc yerde degistirmek demekti.
    """
    if kod not in KATALOG:
        raise APIError(404, "not_found", "rapor_bulunamadi")
    if bicim not in ("tablo", "excel", "pdf"):
        raise APIError(422, "validation_error", "gecersiz_rapor_bicimi")

    p = RaporParam(**body.model_dump())
    sonuc = await _uret(db, user, kod, p)
    tenant = await _tenant(db, user)

    if bicim == "tablo":
        return RaporTablo(
            kod=sonuc.kod, baslik=sonuc.baslik,
            sutunlar=[
                {"anahtar": s.anahtar, "baslik": s.baslik, "tip": s.tip}
                for s in sonuc.sutunlar
            ],
            satirlar=sonuc.satirlar, toplamlar=sonuc.toplamlar,
            metin=sonuc.metin,
        )

    if bicim == "excel":
        icerik = excel_uret(sonuc, tenant.ad, p.baslangic, p.bitis)
        tur = ("application/vnd.openxmlformats-officedocument"
               ".spreadsheetml.sheet")
        uzanti = "xlsx"
    else:
        icerik = (
            metin_pdf(sonuc.baslik, sonuc.metin or "", tenant.ad)
            if not sonuc.sutunlar
            else pdf_uret(sonuc, tenant.ad, p.baslangic, p.bitis)
        )
        tur = "application/pdf"
        uzanti = "pdf"

    gun = datetime.now(timezone.utc).strftime("%Y%m%d")
    return Response(
        content=icerik,
        media_type=tur,
        headers={
            "Content-Disposition":
                f'attachment; filename="{kod}-{gun}.{uzanti}"',
        },
    )
