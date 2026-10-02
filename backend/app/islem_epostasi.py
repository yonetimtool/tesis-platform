"""(P250) IZLENEN ISLEM E-POSTALARI — odeme kodu, hos geldiniz, aidat hatirlatma.

Uc ozellik ayni dort soruyu soruyor; cevaplar burada TEK YERDE:

  1. Kime gidebilir?  (`gonderilemez_sebebi`) — adres yok / sentetik adres /
     kisi e-posta bildirimlerini kapatmis.
  2. Hangi dilde?     (`alici_dili`) — kisinin dili `app_user`da tutulmuyor;
     en son kullandigi CIHAZIN dili (push ile ayni kaynak), yoksa cagiranin
     verdigi varsayilan.
  3. Nasil gider?     (`hemen_gonder` / `kuyruga_al`) — her gonderim bir
     `mesaj_gonderim` satiri birakir (`tur` + HTML). Satir P234 teslim
     geri bildirimine (`saglayici_mesaj_id`) baglanir.
  4. Ne oldu?         (`son_durumlar` + `teslim_durumu`) — listede
     "gonderildi / iletildi / geri dondu".

TEK TEK GONDERIM HEMEN, TOPLU GONDERIM KUYRUKTAN. Toplu istekte satirlar
`kuyrukta` yazilir ve `mesaj_kuyruk` (dakikada bir) e-postalar arasinda
sabit aralik birakarak gonderir — saglayicinin saniyelik siniri asilmaz,
yoneticinin tarayicisi yuzlerce gonderimi beklemez.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from .ceviri import DESTEKLENEN_DILLER
from .gonderim import SaglayiciAyari, saglayici as kanal_saglayicisi
from .models import AppUser, MesajGonderim, UserDevice

#: Teslim durumu (arayuzun gordugu). Ham `mesaj_durum` + `hata`dan turer.
KUYRUKTA = "kuyrukta"
GONDERILDI = "gonderildi"
ILETILDI = "iletildi"
GERI_DONDU = "geri_dondu"
BASARISIZ = "basarisiz"
YAPILANDIRILMADI = "yapilandirilmadi"

#: Sentetik (anonimlestirilmis / adressiz) hesaplarin alan adi — P197.
_SENTETIK_ALAN = "@yonetiyor.invalid"


def teslim_durumu(durum: str, hata: str | None) -> str:
    """Ham gonderim satirindan arayuz durumu.

    `okundu` ayri gosterilmez: "iletildi"nin ustune bilgi eklemiyor ve
    acilma pikseli guvenilir degil (Apple Mail onceden yukler).
    Geri donme P234'te `basarisiz` + `hata='bounce'` olarak yaziliyor.
    """
    if durum in ("iletildi", "okundu"):
        return ILETILDI
    if durum == "basarisiz":
        return GERI_DONDU if hata == "bounce" else BASARISIZ
    if durum in (KUYRUKTA, GONDERILDI, YAPILANDIRILMADI):
        return durum
    return BASARISIZ


def gonderilemez_sebebi(kisi: AppUser, *, tercihe_uy: bool = True) -> str | None:
    """None = gonderilebilir. Aksi halde arayuzun gosterecegi sebep kodu."""
    if not kisi.email or kisi.email.endswith(_SENTETIK_ALAN):
        return "eposta_yok"
    if tercihe_uy and kisi.bildirim_eposta is False:
        return "eposta_kapali"
    return None


async def alici_dili(
    db: AsyncSession, user_ids: list[uuid.UUID], varsayilan: str
) -> dict[uuid.UUID, str]:
    """Her kisi icin en son guncellenen aktif cihazin dili."""
    if not user_ids:
        return {}
    satirlar = (
        await db.execute(
            select(UserDevice.user_id, UserDevice.dil)
            .where(UserDevice.user_id.in_(user_ids), UserDevice.aktif.is_(True))
            .order_by(UserDevice.user_id, UserDevice.updated_at.desc())
            .distinct(UserDevice.user_id)
        )
    ).all()
    sonuc = {uid: varsayilan for uid in user_ids}
    for uid, dil in satirlar:
        if dil in DESTEKLENEN_DILLER:
            sonuc[uid] = dil
    return sonuc


async def son_durumlar(
    db: AsyncSession, tur: str, user_ids: list[uuid.UUID]
) -> dict[uuid.UUID, tuple[str, datetime]]:
    """user_id -> (teslim durumu, zaman) — o turdeki EN SON gonderim."""
    if not user_ids:
        return {}
    satirlar = (
        await db.execute(
            select(
                MesajGonderim.user_id,
                MesajGonderim.durum,
                MesajGonderim.hata,
                MesajGonderim.created_at,
            )
            .where(MesajGonderim.tur == tur, MesajGonderim.user_id.in_(user_ids))
            .order_by(MesajGonderim.user_id, MesajGonderim.created_at.desc())
            .distinct(MesajGonderim.user_id)
        )
    ).all()
    return {r.user_id: (teslim_durumu(r.durum, r.hata), r.created_at) for r in satirlar}


async def yakin_zamanda_gonderilenler(
    db: AsyncSession, tur: str, user_ids: list[uuid.UUID], dakika: int
) -> set[uuid.UUID]:
    """Son `dakika` icinde bu turden e-posta almis (ya da kuyrukta) kisiler.

    Basarisiz/geri donmus satirlar SAYILMAZ: adres duzeltilip yeniden
    gonderilmek isteniyorsa koruma engel olmamali.
    """
    if not user_ids or dakika <= 0:
        return set()
    sinir = datetime.now(tz=timezone.utc) - timedelta(minutes=dakika)
    return set(
        (
            await db.execute(
                select(MesajGonderim.user_id)
                .where(
                    MesajGonderim.tur == tur,
                    MesajGonderim.user_id.in_(user_ids),
                    MesajGonderim.created_at >= sinir,
                    MesajGonderim.durum != "basarisiz",
                )
            )
        ).scalars().all()
    )


def _satir(
    *,
    tenant_id: uuid.UUID,
    kisi: AppUser,
    tur: str,
    konu: str,
    metin: str,
    html: str,
    gonderen_id: uuid.UUID | None,
    saglayici_mesaj_id: str | None = None,
) -> MesajGonderim:
    return MesajGonderim(
        tenant_id=tenant_id, kanal="eposta", amac="operasyonel", tur=tur,
        user_id=kisi.id, hedef=kisi.email, konu=konu, govde=metin,
        govde_html=html, gonderen_user_id=gonderen_id,
        # (P234) Teslim geri bildirimi bu kimlikle baglanir; kuyruk
        # satirinda None, ilk denemede kuyruk doldurur.
        saglayici_mesaj_id=saglayici_mesaj_id,
    )


def hemen_gonder(
    db: AsyncSession,
    *,
    ayar: SaglayiciAyari | None,
    tenant_id: uuid.UUID,
    kisi: AppUser,
    tur: str,
    konu: str,
    metin: str,
    html: str,
    gonderen_id: uuid.UUID | None,
) -> MesajGonderim:
    """Simdi gonderir; basarisizsa satir KUYRUGA duser (yeniden denenir)."""
    sonuc = kanal_saglayicisi("eposta", ayar).gonder(kisi.email, konu, metin, html=html)
    kayit = _satir(
        tenant_id=tenant_id, kisi=kisi, tur=tur, konu=konu, metin=metin,
        html=html, gonderen_id=gonderen_id,
        saglayici_mesaj_id=sonuc.saglayici_mesaj_id,
    )
    kuyrukta = sonuc.durum == "basarisiz"
    kayit.durum = KUYRUKTA if kuyrukta else sonuc.durum
    kayit.hata = sonuc.hata
    kayit.saglayici = sonuc.saglayici
    kayit.deneme = 1
    kayit.son_deneme_at = func.now()
    db.add(kayit)
    return kayit


def kuyruga_al(
    db: AsyncSession,
    *,
    tenant_id: uuid.UUID,
    kisi: AppUser,
    tur: str,
    konu: str,
    metin: str,
    html: str,
    gonderen_id: uuid.UUID | None,
) -> MesajGonderim:
    """Toplu gonderim: satir `kuyrukta`, hic denenmemis (deneme=0)."""
    kayit = _satir(
        tenant_id=tenant_id, kisi=kisi, tur=tur, konu=konu, metin=metin,
        html=html, gonderen_id=gonderen_id,
    )
    kayit.durum = KUYRUKTA
    kayit.deneme = 0
    db.add(kayit)
    return kayit
