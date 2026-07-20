# Ticketing v1 (Talep/Arıza → İş Emri) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repurpose the existing `/complaints` (Şikayet/Öneri) module in place into a full end-to-end maintenance/request ticketing system: kategori + açıklama + up to 3 photos → convert to a work-order task → assignee completes with proof → auto-resolve, with a status timeline and FCM notifications on every transition.

**Architecture:** No parallel system. The `complaint` table/entity/`/complaints` endpoints are reshaped: new `durum` machine (`acik | is_emri | cozuldu | reddedildi`), category becomes an FK to the dynamic `task_category`, single photo becomes a `complaint_photo` child (≤3), a `complaint_status_history` table drives the timeline, and `task` gains `ticket_id` + `oncelik`. All new tables follow the house RLS/composite-FK pattern. `/unit-complaints` (hard-anonymous) is untouched. Tickets are always identified (no anonymity).

**Tech Stack:** FastAPI + async SQLAlchemy 2.0, Postgres RLS, Alembic single canonical migration (`0001`, edited in place, `down -v`), MinIO (boto3 presign), FCM HTTP v1 push, Flutter/Riverpod/Dio (mobile), Next.js App Router + SWR (admin-web), OpenAPI 3.0.3 hand-mirrored contract.

## Global Constraints

- Work ONLY on `main`. NO branches, NO PRs, NO CI/gh. Commit directly to main.
- Canonical migration `contracts/db/migrations/versions/0001_initial_schema.py` is edited **in place**; verify via `down -v && up --build`. No new migration files.
- Every new table: `tenant_id uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE`, `UNIQUE(id, tenant_id)`, `ix_<t>_tenant`, composite FKs `(child, tenant_id) REFERENCES parent(id, tenant_id)`, and appended to **both** RLS loops (`upgrade` list at line ~1832 and `downgrade` list).
- Wire/enum values are Turkish ASCII (no diacritics), literal: `admin|yonetici|security|tesis_gorevlisi|resident`; durum `acik|is_emri|cozuldu|reddedildi`; oncelik `dusuk|orta|yuksek`.
- MinIO keys tenant-prefixed (`{tenant_id}/...`); presigned GET short-lived; `_validate_foto_key` prefix guard on every read.
- Backend Docker images **bake** code — rebuild the api/seed image before pytest/seed sees backend edits. Full cycle: `cd infra && docker compose down -v && docker compose up -d --build && <seed> && pytest` (see repo `infra/` compose + existing memory).
- Backend tests hit a LIVE server via `httpx` (`API_URL`, default `http://localhost:8000`); auth via real `POST /auth/login`; fixtures `world`, `owner_conn`, `app_conn` in `backend/tests/conftest.py`.
- Push is best-effort additive (`dispatch_external`) — failure must never break the originating write.
- ISO8601 UTC timestamps; error envelope `{ "error": { "code", "message" } }`; pagination `limit(≤200)/offset` + `meta`.
- Anonymity is OUT OF SCOPE — no `anonim` flag, no leak tests. `/unit-complaints` remains the anonymous channel.

---

## File Structure

**Backend**
- Modify `backend/app/models.py` — reshape `Complaint`; add `ComplaintPhoto`, `ComplaintStatusHistory`; add `Task.ticket_id` + `Task.oncelik`; new enum objects.
- Modify `backend/app/schemas.py` — reshape `Complaint*`; add photo/history/convert/resolve/decline schemas; harden `PresignRequest`.
- Modify `backend/app/storage.py` — content-type allow-list + declared-size cap in `presign_put`.
- Modify `backend/app/routers/uploads.py` — pass declared size through.
- Modify `backend/app/routers/complaints.py` — reshape create/list/detail; add `convert`/`resolve`/`decline`; status-machine + history helpers.
- Modify `backend/app/routers/tasks.py` — completion of a ticket-linked task auto-resolves the ticket + notifies.
- New `backend/app/ticketing.py` — shared status-machine + history + notification helpers (keep routers thin).
- Tests: `backend/tests/test_ticketing.py` (new), extend `backend/tests/test_complaints.py`, `backend/tests/test_uploads.py` (new if absent).

**Contracts**
- Modify `contracts/db/migrations/versions/0001_initial_schema.py`.
- Modify `contracts/openapi.yaml`, `contracts/auth.md`.

**Infra/seed**
- Modify the seed script (locate under `infra/` / seed image entrypoint) to add demo tickets.

**Mobile** (`mobile/lib/src/features/complaints/`)
- `domain/complaint_models.dart`, `data/complaint_api.dart`, `presentation/complaints_screen.dart`, `presentation/complaints_controller.dart`; touch `mobile/lib/src/features/tasks/presentation/task_detail_screen.dart` for ticket context.

**Admin-web** (`admin-web/`)
- `app/(protected)/complaints/page.tsx`; `app/api/complaints/[id]/convert/route.ts`, `.../resolve/route.ts`, `.../decline/route.ts`; `lib/types.ts`.

---

## Task 1: Migration — reshape complaint, new tables, task.ticket_id + oncelik, RLS

**Files:**
- Modify: `contracts/db/migrations/versions/0001_initial_schema.py` (enums ~59-138; task DDL 829-866; complaint DDL 1319-1360; RLS upgrade loop ~1832; downgrade loop)

**Interfaces:**
- Produces: enum types `complaint_durum('acik','is_emri','cozuldu','reddedildi')`, `task_oncelik('dusuk','orta','yuksek')`, extended `notification_tip`; tables `complaint` (reshaped), `complaint_photo`, `complaint_status_history`; `task.ticket_id`, `task.oncelik`.

- [ ] **Step 1: Edit enum definitions.**

Replace the `complaint_durum` enum (line ~84-86) and REMOVE `complaint_kategori` (line ~87-91):
```python
    op.execute(
        "CREATE TYPE complaint_durum AS ENUM "
        "('acik', 'is_emri', 'cozuldu', 'reddedildi');"
    )
    # NOT: complaint_kategori enum'u KALDIRILDI — talep kategorisi artik dinamik
    # task_category tablosuna FK (elektrik/tesisat/asansor...). Tek taksonomi.
    op.execute(
        "CREATE TYPE task_oncelik AS ENUM ('dusuk', 'orta', 'yuksek');"
    )
```
Extend `notification_tip` (line ~70-74) to include ticketing values:
```python
    op.execute(
        "CREATE TYPE notification_tip AS ENUM "
        "('kacirilan_tur', 'eksik_checkpoint', 'gecikmis_okutma', "
        "'peyzaj_yaklasan', 'peyzaj_kacirilan', "
        "'talep_is_emri', 'talep_cozuldu', 'talep_reddedildi', 'is_emri_atandi');"
    )
```

- [ ] **Step 2: Add `oncelik` + `ticket_id` to the `task` DDL.**

In the `CREATE TABLE task (...)` block (line ~831), add two columns after `foto_zorunlu` and a composite FK. `ticket_id` references `complaint`, but `complaint` is created LATER in the file (line ~1319) — a composite FK requires the target to exist first. Since the whole migration runs in one transaction and `complaint` is created after `task`, add the FK to `task` via a **separate `ALTER TABLE` after the complaint table is created** (Step 4), not inline. Inline, just add the columns:
```sql
            foto_zorunlu     boolean NOT NULL DEFAULT false,
            oncelik          task_oncelik,   -- is emri onceligi (ticket->task); normal gorevde NULL
            ticket_id        uuid,           -- bagli talep (complaint); NULL = normal gorev
            aktif            boolean NOT NULL DEFAULT true,
```
Add an index after the existing task indexes (line ~866):
```python
    op.execute("CREATE INDEX ix_task_ticket ON task (tenant_id, ticket_id);")
```

- [ ] **Step 3: Reshape the `complaint` DDL** (replace lines ~1321-1344 table body):
```sql
        CREATE TABLE complaint (
            id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id            uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            acan_user_id         uuid NOT NULL,
            baslik               text NOT NULL,
            mesaj                text NOT NULL,
            kategori_id          uuid,        -- dinamik task_category FK; NULL = "Diğer"
            durum                complaint_durum NOT NULL DEFAULT 'acik',
            created_at           timestamptz NOT NULL DEFAULT now(),
            updated_at           timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_complaint_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT fk_complaint_acan
                FOREIGN KEY (acan_user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE RESTRICT,
            CONSTRAINT fk_complaint_kategori
                FOREIGN KEY (kategori_id, tenant_id)
                REFERENCES task_category (id, tenant_id) ON DELETE SET NULL (kategori_id)
        );
```
Replace the kategori index (line ~1351-1354) to reference `kategori_id`:
```python
    op.execute(
        "CREATE INDEX ix_complaint_tenant_kategori "
        "ON complaint (tenant_id, kategori_id);"
    )
```
(Keep the `ix_complaint_tenant`, `ix_complaint_tenant_durum`, `ix_complaint_tenant_acan`, `ix_complaint_tenant_created` indexes as-is.)

- [ ] **Step 4: After the complaint indexes (line ~1360), add the `task.ticket_id` FK + the two new child tables.**
```python
    # task.ticket_id -> complaint (complaint task'tan SONRA yaratildigi icin ALTER ile).
    op.execute(
        """
        ALTER TABLE task
            ADD CONSTRAINT fk_task_ticket
            FOREIGN KEY (ticket_id, tenant_id)
            REFERENCES complaint (id, tenant_id) ON DELETE SET NULL (ticket_id);
        """
    )
    # complaint_photo — talep basina <=3 gorsel (MinIO obje anahtari, tenant-onekli).
    op.execute(
        """
        CREATE TABLE complaint_photo (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id     uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            complaint_id  uuid NOT NULL,
            foto_key      text NOT NULL,
            sira          smallint NOT NULL DEFAULT 0,
            created_at    timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_complaint_photo_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT fk_complaint_photo_complaint
                FOREIGN KEY (complaint_id, tenant_id)
                REFERENCES complaint (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    op.execute("CREATE INDEX ix_complaint_photo_tenant ON complaint_photo (tenant_id);")
    op.execute(
        "CREATE INDEX ix_complaint_photo_complaint "
        "ON complaint_photo (tenant_id, complaint_id, sira);"
    )
    # complaint_status_history — timeline kaynagi. actor_role YALNIZ (user_id ASLA).
    op.execute(
        """
        CREATE TABLE complaint_status_history (
            id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id     uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
            complaint_id  uuid NOT NULL,
            durum         complaint_durum NOT NULL,
            actor_role    user_role NOT NULL,
            sebep         text,       -- reddetme gerekcesi / donusturme notu / cozum notu
            created_at    timestamptz NOT NULL DEFAULT now(),
            CONSTRAINT uq_complaint_history_id_tenant UNIQUE (id, tenant_id),
            CONSTRAINT fk_complaint_history_complaint
                FOREIGN KEY (complaint_id, tenant_id)
                REFERENCES complaint (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    op.execute(
        "CREATE INDEX ix_complaint_history_complaint "
        "ON complaint_status_history (tenant_id, complaint_id, created_at);"
    )
```

- [ ] **Step 5: Append the two new tables to the RLS upgrade loop** (after `"complaint",` at line ~1856):
```python
        "complaint",
        "complaint_photo",
        "complaint_status_history",
```

- [ ] **Step 6: Append the same two tables to the `downgrade()` RLS/DROP loop.**

Locate the `downgrade()` function's table list (mirror of the upgrade loop) and add `"complaint_photo"` and `"complaint_status_history"` in the same relative position. Also confirm downgrade drops enums; add `task_oncelik` to the enum-drop list and ensure `complaint_kategori` is removed from it (it no longer exists). Read the downgrade block first to match its exact idiom.

- [ ] **Step 7: Rebuild + apply the migration clean.**

Run: `cd /home/kerem/tesis-platform/infra && docker compose down -v && docker compose up -d --build`
Expected: containers healthy; alembic `upgrade head` runs with no error. Then verify downgrade:
Run: `docker compose exec api alembic downgrade -1 && docker compose exec api alembic upgrade head` (adjust service/exec per repo). Expected: both succeed (no leftover objects).

- [ ] **Step 8: Commit.**
```bash
git add contracts/db/migrations/versions/0001_initial_schema.py
git commit -m "feat(ticketing): 0001 — complaint durum makinesi, kategori_id, foto+history tablolari, task.ticket_id+oncelik"
```

---

## Task 2: Models — reshape Complaint, add photo/history, task fields

**Files:**
- Modify: `backend/app/models.py` (enum objects near top; `Task` 504-548; `Complaint` 953-995)

**Interfaces:**
- Consumes: enum types from Task 1.
- Produces: `Complaint` (reshaped: `kategori_id`, no `foto_key`/`kategori`/`yonetici_yaniti`/`yanitlayan_user_id`/`yanit_zamani`); `ComplaintPhoto`, `ComplaintStatusHistory` ORM classes; `Task.ticket_id`, `Task.oncelik`.

- [ ] **Step 1: Add/adjust enum objects.**

Find where `COMPLAINT_DURUM`, `COMPLAINT_KATEGORI`, `NOTIFICATION_TIP`, `USER_ROLE` are declared (grep `COMPLAINT_DURUM = ENUM`). Update:
```python
COMPLAINT_DURUM = ENUM(
    "acik", "is_emri", "cozuldu", "reddedildi",
    name="complaint_durum", create_type=False,
)
# COMPLAINT_KATEGORI KALDIRILDI (kategori artik task_category FK).
TASK_ONCELIK = ENUM(
    "dusuk", "orta", "yuksek", name="task_oncelik", create_type=False,
)
```
Update `NOTIFICATION_TIP` to add the four ticketing values (mirror Task 1 Step 1). Delete the `COMPLAINT_KATEGORI` object and any import of it.

- [ ] **Step 2: Add `oncelik` + `ticket_id` to `Task`.**

In `Task.__table_args__` add a composite FK; in the columns add two fields:
```python
        ForeignKeyConstraint(
            ["ticket_id", "tenant_id"],
            ["complaint.id", "complaint.tenant_id"],
            ondelete="SET NULL",
            name="fk_task_ticket",
        ),
```
```python
    foto_zorunlu: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    oncelik: Mapped[str | None] = mapped_column(TASK_ONCELIK, nullable=True)
    ticket_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    aktif: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
```

- [ ] **Step 3: Reshape `Complaint`** (replace body lines ~974-995, drop the `fk_complaint_yanitlayan` constraint and removed columns; add kategori FK):
```python
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_complaint_id_tenant"),
        ForeignKeyConstraint(
            ["acan_user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="RESTRICT",
            name="fk_complaint_acan",
        ),
        ForeignKeyConstraint(
            ["kategori_id", "tenant_id"],
            ["task_category.id", "task_category.tenant_id"],
            ondelete="SET NULL",
            name="fk_complaint_kategori",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    acan_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    baslik: Mapped[str] = mapped_column(Text, nullable=False)
    mesaj: Mapped[str] = mapped_column(Text, nullable=False)
    kategori_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    durum: Mapped[str] = mapped_column(
        COMPLAINT_DURUM, nullable=False, server_default=text("'acik'")
    )
    created_at = _created_at()
    updated_at = _created_at()
```

- [ ] **Step 4: Add the two new model classes** (after `Complaint`):
```python
class ComplaintPhoto(Base):
    """Talep gorseli (<=3/talep) — MinIO obje anahtari, tenant-onekli."""

    __tablename__ = "complaint_photo"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_complaint_photo_id_tenant"),
        ForeignKeyConstraint(
            ["complaint_id", "tenant_id"],
            ["complaint.id", "complaint.tenant_id"],
            ondelete="CASCADE",
            name="fk_complaint_photo_complaint",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    complaint_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    foto_key: Mapped[str] = mapped_column(Text, nullable=False)
    sira: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default=text("0"))
    created_at = _created_at()


class ComplaintStatusHistory(Base):
    """Talep durum gecmisi (timeline). actor_role YALNIZ — user_id ASLA."""

    __tablename__ = "complaint_status_history"
    __table_args__ = (
        UniqueConstraint("id", "tenant_id", name="uq_complaint_history_id_tenant"),
        ForeignKeyConstraint(
            ["complaint_id", "tenant_id"],
            ["complaint.id", "complaint.tenant_id"],
            ondelete="CASCADE",
            name="fk_complaint_history_complaint",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    complaint_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    durum: Mapped[str] = mapped_column(COMPLAINT_DURUM, nullable=False)
    actor_role: Mapped[str] = mapped_column(USER_ROLE, nullable=False)
    sebep: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at = _created_at()
```
Ensure `SmallInteger` is imported from `sqlalchemy` at the top of the file (add if missing).

- [ ] **Step 5: Verify import (no test yet — models are exercised by Task 5+ tests).**

Run: `cd /home/kerem/tesis-platform/infra && docker compose up -d --build api && docker compose exec api python -c "import app.models"`
Expected: no ImportError / no mapper configuration error.

- [ ] **Step 6: Commit.**
```bash
git add backend/app/models.py
git commit -m "feat(ticketing): Complaint reshape + ComplaintPhoto/StatusHistory + task.ticket_id/oncelik ORM"
```

---

## Task 3: Schemas — Complaint reshape + convert/resolve/decline + presign hardening

**Files:**
- Modify: `backend/app/schemas.py` (complaints block 653-698; `PresignRequest` 1424-1426)

**Interfaces:**
- Produces: `ComplaintDurum = Literal["acik","is_emri","cozuldu","reddedildi"]`; `TaskOncelik = Literal["dusuk","orta","yuksek"]`; `ComplaintPhotoOut`, `ComplaintStatusHistoryOut`, `ComplaintCreate`, `ComplaintOut`, `ComplaintListResponse`, `ComplaintConvertRequest`, `ComplaintResolveRequest`, `ComplaintDeclineRequest`; hardened `PresignRequest`.

- [ ] **Step 1: Replace the complaints schema block** (lines ~653-698):
```python
# ----------------------------- complaints ---------------------------------- #
ComplaintDurum = Literal["acik", "is_emri", "cozuldu", "reddedildi"]
TaskOncelik = Literal["dusuk", "orta", "yuksek"]


class ComplaintPhotoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    foto_key: str
    sira: int
    foto_url: str | None = None


class ComplaintStatusHistoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    durum: str
    actor_role: str
    sebep: str | None = None
    created_at: datetime


class ComplaintCreate(BaseModel):
    baslik: str = Field(..., min_length=1, max_length=200)
    mesaj: str = Field(..., min_length=1, max_length=5000)
    kategori_id: uuid.UUID | None = None
    # En fazla 3 gorsel; her biri /uploads/presign obje anahtari.
    foto_keys: list[str] = Field(default_factory=list, max_length=3)


class ComplaintOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    acan_user_id: uuid.UUID
    acan_ad: str | None = None
    baslik: str
    mesaj: str
    kategori_id: uuid.UUID | None = None
    kategori_ad: str | None = None
    durum: str
    fotograflar: list[ComplaintPhotoOut] = Field(default_factory=list)
    gecmis: list[ComplaintStatusHistoryOut] = Field(default_factory=list)
    # Bagli is emri (varsa): task ozeti.
    is_emri_id: uuid.UUID | None = None
    is_emri_durum: str | None = None  # 'acik' (atandi) | 'tamamlandi'
    created_at: datetime
    updated_at: datetime


class ComplaintListResponse(BaseModel):
    meta: PageMetaOut
    items: list[ComplaintOut]


class ComplaintConvertRequest(BaseModel):
    """Talebi is emrine donustur (yonetici)."""
    kategori_id: uuid.UUID | None = None       # onaylanan/degistirilen kategori
    oncelik: TaskOncelik = "orta"
    atanan_user_id: uuid.UUID = Field(...)
    not_: str | None = Field(None, alias="not", max_length=2000)
    model_config = ConfigDict(populate_by_name=True)


class ComplaintResolveRequest(BaseModel):
    """Dogrudan coz (yonetici) — opsiyonel cozum notu timeline'a yazilir."""
    cozum_notu: str | None = Field(None, max_length=2000)


class ComplaintDeclineRequest(BaseModel):
    """Reddet (yonetici) — sebep ZORUNLU."""
    sebep: str = Field(..., min_length=1, max_length=2000)
```
Remove `ComplaintUpdate` and `ComplaintKategori` entirely (and any import elsewhere — Task 5 rewrites the router that used them).

- [ ] **Step 2: Harden `PresignRequest`** (lines ~1424-1426):
```python
# İzin verilen gorsel MIME'lari — content_type imzali URL'e baglanir (airtight).
_ALLOWED_UPLOAD_CT = {"image/jpeg", "image/png", "image/webp", "image/heic"}
_MAX_UPLOAD_BYTES = 8 * 1024 * 1024  # ~8 MB, client-declared (best-effort)


class PresignRequest(BaseModel):
    content_type: str = Field(..., min_length=1, examples=["image/jpeg"])
    dosya_adi: str | None = None
    boyut: int | None = Field(None, ge=1, description="Client-declared byte size")

    @field_validator("content_type")
    @classmethod
    def _ct_allow(cls, v: str) -> str:
        if v.lower() not in _ALLOWED_UPLOAD_CT:
            raise ValueError("content_type gorsel olmali (jpeg/png/webp/heic)")
        return v.lower()

    @field_validator("boyut")
    @classmethod
    def _size_cap(cls, v: int | None) -> int | None:
        if v is not None and v > _MAX_UPLOAD_BYTES:
            raise ValueError("dosya cok buyuk (max 8MB)")
        return v
```
Ensure `field_validator` is imported from `pydantic` at the top of `schemas.py` (add if missing). Note: a Pydantic `ValueError` in a request body → FastAPI 422 automatically, matching the "content-type → 422" requirement.

- [ ] **Step 3: Verify import.**

Run: `docker compose exec api python -c "import app.schemas"`
Expected: no error.

- [ ] **Step 4: Commit.**
```bash
git add backend/app/schemas.py
git commit -m "feat(ticketing): Complaint schemas reshape (foto_keys/history/convert/resolve/decline) + presign gorsel dogrulama"
```

---

## Task 4: Storage/uploads — thread declared size (content-type already validated in schema)

**Files:**
- Modify: `backend/app/storage.py` (`presign_put` 76-86)
- Modify: `backend/app/routers/uploads.py`
- Test: `backend/tests/test_uploads.py` (new)

**Interfaces:**
- Consumes: hardened `PresignRequest` (Task 3).
- Produces: `presign_put` unchanged signature is fine; content-type is bound into the signed params (already the case). No behavioral change needed in `storage.py` beyond a comment — the allow-list lives in the schema. This task is primarily the **test** proving 422 on non-image and tenant-prefix on the key.

- [ ] **Step 1: Write the failing test** `backend/tests/test_uploads.py`:
```python
import os
import httpx
import pytest

API_URL = os.getenv("API_URL", "http://localhost:8000")


def _login(client, tenant_slug, email, password):
    r = client.post("/auth/login", json={
        "tenant_slug": tenant_slug, "email": email, "password": password})
    r.raise_for_status()
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_presign_rejects_non_image(client, world):
    h = _login(client, world["a_slug"], world["resident_email"], world["resident_password"])
    r = client.post("/uploads/presign",
                    json={"content_type": "application/pdf"}, headers=h)
    assert r.status_code == 422


def test_presign_image_ok_and_key_is_tenant_prefixed(client, world):
    h = _login(client, world["a_slug"], world["resident_email"], world["resident_password"])
    r = client.post("/uploads/presign",
                    json={"content_type": "image/jpeg", "boyut": 1024}, headers=h)
    assert r.status_code == 200
    body = r.json()
    assert body["method"] == "PUT"
    assert body["foto_key"].startswith(f"{world['a_tenant_id']}/")


def test_presign_rejects_oversize(client, world):
    h = _login(client, world["a_slug"], world["resident_email"], world["resident_password"])
    r = client.post("/uploads/presign",
                    json={"content_type": "image/png", "boyut": 9 * 1024 * 1024}, headers=h)
    assert r.status_code == 422
```
Adjust `world[...]` key names to the actual fixture (read `backend/tests/conftest.py:154-204` — it exposes slugs + per-role creds + tenant ids; use the exact keys, e.g. it may be `world["tenant_a"]["slug"]`). Match existing test files' access pattern (`test_complaints.py`).

- [ ] **Step 2: Run to verify it fails (server not yet rebuilt with Task 3).**

Run: `cd infra && docker compose up -d --build api && docker compose exec api pytest tests/test_uploads.py -v` (or the repo's test runner).
Expected: PASS actually — because Task 3 already added validation. If the api image wasn't rebuilt after Task 3, the non-image test fails (200 instead of 422). Rebuild, then all three PASS.

- [ ] **Step 3: Add a clarifying comment to `presign_put`** in `storage.py` (no logic change) documenting that content-type is bound into the signed URL and validated upstream in `PresignRequest`, size cap is client-declared/best-effort.

- [ ] **Step 4: Run tests — all pass.**

Run: `docker compose exec api pytest tests/test_uploads.py -v`
Expected: 3 passed.

- [ ] **Step 5: Commit.**
```bash
git add backend/app/storage.py backend/tests/test_uploads.py
git commit -m "test(ticketing): presign gorsel content-type/boyut dogrulama + tenant-onek testi"
```

---

## Task 5: Ticketing service + router reshape (create/list/detail/convert/resolve/decline)

**Files:**
- Create: `backend/app/ticketing.py`
- Modify: `backend/app/routers/complaints.py` (full rewrite of handlers)

**Interfaces:**
- Consumes: models (Task 2), schemas (Task 3).
- Produces (from `ticketing.py`):
  - `VALID_TRANSITIONS: dict[str, set[str]]`
  - `assert_transition(current: str, target: str) -> None` (raises `APIError(422,"invalid_transition")`)
  - `add_history(db, *, complaint, durum: str, actor_role: str, sebep: str|None) -> None`
  - `notify_opener(*, complaint, tenant_id, tip: str, mesaj: str) -> None`
- Produces (router): `POST /complaints`, `GET /complaints`, `GET /complaints/{id}`, `POST /complaints/{id}/convert`, `POST /complaints/{id}/resolve`, `POST /complaints/{id}/decline`.

- [ ] **Step 1: Write `backend/app/ticketing.py`:**
```python
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
            422, "invalid_transition",
            f"'{current}' -> '{target}' gecersiz gecis",
        )


def add_history(db, *, complaint, durum: str, actor_role: str,
                sebep: str | None) -> ComplaintStatusHistory:
    row = ComplaintStatusHistory(
        tenant_id=complaint.tenant_id,
        complaint_id=complaint.id,
        durum=durum,
        actor_role=actor_role,
        sebep=sebep,
    )
    db.add(row)
    return row


def notify_opener(*, complaint, tenant_id: uuid.UUID, tip: str, mesaj: str,
                  title: str = "Talep/Ariza") -> None:
    """EK push — talebi acana. Hatasi kaydi kirmaz (dispatch_external try/except)."""
    dispatch_external(
        mesaj, tenant_id=tenant_id, target_user_ids=(complaint.acan_user_id,),
        title=title, data={"tip": tip, "complaint_id": str(complaint.id)},
    )
```

- [ ] **Step 2: Rewrite `backend/app/routers/complaints.py`.** Full new content:
```python
"""Talep/Ariza — sakin/saha -> yonetim, uctan uca is-emri kanali (auth.md §4).

Durum makinesi: acik -> is_emri (donustur) -> cozuldu (+ reddedildi). ASCII
wire, TR etiket UI'da. Her gecis history satiri + acana push. Talepler her
zaman kimlikli (anonimlik /unit-complaints'te). Kategori = dinamik task_category.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..crud_helpers import translate_integrity
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import (
    AppUser, Complaint, ComplaintPhoto, ComplaintStatusHistory, Task, TaskCategory,
)
from ..schemas import (
    ComplaintConvertRequest, ComplaintCreate, ComplaintDeclineRequest, ComplaintDurum,
    ComplaintListResponse, ComplaintOut, ComplaintPhotoOut, ComplaintResolveRequest,
    ComplaintStatusHistoryOut,
)
from ..storage import presign_get
from ..ticketing import add_history, assert_transition, notify_opener
from ..scheduler.notify import dispatch_external

router = APIRouter(prefix="/complaints", tags=["complaints"])

_OPENER = require_role("security", "tesis_gorevlisi", "resident")
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi", "resident")
_MANAGER = require_role("admin", "yonetici")
_OWN_SCOPED_ROLES = ("security", "tesis_gorevlisi", "resident")
_MANAGEMENT_ROLES: tuple[str, ...] = ("admin", "yonetici")
_ATANABILIR_ROLLER = {"security", "tesis_gorevlisi"}


def _validate_foto_key(foto_key: str, tenant_id: uuid.UUID) -> None:
    if not foto_key.startswith(f"{tenant_id}/"):
        raise APIError(422, "invalid_foto_key", "foto_key tenant alani disinda")


def _sign(key: str) -> str | None:
    try:
        return presign_get(key)
    except APIError:
        return None


async def _load_out(db: AsyncSession, obj: Complaint, acan_ad: str | None) -> ComplaintOut:
    """Talebi fotolar + gecmis + bagli is-emri ozeti ile serialize eder."""
    out = ComplaintOut.model_validate(obj)
    out.acan_ad = acan_ad
    # kategori adi
    if obj.kategori_id is not None:
        out.kategori_ad = (
            await db.execute(select(TaskCategory.ad).where(TaskCategory.id == obj.kategori_id))
        ).scalar_one_or_none()
    # fotolar
    photos = (
        await db.execute(
            select(ComplaintPhoto).where(ComplaintPhoto.complaint_id == obj.id)
            .order_by(ComplaintPhoto.sira)
        )
    ).scalars().all()
    out.fotograflar = [
        ComplaintPhotoOut(id=p.id, foto_key=p.foto_key, sira=p.sira, foto_url=_sign(p.foto_key))
        for p in photos
    ]
    # gecmis (timeline)
    hist = (
        await db.execute(
            select(ComplaintStatusHistory).where(ComplaintStatusHistory.complaint_id == obj.id)
            .order_by(ComplaintStatusHistory.created_at)
        )
    ).scalars().all()
    out.gecmis = [ComplaintStatusHistoryOut.model_validate(h) for h in hist]
    # bagli is-emri
    task = (
        await db.execute(select(Task).where(Task.ticket_id == obj.id))
    ).scalars().first()
    if task is not None:
        out.is_emri_id = task.id
        # tamamlanma: task_completion varsa 'tamamlandi', yoksa 'acik'
        from ..models import TaskCompletion
        done = (
            await db.execute(
                select(func.count()).select_from(TaskCompletion)
                .where(TaskCompletion.task_id == task.id)
            )
        ).scalar_one()
        out.is_emri_durum = "tamamlandi" if done else "acik"
    return out


def _own_scope(stmt, user: AppUser):
    if user.role in _OWN_SCOPED_ROLES:
        return stmt.where(Complaint.acan_user_id == user.id)
    return stmt


async def _get_or_404(db: AsyncSession, complaint_id: uuid.UUID, user: AppUser):
    row = (
        await db.execute(
            _own_scope(
                select(Complaint, AppUser.ad)
                .join(AppUser, AppUser.id == Complaint.acan_user_id)
                .where(Complaint.id == complaint_id),
                user,
            )
        )
    ).first()
    if row is None:
        raise APIError(404, "not_found", "Kayit bulunamadi")
    return row  # (Complaint, acan_ad)


@router.get("", response_model=ComplaintListResponse)
async def list_complaints(
    durum: ComplaintDurum | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> ComplaintListResponse:
    stmt = select(Complaint, AppUser.ad).join(AppUser, AppUser.id == Complaint.acan_user_id)
    if durum is not None:
        stmt = stmt.where(Complaint.durum == durum)
    stmt = _own_scope(stmt, user)
    total = (await db.execute(select(func.count()).select_from(stmt.subquery()))).scalar_one()
    rows = (
        await db.execute(stmt.order_by(Complaint.created_at.desc()).limit(limit).offset(offset))
    ).all()
    items = [await _load_out(db, c, ad) for c, ad in rows]
    return ComplaintListResponse(meta={"limit": limit, "offset": offset, "total": total}, items=items)


@router.get("/{complaint_id}", response_model=ComplaintOut)
async def get_complaint(
    complaint_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_READER),
) -> ComplaintOut:
    obj, ad = await _get_or_404(db, complaint_id, user)
    return await _load_out(db, obj, ad)


@router.post("", response_model=ComplaintOut, status_code=201)
async def create_complaint(
    body: ComplaintCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_OPENER),
) -> ComplaintOut:
    for k in body.foto_keys:
        _validate_foto_key(k, user.tenant_id)
    obj = Complaint(
        tenant_id=user.tenant_id, acan_user_id=user.id,
        baslik=body.baslik, mesaj=body.mesaj, kategori_id=body.kategori_id,
    )
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    for i, k in enumerate(body.foto_keys):
        db.add(ComplaintPhoto(tenant_id=user.tenant_id, complaint_id=obj.id, foto_key=k, sira=i))
    add_history(db, complaint=obj, durum="acik", actor_role=user.role, sebep=None)
    await db.flush()
    await db.refresh(obj)
    dispatch_external(
        f"Yeni talep: {body.baslik}", tenant_id=user.tenant_id,
        target_roles=_MANAGEMENT_ROLES, title="Talep/Ariza",
        data={"tip": "talep", "complaint_id": str(obj.id)},
    )
    return await _load_out(db, obj, user.ad)


@router.post("/{complaint_id}/convert", response_model=ComplaintOut)
async def convert_complaint(
    complaint_id: uuid.UUID,
    body: ComplaintConvertRequest,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> ComplaintOut:
    obj, acan_ad = await _get_or_404(db, complaint_id, user)
    assert_transition(obj.durum, "is_emri")
    # atanan ayni tenant + saha rolu olmali
    atanan = (
        await db.execute(select(AppUser).where(AppUser.id == body.atanan_user_id))
    ).scalars().first()
    if atanan is None or atanan.role not in _ATANABILIR_ROLLER:
        raise APIError(422, "invalid_assignee", "atanan security/tesis_gorevlisi olmali")
    kategori_id = body.kategori_id if body.kategori_id is not None else obj.kategori_id
    task = Task(
        tenant_id=user.tenant_id, ad=obj.baslik, aciklama=obj.mesaj,
        atanan_user_id=body.atanan_user_id, kategori_id=kategori_id,
        oncelik=body.oncelik, ticket_id=obj.id, foto_zorunlu=False,
    )
    db.add(task)
    obj.durum = "is_emri"
    obj.updated_at = func.now()
    add_history(db, complaint=obj, durum="is_emri", actor_role=user.role, sebep=body.not_)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await db.refresh(obj)
    notify_opener(complaint=obj, tenant_id=user.tenant_id, tip="talep_is_emri",
                  mesaj=f"Talebiniz is emrine donusturuldu: {obj.baslik}")
    dispatch_external(
        f"Yeni is emri: {obj.baslik}", tenant_id=user.tenant_id,
        target_user_ids=(body.atanan_user_id,), title="Is Emri",
        data={"tip": "is_emri_atandi", "task_id": str(task.id), "complaint_id": str(obj.id)},
    )
    return await _load_out(db, obj, acan_ad)


@router.post("/{complaint_id}/resolve", response_model=ComplaintOut)
async def resolve_complaint(
    complaint_id: uuid.UUID,
    body: ComplaintResolveRequest,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> ComplaintOut:
    obj, acan_ad = await _get_or_404(db, complaint_id, user)
    assert_transition(obj.durum, "cozuldu")
    obj.durum = "cozuldu"
    obj.updated_at = func.now()
    add_history(db, complaint=obj, durum="cozuldu", actor_role=user.role, sebep=body.cozum_notu)
    await db.flush()
    await db.refresh(obj)
    notify_opener(complaint=obj, tenant_id=user.tenant_id, tip="talep_cozuldu",
                  mesaj=f"Talebiniz cozuldu: {obj.baslik}")
    return await _load_out(db, obj, acan_ad)


@router.post("/{complaint_id}/decline", response_model=ComplaintOut)
async def decline_complaint(
    complaint_id: uuid.UUID,
    body: ComplaintDeclineRequest,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_MANAGER),
) -> ComplaintOut:
    obj, acan_ad = await _get_or_404(db, complaint_id, user)
    assert_transition(obj.durum, "reddedildi")
    obj.durum = "reddedildi"
    obj.updated_at = func.now()
    add_history(db, complaint=obj, durum="reddedildi", actor_role=user.role, sebep=body.sebep)
    await db.flush()
    await db.refresh(obj)
    notify_opener(complaint=obj, tenant_id=user.tenant_id, tip="talep_reddedildi",
                  mesaj=f"Talebiniz reddedildi: {obj.baslik}")
    return await _load_out(db, obj, acan_ad)
```

- [ ] **Step 3: Rebuild api + smoke import.**

Run: `docker compose up -d --build api && docker compose exec api python -c "import app.main"`
Expected: no error (router imports resolve).

- [ ] **Step 4: Commit.**
```bash
git add backend/app/ticketing.py backend/app/routers/complaints.py
git commit -m "feat(ticketing): durum makinesi servisi + router (create foto/kategori, convert/resolve/decline, timeline)"
```

---

## Task 6: Task-completion auto-resolves the linked ticket + notifies opener

**Files:**
- Modify: `backend/app/routers/tasks.py` (completion handler `POST /{task_id}/completions`, ~275-364)

**Interfaces:**
- Consumes: `Task.ticket_id`, `ticketing.add_history`, `ticketing.notify_opener`, `Complaint`.
- Produces: on a successful (non-idempotent-replay) completion of a task with `ticket_id`, set the linked `complaint.durum = "cozuldu"`, write a history row (`actor_role` = completer's role), notify opener.

- [ ] **Step 1: In the completion handler, after the completion row is successfully inserted (the branch that returns 201 for a fresh insert — NOT the idempotent 200 replay), add:**
```python
    # Ticket-linked task tamamlandiysa talebi oto-coz (yalniz taze insert'te).
    if task.ticket_id is not None:
        complaint = (
            await db.execute(
                select(Complaint).where(Complaint.id == task.ticket_id)
            )
        ).scalars().first()
        if complaint is not None and complaint.durum == "is_emri":
            from ..ticketing import add_history, notify_opener
            complaint.durum = "cozuldu"
            complaint.updated_at = func.now()
            add_history(db, complaint=complaint, durum="cozuldu",
                        actor_role=user.role, sebep=None)
            await db.flush()
            notify_opener(complaint=complaint, tenant_id=user.tenant_id,
                          tip="talep_cozuldu",
                          mesaj=f"Talebiniz cozuldu: {complaint.baslik}")
```
Add `from ..models import Complaint` and `select`/`func` if not already imported at the top of `tasks.py` (they are — verify). Place this block so it runs only on the fresh-insert path (guard with the same condition that distinguishes 201 from the idempotent 200 replay; read lines ~330-364 to find the exact variable, e.g. `if created:` or the post-`begin_nested` success branch).

- [ ] **Step 2: Rebuild + import smoke.**

Run: `docker compose up -d --build api && docker compose exec api python -c "import app.main"`
Expected: no error.

- [ ] **Step 3: Commit.**
```bash
git add backend/app/routers/tasks.py
git commit -m "feat(ticketing): bagli gorev tamamlaninca talep oto-cozuldu + acana push"
```

---

## Task 7: Backend tests — transitions, convert, complete, decline, RBAC, isolation, notifications

**Files:**
- Create: `backend/tests/test_ticketing.py`
- Modify: `backend/tests/test_complaints.py` (update stale assumptions: durum enum, foto_keys, removed yonetici_yaniti/PATCH)

**Interfaces:**
- Consumes: live server, `world` fixture, `_login` helper pattern.

- [ ] **Step 1: Read `backend/tests/conftest.py` `world` fixture + `test_complaints.py`** to lock exact fixture keys and helper style. Note which roles exist in tenant A (admin, yonetici, security, tesis_gorevlisi, resident) and B (admin, yonetici).

- [ ] **Step 2: Write `backend/tests/test_ticketing.py`.** Use the actual `world` keys; the code below assumes helper `_login(client, slug, email, pw)` and `world` exposing `a_slug`, per-role `*_email`/`*_password`, `a_tenant_id`, and a helper to create a task category. Adjust names to match conftest.
```python
import os, uuid, httpx, pytest

API_URL = os.getenv("API_URL", "http://localhost:8000")


def _login(client, slug, email, pw):
    r = client.post("/auth/login", json={"tenant_slug": slug, "email": email, "password": pw})
    r.raise_for_status()
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _mk_category(client, mgr_h, ad="Elektrik"):
    r = client.post("/task-categories", json={"ad": ad}, headers=mgr_h)
    r.raise_for_status()
    return r.json()["id"]


def _open_ticket(client, opener_h, kategori_id=None, foto_keys=None):
    body = {"baslik": "Asansor arizasi", "mesaj": "Asansor calismiyor"}
    if kategori_id:
        body["kategori_id"] = kategori_id
    if foto_keys:
        body["foto_keys"] = foto_keys
    r = client.post("/complaints", json=body, headers=opener_h)
    assert r.status_code == 201, r.text
    return r.json()


def test_open_ticket_writes_acik_history(client, world):
    res_h = _login(client, world["a_slug"], world["resident_email"], world["resident_password"])
    t = _open_ticket(client, res_h)
    assert t["durum"] == "acik"
    assert [h["durum"] for h in t["gecmis"]] == ["acik"]
    assert t["gecmis"][0]["actor_role"] == "resident"


def test_convert_creates_task_and_sets_is_emri(client, world):
    res_h = _login(client, world["a_slug"], world["resident_email"], world["resident_password"])
    yon_h = _login(client, world["a_slug"], world["yonetici_email"], world["yonetici_password"])
    kat = _mk_category(client, yon_h)
    t = _open_ticket(client, res_h, kategori_id=kat)
    # atanan = security kullanicisi
    who = client.get("/auth/me", headers=_login(client, world["a_slug"],
                     world["security_email"], world["security_password"]))
    sec_id = who.json()["id"]
    r = client.post(f"/complaints/{t['id']}/convert",
                    json={"atanan_user_id": sec_id, "oncelik": "yuksek", "not": "acil"},
                    headers=yon_h)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["durum"] == "is_emri"
    assert body["is_emri_id"] is not None
    assert body["is_emri_durum"] == "acik"
    assert [h["durum"] for h in body["gecmis"]] == ["acik", "is_emri"]


def test_completion_auto_resolves_ticket(client, world):
    res_h = _login(client, world["a_slug"], world["resident_email"], world["resident_password"])
    yon_h = _login(client, world["a_slug"], world["yonetici_email"], world["yonetici_password"])
    sec_h = _login(client, world["a_slug"], world["security_email"], world["security_password"])
    sec_id = client.get("/auth/me", headers=sec_h).json()["id"]
    t = _open_ticket(client, res_h)
    conv = client.post(f"/complaints/{t['id']}/convert",
                       json={"atanan_user_id": sec_id, "oncelik": "orta"}, headers=yon_h).json()
    task_id = conv["is_emri_id"]
    r = client.post(f"/tasks/{task_id}/completions", json={},
                    headers={**sec_h, "Idempotency-Key": str(uuid.uuid4())})
    assert r.status_code == 201, r.text
    detail = client.get(f"/complaints/{t['id']}", headers=yon_h).json()
    assert detail["durum"] == "cozuldu"
    assert [h["durum"] for h in detail["gecmis"]] == ["acik", "is_emri", "cozuldu"]


def test_decline_requires_reason(client, world):
    res_h = _login(client, world["a_slug"], world["resident_email"], world["resident_password"])
    yon_h = _login(client, world["a_slug"], world["yonetici_email"], world["yonetici_password"])
    t = _open_ticket(client, res_h)
    assert client.post(f"/complaints/{t['id']}/decline", json={}, headers=yon_h).status_code == 422
    r = client.post(f"/complaints/{t['id']}/decline", json={"sebep": "gecersiz"}, headers=yon_h)
    assert r.status_code == 200 and r.json()["durum"] == "reddedildi"


def test_invalid_transition_rejected(client, world):
    res_h = _login(client, world["a_slug"], world["resident_email"], world["resident_password"])
    yon_h = _login(client, world["a_slug"], world["yonetici_email"], world["yonetici_password"])
    t = _open_ticket(client, res_h)
    client.post(f"/complaints/{t['id']}/resolve", json={}, headers=yon_h)  # -> cozuldu
    # cozuldu terminal: tekrar decline 422
    assert client.post(f"/complaints/{t['id']}/decline",
                       json={"sebep": "x"}, headers=yon_h).status_code == 422


def test_resident_cannot_convert(client, world):
    res_h = _login(client, world["a_slug"], world["resident_email"], world["resident_password"])
    t = _open_ticket(client, res_h)
    r = client.post(f"/complaints/{t['id']}/convert",
                    json={"atanan_user_id": str(uuid.uuid4()), "oncelik": "orta"}, headers=res_h)
    assert r.status_code == 403


def test_cross_tenant_404(client, world):
    res_h = _login(client, world["a_slug"], world["resident_email"], world["resident_password"])
    t = _open_ticket(client, res_h)
    b_yon = _login(client, world["b_slug"], world["b_yonetici_email"], world["b_yonetici_password"])
    assert client.get(f"/complaints/{t['id']}", headers=b_yon).status_code == 404


def test_resolve_note_in_timeline(client, world):
    res_h = _login(client, world["a_slug"], world["resident_email"], world["resident_password"])
    yon_h = _login(client, world["a_slug"], world["yonetici_email"], world["yonetici_password"])
    t = _open_ticket(client, res_h)
    r = client.post(f"/complaints/{t['id']}/resolve",
                    json={"cozum_notu": "yerinde halledildi"}, headers=yon_h).json()
    assert r["gecmis"][-1]["sebep"] == "yerinde halledildi"
```

- [ ] **Step 3: Update `test_complaints.py`** — remove/adjust any assertion referencing `inceleniyor`, `yonetici_yaniti`, `foto_key` (singular), `PATCH /complaints/{id}`, or `kategori` as enum. Where it opened complaints, switch to `foto_keys`/`kategori_id`. Delete tests exercising the removed PATCH path (their behavior is now covered by convert/resolve/decline in `test_ticketing.py`).

- [ ] **Step 4: Run the full ticketing + complaints + uploads suite.**

Run: `cd infra && docker compose down -v && docker compose up -d --build && <seed cmd> && docker compose exec api pytest tests/test_ticketing.py tests/test_complaints.py tests/test_uploads.py -v`
Expected: all pass. (Note the flake memory: avoid time-of-day-sensitive assertions; none here.)

- [ ] **Step 5: Run the FULL backend suite to catch regressions from the complaint reshape.**

Run: `docker compose exec api pytest -q`
Expected: all pass. Fix any test elsewhere that referenced the old complaint shape.

- [ ] **Step 6: Commit.**
```bash
git add backend/tests/test_ticketing.py backend/tests/test_complaints.py
git commit -m "test(ticketing): gecisler/convert/complete/decline/RBAC/cross-tenant/timeline"
```

---

## Task 8: Contracts — openapi.yaml + auth.md

**Files:**
- Modify: `contracts/openapi.yaml` (schemas near `Complaint` ~5391; paths near `/complaints` ~1048; `Task`; `PresignRequest`)
- Modify: `contracts/auth.md` (§4 matrix ~258-260 + prose)

**Interfaces:**
- Produces: the binding contract both frontends mirror.

- [ ] **Step 1: Update the `Complaint` schema** — `durum enum [acik,is_emri,cozuldu,reddedildi]`; replace `kategori`/`foto_key`/`foto_url`/`yonetici_yaniti`/`yanitlayan_user_id`/`yanit_zamani` with `kategori_id`(uuid,nullable), `kategori_ad`(nullable), `fotograflar` (array of `ComplaintPhoto`), `gecmis` (array of `ComplaintStatusHistory`), `is_emri_id`(uuid,nullable), `is_emri_durum`(string,nullable). Add schemas `ComplaintPhoto {id,foto_key,sira,foto_url}`, `ComplaintStatusHistory {durum,actor_role,sebep,created_at}`, `ComplaintCreate {baslik,mesaj,kategori_id?,foto_keys[]≤3}`, `ComplaintConvertRequest {kategori_id?,oncelik(enum),atanan_user_id,not?}`, `ComplaintResolveRequest {cozum_notu?}`, `ComplaintDeclineRequest {sebep(required)}`. Remove `ComplaintUpdate`, `ComplaintKategori`, `ComplaintDurum` old values.

- [ ] **Step 2: Update paths** — remove `PATCH /complaints/{id}`; add `POST /complaints/{id}/convert`, `POST /complaints/{id}/resolve`, `POST /complaints/{id}/decline` with the request/response schemas and RBAC notes; `POST /complaints` body → `ComplaintCreate`.

- [ ] **Step 3: `Task` schema** — add `ticket_id`(uuid,nullable), `oncelik`(enum `dusuk|orta|yuksek`,nullable). `PresignRequest` — add `boyut`(int,nullable) + note content-type must be image/*.

- [ ] **Step 4: `auth.md §4`** — replace the three complaint rows with ticketing rows (open: sec/tg/res ✅, admin/yon ❌; GET °own; convert/resolve/decline: admin/yon only; complete linked task: field roles). Add a "Talep durum makinesi" prose subsection (the diagram from the spec), a "Talep fotograflari" note (presign footnote style, ≤3 + image-only content-type), and an explicit line: anonimlik talepte YOK — anonim kanal `/unit-complaints`.

- [ ] **Step 5: Validate the OpenAPI file parses.**

Run: `docker compose exec api python -c "import yaml,io; yaml.safe_load(open('/app/contracts/openapi.yaml'))"` (adjust path; or run a repo lint script if present).
Expected: no YAML error.

- [ ] **Step 6: Commit.**
```bash
git add contracts/openapi.yaml contracts/auth.md
git commit -m "docs(ticketing): openapi + auth.md — talep durum makinesi, convert/resolve/decline, foto kurallari, RBAC"
```

---

## Task 9: Seed — demo tickets in mixed states

**Files:**
- Modify: the seed script (locate: `grep -rl "Complaint\|complaint" infra/ backend/ --include=*.py | xargs grep -l seed` or inspect `infra/` compose `seed` service entrypoint).

**Interfaces:**
- Consumes: reshaped models. Produces 4 demo tickets in tenant demo data.

- [ ] **Step 1: Locate the seed entrypoint** and the existing complaint seeding (if any). Read how it creates users/categories so ids are available.

- [ ] **Step 2: Add 4 tickets** for the demo tenant, reusing seeded resident + a task category + a field user:
  1. `acik`, no photos.
  2. `acik`, with 2 `complaint_photo` rows (use plausible tenant-prefixed keys, e.g. `{tenant_id}/tasks/seed-foto-1.jpg`).
  3. `is_emri`: create the complaint, a linked `task` (`ticket_id`, `oncelik='orta'`, `atanan_user_id`=field user), and history rows `acik`→`is_emri`.
  4. `is_emri`→`cozuldu`: as #3 plus a `task_completion` (with a `foto_key` proof) and history `acik`→`is_emri`→`cozuldu`; set complaint `durum='cozuldu'`.
Write `complaint_status_history` rows for each so timelines demo well.

- [ ] **Step 3: Rebuild seed image + run seed + verify.**

Run: `cd infra && docker compose up -d --build && <seed cmd>` then `docker compose exec api python -c "import asyncio"` … or simply query: `docker compose exec db psql -U <u> -d <db> -c "SELECT durum,count(*) FROM complaint GROUP BY durum;"`
Expected: rows across `acik/is_emri/cozuldu`.

- [ ] **Step 4: Commit.**
```bash
git add <seed files>
git commit -m "feat(ticketing): seed — 4 demo talep (acik/fotolu/is_emri/tamamlanmis-kanitli)"
```

---

## Task 10: Mobile — Dart models + API client

**Files:**
- Modify: `mobile/lib/src/features/complaints/domain/complaint_models.dart`
- Modify: `mobile/lib/src/features/complaints/data/complaint_api.dart`

**Interfaces:**
- Produces: `TalepDurum` enum (`acik|isEmri|cozuldu|reddedildi|unknown`), `ComplaintPhoto`, `ComplaintHistory`, reshaped `Complaint` model; api methods `create(...)`, `list(...)`, `get(id)`, `convert(...)`, `resolve(...)`, `decline(...)`, plus existing presign/upload.

- [ ] **Step 1: Rewrite `complaint_models.dart`** mirroring the new OpenAPI `Complaint`. Enum with `fromWire`/`wire`:
```dart
enum TalepDurum { acik, isEmri, cozuldu, reddedildi, unknown }

TalepDurum talepDurumFromWire(String? s) => switch (s) {
  'acik' => TalepDurum.acik,
  'is_emri' => TalepDurum.isEmri,
  'cozuldu' => TalepDurum.cozuldu,
  'reddedildi' => TalepDurum.reddedildi,
  _ => TalepDurum.unknown,
};
```
Add `ComplaintPhoto {id, fotoKey, sira, fotoUrl}`, `ComplaintHistory {durum, actorRole, sebep, createdAt}`, and `Complaint {id, acanUserId, acanAd, baslik, mesaj, kategoriId, kategoriAd, durum, fotograflar[], gecmis[], isEmriId, isEmriDurum, createdAt, updatedAt}` with `fromJson`. Follow the existing file's JSON idiom.

- [ ] **Step 2: Update `complaint_api.dart`** — `create` sends `{baslik, mesaj, kategori_id?, foto_keys: [...]}`; add `convert(id, {kategoriId, oncelik, atananUserId, not})` → `POST /complaints/{id}/convert`, `resolve(id, {cozumNotu})`, `decline(id, {sebep})`. Keep the existing dual-Dio presign upload (`_uploadDio`) unchanged. Add a `listTaskCategories()` call (reuse existing task category API if the tasks feature exposes one; else `GET /task-categories`) for the create-form category picker.

- [ ] **Step 3: Analyze.**

Run: `cd mobile && flutter analyze lib/src/features/complaints`
Expected: no errors (warnings ok if pre-existing).

- [ ] **Step 4: Commit.**
```bash
git add mobile/lib/src/features/complaints/domain/complaint_models.dart mobile/lib/src/features/complaints/data/complaint_api.dart
git commit -m "feat(mobile/ticketing): talep model + api (foto_keys, kategori, convert/resolve/decline)"
```

---

## Task 11: Mobile — create form (multi-photo ≤3 + dynamic category) + list chips

**Files:**
- Modify: `mobile/lib/src/features/complaints/presentation/complaints_screen.dart`
- Modify: `mobile/lib/src/features/complaints/presentation/complaints_controller.dart`

**Interfaces:**
- Consumes: Task 10 api/models. Produces the resident create + "Taleplerim" list UI.

- [ ] **Step 1: Extend the controller** to hold up to 3 photo slots (list of `{path, busy, fotoKey}`), a category list loaded on open, and selected `kategoriId`. Reuse the shared `imagePickerProvider` and the existing single-photo upload logic, generalized to a list capped at 3. Keep `_fotoBekliyor` semantics (block submit while any slot uploading).

- [ ] **Step 2: Rework `_ComplaintForm`** — replace the single photo widget with a horizontal row of up to 3 thumbnails + an "Ekle" tile (Kamera/Galeri sheet) disabled at 3; add a category `ChoiceChip`/dropdown from the loaded task categories (optional → "Diğer"). Submit sends `foto_keys` + `kategori_id`.

- [ ] **Step 3: Update the list durum chip colors** to the ticketing palette:
```dart
Color _durumColor(TalepDurum d) => switch (d) {
  TalepDurum.acik => Colors.amber,
  TalepDurum.isEmri => Colors.blue,
  TalepDurum.cozuldu => Colors.green,
  TalepDurum.reddedildi => Colors.red,
  TalepDurum.unknown => Colors.grey,
};
```
Relabel the app-bar/tab/section titles to "Talep / Arıza" (via existing `tr_upper`). Update tab structure to filter by the new durum values (Açık / İş Emri / Çözülen / Reddedilen), or a single list + filter — match the existing tabbed pattern.

- [ ] **Step 4: Build + analyze.**

Run: `cd mobile && flutter analyze lib/src/features/complaints`
Expected: no errors.

- [ ] **Step 5: Commit.**
```bash
git add mobile/lib/src/features/complaints/presentation/complaints_screen.dart mobile/lib/src/features/complaints/presentation/complaints_controller.dart
git commit -m "feat(mobile/ticketing): create formu coklu foto (<=3) + dinamik kategori + durum chip renkleri"
```

---

## Task 12: Mobile — detail with photo gallery + vertical status timeline

**Files:**
- Modify: `mobile/lib/src/features/complaints/presentation/complaints_screen.dart` (`_ComplaintDetail`)

**Interfaces:**
- Consumes: `Complaint.fotograflar`, `Complaint.gecmis`, `Complaint.isEmriDurum`.

- [ ] **Step 1: Replace the detail bottom-sheet body** with: a photo gallery (reuse the existing `Image.network(fotoUrl, loadingBuilder, errorBuilder)` + full-screen `InteractiveViewer`) iterating `fotograflar`; then a **vertical timeline stepper** built from `gecmis` — one node per history row showing the TR durum label, actor role label, `sebep` (if present), and localized timestamp. Implement the stepper as a simple `Column` of rows (dot + connector line + text) — no new package.
- [ ] **Step 2:** If `durum == isEmri`, show a small card with the linked work-order live status (`isEmriDurum`: "Atandı" / "Tamamlandı").
- [ ] **Step 3: Build + analyze.**

Run: `cd mobile && flutter analyze lib/src/features/complaints`
Expected: no errors.

- [ ] **Step 4: Commit.**
```bash
git add mobile/lib/src/features/complaints/presentation/complaints_screen.dart
git commit -m "feat(mobile/ticketing): detay — foto galerisi + dikey durum timeline + bagli is emri durumu"
```

---

## Task 13: Mobile — yönetici convert/resolve/decline sheets + assignee ticket context

**Files:**
- Modify: `mobile/lib/src/features/complaints/presentation/complaints_screen.dart` (yönetici actions)
- Modify: `mobile/lib/src/features/complaints/presentation/complaints_controller.dart`
- Modify: `mobile/lib/src/features/tasks/presentation/task_detail_screen.dart` (linked ticket info)

**Interfaces:**
- Consumes: Task 10 api convert/resolve/decline; assignee-user list (reuse tasks feature's user list if present, else a lightweight fetch of assignable users).

- [ ] **Step 1: Add yönetici action bar** in the detail sheet, gated by role (`canRespondComplaints`/management): "İş Emrine Dönüştür", "Çöz", "Reddet" — visible only when `durum == acik`.
- [ ] **Step 2: "İş Emrine Dönüştür" bottom-sheet** — fields: kategori (prefilled from ticket, editable, from task categories), öncelik `SegmentedButton<TalepOncelik>` (Düşük/Orta/Yüksek), atanan (dropdown of security/tesis_gorevlisi users), opsiyonel not. Submit → `api.convert(...)` → refresh + SnackBar.
- [ ] **Step 3: "Reddet" sheet** — mandatory `sebep` TextField (submit disabled while empty) → `api.decline`. "Çöz" sheet — optional çözüm notu → `api.resolve`.
- [ ] **Step 4: Assignee ticket context** in `task_detail_screen.dart` — when the task has a `ticketId` (add `ticketId` to the task model if missing; mirror OpenAPI `Task.ticket_id`), show a card with the linked ticket's kategori/açıklama/photos/unit (fetch via `GET /complaints/{ticketId}` — assignee is management-readable? NO: assignee is field role, own-scoped on complaints). **Instead** surface ticket context the task already carries: the task's `ad`/`aciklama` are copied from the ticket at convert; display those + note "İş emri kaynağı: talep". If photos are needed on the assignee side, include the ticket's `foto_keys` into the task creation (out of scope for v1 unless trivial) — for v1 show ad/aciklama/oncelik. Keep the existing completion+proof photo step as-is (auto-resolves the ticket server-side).
- [ ] **Step 5: Build the APK (acceptance gate).**

Run: `cd mobile && flutter analyze && flutter build apk --debug`
Expected: analyze clean; APK builds.

- [ ] **Step 6: Run flutter tests.**

Run: `cd mobile && flutter test`
Expected: pass (add/adjust any widget test referencing old complaint shape).

- [ ] **Step 7: Commit.**
```bash
git add mobile/lib/src/features/complaints/presentation/ mobile/lib/src/features/tasks/presentation/task_detail_screen.dart
git commit -m "feat(mobile/ticketing): yonetici convert/resolve/decline sheet'leri + atanan is-emri baglam karti"
```

---

## Task 14: Admin-web — types + BFF proxy routes

**Files:**
- Modify: `admin-web/lib/types.ts` (`Complaint` interface)
- Create: `admin-web/app/api/complaints/[id]/convert/route.ts`, `.../resolve/route.ts`, `.../decline/route.ts`

**Interfaces:**
- Produces: TS `Complaint` mirror + BFF proxies via `proxyJson`.

- [ ] **Step 1: Update `lib/types.ts`** — `ComplaintDurum = "acik"|"is_emri"|"cozuldu"|"reddedildi"`; reshape `Complaint` to `{id, acan_user_id, acan_ad, baslik, mesaj, kategori_id?, kategori_ad?, durum, fotograflar: {id,foto_key,sira,foto_url}[], gecmis: {durum,actor_role,sebep,created_at}[], is_emri_id?, is_emri_durum?, created_at, updated_at}`.

- [ ] **Step 2: Create the three BFF routes**, each mirroring `app/api/complaints/[id]/route.ts` idiom (nodejs runtime, force-dynamic, `proxyJson`):
```ts
// admin-web/app/api/complaints/[id]/convert/route.ts
import { proxyJson } from "@/lib/backend";
export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export async function POST(req: Request, { params }: { params: { id: string } }) {
  const body = await req.json();
  return proxyJson(`/complaints/${params.id}/convert`, "POST", body);
}
```
Repeat for `resolve` and `decline` (same shape, different path). Match the exact `proxyJson` signature and param typing used by the existing `[id]/route.ts` (App Router may require `params: Promise<...>` in this repo's Next version — copy the existing file's signature verbatim).

- [ ] **Step 3: Typecheck.**

Run: `cd admin-web && npx tsc --noEmit`
Expected: no errors.

- [ ] **Step 4: Commit.**
```bash
git add admin-web/lib/types.ts admin-web/app/api/complaints
git commit -m "feat(admin-web/ticketing): Complaint tipi reshape + convert/resolve/decline BFF proxy'leri"
```

---

## Task 15: Admin-web — complaints page durum column/filter + photos + actions + linked work-order

**Files:**
- Modify: `admin-web/app/(protected)/complaints/page.tsx`

**Interfaces:**
- Consumes: Task 14 types + routes; `tableCardCls`/`EmptyState`/`Toast`/`apiSend`/`useToast`.

- [ ] **Step 1: Update `DURUM_META`** to the four ticket states (mobil ile ayni kod):
```tsx
const DURUM_META: Record<ComplaintDurum, { label: string; cls: string }> = {
  acik:      { label: "Açık",       cls: "bg-amber-100 text-amber-700" },
  is_emri:   { label: "İş Emri",    cls: "bg-blue-100 text-blue-700" },
  cozuldu:   { label: "Çözüldü",    cls: "bg-green-100 text-green-700" },
  reddedildi:{ label: "Reddedildi", cls: "bg-red-100 text-red-700" },
};
```
If `amber`/`red` accents aren't already dark-mapped, add their `.dark .bg-amber-100 {...}` / `.dark .bg-red-100 {...}` mappings in `admin-web/app/globals.css` (do NOT add per-page `dark:` variants).

- [ ] **Step 2: Filter pills** → Tümü / Açık / İş Emri / Çözüldü / Reddedildi (query `?durum=`). Relabel page title to "Talep / Arıza".

- [ ] **Step 3: Card** — replace the old inline durum/yanıt editor. Show kategori_ad, photo thumbnails (`fotograflar[].foto_url` `<img>` → full size), a compact timeline (map `gecmis`), and, if `is_emri_id`, a **read-only** "Bağlı İş Emri: {is_emri_durum}" reference. For `durum === "acik"`, show actions: **Reddet** (prompt/modal for mandatory `sebep`) → `apiSend POST /api/complaints/{id}/decline` and **Çöz** (optional not) → `.../resolve`, each `toast.success` + `mutate()`. (Convert with assignee selection is management-heavy; for admin-web v1 keep convert to mobile — panel shows read-only linked work-order per the spec. Reddet/Çöz are the panel mutations.)

- [ ] **Step 4: Build (acceptance gate).**

Run: `cd admin-web && npm run build`
Expected: build succeeds.

- [ ] **Step 5: Commit.**
```bash
git add admin-web/app/(protected)/complaints/page.tsx admin-web/app/globals.css
git commit -m "feat(admin-web/ticketing): durum kolon/filtre + foto + timeline + bagli is emri + reddet/coz"
```

---

## Task 16: Full acceptance verification

**Files:** none (verification only)

- [ ] **Step 1: Backend clean cycle.**

Run: `cd infra && docker compose down -v && docker compose up -d --build && <seed cmd> && docker compose exec api pytest -q`
Expected: all green.

- [ ] **Step 2: Mobile gates.**

Run: `cd mobile && flutter analyze && flutter test && flutter build apk --debug`
Expected: all pass.

- [ ] **Step 3: Admin-web gate.**

Run: `cd admin-web && npm run build`
Expected: success.

- [ ] **Step 4: End-to-end manual smoke** (use the `/verify` skill or drive via the running stack): resident opens a ticket with a photo → yönetici converts (mobile) → assignee completes with proof → resident sees full timeline `acik→is_emri→cozuldu` + the linked work-order status. Confirm the panel shows the durum column + linked work-order read-only.

- [ ] **Step 5: Final commit (docs/summary if any).**
```bash
git add -A
git commit -m "chore(ticketing): v1 uctan uca — kabul dogrulamasi gecti"
```

---

## Self-Review Notes (author checklist — completed)

- **Spec coverage:** create+photos+category (T5/T11), status model+history (T1/T2/T5), convert→task (T5), completion auto-resolve (T6), notifications (T5/T6), decline+reason (T5), mobile resident/yönetici/assignee (T11-13), admin-web (T14-15), auth.md (T8), seed (T9), tests incl. invalid transitions/RBAC/cross-tenant/photo validation (T4/T7). Anonymity intentionally dropped (documented). ✓
- **Type consistency:** `foto_keys` (create) vs `fotograflar` (out) are intentionally distinct (input keys vs output objects), mirrored across backend schema, OpenAPI, Dart, TS. `durum` values identical everywhere. `is_emri_durum` values `acik|tamamlandi` consistent (T5 §_load_out, T7 assertions, TS type). ✓
- **Open verification points flagged for the implementer** (resolve during execution, not placeholders): exact `world` fixture key names (T7 Step 1), the fresh-insert branch variable in `tasks.py` completion (T6 Step 1), the Next.js route `params` signature (T14 Step 2), the seed entrypoint location (T9 Step 1), and the repo's exact `pytest`/`seed` invocation (compose service names). Each step says to read the concrete file first.
