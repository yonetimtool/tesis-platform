"""SQLAlchemy modelleri — /contracts/db migration'inin BIRE BIR aynasi.

ONEMLI:
  * DDL'in tek dogruluk kaynagi /contracts/db/migrations'tir. Bu modeller YALNIZCA
    sorgu (ORM) icindir. Bunlardan migration URETILMEZ, autogenerate CALISTIRILMAZ.
  * Native enum tipleri (user_role, gun_tipi, patrol_window_durum) migration
    tarafindan olusturulur => burada create_type=False ile referans verilir.
  * Cross-tenant FK engeli icin composite FK (id, tenant_id) -> (id, tenant_id);
    bu yuzden her parent tabloda UNIQUE (id, tenant_id) bulunur.

Mirror dogrulamasi: kolon adlari/tipleri ve kisitlar 0001_initial_schema.py ile
eslesir.
"""
from __future__ import annotations

import uuid

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    ForeignKey,
    ForeignKeyConstraint,
    Integer,
    Numeric,
    Text,
    Time,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import ENUM, TIMESTAMP, UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


# --- native enum tipleri (migration olusturur; SQLAlchemy yeniden olusturmaz) ---
USER_ROLE = ENUM(
    "admin", "security", "cleaning", "resident",
    name="user_role", create_type=False,
)
GUN_TIPI = ENUM(
    "her_gun", "hafta_ici", "hafta_sonu", "resmi_tatil",
    name="gun_tipi", create_type=False,
)
PATROL_WINDOW_DURUM = ENUM(
    "bekliyor", "tamamlandi", "kacirildi",
    name="patrol_window_durum", create_type=False,
)


def _pk() -> Mapped[uuid.UUID]:
    return mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        server_default=text("gen_random_uuid()"),
    )


def _created_at() -> Mapped["str"]:
    return mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default=text("now()")
    )


# --------------------------------------------------------------------------- #
class Tenant(Base):
    __tablename__ = "tenant"

    id: Mapped[uuid.UUID] = _pk()
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    timezone: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("'Europe/Istanbul'")
    )
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class AppUser(Base):
    __tablename__ = "app_user"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_app_user_id_tenant"),
        UniqueConstraint("tenant_id", "email", name="uq_app_user_tenant_email"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenant.id", ondelete="CASCADE"),
        nullable=False,
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    email: Mapped[str] = mapped_column(Text, nullable=False)
    telefon: Mapped[str | None] = mapped_column(Text, nullable=True)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False)
    role: Mapped[str] = mapped_column(USER_ROLE, nullable=False)
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class Shift(Base):
    __tablename__ = "shift"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_shift_id_tenant"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenant.id", ondelete="CASCADE"),
        nullable=False,
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    # Gun-ici saat (UTC degil; tenant.timezone ile yorumlanir).
    baslangic_saat = mapped_column(Time, nullable=False)
    bitis_saat = mapped_column(Time, nullable=False)
    gun_tipi: Mapped[str] = mapped_column(
        GUN_TIPI, nullable=False, server_default=text("'her_gun'")
    )
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class Checkpoint(Base):
    __tablename__ = "checkpoint"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_checkpoint_id_tenant"),
        UniqueConstraint("tenant_id", "nfc_tag_uid", name="uq_checkpoint_tenant_nfc"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenant.id", ondelete="CASCADE"),
        nullable=False,
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    nfc_tag_uid: Mapped[str] = mapped_column(Text, nullable=False)
    gps_lat = mapped_column(Numeric(9, 6), nullable=True)
    gps_lng = mapped_column(Numeric(9, 6), nullable=True)
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class PatrolPlan(Base):
    __tablename__ = "patrol_plan"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_patrol_plan_id_tenant"),
        CheckConstraint("periyot_dakika > 0", name="ck_patrol_plan_periyot"),
        # DDL'de kolon-ozel: ON DELETE SET NULL (shift_id) — sadece shift_id
        # NULL'lanir, paylasilan NOT NULL tenant_id korunur. SQLAlchemy bu
        # kolon-ozel sozdizimini uretmedigimiz icin (DDL kaynagi /contracts)
        # burada ondelete="SET NULL" yalnizca sorgu/metadata aynasidir.
        ForeignKeyConstraint(
            ["shift_id", "tenant_id"],
            ["shift.id", "shift.tenant_id"],
            ondelete="SET NULL",
            name="fk_patrol_plan_shift",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenant.id", ondelete="CASCADE"),
        nullable=False,
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    shift_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    baslangic_saat = mapped_column(Time, nullable=False)
    bitis_saat = mapped_column(Time, nullable=False)
    periyot_dakika: Mapped[int] = mapped_column(Integer, nullable=False)
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class PatrolPlanCheckpoint(Base):
    __tablename__ = "patrol_plan_checkpoint"
    __table_args__ = (
        ForeignKeyConstraint(
            ["patrol_plan_id", "tenant_id"],
            ["patrol_plan.id", "patrol_plan.tenant_id"],
            ondelete="CASCADE",
            name="fk_ppc_plan",
        ),
        ForeignKeyConstraint(
            ["checkpoint_id", "tenant_id"],
            ["checkpoint.id", "checkpoint.tenant_id"],
            ondelete="CASCADE",
            name="fk_ppc_checkpoint",
        ),
        UniqueConstraint("patrol_plan_id", "sira", name="uq_ppc_plan_sira"),
        CheckConstraint("sira >= 0", name="ck_ppc_sira"),
    )

    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenant.id", ondelete="CASCADE"),
        nullable=False,
    )
    patrol_plan_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True
    )
    checkpoint_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True
    )
    sira: Mapped[int] = mapped_column(Integer, nullable=False)


# --------------------------------------------------------------------------- #
class PatrolWindow(Base):
    __tablename__ = "patrol_window"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_patrol_window_id_tenant"),
        ForeignKeyConstraint(
            ["patrol_plan_id", "tenant_id"],
            ["patrol_plan.id", "patrol_plan.tenant_id"],
            ondelete="CASCADE",
            name="fk_patrol_window_plan",
        ),
        CheckConstraint(
            "pencere_bitis > pencere_baslangic", name="ck_patrol_window_aralik"
        ),
        UniqueConstraint(
            "patrol_plan_id", "pencere_baslangic",
            name="uq_patrol_window_plan_baslangic",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenant.id", ondelete="CASCADE"),
        nullable=False,
    )
    patrol_plan_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    pencere_baslangic = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    pencere_bitis = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    durum: Mapped[str] = mapped_column(
        PATROL_WINDOW_DURUM, nullable=False, server_default=text("'bekliyor'")
    )
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class ScanEvent(Base):
    __tablename__ = "scan_event"
    __table_args__ = (
        ForeignKeyConstraint(
            ["guard_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_scan_guard",
        ),
        ForeignKeyConstraint(
            ["checkpoint_id", "tenant_id"],
            ["checkpoint.id", "checkpoint.tenant_id"],
            ondelete="RESTRICT",
            name="fk_scan_checkpoint",
        ),
        # DDL'de kolon-ozel: ON DELETE SET NULL (patrol_window_id) — sadece
        # patrol_window_id NULL'lanir, paylasilan NOT NULL tenant_id korunur.
        # ondelete="SET NULL" burada yalnizca metadata aynasi (DDL /contracts).
        ForeignKeyConstraint(
            ["patrol_window_id", "tenant_id"],
            ["patrol_window.id", "patrol_window.tenant_id"],
            ondelete="SET NULL",
            name="fk_scan_window",
        ),
        UniqueConstraint(
            "tenant_id", "idempotency_key", name="uq_scan_tenant_idempotency"
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenant.id", ondelete="CASCADE"),
        nullable=False,
    )
    guard_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    checkpoint_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    patrol_window_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    nfc_tag_uid: Mapped[str] = mapped_column(Text, nullable=False)
    okutma_zamani = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    gps_lat = mapped_column(Numeric(9, 6), nullable=True)
    gps_lng = mapped_column(Numeric(9, 6), nullable=True)
    foto_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    imza_dogrulandi: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    idempotency_key: Mapped[str] = mapped_column(Text, nullable=False)
    created_at = _created_at()


__all__ = [
    "Base",
    "Tenant",
    "AppUser",
    "Shift",
    "Checkpoint",
    "PatrolPlan",
    "PatrolPlanCheckpoint",
    "PatrolWindow",
    "ScanEvent",
    "USER_ROLE",
    "GUN_TIPI",
    "PATROL_WINDOW_DURUM",
]
