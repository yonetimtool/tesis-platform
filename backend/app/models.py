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
    BigInteger,
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
from sqlalchemy.dialects.postgresql import ENUM, JSONB, TIMESTAMP, UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


# --- native enum tipleri (migration olusturur; SQLAlchemy yeniden olusturmaz) ---
USER_ROLE = ENUM(
    "admin", "yonetici", "security", "tesis_gorevlisi", "resident",
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
    "peyzaj_yaklasan", "peyzaj_kacirilan", "acil_durum",
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
COMPLAINT_DURUM = ENUM(
    "acik", "inceleniyor", "cozuldu",
    name="complaint_durum", create_type=False,
)
COMPLAINT_KATEGORI = ENUM(
    "gurultu", "goruntu", "diger",
    name="complaint_kategori", create_type=False,
)
RESIDENT_ROL = ENUM(
    "malik", "kiraci",
    name="resident_rol", create_type=False,
)
DUES_YONTEM = ENUM(
    "elden", "havale", "kart", "diger",
    name="dues_yontem", create_type=False,
)
BUDGET_TIP = ENUM(
    "gelir", "gider",
    name="budget_tip", create_type=False,
)
BUDGET_KAYNAK = ENUM(
    "manuel", "aidat_odeme",
    name="budget_kaynak", create_type=False,
)
DUES_DURUM = ENUM(
    "basarili", "bekliyor", "iptal",
    name="dues_durum", create_type=False,
)
DEVICE_PLATFORM = ENUM(
    "android", "ios", "web",
    name="device_platform", create_type=False,
)
# (visitor_durum kaldirildi — ziyaretci artik LOG-ONLY, onay/red akisi yok.)
KARGO_DURUM = ENUM(
    "bekliyor", "teslim_alindi",
    name="kargo_durum", create_type=False,
)
ACCESS_REQUEST_DURUM = ENUM(
    "bekliyor", "onaylandi", "reddedildi",
    name="access_request_durum", create_type=False,
)
REZERVASYON_DURUM = ENUM(
    "bekliyor", "onaylandi", "reddedildi",
    name="rezervasyon_durum", create_type=False,
)
KATILIM_DURUM = ENUM(
    "katiliyorum", "katilmiyorum",
    name="katilim_durum", create_type=False,
)
INTEGRATION_CHANNEL = ENUM(
    "webhook", "megaphone", "smarthome",
    name="integration_channel", create_type=False,
)
UNIT_COMPLAINT_KATEGORI = ENUM(
    "gurultu", "kapi_onu_ayakkabi", "zarar_verme", "diger",
    name="unit_complaint_kategori", create_type=False,
)
UNIT_COMPLAINT_DURUM = ENUM(
    "acik", "kapali",
    name="unit_complaint_durum", create_type=False,
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
    # personel icin zorunlu (login anahtari); resident icin opsiyonel.
    email: Mapped[str | None] = mapped_column(Text, nullable=True)
    telefon: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Rol-bazli arama rizasi (C1a): numara YALNIZ riza=true iken ve yetkili
    # arayan role /call-target ile aciklanir (KVKK — amaç-sınırlı).
    aranabilir: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    # resident ilk giriste parola belirleyene kadar NULL.
    password_hash: Mapped[str | None] = mapped_column(Text, nullable=True)
    # sakinin tek seferlik gecici giris kodu (bcrypt hash; duz metin yok).
    temp_code_hash: Mapped[str | None] = mapped_column(Text, nullable=True)
    # sakin kalici parolasini belirledi mi (ilk giris akisi tamamlandi mi)?
    password_set: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
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
    # NTAG424 SDM: AES-128 etiket anahtari (SDM_KEK ile AES-GCM sifreli, base64).
    # NULL = SDM provision edilmemis. sdm_son_sayac = replay korumasi.
    sdm_key_sifreli: Mapped[str | None] = mapped_column(Text, nullable=True)
    sdm_son_sayac: Mapped[int] = mapped_column(
        BigInteger, nullable=False, server_default=text("0")
    )
    created_at = _created_at()
    updated_at = _created_at()

    @property
    def sdm_aktif(self) -> bool:
        return self.sdm_key_sifreli is not None


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
class TaskCategory(Base):
    """Yonetici-tanimli gorev kategorisi (A6) — tenant'a ozel, soft-delete."""

    __tablename__ = "task_category"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_task_category_id_tenant"),
        UniqueConstraint("tenant_id", "ad", name="uq_task_category_tenant_ad"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    aktif: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    created_at = _created_at()
    updated_at = mapped_column(TIMESTAMP(timezone=True), nullable=True)


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
        ForeignKeyConstraint(
            ["kategori_id", "tenant_id"],
            ["task_category.id", "task_category.tenant_id"],
            ondelete="SET NULL",
            name="fk_task_kategori",
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
    kategori_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    periyot_dakika: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sonraki_planlanan = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    foto_zorunlu: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
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
        # DDL'de kolon-ozel ON DELETE SET NULL (birakan_user_id) — tenant_id korunur.
        ForeignKeyConstraint(
            ["birakan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="SET NULL",
            name="fk_checkout_birakan",
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
    birakan_user_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
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
    # Fiziksel yerlesim (bina semasi / yogunluk haritasi icin) — hepsi
    # nullable; yerlesimi girilmemis daire haritada "yerlesimsiz" kovadadir.
    kat: Mapped[int | None] = mapped_column(Integer, nullable=True)  # kat (0=zemin)
    sira: Mapped[int | None] = mapped_column(Integer, nullable=True)  # kattaki sira/konum
    metrekare = mapped_column(Numeric(8, 2), nullable=True)
    aktif: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class BuildingBlock(Base):
    """Bina blok kaydi (D-viz Rev-1) — yonetici/admin blok tanimlar; Rev-2
    gorsel editoru bu bloklara kat/daire yerlestirir. Blok-suz siteler bu
    tabloyu kullanmaz (unit.blok NULL). Etiket unit.blok ile eslesir (zayif
    baglanti; hard FK yok — blok-suz + blok-tabanli siteler birlikte)."""

    __tablename__ = "building_block"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_building_block_id_tenant"),
        UniqueConstraint("tenant_id", "ad", name="uq_building_block_tenant_ad"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)  # blok etiketi
    kat_sayisi: Mapped[int | None] = mapped_column(Integer, nullable=True)
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
        # composite FK hedefi (budget_entry.ilgili_payment_id).
        UniqueConstraint("id", "tenant_id", name="uq_payment_id_tenant"),
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
    donem: Mapped[str | None] = mapped_column(Text, nullable=True)
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
class BudgetCategory(Base):
    """Dinamik gelir/gider kategorisi (butce — Wave 2A).

    Silme = SOFT-DELETE (aktif=false): hareketi olan kategori hard-delete
    edilemez (budget_entry FK RESTRICT) — gecmis kayitlar kategorisini korur.
    """

    __tablename__ = "budget_category"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_budgetcat_id_tenant"),
        UniqueConstraint("tenant_id", "tip", "ad", name="uq_budgetcat_tenant_tip_ad"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    tip: Mapped[str] = mapped_column(BUDGET_TIP, nullable=False)
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class BudgetEntry(Base):
    """Butce defteri kaydi. Para INTEGER KURUS (dues ile ayni desen).

    kaynak='aidat_odeme' kayitlari basarili aidat odemesinden OTOMATIK uretilir
    ve ilgili_payment_id tasir; UNIQUE (tenant_id, ilgili_payment_id) ayni
    odemeden ikinci kaydi engeller (idempotency).
    """

    __tablename__ = "budget_entry"
    __table_args__ = (
        CheckConstraint("tutar_kurus > 0", name="ck_budget_entry_tutar"),
        UniqueConstraint("id", "tenant_id", name="uq_budget_entry_id_tenant"),
        UniqueConstraint(
            "tenant_id", "ilgili_payment_id", name="uq_budget_entry_payment"
        ),
        ForeignKeyConstraint(
            ["kategori_id", "tenant_id"],
            ["budget_category.id", "budget_category.tenant_id"],
            ondelete="RESTRICT",
            name="fk_budget_entry_kategori",
        ),
        # DDL'de kolon-ozel ON DELETE SET NULL (ilgili_payment_id).
        ForeignKeyConstraint(
            ["ilgili_payment_id", "tenant_id"],
            ["dues_payment.id", "dues_payment.tenant_id"],
            ondelete="SET NULL",
            name="fk_budget_entry_payment",
        ),
        ForeignKeyConstraint(
            ["created_by", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_budget_entry_created_by",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    kategori_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    # Kategoriden kopyalanir (denormalize) — bkz. migration notu.
    tip: Mapped[str] = mapped_column(BUDGET_TIP, nullable=False)
    tutar_kurus: Mapped[int] = mapped_column(Integer, nullable=False)
    tarih = mapped_column(Date, nullable=False)
    aciklama: Mapped[str | None] = mapped_column(Text, nullable=True)
    kaynak: Mapped[str] = mapped_column(
        BUDGET_KAYNAK, nullable=False, server_default=text("'manuel'")
    )
    ilgili_payment_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    created_by: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    created_at = _created_at()
    updated_at = _created_at()


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


class Announcement(Base):
    __tablename__ = "announcement"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_announcement_id_tenant"),
        ForeignKeyConstraint(
            ["olusturan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_announcement_olusturan",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    baslik: Mapped[str] = mapped_column(Text, nullable=False)
    govde: Mapped[str] = mapped_column(Text, nullable=False)
    # Opsiyonel gorsel — /uploads/presign ile yuklenen MinIO obje anahtari.
    foto_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    olusturan_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class Complaint(Base):
    """Sikayet/oneri — sakin -> yonetim talep kanali (auth.md §4)."""

    __tablename__ = "complaint"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_complaint_id_tenant"),
        ForeignKeyConstraint(
            ["acan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_complaint_acan",
        ),
        # DDL'de kolon-ozel ON DELETE SET NULL (yanitlayan_user_id); tenant_id korunur.
        ForeignKeyConstraint(
            ["yanitlayan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="SET NULL",
            name="fk_complaint_yanitlayan",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    acan_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    baslik: Mapped[str] = mapped_column(Text, nullable=False)
    mesaj: Mapped[str] = mapped_column(Text, nullable=False)
    # Opsiyonel gorsel — /uploads/presign ile yuklenen MinIO obje anahtari.
    foto_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Opsiyonel tur (gurultu/goruntu kirliligi vb.); NULL = belirtilmemis
    # (eski kayitlar — geriye uyumlu).
    kategori: Mapped[str | None] = mapped_column(COMPLAINT_KATEGORI, nullable=True)
    durum: Mapped[str] = mapped_column(
        COMPLAINT_DURUM, nullable=False, server_default=text("'acik'")
    )
    yonetici_yaniti: Mapped[str | None] = mapped_column(Text, nullable=True)
    yanitlayan_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    yanit_zamani = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    created_at = _created_at()
    updated_at = _created_at()


class Visitor(Base):
    """Ziyaretci LOG kaydi — guvenlik kaydeder, dairenin TEK hedef sakinine
    BILGILENDIRME push'u gider. Onay/red YOKTUR; kayit bir gunluk girisidir.

    GSM'e hazir: hedef sakinin telefonu app_user.telefon'da; ileride gercek
    arama adimi ayri kolon/tablo ile eklenebilir (bkz. migration notu).
    """

    __tablename__ = "visitor"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_visitor_id_tenant"),
        ForeignKeyConstraint(
            ["unit_id", "tenant_id"],
            ["unit.id", "unit.tenant_id"],
            ondelete="CASCADE",
            name="fk_visitor_unit",
        ),
        ForeignKeyConstraint(
            ["kaydeden_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_visitor_kaydeden",
        ),
        ForeignKeyConstraint(
            ["target_resident_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_visitor_target",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    ziyaretci_ad: Mapped[str] = mapped_column(Text, nullable=False)
    notlar: Mapped[str | None] = mapped_column(Text, nullable=True)
    kaydeden_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    # Guvenligin sectigi TEK hedef sakin: bilgilendirme push'u + gorunurluk YALNIZ onda.
    target_resident_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )
    created_at = _created_at()


class Kargo(Base):
    """Kargo/paket takibi — guvenlik kaydeder, dairenin sakini teslim alir.

    visitor ile ayni desen (unit-bazli, push, tam gecmis); akis onay/red degil
    TESLIM: bekliyor -> teslim_alindi. Opsiyonel paket fotografi mevcut
    presign akisiyla yuklenir (foto_key; task/complaint/announcement deseni).
    """

    __tablename__ = "kargo"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_kargo_id_tenant"),
        ForeignKeyConstraint(
            ["unit_id", "tenant_id"],
            ["unit.id", "unit.tenant_id"],
            ondelete="CASCADE",
            name="fk_kargo_unit",
        ),
        ForeignKeyConstraint(
            ["kaydeden_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_kargo_kaydeden",
        ),
        # DDL'de kolon-ozel ON DELETE SET NULL (teslim_alan_user_id); tenant_id korunur.
        ForeignKeyConstraint(
            ["teslim_alan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="SET NULL",
            name="fk_kargo_teslim_alan",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    firma: Mapped[str] = mapped_column(Text, nullable=False)
    foto_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    notlar: Mapped[str | None] = mapped_column(Text, nullable=True)
    durum: Mapped[str] = mapped_column(
        KARGO_DURUM, nullable=False, server_default=text("'bekliyor'")
    )
    kaydeden_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    teslim_alan_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    teslim_zamani = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    created_at = _created_at()


class UnitAccessPermission(Base):
    """Yonetici TEK-SEFERLIK ziyaretci/paket goruntuleme izni.

    Gizlilik: ziyaretci/kargo VARSAYILAN olarak yonetici'ye kapali. Yonetici
    bir daireye izin TALEBI acar -> dairenin sakini onaylar/reddeder. Onay =
    tek-kullanimlik izin (used=false); yonetici o dairenin kayitlarini ILK
    okudugunda tuketilir (used=true). Sureye bagli DEGIL (one-shot).
    Tek satir talep+izin yasam dongusunu tutar (durum).
    """

    __tablename__ = "unit_access_permission"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_uap_id_tenant"),
        ForeignKeyConstraint(
            ["unit_id", "tenant_id"],
            ["unit.id", "unit.tenant_id"],
            ondelete="CASCADE",
            name="fk_uap_unit",
        ),
        ForeignKeyConstraint(
            ["granted_to_yonetici_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_uap_yonetici",
        ),
        # DDL'de kolon-ozel ON DELETE SET NULL (granted_by_resident_user_id).
        ForeignKeyConstraint(
            ["granted_by_resident_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="SET NULL",
            name="fk_uap_resident",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    granted_to_yonetici_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )
    granted_by_resident_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    durum: Mapped[str] = mapped_column(
        ACCESS_REQUEST_DURUM, nullable=False, server_default=text("'bekliyor'")
    )
    used: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    requested_at = _created_at()
    decided_at = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    used_at = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    created_at = _created_at()


class OrtakAlan(Base):
    """Rezerve edilebilir ortak alan (havuz/teras/toplanti odasi).

    Silme = SOFT-DELETE (aktif=false): rezervasyon gecmisi alanini korur
    (rezervasyon.alan_id FK RESTRICT hard-delete'i engeller).
    """

    __tablename__ = "ortak_alan"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_ortak_alan_id_tenant"),
        UniqueConstraint("tenant_id", "ad", name="uq_ortak_alan_tenant_ad"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    aciklama: Mapped[str | None] = mapped_column(Text, nullable=True)
    aktif: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("true")
    )
    created_at = _created_at()


# --------------------------------------------------------------------------- #
class Rezervasyon(Base):
    """Ortak alan rezervasyonu — sakin talep eder, yonetici karar verir.

    Cakisma engeli DB'de: partial EXCLUDE (gist) — ayni alanin ONAYLI iki
    rezervasyonu zaman araliginda kesisemez (bkz. migration 9z5). Kisit
    yalniz durum='onaylandi' satirlara uygulanir: bekleyen talepler ust uste
    binebilir, onaya kaldirma aninda es zamanli iki cakisan onaydan yalniz
    biri basarir (digeri 23P01 -> API 409).
    """

    __tablename__ = "rezervasyon"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_rezervasyon_id_tenant"),
        CheckConstraint("bitis > baslangic", name="ck_rezervasyon_aralik"),
        CheckConstraint("kisi_sayisi > 0", name="ck_rezervasyon_kisi"),
        ForeignKeyConstraint(
            ["alan_id", "tenant_id"],
            ["ortak_alan.id", "ortak_alan.tenant_id"],
            ondelete="RESTRICT",
            name="fk_rezervasyon_alan",
        ),
        ForeignKeyConstraint(
            ["unit_id", "tenant_id"],
            ["unit.id", "unit.tenant_id"],
            ondelete="CASCADE",
            name="fk_rezervasyon_unit",
        ),
        ForeignKeyConstraint(
            ["talep_eden_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_rezervasyon_talep_eden",
        ),
        # DDL'de kolon-ozel ON DELETE SET NULL (onaylayan_user_id); tenant_id korunur.
        ForeignKeyConstraint(
            ["onaylayan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="SET NULL",
            name="fk_rezervasyon_onaylayan",
        ),
        # EXCLUDE USING gist kisiti DDL'de (/contracts); SQLAlchemy'de yalniz
        # dokumantasyon — sorgu katmani kisiti uretmez.
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    alan_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    talep_eden_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )
    tarih = mapped_column(Date, nullable=False)
    baslangic = mapped_column(Time, nullable=False)
    bitis = mapped_column(Time, nullable=False)
    kisi_sayisi: Mapped[int] = mapped_column(Integer, nullable=False)
    notlar: Mapped[str | None] = mapped_column(Text, nullable=True)
    durum: Mapped[str] = mapped_column(
        REZERVASYON_DURUM, nullable=False, server_default=text("'bekliyor'")
    )
    onaylayan_user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), nullable=True
    )
    karar_zamani = mapped_column(TIMESTAMP(timezone=True), nullable=True)
    created_at = _created_at()


class Etkinlik(Base):
    """Etkinlik (cenaze/mac izleme vb.) — yonetici olusturur, sakinler RSVP.

    Katilim SAYISI seffaftir (herkes gorur); kim-katiliyor listesi URUN
    GEREGI paylasilmaz — yalniz sayi (bkz. routers/events.py).
    """

    __tablename__ = "etkinlik"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_etkinlik_id_tenant"),
        ForeignKeyConstraint(
            ["olusturan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_etkinlik_olusturan",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    baslik: Mapped[str] = mapped_column(Text, nullable=False)
    aciklama: Mapped[str] = mapped_column(Text, nullable=False)
    tarih = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    konum: Mapped[str | None] = mapped_column(Text, nullable=True)
    olusturan_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )
    created_at = _created_at()
    updated_at = _created_at()


# --------------------------------------------------------------------------- #
class EtkinlikKatilim(Base):
    """Etkinlik RSVP'si — kullanici basina TEK kayit (UNIQUE), degistirilebilir
    (upsert). Etkinlik silinince RSVP'ler CASCADE ile gider."""

    __tablename__ = "etkinlik_katilim"
    __table_args__ = (
        ForeignKeyConstraint(
            ["etkinlik_id", "tenant_id"],
            ["etkinlik.id", "etkinlik.tenant_id"],
            ondelete="CASCADE",
            name="fk_katilim_etkinlik",
        ),
        ForeignKeyConstraint(
            ["user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="CASCADE",
            name="fk_katilim_user",
        ),
        UniqueConstraint(
            "tenant_id", "etkinlik_id", "user_id",
            name="uq_katilim_tenant_etkinlik_user",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    etkinlik_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    durum: Mapped[str] = mapped_column(KATILIM_DURUM, nullable=False)
    created_at = _created_at()
    updated_at = _created_at()


class SiteKurali(Base):
    """Site kurali — blog-tarzi icerik (yonetici CRUD, herkes okur).

    sira ile siralanir; baslikta ILIKE arama (router). Silme HARD DELETE:
    salt icerik — operasyonel gecmis/FK tasimaz (karar, bkz. migration 9z7).
    """

    __tablename__ = "site_kurali"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_site_kurali_id_tenant"),
        CheckConstraint("sira >= 0", name="ck_site_kurali_sira"),
        ForeignKeyConstraint(
            ["olusturan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_site_kurali_olusturan",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    baslik: Mapped[str] = mapped_column(Text, nullable=False)
    icerik: Mapped[str] = mapped_column(Text, nullable=False)
    foto_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    sira: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default=text("0")
    )
    olusturan_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )
    created_at = _created_at()
    updated_at = _created_at()


class UserDevice(Base):
    __tablename__ = "user_device"
    __table_args__ = (
        ForeignKeyConstraint(
            ["user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="CASCADE",
            name="fk_user_device_user",
        ),
        UniqueConstraint("tenant_id", "fcm_token", name="uq_user_device_tenant_token"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    fcm_token: Mapped[str] = mapped_column(Text, nullable=False)
    platform: Mapped[str] = mapped_column(DEVICE_PLATFORM, nullable=False)
    aktif: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    created_at = _created_at()
    updated_at = _created_at()


class Integration(Base):
    """Dis sistem entegrasyon konfigurasyonu (C1b).

    admin/yonetici bir dis ucu (megafon/akilli-ev/generic webhook) tanimlar;
    tetiklenince SSRF-korumali HTTP istegi gonderilir. `auth_secret_enc` KEK ile
    sifreli saklanir ve GET'te ASLA donmez (write-only). channel_type C1a kanal
    soyutlamasini genisletir (phone + webhook/megaphone/smarthome).
    """

    __tablename__ = "integration"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_integration_id_tenant"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    channel_type: Mapped[str] = mapped_column(
        INTEGRATION_CHANNEL, nullable=False, server_default=text("'webhook'")
    )
    endpoint_url: Mapped[str] = mapped_column(Text, nullable=False)
    http_method: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("'POST'")
    )
    headers_json: Mapped[dict] = mapped_column(
        JSONB, nullable=False, server_default=text("'{}'::jsonb")
    )
    auth_type: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("'none'")
    )
    # KEK ile sifreli auth sirri (write-only); GET yanitinda donmez.
    auth_secret_enc: Mapped[str | None] = mapped_column(Text, nullable=True)
    payload_template: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("''")
    )
    aktif: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    created_at = _created_at()
    updated_at = _created_at()


class UnitComplaint(Base):
    """Sakin -> HEDEF DAIRE sikayeti (D1). TAM ANONIM.

    `complainant_user_id` YALNIZ ic spam korumasi + RLS icindir; HICBIR
    serializer/uc bu alani DONDURMEZ (yonetici/admin dahil kimse sikayet edeni
    goremez). Yonetimin ayri `Complaint` modulunden BAGIMSIZDIR.
    """

    __tablename__ = "unit_complaint"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_unit_complaint_id_tenant"),
        ForeignKeyConstraint(
            ["target_unit_id", "tenant_id"],
            ["unit.id", "unit.tenant_id"],
            ondelete="CASCADE",
            name="fk_unit_complaint_target",
        ),
        ForeignKeyConstraint(
            ["complainant_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="CASCADE",
            name="fk_unit_complaint_complainant",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    target_unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    # IC ALAN — asla serialize edilmez (bkz. schemas.UnitComplaintOut).
    complainant_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False
    )
    kategori: Mapped[str] = mapped_column(
        UNIT_COMPLAINT_KATEGORI, nullable=False, server_default=text("'diger'")
    )
    notlar: Mapped[str | None] = mapped_column(Text, nullable=True)
    durum: Mapped[str] = mapped_column(
        UNIT_COMPLAINT_DURUM, nullable=False, server_default=text("'acik'")
    )
    created_at = _created_at()
    updated_at = _created_at()


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
    "BuildingBlock",
    "UnitResident",
    "DuesAssessment",
    "DuesPayment",
    "PaymentWebhookEvent",
    "Announcement",
    "Visitor",
    "Kargo",
    "OrtakAlan",
    "Rezervasyon",
    "Etkinlik",
    "EtkinlikKatilim",
    "SiteKurali",
    "UserDevice",
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
    "DEVICE_PLATFORM",
    "KARGO_DURUM",
    "REZERVASYON_DURUM",
    "KATILIM_DURUM",
    "Integration",
    "INTEGRATION_CHANNEL",
    "UnitComplaint",
    "UNIT_COMPLAINT_KATEGORI",
    "UNIT_COMPLAINT_DURUM",
]
