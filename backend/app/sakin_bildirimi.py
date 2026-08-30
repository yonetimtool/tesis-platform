"""(P147) Sakine ait bildirim SATIRI yazma — anlik push'un kalici ikizi.

NEDEN AYRI BIR YARDIMCI: `dispatch_external` anlik bildirimi gonderir ve
GERIYE HICBIR SEY BIRAKMAZ. Bildirimi o an kaciran kullanici icin olay yok
olur. Bu yardimci ayni olayi `notification` tablosuna da yazar; ikisi yan
yana cagrilir.

METIN KAYDA DONDURULMAZ: satir yalnizca `mesaj_kimlik` + `mesaj_veri`
tutar, okuma yolu metni ISTEGIN dilinde uretir (tur 16 karari). `mesaj`
sutunu NOT NULL oldugu icin Turkce karsiligi doldurulur — eski satirlarla
ayni bicim, ama okuma yolu onu KULLANMAZ.
"""
from __future__ import annotations

import uuid
from collections.abc import Iterable, Mapping

from sqlalchemy.ext.asyncio import AsyncSession

from .akis_metinleri import _tl
from .models import Notification
from .push_metinleri import push_govdesi


def sakin_bildirimi_yaz(
    db: AsyncSession,
    *,
    tenant_id: uuid.UUID,
    tip: str,
    user_ids: Iterable[uuid.UUID],
    veri: Mapping[str, object] | None = None,
    task_id: uuid.UUID | None = None,
) -> list[Notification]:
    """Her alici icin BIR satir yazar (flush cagirani yapar).

    Alici basina ayri satir: okundu bilgisi KISIYE aittir. Tek satiri
    paylastirsaydik bir kullanicinin okumasi digerininkini de "okundu"
    yapardi — kargo gibi cok alicili olaylarda bu gorulur bir kusurdur.
    """
    veri = dict(veri or {})
    satirlar: list[Notification] = []
    for uid in dict.fromkeys(user_ids):  # yinelenen alici tek satir
        row = Notification(
            tenant_id=tenant_id,
            user_id=uid,
            tip=tip,
            mesaj=push_govdesi(tip, "tr", veri),
            mesaj_kimlik=tip,
            mesaj_veri=veri,
            task_id=task_id,
        )
        db.add(row)
        satirlar.append(row)
    return satirlar


# --------------------------------------------------------------------------- #
# (P191 §2) AIDAT / BORCLANDIRMA BILDIRIMI
#
# Bu yolun push cagrisi da HIC YOKTU: yonetici toplu borclandirma yapiyor,
# sakinin telefonuna hicbir sey dusmuyordu. Aidat kullanicinin PARASIYLA
# ilgili tek olaydir; onu "bir ara uygulamaya bak"a birakmak dogru degil.
#
# HEDEF COZUMU IKI ASAMALI:
#   1. `hedef_user_id` VARSA (gelir/gider tanimi bir hedef kurali tasiyor)
#      borc dogrudan o kisiye yazilmistir; bildirim de ona gider.
#   2. YOKSA borc DAIREYE yazilmistir (tanimsiz tahakkuk — urunun eski ve
#      en yaygin yolu). O daireye BAGLI TUM aktif sakinler bilgilendirilir.
#      Aksi halde en sik kullanilan borclandirma yolu sessiz kalirdi ki
#      olculen kusur zaten buydu. Sakin `/me/dues`ta bu borcu ZATEN goruyor;
#      bildirim yeni bir yetki acmaz, var olan gorunurlugu haber verir.
#
# KISI BASINA TEK BILDIRIM: toplu islemde bir sakine birden cok satir
# yazilabilir (birden cok daire, birden cok tanim). Satir basina push
# gondermek, 3 dairesi olan sakine ust uste 3 bildirim demekti. Tutarlar
# TOPLANIR, tek bildirim gider.
# --------------------------------------------------------------------------- #
async def aidat_bildir(
    db: AsyncSession,
    *,
    tenant_id: uuid.UUID,
    kalemler: Iterable[tuple[uuid.UUID, uuid.UUID | None, str, int]],
) -> None:
    """`kalemler`: (unit_id, hedef_user_id, donem, tutar_kurus) dortluleri."""
    from sqlalchemy import select

    from .models import UnitResident
    from .scheduler.notify import dispatch_external

    kalem_listesi = list(kalemler)
    if not kalem_listesi:
        return
    # Hedefsiz kalemlerin daire sakinleri TEK sorguda cozulur (toplu
    # borclandirmada 500 daire olabilir; daire basina sorgu kabul edilemez).
    hedefsiz = {u for u, h, _, _ in kalem_listesi if h is None}
    daire_sakinleri: dict[uuid.UUID, list[uuid.UUID]] = {}
    if hedefsiz:
        rows = (
            await db.execute(
                select(UnitResident.unit_id, UnitResident.user_id).where(
                    UnitResident.unit_id.in_(hedefsiz),
                    UnitResident.bitis.is_(None),
                )
            )
        ).all()
        for unit_id, user_id in rows:
            daire_sakinleri.setdefault(unit_id, []).append(user_id)

    toplam: dict[uuid.UUID, tuple[str, int]] = {}
    for unit_id, hedef, donem, kurus in kalem_listesi:
        aliciler = [hedef] if hedef is not None else daire_sakinleri.get(unit_id, [])
        for user_id in aliciler:
            onceki = toplam.get(user_id)
            toplam[user_id] = (
                donem if onceki is None else onceki[0],
                (onceki[1] if onceki else 0) + int(kurus or 0),
            )
    for user_id, (donem, kurus) in toplam.items():
        veri = {"donem": donem, "tutar": _tl(kurus)}
        dispatch_external(
            "aidat_borc",
            tenant_id=tenant_id,
            target_user_ids=(user_id,),
            params=veri,
            data={"tip": "aidat_borc"},
        )
        sakin_bildirimi_yaz(
            db, tenant_id=tenant_id, tip="aidat_borc", user_ids=(user_id,), veri=veri
        )
