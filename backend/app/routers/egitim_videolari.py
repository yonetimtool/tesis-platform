"""(P250 §4) KURULUM EGITIM VIDEOLARI.

Videolar YouTube'da ("liste disi"); sistem yalniz KIMLIGI saklar ve
oynatir. Baglantilar PLATFORM admininin panelinden girilir (goc 0163);
degisiklik aninda yayindadir, uygulama surumu gerekmez.

Uclar:
  * `GET  /egitim-videolari`                     — setin adimlari + izlendi
  * `POST /egitim-videolari/{adim}/izlendi`      — video BITINCE (ENDED)
  * `GET  /egitim-videolari/yonetim`             — panel (admin)
  * `PUT  /egitim-videolari/yonetim/{adim}`      — panel (admin)
  * `DELETE /egitim-videolari/yonetim/{adim}`    — panel (admin)

SETLER: bugun yalniz `yonetici` (kurulum sihirbazinin adimlari). Sakin ve
guvenlik icin ayri setler ileride AYNI tabloya yeni `set_kodu` ile gelir;
`SET_ROLLERI` hangi rolun hangi seti gordugunu soyler.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..deps import get_current_user, get_tenant_db, require_role
from ..egitim_video import youtube_kimligi
from ..errors import APIError
from ..models import AppUser, EgitimIzleme, Tenant
from ..schemas import (
    EgitimAdimOut,
    EgitimAdimVideo,
    EgitimVideoListe,
    EgitimVideosuOut,
    EgitimVideosuYaz,
    EgitimVideoYonetimListe,
)
from .kurulum import ADIMLAR, _durum

router = APIRouter(prefix="/egitim-videolari", tags=["egitim-videolari"])

_ADMIN = require_role("admin")

#: set -> sihirbaz adimlari (SIRA ANLAMLI: varsayilan oynatma sirasi).
SETLER: dict[str, tuple[str, ...]] = {
    "yonetici": tuple(a.kod for a in ADIMLAR),
}
#: set -> seti gorebilen roller. "Simdilik yalniz yonetici gorsun."
SET_ROLLERI: dict[str, frozenset[str]] = {
    "yonetici": frozenset({"admin", "yonetici"}),
}

def _set_dogrula(set_kodu: str) -> tuple[str, ...]:
    adimlar = SETLER.get(set_kodu)
    if adimlar is None:
        raise APIError(404, "not_found", "egitim_seti_yok")
    return adimlar


def _adim_dogrula(set_kodu: str, adim_kodu: str) -> None:
    if adim_kodu not in _set_dogrula(set_kodu):
        raise APIError(404, "not_found", "egitim_adimi_yok")


async def _videolar(db: AsyncSession, set_kodu: str) -> list[EgitimVideosuOut]:
    satirlar = (
        await db.execute(
            text(
                "SELECT adim_kodu, youtube_id, baslik, aciklama, sira, aktif, "
                "surum, updated_at FROM public.egitim_videosu_oku(:s)"
            ),
            {"s": set_kodu},
        )
    ).mappings().all()
    return [EgitimVideosuOut(**dict(r)) for r in satirlar]


def _sirala(adimlar: tuple[str, ...], videolar: dict[str, EgitimVideosuOut]) -> list[str]:
    """Oynatma sirasi: panelde girilen `sira`, yoksa sihirbaz sirasi.

    Videosuz adimin etkin sirasi sihirbazdaki yerinin 10 kati — panel de
    yeni bir video icin ayni varsayilani onerir, yani `sira`ya hic
    dokunulmazsa sihirbaz sirasi korunur.
    """
    def anahtar(i_kod: tuple[int, str]) -> tuple[int, int]:
        i, kod = i_kod
        v = videolar.get(kod)
        return ((v.sira if v else (i + 1) * 10), i)

    return [k for _, k in sorted(enumerate(adimlar), key=anahtar)]


# ============================ KULLANICI ==================================== #
@router.get("", response_model=EgitimVideoListe)
async def liste(
    set_kodu: str = Query("yonetici", alias="set", pattern=r"^[a-z_]{1,30}$"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(get_current_user),
) -> EgitimVideoListe:
    adimlar = _set_dogrula(set_kodu)
    if user.role not in SET_ROLLERI[set_kodu]:
        raise APIError(403, "forbidden", "egitim_seti_rol_disi")
    videolar = {v.adim_kodu: v for v in await _videolar(db, set_kodu) if v.aktif}
    izlenen_surum = dict(
        (
            await db.execute(
                select(EgitimIzleme.adim_kodu, EgitimIzleme.surum).where(
                    EgitimIzleme.user_id == user.id,
                    EgitimIzleme.set_kodu == set_kodu,
                )
            )
        ).all()
    )
    cikti: list[EgitimAdimOut] = []
    for kod in _sirala(adimlar, videolar):
        v = videolar.get(kod)
        cikti.append(
            EgitimAdimOut(
                adim_kodu=kod,
                video=EgitimAdimVideo(
                    youtube_id=v.youtube_id, baslik=v.baslik, aciklama=v.aciklama
                ) if v else None,
                izlendi=bool(v) and izlenen_surum.get(kod) == v.surum,
            )
        )
    tenant = (
        await db.execute(select(Tenant).where(Tenant.id == user.tenant_id))
    ).scalar_one()
    durum = await _durum(db, tenant)
    return EgitimVideoListe(
        set_kodu=set_kodu,
        adimlar=cikti,
        toplam=sum(1 for a in cikti if a.video),
        izlenen=sum(1 for a in cikti if a.izlendi),
        kurulum_tamam=not durum.eksik_zorunlular,
    )


@router.post("/{adim_kodu}/izlendi", status_code=204, response_class=Response)
async def izlendi(
    adim_kodu: str,
    set_kodu: str = Query("yonetici", alias="set", pattern=r"^[a-z_]{1,30}$"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(get_current_user),
) -> Response:
    """Video SONUNA KADAR izlendi (oynaticinin ENDED olayi).

    Ortada kapatilan video bu uca hic gelmez — izlendi sayilmaz. Isaret o
    anki video SURUMUNE yazilir; video degisirse yeniden "izlenmedi" olur.
    """
    # ROL ONCE: rol disi kisi adimin var olup olmadigini bile ogrenmesin
    # (ve rol matrisi kilidi 403'u olcebilsin).
    _set_dogrula(set_kodu)
    if user.role not in SET_ROLLERI[set_kodu]:
        raise APIError(403, "forbidden", "egitim_seti_rol_disi")
    _adim_dogrula(set_kodu, adim_kodu)
    v = next(
        (x for x in await _videolar(db, set_kodu) if x.adim_kodu == adim_kodu and x.aktif),
        None,
    )
    if v is None:
        raise APIError(404, "not_found", "egitim_videosu_yok")
    ifade = pg_insert(EgitimIzleme).values(
        tenant_id=user.tenant_id, user_id=user.id, set_kodu=set_kodu,
        adim_kodu=adim_kodu, surum=v.surum,
    )
    await db.execute(
        ifade.on_conflict_do_update(
            index_elements=["tenant_id", "user_id", "set_kodu", "adim_kodu"],
            set_={"surum": v.surum, "izlendi_at": text("now()")},
        )
    )
    return Response(status_code=204)


# ============================ PANEL (admin) ================================ #
@router.get("/yonetim", response_model=EgitimVideoYonetimListe)
async def yonetim_listesi(
    set_kodu: str = Query("yonetici", alias="set", pattern=r"^[a-z_]{1,30}$"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> EgitimVideoYonetimListe:
    adimlar = _set_dogrula(set_kodu)
    return EgitimVideoYonetimListe(
        set_kodu=set_kodu, adimlar=list(adimlar), videolar=await _videolar(db, set_kodu)
    )


@router.put("/yonetim/{adim_kodu}", response_model=EgitimVideosuOut)
async def yonetim_kaydet(
    adim_kodu: str,
    body: EgitimVideosuYaz,
    set_kodu: str = Query("yonetici", alias="set", pattern=r"^[a-z_]{1,30}$"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> EgitimVideosuOut:
    """Adimin videosunu yazar. Gecersiz baglanti -> anlasilir 422."""
    _adim_dogrula(set_kodu, adim_kodu)
    kimlik = youtube_kimligi(body.baglanti)
    if kimlik is None:
        raise APIError(422, "validation_error", "youtube_baglantisi_gecersiz")
    satir = (
        await db.execute(
            text(
                "SELECT adim_kodu, youtube_id, baslik, aciklama, sira, aktif, "
                "surum, updated_at FROM public.egitim_videosu_yaz("
                ":s, :a, :y, :b, :ac, :si, :ak, :k)"
            ),
            {"s": set_kodu, "a": adim_kodu, "y": kimlik, "b": body.baslik,
             "ac": body.aciklama, "si": body.sira, "ak": body.aktif, "k": user.id},
        )
    ).mappings().one()
    await audit_user(
        db, user, Action.EGITIM_VIDEOSU, resource_type="egitim_videosu",
        resource_id=None,
        meta={"set": set_kodu, "adim": adim_kodu, "youtube_id": kimlik,
              "aktif": body.aktif, "surum": satir["surum"]},
    )
    return EgitimVideosuOut(**dict(satir))


@router.delete("/yonetim/{adim_kodu}", status_code=204, response_class=Response)
async def yonetim_sil(
    adim_kodu: str,
    set_kodu: str = Query("yonetici", alias="set", pattern=r"^[a-z_]{1,30}$"),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN),
) -> Response:
    _adim_dogrula(set_kodu, adim_kodu)
    silindi = (
        await db.execute(
            text("SELECT public.egitim_videosu_sil(:s, :a)"),
            {"s": set_kodu, "a": adim_kodu},
        )
    ).scalar_one()
    if not silindi:
        raise APIError(404, "not_found", "egitim_videosu_yok")
    await audit_user(
        db, user, Action.EGITIM_VIDEOSU, resource_type="egitim_videosu",
        resource_id=None, meta={"set": set_kodu, "adim": adim_kodu, "silindi": True},
    )
    return Response(status_code=204)
