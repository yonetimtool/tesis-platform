"""(P253 §D) POST /platform/sikayet-kimlik — RESMI KIMLIK ACMA.

Sikayet edenin kimligi HICBIR site rolune donmez (yonetici dahil). Resmi
bir talep (mahkeme, kolluk, KVKK basvurusu) halinde kimligi yalniz
PLATFORM yoneticisi acabilir:

  * gerekce ZORUNLU (en az 20 karakter — "talep" yazip gecilemesin);
  * HER GORUNTULEME denetime yazilir (ayni sikayeti ikinci kez acmak da
    yeni bir kayittir); kayit o TESISIN denetiminde durur;
  * GET degil POST: kimlik bir sorgu dizesinde, tarayici gecmisinde ya
    da erisim gunlugunde kalmasin; gerekce govdede tasinir.

Site yoneticisine bu yetki VERILMEZ — rol kapisi yalniz `admin`.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import select

from ..audit import Action, record_audit
from ..db import SessionLocal, set_tenant
from ..deps import require_role
from ..errors import APIError
from ..models import AppUser, Unit, UnitComplaint
from ..schemas import SikayetKimlikIstek, SikayetKimlikOut

router = APIRouter(prefix="/platform", tags=["platform"])

_ADMIN = require_role("admin")


@router.post("/sikayet-kimlik", response_model=SikayetKimlikOut)
async def sikayet_kimlik_ac(
    body: SikayetKimlikIstek,
    admin: AppUser = Depends(_ADMIN),
) -> SikayetKimlikOut:
    gerekce = body.gerekce
    async with SessionLocal() as session:
        async with session.begin():
            await set_tenant(session, body.tenant_id)
            obj = (
                await session.execute(
                    select(UnitComplaint).where(UnitComplaint.id == body.sikayet_id)
                )
            ).scalar_one_or_none()
            if obj is None:
                raise APIError(404, "not_found", "kayit_bulunamadi")
            kisi = await session.get(AppUser, obj.complainant_user_id)
            hedef = await session.get(Unit, obj.target_unit_id)
            kaynak = await session.get(Unit, obj.kaynak_unit_id) if obj.kaynak_unit_id else None
            await record_audit(
                session,
                action=Action.SIKAYET_KIMLIK_ACMA,
                tenant_id=body.tenant_id,
                actor_user_id=admin.id,
                actor_rol=admin.role,
                resource_type="unit_complaint",
                resource_id=obj.id,
                meta={"gerekce": gerekce},
            )
            return SikayetKimlikOut(
                sikayet_id=obj.id,
                tenant_id=body.tenant_id,
                hedef_daire=hedef.no if hedef else None,
                kaynak_daire=kaynak.no if kaynak else None,
                kategori=obj.kategori,
                created_at=obj.created_at,
                sikayet_eden_id=obj.complainant_user_id,
                sikayet_eden_ad=kisi.ad if kisi else "-",
                sikayet_eden_telefon=kisi.telefon if kisi else None,
                sikayet_eden_eposta=kisi.email if kisi else None,
            )
