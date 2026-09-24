"""POST /uploads/presign — foto yukleme icin presigned PUT URL.

RBAC: admin/security/tesis_gorevlisi (completion gonderebilenler) + yonetici
(duyuru gorseli) + resident (sikayet/oneri gorseli). tenant token'dan;
foto_key tenant ile namespace'lenir.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends

from ..deps import require_role
from ..models import AppUser
from ..schemas import PresignRequest, PresignResponse
from ..storage import presign_put, presign_put_anahtar

router = APIRouter(prefix="/uploads", tags=["uploads"])

_UPLOADER = require_role(
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident"
)


@router.post("/presign", response_model=PresignResponse)
async def presign(
    body: PresignRequest,
    user: AppUser = Depends(_UPLOADER),
) -> PresignResponse:
    if body.amac == "belge" and body.content_type == "application/pdf":
        # (E2E 2026-09) BELGE ADI ALANI: `{tenant}/belge/<hex>.pdf`.
        # Uzanti ICERIK TURUNDEN gelir, dosya adindan DEGIL — `rapor.html`
        # adli bir PDF'in anahtari `.html` ile bitmemeli. Gorev
        # fotograflari (`/tasks/`) ile ayni onekte yasamamasi depoda hangi
        # dosyanin ne oldugunu YOLDAN okunur kilar.
        foto_key, upload_url, expires_in = presign_put_anahtar(
            f"{user.tenant_id}/belge/{uuid.uuid4().hex}.pdf", body.content_type
        )
    else:
        foto_key, upload_url, expires_in = presign_put(
            user.tenant_id, body.content_type, body.dosya_adi
        )
    return PresignResponse(
        foto_key=foto_key, upload_url=upload_url, method="PUT", expires_in=expires_in
    )
