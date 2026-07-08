"""POST /uploads/presign — foto yukleme icin presigned PUT URL.

RBAC: admin/security/tesis_gorevlisi (completion gonderebilenler). tenant token'dan;
foto_key tenant ile namespace'lenir.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends

from ..deps import require_role
from ..models import AppUser
from ..schemas import PresignRequest, PresignResponse
from ..storage import presign_put

router = APIRouter(prefix="/uploads", tags=["uploads"])

_UPLOADER = require_role("admin", "security", "tesis_gorevlisi")


@router.post("/presign", response_model=PresignResponse)
async def presign(
    body: PresignRequest,
    user: AppUser = Depends(_UPLOADER),
) -> PresignResponse:
    foto_key, upload_url, expires_in = presign_put(
        user.tenant_id, body.content_type, body.dosya_adi
    )
    return PresignResponse(
        foto_key=foto_key, upload_url=upload_url, method="PUT", expires_in=expires_in
    )
