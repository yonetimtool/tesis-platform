# SOS kaldırma + Yönetici İletişim + çoklu yönetici + tesis adlandırma

Tarih: 2026-07-16 · Kapsam: migration + backend + contracts + mobil + admin-web + seed · Branch: main

Dört ürün değişikliği. Hepsi tek migration (kanonik 0001 yerinde düzenlenir, `down -v`).

---

## Keşif bulguları (tasarımı şekillendiren mevcut durum)

Bu bölüm, spec'in neden istenen metinden yer yer ayrıldığını açıklar.

1. **Değişiklik 4'ün çekirdeği ZATEN VAR.** 2026-07-15 onboarding işi `tenant.kurulum_tamamlandi`
   + `HomeGate` + `SetupTenantScreen` + `POST /tenant/setup` (ikinci çağrı 409) ile yöneticinin
   ilk girişte tesisi adlandırmasını halihazırda zorluyor. **Karar: yeni `ad_onaylandi` bayrağı
   EKLENMEZ** — iki bayrak çelişebilir. Değişiklik 4 şuna daralır: (a) kapıyı YALNIZ birincil
   yöneticiye kısıtla, (b) mobil yeniden adlandırma ekranı ekle.
2. **Uygulamada hiçbir yerde bottom tab bar YOK.** Tüm roller aynı `HomeScreen` 2-sütunlu ikon
   ızgarasını görür (`homeMenuForRole()`). Değişiklik 2 bu yüzden menü girişi olarak iner.
3. **`TenantSettings` şu an `emergency_models.dart` içinde yaşıyor.** `features/emergency/`
   doğrudan silinirse tesis adı her yerde kırılır → önce taşınmalı.
4. **Tekil yönetici varsayımı üç yerde gömülü:** `tenant_detail`, `PATCH /tenants/{id}/yonetici`,
   `reset_yonetici_credential` — hepsi `ORDER BY created_at ASC LIMIT 1`.
5. **Bireysel kullanıcı silme ucu YOK.** Yalnız `DELETE /tenants/{id}` (tüm tenant, cascade) ve
   daire-sakin bağı kaldırma var. Yönetici yalnızca pasifleştirilebilir (`is_active=false`).
   → "birincil silinirse terfi ettir" senaryosu **ulaşılamaz**; ölü kod yazılmaz, invaryant
   dokümante edilir.
6. **Kod üretimi yok.** Şekil değişikliği elle 5 yerde: migration → `models.py` → `schemas.py` →
   `openapi.yaml` → `admin-web/lib/types.ts`.
7. **`slug` değişmezliği yapısal olarak garanti.** `update_tenant_ad` yalnız `ad` +
   `kurulum_tamamlandi` yazar; `slug`a dokunmaz. `POST /tenant/setup` de dokunmaz.

## Onaylanan kararlar

| Karar | Seçim |
|---|---|
| Adlandırma bayrağı | Mevcut `kurulum_tamamlandi` yeniden kullanılır; `ad_onaylandi` eklenmez |
| `acil_durum_telefon` | SOS ile birlikte SİLİNİR (yerini Yönetici İletişim sekmesi alır) |
| Yönetici başına e-posta | ALINMAZ — satırlar `ad` / `telefon` / `parola` (giriş anahtarı telefon; e-posta hiçbir yerde okunmuyordu) |
| `aranabilir` vs iletişim sekmesi | Sekme `aranabilir`ı YOKSAYAR (hizmet-rolü dizini); yine de kayıtta `true` set edilir ki `/call-target` çalışsın |
| Adlandırma ön-doldurma | Admin oluştururken opsiyonel "Tesis adı" girebilir → birincil onaylar; boşsa placeholder + boş alan |
| Birincil yaşam döngüsü | Tam olarak bir birincil (partial unique index); pasifleştirme terfi ETTİRMEZ; silme ucu yok |
| Dış istemci | Yok → `POST /tenants` yanıtı kırıcı değişebilir |
| Birincil olmayan yönetici, tesis adsızken | **Engelleyici ekran YOK** — normal ana ekranı görür, app-bar'da `(Kurulum bekliyor)` yazar |

---

## Değişiklik 1 — SOS/acil durum tamamen kaldırılır

### Ön koşul (kırılmayı önler)
`TenantSettings` sınıfı `mobile/lib/src/features/emergency/domain/emergency_models.dart`'tan yeni
`mobile/lib/src/features/tenant/domain/tenant_models.dart`'a TAŞINIR; `acilDurumTelefon` alanı
düşürülür. `tenant_api.dart` importu güncellenir. **Ancak bundan sonra** `features/emergency/` silinir.

### Migration (0001, yerinde)
- `notification_tip` enum'undan `'acil_durum'` değeri çıkar (L69-73). PostgreSQL enum'dan değer
  DÜŞÜREMEZ; sorun değil çünkü 0001 yerinde düzenleniyor ve şema `down -v` ile sıfırdan
  kuruluyor (migration zinciri yok, tek kanonik dosya).
- `CREATE TYPE emergency_durum` silinir (L84-85) + downgrade `DROP TYPE` (L1990)
- `tenant.acil_durum_telefon text` kolonu silinir (L156-157)
- tenant-purge fonksiyonundaki `DELETE FROM emergency_alert` satırı silinir (L514)
- `CREATE TABLE emergency_alert` (L964-991) + 3 index (`ix_emergency_tenant`, `ix_emergency_durum`,
  `ix_emergency_zaman`) silinir
- RLS enable döngüsünden `"emergency_alert"` çıkar (L1858); downgrade drop döngüsünden çıkar (L1958)
- L1392/L1436'daki `notlar` isimlendirme yorumları emergency'ye atıf yapmayacak şekilde düzeltilir

### Backend
- `app/routers/emergency.py` → SİL; `main.py` L26 import + L102 `include_router` → SİL
- `models.py`: `EmergencyAlert` (L660-698), `EMERGENCY_DURUM` (L66-69), `Tenant.acil_durum_telefon`
  (L161-162), `__all__` girişleri (L1547/L1569), `notification.tip` tuple'ından `"acil_durum"` (L55)
- `schemas.py`: `EmergencyDurum`/`EmergencyCreate`/`EmergencyResolve`/`EmergencyAlertOut`/
  `EmergencyListResponse` (L1521-1553); `AlarmTip`'ten `"acil_durum"` (L518); TenantSettings
  out/update'ten `acil_durum_telefon` (L1564/L1570)
- `routers/tenant.py`: `_to_settings`'ten `acil_durum_telefon` maplemesi (L31)
- `routers/dashboard.py`: `son_alarmlar` içindeki `'acil_durum'` ve
  `ORDER BY (tip = 'acil_durum') DESC, created_at DESC` → düz `ORDER BY created_at DESC` (L59-61)
- `scheduler/notify.py` L84 docstring atfı temizlenir

### Contracts
- `openapi.yaml`: `/emergency` GET+POST (L2543-2604), `/emergency/{id}` PATCH (L2606-2625);
  `EmergencyDurum`/`EmergencyAlert`/`EmergencyCreate`/`EmergencyResolve` şemaları (L6228-6258);
  `AlarmTip`'ten `acil_durum` (L5332); TenantSettings + update'ten `acil_durum_telefon`
  (L6270-6273, L6282); `/tenant/settings` açıklaması (L2775-2776)
- `auth.md`: matris satırları `POST/GET/PATCH /emergency` (L302-304); yonetici paragrafından
  "acil durumu tetikler/yonetir" (L430); resident paragrafından panik butonu cümlesi (L445-446)
- `README.md`: `emergency_alert` tablo açıklaması + uçlar (L105-108), yönetim numarası (L109-110),
  yonetici persona atfı (L122), push fan-out (L193), uç listesi (L299)

### Mobil
- `features/emergency/` dizini tamamen silinir (TenantSettings taşındıktan SONRA)
- `routing/app_router.dart`: L21 import, L56 `AppRoutes.emergency`, L194-195 `GoRoute`
- `features/home/domain/home_menu.dart`: `HomeMenuEntry.emergency` (L9-10) + **5 rolün 5'inden de**
  giriş (admin L136, security L157, tesisGorevlisi L177, yonetici L192, resident L217)
- `features/home/presentation/home_screen.dart`: L19 doc, L31-33 ızgaradan ayırma, L112-142 kırmızı
  tam-genişlik banner, L207-212 fallback tile
- `features/auth/domain/user_role.dart`: `canTriggerEmergency` (L52-55) — **ölü kod**, hiçbir yerde
  çağrılmıyor
- `features/push/domain/push_models.dart` L25 yorumundaki `acil_durum` örneği

### Admin-web
- `app/(protected)/emergency/page.tsx`, `app/api/emergency/route.ts`,
  `app/api/emergency/[id]/route.ts` → SİL
- `components/Nav.tsx` L23 nav girişi; `middleware.ts` L35 matcher
- `lib/types.ts`: AlarmTip'ten `"acil_durum"` (L8), `EmergencyDurum`/`EmergencyAlert`/`EmergencyList`
  (L409-426), `acil_durum_telefon` (L460)
- `app/(protected)/dashboard/page.tsx` L23-33 kırmızı/öncelik stili + "ACİL DURUM" etiketi
- `app/(protected)/settings/page.tsx` L30/L49/L94-95 `acil_durum_telefon` alanı
- `README.md` L94 dashboard sıralama notu

### Seed
`backend/scripts/seed.py`: `TENANT["acil_durum_telefon"]` (L41) + INSERT/ON CONFLICT'teki kolon (L104-111)

### Testler (silinen)
- `backend/tests/test_emergency.py` → SİL (tamamı)
- `backend/tests/test_push.py` L224-236 emergency bloğu
- `backend/tests/test_yonetici.py` L141-155 + L173 emergency/acil_durum_telefon blokları
- `mobile/test/emergency_models_test.dart` → SİL (TenantSettings testleri varsa
  `tenant_models_test.dart`'a taşınır)
- `mobile/test/home_menu_test.dart` L10/L25/L82/L98/L223 + L445-455 ("5 rolün 5'inde de var")
- `mobile/test/user_role_test.dart` L39-44 `canTriggerEmergency`

### Dokümanlar
`backend/README.md` L174-188 §; `mobile/README.md` L629/L632 rol menü tabloları + L911-977 §12 +
L1165; `docs/CIHAZ-TESTI.md` L135-137, L221-225, L307-315 (S6 senaryosu), L364, L429, L468, L511.

> Not: `mobile/README.md` L914/L973 zaten BAYAT (resident'ın 403 olduğunu söylüyor, gerçekte
> gönderebiliyor). SOS ile birlikte silineceği için ayrıca düzeltilmez.

### Yeni test
`test_sos_kaldirildi.py`: `POST/GET /emergency` + `PATCH /emergency/{id}` → **404**.

---

## Değişiklik 2 — "Yönetici İletişim"

### Migration
`tenant.yonetim_email text` (nullable, serbest metin e-posta; anlamsal kısıt yok).

### Backend — `GET /yonetici-iletisim`
- **RBAC:** tenant'ın HERHANGİ bir kimliklenmiş üyesi (5 rol de). Rol kapısı yok — tenant izolasyonu
  RLS ile.
- **Yanıt:** `YoneticiIletisimOut { yoneticiler: [{user_id, ad_soyad, telefon}], yonetim_email }`
- Yalnız `role='yonetici' AND is_active=true`; **sıralama: birincil önce**, sonra `created_at ASC`
- **`aranabilir` YOKSAYILIR** (bilinçli gizlilik istisnası)
- Yeni router `app/routers/yonetici_iletisim.py` + `main.py` include

### Gizlilik istisnası — auth.md'ye yazılır
C1a'nın üç kapısı (YÖN + RIZA + NUMARA VARLIĞI) ve "listede numara YOK" kuralı, yönetici iletişim
kartı için **bilinçli olarak** delinir:
- **Gerekçe:** yönetici bir HİZMET rolüdür; numarayı admin bilerek girer; sahadaki personelin ve
  sakinin yönetime ulaşabilmesi ürün gereğidir.
- **Kapsam:** YALNIZ `GET /yonetici-iletisim`, YALNIZ `role='yonetici'` kullanıcılar için.
- C1a modeli **başka her şey için aynen korunur** (`/call-target` üç kapılı kalır; `GET /users`
  numara taşımaz; `PATCH /me/contact` rızası geçerliliğini sürdürür).
- Yöneticiler için kayıtta `aranabilir=true` set edilir → `/call-target` de tutarlı çalışır.

### Contracts
`openapi.yaml`: `/yonetici-iletisim` path + `YoneticiIletisimOut`/`YoneticiKart` şemaları;
`TenantSettings`e `yonetim_email`. `auth.md` matrisine satır + istisna notu.

### Mobil
- `HomeMenuEntry.yoneticiIletisim` — `security`, `tesisGorevlisi`, `resident` listelerinin **EN
  SONUNA**. `yonetici`'ye ve `admin`'e **eklenmez**.
- `features/yonetici_iletisim/`: `domain/yonetici_iletisim_models.dart`,
  `data/yonetici_iletisim_api.dart`, `presentation/yonetici_iletisim_screen.dart`
- `AppRoutes.yoneticiIletisim = '/yonetici-iletisim'` + GoRoute
- **Ekran:** yönetici kartları (ad-soyad + telefon METNİ + "Yöneticiyi Ara" `FilledButton.icon`),
  altında yönetim maili kartı (boşsa gizlenir).
- **Arama:** `ref.read(callLauncherProvider).dial('tel:$telefon')` — mevcut `CallLauncher`
  yeniden kullanılır. **`CallButton` KULLANILMAZ:** o `/call-target`'a çözümler ve numarayı
  kasten göstermez; buradaki kart numarayı gösteriyor. Paylaşılan parça `CallLauncher`'dır →
  tel: mantığı kopyalanmaz.

---

## Değişiklik 3 — Web tenant-create: yönetim maili + N yönetici

### Migration
- `app_user.birincil boolean NOT NULL DEFAULT false`
- `CREATE UNIQUE INDEX uq_app_user_birincil ON app_user (tenant_id) WHERE birincil;`
  → tenant başına **en fazla bir** birincil, yapısal garanti
- `create_tenant_with_yonetici` (9 parametreli) → **DROP**; yerine:
  ```sql
  create_tenant_with_yoneticis(
      p_ad text, p_slug text, p_timezone text, p_kurulum boolean,
      p_yonetim_email text, p_yoneticiler jsonb
  ) RETURNS TABLE (tenant_id uuid, user_id uuid, sira int)
  ```
  `p_yoneticiler` = `[{ad, telefon, password_hash, temp_code_hash, password_set}, ...]`;
  **ilk eleman `birincil=true`**, hepsi `role='yonetici'`, `aranabilir=true`, `is_active=true`.
  SECURITY DEFINER + `REVOKE ALL` + `GRANT EXECUTE TO app_rw` (mevcut desen).
- `tenant_detail`: `role='yonetici' ORDER BY created_at ASC LIMIT 1` → `WHERE birincil` (tekil
  admin uçları birincile bakmaya devam eder).

### Backend — `POST /tenants` (kırıcı değişiklik; dış istemci yok)
```python
class YoneticiCreate(BaseModel):
    ad: str = Field(..., min_length=2, max_length=120)
    phone: str = Field(..., min_length=1)
    password: str | None = Field(None, min_length=8)

class TenantAdminCreate(BaseModel):
    ad: str | None = Field(None, min_length=2, max_length=160)   # YENİ, opsiyonel
    yonetim_email: str | None = None                              # YENİ, opsiyonel
    yoneticiler: list[YoneticiCreate] = Field(..., min_length=1)  # en az bir

class YoneticiCreatedOut(BaseModel):
    user_id: uuid.UUID
    ad: str
    birincil: bool
    temp_code: str | None

class TenantAdminCreatedOut(BaseModel):
    tenant_id: uuid.UUID
    yoneticiler: list[YoneticiCreatedOut]
```
- **`ad` verilirse:** `tenant.ad = ad`, `slug = slugify_tenant(ad)`, `kurulum_tamamlandi=false`
  (birincil yine ONAYLAR). Verilmezse mevcut davranış: `_PLACEHOLDER_AD` + rastgele slug.
- Her yönetici için ayrı ayrı parola-veya-geçici-kod (mevcut mantık satır bazında).
- **Payload içi telefon tekrarı → 422** (`validation_error`); DB'de global çakışma → 409
  ("Bu telefon zaten kayitli."). Tek transaction → kısmi tenant oluşmaz.
- `yonetim_email` boş string → `None` normalize edilir.

### Admin-web (`app/(protected)/tenants/page.tsx`)
- Yeni opsiyonel alanlar: **"Tesis adı (opsiyonel)"**, **"Yönetim maili (opsiyonel)"**
- `FormState.yoneticiler: {ad, phone, password}[]` — **"Yönetici ekle"** butonu satır ekler;
  ilk satır **"Birincil yönetici"** rozetiyle işaretlenir ve **silinemez**; diğerlerinde "Kaldır".
- Mevcut statik metin ("Tesis adı burada girilmez…") güncellenir.
- Geçici kodlar: tek `window.alert` yerine **yönetici adı → kod** listesi gösterilir.
- `lib/types.ts`: `TenantAdminCreate`/`CreatedOut` şekilleri + `yonetim_email` +
  eksik `kurulum_tamamlandi` (mevcut bayat alan) eklenir.

---

## Değişiklik 4 — Tesis görünen adı: birincil yönetici

### Backend
- `GET /me/profile` yanıtına **`birincil: bool`** eklenir (mobil kapı bunu okur; JWT claim'i
  değiştirmiyoruz — token şeması sabit kalır).
- **`POST /tenant/setup` artık YALNIZ birincil yöneticiye açık** — birincil olmayan yönetici
  çağırırsa **403**. (Kapı yalnız birincile gösteriliyor; uç da eşleşmeli, aksi halde istemci
  tarafı bir kısıt olarak kalırdı.) Zaten kuruluysa 409 davranışı korunur.
- **İki uç `tenant.ad` yazar — bilinçli:** `POST /tenant/setup` tek-seferlik kurulum kapısıdır
  (`kurulum_tamamlandi=false` iken, birincil, 409 ile korunur); `PATCH /tenant/settings {ad}`
  ise kurulum sonrası sürekli yeniden adlandırmadır (tüm yöneticiler). İkisi de tenant-kapsamlı
  RLS oturumunda **ORM ile `t.ad`** yazar (`update_tenant_ad` SECURITY DEFINER fonksiyonu
  admin'in cross-tenant `PATCH /tenants/{id}` ucuna aittir; bu uçlar onu kullanmaz).
  Hiçbiri `slug`a dokunmaz → değişmezlik üç uçta da korunur.
- `PATCH /tenant/settings` RBAC genişler:
  - `admin`: `ad`, `timezone`, `yonetim_email`
  - `yonetici`: **YALNIZ `ad`** — başka alan gönderirse **403** (`forbidden`)
  - diğer roller: 403 (mevcut)
  - `ad` yazımı `update_tenant_ad` üzerinden → **`slug` DEĞİŞMEZ**, `kurulum_tamamlandi=true` olur
- `GET /tenant/settings` yanıtına `yonetim_email` eklenir; `acil_durum_telefon` çıkar (Değişiklik 1).

### Mobil
- `home_gate.dart`: koşul `role == yonetici && !kurulumTamamlandi` →
  **`role == yonetici && profile.birincil && !kurulumTamamlandi`**.
  Profil `FutureProvider` ile okunur; hata → **fail-open** (mevcut desen; kullanıcı kilitlenmez).
- `SetupTenantScreen`: alan `tenant.ad` ile **ön-doldurulur** — ancak `ad != '(Kurulum bekliyor)'`
  ise (placeholder asla kullanıcıya gösterilmez, o durumda alan boş).
- `settings_screen.dart`: **yalnız `yonetici`** rolüne "Tesis" bölümü + "Tesis adı" alanı + Kaydet
  → `PATCH /tenant/settings {ad}` → `ref.invalidate(tenantSettingsProvider)` → ana ekran app-bar'ı
  güncellenir.
- **Birincil olmayan yönetici, tesis adsızken:** engelleyici ekran YOK; normal ana ekran, app-bar'da
  placeholder. (Bilinçli karar — kapı yalnız birincile ait.)

### Adın her yerde yansıması
- Mobil: `tenantSettingsProvider` → `home_screen` app-bar başlığı (tek gösterim yeri).
- Admin-web: `tenant.ad` üç yerde SWR ile okunuyor (`tenants/page.tsx` listesi,
  `tenants/[id]/page.tsx` başlığı, `settings/page.tsx`) → **doğrulandı, ek iş gerekmez**;
  SWR yalnız bellek-içi cache, `mutate()` ile tazeleniyor.
- **`slug` ve tenant `id` ASLA değişmez** — `update_tenant_ad` yalnız `ad`+`kurulum_tamamlandi`
  yazar; giriş/slug akışları (`tenant_id_by_slug`, `tenant_id_by_phone`) dokunulmaz.

---

## Seed (`backend/scripts/seed.py`)
- `TENANT["yonetim_email"] = "yonetim@acme.com"`; `acil_durum_telefon` çıkar; INSERT/ON CONFLICT
  buna göre.
- Mevcut yönetici (`Acme Yonetici`, `+905321112201`, `aranabilir=True`) → **`birincil=True`**.
- **İkinci yönetici eklenir** (çoklu listeyi göstermek için):
  `Acme Yonetici 2`, `yonetici2@acme.com`, **`+905321112206`**, `aranabilir=True`, `birincil=False`.
  > `telefon` GLOBAL benzersiz (`uq_app_user_telefon`). Seed'de 201-205 zaten dolu
  > (201 yönetici, 202 guard, 203 sakin, **204 cleaner**, 205 sakin-3) → yeni numara **206**.
- `app_user` upsert'ü `birincil` kolonunu taşır.

---

## Testler

**Backend (`backend/tests/`)** — canlı sunucuya vuran mevcut desen (`client` fixture, `world`):
- `test_sos_kaldirildi.py` (YENİ): `/emergency` GET/POST/PATCH → 404.
- `test_yonetici_iletisim.py` (YENİ):
  - `security` / `tesis_gorevlisi` / `resident` → 200, tüm aktif yöneticiler + `yonetim_email`
  - **birincil listede İLK**
  - `aranabilir=false` yapılan yönetici **yine de** numarasıyla listelenir (istisna doğrulaması)
  - `is_active=false` yönetici listelenmez
  - **tenant izolasyonu:** A tenant'ı B'nin yöneticilerini görmez
  - kimliksiz → 401
- `test_tenants.py` (GÜNCELLE):
  - N yönetici oluşturma → hepsi `role=yonetici`, **tam biri `birincil`**, her birine temp_code
  - `ad` verilerek oluşturma → `tenant.ad` set + `kurulum_tamamlandi=false`
  - `ad` verilmeden → placeholder
  - payload içi telefon tekrarı → 422; mevcut telefon → 409 (+ tenant oluşmadı)
  - `yoneticiler: []` → 422
- `test_tenant_ad.py` (YENİ):
  - birincil yönetici `PATCH /tenant/settings {ad}` → 200, **slug DEĞİŞMEDİ** (DB'den doğrula)
  - yönetici `timezone` göndermeye çalışır → 403
  - `security`/`resident` → 403
  - ad değişimi sonrası `GET /tenant/settings` yeni adı döner
- `test_first_login_setup.py` (YENİ): birincil → `kurulum_tamamlandi=false` görür; ikinci
  `POST /tenant/setup` → 409; **birincil olmayan yöneticinin `/me/profile`'ı `birincil=false`**;
  **birincil olmayan yönetici `POST /tenant/setup` → 403**.

**Mobil (`mobile/test/`)**
- `home_menu_test.dart`: `emergency` girişi 5 rolde de YOK; `yoneticiIletisim` yalnız security/
  tesisGorevlisi/resident'te ve **listenin sonunda**; yonetici/admin'de yok.
- `yonetici_iletisim_test.dart` (YENİ): "Yöneticiyi Ara" → fake `CallLauncher`'a
  `tel:+90...` gider (mevcut `call_button_test.dart` fake deseni).
- `tenant_models_test.dart` (YENİ): `TenantSettings.fromJson` (+ `yonetim_email`,
  `acil_durum_telefon` yok).
- `user_role_test.dart`: `canTriggerEmergency` testleri silinir.

## Kabul kriterleri
`down -v && up --build && seed && pytest` yeşil · `flutter analyze` + `flutter test` +
`flutter build apk --debug` · `admin-web build`. SOS hiçbir katmanda kalmadı · iletişim sekmesi üç
rolde arama butonuyla çalışıyor · tenant-create mail + N yönetici alıyor · birincil tesisi bir kez
adlandırıyor ve ayarlardan değiştirebiliyor · **slug/ID değişmedi**.

> Bilinen kırılganlık: `test_rezervasyon` saat-bağımlı flake (21:xx'te gece-yarısı sarması) —
> bu işle ilgisiz.
