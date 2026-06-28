"""Pydantic request/response semalari — openapi.yaml ile uyumlu."""
from __future__ import annotations

import uuid
from datetime import datetime, time
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
    email: str
    role: str
    is_active: bool


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
    created_at: datetime
    updated_at: datetime | None = None


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
    imza_dogrulandi: bool = False


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
AlarmTip = Literal["kacirilan_tur", "eksik_checkpoint", "gecikmis_okutma"]


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


# ----------------------------- notifications ------------------------------- #
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
    aktif: bool = True


class TaskUpdate(BaseModel):
    tip: TaskTip | None = None
    ad: str | None = Field(None, min_length=1)
    aciklama: str | None = None
    atanan_user_id: uuid.UUID | None = None
    checkpoint_id: uuid.UUID | None = None
    periyot_dakika: int | None = Field(None, ge=1)
    sonraki_planlanan: datetime | None = None
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


class AssetOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    kategori: str | None = None
    nfc_tag_uid: str | None = None
    durum: str
    aciklama: str | None = None
    aktif: bool
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
