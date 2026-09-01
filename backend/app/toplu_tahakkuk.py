"""(P192 §4.1) TOPLU TAHAKKUK CEKIRDEGI — uc ile OTOMASYONUN ortak yolu.

Bu kod `routers/borclandirma_uc.py` icindeydi ve YALNIZ uc tarafindan
cagrilabiliyordu. Otomatik aylik tahakkuk (`app/otomasyon.py`) ayni isi
yapmak zorunda; ikinci bir kopya yazmak, "elle tahakkuk" ile "otomatik
tahakkuk"un gunun birinde FARKLI davranmasi demekti — ve fark ancak
rakamlar tutmayinca fark edilirdi.

Modul SAF DEGIL (veritabanina bakar) ama KARAR ICERMEZ: dagitim
matematigi `borclandirma.py`de, yazma kurallari burada, HTTP kabugu
router'da.
"""
from __future__ import annotations

import uuid
from datetime import date

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from .borclandirma import Bag, hedef_sec, oransal_dagit, tipe_gore_dagit
from .crud_helpers import is_unique_violation, translate_integrity
from .models import (
    AppUser,
    DuesAssessment,
    GelirGiderTanim,
    Unit,
    UnitResident,
    UnitTip,
)
from .schemas import TopluBorcIstek, TopluBorcSatir


async def daire_baglari(
    db: AsyncSession, unit_idler: list[uuid.UUID]
) -> dict[uuid.UUID, list[Bag]]:
    """Daire -> AKTIF sakin baglari (P23). TEK sorgu (daire basina N+1 yok)."""
    if not unit_idler:
        return {}
    rows = (
        await db.execute(
            select(UnitResident.unit_id, UnitResident.user_id, UnitResident.rol_tipi)
            .where(
                UnitResident.unit_id.in_(unit_idler),
                UnitResident.bitis.is_(None),
            )
        )
    ).all()
    sonuc: dict[uuid.UUID, list[Bag]] = {}
    for uid, kullanici, rol in rows:
        sonuc.setdefault(uid, []).append(Bag(str(kullanici), rol))
    return sonuc


async def hedef_adlari(
    db: AsyncSession, idler: set[uuid.UUID]
) -> dict[uuid.UUID, str]:
    if not idler:
        return {}
    return dict(
        (await db.execute(select(AppUser.id, AppUser.ad).where(AppUser.id.in_(idler)))).all()
    )


async def hedef_daireler(
    db: AsyncSession, suzgec
) -> list[tuple[uuid.UUID, str, uuid.UUID | None]]:
    """Suzgece uyan AKTIF daireler: (id, no, unit_tip_id, arsa_payi, metrekare)."""
    _sutunlar = (Unit.id, Unit.no, Unit.unit_tip_id, Unit.arsa_payi, Unit.metrekare)
    q = select(*_sutunlar).where(Unit.aktif.is_(True))
    if suzgec.unit_ids:
        # Elle secim suzgeci EZER: kullanici tek tek sectiyse blok/tip
        # kisitlarini ayrica uygulamak "sectigim daire neden yok" uretirdi.
        q = select(*_sutunlar).where(Unit.id.in_(suzgec.unit_ids))
    else:
        if suzgec.blok is not None:
            q = q.where(Unit.blok == suzgec.blok)
        if suzgec.unit_tip_id is not None:
            q = q.where(Unit.unit_tip_id == suzgec.unit_tip_id)
        if suzgec.unit_grup_id is not None:
            q = q.where(Unit.unit_grup_id == suzgec.unit_grup_id)
    return [tuple(r) for r in (await db.execute(q.order_by(Unit.no))).all()]


async def tip_varsayilanlari(db: AsyncSession) -> dict[uuid.UUID, int | None]:
    rows = (
        await db.execute(select(UnitTip.id, UnitTip.varsayilan_aidat_kurus))
    ).all()
    return {r[0]: r[1] for r in rows}


async def toplu_plan(
    db: AsyncSession, body: TopluBorcIstek, tanim: GelirGiderTanim
) -> list[TopluBorcSatir]:
    """Onizleme ve isleme AYNI plani kullanir — gorulen ile yazilan ayni olsun."""
    daireler = await hedef_daireler(db, body.suzgec)
    if not daireler:
        return []
    idler = [d[0] for d in daireler]
    baglar = await daire_baglari(db, idler)

    # (P192 §3.3) DAGITIM YONTEMI. `daire_basina` ESKI DAVRANISTIR ve
    # varsayilandir: mevcut cagiranlar (panel, testler) aynen calisir.
    nedenler: dict[uuid.UUID, str] = {}
    if body.dagitim == "daire_basina":
        if body.tutar_kurus is not None:
            tutarlar: list[int | None] = [body.tutar_kurus] * len(daireler)
        else:
            varsayilanlar = await tip_varsayilanlari(db)
            tutarlar = tipe_gore_dagit(
                [varsayilanlar.get(d[2]) if d[2] else None for d in daireler],
                body.yedek_tutar_kurus,
            )
            for d, t in zip(daireler, tutarlar):
                if t is None:
                    nedenler[d[0]] = "tip_varsayilani_yok"
    elif body.dagitim == "esit":
        # Toplami esit bolmek `oransal_dagit`in agirliklari 1 olan hali:
        # ayri bir kod yolu, ayni yuvarlama kuralini iki yerde tutmak
        # olurdu.
        tutarlar = oransal_dagit(
            body.toplam_tutar_kurus or 0, [1] * len(daireler)
        )
    else:
        alan = 3 if body.dagitim == "arsa_payi" else 4
        agirliklar = [d[alan] for d in daireler]
        tutarlar = oransal_dagit(body.toplam_tutar_kurus or 0, agirliklar)
        eksik = (
            "arsa_payi_girilmemis" if body.dagitim == "arsa_payi"
            else "metrekare_girilmemis"
        )
        for d, a in zip(daireler, agirliklar):
            if a is None or a <= 0:
                # SESSIZ ATLAMA YOK (P192 §3.2): arsa payi girilmemis daire
                # dagitimin disinda kalir ve bu KULLANICIYA SOYLENIR.
                nedenler[d[0]] = eksik

    hedefler = {
        d[0]: hedef_sec(baglar.get(d[0], []), tanim.hedef_kurali) for d in daireler
    }
    adlar = await hedef_adlari(
        db, {uuid.UUID(h) for h in hedefler.values() if h}
    )

    satirlar: list[TopluBorcSatir] = []
    for daire, tutar in zip(daireler, tutarlar):
        uid, no = daire[0], daire[1]
        hedef = hedefler[uid]
        satirlar.append(
            TopluBorcSatir(
                unit_id=uid,
                unit_no=no,
                tutar_kurus=tutar,
                hedef_user_id=uuid.UUID(hedef) if hedef else None,
                hedef_ad=adlar.get(uuid.UUID(hedef)) if hedef else None,
                # Tutari cozulemeyen daire ATLANIR: sessizce 0 borclandirmak,
                # yonetimin fark etmedigi eksik tahakkuk uretirdi. NEDEN de
                # tasinir (P192 §3.2) — "atlandi" demek yetmez, NIYE
                # atlandigi soylenmeli.
                atlama_nedeni=(
                    None if tutar else nedenler.get(uid, "tutar_cozulemedi")
                ),
            )
        )
    return satirlar


async def tahakkuk_yaz(
    db: AsyncSession,
    user: AppUser | None,
    *,
    unit_id: uuid.UUID,
    donem: str,
    tutar_kurus: int,
    tanim_id: uuid.UUID | None,
    hedef_user_id: uuid.UUID | None,
    son_odeme_tarihi: date | None,
    tarih: date | None,
    aciklama: str | None,
    gecikme_uygula: bool,
    kaynak: str,
    kalem_tipi: str = "aidat",
    tenant_id: uuid.UUID | None = None,
) -> bool:
    """Tek satir yaz; benzersizlik carpismasinda ATLA (False doner).

    SAVEPOINT: tek satirin carpismasi tum toplu islemi dusurmemeli — mevcut
    `create_assessments` ile ayni desen.

    (P192 §4.1) `user` OPSIYONEL: otomatik tahakkukun bir kullanicisi
    yoktur ve uydurma bir kullanici atamak, denetim kaydinda o kisiyi
    yapmadigi bir isin altina imza attirmak olurdu. O durumda `tenant_id`
    acikca verilir.
    """
    kime = user.tenant_id if user is not None else tenant_id
    if kime is None:
        raise ValueError("tahakkuk_yaz: user ya da tenant_id gerekli")
    obj = DuesAssessment(
        tenant_id=kime,
        unit_id=unit_id,
        donem=donem,
        tutar_kurus=tutar_kurus,
        gelir_gider_tanim_id=tanim_id,
        hedef_user_id=hedef_user_id,
        son_odeme_tarihi=son_odeme_tarihi,
        aciklama=aciklama,
        gecikme_uygula=gecikme_uygula,
        kaynak=kaynak,
        kalem_tipi=kalem_tipi,
        **({"tarih": tarih} if tarih is not None else {}),
    )
    try:
        async with db.begin_nested():
            db.add(obj)
            await db.flush()
    except IntegrityError as exc:
        try:
            db.expunge(obj)
        except Exception:
            pass
        if is_unique_violation(exc):
            return False
        raise translate_integrity(exc)
    return True
