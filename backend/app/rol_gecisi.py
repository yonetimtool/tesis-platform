"""(P247 §2) PROFILDEN ROL GECISI — YONETICI <-> SAKIN.

=========================================================================
KURAL: BIR KISI AYNI TESISTE TEK ROL — TEK ISTISNA YONETICI + SAKIN
=========================================================================
Site yoneticisi cogu zaman o sitede oturur. Iki rol ASLA KARISMAZ: kisi
bir anda ya yoneticidir ya sakindir; ekranda karisik durum olusmaz.
Guvenlik+yonetici, gorevli+sakin gibi diger birlesimler YASAK kalir.

=========================================================================
VERI: TEK SATIR (ikinci uyelik satiri DEGIL)
=========================================================================
Telefon PLATFORM genelinde, e-posta TESIS icinde benzersiz: ayni kisiye
ayni tesiste ikinci `app_user` satiri acmak bu kimlik degismezlerini
bozardi (P228: kimlik telefona capali). Bu yuzden rol `app_user.role`da
TEK kalir (`yonetici`); SAKIN MODU yoneticinin bir daireye AKTIF bagi
(`unit_resident`, bitis NULL) oldugunda acilir. Yeni tablo/kolon yok.

=========================================================================
YETKI BAGLAMI: JETONDAKI AKTIF ROL — SUNUCU ZORLAR
=========================================================================
Mod bir arayuz tercihi DEGIL. Erisim jetonunun `role` iddiasi AKTIF
rolu tasir; `get_current_user` her istekte DB rolunu okur ve jeton
`resident` diyorsa YALNIZ su iki kosulda sakin modunu uygular: DB rolu
`yonetici` VE aktif daire bagi var. Aksi hâlde DB rolu gecerlidir
(iddia yok sayilir — jeton uydurularak yetki KAZANILAMAZ, yalniz
DUSURULEBILIR). Sakin modundayken butun `require_role` kapilari sakin
roluyle calisir: yonetici ucu 403 — istemci atlatilsa bile.

Rol degeri bellekte `set_committed_value` ile yazilir: nesne "kirli"
sayilmaz, oturum commit'inde DB'ye YAZILMAZ.

Mod gecisi YENI jeton cifti uretir (yeni yetki baglami); refresh jetonu
modu `arol` iddiasinda tasir — uygulama yeniden acildiginda son mod gelir.
"""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm.attributes import set_committed_value

from .models import AppUser, UnitResident

#: Asil rol -> gecilebilecek IKINCIL rol. Tek istisna bu satirdir.
IKINCIL_ROL: dict[str, str] = {"yonetici": "resident"}


async def rol_secenekleri(db: AsyncSession, user: AppUser) -> list[str]:
    """Kisinin bu tesiste gecebilecegi roller (asil rol HER ZAMAN ilk)."""
    asil = asil_rol(user)
    ikincil = IKINCIL_ROL.get(asil)
    if ikincil is None:
        return [asil]
    bag = (
        await db.execute(
            select(UnitResident.unit_id).where(
                UnitResident.user_id == user.id, UnitResident.bitis.is_(None)
            ).limit(1)
        )
    ).scalar_one_or_none()
    return [asil, ikincil] if bag is not None else [asil]


def asil_rol(user: AppUser) -> str:
    return getattr(user, "_asil_rol", None) or user.role


def aktif_rolu_uygula(user: AppUser, rol: str) -> None:
    """Bellekteki rolu degistir — DB'ye YAZILMAZ (kirli sayilmaz)."""
    if getattr(user, "_asil_rol", None) is None:
        user._asil_rol = user.role  # type: ignore[attr-defined]
    set_committed_value(user, "role", rol)


def ikincil_modda_mi(user: AppUser) -> bool:
    return asil_rol(user) != user.role
