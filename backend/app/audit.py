"""KVKK denetim kaydi yardimcisi (WP1).

Kullanim (router icinde, tenant-baglamli `db` oturumu ile — AYNI transaction):
    from ..audit import audit_user, Action
    await audit_user(db, user, Action.RESIDENT_CREATE,
                     resource_type="app_user", resource_id=new_id)

Neden ayni-transaction dogrudan INSERT? (1) atomiklik — denetim satiri islem
COMMIT olursa yazilir, ROLLBACK olursa yazilmaz (yaniltici iz olmaz); (2) ucuz —
ekstra baglanti/round-trip yok; (3) app_rw INSERT hakki + set edilmis tenant
baglami sayesinde RLS WITH CHECK gecer. app_rw UPDATE/DELETE ALAMAZ (append-only,
setup_app_role.py REVOKE). Platform/sistem (tenant-siz) olaylar retention task'i
tarafindan owner ile yazilir (RLS bypass).

`meta`: YALNIZ id'ler ve alan ADLARI. ASLA kisisel veri DEGERI konmaz (ad, telefon,
e-posta, parola vb. degerleri denetim kaydina GIRMEZ).
"""
from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from .models import AppUser, AuditLog


class Action:
    """action serbest-metin degerleri (enum degil; merkezi sabitler)."""

    # --- kimlik / oturum ---
    LOGIN_OK = "login_ok"
    LOGIN_FAIL = "login_fail"
    PASSWORD_SET = "password_set"          # ilk giris kalici parola belirleme
    PASSWORD_CHANGE = "password_change"    # oturumlu parola degistirme
    TOKEN_REUSE = "token_reuse"            # refresh yeniden-kullanim (guvenlik)

    # --- kisisel veri kaynaklari (yazma) ---
    RESIDENT_CREATE = "resident_create"
    RESIDENT_UPDATE = "resident_update"
    RESIDENT_DELETE = "resident_delete"    # tam silme (ledger referansi yoksa)
    RESIDENT_ERASURE = "resident_erasure"  # anonimlestirme (ledger korunur)
    RESIDENT_RESET_PASSWORD = "resident_reset_password"
    USER_CREATE = "user_create"
    USER_UPDATE = "user_update"
    USER_RESET_PASSWORD = "user_reset_password"
    USER_CONTACT_UPDATE = "user_contact_update"   # telefon/aranabilir (riza)
    RESIDENT_ASSIGN = "resident_assign"
    RESIDENT_UNASSIGN = "resident_unassign"
    VISITOR_CREATE = "visitor_create"
    VISITOR_UPDATE = "visitor_update"
    KARGO_CREATE = "kargo_create"
    KARGO_RECEIVE = "kargo_receive"
    KARGO_PHOTO_VIEW = "kargo_photo_view"         # foto presign-GET (ifsa)
    UNIT_ACCESS_REQUEST = "unit_access_request"
    UNIT_ACCESS_DECIDE = "unit_access_decide"
    COMPLAINT_CREATE = "complaint_create"
    COMPLAINT_CONVERT = "complaint_convert"
    COMPLAINT_RESOLVE = "complaint_resolve"
    COMPLAINT_DECLINE = "complaint_decline"
    UNIT_COMPLAINT_FILE = "unit_complaint_file"
    UNIT_COMPLAINT_CLOSE = "unit_complaint_close"
    DUES_ASSESSMENT_CREATE = "dues_assessment_create"
    DUES_PAYMENT_RECORD = "dues_payment_record"
    BLOCK_CREATE = "block_create"
    BLOCK_UPDATE = "block_update"
    BLOCK_DELETE = "block_delete"
    UNIT_CREATE = "unit_create"
    UNIT_UPDATE = "unit_update"
    UNIT_DELETE = "unit_delete"

    # --- KVKK-kritik: telefon ifsasi + arama ---
    PHONE_REVEAL = "phone_reveal"
    CALL_INITIATE = "call_initiate"

    # --- seffaflik panosu (yayin kontrolu) ---
    TRANSPARENCY_PUBLISH = "transparency_publish"
    TRANSPARENCY_UNPUBLISH = "transparency_unpublish"

    # --- sistem ---
    EXPORT = "export"
    ERASURE_RUN = "erasure_run"            # retention/imha calismasi (sayilar)


async def record_audit(
    session: AsyncSession,
    *,
    action: str,
    tenant_id: uuid.UUID | str | None = None,
    actor_user_id: uuid.UUID | str | None = None,
    actor_rol: str | None = None,
    resource_type: str | None = None,
    resource_id: uuid.UUID | str | None = None,
    meta: dict[str, Any] | None = None,
) -> None:
    """Denetim satirini AYNI transaction'a ekler (commit ile yazilir)."""
    session.add(
        AuditLog(
            tenant_id=tenant_id,
            actor_user_id=actor_user_id,
            actor_rol=actor_rol,
            action=action,
            resource_type=resource_type,
            resource_id=str(resource_id) if resource_id is not None else None,
            meta=meta or {},
        )
    )


async def audit_user(
    session: AsyncSession,
    user: AppUser,
    action: str,
    *,
    resource_type: str | None = None,
    resource_id: uuid.UUID | str | None = None,
    meta: dict[str, Any] | None = None,
) -> None:
    """Kimlikli aktorden denetim — tenant_id/actor_user_id/actor_rol otomatik."""
    await record_audit(
        session,
        action=action,
        tenant_id=user.tenant_id,
        actor_user_id=user.id,
        actor_rol=user.role,
        resource_type=resource_type,
        resource_id=resource_id,
        meta=meta,
    )
