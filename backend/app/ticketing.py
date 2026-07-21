"""Talep (ticket) durum makinesi + timeline + bildirim yardimcilari.

Router'lari ince tutar; gecis kurallari tek yerde. Anonimlik YOK — talepler
her zaman kimlikli; history YALNIZ actor_role tutar (user_id asla).
"""
from __future__ import annotations

import uuid

from .errors import APIError
from .models import ComplaintStatusHistory
from .scheduler.notify import dispatch_external

# Gecerli gecisler. cozuldu/reddedildi terminal.
VALID_TRANSITIONS: dict[str, set[str]] = {
    "acik": {"is_emri", "cozuldu", "reddedildi"},
    "is_emri": {"cozuldu"},
    "cozuldu": set(),
    "reddedildi": set(),
}


def assert_transition(current: str, target: str) -> None:
    if target not in VALID_TRANSITIONS.get(current, set()):
        raise APIError(
            422,
            "invalid_transition",
            f"'{current}' -> '{target}' gecersiz gecis",
        )


def add_history(
    db, *, complaint, durum: str, actor_role: str, sebep: str | None
) -> ComplaintStatusHistory:
    """Timeline satiri ekler (flush cagirani yapar). actor_role YALNIZ."""
    row = ComplaintStatusHistory(
        tenant_id=complaint.tenant_id,
        complaint_id=complaint.id,
        durum=durum,
        actor_role=actor_role,
        sebep=sebep,
    )
    db.add(row)
    return row


def notify_opener(
    *,
    complaint,
    tenant_id: uuid.UUID,
    tip: str,
    mesaj: str,
    title: str = "Talep/Ariza",
) -> None:
    """EK push — talebi acana. Hatasi kaydi kirmaz (dispatch_external try/except)."""
    dispatch_external(
        mesaj,
        tenant_id=tenant_id,
        target_user_ids=(complaint.acan_user_id,),
        title=title,
        data={"tip": tip, "complaint_id": str(complaint.id)},
    )
