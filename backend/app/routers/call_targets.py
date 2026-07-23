"""Rol-bazli arama hedefi cozumu (C1a) — GET /call-target/{user_id}.

Numara-gizliligi kapisi (KVKK, auth.md §4): callee'nin telefonu YALNIZ
  (1) arayan rol o callee rolunu arayabiliyorsa (CALL_DIRECTIONS) VE
  (2) callee.aranabilir = true iken
aciklanir. Aksi halde numara ASLA donmez (403 yetkisiz yon / 404 aranamiyor).
Amaç-sınırlı (yalniz arama), toplu listelenmez, rizasiz asla.

Kanal soyutlamasi (bkz. app.call_targets): C1a yalniz 'phone' (tel:); C1b
megafon/akilli-ev kanallarini yeniden yazim olmadan ekler.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..call_targets import caller_can_reach, resolve_phone_target
from ..crud_helpers import get_or_404
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser
from ..schemas import CallTargetOut

router = APIRouter(prefix="/call-target", tags=["call-target"])

# Arayan roller (C1a): security + resident. admin/yonetici/tesis_gorevlisi bu
# turda arama BASLATMAZ (403). Yon ayrica CALL_DIRECTIONS'ta zorlanir.
_CALLER = require_role("security", "resident")


@router.get("/{user_id}", response_model=CallTargetOut)
async def resolve_call_target(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_CALLER),
) -> CallTargetOut:
    # Callee ayni tenant'ta olmali (RLS + get_or_404). Baska tenant -> 404.
    callee = await get_or_404(db, AppUser, user_id)

    # Yon kapisi: arayan rol bu callee rolunu arayabiliyor mu? (tam dizin degil)
    if not caller_can_reach(user.role, callee.role):
        raise APIError(
            403, "forbidden", "Bu rolu arama yetkiniz yok."
        )

    # Riza + numara kapisi: riza yoksa/numara yoksa numara ACIKLANMAZ (404).
    target = resolve_phone_target(callee)
    if target is None:
        raise APIError(
            404, "not_found", "Bu kullanici su an aranamiyor."
        )

    # KVKK-kritik iz: telefon IFSASI + arama baslatma (kanal handoff). meta'da
    # NUMARA YOK — yalniz hedef id/rol/kanal. Ayni islemde yazilir (commit ile).
    _call_meta = {"target_user_id": str(callee.id), "target_rol": callee.role,
                  "channel": target.channel}
    await audit_user(db, user, Action.PHONE_REVEAL, resource_type="app_user",
                     resource_id=callee.id, meta=_call_meta)
    await audit_user(db, user, Action.CALL_INITIATE, resource_type="app_user",
                     resource_id=callee.id, meta=_call_meta)

    return CallTargetOut(
        user_id=callee.id,
        ad=target.ad,
        role=target.role,
        channel=target.channel,
        telefon=target.address,
        tel_uri=target.uri,
    )
