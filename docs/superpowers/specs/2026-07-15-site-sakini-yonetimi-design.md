# Site Sakini yönetimi (yönetici) — Tasarım

Tarih: 2026-07-15 · Kapsam: backend + contracts + mobil · Branch: main

## Amaç

Site sakini KENDİ kayıt olamaz; site yöneticisi ekler/çıkarır (yeni taşınan →
ekle, ayrılan → çıkar). Feature 3'teki "Saha Personeli" ekranının SAKIN karşılığı.

## Kararlar (onaylandı)

- Ayrı "Site Sakinleri" ekranı (Saha Personeli yanında ikinci menü girişi).
- "Çıkar" = aktif daire bağını bitir **+ hesabı pasifleştir** (giriş yapamaz).
- Ekleme: Ad + Cep telefonu + Daire no → `POST /residents` → geçici kod.
- Liste: ad + daire no + durum (telefon KVKK gereği listede yok).
- Menü: yalnız yönetici (admin panelden yönetir — personel deseniyle aynı).

## Backend — `/residents` router (yönetici + admin, `_YONETIM`)

- **`GET /residents`** → `ResidentListResponse { items: [ResidentListItem] }`.
  `ResidentListItem { user_id, ad, unit_no, is_active }`. role=resident kullanicilar;
  `unit_no` aktif (`bitis IS NULL`) `unit_resident`+`unit` bağından türetilir
  (birden çok aktif daire varsa virgülle birleştirilir; yoksa null). RLS ile
  tenant-kapsamlı. Telefon DÖNMEZ.
- **`DELETE /residents/{user_id}`** → 204. Sakini "siteden çıkar": aktif
  `unit_resident` bağlarını `bitis=now()` yapar + `app_user.is_active=false`.
  Idempotent. Kullanıcı tenant'ta role=resident değilse → 404 (varlık sızmaz).
- **`POST /residents`** (mevcut) — değişmez.

Şemalar (`app/schemas.py`): `ResidentListItem`, `ResidentListResponse`.

## Contracts
- `auth.md` §4 matris: `GET /residents` + `DELETE /residents/{id}` (admin ✅,
  yönetici ✅; diğerleri ❌) + kısa not.
- `openapi.yaml`: iki uç + `ResidentListItem` / `ResidentListResponse`.

## Mobil (Flutter)
- `features/residents/`:
  - `data/residents_api.dart` — `ResidentMember { userId, ad, unitNo, isActive }`;
    `getResidents()`, `addResident({ad, telefon, unitNo, password?}) -> tempCode?`,
    `removeResident(userId)`; `residentsProvider` (FutureProvider).
  - `presentation/residents_screen.dart` — liste (ad + daire no + Aktif/Pasif);
    FAB "Sakin ekle" → alt sayfa (Ad, Cep telefonu, Daire no, opsiyonel parola) →
    geçici kod dialog; aktif sakinde "Çıkar" (onay → DELETE → invalidate).
- `home_menu.dart`: yeni `sakinler` enum + yönetici menüsüne (personel yakınına).
- `home_screen.dart`: `sakinler` tile (ikon Icons.people_alt_outlined,
  "Site Sakinleri", rota `/sakinler`). Router `AppRoutes.sakinler`.

## Test
- `backend/tests/test_residents.py`:
  - `POST /residents` (yönetici) → 201 + temp_code + unit oluşur.
  - `GET /residents` (yönetici) → eklenen sakin ad + unit_no ile listelenir; telefon yok.
  - `DELETE /residents/{id}` (yönetici) → 204; sonra o telefonla `login-phone` **401**
    (pasif); tekrar DELETE idempotent (404 değil — zaten pasif; ya da 204).
  - RBAC: security/tesis_gorevlisi/resident → 403 (GET+DELETE); admin ✅.
- `flutter analyze` temiz; `home_menu_test` yönetici listesi güncellenir.

## Kabul
Yönetici sakinleri listeler/ekler/çıkarır; çıkarılan giriş yapamaz; sakin kendi
kayıt olamaz; testler + analyze yeşil.
