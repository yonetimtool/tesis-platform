# Ana Ekran Görsel Zenginleştirme — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Referans görsellere (docs/design-refs) göre: duyuru kartına resim, 4'lü kompakt ızgaralar, hava durumu, personel profil fotoğrafı, vardiya↔personel ataması ve kamera MVP'si.

**Architecture:** Backend FastAPI + SQLAlchemy (async) + Alembic migration (`contracts/db/migrations`), RLS'li Postgres, MinIO presign foto deseni. Mobil Flutter + Riverpod + Dio; ana ekran "saf gövde + provider glue" deseni (RoleHomeBody). Tek migration (0005) dört şema değişikliğini taşır; iş paketleri B→A→C→D→E→F sırasında bağımsız commit'lenir.

**Tech Stack:** FastAPI, SQLAlchemy async, Alembic (raw SQL op.execute), psycopg (test fixture), httpx (hava proxy + testler), Flutter/Riverpod/Dio/GoRouter, `image_picker` (mevcut), `video_player` (YENİ, WP-F).

**Spec:** `docs/superpowers/specs/2026-07-24-home-gorsel-zenginlestirme-design.md`

## Global Constraints

- **Backend testleri CANLI api container'ına gider** (httpx `client` fixture, monkeypatch yok). Backend/test düzenlemesinden sonra ZORUNLU: `cd infra && docker compose build api && docker compose up -d api`, sonra `docker compose exec -T api sh -c "pytest -q tests/<dosya> 2>&1 | tail -5"`.
- Migration'lar İLERİ-YÖNLÜ ve additive; 0001-0004 IMMUTABLE. Migration değişikliği sonrası: `cd infra && docker compose down -v && docker compose up -d --build` (migrate servisi uygular) + `docker compose build seed && docker compose run --rm seed`.
- Her backend RBAC değişikliğinde `contracts/auth.md` §4 aynı commit'te güncellenir.
- `models.py` yalnız MIRROR'dır — DDL kaynağı migration; ikisi aynı commit'te eşleşir.
- Mobil: yorumlar/adlandırma Türkçe (ASCII yorum), UI metinleri Türkçe. Savunmacı JSON parse (`as String? ?? ''` deseni). Ana ekran bölümleri hata/boş durumda SESSİZCE gizlenir; ekran asla düşmez.
- TDD: her adımda önce KIRMIZI test, sonra minimal kod. Mobil tam doğrulama: `cd mobile && flutter analyze && flutter test` (mevcut suite 558+; her görev sonunda tamamı yeşil).
- Renk sabitleri: marka navy `0xFF0E3C91` / teal `0xFF1DB2B6` (`core/branding/yonetio_logo.dart`); pastel vurgular mevcut kartlardaki sabitler.
- Commit mesajı dili mevcut geçmişle uyumlu: `feat(scope): turkce-ascii ozet`.

---

### Task 1: WP-B — Duyurular kartına resim thumbnail'i

**Files:**
- Modify: `mobile/lib/src/features/home/presentation/duyurular_karti.dart`
- Create: `mobile/test/duyurular_karti_test.dart`

**Interfaces:**
- Consumes: `Announcement.fotoUrl` (mevcut model alanı; `sonDuyurularProvider` zaten dolduruyor).
- Produces: değişiklik yok — `DuyurularKarti` imzası aynı kalır (salt iç düzen).

- [ ] **Step 1: Kırmızı test yaz**

`mobile/test/duyurular_karti_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/announcements/domain/announcement_models.dart';
import 'package:mobile/src/features/home/presentation/duyurular_karti.dart';

Announcement _duyuru({String? fotoUrl}) => Announcement(
      id: 'a1',
      baslik: 'Bahçe Düzenlemesi',
      govde: 'Site bahçemizde peyzaj düzenlemesi yapılacaktır.',
      olusturanUserId: 'u1',
      createdAt: DateTime(2026, 7, 20),
      updatedAt: DateTime(2026, 7, 20),
      fotoUrl: fotoUrl,
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final now = DateTime(2026, 7, 21);

  testWidgets('fotoUrl varsa thumbnail cizilir', (tester) async {
    await tester.pumpWidget(_wrap(DuyurularKarti(
      duyurular: [_duyuru(fotoUrl: 'https://example.com/foto.jpg')],
      now: now,
      onTumu: () {},
    )));
    // Thumbnail Image widget'i olarak render edilir (network yuklenmese de
    // widget agacinda bulunur).
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Bahçe Düzenlemesi'), findsOneWidget);
  });

  testWidgets('fotoUrl yoksa Image cizilmez (metin-only kart)', (tester) async {
    await tester.pumpWidget(_wrap(DuyurularKarti(
      duyurular: [_duyuru()],
      now: now,
      onTumu: () {},
    )));
    expect(find.byType(Image), findsNothing);
    expect(find.text('Bahçe Düzenlemesi'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Testin KIRMIZI olduğunu gör**

Run: `cd mobile && flutter test test/duyurular_karti_test.dart`
Expected: FAIL — ilk test `findsOneWidget` yerine `findsNothing` (Image yok).

- [ ] **Step 3: Thumbnail'i ekle**

`duyurular_karti.dart` içinde kart gövdesini `Row` ile sarmala: `fotoUrl != null` ise solda 72×72 yuvarlatılmış resim, sağda mevcut `Column`. `Image.network` `errorBuilder` ile hata durumunda `SizedBox.shrink()` döner (kart metne düşer):

```dart
child: Padding(
  padding: const EdgeInsets.all(16),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (d.fotoUrl != null) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            d.fotoUrl!,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            // Yuklenemeyen gorsel karti BOZMAZ — bos kutuya duser.
            errorBuilder: (_, _, _) =>
                const SizedBox(width: 72, height: 72),
          ),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... mevcut baslik satiri + govde + tarih AYNEN buraya tasinir
          ],
        ),
      ),
    ],
  ),
),
```

- [ ] **Step 4: Testleri koş** — `flutter test test/duyurular_karti_test.dart` PASS; ardından `flutter analyze` temiz.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/src/features/home/presentation/duyurular_karti.dart mobile/test/duyurular_karti_test.dart
git commit -m "feat(mobile/home): WP-B — duyurular kartina resim thumbnail'i (referans site-sakini)"
```

---

### Task 2: WP-A — 4'lü kompakt dizilim

**Files:**
- Create: `mobile/lib/src/features/home/presentation/widgets/home_grid.dart`
- Modify: `mobile/lib/src/features/home/presentation/widgets/module_card.dart` (dense varyant)
- Modify: `mobile/lib/src/features/home/presentation/role_home_body.dart` (`_grid` → 4 sütun)
- Modify: `mobile/lib/src/features/home/presentation/widgets/yakinda_section.dart` (4 sütun)
- Modify: `mobile/lib/src/features/home/presentation/yonetici_quick_stats.dart` (4 sütun)
- Create: `mobile/test/home_grid_test.dart`
- Modify: `mobile/test/module_card_test.dart` (dense testi ekle)

**Interfaces:**
- Produces: `int homeGridCols(double maxWidth)` — `maxWidth <= 360 ? 2 : 4`. `ModuleCard` yeni parametre `dense: bool = false`. Diğer görevler grid'e dokunmaz.

- [ ] **Step 1: Kırmızı testler yaz**

`mobile/test/home_grid_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/presentation/role_home_body.dart';
import 'package:mobile/src/features/home/presentation/widgets/home_grid.dart';
import 'package:mobile/src/features/home/presentation/widgets/module_card.dart';

Widget _body(double width) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: 800,
            child: RoleHomeBody(
              role: UserRole.resident,
              greetingName: 'Kerem',
              subtitle: 'Site Sakini',
              onOpen: (_) {},
            ),
          ),
        ),
      ),
    );

void main() {
  test('homeGridCols: genis ekranda 4, dar ekranda 2', () {
    expect(homeGridCols(412), 4);
    expect(homeGridCols(360), 2);
    expect(homeGridCols(320), 2);
  });

  testWidgets('412dp genislikte ilk 4 ModuleCard AYNI satirda', (tester) async {
    await tester.pumpWidget(_body(412));
    final cards = find.byType(ModuleCard);
    expect(cards, findsWidgets);
    final dy0 = tester.getTopLeft(cards.at(0)).dy;
    for (var i = 1; i < 4; i++) {
      expect(tester.getTopLeft(cards.at(i)).dy, dy0);
    }
  });

  testWidgets('320dp genislikte 3. kart ALT satira duser (2 sutun)',
      (tester) async {
    await tester.pumpWidget(_body(320));
    final cards = find.byType(ModuleCard);
    final dy0 = tester.getTopLeft(cards.at(0)).dy;
    expect(tester.getTopLeft(cards.at(1)).dy, dy0);
    expect(tester.getTopLeft(cards.at(2)).dy, greaterThan(dy0));
  });
}
```

`module_card_test.dart`'a ekle:

```dart
testWidgets('dense varyant: dar hucrede tasma olmadan cizilir', (tester) async {
  await tester.pumpWidget(_wrap(const SizedBox(
    width: 92, // 4 sutunlu izgaradaki gercek hucre genisligine yakin
    height: 128,
    child: ModuleCard(
        icon: Icons.campaign_outlined, title: 'Duyurular', dense: true),
  )));
  expect(find.text('Duyurular'), findsOneWidget);
  expect(tester.takeException(), isNull); // RenderFlex overflow yok
});
```

- [ ] **Step 2: KIRMIZI gör** — `flutter test test/home_grid_test.dart` FAIL (`home_grid.dart` yok; 412'de 4. kart alt satırda).

- [ ] **Step 3: `home_grid.dart` + dense ModuleCard + ızgara geçişleri**

`widgets/home_grid.dart`:

```dart
/// Ana ekran izgara sutun sayisi — referans 4'lu dizilim; cok dar ekranda
/// (<=360dp) 2'ye duser (kompakt kart bile sigmayacagi icin).
int homeGridCols(double maxWidth) => maxWidth <= 360 ? 2 : 4;

/// Sutuna gore hucre oranı: 4 sutunda kartlar dikey-dikdortgen.
double homeGridAspect(int cols) => cols == 4 ? 0.72 : 1.15;
```

`module_card.dart`: `this.dense = false` parametresi; `dense` iken chip 36×36 / ikon 20, padding 10, başlık `labelMedium` w700, sayaç `labelSmall`:

```dart
final bool dense;
// build icinde:
final double chip = dense ? 36 : 46;
final double iconSize = dense ? 20 : 24;
final EdgeInsets pad = EdgeInsets.all(dense ? 10 : 14);
final TextStyle? titleStyle = (dense
        ? theme.textTheme.labelMedium
        : theme.textTheme.titleSmall)
    ?.copyWith(
        fontWeight: FontWeight.w700,
        color: comingSoon ? theme.disabledColor : null);
```

`role_home_body.dart` `_grid`:

```dart
Widget _grid(List<HomeMenuEntry> entries) {
  return LayoutBuilder(builder: (context, c) {
    final cols = homeGridCols(c.maxWidth);
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: homeGridAspect(cols),
      children: [
        for (final entry in entries)
          Builder(builder: (context) {
            final spec = moduleCardSpec(entry);
            return ModuleCard(
              icon: spec.icon,
              title: spec.title,
              accent: spec.accent,
              counter: counters[entry],
              dense: cols == 4,
              onTap: () => onOpen(entry),
            );
          }),
      ],
    );
  });
}
```

`yakinda_section.dart`: aynı `LayoutBuilder` deseni (`dense: cols == 4`, `comingSoon: true` korunur). `yonetici_quick_stats.dart`: `GridView.count` → `LayoutBuilder` + `crossAxisCount: cols`, `childAspectRatio: cols == 4 ? 0.68 : 1.05` (StatTile FittedBox'lı değer metni dar hücreye sığar; taşarsa oranı 0.62'ye düşür).

- [ ] **Step 4: Tüm suite'i koş** — `flutter test` (özellikle `small_screen_overflow_test`, `role_home_body_test`, `saha_home_screen_test`, `stat_tile_test`) + `flutter analyze`. 4 sütunda RenderFlex overflow çıkarsa `homeGridAspect`/padding'i küçült — test yeşilken bırak.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/src/features/home mobile/test
git commit -m "feat(mobile/home): WP-A — 4'lu kompakt izgara (dense ModuleCard; <=360dp'de 2 sutun)"
```

---

### Task 3: Migration 0005 + models.py mirror

**Files:**
- Create: `contracts/db/migrations/versions/0005_home_gorsel.py`
- Modify: `backend/app/models.py` (Tenant + AppUser alanları; ShiftAssignment + Camera sınıfları)

**Interfaces:**
- Produces: `tenant.konum_ad/konum_lat/konum_lon`, `app_user.avatar_key`, `shift_assignment` ve `camera` tabloları. Task 4-12 bunları kullanır.

- [ ] **Step 1: Migration'ı yaz**

`contracts/db/migrations/versions/0005_home_gorsel.py`:

```python
"""home_gorsel (0005) — ana ekran gorsel zenginlestirme semasi.

* tenant.konum_ad/lat/lon : hava durumu konumu (varsayilan Istanbul).
* app_user.avatar_key     : personel profil fotografi (MinIO anahtari;
                            yalniz personel rolleri yukler — API katmani zorlar).
* shift_assignment        : vardiya <-> personel atamasi (yonetici atar).
* camera                  : site kamera yayin URL'leri (istemci oynatir;
                            backend yayini HIC cekmez — SSRF yuzeyi yok).

URETIM: additive + geriye-uyumlu; 0001-0004 IMMUTABLE.
"""
from alembic import op

revision = "0005_home_gorsel"
down_revision = "0004_platform_support_ticket"
branch_labels = None
depends_on = None

APP_ROLE = "app_rw"


def upgrade() -> None:
    op.execute(
        """
        ALTER TABLE tenant
            ADD COLUMN konum_ad  text NOT NULL DEFAULT 'İstanbul',
            ADD COLUMN konum_lat numeric(9,6) NOT NULL DEFAULT 41.0082,
            ADD COLUMN konum_lon numeric(9,6) NOT NULL DEFAULT 28.9784;
        """
    )
    op.execute("ALTER TABLE app_user ADD COLUMN avatar_key text;")

    op.execute(
        """
        CREATE TABLE shift_assignment (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id  uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            shift_id   uuid NOT NULL,
            user_id    uuid NOT NULL,
            created_at timestamptz NOT NULL DEFAULT now(),
            UNIQUE (tenant_id, shift_id, user_id),
            FOREIGN KEY (shift_id, tenant_id)
                REFERENCES shift (id, tenant_id) ON DELETE CASCADE,
            -- personel siteden cikinca atama otomatik duser
            FOREIGN KEY (user_id, tenant_id)
                REFERENCES app_user (id, tenant_id) ON DELETE CASCADE
        );
        """
    )
    op.execute(
        """
        CREATE TABLE camera (
            id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            tenant_id  uuid NOT NULL REFERENCES tenant (id) ON DELETE CASCADE,
            ad         text NOT NULL,
            stream_url text NOT NULL,
            created_at timestamptz NOT NULL DEFAULT now(),
            updated_at timestamptz NOT NULL DEFAULT now(),
            UNIQUE (tenant_id, ad)
        );
        """
    )
    for table in ("shift_assignment", "camera"):
        op.execute(f"ALTER TABLE {table} ENABLE ROW LEVEL SECURITY;")
        op.execute(f"ALTER TABLE {table} FORCE ROW LEVEL SECURITY;")
        op.execute(
            f"""
            CREATE POLICY {table}_isolation ON {table}
                USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid)
                WITH CHECK (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
            """
        )
    # Atama declarative-replace: SELECT+INSERT+DELETE yeter (UPDATE yok).
    op.execute(f"GRANT SELECT, INSERT, DELETE ON shift_assignment TO {APP_ROLE};")
    op.execute(f"GRANT SELECT, INSERT, UPDATE, DELETE ON camera TO {APP_ROLE};")


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS camera;")
    op.execute("DROP TABLE IF EXISTS shift_assignment;")
    op.execute("ALTER TABLE app_user DROP COLUMN IF EXISTS avatar_key;")
    op.execute(
        "ALTER TABLE tenant DROP COLUMN IF EXISTS konum_ad, "
        "DROP COLUMN IF EXISTS konum_lat, DROP COLUMN IF EXISTS konum_lon;"
    )
```

- [ ] **Step 2: models.py mirror'ını güncelle**

`Tenant`'a (dis_hizmet_notu'nun altına):

```python
    # Hava durumu konumu (0005) — baslikta gorunen ad + Open-Meteo koordinati.
    konum_ad: Mapped[str] = mapped_column(
        Text, nullable=False, server_default=text("'İstanbul'")
    )
    konum_lat = mapped_column(
        Numeric(9, 6), nullable=False, server_default=text("41.0082")
    )
    konum_lon = mapped_column(
        Numeric(9, 6), nullable=False, server_default=text("28.9784")
    )
```

`AppUser`'a (`is_active` altına):

```python
    # Personel profil fotografi (0005) — MinIO obje anahtari; yalniz personel
    # rolleri yazar (PATCH /me/avatar), resident'a 403.
    avatar_key: Mapped[str | None] = mapped_column(Text, nullable=True)
```

Yeni sınıflar (Shift'in altına):

```python
class ShiftAssignment(Base):
    """Vardiya personel atamasi (0005) — yonetici atar; kartta avatar."""

    __tablename__ = "shift_assignment"
    __table_args__ = (
        UniqueConstraint(
            "tenant_id", "shift_id", "user_id", name="uq_shift_assignment"
        ),
        ForeignKeyConstraint(
            ["shift_id", "tenant_id"],
            ["shift.id", "shift.tenant_id"],
            ondelete="CASCADE",
            name="fk_shift_assignment_shift",
        ),
        ForeignKeyConstraint(
            ["user_id", "tenant_id"],
            ["app_user.id", "app_user.tenant_id"],
            ondelete="CASCADE",
            name="fk_shift_assignment_user",
        ),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    shift_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    created_at = _created_at()


class Camera(Base):
    """Site kamera yayini (0005) — ad + istemcinin oynattigi URL (MVP)."""

    __tablename__ = "camera"
    __table_args__ = (
        UniqueConstraint("tenant_id", "ad", name="uq_camera_tenant_ad"),
    )

    id: Mapped[uuid.UUID] = _pk()
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tenant.id", ondelete="CASCADE"), nullable=False
    )
    ad: Mapped[str] = mapped_column(Text, nullable=False)
    stream_url: Mapped[str] = mapped_column(Text, nullable=False)
    created_at = _created_at()
    updated_at = _created_at()
```

- [ ] **Step 3: Migration'ı uygula ve doğrula**

```bash
cd infra && docker compose down -v && docker compose up -d --build
docker compose build seed && docker compose run --rm seed
docker compose exec -T db psql -U tesis_owner -d tesis -c "\d shift_assignment" -c "\d camera" -c "SELECT konum_ad FROM tenant LIMIT 1" -c "SELECT column_name FROM information_schema.columns WHERE table_name='app_user' AND column_name='avatar_key'"
```

Expected: iki tablo tanımı + `konum_ad` değeri + `avatar_key` satırı. (psql kullanıcı adı `.env`'den farklıysa `infra/.env`'deki owner kullanıcıyla değiştir.)

- [ ] **Step 4: Mevcut backend suite'inin bozulmadığını hızlı kontrol et**

```bash
docker compose exec -T api sh -c "pytest -q tests/test_rls_isolation.py tests/test_tenant_ad.py 2>&1 | tail -3"
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add contracts/db/migrations/versions/0005_home_gorsel.py backend/app/models.py
git commit -m "feat(db): 0005 home_gorsel — tenant konum, app_user.avatar_key, shift_assignment, camera (RLS)"
```

---

### Task 4: WP-C backend — tenant konum ayarları

**Files:**
- Modify: `backend/app/schemas.py` (TenantSettings, TenantSettingsUpdate)
- Modify: `backend/app/routers/tenant.py` (`_to_settings`, `_YONETICI_YAZABILIR`)
- Create: `backend/tests/test_weather.py` (konum testleri; Task 5 hava testleri de buraya)
- Modify: `contracts/auth.md` (§4 tenant satırı: yönetici artık konum da yazar)

**Interfaces:**
- Produces: `GET/PATCH /tenant/settings` alanları `konum_ad: str`, `konum_lat: float`, `konum_lon: float`. Task 5 `/weather` tenant satırından okur; Task 6 `konum_ad`'ı başlıkta gösterir.

- [ ] **Step 1: Kırmızı test yaz** — `backend/tests/test_weather.py`:

```python
"""Hava durumu — tenant konum ayarlari + GET /weather (0005 / WP-C)."""
from __future__ import annotations


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_settings_konum_alanlari_doner_ve_yonetici_gunceller(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.get("/tenant/settings", headers=yonetici)
    assert r.status_code == 200
    body = r.json()
    assert body["konum_ad"] == "İstanbul"
    assert abs(body["konum_lat"] - 41.0082) < 1e-4

    r = client.patch(
        "/tenant/settings", headers=yonetici,
        json={"konum_ad": "Ankara", "konum_lat": 39.9334, "konum_lon": 32.8597},
    )
    assert r.status_code == 200, r.text
    assert r.json()["konum_ad"] == "Ankara"


def test_konum_sinir_disi_422(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.patch("/tenant/settings", headers=admin, json={"konum_lat": 91.0})
    assert r.status_code == 422
```

- [ ] **Step 2: KIRMIZI gör**

```bash
cd infra && docker compose build api && docker compose up -d api
docker compose exec -T api sh -c "pytest -q tests/test_weather.py 2>&1 | tail -5"
```

Expected: FAIL — yanıtta `konum_ad` anahtarı yok (KeyError).

- [ ] **Step 3: Şema + router**

`schemas.py` `TenantSettings`'e:

```python
    # Hava durumu konumu (0005) — baslik + /weather sorgusu.
    konum_ad: str = "İstanbul"
    konum_lat: float = 41.0082
    konum_lon: float = 28.9784
```

`TenantSettingsUpdate`'e:

```python
    konum_ad: str | None = Field(None, min_length=1)
    konum_lat: float | None = Field(None, ge=-90, le=90)
    konum_lon: float | None = Field(None, ge=-180, le=180)
```

`tenant.py`: `_YONETICI_YAZABILIR = {"ad", "konum_ad", "konum_lat", "konum_lon"}` (yorumu güncelle: yönetici tesis adı + hava konumu). `_to_settings`'e:

```python
        konum_ad=t.konum_ad,
        konum_lat=float(t.konum_lat),
        konum_lon=float(t.konum_lon),
```

`contracts/auth.md` §4'te PATCH /tenant/settings satırına yönetici alan listesi notunu güncelle.

- [ ] **Step 4: Yeşil gör** — build api + `pytest -q tests/test_weather.py tests/test_tenant_ad.py` PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/schemas.py backend/app/routers/tenant.py backend/tests/test_weather.py contracts/auth.md
git commit -m "feat(tenant): konum_ad/lat/lon ayarlari — yonetici hava konumunu yonetir (WP-C)"
```

---

### Task 5: WP-C backend — GET /weather (Open-Meteo proxy + cache)

**Files:**
- Modify: `backend/app/config.py` (weather ayarları)
- Create: `backend/app/weather.py` (saf kod-eşleme + cache)
- Create: `backend/app/routers/weather.py`
- Modify: `backend/app/main.py` (router kaydı), `backend/app/schemas.py` (WeatherOut)
- Modify: `backend/tests/test_weather.py` (hava testleri ekle)
- Modify: `contracts/auth.md` (§4 yeni uç: GET /weather tüm roller)

**Interfaces:**
- Produces: `GET /weather` → `{"sicaklik_c": float, "durum": str, "konum_ad": str}`; `durum ∈ {acik, parcali, kapali, sis, yagmur, kar, firtina}`. `app.weather.kod_durum(code: int) -> str` saf fonksiyon. Task 6 mobil bunu tüketir.

- [ ] **Step 1: Kırmızı testleri ekle** — `test_weather.py`'ye:

```python
DURUMLAR = {"acik", "parcali", "kapali", "sis", "yagmur", "kar", "firtina"}


def test_kod_durum_eslemesi():
    from app.weather import kod_durum

    assert kod_durum(0) == "acik"
    assert kod_durum(2) == "parcali"
    assert kod_durum(3) == "kapali"
    assert kod_durum(45) == "sis"
    assert kod_durum(61) == "yagmur"
    assert kod_durum(80) == "yagmur"
    assert kod_durum(71) == "kar"
    assert kod_durum(95) == "firtina"
    assert kod_durum(9999) == "kapali"  # bilinmeyen kod guvenli varsayilan


def test_weather_tum_roller_okur_anonim_401(client, world):
    # Dis servis (Open-Meteo) testte erisilemeyebilir: 200 (veri) da 503
    # (weather_unavailable) da SOZLESMEYE uygundur; 403 ASLA.
    for who in ("admin_a", "yonetici_a", "guard_a", "gorevli_a", "resident_a"):
        h = _headers(client, world["slug_a"], world[who])
        r = client.get("/weather", headers=h)
        assert r.status_code in (200, 503), f"{who}: {r.status_code} {r.text}"
        if r.status_code == 200:
            body = r.json()
            assert set(body) >= {"sicaklik_c", "durum", "konum_ad"}
            assert body["durum"] in DURUMLAR
    assert client.get("/weather").status_code == 401
```

- [ ] **Step 2: KIRMIZI gör** — build api + koş; `test_kod_durum_eslemesi` ImportError, `/weather` 404.

- [ ] **Step 3: Uygula**

`config.py` (fcm bloğunun altına):

```python
    # Hava durumu proxy'si (WP-C) — anahtarsiz Open-Meteo; testte/ozel kurulumda
    # baska taban URL verilebilir.
    weather_base_url: str = "https://api.open-meteo.com"
    weather_cache_ttl: int = 1800  # saniye — tenant basina >=30dk'da 1 dis istek
```

`backend/app/weather.py`:

```python
"""Hava durumu yardimcilari (WP-C) — WMO weather_code -> basit durum + cache.

Cache surec-ici sozluk: {(lat, lon): (payload, monotonic_ts)}. TTL icinde
istemciler dis servise HIC cikmaz; dis servis dusukse SURESI GECMIS veri
donmeye devam eder (bayat-veri toleransi) — hic veri yoksa 503.
"""
from __future__ import annotations

import time as _time

# (payload, ts) — payload: {"sicaklik_c": float, "durum": str}
_CACHE: dict[tuple[float, float], tuple[dict, float]] = {}


def kod_durum(code: int) -> str:
    """WMO weather_code -> TR durum anahtari. Bilinmeyen kod 'kapali'
    (yanlis 'acik' gostermekten guvenli)."""
    if code == 0:
        return "acik"
    if code in (1, 2):
        return "parcali"
    if code in (45, 48):
        return "sis"
    if 51 <= code <= 67 or 80 <= code <= 82:
        return "yagmur"
    if 71 <= code <= 77 or code in (85, 86):
        return "kar"
    if 95 <= code <= 99:
        return "firtina"
    return "kapali"


def cache_get(lat: float, lon: float, ttl: int) -> dict | None:
    """TTL icindeyse payload; degilse None (bayat girdi SILINMEZ — 503
    yerine bayat veri donebilmek icin cache_get_stale kullanilir)."""
    hit = _CACHE.get((lat, lon))
    if hit and _time.monotonic() - hit[1] < ttl:
        return hit[0]
    return None


def cache_get_stale(lat: float, lon: float) -> dict | None:
    hit = _CACHE.get((lat, lon))
    return hit[0] if hit else None


def cache_put(lat: float, lon: float, payload: dict) -> None:
    _CACHE[(lat, lon)] = (payload, _time.monotonic())
```

`routers/weather.py`:

```python
"""GET /weather — tenant konumu icin Open-Meteo proxy'si (WP-C).

RBAC: TUM kimlikli roller (ana ekran basligi). Dis istek YALNIZ cache
kacirilinca atilir (30dk TTL); kisa timeout (3sn) — baslik ana ekrani
bekletmez. Dis servis dusukse bayat cache donulur; hic veri yoksa 503.
"""
from __future__ import annotations

import httpx
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import settings
from ..deps import get_tenant_db, require_role
from ..errors import APIError
from ..models import AppUser, Tenant
from ..schemas import WeatherOut
from ..weather import cache_get, cache_get_stale, cache_put, kod_durum

router = APIRouter(prefix="/weather", tags=["weather"])

_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi", "resident")


@router.get("", response_model=WeatherOut)
async def get_weather(
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> WeatherOut:
    t = (await db.execute(select(Tenant))).scalar_one_or_none()
    if t is None:
        raise APIError(404, "not_found", "Tenant bulunamadi.")
    lat, lon = float(t.konum_lat), float(t.konum_lon)

    payload = cache_get(lat, lon, settings.weather_cache_ttl)
    if payload is None:
        try:
            async with httpx.AsyncClient(timeout=3.0) as http:
                r = await http.get(
                    f"{settings.weather_base_url}/v1/forecast",
                    params={
                        "latitude": lat,
                        "longitude": lon,
                        "current": "temperature_2m,weather_code",
                    },
                )
                r.raise_for_status()
                cur = r.json()["current"]
                payload = {
                    "sicaklik_c": float(cur["temperature_2m"]),
                    "durum": kod_durum(int(cur["weather_code"])),
                }
                cache_put(lat, lon, payload)
        except Exception:
            payload = cache_get_stale(lat, lon)  # bayat-veri toleransi
    if payload is None:
        raise APIError(503, "weather_unavailable", "Hava durumu su an alinamiyor.")
    return WeatherOut(**payload, konum_ad=t.konum_ad)
```

`schemas.py`:

```python
# -------------------------------- weather ---------------------------------- #
class WeatherOut(BaseModel):
    sicaklik_c: float
    durum: str  # acik|parcali|kapali|sis|yagmur|kar|firtina
    konum_ad: str
```

`main.py`: `from .routers import weather as weather_router` (mevcut import bloğu deseniyle) + `app.include_router(weather_router.router)`. `contracts/auth.md` §4'e GET /weather satırı (tüm roller).

- [ ] **Step 4: Yeşil gör** — build api + `pytest -q tests/test_weather.py` PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app backend/tests/test_weather.py contracts/auth.md
git commit -m "feat(weather): GET /weather — Open-Meteo proxy, 30dk cache, bayat-veri toleransi (WP-C)"
```

---

### Task 6: WP-C mobil — başlıkta hava durumu

**Files:**
- Create: `mobile/lib/src/features/weather/domain/weather_models.dart`
- Create: `mobile/lib/src/features/weather/data/weather_api.dart`
- Modify: `mobile/lib/src/features/home/presentation/widgets/home_header.dart` (HomeWeather'a ikon)
- Modify: 4 rol ekranı — `resident_home_screen.dart`, `yonetici_home_screen.dart`, `saha_home_screen.dart`, `admin_home_screen.dart` (weather bağla)
- Create: `mobile/test/weather_models_test.dart`
- Modify: mevcut rol ekranı testleri (weatherProvider override)

**Interfaces:**
- Consumes: `GET /weather` (Task 5).
- Produces: `Weather {sicaklikC: double, durum: String, konumAd: String}`; `weatherProvider: FutureProvider.autoDispose<Weather>`; `IconData weatherIcon(String durum)`; `HomeWeather` yeni alan `icon: IconData` (varsayılan `Icons.wb_sunny_outlined`).

- [ ] **Step 1: Kırmızı test** — `mobile/test/weather_models_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/weather/domain/weather_models.dart';

void main() {
  test('fromJson savunmaci parse + tempLabel yuvarlama', () {
    final w = Weather.fromJson(
        {'sicaklik_c': 23.6, 'durum': 'acik', 'konum_ad': 'İstanbul'});
    expect(w.sicaklikC, 23.6);
    expect(w.tempLabel, '24°C');
    expect(w.konumAd, 'İstanbul');
  });

  test('bozuk govde varsayilanlara duser (cokme yok)', () {
    final w = Weather.fromJson(const {});
    expect(w.tempLabel, '0°C');
    expect(w.durum, 'kapali');
  });

  test('weatherIcon eslemesi', () {
    expect(weatherIcon('acik'), Icons.wb_sunny_outlined);
    expect(weatherIcon('yagmur'), Icons.umbrella_outlined);
    expect(weatherIcon('kar'), Icons.ac_unit);
    expect(weatherIcon('firtina'), Icons.thunderstorm_outlined);
    expect(weatherIcon('bilinmeyen'), Icons.cloud_outlined);
  });
}
```

- [ ] **Step 2: KIRMIZI gör** — `flutter test test/weather_models_test.dart` FAIL (dosya yok).

- [ ] **Step 3: Uygula**

`weather_models.dart`:

```dart
import 'package:flutter/material.dart';

/// GET /weather yaniti (WP-C). Savunmaci parse: alan yoksa guvenli varsayilan.
class Weather {
  const Weather({
    required this.sicaklikC,
    required this.durum,
    required this.konumAd,
  });

  final double sicaklikC;
  final String durum; // acik|parcali|kapali|sis|yagmur|kar|firtina
  final String konumAd;

  String get tempLabel => '${sicaklikC.round()}°C';

  factory Weather.fromJson(Map<String, dynamic> json) => Weather(
        sicaklikC: (json['sicaklik_c'] as num?)?.toDouble() ?? 0,
        durum: json['durum'] as String? ?? 'kapali',
        konumAd: json['konum_ad'] as String? ?? '',
      );
}

/// Durum anahtari -> baslik ikonu; bilinmeyen anahtar bulut.
IconData weatherIcon(String durum) => switch (durum) {
      'acik' => Icons.wb_sunny_outlined,
      'parcali' => Icons.wb_cloudy_outlined,
      'sis' => Icons.foggy,
      'yagmur' => Icons.umbrella_outlined,
      'kar' => Icons.ac_unit,
      'firtina' => Icons.thunderstorm_outlined,
      _ => Icons.cloud_outlined,
    };
```

`weather_api.dart` (shifts_api deseni):

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../domain/weather_models.dart';

class WeatherApi {
  WeatherApi(this._dio);
  final Dio _dio;

  Future<Weather> fetch() async {
    final res = await _dio.get<Map<String, dynamic>>('/weather');
    return Weather.fromJson(res.data ?? const {});
  }
}

final weatherApiProvider = Provider<WeatherApi>((ref) {
  return WeatherApi(ref.watch(dioProvider));
});

/// Ana ekran basligi hava blogu — hata/yuklemede blok sessizce gizlenir.
final weatherProvider = FutureProvider.autoDispose<Weather>((ref) {
  return ref.watch(weatherApiProvider).fetch();
});
```

`home_header.dart`: `HomeWeather`'a `this.icon = Icons.wb_sunny_outlined` alanı; `_WeatherBlock` sabit `Icons.wb_sunny_outlined` yerine `weather.icon` (renk: amber yalnız güneşte, diğerlerinde `theme.hintColor` — `color: weather.icon == Icons.wb_sunny_outlined ? Colors.amber : theme.hintColor`).

4 rol ekranında `RoleHomeBody(weather: ...)` bağla (hepsi aynı desen):

```dart
final hava = ref.watch(weatherProvider).maybeWhen(
      data: (w) => HomeWeather(
        tempLabel: w.tempLabel,
        city: w.konumAd,
        icon: weatherIcon(w.durum),
      ),
      orElse: () => null, // yukleme/hata: blok gizli
    );
// ...
RoleHomeBody(..., weather: hava, ...)
```

Mevcut rol ekranı testlerinde `ProviderScope(overrides: [...])` listesine ekle:

```dart
weatherProvider.overrideWith(
    (ref) async => const Weather(sicaklikC: 24, durum: 'acik', konumAd: 'İstanbul')),
```

- [ ] **Step 4: Tüm suite** — `flutter test && flutter analyze` yeşil (rol ekranı testleri dahil).

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/src/features/weather mobile/lib/src/features/home mobile/test
git commit -m "feat(mobile/home): baslikta hava durumu — /weather provider + durum ikonu (WP-C)"
```

---

### Task 7: WP-D backend — profil fotoğrafı

**Files:**
- Modify: `backend/app/audit.py` (Action.AVATAR_UPDATE)
- Modify: `backend/app/schemas.py` (UserOut.avatar_url, AvatarUpdate; YoneticiKart.avatar_url)
- Modify: `backend/app/routers/me.py` (GET /me avatar_url + PATCH /me/avatar)
- Modify: `backend/app/routers/yonetici_iletisim.py` (kartta avatar_url)
- Create: `backend/tests/test_avatar.py`
- Modify: `contracts/auth.md` (§4: PATCH /me/avatar personel rolleri)

**Interfaces:**
- Consumes: `app_user.avatar_key` (Task 3), `storage.presign_get/delete_objects`, `/uploads/presign`.
- Produces: `GET /me` → `avatar_url: str | None`; `PATCH /me/avatar {"avatar_key": str | null}` → UserOut; yönetici iletişim kartında `avatar_url`. Task 8-10 tüketir.

- [ ] **Step 1: Kırmızı test** — `backend/tests/test_avatar.py`:

```python
"""Profil fotografi (WP-D) — PATCH /me/avatar RBAC + tenant-onek + temizlik."""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _upload_foto(client, headers) -> str:
    """presign -> MinIO'ya PUT -> foto_key (announcement testleriyle ayni akis)."""
    import httpx

    r = client.post(
        "/uploads/presign", headers=headers,
        json={"content_type": "image/jpeg", "dosya_adi": "avatar.jpg"},
    )
    assert r.status_code == 200, r.text
    t = r.json()
    put = httpx.put(
        t["upload_url"], content=b"fake-jpeg-bytes",
        headers={"Content-Type": "image/jpeg"}, timeout=10,
    )
    assert put.status_code in (200, 204), put.text
    return t["foto_key"]


def test_yonetici_avatar_yukler_me_gorur_null_kaldirir(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    key = _upload_foto(client, yonetici)

    r = client.patch("/me/avatar", headers=yonetici, json={"avatar_key": key})
    assert r.status_code == 200, r.text
    assert r.json()["avatar_url"]  # presigned GET URL

    assert client.get("/me", headers=yonetici).json()["avatar_url"]

    r = client.patch("/me/avatar", headers=yonetici, json={"avatar_key": None})
    assert r.status_code == 200
    assert r.json()["avatar_url"] is None


def test_resident_403_yabanci_onek_422(client, world):
    resident = _headers(client, world["slug_a"], world["resident_a"])
    r = client.patch("/me/avatar", headers=resident, json={"avatar_key": "x/y.jpg"})
    assert r.status_code == 403

    guard = _headers(client, world["slug_a"], world["guard_a"])
    yabanci = f"{uuid.uuid4()}/avatars/kacak.jpg"  # baska tenant onegi -> IDOR engeli
    r = client.patch("/me/avatar", headers=guard, json={"avatar_key": yabanci})
    assert r.status_code == 422


def test_iletisim_kartinda_yonetici_avatari(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    key = _upload_foto(client, yonetici)
    client.patch("/me/avatar", headers=yonetici, json={"avatar_key": key})

    resident = _headers(client, world["slug_a"], world["resident_a"])
    r = client.get("/yonetici-iletisim", headers=resident)
    assert r.status_code == 200, r.text
    # Yanit sekli: {"yoneticiler": [YoneticiKart...], "yonetim_email": ...}
    assert any(k.get("avatar_url") for k in r.json()["yoneticiler"])
```

- [ ] **Step 2: KIRMIZI gör** — build api + `pytest -q tests/test_avatar.py`: 404 `/me/avatar`.

- [ ] **Step 3: Uygula**

`audit.py` Action'a: `AVATAR_UPDATE = "avatar_update"  # profil fotografi (yukle/kaldir)`.

`schemas.py`: `UserOut`'a `avatar_url: str | None = None`; yeni:

```python
class AvatarUpdate(BaseModel):
    """PATCH /me/avatar — null gonderimi fotografi KALDIRIR (alan zorunlu)."""

    avatar_key: str | None
```

`YoneticiKart`'a `avatar_url: str | None = None`.

`me.py`: yardımcı + uçlar:

```python
from ..storage import delete_objects, presign_get

_AVATAR_ROLLER = require_role("admin", "yonetici", "security", "tesis_gorevlisi")


def _user_out(user: AppUser) -> UserOut:
    return UserOut(
        id=user.id, tenant_id=user.tenant_id, ad=user.ad, email=user.email,
        role=user.role, is_active=user.is_active,
        avatar_url=presign_get(user.avatar_key) if user.avatar_key else None,
    )


@router.get("/me", response_model=UserOut)
async def me(user: AppUser = Depends(get_current_user)) -> UserOut:
    """Access token'daki kullaniciyi doner (tenant context token'dan)."""
    return _user_out(user)


@router.patch("/me/avatar", response_model=UserOut)
async def update_my_avatar(
    body: AvatarUpdate,
    user: AppUser = Depends(_AVATAR_ROLLER),
    db: AsyncSession = Depends(get_tenant_db),
) -> UserOut:
    """Self-servis profil fotografi — YALNIZ personel rolleri (resident 403;
    sakinler personeli tanisin amaci tek yonlu). Anahtar kendi tenant
    namespace'inde olmali (announcement _validate_foto_key deseni — IDOR).
    Degisen/kaldirilan eski obje MinIO'dan silinir (artik erisilemez cop)."""
    if body.avatar_key is not None and not body.avatar_key.startswith(
        f"{user.tenant_id}/"
    ):
        raise APIError(422, "invalid_foto_key", "avatar_key tenant alani disinda")
    eski = user.avatar_key
    user.avatar_key = body.avatar_key
    user.updated_at = func.now()
    if eski and eski != body.avatar_key:
        delete_objects([eski])
    await audit_user(
        db, user, Action.AVATAR_UPDATE, resource_type="app_user",
        resource_id=user.id, meta={"kaldirildi": body.avatar_key is None},
    )
    return _user_out(user)
```

(`me.py` importlarına `Action, audit_user` zaten var; `APIError`, `func` mevcut; `UserOut` zaten import'lu.)

`yonetici_iletisim.py`: `YoneticiKart` üretiminde `avatar_url=presign_get(u.avatar_key) if u.avatar_key else None` (kart ORM'den `model_validate` ile kuruluyorsa açık kurucuya çevir; `from ..storage import presign_get`).

KVKK temizlik notu: `/users` altında personel SİLME ucu YOK (yalnız create/update/reset; sakin çıkarma residents.py'de ve sakinler avatar yükleyemez). Değiştirme/kaldırma anındaki obje silmesi PATCH /me/avatar içinde yapılır (yukarıda `delete_objects`); ayrı bir silme-ucu entegrasyonu gerekmez. İleride personel silme ucu eklenirse avatar objesi de silinmelidir — bu not `me.py` docstring'ine değil, `contracts/auth.md` §4 PATCH /me/avatar satırının yanına yazılır.

- [ ] **Step 4: Yeşil gör** — build api + `pytest -q tests/test_avatar.py tests/test_profile.py tests/test_yonetici_iletisim.py` PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app backend/tests/test_avatar.py contracts/auth.md
git commit -m "feat(avatar): PATCH /me/avatar — personel profil fotografi + iletisim kartinda gorunur (WP-D)"
```

---

### Task 8: WP-D mobil — avatar yükleme + görüntüleme

**Files:**
- Create: `mobile/lib/src/features/profile/data/avatar_api.dart`
- Modify: `mobile/lib/src/features/profile/presentation/profile_screen.dart` (personel rollerine foto bölümü)
- Modify: HomeShell app-bar avatar widget'ı (`mobile/lib/src/features/home/presentation/widgets/home_shell.dart`) — avatar_url varsa `NetworkImage`
- Create: `mobile/test/avatar_api_test.dart`

**Interfaces:**
- Consumes: `/uploads/presign` + presigned PUT (AnnouncementApi deseni), `PATCH /me/avatar`, `GET /me → avatar_url` (Task 7).
- Produces: `myAvatarUrlProvider: FutureProvider.autoDispose<String?>` (GET /me → avatar_url); `AvatarApi.setAvatar(String? key)`; `AvatarApi.presignUpload/uploadPhoto` (PresignTicket yeniden kullanılır).

- [ ] **Step 1: Kırmızı test** — `mobile/test/avatar_api_test.dart` (dio mock'suz, model/parse odaklı; ağ testleri backend'de):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/profile/data/avatar_api.dart';

void main() {
  test('avatarUrlFromMe savunmaci parse', () {
    expect(avatarUrlFromMe({'avatar_url': 'https://x/y.jpg'}), 'https://x/y.jpg');
    expect(avatarUrlFromMe(const {}), isNull);
    expect(avatarUrlFromMe({'avatar_url': null}), isNull);
  });
}
```

- [ ] **Step 2: KIRMIZI gör** — `flutter test test/avatar_api_test.dart` FAIL.

- [ ] **Step 3: Uygula**

`avatar_api.dart`:

```dart
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../tasks/domain/task_models.dart' show PresignTicket;

/// GET /me yanitindan avatar_url (SAF — test edilebilir).
String? avatarUrlFromMe(Map<String, dynamic> json) =>
    json['avatar_url'] as String?;

/// Profil fotografi istemcisi (WP-D) — presign PUT + PATCH /me/avatar.
/// Yalniz personel rollerinde cagrilir (resident'a sunucu 403 doner).
class AvatarApi {
  AvatarApi(this._dio, {Dio? uploadDio}) : _uploadDio = uploadDio ?? Dio();

  final Dio _dio;
  final Dio _uploadDio; // presigned PUT: auth header'siz temiz istemci

  Future<PresignTicket> presignUpload({required String contentType}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/uploads/presign',
        data: {'content_type': contentType, 'dosya_adi': 'avatar.jpg'},
      );
      return PresignTicket.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> uploadPhoto({
    required PresignTicket ticket,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _uploadDio.put<void>(
      ticket.uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(headers: {
        Headers.contentTypeHeader: contentType,
        Headers.contentLengthHeader: bytes.length,
      }),
    );
  }

  /// null -> fotografi kaldir. Basarida yeni avatar_url doner.
  Future<String?> setAvatar(String? fotoKey) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/me/avatar',
        data: {'avatar_key': fotoKey},
      );
      return avatarUrlFromMe(res.data ?? const {});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<String?> fetchMyAvatarUrl() async {
    final res = await _dio.get<Map<String, dynamic>>('/me');
    return avatarUrlFromMe(res.data ?? const {});
  }
}

final avatarApiProvider = Provider<AvatarApi>((ref) {
  return AvatarApi(ref.watch(dioProvider));
});

/// App-bar avatari + profil ekrani onizlemesi. Hata -> null (bas harf/ikon
/// fallback'i cizilir; ekran dusmez).
final myAvatarUrlProvider = FutureProvider.autoDispose<String?>((ref) async {
  try {
    return await ref.watch(avatarApiProvider).fetchMyAvatarUrl();
  } catch (_) {
    return null;
  }
});
```

`profile_screen.dart`: personel rollerinde (role != resident) üste "Profil Fotoğrafı" bölümü — `CircleAvatar(radius: 36, backgroundImage: url != null ? NetworkImage(url) : null, child: url == null ? Icon(Icons.person) : null)` + `TextButton.icon` "Fotoğraf Seç" (announcements'daki `imagePickerProvider` galeri/kamera sheet deseni → presign → PUT → `setAvatar(key)` → `ref.invalidate(myAvatarUrlProvider)`) + foto varken "Kaldır" (`setAvatar(null)`). Yüklemede `SnackBar` hata mesajı (`ApiException.message`).

HomeShell app-bar avatarı: mevcut avatar/`CircleAvatar` widget'ında `ref.watch(myAvatarUrlProvider).valueOrNull` dolu ise `backgroundImage: NetworkImage(url)`, değilse mevcut fallback aynen.

- [ ] **Step 4: Suite + analyze yeşil** — `flutter test && flutter analyze`. HomeShell testleri ağa çıkmasın diye gerekiyorsa `myAvatarUrlProvider.overrideWith((ref) async => null)` ekle.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/src/features/profile mobile/lib/src/features/home mobile/test
git commit -m "feat(mobile/profile): personel profil fotografi — yukle/kaldir + app-bar avatari (WP-D)"
```

---

### Task 9: WP-E backend — vardiya personel ataması

**Files:**
- Modify: `backend/app/audit.py` (Action.SHIFT_ASSIGN)
- Modify: `backend/app/schemas.py` (ShiftPersonelOut, ShiftOut.personel, ShiftAssignmentsUpdate)
- Modify: `backend/app/routers/shifts.py` (PUT assignments + listede personel)
- Create: `backend/tests/test_shift_assignments.py`
- Modify: `contracts/auth.md` (§4: PUT /shifts/{id}/assignments admin+yonetici)

**Interfaces:**
- Consumes: `shift_assignment` tablosu (Task 3), `presign_get` (Task 7 ile aynı yardımcı).
- Produces: `PUT /shifts/{shift_id}/assignments {"user_ids": [uuid]}` → ShiftOut; `GET /shifts` iteminde `personel: [{"user_id","ad","avatar_url"}]`. Task 10 tüketir.

- [ ] **Step 1: Kırmızı test** — `backend/tests/test_shift_assignments.py`:

```python
"""Vardiya atamasi (WP-E) — PUT /shifts/{id}/assignments RBAC + rol kisiti."""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _me_id(client, headers):
    return client.get("/me", headers=headers).json()["id"]


def _vardiya_ac(client, admin_headers) -> str:
    r = client.post(
        "/shifts", headers=admin_headers,
        json={"ad": f"Test-{uuid.uuid4().hex[:6]}", "baslangic_saat": "06:00",
              "bitis_saat": "14:00"},
    )
    assert r.status_code == 201, r.text
    return r.json()["id"]


def test_yonetici_atar_listede_personel_gorunur(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])
    sid = _vardiya_ac(client, admin)

    r = client.put(
        f"/shifts/{sid}/assignments", headers=yonetici,
        json={"user_ids": [_me_id(client, guard), _me_id(client, gorevli)]},
    )
    assert r.status_code == 200, r.text
    assert len(r.json()["personel"]) == 2
    assert {p["ad"] for p in r.json()["personel"]} == {"Guard A", "Gorevli A"}

    # GET listesi de personeli tasir (security okuyabilir)
    r = client.get("/shifts", headers=guard)
    item = next(i for i in r.json()["items"] if i["id"] == sid)
    assert len(item["personel"]) == 2

    # declarative replace: bos liste atamayi temizler
    r = client.put(f"/shifts/{sid}/assignments", headers=yonetici,
                   json={"user_ids": []})
    assert r.status_code == 200 and r.json()["personel"] == []


def test_rbac_ve_rol_kisiti(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    sid = _vardiya_ac(client, admin)

    # security/resident atama YAPAMAZ
    for h in (guard, resident):
        r = client.put(f"/shifts/{sid}/assignments", headers=h,
                       json={"user_ids": []})
        assert r.status_code == 403

    # resident ATANAMAZ (yalniz security|tesis_gorevlisi)
    r = client.put(
        f"/shifts/{sid}/assignments", headers=admin,
        json={"user_ids": [_me_id(client, resident)]},
    )
    assert r.status_code == 422


def test_tenant_izolasyonu(client, world):
    admin_a = _headers(client, world["slug_a"], world["admin_a"])
    yonetici_b = _headers(client, world["slug_b"], world["yonetici_b"])
    sid = _vardiya_ac(client, admin_a)
    r = client.put(f"/shifts/{sid}/assignments", headers=yonetici_b,
                   json={"user_ids": []})
    assert r.status_code == 404  # RLS: B, A'nin vardiyasini goremez
```

- [ ] **Step 2: KIRMIZI gör** — build api + `pytest -q tests/test_shift_assignments.py`: 404/405.

- [ ] **Step 3: Uygula**

`audit.py`: `SHIFT_ASSIGN = "shift_assign"  # vardiya personel atamasi (tam-liste)`.

`schemas.py` (shift bloğuna):

```python
class ShiftPersonelOut(BaseModel):
    user_id: uuid.UUID
    ad: str
    avatar_url: str | None = None


class ShiftAssignmentsUpdate(BaseModel):
    """Tam-liste degistirme (declarative replace) — tekil ekle/cikar ucu YOK."""

    user_ids: list[uuid.UUID]
```

`ShiftOut`'a: `personel: list[ShiftPersonelOut] = []`.

`shifts.py`: importlara `ShiftAssignment`, `ShiftAssignmentsUpdate`, `ShiftPersonelOut`, `delete`, `Action/audit_user`, `presign_get`, `APIError` ekle; yardımcı + uç:

```python
_ASSIGNER = require_role("admin", "yonetici")
_ATANABILIR = {"security", "tesis_gorevlisi"}


async def _personel_map(
    db: AsyncSession, shift_ids: list[uuid.UUID]
) -> dict[uuid.UUID, list[ShiftPersonelOut]]:
    """shift_id -> atanan personel listesi (ad + presigned avatar)."""
    if not shift_ids:
        return {}
    rows = (
        await db.execute(
            select(ShiftAssignment.shift_id, AppUser)
            .join(AppUser, AppUser.id == ShiftAssignment.user_id)
            .where(ShiftAssignment.shift_id.in_(shift_ids))
            .order_by(AppUser.ad)
        )
    ).all()
    out: dict[uuid.UUID, list[ShiftPersonelOut]] = {}
    for shift_id, u in rows:
        out.setdefault(shift_id, []).append(
            ShiftPersonelOut(
                user_id=u.id, ad=u.ad,
                avatar_url=presign_get(u.avatar_key) if u.avatar_key else None,
            )
        )
    return out


def _shift_out(obj: Shift, personel: list[ShiftPersonelOut]) -> ShiftOut:
    out = ShiftOut.model_validate(obj)
    out.personel = personel
    return out


@router.put("/{shift_id}/assignments", response_model=ShiftOut)
async def replace_assignments(
    shift_id: uuid.UUID,
    body: ShiftAssignmentsUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ASSIGNER),
) -> ShiftOut:
    """Vardiya personelini TAM LISTE olarak degistirir (admin + yonetici).

    Yalniz saha rolleri atanabilir (security|tesis_gorevlisi) — baska rol id'si
    422. RLS: yabanci tenant vardiyasi 404."""
    obj = await get_or_404(db, Shift, shift_id)
    ids = list(dict.fromkeys(body.user_ids))  # sirali tekillestirme
    if ids:
        users = (
            (await db.execute(select(AppUser).where(AppUser.id.in_(ids)))).scalars().all()
        )
        if len(users) != len(ids) or any(u.role not in _ATANABILIR for u in users):
            raise APIError(
                422, "invalid_assignment",
                "Yalniz security/tesis_gorevlisi kullanicilari atanabilir.",
            )
    await db.execute(delete(ShiftAssignment).where(ShiftAssignment.shift_id == shift_id))
    for uid in ids:
        db.add(ShiftAssignment(tenant_id=user.tenant_id, shift_id=shift_id, user_id=uid))
    await db.flush()
    await audit_user(
        db, user, Action.SHIFT_ASSIGN, resource_type="shift", resource_id=shift_id,
        meta={"user_ids": [str(i) for i in ids]},
    )
    pmap = await _personel_map(db, [shift_id])
    return _shift_out(obj, pmap.get(shift_id, []))
```

`list_shifts` dönüşünü `_personel_map` ile zenginleştir (`items=[_shift_out(r, pmap.get(r.id, [])) for r in rows]`); `get_shift` aynı şekilde. `contracts/auth.md` §4 shifts satırına atama ucu.

- [ ] **Step 4: Yeşil gör** — build api + `pytest -q tests/test_shift_assignments.py tests/test_yonetici.py` PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app backend/tests/test_shift_assignments.py contracts/auth.md
git commit -m "feat(shifts): personel atamasi — PUT /shifts/{id}/assignments + listede personel/avatar (WP-E)"
```

---

### Task 10: WP-E mobil — vardiya kartında foto + atama ekranı

**Files:**
- Modify: `mobile/lib/src/features/shifts/domain/shift_models.dart` (ShiftPersonel)
- Modify: `mobile/lib/src/features/shifts/data/shifts_api.dart` (updateAssignments + personelProvider)
- Modify: `mobile/lib/src/features/home/presentation/widgets/shift_status_card.dart` (avatarUrl)
- Modify: `mobile/lib/src/features/shifts/presentation/vardiya_section.dart` (avatar + N Görevli)
- Create: `mobile/lib/src/features/shifts/presentation/vardiyalar_screen.dart`
- Modify: `mobile/lib/src/routing/app_router.dart` (`/vardiyalar` rotası), yönetici+saha ekranlarında `onSeeAll` → `/vardiyalar`
- Modify: `mobile/test/shift_models_test.dart`, `mobile/test/shift_status_card_test.dart`
- Create: `mobile/test/vardiyalar_screen_test.dart`

**Interfaces:**
- Consumes: `GET /shifts → personel[]`, `PUT /shifts/{id}/assignments`, `GET /users?role=` (admin+yonetici — atama seçicisi).
- Produces: `ShiftPersonel {userId, ad, avatarUrl}`; `Shift.personel: List<ShiftPersonel>`; `ShiftStatusCard.avatarUrl: String?`; `ShiftsApi.updateAssignments(String shiftId, List<String> userIds)`; `atanabilirPersonelProvider` (security+tesis_gorevlisi kullanıcı listesi); rota `/vardiyalar`.

- [ ] **Step 1: Kırmızı testler**

`shift_models_test.dart`'a:

```dart
test('personel listesi savunmaci parse edilir', () {
  final s = Shift.fromJson({
    'id': 's1', 'ad': 'Sabah', 'baslangic_saat': '06:00',
    'bitis_saat': '14:00',
    'personel': [
      {'user_id': 'u1', 'ad': 'Guard A', 'avatar_url': 'https://x/a.jpg'},
      {'user_id': 'u2', 'ad': 'Gorevli A'},
    ],
  });
  expect(s.personel.length, 2);
  expect(s.personel.first.avatarUrl, 'https://x/a.jpg');
  expect(s.personel.last.avatarUrl, isNull);
});

test('personel alani yoksa bos liste (eski sunucu uyumu)', () {
  final s = Shift.fromJson({'id': 's1', 'ad': 'Sabah',
      'baslangic_saat': '06:00', 'bitis_saat': '14:00'});
  expect(s.personel, isEmpty);
});
```

`shift_status_card_test.dart`'a:

```dart
testWidgets('avatarUrl verilirse resimli avatar cizilir', (tester) async {
  await tester.pumpWidget(_wrap(const ShiftStatusCard(
    title: 'Sabah', subtitle: '06:00 - 14:00',
    status: ShiftStatus.aktif, footer: '2 Görevli',
    avatarUrl: 'https://example.com/a.jpg',
  )));
  final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
  expect(avatar.backgroundImage, isA<NetworkImage>());
});
```

- [ ] **Step 2: KIRMIZI gör** — `flutter test test/shift_models_test.dart test/shift_status_card_test.dart` FAIL.

- [ ] **Step 3: Model + kart + API**

`shift_models.dart`:

```dart
/// Vardiyaya atanan personel (WP-E) — GET /shifts personel[] elemani.
class ShiftPersonel {
  const ShiftPersonel({required this.userId, required this.ad, this.avatarUrl});

  final String userId;
  final String ad;
  final String? avatarUrl;

  factory ShiftPersonel.fromJson(Map<String, dynamic> json) => ShiftPersonel(
        userId: json['user_id'] as String? ?? '',
        ad: json['ad'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
      );
}
```

`Shift`'e `this.personel = const []` + `final List<ShiftPersonel> personel;` + fromJson'da:

```dart
personel: [
  for (final p in (json['personel'] as List?) ?? const [])
    if (p is Map) ShiftPersonel.fromJson(Map<String, dynamic>.from(p)),
],
```

`shift_status_card.dart`: `this.avatarUrl` parametresi; `_Avatar`'a `avatarUrl` geçir:

```dart
CircleAvatar(
  radius: 22,
  backgroundColor: color.withValues(alpha: 0.12),
  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
  child: avatarUrl == null ? Icon(Icons.person, color: color) : null,
),
```

`vardiya_section.dart` itemBuilder'da:

```dart
return ShiftStatusCard(
  title: v.ad,
  subtitle: '${v.baslangicSaat} - ${v.bitisSaat}',
  status: aktif ? ShiftStatus.aktif : ShiftStatus.planlandi,
  avatarUrl: v.personel.isNotEmpty ? v.personel.first.avatarUrl : null,
  footer: v.personel.isNotEmpty
      ? '${v.personel.length} Görevli'
      : gunTipiLabel(v.gunTipi),
);
```

`shifts_api.dart`'a:

```dart
  Future<void> updateAssignments(String shiftId, List<String> userIds) async {
    await _dio.put<Map<String, dynamic>>(
      '/shifts/$shiftId/assignments',
      data: {'user_ids': userIds},
    );
  }

/// Atanabilir saha personeli (admin+yonetici cagirir; GET /users RBAC'i).
final atanabilirPersonelProvider =
    FutureProvider.autoDispose<List<ShiftPersonel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final out = <ShiftPersonel>[];
  for (final role in ['security', 'tesis_gorevlisi']) {
    final res = await dio.get<Map<String, dynamic>>(
      '/users', queryParameters: {'role': role, 'limit': 200},
    );
    for (final item in (res.data?['items'] as List?) ?? const []) {
      if (item is Map) {
        final m = Map<String, dynamic>.from(item);
        out.add(ShiftPersonel(
            userId: m['id'] as String? ?? '', ad: m['ad'] as String? ?? ''));
      }
    }
  }
  return out;
});
```

- [ ] **Step 4: VardiyalarScreen + rota**

`vardiyalar_screen.dart`: `ConsumerWidget`; `shiftsProvider` listesi → her vardiya `Card(ListTile)`: başlık `v.ad`, altyazı `'${v.baslangicSaat} - ${v.bitisSaat} • ${gunTipiLabel(v.gunTipi)}'` + personel adları virgüllü satır. Rol admin/yonetici ise trailing `TextButton('Personel Ata')` → `showModalBottomSheet` içinde `atanabilirPersonelProvider` listesi `CheckboxListTile`'larla (başlangıç işaretleri `v.personel` id'leri); "Kaydet" → `updateAssignments` → `ref.invalidate(shiftsProvider)` + sheet kapat; hata SnackBar. Diğer roller salt-okunur. Boş vardiya listesi: ortada "Vardiya tanımı yok" metni.

`app_router.dart`: mevcut düz GoRoute desenine `AppRoutes.vardiyalar = '/vardiyalar'` ekle (guard: shifts okuyabilen roller — admin/yonetici/security/tesisGorevlisi; mevcut rota-guard deseni neyse onu izle). `yonetici_home_screen.dart` ve `saha_home_screen.dart`'ta `VardiyaSection(onSeeAll: () => context.push(AppRoutes.vardiyalar))`.

`vardiyalar_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/shifts/data/shifts_api.dart';
import 'package:mobile/src/features/shifts/domain/shift_models.dart';
import 'package:mobile/src/features/shifts/presentation/vardiyalar_screen.dart';

void main() {
  testWidgets('vardiyalar listelenir; personel adlari gorunur', (tester) async {
    const v = Shift(
      id: 's1', ad: 'Sabah Vardiyası',
      baslangicSaat: '06:00', bitisSaat: '14:00',
      personel: [ShiftPersonel(userId: 'u1', ad: 'Guard A')],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [shiftsProvider.overrideWith((ref) async => [v])],
      // Ekran kurucusu rol parametresi aliyorsa testte yonetici gec.
      child: const MaterialApp(home: VardiyalarScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sabah Vardiyası'), findsOneWidget);
    expect(find.textContaining('Guard A'), findsOneWidget);
  });
}
```

- [ ] **Step 5: Suite yeşil** — `flutter test && flutter analyze`.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/src mobile/test
git commit -m "feat(mobile/shifts): vardiya kartinda personel avatari + /vardiyalar atama ekrani (WP-E)"
```

---

### Task 11: WP-F backend — kamera CRUD

**Files:**
- Modify: `backend/app/audit.py` (CAMERA_CREATE/UPDATE/DELETE)
- Modify: `backend/app/schemas.py` (Camera şemaları)
- Create: `backend/app/routers/cameras.py`
- Modify: `backend/app/main.py` (router kaydı)
- Create: `backend/tests/test_cameras.py`
- Modify: `contracts/auth.md` (§4 cameras satırı)

**Interfaces:**
- Consumes: `camera` tablosu (Task 3).
- Produces: `GET /cameras` (admin+yonetici+security) → `{meta, items:[{id, ad, stream_url, created_at, updated_at}]}`; `POST/PATCH/DELETE` (admin+yonetici). Task 12 tüketir.

- [ ] **Step 1: Kırmızı test** — `backend/tests/test_cameras.py`:

```python
"""Kamera MVP (WP-F) — CRUD RBAC + URL semasi + tenant izolasyonu."""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_yonetici_crud_security_okur(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])

    ad = f"Ana Giriş {uuid.uuid4().hex[:6]}"
    r = client.post("/cameras", headers=yonetici,
                    json={"ad": ad, "stream_url": "https://nvr.example.com/s1.m3u8"})
    assert r.status_code == 201, r.text
    cid = r.json()["id"]

    r = client.get("/cameras", headers=guard)  # security OKUR
    assert r.status_code == 200
    assert any(i["id"] == cid for i in r.json()["items"])

    r = client.patch(f"/cameras/{cid}", headers=yonetici, json={"ad": ad + "-2"})
    assert r.status_code == 200 and r.json()["ad"] == ad + "-2"

    assert client.delete(f"/cameras/{cid}", headers=yonetici).status_code == 204


def test_rbac_gorevli_resident_403_guard_yazamaz(client, world):
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])
    resident = _headers(client, world["slug_a"], world["resident_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])

    for h in (gorevli, resident):  # KVKK: kamera listesi bile kapali
        assert client.get("/cameras", headers=h).status_code == 403
    r = client.post("/cameras", headers=guard,
                    json={"ad": "X", "stream_url": "https://x/y.m3u8"})
    assert r.status_code == 403


def test_gecersiz_url_422(client, world):
    yonetici = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.post("/cameras", headers=yonetici,
                    json={"ad": "K", "stream_url": "rtsp://nvr/kanal1"})
    assert r.status_code == 422  # yalniz http(s) — istemci oynaticisi sinirli


def test_tenant_izolasyonu(client, world):
    yonetici_a = _headers(client, world["slug_a"], world["yonetici_a"])
    yonetici_b = _headers(client, world["slug_b"], world["yonetici_b"])
    r = client.post("/cameras", headers=yonetici_a,
                    json={"ad": f"A-{uuid.uuid4().hex[:6]}",
                          "stream_url": "https://a/s.m3u8"})
    cid = r.json()["id"]
    assert client.get("/cameras", headers=yonetici_b).json()["items"] == [] or all(
        i["id"] != cid for i in client.get("/cameras", headers=yonetici_b).json()["items"]
    )
    assert client.delete(f"/cameras/{cid}", headers=yonetici_b).status_code == 404
```

- [ ] **Step 2: KIRMIZI gör** — build api + `pytest -q tests/test_cameras.py`: 404.

- [ ] **Step 3: Uygula**

`audit.py`:

```python
    CAMERA_CREATE = "camera_create"
    CAMERA_UPDATE = "camera_update"
    CAMERA_DELETE = "camera_delete"
```

`schemas.py`:

```python
# -------------------------------- cameras ---------------------------------- #
def _http_url(v: str) -> str:
    if not (v.startswith("http://") or v.startswith("https://")):
        raise ValueError("stream_url http(s):// ile baslamali")
    return v


class CameraCreate(BaseModel):
    ad: str = Field(..., min_length=1, max_length=100)
    # Istemcinin oynattigi HLS/MJPEG yayini; backend HIC cekmez.
    stream_url: str

    @field_validator("stream_url")
    @classmethod
    def _v_url(cls, v: str) -> str:
        return _http_url(v)


class CameraUpdate(BaseModel):
    ad: str | None = Field(None, min_length=1, max_length=100)
    stream_url: str | None = None

    @field_validator("stream_url")
    @classmethod
    def _v_url(cls, v: str | None) -> str | None:
        return None if v is None else _http_url(v)

    @model_validator(mode="after")
    def _at_least_one(self) -> "CameraUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self


class CameraOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    ad: str
    stream_url: str
    created_at: datetime
    updated_at: datetime


class CameraListResponse(BaseModel):
    meta: PageMetaOut
    items: list[CameraOut]
```

`routers/cameras.py` — `shifts.py` CRUD iskeletinin birebir uyarlaması:

```python
"""Kamera MVP (WP-F) — site kamera yayin URL'leri CRUD.

RBAC (auth.md §4): GET admin/yonetici/security (KVKK: tesis_gorevlisi ve
resident kamera GORMEZ); yazma admin/yonetici. Backend yayini HIC cekmez
(istemci oynatir) — SSRF yuzeyi yok; URL semasi http(s) ile sinirli.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from ..audit import Action, audit_user
from ..crud_helpers import get_or_404, translate_integrity
from ..deps import get_tenant_db, require_role
from ..models import AppUser, Camera
from ..schemas import CameraCreate, CameraListResponse, CameraOut, CameraUpdate

router = APIRouter(prefix="/cameras", tags=["cameras"])

_READER = require_role("admin", "yonetici", "security")
_WRITER = require_role("admin", "yonetici")


@router.get("", response_model=CameraListResponse)
async def list_cameras(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_tenant_db),
    _: AppUser = Depends(_READER),
) -> CameraListResponse:
    total = (await db.execute(select(func.count()).select_from(Camera))).scalar_one()
    rows = (
        await db.execute(select(Camera).order_by(Camera.ad).limit(limit).offset(offset))
    ).scalars().all()
    return CameraListResponse(
        meta={"limit": limit, "offset": offset, "total": total}, items=list(rows)
    )


@router.post("", response_model=CameraOut, status_code=201)
async def create_camera(
    body: CameraCreate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> Camera:
    obj = Camera(tenant_id=user.tenant_id, **body.model_dump())
    db.add(obj)
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await audit_user(db, user, Action.CAMERA_CREATE, resource_type="camera",
                     resource_id=obj.id, meta={"ad": obj.ad})
    await db.refresh(obj)
    return obj


@router.patch("/{camera_id}", response_model=CameraOut)
async def update_camera(
    camera_id: uuid.UUID,
    body: CameraUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> Camera:
    obj = await get_or_404(db, Camera, camera_id)
    for key, value in body.model_dump(exclude_unset=True).items():
        setattr(obj, key, value)
    obj.updated_at = func.now()
    try:
        await db.flush()
    except IntegrityError as exc:
        raise translate_integrity(exc)
    await audit_user(db, user, Action.CAMERA_UPDATE, resource_type="camera",
                     resource_id=obj.id)
    await db.refresh(obj)
    return obj


@router.delete("/{camera_id}", status_code=204)
async def delete_camera(
    camera_id: uuid.UUID,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_WRITER),
) -> Response:
    obj = await get_or_404(db, Camera, camera_id)
    await db.delete(obj)
    await db.flush()
    await audit_user(db, user, Action.CAMERA_DELETE, resource_type="camera",
                     resource_id=camera_id)
    return Response(status_code=204)
```

`main.py` kayıt + `contracts/auth.md` §4 cameras satırı.

- [ ] **Step 4: Yeşil gör** — build api + `pytest -q tests/test_cameras.py` PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app backend/tests/test_cameras.py contracts/auth.md
git commit -m "feat(cameras): kamera MVP CRUD — yonetici tanimlar, security okur (WP-F)"
```

---

### Task 12: WP-F mobil — Canlı Kamera şeridi + oynatıcı + yönetim

**Files:**
- Modify: `mobile/pubspec.yaml` (`video_player: ^2.9.2`)
- Create: `mobile/lib/src/features/cameras/domain/camera_models.dart`
- Create: `mobile/lib/src/features/cameras/data/cameras_api.dart`
- Create: `mobile/lib/src/features/cameras/presentation/canli_kamera_section.dart`
- Create: `mobile/lib/src/features/cameras/presentation/camera_player_screen.dart`
- Create: `mobile/lib/src/features/cameras/presentation/kameralar_screen.dart`
- Modify: `mobile/lib/src/features/home/presentation/saha_home_screen.dart` (şerit ekle; Yakında'dan Canlı Kamera kartını KALDIR)
- Modify: `mobile/lib/src/routing/app_router.dart` (`/kameralar`, `/kamera-izle`)
- Modify: ayarlar ekranı (`features/settings`) — admin/yonetici'ye "Kameralar" girişi
- Create: `mobile/test/camera_models_test.dart`, `mobile/test/canli_kamera_section_test.dart`
- Modify: `mobile/test/saha_home_screen_test.dart` (camerasProvider override; Yakında'da 2 kart kaldı)

**Interfaces:**
- Consumes: `/cameras` CRUD (Task 11).
- Produces: `Camera {id, ad, streamUrl}`; `camerasProvider: FutureProvider.autoDispose<List<Camera>>`; `CanliKameraSection({required List<Camera> kameralar, required ValueChanged<Camera> onIzle})`; rotalar `/kameralar` (yönetim), `/kamera-izle` (extra: Camera).

- [ ] **Step 1: Kırmızı testler**

`camera_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';

void main() {
  test('fromJson savunmaci parse', () {
    final c = Camera.fromJson(
        {'id': 'c1', 'ad': 'Ana Giriş', 'stream_url': 'https://x/s.m3u8'});
    expect(c.ad, 'Ana Giriş');
    expect(c.streamUrl, 'https://x/s.m3u8');
    expect(Camera.fromJson(const {}).ad, '');
  });
}
```

`canli_kamera_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';
import 'package:mobile/src/features/cameras/presentation/canli_kamera_section.dart';

void main() {
  const kamera = Camera(id: 'c1', ad: 'Ana Giriş', streamUrl: 'https://x/s.m3u8');

  testWidgets('kameralar yatay kartlarla listelenir; dokunma onIzle cagirir',
      (tester) async {
    Camera? izlenen;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CanliKameraSection(
            kameralar: const [kamera], onIzle: (c) => izlenen = c),
      ),
    ));
    expect(find.text('Canlı Kamera'), findsOneWidget);
    expect(find.text('Ana Giriş'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    await tester.tap(find.text('Ana Giriş'));
    expect(izlenen?.id, 'c1');
  });

  testWidgets('bos listede bolum HIC cizilmez', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CanliKameraSection(kameralar: const [], onIzle: (_) {}),
      ),
    ));
    expect(find.text('Canlı Kamera'), findsNothing);
  });
}
```

- [ ] **Step 2: KIRMIZI gör** — `flutter test test/camera_models_test.dart test/canli_kamera_section_test.dart` FAIL.

- [ ] **Step 3: Model + API + şerit**

`camera_models.dart`:

```dart
/// GET /cameras elemani (WP-F) — yayin URL'sini ISTEMCI oynatir.
class Camera {
  const Camera({required this.id, required this.ad, required this.streamUrl});

  final String id;
  final String ad;
  final String streamUrl;

  factory Camera.fromJson(Map<String, dynamic> json) => Camera(
        id: json['id'] as String? ?? '',
        ad: json['ad'] as String? ?? '',
        streamUrl: json['stream_url'] as String? ?? '',
      );
}
```

`cameras_api.dart` (shifts_api deseni: fetch + create/update/delete + `camerasProvider`; hata → izleyen bölüm gizler). `canli_kamera_section.dart`: boş listede `SizedBox.shrink()`; `SectionHeader(title: 'Canlı Kamera')` + 120 yükseklikte yatay `ListView.separated`; her kart 160 genişlik, koyu (`Colors.black87`) `Card` + ortada `Icon(Icons.play_circle_fill, color: Colors.white70, size: 36)` + altta ad ve yeşil "● Canlı" satırı; `InkWell` → `onIzle(kamera)`.

- [ ] **Step 4: Oynatıcı + yönetim + kablolama**

`pubspec.yaml` dependencies'e `video_player: ^2.9.2`; `flutter pub get`.

`camera_player_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../domain/camera_models.dart';

/// Tam ekran canli yayin (WP-F MVP) — HLS/MJPEG URL'sini oynatir.
/// Baglanti kurulamazsa kullaniciya acik mesaj (cokme yok).
class CameraPlayerScreen extends StatefulWidget {
  const CameraPlayerScreen({super.key, required this.kamera});

  final Camera kamera;

  @override
  State<CameraPlayerScreen> createState() => _CameraPlayerScreenState();
}

class _CameraPlayerScreenState extends State<CameraPlayerScreen> {
  late final VideoPlayerController _controller;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.kamera.streamUrl))
          ..initialize().then((_) {
            if (mounted) setState(() => _controller.play());
          }).catchError((Object e) {
            if (mounted) setState(() => _hata = 'Yayına bağlanılamadı');
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.kamera.ad)),
      backgroundColor: Colors.black,
      body: Center(
        child: _hata != null
            ? Text(_hata!, style: const TextStyle(color: Colors.white70))
            : _controller.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(),
      ),
    );
  }
}
```

`kameralar_screen.dart`: `camerasProvider` listesi (`ListTile`: ad + URL altyazı, tıklayınca oynatıcı); admin/yonetici için FAB "Kamera Ekle" + satırda düzenle/sil — form `AlertDialog` (ad + URL `TextFormField`, URL `http` şema kontrolü istemcide de) → API çağrısı → `ref.invalidate(camerasProvider)`; hata SnackBar.

`app_router.dart`: `/kameralar` → `KameralarScreen` (admin/yonetici/security), `/kamera-izle` → `CameraPlayerScreen(kamera: state.extra as Camera)`. `saha_home_screen.dart`: security'de `VardiyaSection` altına:

```dart
if (role == UserRole.security)
  ref.watch(camerasProvider).maybeWhen(
        data: (list) => CanliKameraSection(
          kameralar: list,
          onIzle: (c) => context.push(AppRoutes.kameraIzle, extra: c),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
```

ve Yakında listesinden `'Canlı Kamera'` `YakindaKart`'ını SİL (security'de 2 kart kalır: Araç Plaka + İhlaller). Ayarlar ekranına admin/yonetici görünürlüklü `ListTile('Kameralar')` → `/kameralar`. `saha_home_screen_test.dart`: `camerasProvider.overrideWith((ref) async => const <Camera>[])` ekle; "Canlı Kamera" Yakında kartı beklentisini kaldır.

- [ ] **Step 5: Suite yeşil** — `flutter test && flutter analyze`.

- [ ] **Step 6: Commit**

```bash
git add mobile/pubspec.yaml mobile/pubspec.lock mobile/lib/src mobile/test
git commit -m "feat(mobile/cameras): canli kamera seridi + video_player oynatici + yonetim ekrani (WP-F)"
```

---

### Task 13: Uçtan uca doğrulama + kapanış

**Files:**
- Modify: `docs/superpowers/specs/2026-07-24-home-gorsel-zenginlestirme-design.md` (Durum: uygulandı)

**Interfaces:** —

- [ ] **Step 1: Backend TAM suite**

```bash
cd infra && docker compose build api && docker compose up -d api
docker compose exec -T api sh -c "pytest -q > /tmp/pt.txt 2>&1; echo EXITCODE=$?; tail -6 /tmp/pt.txt"
```

Expected: EXITCODE=0 (523 + yeni testler; ~25 dk sürer — bekle). Rezervasyon saat-flake bilinen istisna: 21:xx'te `test_rezervasyon` 422 verirse yalnız o dosyayı saat dışında tekrar koş.

- [ ] **Step 2: Mobil TAM suite + analiz**

```bash
cd mobile && flutter analyze && flutter test
```

Expected: analiz temiz; tüm testler yeşil (`scan_outbox_test` paralel-flake bilinen istisna — izole koşumda geçmeli).

- [ ] **Step 3: Görsel doğrulama (flutter web + Playwright akışı)**

`flutter build web --release --dart-define=API_BASE_URL=http://localhost:8000` + `python3 -m http.server 7357 --directory build/web` + Playwright chromium (`--disable-web-security --enable-unsafe-swiftshader`). Seed kullanıcılar: `+90532111220{1..4}` / `Yonetici123!`/`Guard123!`/`Resident123!`/`Clean123!`. Kontrol listesi: (1) 4'lü ızgara + dar pencerede 2'ye düşüş, (2) başlıkta hava (İstanbul), (3) sakin duyuru kartında resim (resimli duyuru seed'de yoksa yönetici hesabından resimli duyuru oluştur), (4) yönetici profilden foto yükle → app-bar + vardiya kartı + sakinin iletişim kartında görünür, (5) yönetici `/vardiyalar`'dan atama, (6) security ana ekranda Canlı Kamera şeridi (test için yönetici hesabından bir kamera kaydı ekle; örnek herkese açık HLS: `https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8`). Video web'de oynamazsa karta/hata mesajına kadar doğrula — gerçek oynatma cihaz testine not düş.

- [ ] **Step 4: Spec durumunu güncelle + commit**

Spec başındaki Durum satırını "Uygulandı (2026-07-XX)" yap.

```bash
git add docs/superpowers/specs/2026-07-24-home-gorsel-zenginlestirme-design.md
git commit -m "docs(spec): home gorsel zenginlestirme — uygulandi isareti"
```
