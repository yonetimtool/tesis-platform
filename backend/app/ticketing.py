"""Talep (ticket) durum makinesi + timeline + bildirim yardimcilari.

Router'lari ince tutar; gecis kurallari tek yerde. Anonimlik YOK — talepler
her zaman kimlikli; history YALNIZ actor_role tutar (user_id asla).
"""
from __future__ import annotations

import uuid

from .errors import APIError
from .models import ComplaintStatusHistory
from .scheduler.notify import dispatch_external

# Gecerli gecisler. cozuldu/reddedildi/geri_alindi terminal.
#
# (P146) `geri_alindi` YALNIZ `acik`tan gelir: talep is emrine donustuyse
# sahada is baslamis olabilir ve geri alma yetim bir gorev birakir. Bu
# kisit burada tek yerde durur — uc onu tekrar etmez, cagirir.
VALID_TRANSITIONS: dict[str, set[str]] = {
    "acik": {"is_emri", "cozuldu", "reddedildi", "geri_alindi"},
    "is_emri": {"cozuldu"},
    "cozuldu": set(),
    "reddedildi": set(),
    "geri_alindi": set(),
}


def assert_transition(current: str, target: str) -> None:
    if target not in VALID_TRANSITIONS.get(current, set()):
        raise APIError(
            422,
            "invalid_transition",
            "gecersiz_durum_gecisi",
            mevcut=current,
            hedef=target,
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
) -> None:
    """EK push — talebi acana. Hatasi kaydi kirmaz (dispatch_external try/except).

    `tip` hem `data.tip` (istemci yonlendirmesi) hem de METIN KIMLIGIDIR
    (tur 16): baslik/govde alicinin CIHAZ dilinde uretilir.
    """
    dispatch_external(
        tip,
        tenant_id=tenant_id,
        target_user_ids=(complaint.acan_user_id,),
        params={"baslik": complaint.baslik},
        data={"tip": tip, "complaint_id": str(complaint.id)},
    )
