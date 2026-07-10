"""Pydantic request/response semalari — openapi.yaml ile uyumlu."""
from __future__ import annotations

import uuid
from datetime import date, datetime, time
from typing import Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    EmailStr,
    Field,
    field_validator,
    model_validator,
)

GunTipi = Literal["her_gun", "hafta_ici", "hafta_sonu", "resmi_tatil"]


def _hhmm(v: object) -> object:
    """time/str -> "HH:MM" (openapi gun-ici saat formati)."""
    if isinstance(v, time):
        return v.strftime("%H:%M")
    if isinstance(v, str):
        return v[:5]  # "HH:MM[:SS]" -> "HH:MM"
    return v


# ------------------------------- auth -------------------------------------- #
class LoginRequest(BaseModel):
    tenant_slug: str = Field(..., examples=["acme-plaza"])
    email: EmailStr
    password: str = Field(..., min_length=8)


class ResidentLoginRequest(BaseModel):
    """Sakin girisi: daire no + (gecici kod VEYA kalici parola)."""

    tenant_slug: str = Field(..., examples=["acme-plaza"])
    unit_no: str = Field(..., min_length=1, examples=["A-12"])
    password: str = Field(..., min_length=8)


class ResidentLoginResponse(BaseModel):
    """Sakin giris yaniti — iki durum:

    * Kalici parola ile giris: `password_setup_required=false` + tam token cifti.
    * Gecici kod ile ILK giris: `password_setup_required=true` + `setup_token`
      (yalniz /auth/set-password'de gecer; oturum token'i VERILMEZ).
    """

    password_setup_required: bool
    setup_token: str | None = None
    access_token: str | None = None
    refresh_token: str | None = None
    token_type: str | None = None
    expires_in: int | None = None


class SetPasswordRequest(BaseModel):
    setup_token: str
    new_password: str = Field(..., min_length=8)


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    expires_in: int


# ------------------------------- users ------------------------------------- #
class UserOut(BaseModel):
    id: uuid.UUID
    tenant_id: uuid.UUID
    ad: str
    email: str | None = None  # resident'ta opsiyonel
    role: str
    is_active: bool


UserRoleLiteral = Literal["admin", "yonetici", "security", "tesis_gorevlisi", "resident"]


# Admin kullanici yonetimi ciktisi — password_hash ASLA yok.
class UserAdminOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    email: str | None = None  # resident'ta opsiyonel
    telefon: str | None = None
    role: str
    is_active: bool
    created_at: datetime


class UserCreate(BaseModel):
    ad: str = Field(..., min_length=1)
    email: EmailStr
    telefon: str | None = None
    role: UserRoleLiteral
    password: str = Field(..., min_length=8)


class UserUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1)
    email: EmailStr | None = None
    telefon: str | None = None
    role: UserRoleLiteral | None = None
    is_active: bool | None = None
    password: str | None = Field(None, min_length=8)

    @model_validator(mode="after")
    def _at_least_one(self) -> "UserUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class UserAdminListResponse(BaseModel):
    meta: PageMetaOut
    items: list[UserAdminOut]


# ----------------------- Faz-0 dogrulama (diagnostic) ---------------------- #
# NOT: /me/checkpoints diagnostigi icin (Faz-0). Checkpoint CRUD asagida.
class CheckpointBrief(BaseModel):
    id: uuid.UUID
    ad: str
    nfc_tag_uid: str


# --------------------------- ortak: sayfalama ------------------------------ #
class PageMetaOut(BaseModel):
    limit: int
    offset: int
    total: int


# -------------------------------- shift ------------------------------------ #
class ShiftOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    baslangic_saat: str
    bitis_saat: str
    gun_tipi: str
    created_at: datetime
    updated_at: datetime | None = None

    @field_validator("baslangic_saat", "bitis_saat", mode="before")
    @classmethod
    def _fmt_saat(cls, v: object) -> object:
        return _hhmm(v)


class ShiftCreate(BaseModel):
    ad: str = Field(..., min_length=1)
    # "HH:MM" / "HH:MM:SS" kabul edilir. baslangic > bitis (gece sarkmasi) gecerli.
    baslangic_saat: time
    bitis_saat: time
    gun_tipi: GunTipi | None = None


class ShiftUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1)
    baslangic_saat: time | None = None
    bitis_saat: time | None = None
    gun_tipi: GunTipi | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "ShiftUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class ShiftListResponse(BaseModel):
    meta: PageMetaOut
    items: list[ShiftOut]


# ------------------------------ checkpoint --------------------------------- #
class CheckpointOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    nfc_tag_uid: str
    gps_lat: float | None = None
    gps_lng: float | None = None
    aktif: bool
    # NTAG424 SDM provision edildi mi (anahtar HICBIR response'ta donmez).
    sdm_aktif: bool = False
    created_at: datetime
    updated_at: datetime | None = None


class SdmKeyUpdate(BaseModel):
    """PUT /checkpoints/{id}/sdm-key govdesi — key: 32 hex (AES-128) | null (kapat)."""

    key: str | None

    @field_validator("key")
    @classmethod
    def _hex_128bit(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = v.strip()
        if len(v) != 32:
            raise ValueError("key 32 hex karakter (AES-128) olmali.")
        try:
            bytes.fromhex(v)
        except ValueError:
            raise ValueError("key gecerli hex olmali.")
        return v


class CheckpointCreate(BaseModel):
    ad: str = Field(..., min_length=1)
    nfc_tag_uid: str = Field(..., min_length=1)
    gps_lat: float | None = None
    gps_lng: float | None = None
    aktif: bool = True


class CheckpointUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1)
    nfc_tag_uid: str | None = Field(None, min_length=1)
    gps_lat: float | None = None
    gps_lng: float | None = None
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "CheckpointUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class CheckpointListResponse(BaseModel):
    meta: PageMetaOut
    items: list[CheckpointOut]


# ------------------------------ patrol plan -------------------------------- #
class PatrolPlanOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    shift_id: uuid.UUID | None = None
    baslangic_saat: str
    bitis_saat: str
    periyot_dakika: int
    aktif: bool
    created_at: datetime
    updated_at: datetime | None = None

    @field_validator("baslangic_saat", "bitis_saat", mode="before")
    @classmethod
    def _fmt_saat(cls, v: object) -> object:
        return _hhmm(v)


class PatrolPlanCheckpointOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    checkpoint_id: uuid.UUID
    sira: int


class PatrolPlanDetailOut(PatrolPlanOut):
    checkpoints: list[PatrolPlanCheckpointOut] = []


class PatrolPlanCreate(BaseModel):
    ad: str = Field(..., min_length=1)
    shift_id: uuid.UUID | None = None
    baslangic_saat: time
    bitis_saat: time
    periyot_dakika: int = Field(..., ge=1)
    aktif: bool = True


class PatrolPlanUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1)
    shift_id: uuid.UUID | None = None
    baslangic_saat: time | None = None
    bitis_saat: time | None = None
    periyot_dakika: int | None = Field(None, ge=1)
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "PatrolPlanUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class PatrolPlanListResponse(BaseModel):
    meta: PageMetaOut
    items: list[PatrolPlanOut]


# plana checkpoint atama (PUT /patrol-plans/{id}/checkpoints)
class PatrolPlanCheckpointItemIn(BaseModel):
    checkpoint_id: uuid.UUID
    sira: int | None = Field(None, ge=0)


class PatrolPlanCheckpointAssign(BaseModel):
    items: list[PatrolPlanCheckpointItemIn]


# -------------------------------- scans ------------------------------------ #
class ScanCreate(BaseModel):
    nfc_tag_uid: str = Field(..., min_length=1)
    # istemci biliyorsa verir; yoksa nfc_tag_uid ile cozulur (nfc kaynak-dogru).
    checkpoint_id: uuid.UUID | None = None
    patrol_window_id: uuid.UUID | None = None
    okutma_zamani: datetime
    gps_lat: float | None = None
    gps_lng: float | None = None
    foto_url: str | None = None
    # DEPRECATED + YOK SAYILIR: deger artik SUNUCUDA SDM dogrulamasiyla belirlenir.
    # Eski mobil surumler kirilmasin diye govdede kabul edilir ama etkisizdir.
    imza_dogrulandi: bool = False
    # NTAG424 SDM/SUN ham verisi (etiketin NDEF ciktisindan): 16B ENCPICCData +
    # 8B SDMMAC, hex. Ikisi birlikte gonderilir; checkpoint'te anahtar varsa
    # sunucu dogrular (gecersiz -> 422 invalid_signature, tekrar -> replay_detected).
    sdm_picc_data: str | None = Field(None, min_length=32, max_length=32)
    sdm_cmac: str | None = Field(None, min_length=16, max_length=16)


class ScanEventOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    guard_id: uuid.UUID
    checkpoint_id: uuid.UUID
    patrol_window_id: uuid.UUID | None = None
    nfc_tag_uid: str
    okutma_zamani: datetime
    gps_lat: float | None = None
    gps_lng: float | None = None
    foto_url: str | None = None
    imza_dogrulandi: bool
    idempotency_key: str
    created_at: datetime


# ------------------------------ dashboard ---------------------------------- #
AlarmTip = Literal["kacirilan_tur", "eksik_checkpoint", "gecikmis_okutma", "acil_durum"]


class AktifTurOut(BaseModel):
    patrol_window_id: uuid.UUID
    patrol_plan_id: uuid.UUID
    patrol_plan_ad: str | None = None
    pencere_baslangic: datetime
    pencere_bitis: datetime
    durum: str
    beklenen_checkpoint_sayisi: int | None = None
    okutulan_checkpoint_sayisi: int | None = None


class AlarmOut(BaseModel):
    tip: AlarmTip
    olusma_zamani: datetime
    mesaj: str
    patrol_window_id: uuid.UUID | None = None
    checkpoint_id: uuid.UUID | None = None


class DashboardLiveOut(BaseModel):
    generated_at: datetime
    aktif_turlar: list[AktifTurOut]
    son_alarmlar: list[AlarmOut]


# ---------------------------- patrol-windows ------------------------------- #
PatrolWindowDurumLiteral = Literal["bekliyor", "tamamlandi", "kacirildi"]


class PatrolWindowOut(BaseModel):
    id: uuid.UUID
    patrol_plan_id: uuid.UUID
    plan_adi: str | None = None
    pencere_baslangic: datetime
    pencere_bitis: datetime
    durum: str
    beklenen_checkpoint_sayisi: int
    okutulan_checkpoint_sayisi: int


class PatrolWindowOzet(BaseModel):
    toplam: int
    tamamlandi: int
    kacirildi: int
    bekliyor: int


class PatrolWindowListResponse(BaseModel):
    meta: PageMetaOut
    ozet: PatrolWindowOzet
    items: list[PatrolWindowOut]


# --------------------------- me/patrol-window ------------------------------ #
class MePatrolCheckpointOut(BaseModel):
    checkpoint_id: uuid.UUID
    ad: str
    sira: int
    okutuldu: bool
    okutma_zamani: datetime | None = None
    okutan_user_id: uuid.UUID | None = None


class MePatrolWindowInfo(BaseModel):
    id: uuid.UUID
    patrol_plan_id: uuid.UUID
    plan_adi: str | None = None
    pencere_baslangic: datetime
    pencere_bitis: datetime
    durum: str


class MePatrolWindowItem(MePatrolWindowInfo):
    checkpoints: list[MePatrolCheckpointOut]


class MePatrolWindowResponse(BaseModel):
    generated_at: datetime
    window: MePatrolWindowInfo | None = None
    checkpoints: list[MePatrolCheckpointOut]
    windows: list[MePatrolWindowItem]


# ----------------------------- notifications ------------------------------- #
# ---------------------------- announcements -------------------------------- #
class AnnouncementCreate(BaseModel):
    baslik: str = Field(..., min_length=1, max_length=200)
    govde: str = Field(..., min_length=1, max_length=5000)
    # Opsiyonel gorsel: /uploads/presign ile yuklenen obje anahtari.
    foto_key: str | None = None


class AnnouncementUpdate(BaseModel):
    baslik: str | None = Field(None, min_length=1, max_length=200)
    govde: str | None = Field(None, min_length=1, max_length=5000)
    # Acikca null gonderilirse gorsel kaldirilir; alan hic yoksa dokunulmaz.
    foto_key: str | None = None


class AnnouncementOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    baslik: str
    govde: str
    foto_key: str | None = None
    # Goruntuleme icin kisa omurlu presigned GET URL (foto_key varsa).
    foto_url: str | None = None
    olusturan_user_id: uuid.UUID
    # Liste ekranlarinda "kim gonderdi" icin ad (join ile doldurulur).
    olusturan_ad: str | None = None
    created_at: datetime
    updated_at: datetime


class AnnouncementListResponse(BaseModel):
    meta: PageMetaOut
    items: list[AnnouncementOut]


# ----------------------------- complaints ---------------------------------- #
ComplaintDurum = Literal["acik", "inceleniyor", "cozuldu"]
# Talep turu (opsiyonel): gurultu/goruntu kirliligi + genel 'diger'.
ComplaintKategori = Literal["gurultu", "goruntu", "diger"]


class ComplaintCreate(BaseModel):
    baslik: str = Field(..., min_length=1, max_length=200)
    mesaj: str = Field(..., min_length=1, max_length=5000)
    # Opsiyonel tur; verilmezse NULL (eski davranis — geriye uyumlu).
    kategori: ComplaintKategori | None = None
    # Opsiyonel gorsel: /uploads/presign ile yuklenen obje anahtari.
    foto_key: str | None = None


class ComplaintUpdate(BaseModel):
    """Yonetim yaniti: durum ve/veya yanit metni (admin+yonetici)."""

    durum: ComplaintDurum | None = None
    yonetici_yaniti: str | None = Field(None, min_length=1, max_length=5000)


class ComplaintOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    acan_user_id: uuid.UUID
    # Yonetim listesinde "kim acti" icin ad (join ile doldurulur).
    acan_ad: str | None = None
    baslik: str
    mesaj: str
    kategori: str | None = None
    foto_key: str | None = None
    # Goruntuleme icin kisa omurlu presigned GET URL (foto_key varsa).
    foto_url: str | None = None
    durum: str
    yonetici_yaniti: str | None = None
    yanitlayan_user_id: uuid.UUID | None = None
    yanit_zamani: datetime | None = None
    created_at: datetime
    updated_at: datetime


class ComplaintListResponse(BaseModel):
    meta: PageMetaOut
    items: list[ComplaintOut]


class NotificationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    tip: str
    patrol_window_id: uuid.UUID | None = None
    patrol_plan_id: uuid.UUID | None = None
    checkpoint_id: uuid.UUID | None = None
    task_id: uuid.UUID | None = None
    mesaj: str
    okundu: bool
    created_at: datetime


class NotificationListResponse(BaseModel):
    meta: PageMetaOut
    items: list[NotificationOut]


class NotificationUpdate(BaseModel):
    okundu: bool


# -------------------------------- tasks ------------------------------------ #
TaskTip = Literal["temizlik", "kontrol", "ilaclama", "bakim", "peyzaj", "diger"]


class TaskOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    tip: str
    ad: str
    aciklama: str | None = None
    atanan_user_id: uuid.UUID | None = None
    checkpoint_id: uuid.UUID | None = None
    periyot_dakika: int | None = None
    sonraki_planlanan: datetime | None = None
    foto_zorunlu: bool
    aktif: bool
    created_at: datetime
    updated_at: datetime | None = None


class TaskCreate(BaseModel):
    tip: TaskTip
    ad: str = Field(..., min_length=1)
    aciklama: str | None = None
    atanan_user_id: uuid.UUID | None = None
    checkpoint_id: uuid.UUID | None = None
    periyot_dakika: int | None = Field(None, ge=1)
    sonraki_planlanan: datetime | None = None
    foto_zorunlu: bool = False
    aktif: bool = True


class TaskUpdate(BaseModel):
    tip: TaskTip | None = None
    ad: str | None = Field(None, min_length=1)
    aciklama: str | None = None
    atanan_user_id: uuid.UUID | None = None
    checkpoint_id: uuid.UUID | None = None
    periyot_dakika: int | None = Field(None, ge=1)
    sonraki_planlanan: datetime | None = None
    foto_zorunlu: bool | None = None
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "TaskUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class TaskListResponse(BaseModel):
    meta: PageMetaOut
    items: list[TaskOut]


class TaskCompletionCreate(BaseModel):
    tamamlanma_zamani: datetime
    nfc_tag_uid: str | None = None
    gps_lat: float | None = None
    gps_lng: float | None = None
    foto_key: str | None = None
    notlar: str | None = None


class TaskCompletionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    task_id: uuid.UUID
    tamamlayan_user_id: uuid.UUID
    tamamlanma_zamani: datetime
    nfc_tag_uid: str | None = None
    gps_lat: float | None = None
    gps_lng: float | None = None
    foto_key: str | None = None
    foto_url: str | None = None
    notlar: str | None = None
    idempotency_key: str
    created_at: datetime


class TaskCompletionListResponse(BaseModel):
    meta: PageMetaOut
    items: list[TaskCompletionOut]


# Capraz-gorev tamamlama gecmisi (GET /task-completions). foto_url/gps yok;
# kanit varligi foto_var/nfc_dogrulandi bool olarak yeter.
class TaskCompletionHistoryOut(BaseModel):
    id: uuid.UUID
    task_id: uuid.UUID
    task_adi: str | None = None
    tip: str
    tamamlayan_user_id: uuid.UUID
    tamamlanma_zamani: datetime
    foto_var: bool
    nfc_dogrulandi: bool
    notlar: str | None = None


class TaskCompletionOzet(BaseModel):
    toplam: int
    temizlik: int
    kontrol: int
    ilaclama: int
    peyzaj: int


class TaskCompletionHistoryListResponse(BaseModel):
    meta: PageMetaOut
    ozet: TaskCompletionOzet
    items: list[TaskCompletionHistoryOut]


# ------------------------------- devices ----------------------------------- #
DevicePlatform = Literal["android", "ios", "web"]


class DeviceRegister(BaseModel):
    fcm_token: str = Field(..., min_length=1)
    platform: DevicePlatform


class DeviceOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_id: uuid.UUID
    fcm_token: str
    platform: str
    aktif: bool
    created_at: datetime
    updated_at: datetime


class DeviceListResponse(BaseModel):
    meta: PageMetaOut
    items: list[DeviceOut]


# ------------------------------- uploads ----------------------------------- #
class PresignRequest(BaseModel):
    content_type: str = Field(..., min_length=1, examples=["image/jpeg"])
    dosya_adi: str | None = None


class PresignResponse(BaseModel):
    foto_key: str
    upload_url: str
    method: str = "PUT"
    expires_in: int


# -------------------------------- assets ----------------------------------- #
AssetKategori = Literal["ekipman", "arac", "alet", "diger"]
AssetDurum = Literal["musait", "zimmetli", "bakimda"]


class AcikZimmetOut(BaseModel):
    """Asset uzerindeki ACIK zimmetin ozeti (mobil §13 #2/#5) — history taramadan."""

    alan_user_id: uuid.UUID
    alan_user_ad: str
    alinma_zamani: datetime


class AssetOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    kategori: str | None = None
    nfc_tag_uid: str | None = None
    durum: str
    aciklama: str | None = None
    aktif: bool
    acik_zimmet: AcikZimmetOut | None = None
    created_at: datetime
    updated_at: datetime | None = None


class AssetCreate(BaseModel):
    ad: str = Field(..., min_length=1)
    kategori: AssetKategori | None = None
    nfc_tag_uid: str | None = None
    aciklama: str | None = None
    aktif: bool = True


class AssetUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1)
    kategori: AssetKategori | None = None
    nfc_tag_uid: str | None = None
    durum: AssetDurum | None = None
    aciklama: str | None = None
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "AssetUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class AssetListResponse(BaseModel):
    meta: PageMetaOut
    items: list[AssetOut]


class AssetCheckoutOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    asset_id: uuid.UUID
    alan_user_id: uuid.UUID
    alan_user_ad: str | None = None
    birakan_user_id: uuid.UUID | None = None
    birakan_user_ad: str | None = None
    alma_zamani: datetime
    birakma_zamani: datetime | None = None
    alma_nfc_tag_uid: str | None = None
    birakma_nfc_tag_uid: str | None = None
    alma_gps_lat: float | None = None
    alma_gps_lng: float | None = None
    birakma_gps_lat: float | None = None
    birakma_gps_lng: float | None = None
    notlar: str | None = None
    idempotency_key: str
    created_at: datetime


class AssetCheckoutListResponse(BaseModel):
    meta: PageMetaOut
    items: list[AssetCheckoutOut]


class CheckoutRequest(BaseModel):
    nfc_tag_uid: str | None = None
    gps_lat: float | None = None
    gps_lng: float | None = None
    notlar: str | None = None


class CheckinRequest(BaseModel):
    nfc_tag_uid: str | None = None
    gps_lat: float | None = None
    gps_lng: float | None = None
    notlar: str | None = None


# ------------------------------ emergency ---------------------------------- #
EmergencyDurum = Literal["acik", "cozuldu"]


class EmergencyCreate(BaseModel):
    gps_lat: float | None = None
    gps_lng: float | None = None
    notlar: str | None = None


class EmergencyResolve(BaseModel):
    notlar: str | None = None


class EmergencyAlertOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    tetikleyen_user_id: uuid.UUID
    tetiklenme_zamani: datetime
    gps_lat: float | None = None
    gps_lng: float | None = None
    durum: str
    cozen_user_id: uuid.UUID | None = None
    cozulme_zamani: datetime | None = None
    notlar: str | None = None
    idempotency_key: str
    created_at: datetime


class EmergencyListResponse(BaseModel):
    meta: PageMetaOut
    items: list[EmergencyAlertOut]


# --------------------------- tenant settings ------------------------------- #
class TenantSettings(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    tenant_id: uuid.UUID
    ad: str
    slug: str
    timezone: str
    acil_durum_telefon: str | None = None


class TenantSettingsUpdate(BaseModel):
    acil_durum_telefon: str | None = None
    timezone: str | None = None
    ad: str | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "TenantSettingsUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


# -------------------------------- aidat ------------------------------------ #
ResidentRol = Literal["malik", "kiraci"]
DuesYontem = Literal["elden", "havale", "kart", "diger"]
DuesDurum = Literal["basarili", "bekliyor", "iptal"]


class UnitOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    no: str
    blok: str | None = None
    metrekare: float | None = None
    aktif: bool
    created_at: datetime
    updated_at: datetime | None = None


class UnitCreate(BaseModel):
    no: str = Field(..., min_length=1)
    blok: str | None = None
    metrekare: float | None = None
    aktif: bool = True


class UnitUpdate(BaseModel):
    no: str | None = Field(None, min_length=1)
    blok: str | None = None
    metrekare: float | None = None
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "UnitUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class UnitListResponse(BaseModel):
    meta: PageMetaOut
    items: list[UnitOut]


class UnitResidentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    unit_id: uuid.UUID
    user_id: uuid.UUID
    rol_tipi: str | None = None
    baslangic: datetime | None = None
    bitis: datetime | None = None
    created_at: datetime


class ResidentAssign(BaseModel):
    user_id: uuid.UUID
    rol_tipi: ResidentRol | None = None
    baslangic: datetime | None = None


# ------------------- sakin olusturma (yonetici, gecici kod) ---------------- #
class ResidentCreate(BaseModel):
    """Yonetici daire + sakin hesabini tek adimda acar; gecici kod uretilir."""

    unit_no: str = Field(..., min_length=1, examples=["A-12"])
    blok: str | None = None  # yalniz YENI acilan unit'e islenir
    ad: str = Field(..., min_length=1)
    email: EmailStr | None = None  # sakinde opsiyonel
    telefon: str | None = None
    rol_tipi: ResidentRol | None = None


class ResidentCreatedOut(BaseModel):
    """`temp_code` YALNIZ bu yanitta bir kez duz metin doner (yonetici sakine
    iletir); sunucuda hash'i saklanir ve parola belirlenince gecersizlesir."""

    user_id: uuid.UUID
    unit_id: uuid.UUID
    unit_no: str
    ad: str
    email: str | None = None
    temp_code: str


class DuesAssessmentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    unit_id: uuid.UUID
    donem: str
    tutar_kurus: int
    son_odeme_tarihi: date | None = None
    aciklama: str | None = None
    created_at: datetime


class DuesAssessmentCreate(BaseModel):
    donem: str = Field(..., min_length=1)
    tutar_kurus: int = Field(..., ge=1)  # KURUS; negatif/sifir reddedilir
    unit_id: uuid.UUID | None = None     # verilirse tek daire
    unit_ids: list[uuid.UUID] | None = None  # toplu hedef; yoksa tum aktif daireler
    son_odeme_tarihi: date | None = None
    aciklama: str | None = None


class DuesAssessmentResult(BaseModel):
    created: list[DuesAssessmentOut]
    atlanan: int


class DuesAssessmentListResponse(BaseModel):
    meta: PageMetaOut
    items: list[DuesAssessmentOut]


class DuesPaymentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    unit_id: uuid.UUID
    assessment_id: uuid.UUID | None = None
    tutar_kurus: int
    odeme_zamani: datetime
    donem: str | None = None
    yontem: str
    durum: str
    makbuz_no: str | None = None
    provider: str | None = None
    provider_ref: str | None = None
    kaydeden_user_id: uuid.UUID
    idempotency_key: str
    created_at: datetime


class DuesPaymentCreate(BaseModel):
    unit_id: uuid.UUID
    assessment_id: uuid.UUID | None = None
    tutar_kurus: int = Field(..., ge=1)  # KURUS
    yontem: DuesYontem
    makbuz_no: str | None = None
    odeme_zamani: datetime | None = None
    # 'YYYY-MM'; verilmezse assessment'tan turer, o da yoksa NULL kalir.
    donem: str | None = Field(None, min_length=1)


class DuesPaymentListResponse(BaseModel):
    meta: PageMetaOut
    items: list[DuesPaymentOut]


class UnitDuesStatus(BaseModel):
    unit_id: uuid.UUID
    no: str
    toplam_tahakkuk_kurus: int
    toplam_odenen_kurus: int
    bakiye_kurus: int
    assessments: list[DuesAssessmentOut] = []
    payments: list[DuesPaymentOut] = []


class MeDuesResponse(BaseModel):
    items: list[UnitDuesStatus]


# ------------------------------- budget ------------------------------------ #
# Butce (Wave 2A): para HER YERDE integer KURUS (dues deseni; float ASLA).
BudgetTip = Literal["gelir", "gider"]
BudgetKaynak = Literal["manuel", "aidat_odeme"]


class BudgetCategoryCreate(BaseModel):
    ad: str = Field(..., min_length=1, max_length=100)
    tip: BudgetTip


class BudgetCategoryUpdate(BaseModel):
    """aktif=false = soft-delete (kayitli hareketler kategorisini korur)."""

    ad: str | None = Field(None, min_length=1, max_length=100)
    aktif: bool | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "BudgetCategoryUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class BudgetCategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    tip: str
    aktif: bool
    created_at: datetime


class BudgetCategoryListResponse(BaseModel):
    meta: PageMetaOut
    items: list[BudgetCategoryOut]


class BudgetEntryCreate(BaseModel):
    """Manuel defter kaydi. `tip` ISTEMCIDEN ALINMAZ — kategoriden turetilir
    (kategori-tip uyusmazligi imkansiz olsun)."""

    kategori_id: uuid.UUID
    tutar_kurus: int = Field(..., ge=1)  # KURUS; sifir/negatif reddedilir
    tarih: date
    aciklama: str | None = Field(None, max_length=1000)

    @field_validator("tutar_kurus", mode="before")
    @classmethod
    def _tam_kurus(cls, v: object) -> object:
        # 10.5 gibi float'lar sessizce yuvarlanmasin — para integer kurus.
        if isinstance(v, float):
            raise ValueError("tutar_kurus tam sayi (kurus) olmali")
        return v


class BudgetEntryUpdate(BaseModel):
    """Yalniz MANUEL kayitlar duzenlenebilir (aidat_odeme kayitlari aidat
    modulunun yetkisindedir)."""

    kategori_id: uuid.UUID | None = None
    tutar_kurus: int | None = Field(None, ge=1)
    tarih: date | None = None
    aciklama: str | None = Field(None, max_length=1000)

    @field_validator("tutar_kurus", mode="before")
    @classmethod
    def _tam_kurus(cls, v: object) -> object:
        if isinstance(v, float):
            raise ValueError("tutar_kurus tam sayi (kurus) olmali")
        return v

    @model_validator(mode="after")
    def _at_least_one(self) -> "BudgetEntryUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class BudgetEntryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    kategori_id: uuid.UUID
    # Liste/rapor icin kategori adi (join ile doldurulur).
    kategori_ad: str | None = None
    tip: str
    tutar_kurus: int
    tarih: date
    aciklama: str | None = None
    kaynak: str
    ilgili_payment_id: uuid.UUID | None = None
    created_by: uuid.UUID
    created_at: datetime


class BudgetEntryListResponse(BaseModel):
    meta: PageMetaOut
    items: list[BudgetEntryOut]


class BudgetCategorySummary(BaseModel):
    kategori_id: uuid.UUID
    ad: str
    tip: str
    toplam_kurus: int


class BudgetSummary(BaseModel):
    """Kasa ozeti: bakiye = gelir - gider (negatif olabilir). KURUS."""

    toplam_gelir_kurus: int
    toplam_gider_kurus: int
    bakiye_kurus: int
    kategoriler: list[BudgetCategorySummary]
