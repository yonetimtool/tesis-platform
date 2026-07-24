# Panel Görsel Düzeltmeleri + Saha Personeli Fotoğraf Yönetimi — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 4'lü ızgara/Hızlı Özet taşmalarını gidermek ve saha personeli profil fotoğrafını yalnız yöneticinin yönettiği (vardiya kartlarında görünen) bir akışa kavuşturmak.

**Architecture:** Mobil Flutter/Riverpod/Dio + backend FastAPI/SQLAlchemy(async)/RLS. Taşma düzeltmesi saf sunum (FittedBox). Avatar yönetimi: `PATCH /me/avatar` RBAC daralır (yönetici+resident), yeni `PATCH /users/{id}/avatar` (yalnız yönetici, saha personeli) + `GET /users` avatar_url. Vardiya kartları avatarı zaten `AppUser.avatar_key`'den türetir — değişmez.

**Tech Stack:** FastAPI, SQLAlchemy async, httpx (canlı-server testleri), Flutter/Riverpod/Dio/GoRouter, `image_picker` (mevcut), MinIO presign.

**Spec:** `docs/superpowers/specs/2026-07-24-panel-duzeltme-saha-avatar-design.md`

## Global Constraints

- **Backend testleri CANLI api container'ına gider** (httpx `client` fixture, monkeypatch yok). Backend/test düzenlemesinden sonra ZORUNLU: `cd infra && docker compose build api && docker compose up -d api`, api healthy olana kadar bekle, sonra `docker compose exec -T api sh -c "pytest -q tests/<dosya> 2>&1 | tail -5"`. **Bu planda migration YOK** (yalnız RBAC + presign + şema alanı) — `down -v` GEREKMEZ.
- Her backend RBAC değişikliğinde `contracts/auth.md` §4 aynı commit'te güncellenir.
- Mobil: yorumlar/adlandırma Türkçe (ASCII yorum), UI metinleri Türkçe. Savunmacı JSON parse (`as String? ?? ''`). Ana ekran/personel ekranı hata/boş durumda SESSİZCE gizlenir; ekran asla düşmez.
- TDD: her adımda önce KIRMIZI test, sonra minimal kod. Mobil tam doğrulama: `cd mobile && flutter analyze && flutter test` (mevcut suite 586; her görev sonunda tamamı yeşil, `flutter analyze` "No issues found").
- Renk sabitleri: marka navy `0xFF0E3C91` / teal `0xFF1DB2B6` (`core/branding/yonetio_logo.dart`).
- Commit mesajı dili: `feat(scope): turkce-ascii ozet` / `fix(scope): ...`.
- Avatar yetki matrisi (spec): `PATCH /me/avatar` → yönetici+resident; `PATCH /users/{id}/avatar` → yalnız yönetici, hedef ∈ {security, tesis_gorevlisi}.

---

### Task 1: P1 — StatTile + dense ModuleCard taşma düzeltmesi (mobil, backend yok)

**Files:**
- Modify: `mobile/lib/src/features/home/presentation/widgets/stat_tile.dart`
- Modify: `mobile/lib/src/features/home/presentation/widgets/module_card.dart`
- Modify: `mobile/test/stat_tile_test.dart`
- Modify: `mobile/test/module_card_test.dart`

**Interfaces:**
- Produces: `StatTile`/`ModuleCard` imzaları AYNI kalır (yalnız iç düzen). Diğer görevler etkilenmez.

- [ ] **Step 1: Kırmızı test — dense StatTile uzun değer taşmaz**

`mobile/test/stat_tile_test.dart`'a ekle (mevcut `_wrap` helper'ını kullan; yoksa aşağıdaki gibi dar hücre kur):

```dart
testWidgets('dense: uzun para degeri dar hucrede tasmadan sigar', (tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 88, // 4 sutunlu izgaradaki gercek hucre genisligine yakin
          height: 150,
          child: StatTile(
            icon: Icons.payments_outlined,
            value: '₺248.750',
            label: 'Toplam Tahsilat',
            sublabel: 'Bu Ay',
            dense: true,
          ),
        ),
      ),
    ),
  ));
  expect(tester.takeException(), isNull); // RenderFlex overflow yok
  expect(find.text('₺248.750'), findsOneWidget); // deger hala ekranda
});
```

- [ ] **Step 2: KIRMIZI gör**

Run: `cd mobile && flutter test test/stat_tile_test.dart`
Expected: FAIL — `A RenderFlex overflowed` (takeException null değil) VEYA metin FittedBox olmadan kesiliyor.

- [ ] **Step 3: StatTile value'yu FittedBox ile sığdır**

`stat_tile.dart` — `value` Text'ini şununla değiştir (mevcut `Text(value, ...)` bloğu):

```dart
SizedBox(
  width: double.infinity,
  child: FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(
      value,
      maxLines: 1,
      style: theme.textTheme.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w800),
    ),
  ),
),
```

- [ ] **Step 4: Yeşil gör** — `flutter test test/stat_tile_test.dart` PASS.

- [ ] **Step 5: Kırmızı test — dense ModuleCard uzun baslik taşmaz**

`mobile/test/module_card_test.dart`'a ekle:

```dart
testWidgets('dense: uzun baslik dar hucrede tasmaz', (tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 88,
          height: 132,
          child: ModuleCard(
            icon: Icons.directions_car_outlined,
            title: 'Otopark Kullanımı',
            counter: '78 / 120',
            dense: true,
          ),
        ),
      ),
    ),
  ));
  expect(tester.takeException(), isNull);
  expect(find.text('Otopark Kullanımı'), findsOneWidget);
  expect(find.text('78 / 120'), findsOneWidget);
});
```

- [ ] **Step 6: KIRMIZI gör** — `flutter test test/module_card_test.dart` FAIL (overflow).

- [ ] **Step 7: dense ModuleCard baslik + sayaci FittedBox ile sığdır**

`module_card.dart` — `Flexible(child: Text(title...))` bloğunu dense'e göre dallandır:

```dart
// Dense: tek satir + FittedBox (referans temiz gorunum; tasma imkansiz).
// Non-dense: mevcut 2 satir + ellipsis korunur.
dense
    ? SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(title, maxLines: 1, style: titleStyle),
        ),
      )
    : Flexible(
        child: Text(
          title,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
      ),
```

Sayaç `Text(counter!...)` bloğunu (else if dalı) FittedBox ile sar:

```dart
FittedBox(
  fit: BoxFit.scaleDown,
  child: Text(
    counter!,
    maxLines: 1,
    style: (dense
            ? theme.textTheme.labelSmall
            : theme.textTheme.labelMedium)
        ?.copyWith(
      color: accent ?? YonetioColors.navy,
      fontWeight: FontWeight.w600,
    ),
  ),
),
```

- [ ] **Step 8: Tüm suite** — `flutter test` (özellikle `small_screen_overflow_test`, `home_grid_test`, `stat_tile_test`, `module_card_test`, `role_home_body_test`) + `flutter analyze` temiz. 320/360/412dp'de taşma yok.

- [ ] **Step 9: Commit**

```bash
git add mobile/lib/src/features/home/presentation/widgets/stat_tile.dart mobile/lib/src/features/home/presentation/widgets/module_card.dart mobile/test/stat_tile_test.dart mobile/test/module_card_test.dart
git commit -m "fix(mobile/home): 4'lu izgara + Hizli Ozet tasma — FittedBox ile deger/baslik sigar"
```

---

### Task 2: P3 backend — avatar RBAC daralt + `PATCH /users/{id}/avatar` + users avatar_url

**Files:**
- Modify: `backend/app/routers/me.py` (`_AVATAR_ROLLER`)
- Modify: `backend/app/routers/users.py` (avatar_url doldur + yeni uç)
- Modify: `backend/app/schemas.py` (`UserAdminListItem.avatar_url`, `UserAdminOut.avatar_url`)
- Modify: `backend/tests/test_avatar.py`
- Create: `backend/tests/test_users_avatar.py`
- Modify: `contracts/auth.md` (§4 iki satır)

**Interfaces:**
- Consumes: `AvatarUpdate` (mevcut), `storage.presign_get/delete_objects`, `AppUser.avatar_key`.
- Produces: `PATCH /me/avatar` → yönetici+resident (diğerleri 403). `PATCH /users/{id}/avatar {avatar_key: str|null}` → yönetici, hedef saha personeli → `UserAdminOut` (avatar_url dolu). `GET /users` item + `GET /users/{id}` → `avatar_url: str | None`.

- [ ] **Step 1: Kırmızı test — /me/avatar yeni RBAC + users-avatar**

`backend/tests/test_users_avatar.py` (yeni):

```python
"""Saha personeli avatari (P3) — yonetici yonetir; /me/avatar RBAC daraldi."""
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
    import httpx

    r = client.post(
        "/uploads/presign", headers=headers,
        json={"content_type": "image/jpeg", "dosya_adi": "p.jpg"},
    )
    assert r.status_code == 200, r.text
    t = r.json()
    put = httpx.put(t["upload_url"], content=b"x",
                    headers={"Content-Type": "image/jpeg"}, timeout=10)
    assert put.status_code in (200, 204), put.text
    return t["foto_key"]


def _staff_id(client, world, role):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    who = {"security": "guard_a", "tesis_gorevlisi": "gorevli_a"}[role]
    me = _headers(client, world["slug_a"], world[who])
    return client.get("/me", headers=me).json()["id"]


def test_me_avatar_rbac_yonetici_resident_evet_digerleri_403(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    res = _headers(client, world["slug_a"], world["resident_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])

    key_y = _upload_foto(client, yon)
    assert client.patch("/me/avatar", headers=yon,
                        json={"avatar_key": key_y}).status_code == 200
    key_r = _upload_foto(client, res)
    assert client.patch("/me/avatar", headers=res,
                        json={"avatar_key": key_r}).status_code == 200
    # saha rolleri + admin self-servis KAPALI
    for h in (guard, admin):
        assert client.patch("/me/avatar", headers=h,
                            json={"avatar_key": None}).status_code == 403


def test_yonetici_saha_personeline_avatar_atar_listede_gorunur(client, world):
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    gid = _staff_id(client, world, "security")
    key = _upload_foto(client, yon)

    r = client.patch(f"/users/{gid}/avatar", headers=yon,
                     json={"avatar_key": key})
    assert r.status_code == 200, r.text
    assert r.json()["avatar_url"]

    r = client.get("/users", headers=yon, params={"role": "security"})
    item = next(i for i in r.json()["items"] if i["id"] == gid)
    assert item["avatar_url"]


def test_users_avatar_rbac_ve_hedef_kisiti(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    guard = _headers(client, world["slug_a"], world["guard_a"])
    yon = _headers(client, world["slug_a"], world["yonetici_a"])

    gid = _staff_id(client, world, "security")
    # admin + guard bu ucu KULLANAMAZ (yalniz yonetici)
    for h in (admin, guard):
        assert client.patch(f"/users/{gid}/avatar", headers=h,
                            json={"avatar_key": None}).status_code == 403
    # hedef saha disi (resident) -> 422
    res_me = _headers(client, world["slug_a"], world["resident_a"])
    rid = client.get("/me", headers=res_me).json()["id"]
    key = _upload_foto(client, yon)
    assert client.patch(f"/users/{rid}/avatar", headers=yon,
                        json={"avatar_key": key}).status_code == 422
    # yabanci onek -> 422
    assert client.patch(f"/users/{gid}/avatar", headers=yon,
                        json={"avatar_key": f"{uuid.uuid4()}/x.jpg"}).status_code == 422


def test_users_avatar_tenant_izolasyonu(client, world):
    yon_b = _headers(client, world["slug_b"], world["yonetici_b"])
    gid_a = _staff_id(client, world, "security")  # tenant A personeli
    r = client.patch(f"/users/{gid_a}/avatar", headers=yon_b,
                     json={"avatar_key": None})
    assert r.status_code == 404  # RLS: B, A'nin kullanicisini goremez
```

- [ ] **Step 2: KIRMIZI gör**

```bash
cd infra && docker compose build api && docker compose up -d api
# api healthy bekle:
for i in $(seq 1 30); do docker compose ps api --format '{{.Status}}' | grep -q healthy && break; sleep 2; done
docker compose exec -T api sh -c "pytest -q tests/test_users_avatar.py 2>&1 | tail -8"
```
Expected: FAIL — `/users/{id}/avatar` 404/405; `/me/avatar` admin/guard 200 (henüz 403 değil); users item'da `avatar_url` KeyError.

- [ ] **Step 3: schemas — avatar_url alanları**

`schemas.py` `UserAdminListItem`'a (`created_at` üstüne):

```python
    # Saha personeli profil fotografi (presign GET URL; router doldurur).
    avatar_url: str | None = None
```

`UserAdminOut`'a (aynı yere):

```python
    avatar_url: str | None = None
```

- [ ] **Step 4: me.py — RBAC daralt**

`me.py`: `_AVATAR_ROLLER = require_role("yonetici", "resident")` (yorumu güncelle: self-servis avatar yalniz yonetici + resident; saha personeli fotosunu yonetici /users/{id}/avatar ile yonetir).

- [ ] **Step 5: users.py — avatar_url doldur + yeni uç**

`users.py` importlarına ekle: `from ..schemas import ... AvatarUpdate, UserAdminListItem` ve `from ..storage import delete_objects, presign_get`. Yardımcılar (router tanımından sonra):

```python
_AVATAR_MANAGER = require_role("yonetici")
_AVATAR_HEDEF_ROLLER = {"security", "tesis_gorevlisi"}


def _admin_out(obj: AppUser) -> UserAdminOut:
    out = UserAdminOut.model_validate(obj)
    out.avatar_url = presign_get(obj.avatar_key) if obj.avatar_key else None
    return out


def _list_item(obj: AppUser) -> UserAdminListItem:
    out = UserAdminListItem.model_validate(obj)
    out.avatar_url = presign_get(obj.avatar_key) if obj.avatar_key else None
    return out
```

`list_users` dönüşü: `items=[_list_item(r) for r in rows]`.
`get_user` dönüşü: `return _admin_out(await get_or_404(db, AppUser, user_id))` (dönüş tipi `UserAdminOut`).
`update_user` sonundaki `return obj` → `return _admin_out(obj)`.
`update_user_contact` sonundaki `return obj` → `return _admin_out(obj)`.

Yeni uç (dosya sonuna):

```python
@router.patch("/{user_id}/avatar", response_model=UserAdminOut)
async def update_user_avatar(
    user_id: uuid.UUID,
    body: AvatarUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_AVATAR_MANAGER),
) -> UserAdminOut:
    """Saha personeli profil fotografi — YALNIZ yonetici. Hedef ayni tenant'ta
    (RLS) ve rolu saha personeli (security/tesis_gorevlisi) olmali; degilse 422.
    avatar_key yoneticinin kendi tenant namespace'inde (IDOR). null kaldirir;
    eski MinIO objesi silinir."""
    obj = await get_or_404(db, AppUser, user_id)
    if obj.role not in _AVATAR_HEDEF_ROLLER:
        raise APIError(422, "invalid_target",
                       "Yalniz saha personeline fotograf atanabilir.")
    if body.avatar_key is not None and not body.avatar_key.startswith(
        f"{user.tenant_id}/"
    ):
        raise APIError(422, "invalid_foto_key", "avatar_key tenant alani disinda")
    eski = obj.avatar_key
    obj.avatar_key = body.avatar_key
    obj.updated_at = func.now()
    if eski and eski != body.avatar_key:
        delete_objects([eski])
    await audit_user(
        db, user, Action.AVATAR_UPDATE, resource_type="app_user",
        resource_id=obj.id, meta={"hedef": str(obj.id),
                                  "kaldirildi": body.avatar_key is None},
    )
    return _admin_out(obj)
```

- [ ] **Step 6: test_avatar.py güncelle (eski self-servis RBAC değişti)**

`test_avatar.py` `test_resident_403_yabanci_onek_422` artık geçersiz (resident self-servis yükler, guard 403). Şu testle DEĞİŞTİR:

```python
def test_me_avatar_yeni_rbac(client, world):
    # yonetici + resident yukler; security/tesis_gorevlisi/admin 403.
    yon = _headers(client, world["slug_a"], world["yonetici_a"])
    res = _headers(client, world["slug_a"], world["resident_a"])
    key = _upload_foto(client, res)
    assert client.patch("/me/avatar", headers=res,
                        json={"avatar_key": key}).status_code == 200
    guard = _headers(client, world["slug_a"], world["guard_a"])
    gorevli = _headers(client, world["slug_a"], world["gorevli_a"])
    admin = _headers(client, world["slug_a"], world["admin_a"])
    yabanci = f"{uuid.uuid4()}/x.jpg"
    for h in (guard, gorevli, admin):
        assert client.patch("/me/avatar", headers=h,
                            json={"avatar_key": None}).status_code == 403
    # yonetici yabanci onek 422
    assert client.patch("/me/avatar", headers=yon,
                        json={"avatar_key": yabanci}).status_code == 422
```

`test_iletisim_kartinda_yonetici_avatari` AYNEN KALIR (yönetici self-servis hâlâ geçerli). `test_yonetici_avatar_yukler_me_gorur_null_kaldirir` AYNEN KALIR.

- [ ] **Step 7: contracts/auth.md §4 güncelle**

`PATCH /me/avatar` satırını bul; yetki sütunlarını `admin ❌ | yonetici ✅ | security ❌ | tesis_gorevlisi ❌ | resident ✅` yap ve yanındaki notu güncelle. `PATCH /me/avatar` satırının altına ekle:

```
| `PATCH /users/{id}/avatar` (saha personeli)| ❌ | ✅ | ❌  | ❌  | ❌  |
```

Not bloğunu güncelle: "Saha personeli (security/tesis_gorevlisi) profil fotosu YALNIZ yonetici tarafindan `PATCH /users/{id}/avatar` ile yonetilir; kendileri self-servis yukleyemez. `PATCH /me/avatar` yalniz yonetici + resident (kendi fotografi)."

- [ ] **Step 8: Yeşil gör**

```bash
cd infra && docker compose build api && docker compose up -d api
for i in $(seq 1 30); do docker compose ps api --format '{{.Status}}' | grep -q healthy && break; sleep 2; done
docker compose exec -T api sh -c "pytest -q tests/test_users_avatar.py tests/test_avatar.py tests/test_users.py tests/test_shift_assignments.py 2>&1 | tail -6"
```
Expected: PASS. (`tests/test_users.py` yoksa `docker compose exec -T api sh -c "ls tests | grep -i user"` ile bul ve onu koş.)

- [ ] **Step 9: Commit**

```bash
git add backend/app/routers/me.py backend/app/routers/users.py backend/app/schemas.py backend/tests/test_avatar.py backend/tests/test_users_avatar.py contracts/auth.md
git commit -m "feat(avatar): saha personeli fotosu yonetici yonetir; /me/avatar yonetici+resident (P3)"
```

---

### Task 3: P2/P3 mobil — StaffScreen foto yükleme + profil avatar görünürlüğü

**Files:**
- Modify: `mobile/lib/src/features/staff/data/staff_api.dart` (avatarUrl + setStaffAvatar + presign/upload)
- Modify: `mobile/lib/src/features/staff/presentation/staff_screen.dart` (foto seçici + listede avatar)
- Modify: `mobile/lib/src/features/profile/presentation/profile_screen.dart` (avatar kartı görünürlüğü)
- Modify: `mobile/test/staff_screen_test.dart` (varsa; yoksa Create)
- Create: `mobile/test/staff_api_test.dart`

**Interfaces:**
- Consumes: `PATCH /users/{id}/avatar` (Task 2), `/uploads/presign` + presigned PUT, `GET /users → avatar_url`.
- Produces: `StaffMember {..., avatarUrl: String?}`; `avatarUrlFromUsers(Map)`; `StaffApi.setStaffAvatar(String id, String? fotoKey)`, `StaffApi.presignUpload/uploadPhoto` (PresignTicket yeniden kullanılır).

- [ ] **Step 1: Kırmızı test — StaffMember.avatarUrl parse**

`mobile/test/staff_api_test.dart` (yeni):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/staff/data/staff_api.dart';

void main() {
  test('StaffMember avatar_url savunmaci parse', () {
    final s = StaffMember.fromJson(const {
      'id': 'u1', 'ad': 'Guard A', 'role': 'security',
      'is_active': true, 'avatar_url': 'https://x/a.jpg',
    });
    expect(s.avatarUrl, 'https://x/a.jpg');
    expect(
      StaffMember.fromJson(const {
        'id': 'u2', 'ad': 'B', 'role': 'security', 'is_active': true,
      }).avatarUrl,
      isNull,
    );
  });

  test('avatarUrlFromUsers SAF parse', () {
    expect(avatarUrlFromUsers({'avatar_url': 'https://x/y.jpg'}),
        'https://x/y.jpg');
    expect(avatarUrlFromUsers(const {}), isNull);
  });
}
```

- [ ] **Step 2: KIRMIZI gör** — `cd mobile && flutter test test/staff_api_test.dart` FAIL (alan/fonksiyon yok).

- [ ] **Step 3: staff_api.dart — avatarUrl + setStaffAvatar + presign/upload**

`StaffMember`'a alan + parse:

```dart
  final String? avatarUrl;
```
(kurucuya `this.avatarUrl,` ekle; `fromJson`'a `avatarUrl: json['avatar_url'] as String?,`.)

Dosya üstüne SAF yardımcı:

```dart
/// GET /users öğesinden avatar_url (SAF — test edilebilir).
String? avatarUrlFromUsers(Map<String, dynamic> json) =>
    json['avatar_url'] as String?;
```

`StaffApi`'ye (üst kısma `import 'dart:typed_data';` ve `import '../../tasks/domain/task_models.dart' show PresignTicket;`; kurucuyu `StaffApi(this._dio, {Dio? uploadDio}) : _uploadDio = uploadDio ?? Dio();` yap, alan `final Dio _uploadDio;`):

```dart
  Future<PresignTicket> presignUpload({required String contentType}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/uploads/presign',
        data: {'content_type': contentType, 'dosya_adi': 'personel.jpg'},
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

  /// Saha personeli avatarini ata/kaldir (yalniz yonetici — sunucu zorlar).
  Future<void> setStaffAvatar(String id, String? fotoKey) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/users/$id/avatar',
        data: {'avatar_key': fotoKey},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
```

- [ ] **Step 4: Yeşil gör** — `flutter test test/staff_api_test.dart` PASS; `flutter analyze` temiz.

- [ ] **Step 5: staff_screen.dart — foto seçici + listede avatar**

`_AddStaffSheet` (ekle/düzenle) `ConsumerStatefulWidget` state'ine foto durumu ekle: `Uint8List? _onizleme; String? _fotoKey; bool _fotoYukleniyor = false;`. `image_picker` + `imagePickerProvider` import et (`import 'package:image_picker/image_picker.dart';`, `import '../../tasks/presentation/task_complete_controller.dart' show imagePickerProvider;`). Form üstüne foto satırı (announcements/`_AvatarCard` deseni):

```dart
Row(
  children: [
    CircleAvatar(
      radius: 28,
      backgroundImage: _onizleme != null ? MemoryImage(_onizleme!) : null,
      child: _onizleme == null ? const Icon(Icons.person_outline) : null,
    ),
    const SizedBox(width: 12),
    OutlinedButton.icon(
      onPressed: _fotoYukleniyor ? null : _fotoSecMenu,
      icon: _fotoYukleniyor
          ? const SizedBox(
              height: 16, width: 16,
              child: CircularProgressIndicator(strokeWidth: 2.5))
          : const Icon(Icons.add_a_photo_outlined, size: 18),
      label: const Text('Fotoğraf'),
    ),
  ],
),
```

`_fotoSecMenu()` (Kamera/Galeri sheet — `_AvatarCard`/`destek_screen` deseni) ve `_fotoSec(ImageSource)` (pickImage → readAsBytes → `presignUpload` → `uploadPhoto` → `setState(_fotoKey=..., _onizleme=bytes)`; hata SnackBar). Düzenlemede mevcut `member.avatarUrl` varsa `NetworkImage` ile başlangıç önizleme (bytes yoksa url).

Kaydetme akışında (mevcut `addStaff`/`updateStaff` çağrısından SONRA, dönen/mevcut `id` ile):

```dart
// Foto secildiyse kullanici olustuktan/guncellendikten sonra avatarini ata.
if (_fotoKey != null && id != null) {
  await ref.read(staffApiProvider).setStaffAvatar(id, _fotoKey);
}
```
(`addStaff` yalnız `temp_code` döndürüyor; yeni kullanıcı id'si için: create sonrası `ref.refresh(fieldStaffProvider.future)` ile listeyi tazele ve ada göre id bul, YA DA `StaffApi.addStaff`'i `id` de dönecek şekilde küçük genişlet — tercih: `addStaff`'in `POST /users` yanıtındaki `id`'yi de döndürmesi. `res.data!['id']` mevcut. `addStaff` dönüşünü `({String? tempCode, String id})` yap ve `staff_screen` çağrısını uyarlayın.)

Listede satır `leading`'ine avatar ekle (`_StaffTile`/`ListTile`):

```dart
leading: CircleAvatar(
  backgroundImage:
      member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
  child: member.avatarUrl == null ? const Icon(Icons.person_outline) : null,
),
```

- [ ] **Step 6: profile_screen.dart — avatar kartı görünürlüğü**

`_AvatarCard` görünürlük koşulunu değiştir:

```dart
// Self-servis profil fotografi YALNIZ yonetici + site sakini (spec P3).
// admin/guvenlik/tesis gorevlisi'nde gizli (saha personeli fotosunu yonetici
// StaffScreen'den yonetir).
if (UserRole.fromClaim(profile.role) == UserRole.yonetici ||
    UserRole.fromClaim(profile.role) == UserRole.resident) ...[
  const _AvatarCard(),
  const SizedBox(height: 16),
],
```

- [ ] **Step 7: staff_screen_test — listede avatar + foto butonu**

`mobile/test/staff_screen_test.dart` (varsa mevcut override'a `avatar_url` ekle; yoksa yeni). `fieldStaffProvider` override ile avatarUrl'lü bir personel ver; ekle sheet'inde 'Fotoğraf' butonunu bekle. NetworkImage testte ağa çıkarsa `shift_status_card_test.dart`'taki `_PngHttpClient` + `HttpOverrides.runZoned` desenini kullan (avatarlı satır render'ında). Minimum:

```dart
testWidgets('personel listesinde avatarli satir cizilir', (tester) async {
  await HttpOverrides.runZoned(() async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        fieldStaffProvider.overrideWith((ref) async => const [
              StaffMember(
                  id: 'u1', ad: 'Guard A', role: 'security',
                  isActive: true, avatarUrl: 'https://x/a.jpg'),
            ]),
      ],
      child: const MaterialApp(home: StaffScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Guard A'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsWidgets);
  }, createHttpClient: (c) => _PngHttpClient());
});
```
(`_PngHttpClient` + `_transparentPng` `shift_status_card_test.dart`'tan kopyalanır — testte NetworkImage 400 hatasını önler; `import 'dart:io'`, `dart:async`, `dart:convert` ekle.)

- [ ] **Step 8: Tüm suite + analiz** — `cd mobile && flutter analyze && flutter test` yeşil (staff + profil + avatar testleri dahil).

- [ ] **Step 9: Commit**

```bash
git add mobile/lib/src/features/staff mobile/lib/src/features/profile/presentation/profile_screen.dart mobile/test/staff_api_test.dart mobile/test/staff_screen_test.dart
git commit -m "feat(mobile/staff): yonetici saha personeli fotosu yukler + listede avatar; profil avatari yonetici/resident (P2/P3)"
```

---

### Task 4: Uçtan uca doğrulama + kapanış

**Files:** —

- [ ] **Step 1: Backend ilgili suite** — `docker compose exec -T api sh -c "pytest -q tests/test_users_avatar.py tests/test_avatar.py tests/test_shift_assignments.py tests/test_yonetici_iletisim.py 2>&1 | tail -6"` PASS.
- [ ] **Step 2: Mobil TAM suite + analiz** — `cd mobile && flutter analyze && flutter test` (586+ yeşil; `scan_outbox_test` paralel-flake bilinen istisna — izole koşumda geçmeli).
- [ ] **Step 3: Push** — kullanıcı isterse `git push origin main`.
