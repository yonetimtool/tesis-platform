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
    Date,
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
NOTIFICATION_TIP = ENUM(
    "kacirilan_tur", "eksik_checkpoint", "gecikmis_okutma",
    "peyzaj_yaklasan", "peyzaj_kacirilan",
    name="notification_tip", create_type=False,
)
TASK_TIP = ENUM(
    "temizlik", "kontrol", "ilaclama", "bakim", "peyzaj", "diger",
    name="task_tip", create_type=False,
)
ASSET_KATEGORI = ENUM(
    "ekipman", "arac", "alet", "diger",
    name="asset_kategori", create_type=False,
)
ASSET_DURUM = ENUM(
    "musait", "zimmetli", "bakimda",
    name="asset_durum", create_type=False,
)
EMERGENCY_DURUM = ENUM(
    "acik", "cozuldu",
    name="emergency_durum", create_type=False,
)
RESIDENT_ROL = ENUM(
    "malik", "kiraci",
    name="resident_rol", create_type=False,
)
DUES_YONTEM = ENUM(
    "elden", "havale", "kart", "diger",
    name="dues_yontem", create_type=False,
)
DUES_DURUM = ENUM(
    "basarili", "bekliyor", "iptal",
    name="dues_durum", create_type=False,
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
    __table_args__ = (
        UniqueConstraint("slug", name="uq_tenant_slug"),
    )

    id: Mapped[uuid.UUID] = _pk()
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    # Login tenant'i bu slug ile belirler (bkz. /contracts/auth.md §1.1).
    slug: Mapped[str] = mapped_column(Text, nullable=False)
    timezone: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("'Europe/Istanbul'")
    )
    # acil durumda mobilin arayacagi yonetim numarasi.
    acil_durum_telefon: Mapped[str | None] = mapped_column(Text, nullable=True)
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


# --------------------------------------------------------------------------- #
class Notification(Base):
    __tablename__ = "notification"
    __table_args__ = (
        # DDL'de kolon-ozel ON DELETE SET NULL (<kolon>) — sadece ilgili FK kolonu
        # NULL'lanir, paylasilan NOT NULL tenant_id korunur (DDL kaynagi /contracts).
        ForeignKeyConstraint(
            ["patrol_window_id", "tenant_id"],
            ["patrol_window.id", "patrol_window.tenant_id"],
            ondelete="SET NULL",
            name="fk_notification_window",
        ),
        ForeignKeyConstraint(
            ["patrol_plan_id", "tenant_id"],
            ["patrol_plan.id", "patrol_plan.tenant_id"],
            ondelete="SET NULL",
            name="fk_notification_plan",
        ),
        ForeignKeyConstraint(
            ["checkpoint_id", "tenant_id"],
            ["checkpoint.id", "checkpoint.tenant_id"],
            ondelete="SET NULL",
            name="fk_notification_checkpoint",
        ),
        UniqueConstraint(
            "tenant_id", "tip", "patrol_window_id",
            name="uq_notification_tenant_tip_window",
        ),
        UniqueConstraint("tenant_id", "dedup_key", name="uq_notification_dedup"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenant.id", ondelete="CASCADE"),
        nullable=False,
    )
    tip: Mapped[str] = mapped_column(NOTIFICATION_TIP, nullable=False)
    patrol_window_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    patrol_plan_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    checkpoint_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    task_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    dedup_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    mesaj: Mapped[str] = mapped_column(Text, nullable=False)
    okundu: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class Task(Base):
    __tablename__ = "task"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_task_id_tenant"),
        CheckConstraint(
            "periyot_dakika IS NULL OR periyot_dakika > 0", name="ck_task_periyot"
        ),
        # DDL'de kolon-ozel ON DELETE SET NULL (<kolon>) — tenant_id korunur.
        ForeignKeyConstraint(
            ["atanan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="SET NULL",
            name="fk_task_atanan",
        ),
        ForeignKeyConstraint(
            ["checkpoint_id", "tenant_id"],
            ["checkpoint.id", "checkpoint.tenant_id"],
            ondelete="SET NULL",
            name="fk_task_checkpoint",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    tip: Mapped[str] = mapped_column(TASK_TIP, nullable=False)
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    aciklama: Mapped[str | None] = mapped_column(Text, nullable=True)
    atanan_user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    checkpoint_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    periyot_dakika: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sonraki_planlanan = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    aktif: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class TaskCompletion(Base):
    __tablename__ = "task_completion"
    __table_args__ = (
        ForeignKeyConstraint(
            ["task_id", "tenant_id"],
            ["task.id", "task.tenant_id"],
            ondelete="CASCADE",
            name="fk_completion_task",
        ),
        ForeignKeyConstraint(
            ["tamamlayan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_completion_user",
        ),
        UniqueConstraint(
            "tenant_id", "idempotency_key", name="uq_completion_tenant_idempotency"
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    task_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    tamamlayan_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    tamamlanma_zamani = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    nfc_tag_uid: Mapped[str | None] = mapped_column(Text, nullable=True)
    gps_lat = mapped_column(Numeric(9, 6), nullable=True)
    gps_lng = mapped_column(Numeric(9, 6), nullable=True)
    foto_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    foto_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    notlar: Mapped[str | None] = mapped_column(Text, nullable=True)
    idempotency_key: Mapped[str] = mapped_column(Text, nullable=False)
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class Asset(Base):
    __tablename__ = "asset"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_asset_id_tenant"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    kategori: Mapped[str | None] = mapped_column(ASSET_KATEGORI, nullable=True)
    nfc_tag_uid: Mapped[str | None] = mapped_column(Text, nullable=True)
    durum: Mapped[str] = mapped_column(
        ASSET_DURUM, nullable=False, server_default=text("'musait'")
    )
    aciklama: Mapped[str | None] = mapped_column(Text, nullable=True)
    aktif: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class AssetCheckout(Base):
    __tablename__ = "asset_checkout"
    __table_args__ = (
        ForeignKeyConstraint(
            ["asset_id", "tenant_id"],
            ["asset.id", "asset.tenant_id"],
            ondelete="CASCADE",
            name="fk_checkout_asset",
        ),
        ForeignKeyConstraint(
            ["alan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_checkout_user",
        ),
        UniqueConstraint(
            "tenant_id", "idempotency_key", name="uq_checkout_tenant_idempotency"
        ),
        # Tek aktif zimmet (acik checkout) + birakma idempotency partial-unique index'leri
        # DDL'de (/contracts) tanimli; burada sadece sorgu aynasi.
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    asset_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    alan_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    alma_zamani = mapped_column(TIMESTAMP(timezone=True), nullable=False, server_default=text("now()"))
    birakma_zamani = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    alma_nfc_tag_uid: Mapped[str | None] = mapped_column(Text, nullable=True)
    birakma_nfc_tag_uid: Mapped[str | None] = mapped_column(Text, nullable=True)
    alma_gps_lat = mapped_column(Numeric(9, 6), nullable=True)
    alma_gps_lng = mapped_column(Numeric(9, 6), nullable=True)
    birakma_gps_lat = mapped_column(Numeric(9, 6), nullable=True)
    birakma_gps_lng = mapped_column(Numeric(9, 6), nullable=True)
    notlar: Mapped[str | None] = mapped_column(Text, nullable=True)
    idempotency_key: Mapped[str] = mapped_column(Text, nullable=False)
    birakma_idempotency_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class EmergencyAlert(Base):
    __tablename__ = "emergency_alert"
    __table_args__ = (
        ForeignKeyConstraint(
            ["tetikleyen_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_emergency_tetikleyen",
        ),
        # DDL'de kolon-ozel ON DELETE SET NULL (cozen_user_id); tenant_id korunur.
        ForeignKeyConstraint(
            ["cozen_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="SET NULL",
            name="fk_emergency_cozen",
        ),
        UniqueConstraint(
            "tenant_id", "idempotency_key", name="uq_emergency_tenant_idempotency"
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    tetikleyen_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    tetiklenme_zamani = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default=text("now()")
    )
    gps_lat = mapped_column(Numeric(9, 6), nullable=True)
    gps_lng = mapped_column(Numeric(9, 6), nullable=True)
    durum: Mapped[str] = mapped_column(
        EMERGENCY_DURUM, nullable=False, server_default=text("'acik'")
    )
    cozen_user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    cozulme_zamani = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    notlar: Mapped[str | None] = mapped_column(Text, nullable=True)
    idempotency_key: Mapped[str] = mapped_column(Text, nullable=False)
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class Unit(Base):
    __tablename__ = "unit"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_unit_id_tenant"),
        UniqueConstraint("tenant_id", "no", name="uq_unit_tenant_no"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    no: Mapped[str] = mapped_column(Text, nullable=False)
    blok: Mapped[str | None] = mapped_column(Text, nullable=True)
    metrekare = mapped_column(Numeric(8, 2), nullable=True)
    aktif: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class UnitResident(Base):
    __tablename__ = "unit_resident"
    __table_args__ = (
        ForeignKeyConstraint(
            ["unit_id", "tenant_id"],
            ["unit.id", "unit.tenant_id"],
            ondelete="CASCADE",
            name="fk_unitresident_unit",
        ),
        ForeignKeyConstraint(
            ["user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="CASCADE",
            name="fk_unitresident_user",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    rol_tipi: Mapped[str | None] = mapped_column(RESIDENT_ROL, nullable=True)
    baslangic = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    bitis = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class DuesAssessment(Base):
    __tablename__ = "dues_assessment"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_assessment_id_tenant"),
        CheckConstraint("tutar_kurus > 0", name="ck_assessment_tutar"),
        ForeignKeyConstraint(
            ["unit_id", "tenant_id"],
            ["unit.id", "unit.tenant_id"],
            ondelete="CASCADE",
            name="fk_assessment_unit",
        ),
        UniqueConstraint(
            "tenant_id", "unit_id", "donem", name="uq_assessment_tenant_unit_donem"
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    donem: Mapped[str] = mapped_column(Text, nullable=False)
    tutar_kurus: Mapped[int] = mapped_column(Integer, nullable=False)
    son_odeme_tarihi = mapped_column(Date, nullable=True)
    aciklama: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class DuesPayment(Base):
    __tablename__ = "dues_payment"
    __table_args__ = (
        CheckConstraint("tutar_kurus > 0", name="ck_payment_tutar"),
        ForeignKeyConstraint(
            ["unit_id", "tenant_id"],
            ["unit.id", "unit.tenant_id"],
            ondelete="CASCADE",
            name="fk_payment_unit",
        ),
        # DDL'de kolon-ozel ON DELETE SET NULL (assessment_id); tenant_id korunur.
        ForeignKeyConstraint(
            ["assessment_id", "tenant_id"],
            ["dues_assessment.id", "dues_assessment.tenant_id"],
            ondelete="SET NULL",
            name="fk_payment_assessment",
        ),
        ForeignKeyConstraint(
            ["kaydeden_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_payment_kaydeden",
        ),
        UniqueConstraint(
            "tenant_id", "idempotency_key", name="uq_payment_tenant_idempotency"
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    assessment_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    tutar_kurus: Mapped[int] = mapped_column(Integer, nullable=False)
    odeme_zamani = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default=text("now()")
    )
    yontem: Mapped[str] = mapped_column(DUES_YONTEM, nullable=False)
    durum: Mapped[str] = mapped_column(
        DUES_DURUM, nullable=False, server_default=text("'basarili'")
    )
    makbuz_no: Mapped[str | None] = mapped_column(Text, nullable=True)
    provider: Mapped[str | None] = mapped_column(Text, nullable=True)
    provider_ref: Mapped[str | None] = mapped_column(Text, nullable=True)
    kaydeden_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(Text, nullable=False)
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class PaymentWebhookEvent(Base):
    __tablename__ = "payment_webhook_event"
    __table_args__ = (
        UniqueConstraint("tenant_id", "provider", "event_id", name="uq_webhook_event"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    provider: Mapped[str] = mapped_column(Text, nullable=False)
    event_id: Mapped[str] = mapped_column(Text, nullable=False)
    provider_ref: Mapped[str] = mapped_column(Text, nullable=False)
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
    "Notification",
    "Task",
    "TaskCompletion",
    "Asset",
    "AssetCheckout",
    "EmergencyAlert",
    "Unit",
    "UnitResident",
    "DuesAssessment",
    "DuesPayment",
    "PaymentWebhookEvent",
    "USER_ROLE",
    "GUN_TIPI",
    "PATROL_WINDOW_DURUM",
    "NOTIFICATION_TIP",
    "TASK_TIP",
    "ASSET_KATEGORI",
    "ASSET_DURUM",
    "EMERGENCY_DURUM",
    "RESIDENT_ROL",
    "DUES_YONTEM",
    "DUES_DURUM",
]
