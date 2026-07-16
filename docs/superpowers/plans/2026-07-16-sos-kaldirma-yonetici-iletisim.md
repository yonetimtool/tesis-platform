# SOS kaldırma + Yönetici İletişim + çoklu yönetici + tesis adlandırma — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SOS/acil-durum özelliğini uçtan uca kaldır; üç saha rolüne yönetici iletişim dizini ekle; tenant oluşturmayı N yönetici + yönetim maili alacak şekilde genişlet; tesis adını birincil yöneticiye adlandırt/değiştirt.

**Architecture:** Kanonik `0001_initial_schema.py` YERİNDE düzenlenir (migration zinciri yok; şema `down -v` ile sıfırdan kurulur). Backend FastAPI + SQLAlchemy (RLS'li tenant-kapsamlı oturum; cross-tenant işler SECURITY DEFINER fonksiyonlarla). Mobil Flutter + Riverpod + go_router (tab bar yok — rol-bazlı ikon ızgarası). Admin-web Next.js + SWR (BFF proxy route'ları).

**Tech Stack:** Python 3 / FastAPI / SQLAlchemy / Alembic (tek kanonik revizyon) / PostgreSQL (RLS) · Flutter / Riverpod / go_router / dio · Next.js / SWR · pytest (canlı sunucuya vurur) · Docker Compose.

## Global Constraints

Bu bölüm HER task'ın gereksinimlerine örtük olarak dahildir.

- **Yalnız `main`.** Branch YOK, PR YOK, `gh` komutu YOK, CI YOK. Doğrudan main'e commit.
- **Kanonik migration yerinde düzenlenir:** `contracts/db/migrations/versions/0001_initial_schema.py`. Yeni revizyon dosyası OLUŞTURULMAZ. Şema değişimi `down -v` ile test edilir.
- **Kod üretimi YOK.** Şema değişikliği elle 5 yerde yansıtılır: migration → `backend/app/models.py` → `backend/app/schemas.py` → `contracts/openapi.yaml` → `admin-web/lib/types.ts`. `models.py` yalnız AYNADIR; ondan migration üretilmez (`autogenerate` çalıştırılmaz).
- **Backend Docker image kodu BAKE eder (mount yok).** `pytest`/`seed` backend değişikliğini görsün diye önce `api`/`seed` image'ları yeniden derlenmeli. Tam döngü:
  ```bash
  cd /home/kerem/tesis-platform/infra
  docker compose down -v
  docker compose up -d --build
  docker compose --profile seed run --rm seed
  cd /home/kerem/tesis-platform/backend && python -m pytest -q
  ```
- **Testler CANLI sunucuya vurur** (`client` fixture = `httpx` → `http://localhost:8000`). Monkeypatch YOK. Sunucu erişilemezse testler `skip` olur — "skipped" ASLA "passed" sayılmaz.
- **`telefon` GLOBAL benzersizdir** (`uq_app_user_telefon ... WHERE telefon IS NOT NULL`) — tenant içi değil. Seed'de 201-205 dolu.
- **Tenant izolasyonu RLS ile:** tenant-kapsamlı uçlar `get_tenant_db` kullanır; cross-tenant admin işleri SECURITY DEFINER fonksiyon + `REVOKE ALL` + `GRANT EXECUTE TO app_rw` desenini izler.
- **`slug` ve tenant `id` ASLA değişmez.** Hiçbir task bunlara yazmaz.
- **Türkçe, ASCII-güvenli kod yorumları** (mevcut kod deseni: yorumlarda `ı/ş/ğ` yok; kullanıcıya görünen metinlerde tam Türkçe var).
- **Commit mesajları Türkçe**, mevcut desen: `feat(kapsam): ...` / `fix(kapsam): ...` / `docs(kapsam): ...`. Her commit'in sonuna:
  ```
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_019PQv4ATndrTUEpBNWypYmS
  ```
- **Bilinen flake:** `test_rezervasyon` 21:xx'te gece-yarısı sarmasından 422 verir — bu işle ilgisiz, kod değişikliğine bağlı değil.

## File Structure

**Yeni dosyalar**
| Dosya | Sorumluluk |
|---|---|
| `mobile/lib/src/features/tenant/domain/tenant_models.dart` | `TenantSettings` (emergency'den taşınır) |
| `mobile/lib/src/features/call/domain/tel_uri.dart` | `telUri()` yardımcısı (emergency'den taşınır) — tel: mantığının TEK yeri |
| `backend/app/routers/yonetici_iletisim.py` | `GET /yonetici-iletisim` |
| `mobile/lib/src/features/yonetici_iletisim/domain/yonetici_iletisim_models.dart` | `YoneticiKart`, `YoneticiIletisim` |
| `mobile/lib/src/features/yonetici_iletisim/data/yonetici_iletisim_api.dart` | HTTP + provider |
| `mobile/lib/src/features/yonetici_iletisim/presentation/yonetici_iletisim_screen.dart` | Kart listesi + arama butonu |
| `backend/tests/test_sos_kaldirildi.py` | SOS uçları 404 |
| `backend/tests/test_yonetici_iletisim.py` | Dizin + izolasyon + istisna |
| `backend/tests/test_tenant_ad.py` | Yeniden adlandırma + slug değişmezliği |
| `mobile/test/tenant_models_test.dart` | `TenantSettings.fromJson` |
| `mobile/test/yonetici_iletisim_test.dart` | Arama butonu → fake launcher |

**Silinen dosyalar**
`backend/app/routers/emergency.py` · `backend/tests/test_emergency.py` · `mobile/lib/src/features/emergency/**` (3 dosya) · `mobile/test/emergency_models_test.dart` · `admin-web/app/(protected)/emergency/page.tsx` · `admin-web/app/api/emergency/route.ts` · `admin-web/app/api/emergency/[id]/route.ts`

**Sıra mantığı:** Task 1 (taşıma) Task 5'ten (silme) ÖNCE olmalı — yoksa tesis adı kırılır. Task 6 (migration) Task 7-10'dan önce. SOS kaldırma (1-5) yeni özelliklerden (6-13) önce ki `down -v` tek seferde temiz şema kursun.

---

### Task 1: Mobil — `TenantSettings` + `telUri` emergency'den çıkarılır

Davranış değişikliği YOK; yalnız taşıma. Bu, Task 5'in `features/emergency/` dizinini silebilmesinin ön koşulu.

**Files:**
- Create: `mobile/lib/src/features/tenant/domain/tenant_models.dart`
- Create: `mobile/lib/src/features/call/domain/tel_uri.dart`
- Modify: `mobile/lib/src/features/tenant/data/tenant_api.dart:7` (import)
- Modify: `mobile/lib/src/features/emergency/domain/emergency_models.dart` (taşınanları çıkar)
- Modify: `mobile/lib/src/features/emergency/presentation/emergency_controller.dart` (import düzelt)
- Modify: `mobile/lib/src/features/emergency/data/emergency_api.dart` (import düzelt)
- Create: `mobile/test/tenant_models_test.dart`

**Interfaces:**
- Produces: `class TenantSettings { final String tenantId; final String ad; final bool kurulumTamamlandi; factory TenantSettings.fromJson(Map<String,dynamic>) }` — **`acilDurumTelefon` alanı YOK** (Task 2 kolonu siliyor). `Uri? telUri(String phone)` — `features/call/domain/tel_uri.dart`.

- [ ] **Step 1: Failing test yaz**

`mobile/test/tenant_models_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_mobile/src/features/tenant/domain/tenant_models.dart';

void main() {
  test('TenantSettings.fromJson ad + kurulum_tamamlandi okur', () {
    final s = TenantSettings.fromJson({
      'tenant_id': 't1',
      'ad': 'Acme Plaza',
      'slug': 'acme-plaza',
      'timezone': 'Europe/Istanbul',
      'kurulum_tamamlandi': false,
    });
    expect(s.tenantId, 't1');
    expect(s.ad, 'Acme Plaza');
    expect(s.kurulumTamamlandi, isFalse);
  });

  test('kurulum_tamamlandi yoksa true varsayilir (eski tesisler)', () {
    final s = TenantSettings.fromJson({'tenant_id': 't1', 'ad': 'X'});
    expect(s.kurulumTamamlandi, isTrue);
  });
}
```

> `tesis_mobile` paket adını doğrula: `head -2 mobile/pubspec.yaml`. Farklıysa importu ona göre düzelt (mevcut testlerdeki importla aynı olmalı).

- [ ] **Step 2: Testi çalıştır, BAŞARISIZ olduğunu gör**

Run: `cd mobile && flutter test test/tenant_models_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../tenant/domain/tenant_models.dart'`

- [ ] **Step 3: `tenant_models.dart` oluştur**

```dart
/// Tesis (tenant) domain modelleri — `contracts/openapi.yaml` TenantSettings
/// semasina uyar.
library;

/// `GET /tenant/settings` yaniti. Mobil `ad`i ana ekran basliginda gosterir;
/// `kurulum_tamamlandi=false` ise BIRINCIL yonetici tesisi adlandirmalidir.
class TenantSettings {
  const TenantSettings({
    required this.tenantId,
    required this.ad,
    this.kurulumTamamlandi = true,
  });

  final String tenantId;
  final String ad;

  /// false ise BIRINCIL yonetici ILK GIRISTE tesisi adlandirmali (home gate).
  /// Eski/adlandirilmis tesislerde true.
  final bool kurulumTamamlandi;

  factory TenantSettings.fromJson(Map<String, dynamic> json) => TenantSettings(
        tenantId: json['tenant_id'] as String,
        ad: json['ad'] as String? ?? '',
        kurulumTamamlandi: json['kurulum_tamamlandi'] as bool? ?? true,
      );
}
```

- [ ] **Step 4: `tel_uri.dart` oluştur**

```dart
/// `tel:` URI uretimi — cihaz ceviricisine verilecek tek biçim. Arama
/// mantiginin TEK yeri (CallLauncher ile birlikte); kopyalanmaz.
library;

/// Telefon numarasini `tel:` URI'sine cevirir. Gorsel ayraclar (bosluk,
/// tire, parantez, nokta) atilir; `+` ve rakamlar kalir. Aranabilir icerik
/// yoksa null — arama butonu hic gosterilmez.
Uri? telUri(String phone) {
  final cleaned = phone.replaceAll(RegExp(r'[\s\-().]'), '');
  if (!RegExp(r'^\+?\d+$').hasMatch(cleaned)) return null;
  return Uri(scheme: 'tel', path: cleaned);
}
```

- [ ] **Step 5: `emergency_models.dart`'tan taşınanları çıkar**

`TenantSettings` sınıfını (L97-124) ve `telUri` fonksiyonunu (L126-133) SİL. Dosyanın geri kalanı (`EmergencyDraft`, `EmergencyAlert`, `EmergencySubmitResult`) kalır — Task 5 dosyayı tamamen silecek.

- [ ] **Step 6: Import'ları düzelt**

`mobile/lib/src/features/tenant/data/tenant_api.dart` L7:
```dart
// ONCE: import '../../emergency/domain/emergency_models.dart';
import '../domain/tenant_models.dart';
```
`emergency_api.dart` ve `emergency_controller.dart` `TenantSettings`/`telUri` kullanıyorsa `../../tenant/domain/tenant_models.dart` / `../../call/domain/tel_uri.dart` importu ekle. Doğrula:
```bash
cd mobile && grep -rn "TenantSettings\|telUri" lib/ | grep -v "tenant/domain\|call/domain"
```

- [ ] **Step 7: Testleri + analiz çalıştır**

Run: `cd mobile && flutter analyze && flutter test`
Expected: analyze temiz (0 issue), tüm testler PASS.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/src/features/tenant/domain/tenant_models.dart \
        mobile/lib/src/features/call/domain/tel_uri.dart \
        mobile/lib/src/features/tenant/data/tenant_api.dart \
        mobile/lib/src/features/emergency/ mobile/test/tenant_models_test.dart
git commit -m "refactor(mobil): TenantSettings + telUri emergency modulunden cikarildi

SOS kaldirilmadan ONCE: tesis adi (TenantSettings) ve tel: uretimi (telUri)
emergency_models.dart icinde yasiyordu; features/emergency silinince tesis
adi her yerde kirilirdi. TenantSettings -> tenant/domain, telUri -> call/domain
(tel: mantiginin tek yeri). Davranis degisikligi yok.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019PQv4ATndrTUEpBNWypYmS"
```

---

### Task 2: Migration + backend — SOS kaldırma

**Files:**
- Modify: `contracts/db/migrations/versions/0001_initial_schema.py` (L69-73, L84-85, L156-157, L514, L964-997, L1392, L1436, L1858, L1958, L1990)
- Delete: `backend/app/routers/emergency.py`
- Modify: `backend/app/main.py:26,102`
- Modify: `backend/app/models.py` (L55, L66-69, L161-162, L660-698, L1547, L1569)
- Modify: `backend/app/schemas.py` (L518, L1521-1553, L1564, L1570)
- Modify: `backend/app/routers/tenant.py:3,31`
- Modify: `backend/app/routers/dashboard.py:59-61`
- Modify: `backend/app/scheduler/notify.py:84`
- Delete: `backend/tests/test_emergency.py`
- Modify: `backend/tests/test_push.py:224-236`, `backend/tests/test_yonetici.py:141-155,173`
- Create: `backend/tests/test_sos_kaldirildi.py`

**Interfaces:**
- Produces: `/emergency` uçları YOK (404). `tenant.acil_durum_telefon` kolonu YOK. `notification_tip` enum'unda `acil_durum` YOK.

- [ ] **Step 1: Failing test yaz**

`backend/tests/test_sos_kaldirildi.py`:
```python
"""SOS/acil-durum ucu tamamen kaldirildi — hicbir rol icin yok.

Bu dosya bir REGRESYON kapisidir: ozellik geri sizarsa kirilir.
"""
from __future__ import annotations

import uuid


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_emergency_uclari_404(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])

    assert client.post("/emergency", json={}, headers=admin).status_code == 404
    assert client.get("/emergency", headers=admin).status_code == 404
    assert (
        client.patch(
            f"/emergency/{uuid.uuid4()}", json={"durum": "cozuldu"}, headers=admin
        ).status_code
        == 404
    )


def test_tenant_settings_acil_durum_telefon_tasimaz(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.get("/tenant/settings", headers=admin)
    assert r.status_code == 200, r.text
    assert "acil_durum_telefon" not in r.json()
```

- [ ] **Step 2: Testi çalıştır, BAŞARISIZ olduğunu gör**

Run: `cd backend && python -m pytest tests/test_sos_kaldirildi.py -q`
Expected: FAIL — `/emergency` 404 yerine 200/201/422 döner; `acil_durum_telefon` yanıtta var.
(Sunucu ayakta değilse SKIP → önce `docker compose up -d --build`.)

- [ ] **Step 3: Migration'dan SOS'u çıkar**

`contracts/db/migrations/versions/0001_initial_schema.py`:
1. L69-73 `notification_tip` enum yaratımından `'acil_durum'` değerini çıkar.
   > Postgres enum'dan değer DÜŞÜREMEZ; sorun değil — 0001 yerinde düzenleniyor ve şema `down -v` ile sıfırdan kuruluyor.
2. L84-85 `CREATE TYPE emergency_durum AS ENUM ('acik', 'cozuldu');` → SİL.
3. L156-157 `tenant` DDL'inden `acil_durum_telefon text` kolonunu SİL.
4. L514 tenant-purge fonksiyonundaki `DELETE FROM public.emergency_alert WHERE tenant_id = p_tenant_id;` → SİL.
5. L964-991 `CREATE TABLE emergency_alert (...)` → SİL.
6. L993-997 `ix_emergency_tenant`, `ix_emergency_durum`, `ix_emergency_zaman` → SİL.
7. L1858 RLS enable listesinden `"emergency_alert"` → SİL.
8. L1958 downgrade drop listesinden `"emergency_alert"` → SİL.
9. L1990 `DROP TYPE IF EXISTS emergency_durum;` → SİL.
10. L1392 + L1436 `notlar` yorumlarındaki emergency atfını nötr ifadeyle değiştir (örn. "notlar: serbest metin").

- [ ] **Step 4: Backend kodundan SOS'u çıkar**

```bash
rm backend/app/routers/emergency.py backend/tests/test_emergency.py
```
- `main.py`: L26 `from .routers import emergency as emergency_router` (veya eşdeğeri) + L102 `app.include_router(emergency_router.router)` → SİL.
- `models.py`: `EmergencyAlert` (L660-698), `EMERGENCY_DURUM` (L66-69), `Tenant.acil_durum_telefon` (L161-162), `__all__`'dan `"EmergencyAlert"`/`"EMERGENCY_DURUM"` (L1547/L1569), `notification.tip` tuple'ından `"acil_durum"` (L55) → SİL.
- `schemas.py`: L1521-1553 emergency bloğu (`EmergencyDurum`, `EmergencyCreate`, `EmergencyResolve`, `EmergencyAlertOut`, `EmergencyListResponse`) → SİL; `AlarmTip`'ten `"acil_durum"` (L518) → SİL; `TenantSettings.acil_durum_telefon` (L1564) + `TenantSettingsUpdate.acil_durum_telefon` (L1570) → SİL.
- `routers/tenant.py`: L3 docstring'deki acil-durum cümlesini çıkar; `_to_settings`'ten `acil_durum_telefon=t.acil_durum_telefon,` (L31) → SİL.
- `routers/dashboard.py` L59-61: `son_alarmlar` sorgusunda `'acil_durum'`ı listeden çıkar ve
  `ORDER BY (tip = 'acil_durum') DESC, created_at DESC` → `ORDER BY created_at DESC`.
- `scheduler/notify.py` L84: docstring'deki emergency atfını çıkar.

- [ ] **Step 5: Diğer testlerdeki SOS bloklarını çıkar**

- `backend/tests/test_push.py` L224-236: emergency push testi → SİL.
- `backend/tests/test_yonetici.py` L141-155 (yönetici `/emergency` POST/GET/PATCH) + L173 (`acil_durum_telefon` 403) → SİL.

Kalan atıf kalmadığını doğrula:
```bash
cd /home/kerem/tesis-platform
grep -rni "emergency\|acil_durum" backend/ contracts/db/ --include="*.py" | grep -v "test_sos_kaldirildi"
```
Expected: boş çıktı.

- [ ] **Step 6: Şemayı sıfırdan kur + seed + test**

```bash
cd /home/kerem/tesis-platform/infra
docker compose down -v && docker compose up -d --build
docker compose --profile seed run --rm seed
cd /home/kerem/tesis-platform/backend && python -m pytest tests/test_sos_kaldirildi.py -q
```
Expected: 2 passed. (SKIP çıkarsa API ayakta değildir — geçmiş sayılmaz.)

> Seed bu adımda `acil_durum_telefon` kolonuna yazmaya çalışıp PATLAR — bu BEKLENEN. Task 2'de seed'i de düzeltmek gerekir: `backend/scripts/seed.py` L41 `TENANT["acil_durum_telefon"]` + L104-111 INSERT/ON CONFLICT'teki kolon → SİL. (Tam seed içeriği Task 10'da; burada yalnız SOS kolonunu çıkar ki şema kurulsun.)

- [ ] **Step 7: Tüm backend testlerini çalıştır**

Run: `cd backend && python -m pytest -q`
Expected: tümü PASS (emergency testleri artık yok).

- [ ] **Step 8: Commit**

```bash
git add -A backend/ contracts/db/
git commit -m "feat(sos): acil durum ozelligi backend + migration'dan kaldirildi

emergency_alert tablosu + emergency_durum tipi + 3 index + RLS kaydi +
purge DELETE + tenant.acil_durum_telefon kolonu + notification_tip'teki
'acil_durum' degeri silindi. /emergency router'i kaldirildi; dashboard
alarm siralamasindaki oncelik-yukseltmesi duz created_at DESC oldu.
Kanonik 0001 yerinde duzenlendi (down -v ile sifirdan kurulur).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019PQv4ATndrTUEpBNWypYmS"
```

---

### Task 3: Contracts + dokümanlar — SOS kaldırma

**Files:**
- Modify: `contracts/openapi.yaml` (L2543-2625, L2775-2776, L5332, L6228-6258, L6270-6273, L6282)
- Modify: `contracts/auth.md` (L302-304, L430, L445-446)
- Modify: `contracts/README.md` (L105-110, L122, L193, L299)
- Modify: `backend/README.md` (L168, L174-188)
- Modify: `mobile/README.md` (L629, L632, L911-977, L1165)
- Modify: `docs/CIHAZ-TESTI.md` (L135-137, L221-225, L307-315, L364, L429, L468, L511)
- Modify: `admin-web/README.md:94`

- [ ] **Step 1: openapi.yaml**

SİL: `/emergency` GET+POST (L2543-2604); `/emergency/{id}` PATCH (L2606-2625); `EmergencyDurum`/`EmergencyAlert`/`EmergencyCreate`/`EmergencyResolve` şemaları (L6228-6258); `AlarmTip` enum'undan `acil_durum` (L5332); `TenantSettings.acil_durum_telefon` (L6270-6273) + `TenantSettingsUpdate.acil_durum_telefon` (L6282). `/tenant/settings` açıklamasını (L2775-2776) acil-durum atfı olmadan yeniden yaz.

- [ ] **Step 2: auth.md**

- Matris satırları `POST /emergency` (L302), `GET /emergency` (L303), `PATCH /emergency/{id}` (L304) → SİL.
- L430 yonetici paragrafından `acil durumu tetikler/yonetir;` → SİL.
- L445-446 resident paragrafından panik-butonu cümlesini SİL; cümleyi şuna indir:
  `(POST /complaints acar, ° GET /complaints* YALNIZ kendi actiklarini gorur; PATCH ❌) disinda her resource 403.`

- [ ] **Step 3: contracts/README.md + backend/README.md + admin-web/README.md**

- `contracts/README.md`: L105-108 `emergency_alert` tablo açıklaması, L109-110 yönetim numarası, L122 yonetici persona atfı, L193 push fan-out satırı, L299 uç listesi → SİL.
- `backend/README.md`: L174-188 "Acil durum (panik butonu) + yönetim numarası" bölümü → SİL; L168 pattern atfını nötrle.
- `admin-web/README.md`: L94 dashboard alarm sıralama notu → SİL.

- [ ] **Step 4: mobile/README.md + CIHAZ-TESTI.md**

- `mobile/README.md`: L629/L632 rol menü tablolarından "Acil durum" satırları; L911-977 §12 tamamı; L1165 push deep-link atfı → SİL. (§ numaraları kayarsa sonraki başlıkları yeniden numaralandır.)
  > L914/L973 zaten BAYAT (resident 403 diyor, gerçekte gönderebiliyordu) — bölüm tümden silindiği için ayrıca düzeltilmez.
- `docs/CIHAZ-TESTI.md`: L135-137 seed/RBAC notu; L221-225 menü beklentileri; L307-315 "S6 — Acil durum (panik)" senaryosu; L364 push kontrolü; L429/L468 push kitlesi; L511 S6 imza satırı → SİL. Senaryo numaraları kayarsa S7+ yeniden numaralandır.

- [ ] **Step 5: Atıf kalmadığını doğrula**

```bash
cd /home/kerem/tesis-platform
grep -rni "emergency\|acil durum\|acil_durum\|panik" contracts/ docs/ backend/README.md mobile/README.md admin-web/README.md | grep -v "docs/superpowers"
```
Expected: boş çıktı. (`docs/superpowers/` hariç — spec/plan bu işi ANLATIR, atıf sayılmaz.)

- [ ] **Step 6: Commit**

```bash
git add contracts/ docs/CIHAZ-TESTI.md backend/README.md mobile/README.md admin-web/README.md
git commit -m "docs(sos): acil durum sozlesme + dokumanlardan kaldirildi

openapi /emergency uclari + semalari; auth.md matris satirlari + rol
paragraflari; contracts/backend/mobile README bolumleri; CIHAZ-TESTI S6
senaryosu. mobile/README §12 zaten bayatti (resident 403 diyordu) —
bolum tumden kalktigi icin ayrica duzeltilmedi.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019PQv4ATndrTUEpBNWypYmS"
```

---

### Task 4: Admin-web — SOS kaldırma

**Files:**
- Delete: `admin-web/app/(protected)/emergency/page.tsx`, `admin-web/app/api/emergency/route.ts`, `admin-web/app/api/emergency/[id]/route.ts`
- Modify: `admin-web/components/Nav.tsx:23`, `admin-web/middleware.ts:35`, `admin-web/lib/types.ts` (L8, L409-426, L460), `admin-web/app/(protected)/dashboard/page.tsx:23-33`, `admin-web/app/(protected)/settings/page.tsx` (L30, L49, L94-95)

- [ ] **Step 1: Dosyaları sil**

```bash
cd /home/kerem/tesis-platform/admin-web
rm -rf "app/(protected)/emergency" app/api/emergency
```

- [ ] **Step 2: Nav + middleware**

- `components/Nav.tsx` L23: `{ href: "/emergency", label: "Acil Durum" },` → SİL.
- `middleware.ts` L35: matcher'dan `"/emergency/:path*",` → SİL.

- [ ] **Step 3: types.ts**

SİL: `AlarmTip` union'ından `"acil_durum"` (L8); `EmergencyDurum`/`EmergencyAlert`/`EmergencyList` tipleri (L409-426); `TenantSettings.acil_durum_telefon` (L460).

- [ ] **Step 4: dashboard + settings sayfaları**

- `dashboard/page.tsx` L23-33: `alarm.tip === "acil_durum"` kırmızı/öncelik stili + "ACİL DURUM" etiketi → SİL; alarm satırı tek biçim render edilsin.
- `settings/page.tsx`: L30 state alanı, L49 form gönderimindeki alan, L94-95 "Acil durum yönetim telefonu" input'u → SİL.

- [ ] **Step 5: Build + atıf kontrolü**

```bash
cd /home/kerem/tesis-platform/admin-web
grep -rni "emergency\|acil_durum\|Acil Durum" app/ components/ lib/ middleware.ts
npm run build
```
Expected: grep boş; build başarılı.
> `.next/` içindeki eski derleme çıktıları grep'e takılırsa yok say — build üretimi, kaynak değil.

- [ ] **Step 6: Commit**

```bash
git add -A admin-web/
git commit -m "feat(sos): acil durum panelden kaldirildi

Emergency sayfasi + 2 BFF proxy route + Nav girisi + middleware matcher +
tipler; dashboard'daki kirmizi oncelik stili ve ayarlardaki acil durum
telefonu alani silindi.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019PQv4ATndrTUEpBNWypYmS"
```

---

### Task 5: Mobil — SOS kaldırma

**Files:**
- Delete: `mobile/lib/src/features/emergency/` (3 dosya), `mobile/test/emergency_models_test.dart`
- Modify: `mobile/lib/src/routing/app_router.dart` (L21, L56, L194-195), `mobile/lib/src/features/home/domain/home_menu.dart` (L9-10 + 5 rol listesi), `mobile/lib/src/features/home/presentation/home_screen.dart` (L19, L31-33, L112-142, L207-212), `mobile/lib/src/features/auth/domain/user_role.dart:52-55`, `mobile/lib/src/features/push/domain/push_models.dart:25`
- Modify: `mobile/test/home_menu_test.dart` (L10, L25, L82, L98, L223, L445-455), `mobile/test/user_role_test.dart:39-44`

- [ ] **Step 1: Testleri önce güncelle (kırmızıya çek)**

`mobile/test/home_menu_test.dart`: L445-455'teki "Acil Durum kartı 5 rolün 5'inde de var" testini şununla DEĞİŞTİR:
```dart
  test('Acil durum girisi hicbir rolde YOK (SOS kaldirildi)', () {
    for (final role in UserRole.values) {
      final entries = homeMenuForRole(role);
      expect(
        entries.map((e) => e.name),
        isNot(contains('emergency')),
        reason: '$role menusunde emergency kalmis',
      );
    }
  });
```
L10/L25/L82/L98/L223'teki `HomeMenuEntry.emergency` beklentilerini listelerden çıkar.
`mobile/test/user_role_test.dart` L39-44 `canTriggerEmergency` testleri → SİL.

- [ ] **Step 2: Testi çalıştır, BAŞARISIZ olduğunu gör**

Run: `cd mobile && flutter test test/home_menu_test.dart`
Expected: FAIL — `emergency` hâlâ menülerde.

- [ ] **Step 3: Emergency dizinini + testini sil**

```bash
cd /home/kerem/tesis-platform
rm -rf mobile/lib/src/features/emergency mobile/test/emergency_models_test.dart
```

- [ ] **Step 4: Menü + ana ekran + rota**

- `home_menu.dart`: `HomeMenuEntry.emergency` enum değeri + docstring (L9-10) → SİL; **5 rolün 5'inden de** `HomeMenuEntry.emergency,` satırını çıkar (admin L136, security L157, tesisGorevlisi L177, yonetici L192, resident L217). Resident yorumundaki (L212-213) "acil durum (panik butonu sakinin de hakki) +" ifadesini de çıkar.
- `home_screen.dart`: L19 docstring atfı; L31-33 `hasEmergency`/`gridEntries` ayırması → `final gridEntries = entries;` (veya `entries` doğrudan kullanılsın); L112-142 kırmızı banner kartı; L207-212 `_tileData` içindeki emergency case'i → SİL.
- `app_router.dart`: L21 import, L56 `static const emergency = '/emergency';`, L194-195 `GoRoute` → SİL.
- `user_role.dart` L52-55 `canTriggerEmergency` getter → SİL (ölü kod; hiçbir yerde çağrılmıyor).
- `push_models.dart` L25 yorumundaki `acil_durum` örneğini başka bir `tip` ile değiştir (örn. `duyuru`).

- [ ] **Step 5: Testler + analiz + build**

```bash
cd /home/kerem/tesis-platform/mobile
grep -rni "emergency\|acil durum\|acil_durum\|panik" lib/ test/
flutter analyze && flutter test && flutter build apk --debug
```
Expected: grep boş; analyze 0 issue; testler PASS; APK derlenir.

- [ ] **Step 6: Commit**

```bash
git add -A mobile/
git commit -m "feat(sos): acil durum mobilden kaldirildi

features/emergency dizini + rota + AppRoutes.emergency + kirmizi panik
banner'i + 5 rolun menu girisi + canTriggerEmergency (olu kod) silindi.
home_menu_test artik emergency'nin HICBIR rolde olmadigini dogruluyor.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019PQv4ATndrTUEpBNWypYmS"
```

---

### Task 6: Migration — `yonetim_email` + `birincil` + çoklu-yönetici fonksiyonu

**Files:**
- Modify: `contracts/db/migrations/versions/0001_initial_schema.py` (tenant DDL, app_user DDL + index, `create_tenant_with_yonetici` → `create_tenant_with_yoneticis`, `tenant_detail`)
- Modify: `backend/app/models.py` (Tenant, AppUser aynası)

**Interfaces:**
- Produces: `tenant.yonetim_email text` (nullable); `app_user.birincil boolean NOT NULL DEFAULT false`; `uq_app_user_birincil` partial unique index; SQL fonksiyonu
  `create_tenant_with_yoneticis(p_ad text, p_slug text, p_timezone text, p_kurulum boolean, p_yonetim_email text, p_yoneticiler jsonb) RETURNS TABLE (tenant_id uuid, user_id uuid, sira int)`.

- [ ] **Step 1: tenant + app_user DDL**

`tenant` CREATE TABLE'a (L148 civarı), `kurulum_tamamlandi` satırından sonra:
```sql
    yonetim_email text,
```
`app_user` CREATE TABLE'a (L203 civarı), `aranabilir` satırından sonra:
```sql
    birincil       boolean NOT NULL DEFAULT false,
```
`app_user` index'lerinin yanına:
```python
op.execute(
    """
    -- Tenant basina EN FAZLA BIR birincil yonetici — yapisal garanti.
    -- (Kismi unique index: birincil=false satirlar kisitlanmaz.)
    CREATE UNIQUE INDEX uq_app_user_birincil
        ON app_user (tenant_id) WHERE birincil;
    """
)
```

- [ ] **Step 2: `create_tenant_with_yonetici` → `create_tenant_with_yoneticis`**

Eski fonksiyonu (9 parametreli, L282 civarı) ve onun `REVOKE`/`GRANT` satırlarını SİL; yerine:
```python
op.execute(
    """
    -- Admin cross-tenant: tenant + N yonetici TEK transaction'da.
    -- p_yoneticiler = [{ad, telefon, password_hash, temp_code_hash, password_set}, ...]
    -- ILK eleman BIRINCIL (birincil=true). Hepsi aranabilir=true — yonetici
    -- iletisim karti (auth.md gizlilik istisnasi) numarayi tenant'a acar.
    CREATE OR REPLACE FUNCTION public.create_tenant_with_yoneticis(
        p_ad            text,
        p_slug          text,
        p_timezone      text,
        p_kurulum       boolean,
        p_yonetim_email text,
        p_yoneticiler   jsonb
    )
    RETURNS TABLE (tenant_id uuid, user_id uuid, sira int)
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = ''
    AS $$
    DECLARE
        v_tenant uuid;
    BEGIN
        INSERT INTO public.tenant (ad, slug, timezone, kurulum_tamamlandi, yonetim_email)
        VALUES (p_ad, p_slug, p_timezone, p_kurulum, p_yonetim_email)
        RETURNING id INTO v_tenant;

        RETURN QUERY
        INSERT INTO public.app_user
            (tenant_id, ad, telefon, password_hash, temp_code_hash,
             password_set, role, is_active, aranabilir, birincil)
        SELECT
            v_tenant,
            y.value ->> 'ad',
            y.value ->> 'telefon',
            y.value ->> 'password_hash',
            y.value ->> 'temp_code_hash',
            (y.value ->> 'password_set')::boolean,
            'yonetici'::public.user_role,
            true,
            true,
            (y.ordinality = 1)
        FROM jsonb_array_elements(p_yoneticiler) WITH ORDINALITY AS y(value, ordinality)
        RETURNING v_tenant, public.app_user.id, 0;
    END;
    $$;
    """
)
op.execute(
    "REVOKE ALL ON FUNCTION public.create_tenant_with_yoneticis"
    "(text, text, text, boolean, text, jsonb) FROM PUBLIC;"
)
op.execute(
    f"GRANT EXECUTE ON FUNCTION public.create_tenant_with_yoneticis"
    f"(text, text, text, boolean, text, jsonb) TO {APP_ROLE};"
)
```
> `RETURNING` INSERT'in satır SIRASINI garanti etmez. `sira` sütunu bu yüzden 0 döner ve **kullanılmaz**; Task 7 yöneticileri `telefon` ile eşler (global benzersiz). Yanlış eşleme = yanlış kişiye geçici kod → `telefon` ile eşleme ZORUNLU.

- [ ] **Step 3: `tenant_detail` birincil'e bakacak**

`tenant_detail` fonksiyonundaki (L360 civarı) yönetici alt-sorgusunda:
```sql
-- ONCE: WHERE u.tenant_id = t.id AND u.role = 'yonetici' ORDER BY u.created_at ASC LIMIT 1
-- SONRA:
WHERE u.tenant_id = t.id AND u.role = 'yonetici'::public.user_role AND u.birincil
LIMIT 1
```
> Tekil admin uçları (`PATCH /tenants/{id}/yonetici`, `reset-credential`) böylece BİRİNCİL'e bakmaya devam eder.

- [ ] **Step 4: `models.py` aynasını güncelle**

`Tenant` sınıfına (`kurulum_tamamlandi`'dan sonra):
```python
    # Tesisin yonetim maili (tenant seviyesi; kisisel veya ortak olabilir —
    # anlamsal kisit yok). Yonetici iletisim kartinda gosterilir.
    yonetim_email: Mapped[str | None] = mapped_column(Text, nullable=True)
```
`AppUser` sınıfına (`aranabilir`'dan sonra):
```python
    # Tenant'in BIRINCIL yoneticisi mi? Tesisi ilk giriste adlandirma kapisi
    # yalniz buna acilir. Kismi unique index (uq_app_user_birincil) tenant
    # basina en fazla bir true garantiler.
    birincil: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
```

- [ ] **Step 5: Şemayı sıfırdan kur**

```bash
cd /home/kerem/tesis-platform/infra
docker compose down -v && docker compose up -d --build
docker compose logs migrate --tail=30
```
Expected: migration hatasız. Doğrula:
```bash
docker compose exec -T db psql -U tesis_owner -d tesis -c "\d app_user" | grep birincil
docker compose exec -T db psql -U tesis_owner -d tesis -c "\d tenant" | grep yonetim_email
docker compose exec -T db psql -U tesis_owner -d tesis -c "\di uq_app_user_birincil"
```
Expected: üçü de bulunur.

- [ ] **Step 6: Commit**

```bash
git add contracts/db/ backend/app/models.py
git commit -m "feat(tenant): yonetim_email + birincil yonetici + coklu-yonetici olusturma fonksiyonu

tenant.yonetim_email; app_user.birincil + uq_app_user_birincil kismi unique
index (tenant basina en fazla bir birincil — yapisal garanti).
create_tenant_with_yonetici -> create_tenant_with_yoneticis (jsonb dizi, ilk
eleman birincil, hepsi aranabilir=true). tenant_detail artik created_at
siralamasi yerine birincil bayragina bakiyor.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019PQv4ATndrTUEpBNWypYmS"
```

---

### Task 7: Backend — `POST /tenants` çoklu yönetici

**Files:**
- Modify: `backend/app/schemas.py` (`TenantAdminCreate`, `TenantAdminCreatedOut` + yeni `YoneticiCreate`, `YoneticiCreatedOut`)
- Modify: `backend/app/routers/tenants.py:47-99`
- Modify: `backend/tests/test_tenants.py`

**Interfaces:**
- Consumes: `create_tenant_with_yoneticis(...)` (Task 6).
- Produces: `POST /tenants` body `{ad?: str, yonetim_email?: str, yoneticiler: [{ad, phone, password?}]}` (min 1) → 201 `{tenant_id, yoneticiler: [{user_id, ad, birincil, temp_code}]}`.

- [ ] **Step 1: Failing test yaz**

`backend/tests/test_tenants.py`'ye ekle (mevcut `_headers`, `_uphone` yardımcılarını kullan):
```python
def test_coklu_yonetici_olusturma_birincil_isaretlenir(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    p1, p2, p3 = _uphone(), _uphone(), _uphone()
    r = client.post(
        "/tenants",
        json={
            "ad": "Coklu Sitesi",
            "yonetim_email": "yonetim@coklu.com",
            "yoneticiler": [
                {"ad": "Birinci Yonetici", "phone": p1},
                {"ad": "Ikinci Yonetici", "phone": p2, "password": "Yonetici123!"},
                {"ad": "Ucuncu Yonetici", "phone": p3},
            ],
        },
        headers=admin,
    )
    assert r.status_code == 201, r.text
    body = r.json()
    assert len(body["yoneticiler"]) == 3

    birinciler = [y for y in body["yoneticiler"] if y["birincil"]]
    assert len(birinciler) == 1
    assert birinciler[0]["ad"] == "Birinci Yonetici"

    # parolasiz olanlar gecici kod alir; parolali olan almaz.
    by_ad = {y["ad"]: y for y in body["yoneticiler"]}
    assert by_ad["Birinci Yonetici"]["temp_code"]
    assert by_ad["Ikinci Yonetici"]["temp_code"] is None
    assert by_ad["Ucuncu Yonetici"]["temp_code"]

    tid = body["tenant_id"]
    try:
        rows = owner_conn.execute(
            "SELECT ad, birincil, aranabilir, role FROM app_user "
            "WHERE tenant_id = %s ORDER BY birincil DESC",
            (tid,),
        ).fetchall()
        assert len(rows) == 3
        assert all(r[3] == "yonetici" for r in rows)
        assert all(r[2] is True for r in rows)  # aranabilir=true (iletisim karti)
        assert [r[1] for r in rows] == [True, False, False]

        t = owner_conn.execute(
            "SELECT ad, yonetim_email, kurulum_tamamlandi FROM tenant WHERE id = %s",
            (tid,),
        ).fetchone()
        assert t[0] == "Coklu Sitesi"
        assert t[1] == "yonetim@coklu.com"
        assert t[2] is False  # ad verildi ama birincil yine ONAYLAR
    finally:
        owner_conn.execute("DELETE FROM tenant WHERE id = %s", (tid,))


def test_ad_verilmezse_placeholder(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post(
        "/tenants",
        json={"yoneticiler": [{"ad": "Tek Yonetici", "phone": _uphone()}]},
        headers=admin,
    )
    assert r.status_code == 201, r.text
    tid = r.json()["tenant_id"]
    try:
        t = owner_conn.execute(
            "SELECT ad, kurulum_tamamlandi FROM tenant WHERE id = %s", (tid,)
        ).fetchone()
        assert t[0] == "(Kurulum bekliyor)"
        assert t[1] is False
    finally:
        owner_conn.execute("DELETE FROM tenant WHERE id = %s", (tid,))


def test_payload_ici_telefon_tekrari_422(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    p = _uphone()
    r = client.post(
        "/tenants",
        json={"yoneticiler": [{"ad": "A", "phone": p}, {"ad": "B", "phone": p}]},
        headers=admin,
    )
    assert r.status_code == 422, r.text


def test_bos_yonetici_listesi_422(client, world):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    r = client.post("/tenants", json={"yoneticiler": []}, headers=admin)
    assert r.status_code == 422, r.text


def test_mevcut_telefon_409_ve_tenant_olusmaz(client, world, owner_conn):
    admin = _headers(client, world["slug_a"], world["admin_a"])
    once = owner_conn.execute("SELECT count(*) FROM tenant").fetchone()[0]
    r = client.post(
        "/tenants",
        json={
            "ad": "Catisan",
            "yoneticiler": [{"ad": "X", "phone": world["yonetici_a"]["telefon"]}],
        },
        headers=admin,
    )
    assert r.status_code == 409, r.text
    assert owner_conn.execute("SELECT count(*) FROM tenant").fetchone()[0] == once
```
> `world` fixture'ında `yonetici_a["telefon"]` yoksa `owner_conn` ile mevcut bir telefonu oku ya da önce bir tenant açıp onun telefonunu kullan. Fixture'ın gerçek şeklini `backend/tests/conftest.py`'den DOĞRULA.

- [ ] **Step 2: Testi çalıştır, BAŞARISIZ olduğunu gör**

Run: `cd backend && python -m pytest tests/test_tenants.py -q -k "coklu or placeholder or tekrari or bos_yonetici or mevcut_telefon"`
Expected: FAIL — eski şema `yonetici_ad`/`phone` bekliyor, 422 döner.

- [ ] **Step 3: Şemalar**

`backend/app/schemas.py` — eski `TenantAdminCreate`/`TenantAdminCreatedOut`u DEĞİŞTİR:
```python
class YoneticiCreate(BaseModel):
    """Tenant olusturmada tek bir yonetici satiri. Telefon = giris anahtari
    (global benzersiz). E-posta ALINMAZ: mobil giris telefonladir ve yonetici
    e-postasini hicbir uc okumaz (tenant seviyesindeki yonetim_email ayridir)."""

    ad: str = Field(..., min_length=2, max_length=120, examples=["Ayse Yilmaz"])
    phone: str = Field(..., min_length=1, examples=["+905321112203"])
    password: str | None = Field(None, min_length=8)

    @field_validator("password")
    @classmethod
    def _strong(cls, v: str | None) -> str | None:
        return v if v is None else validate_password_strength(v)


class TenantAdminCreate(BaseModel):
    """Admin bir tenant + N yonetici acar. ILK yonetici BIRINCIL'dir (tesisi
    ilk giriste adlandirir). ad verilmezse placeholder + rastgele slug; her
    durumda kurulum_tamamlandi=false (birincil adi ONAYLAR)."""

    ad: str | None = Field(None, min_length=2, max_length=160, examples=["Acme Plaza"])
    yonetim_email: str | None = Field(None, examples=["yonetim@acme.com"])
    yoneticiler: list[YoneticiCreate] = Field(..., min_length=1)

    @model_validator(mode="after")
    def _telefon_tekrari_yok(self) -> "TenantAdminCreate":
        phones = [y.phone for y in self.yoneticiler]
        if len(phones) != len(set(phones)):
            raise ValueError("Ayni telefon birden fazla yoneticide kullanilamaz.")
        return self

    @field_validator("yonetim_email")
    @classmethod
    def _bos_ise_none(cls, v: str | None) -> str | None:
        return v.strip() or None if v is not None else None


class YoneticiCreatedOut(BaseModel):
    user_id: uuid.UUID
    ad: str
    birincil: bool
    temp_code: str | None = None


class TenantAdminCreatedOut(BaseModel):
    """temp_code YALNIZ parola verilmeyen yonetici icin ve BIR KEZ doner
    (admin ilgili yoneticiye iletir). tenant_id GIZLI kimliktir."""

    tenant_id: uuid.UUID
    yoneticiler: list[YoneticiCreatedOut]
```
> `model_validator` ve `field_validator` importlarının dosyada olduğunu doğrula.

- [ ] **Step 4: Endpoint**

`backend/app/routers/tenants.py` L47-99'u DEĞİŞTİR:
```python
@router.post("", response_model=TenantAdminCreatedOut, status_code=201)
async def create_tenant(
    body: TenantAdminCreate,
    _: AppUser = Depends(_ADMIN),
) -> TenantAdminCreatedOut:
    """Admin: yeni tenant + N yonetici acar (ILK yonetici BIRINCIL).
    Yonetici basina parola verilirse dogrudan belirlenir; verilmezse gecici kod
    uretilir (bir kez doner). Telefon global benzersiz -> cakisma 409."""
    hazir: list[dict] = []
    for y in body.yoneticiler:
        try:
            phone = normalize_phone(y.phone)
        except ValueError:
            raise APIError(422, "validation_error", "Gecersiz telefon numarasi.")
        if y.password is not None:
            hazir.append({
                "ad": y.ad, "telefon": phone, "password_hash": hash_password(y.password),
                "temp_code_hash": None, "password_set": True, "temp_code": None,
            })
        else:
            code = generate_temp_code()
            hazir.append({
                "ad": y.ad, "telefon": phone, "password_hash": None,
                "temp_code_hash": hash_password(code), "password_set": False,
                "temp_code": code,
            })

    # Normalize sonrasi cakisma (orn. 0532... ve +90532... ayni numaraya coker).
    phones = [h["telefon"] for h in hazir]
    if len(phones) != len(set(phones)):
        raise APIError(422, "validation_error", "Ayni telefon birden fazla yoneticide kullanilamaz.")

    ad = body.ad or _PLACEHOLDER_AD
    payload = [
        {k: h[k] for k in ("ad", "telefon", "password_hash", "temp_code_hash", "password_set")}
        for h in hazir
    ]

    async with SessionLocal() as session:
        async with session.begin():
            try:
                rows = (
                    await session.execute(
                        text(
                            "SELECT tenant_id, user_id FROM "
                            "public.create_tenant_with_yoneticis("
                            ":ad, :slug, :tz, :kur, :yem, CAST(:yon AS jsonb))"
                        ),
                        {
                            "ad": ad,
                            "slug": slugify_tenant(ad),
                            "tz": "Europe/Istanbul",
                            "kur": False,
                            "yem": body.yonetim_email,
                            "yon": json.dumps(payload),
                        },
                    )
                ).all()
            except IntegrityError:
                raise APIError(409, "conflict", "Bu telefon zaten kayitli.")

        # INSERT ... RETURNING satir SIRASINI garanti ETMEZ -> telefonla esle.
        ids = await session.execute(
            text(
                "SELECT id, telefon, birincil FROM app_user "
                "WHERE tenant_id = :t AND role = 'yonetici'"
            ),
            {"t": rows[0].tenant_id},
        )
        by_phone = {r.telefon: r for r in ids.all()}

    return TenantAdminCreatedOut(
        tenant_id=rows[0].tenant_id,
        yoneticiler=[
            YoneticiCreatedOut(
                user_id=by_phone[h["telefon"]].id,
                ad=h["ad"],
                birincil=by_phone[h["telefon"]].birincil,
                temp_code=h["temp_code"],
            )
            for h in hazir
        ],
    )
```
Import ekle: `import json`; `from ..schemas import TenantAdminCreate, TenantAdminCreatedOut, YoneticiCreatedOut, ...`.
> Eşleme telefonla — **sıraya güvenme**. Yanlış eşleme = yanlış kişiye geçici kod.
> `SessionLocal()` RLS bypass etmez; yönetici okuması `create_tenant_with_yoneticis` ile aynı transaction dışında ve tenant context'siz. Okuma 0 satır dönerse SECURITY DEFINER fonksiyon içinden `ad`/`birincil`i de RETURNING ile döndürmeyi tercih et (fonksiyon owner yetkisiyle RLS'i bypass eder).

- [ ] **Step 5: Testleri çalıştır**

```bash
cd /home/kerem/tesis-platform/infra && docker compose up -d --build api
cd /home/kerem/tesis-platform/backend && python -m pytest tests/test_tenants.py -q
```
Expected: tümü PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/app/schemas.py backend/app/routers/tenants.py backend/tests/test_tenants.py
git commit -m "feat(tenant): POST /tenants coklu yonetici + yonetim maili + opsiyonel tesis adi

Govde {ad?, yonetim_email?, yoneticiler:[{ad, phone, password?}]} (en az bir);
yanit yoneticiler[] (user_id/ad/birincil/temp_code) — KIRICI degisiklik, dis
istemci yok. Ilk yonetici birincil; hepsi aranabilir=true. Payload ici telefon
tekrari 422 (normalize SONRASI da kontrol), global cakisma 409 (tenant olusmaz).
Yoneticiler telefonla eslesir — INSERT RETURNING sira garantisi yok.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019PQv4ATndrTUEpBNWypYmS"
```

---

### Task 8: Backend — `GET /yonetici-iletisim`

**Files:**
- Create: `backend/app/routers/yonetici_iletisim.py`
- Modify: `backend/app/main.py` (import + include_router)
- Modify: `backend/app/schemas.py` (`YoneticiKart`, `YoneticiIletisimOut`)
- Create: `backend/tests/test_yonetici_iletisim.py`

**Interfaces:**
- Produces: `GET /yonetici-iletisim` → `{yoneticiler: [{user_id, ad_soyad, telefon}], yonetim_email}`. Birincil ilk. `aranabilir` YOKSAYILIR.

- [ ] **Step 1: Failing test yaz**

`backend/tests/test_yonetici_iletisim.py`:
```python
"""GET /yonetici-iletisim — yonetici iletisim dizini.

GIZLILIK ISTISNASI (auth.md): bu uc C1a'nin uc kapisini (yon + riza + numara)
YALNIZ yonetici kartlari icin deler. Yonetici bir HIZMET rolüdür; numarayi
admin bilerek girer. C1a modeli baska her sey icin aynen korunur.
"""
from __future__ import annotations


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_saha_rolleri_yoneticileri_gorur(client, world):
    for cred in (world["guard_a"], world["gorevli_a"], world["resident_a"]):
        h = _headers(client, world["slug_a"], cred)
        r = client.get("/yonetici-iletisim", headers=h)
        assert r.status_code == 200, r.text
        body = r.json()
        assert len(body["yoneticiler"]) >= 1
        y = body["yoneticiler"][0]
        assert y["ad_soyad"]
        assert "telefon" in y
        assert "yonetim_email" in body


def test_birincil_listede_ilk(client, world, owner_conn):
    owner_conn.execute(
        "UPDATE app_user SET birincil = true WHERE id = %s", (world["yonetici_a"]["id"],)
    )
    h = _headers(client, world["slug_a"], world["guard_a"])
    r = client.get("/yonetici-iletisim", headers=h)
    assert r.status_code == 200, r.text
    assert r.json()["yoneticiler"][0]["user_id"] == str(world["yonetici_a"]["id"])


def test_aranabilir_false_olsa_bile_listelenir(client, world, owner_conn):
    """Bilincli istisna: sekme aranabilir'i YOKSAYAR (hizmet-rolu dizini)."""
    owner_conn.execute(
        "UPDATE app_user SET aranabilir = false, telefon = %s WHERE id = %s",
        ("+905999888777", world["yonetici_a"]["id"]),
    )
    h = _headers(client, world["slug_a"], world["guard_a"])
    r = client.get("/yonetici-iletisim", headers=h)
    assert r.status_code == 200, r.text
    kart = [y for y in r.json()["yoneticiler"] if y["user_id"] == str(world["yonetici_a"]["id"])]
    assert kart and kart[0]["telefon"] == "+905999888777"


def test_pasif_yonetici_listelenmez(client, world, owner_conn):
    owner_conn.execute(
        "UPDATE app_user SET is_active = false WHERE id = %s", (world["yonetici_a"]["id"],)
    )
    try:
        h = _headers(client, world["slug_a"], world["guard_a"])
        r = client.get("/yonetici-iletisim", headers=h)
        assert r.status_code == 200, r.text
        ids = [y["user_id"] for y in r.json()["yoneticiler"]]
        assert str(world["yonetici_a"]["id"]) not in ids
    finally:
        owner_conn.execute(
            "UPDATE app_user SET is_active = true WHERE id = %s", (world["yonetici_a"]["id"],)
        )


def test_tenant_izolasyonu(client, world, owner_conn):
    owner_conn.execute(
        "UPDATE tenant SET yonetim_email = %s WHERE id = %s",
        ("a@a.com", world["tenant_a"]),
    )
    owner_conn.execute(
        "UPDATE tenant SET yonetim_email = %s WHERE id = %s",
        ("b@b.com", world["tenant_b"]),
    )
    h = _headers(client, world["slug_a"], world["guard_a"])
    r = client.get("/yonetici-iletisim", headers=h)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["yonetim_email"] == "a@a.com"
    assert str(world["yonetici_b"]["id"]) not in [y["user_id"] for y in body["yoneticiler"]]


def test_kimliksiz_401(client):
    assert client.get("/yonetici-iletisim").status_code == 401
```
> `world` fixture'ının gerçek anahtarlarını (`guard_a`, `gorevli_a`, `resident_a`, `yonetici_a["id"]`, `tenant_a`…) `backend/tests/conftest.py`'den DOĞRULA ve gerekirse uyarla.

- [ ] **Step 2: Testi çalıştır, BAŞARISIZ olduğunu gör**

Run: `cd backend && python -m pytest tests/test_yonetici_iletisim.py -q`
Expected: FAIL — 404 (uç yok).

- [ ] **Step 3: Şemalar**

`backend/app/schemas.py`'ye ekle:
```python
# --------------------------- yonetici iletisim ----------------------------- #
class YoneticiKart(BaseModel):
    """Yonetici iletisim karti. GIZLILIK ISTISNASI (auth.md): telefon burada
    tenant'in TUM uyelerine acilir — C1a'nin riza/yon kapilari BU UC icin
    gecerli DEGILDIR (yonetici = hizmet rolu; numarayi admin bilerek girer).
    Istisna YALNIZ role='yonetici' icindir."""

    model_config = ConfigDict(from_attributes=True)

    user_id: uuid.UUID
    ad_soyad: str
    telefon: str | None = None


class YoneticiIletisimOut(BaseModel):
    yoneticiler: list[YoneticiKart]
    yonetim_email: str | None = None
```

- [ ] **Step 4: Router**

`backend/app/routers/yonetici_iletisim.py`:
```python
"""GET /yonetici-iletisim — tenant'in yonetici iletisim dizini.

GIZLILIK ISTISNASI (contracts/auth.md): C1a'nin UC kapisi (YON + RIZA +
NUMARA VARLIGI) ve "listede numara YOK" kurali burada BILINCLI olarak
delinir. Gerekce: yonetici bir HIZMET rolüdür; numarayi admin bilerek girer;
sahadaki personelin ve sakinin yonetime ulasabilmesi urun geregidir.
Kapsam: YALNIZ bu uc, YALNIZ role='yonetici'. C1a modeli (/call-target uc
kapili; GET /users numara tasimaz; PATCH /me/contact rizasi) BASKA HER SEY
icin aynen korunur.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..deps import get_current_user, get_tenant_db
from ..errors import APIError
from ..models import AppUser, Tenant
from ..schemas import YoneticiIletisimOut, YoneticiKart

router = APIRouter(tags=["yonetici-iletisim"])


@router.get("/yonetici-iletisim", response_model=YoneticiIletisimOut)
async def yonetici_iletisim(
    _user: AppUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_tenant_db),
) -> YoneticiIletisimOut:
    """Tenant'in TUM aktif yoneticileri (birincil ilk) + yonetim maili.

    RBAC: tenant'in HERHANGI bir kimlikli uyesi (rol kapisi yok); izolasyon
    RLS ile. `aranabilir` YOKSAYILIR — bkz. modul docstring'i.
    """
    rows = (
        await db.execute(
            select(AppUser)
            .where(AppUser.role == "yonetici", AppUser.is_active.is_(True))
            .order_by(AppUser.birincil.desc(), AppUser.created_at.asc())
        )
    ).scalars().all()

    t = (await db.execute(select(Tenant))).scalar_one_or_none()
    if t is None:
        raise APIError(404, "not_found", "Tenant bulunamadi.")

    return YoneticiIletisimOut(
        yoneticiler=[
            YoneticiKart(user_id=u.id, ad_soyad=u.ad, telefon=u.telefon) for u in rows
        ],
        yonetim_email=t.yonetim_email,
    )
```
`backend/app/main.py`: import + `app.include_router(yonetici_iletisim.router)` ekle (diğer router'larla aynı desende).

- [ ] **Step 5: Testleri çalıştır**

```bash
cd /home/kerem/tesis-platform/infra && docker compose up -d --build api
cd /home/kerem/tesis-platform/backend && python -m pytest tests/test_yonetici_iletisim.py -q
```
Expected: 6 passed.

- [ ] **Step 6: Commit**

```bash
git add backend/app/routers/yonetici_iletisim.py backend/app/main.py \
        backend/app/schemas.py backend/tests/test_yonetici_iletisim.py
git commit -m "feat(iletisim): GET /yonetici-iletisim — yonetici dizini (C1a gizlilik istisnasi)

Tenant'in tum aktif yoneticileri (birincil ilk) + tenant yonetim maili;
tenant'in herhangi bir kimlikli uyesine acik (izolasyon RLS ile).
BILINCLI ISTISNA: aranabilir YOKSAYILIR ve numara listede doner — yonetici
hizmet rolüdür. Istisna yalniz bu uc + yalniz role=yonetici icindir; C1a
modeli baska her sey icin korunur.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019PQv4ATndrTUEpBNWypYmS"
```

---

### Task 9: Backend — `birincil` profilde + setup birincil-only + yönetici yeniden adlandırma

**Files:**
- Modify: `backend/app/schemas.py` (`MeProfileOut`, `TenantSettings`, `TenantSettingsUpdate`)
- Modify: `backend/app/routers/tenant.py` (RBAC + `_to_settings`)
- Create: `backend/tests/test_tenant_ad.py`
- Modify: `backend/tests/test_tenants.py` (setup 403 testi)

**Interfaces:**
- Consumes: `AppUser.birincil` (Task 6), `Tenant.yonetim_email` (Task 6).
- Produces: `GET /me/profile` → `+birincil: bool`. `POST /tenant/setup` birincil-only. `PATCH /tenant/settings`: admin → `ad|timezone|yonetim_email`; yonetici → yalnız `ad`. `GET /tenant/settings` → `+yonetim_email`.

- [ ] **Step 1: Failing test yaz**

`backend/tests/test_tenant_ad.py`:
```python
"""Tesis gorunen adi: birincil yonetici adlandirir; yoneticiler yeniden
adlandirir. slug ve id ASLA degismez."""
from __future__ import annotations


def _headers(client, slug, cred):
    r = client.post(
        "/auth/login",
        json={"tenant_slug": slug, "email": cred["email"], "password": cred["password"]},
    )
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_yonetici_adi_degistirir_slug_degismez(client, world, owner_conn):
    onceki = owner_conn.execute(
        "SELECT slug FROM tenant WHERE id = %s", (world["tenant_a"],)
    ).fetchone()[0]

    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.patch("/tenant/settings", json={"ad": "Yeni Tesis Adi"}, headers=h)
    assert r.status_code == 200, r.text
    assert r.json()["ad"] == "Yeni Tesis Adi"

    sonraki = owner_conn.execute(
        "SELECT ad, slug FROM tenant WHERE id = %s", (world["tenant_a"],)
    ).fetchone()
    assert sonraki[0] == "Yeni Tesis Adi"
    assert sonraki[1] == onceki, "slug DEGISMEMELI"

    r2 = client.get("/tenant/settings", headers=h)
    assert r2.json()["ad"] == "Yeni Tesis Adi"


def test_yonetici_timezone_degistiremez_403(client, world):
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.patch("/tenant/settings", json={"timezone": "UTC"}, headers=h)
    assert r.status_code == 403, r.text


def test_yonetici_yonetim_email_degistiremez_403(client, world):
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.patch("/tenant/settings", json={"yonetim_email": "x@x.com"}, headers=h)
    assert r.status_code == 403, r.text


def test_admin_hepsini_degistirir(client, world):
    h = _headers(client, world["slug_a"], world["admin_a"])
    r = client.patch(
        "/tenant/settings",
        json={"ad": "Admin Adi", "yonetim_email": "yonetim@a.com"},
        headers=h,
    )
    assert r.status_code == 200, r.text
    assert r.json()["yonetim_email"] == "yonetim@a.com"


def test_saha_rolleri_adi_degistiremez_403(client, world):
    for cred in (world["guard_a"], world["resident_a"]):
        h = _headers(client, world["slug_a"], cred)
        r = client.patch("/tenant/settings", json={"ad": "Olmaz"}, headers=h)
        assert r.status_code == 403, r.text


def test_profil_birincil_alani_doner(client, world, owner_conn):
    owner_conn.execute(
        "UPDATE app_user SET birincil = true WHERE id = %s", (world["yonetici_a"]["id"],)
    )
    h = _headers(client, world["slug_a"], world["yonetici_a"])
    r = client.get("/me/profile", headers=h)
    assert r.status_code == 200, r.text
    assert r.json()["birincil"] is True

    hg = _headers(client, world["slug_a"], world["guard_a"])
    assert client.get("/me/profile", headers=hg).json()["birincil"] is False
```
`backend/tests/test_tenants.py`'ye ekle:
```python
def test_birincil_olmayan_yonetici_setup_403(client, world, owner_conn):
    owner_conn.execute(
        "UPDATE app_user SET birincil = false WHERE id = %s", (world["yonetici_a"]["id"],)
    )
    owner_conn.execute(
        "UPDATE tenant SET kurulum_tamamlandi = false WHERE id = %s", (world["tenant_a"],)
    )
    try:
        h = _headers(client, world["slug_a"], world["yonetici_a"])
        r = client.post("/tenant/setup", json={"ad": "Olmaz"}, headers=h)
        assert r.status_code == 403, r.text
    finally:
        owner_conn.execute(
            "UPDATE tenant SET kurulum_tamamlandi = true WHERE id = %s", (world["tenant_a"],)
        )
```

- [ ] **Step 2: Testi çalıştır, BAŞARISIZ olduğunu gör**

Run: `cd backend && python -m pytest tests/test_tenant_ad.py -q`
Expected: FAIL — yönetici PATCH'te 403 (henüz admin-only), `birincil` profilde yok.

- [ ] **Step 3: Şemalar**

`MeProfileOut`'a (`is_active`'ten sonra):
```python
    # Tenant'in birincil yoneticisi mi? Mobil ilk-giris adlandirma kapisi
    # yalniz buna acilir (yonetici disi rollerde daima false).
    birincil: bool = False
```
`TenantSettings`'e (`kurulum_tamamlandi`'dan sonra):
```python
    # Tesisin yonetim maili — yonetici iletisim kartinda gosterilir.
    yonetim_email: str | None = None
```
`TenantSettingsUpdate`'i DEĞİŞTİR:
```python
class TenantSettingsUpdate(BaseModel):
    """admin: hepsi. yonetici: YALNIZ `ad` (digerleri 403 — bkz. router)."""

    timezone: str | None = None
    ad: str | None = None
    yonetim_email: str | None = None

    @model_validator(mode="after")
    def _at_least_one(self) -> "TenantSettingsUpdate":
        if not self.model_fields_set:
            raise ValueError("en az bir alan gerekli")
        return self
```

- [ ] **Step 4: Router RBAC**

`backend/app/routers/tenant.py`:
```python
_READER = require_role("admin", "yonetici", "security", "tesis_gorevlisi", "resident")
_ADMIN = require_role("admin")
_YONETICI = require_role("yonetici")
_ADMIN_VEYA_YONETICI = require_role("admin", "yonetici")

# Yonetici YALNIZ tesis adini degistirebilir; yapilandirma admin'de kalir.
_YONETICI_YAZABILIR = {"ad"}


def _to_settings(t: Tenant) -> TenantSettings:
    return TenantSettings(
        tenant_id=t.id, ad=t.ad, slug=t.slug, timezone=t.timezone,
        kurulum_tamamlandi=t.kurulum_tamamlandi,
        yonetim_email=t.yonetim_email,
    )


@router.patch("/settings", response_model=TenantSettings)
async def update_settings(
    body: TenantSettingsUpdate,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_ADMIN_VEYA_YONETICI),
) -> TenantSettings:
    """admin: ad + timezone + yonetim_email. yonetici: YALNIZ ad (tesisini
    yeniden adlandirir); baska alan gonderirse 403 — yetki yukseltme yok.
    slug'a ASLA yazilmaz (id/slug degismez)."""
    data = body.model_dump(exclude_unset=True)
    if user.role == "yonetici" and not set(data) <= _YONETICI_YAZABILIR:
        raise APIError(403, "forbidden", "Yonetici yalniz tesis adini degistirebilir.")
    t = await _current_tenant(db)
    for key, value in data.items():
        setattr(t, key, value)
    await db.flush()
    await db.refresh(t)
    return _to_settings(t)


@router.post("/setup", response_model=TenantSettings)
async def setup_tenant(
    body: TenantSetupRequest,
    db: AsyncSession = Depends(get_tenant_db),
    user: AppUser = Depends(_YONETICI),
) -> TenantSettings:
    """BIRINCIL yonetici ILK GIRISTE tesisini adlandirir (onboarding Model A).
    Birincil olmayan yonetici 403 — kapi mobilde yalniz birincile gosterilir,
    uc de eslesmeli. Zaten kuruluysa 409."""
    if not user.birincil:
        raise APIError(403, "forbidden", "Tesisi yalniz birincil yonetici adlandirabilir.")
    t = await _current_tenant(db)
    if t.kurulum_tamamlandi:
        raise APIError(409, "conflict", "Tesis zaten kuruldu.")
    t.ad = body.ad
    t.kurulum_tamamlandi = True
    await db.flush()
    await db.refresh(t)
    return _to_settings(t)
```
Modül docstring'ini (L1-7) acil-durum atfı olmadan yeniden yaz; RBAC satırını güncelle: `guncelleme: admin (hepsi) / yonetici (yalniz ad); ilk-giris adlandirma: birincil yonetici`.

- [ ] **Step 5: Testleri çalıştır**

```bash
cd /home/kerem/tesis-platform/infra && docker compose up -d --build api
cd /home/kerem/tesis-platform/backend && python -m pytest tests/test_tenant_ad.py tests/test_tenants.py -q
```
Expected: tümü PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/app/schemas.py backend/app/routers/tenant.py \
        backend/tests/test_tenant_ad.py backend/tests/test_tenants.py
git commit -m "feat(tesis): birincil yonetici adlandirir; yoneticiler yeniden adlandirir

GET /me/profile artik birincil bayragini doner (mobil kapi bunu okur; JWT
semasi degismedi). POST /tenant/setup birincil-only (403) — kapi mobilde
yalniz birincile gosteriliyordu, uc de eslesti. PATCH /tenant/settings
yoneticiye acildi ama YALNIZ ad icin (timezone/yonetim_email admin'de kalir,
aksi 403). slug'a hicbir ucta yazilmaz.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019PQv4ATndrTUEpBNWypYmS"
```

---

### Task 10: Seed — yönetim maili + birincil + ikinci yönetici

**Files:**
- Modify: `backend/scripts/seed.py` (TENANT sözlüğü, USERS listesi, INSERT'ler)

- [ ] **Step 1: TENANT sözlüğü**

```python
TENANT = {
    "slug": "acme-plaza",
    "ad": "Acme Plaza",
    "timezone": "Europe/Istanbul",
    "yonetim_email": "yonetim@acme.com",
}
```
(`acil_durum_telefon` Task 2'de çıkarılmıştı.)

- [ ] **Step 2: Tenant INSERT**

```python
        tenant_id = conn.execute(
            """
            INSERT INTO tenant (ad, slug, timezone, yonetim_email)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (slug) DO UPDATE
                SET ad = EXCLUDED.ad, timezone = EXCLUDED.timezone,
                    yonetim_email = EXCLUDED.yonetim_email
            RETURNING id
            """,
            (TENANT["ad"], TENANT["slug"], TENANT["timezone"], TENANT["yonetim_email"]),
        ).fetchone()[0]
```

- [ ] **Step 3: USERS — birincil + ikinci yönetici**

Mevcut `Acme Yonetici` girdisine `"birincil": True` ekle; hemen ardına ikinci yöneticiyi ekle:
```python
    {
        "ad": "Acme Yonetici",
        "email": "yonetici@acme.com",
        "role": "yonetici",
        "password": os.getenv("SEED_YONETICI_PASSWORD", "Yonetici123!"),
        # Rol-bazli arama (C1a): security yoneticiyi arayabilir (rizali).
        "telefon": "+905321112201",
        "aranabilir": True,
        # Tesisi ilk giriste adlandiran yonetici (kapi yalniz buna acilir).
        "birincil": True,
    },
    {
        # Ikinci yonetici: "Yonetici Iletisim" sekmesindeki COKLU listeyi
        # gosterir. NOT: telefon GLOBAL benzersiz — 201-205 dolu (201 yonetici,
        # 202 guard, 203 sakin, 204 cleaner, 205 sakin-3) -> 206.
        "ad": "Acme Yonetici 2",
        "email": "yonetici2@acme.com",
        "role": "yonetici",
        "password": os.getenv("SEED_YONETICI2_PASSWORD", "Yonetici123!"),
        "telefon": "+905321112206",
        "aranabilir": True,
        "birincil": False,
    },
```

- [ ] **Step 4: Kullanıcı INSERT'ine `birincil` ekle**

```python
            conn.execute(
                """
                INSERT INTO app_user (tenant_id, ad, email, password_hash,
                                      password_set, temp_code_hash, role, is_active,
                                      telefon, aranabilir, birincil)
                VALUES (%s, %s, %s, %s, true, NULL, %s::user_role, true, %s, %s, %s)
                ON CONFLICT (tenant_id, email) DO UPDATE
                    SET ad = EXCLUDED.ad,
                        password_hash = EXCLUDED.password_hash,
                        password_set = true,
                        temp_code_hash = NULL,
                        role = EXCLUDED.role,
                        is_active = true,
                        telefon = EXCLUDED.telefon,
                        aranabilir = EXCLUDED.aranabilir,
                        birincil = EXCLUDED.birincil,
                        updated_at = now()
                """,
                (tenant_id, u["ad"], u["email"], hash_password(u["password"]),
                 u["role"], u.get("telefon"), u.get("aranabilir", False),
                 u.get("birincil", False)),
            )
```
> Mevcut INSERT'in parametre sırasını DOĞRULA ve `birincil`i sona ekle — sıra kayarsa yanlış kolona yazılır.

- [ ] **Step 5: Seed'i çalıştır ve doğrula**

```bash
cd /home/kerem/tesis-platform/infra
docker compose down -v && docker compose up -d --build
docker compose --profile seed run --rm seed
docker compose --profile seed run --rm seed   # idempotent: ikinci kez de gecmeli
docker compose exec -T db psql -U tesis_owner -d tesis -c \
  "SELECT ad, telefon, birincil FROM app_user WHERE role='yonetici' ORDER BY birincil DESC;"
docker compose exec -T db psql -U tesis_owner -d tesis -c \
  "SELECT ad, yonetim_email FROM tenant WHERE slug='acme-plaza';"
```
Expected: iki yönetici (201 birincil=t, 206 birincil=f); tenant `yonetim_email='yonetim@acme.com'`. İkinci seed çalışması da hatasız (idempotent).

- [ ] **Step 6: Commit**

```bash
git add backend/scripts/seed.py
git commit -m "feat(seed): yonetim maili + birincil yonetici + ikinci yonetici

acme-plaza'ya yonetim_email; mevcut yonetici birincil=true; coklu listeyi
gostermek icin ikinci yonetici (+905321112206 — telefon GLOBAL benzersiz ve
201-205 zaten doluydu; 204 cleaner'a ait).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019PQv4ATndrTUEpBNWypYmS"
```

---

### Task 11: Admin-web — tesis oluşturma formu

**Files:**
- Modify: `admin-web/app/(protected)/tenants/page.tsx`
- Modify: `admin-web/lib/types.ts`

**Interfaces:**
- Consumes: `POST /tenants` yeni gövde/yanıt (Task 7).

- [ ] **Step 1: types.ts**

```ts
export type YoneticiCreate = { ad: string; phone: string; password?: string };
export type TenantAdminCreate = {
  ad?: string;
  yonetim_email?: string;
  yoneticiler: YoneticiCreate[];
};
export type YoneticiCreatedOut = {
  user_id: string;
  ad: string;
  birincil: boolean;
  temp_code: string | null;
};
export type TenantAdminCreatedOut = {
  tenant_id: string;
  yoneticiler: YoneticiCreatedOut[];
};
```
`TenantSettings` tipine `yonetim_email?: string | null;` ve **eksik olan** `kurulum_tamamlandi: boolean;` ekle.

- [ ] **Step 2: Form state**

```tsx
type YoneticiForm = { ad: string; phone: string; password: string };
type FormState = { ad: string; yonetim_email: string; yoneticiler: YoneticiForm[] };

const BOS_YONETICI: YoneticiForm = { ad: "", phone: "", password: "" };
const EMPTY: FormState = { ad: "", yonetim_email: "", yoneticiler: [{ ...BOS_YONETICI }] };
```

- [ ] **Step 3: Alanlar**

`yonetici_ad`/`phone`/`password` alanlarını KALDIR; yerine:
1. "Tesis adı (opsiyonel)" → `form.ad`, hint: `Boş bırakırsanız yönetici ilk girişte kendisi belirler.`
2. "Yönetim maili (opsiyonel)" → `form.yonetim_email`, `type="email"`, hint: `Yönetici iletişim kartında herkese görünür.`
3. `form.yoneticiler.map((y, i) => ...)` ile satırlar; her satır: "Ad soyad" (required, minLength 2), "Cep telefonu (giriş anahtarı)" (required), "Parola (opsiyonel)" (minLength 8).
   - `i === 0` → başlık `Birincil yönetici` + hint `Tesisi ilk girişte adlandırır.`; **Kaldır butonu YOK**.
   - `i > 0` → başlık `Yönetici ${i + 1}` + "Kaldır" butonu.
4. Listenin altına "**+ Yönetici ekle**" butonu:
```tsx
<button type="button" onClick={() =>
  setForm({ ...form, yoneticiler: [...form.yoneticiler, { ...BOS_YONETICI }] })}>
  + Yönetici ekle
</button>
```
Kaldırma:
```tsx
onClick={() => setForm({
  ...form,
  yoneticiler: form.yoneticiler.filter((_, j) => j !== i),
})}
```
Statik metni ("Tesis adı burada girilmez — yönetici uygulamaya ilk girişte kendisi belirler.") SİL — artık yanlış.

- [ ] **Step 4: Submit**

```tsx
const body: TenantAdminCreate = {
  yoneticiler: form.yoneticiler.map((y) => ({
    ad: y.ad,
    phone: y.phone,
    ...(y.password ? { password: y.password } : {}),
  })),
};
if (form.ad.trim()) body.ad = form.ad.trim();
if (form.yonetim_email.trim()) body.yonetim_email = form.yonetim_email.trim();

const created = await apiSend<TenantAdminCreatedOut>("/api/tenants", "POST", body);

const kodlar = (created?.yoneticiler ?? []).filter((y) => y.temp_code);
if (kodlar.length) {
  window.alert(
    "Tesis + yöneticiler oluşturuldu.\n\nGeçici giriş kodları:\n" +
      kodlar.map((y) => `• ${y.ad}${y.birincil ? " (birincil)" : ""}: ${y.temp_code}`).join("\n") +
      "\n\nHer yönetici telefonu + kendi kodu ile girip kalıcı parolasını belirler.",
  );
}
```
Çakışma metni ("Bu telefon zaten kayıtlı.") eşlemesini KORU.

- [ ] **Step 5: Build + elle doğrula**

```bash
cd /home/kerem/tesis-platform/admin-web && npm run build
```
Expected: build başarılı. Ardından `npm run dev` ile admin olarak gir; "Yönetici ekle" ile 2 satırlı bir tesis oluştur; geçici kodların ikisinin de listelendiğini ve ilk satırın "birincil" işaretlendiğini gör.

- [ ] **Step 6: Commit**

```bash
git add admin-web/
git commit -m "feat(panel): tesis olusturmada yonetim maili + N yonetici

Opsiyonel 'Tesis adi' + 'Yonetim maili'; 'Yonetici ekle' ile coklu satir
(ilk satir = birincil, silinemez). Gecici kodlar yonetici adiyla eslenerek
listelenir. types.ts yeni POST /tenants sekline gore guncellendi (+ eksik
olan kurulum_tamamlandi alani eklendi).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019PQv4ATndrTUEpBNWypYmS"
```

---

### Task 12: Mobil — Yönetici İletişim ekranı

**Files:**
- Create: `mobile/lib/src/features/yonetici_iletisim/domain/yonetici_iletisim_models.dart`
- Create: `mobile/lib/src/features/yonetici_iletisim/data/yonetici_iletisim_api.dart`
- Create: `mobile/lib/src/features/yonetici_iletisim/presentation/yonetici_iletisim_screen.dart`
- Modify: `mobile/lib/src/routing/app_router.dart`, `mobile/lib/src/features/home/domain/home_menu.dart`, `mobile/lib/src/features/home/presentation/home_screen.dart`
- Modify: `mobile/test/home_menu_test.dart`
- Create: `mobile/test/yonetici_iletisim_test.dart`

**Interfaces:**
- Consumes: `GET /yonetici-iletisim` (Task 8); `callLauncherProvider.dial(String)`; `telUri(String)` (Task 1).
- Produces: `HomeMenuEntry.yoneticiIletisim`; `AppRoutes.yoneticiIletisim = '/yonetici-iletisim'`.

- [ ] **Step 1: Failing test yaz**

`mobile/test/home_menu_test.dart`'e ekle:
```dart
  test('Yonetici Iletisim yalniz saha rolleri + sakinde, EN SONDA', () {
    for (final role in [UserRole.security, UserRole.tesisGorevlisi, UserRole.resident]) {
      final entries = homeMenuForRole(role);
      expect(entries, contains(HomeMenuEntry.yoneticiIletisim), reason: '$role');
      expect(entries.last, HomeMenuEntry.yoneticiIletisim, reason: '$role sonda degil');
    }
    for (final role in [UserRole.yonetici, UserRole.admin]) {
      expect(homeMenuForRole(role), isNot(contains(HomeMenuEntry.yoneticiIletisim)),
          reason: '$role gormemeli');
    }
  });
```
`mobile/test/yonetici_iletisim_test.dart` (mevcut `call_button_test.dart`'taki fake launcher desenini izle):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tesis_mobile/src/features/call/data/call_launcher.dart';
import 'package:tesis_mobile/src/features/yonetici_iletisim/domain/yonetici_iletisim_models.dart';
import 'package:tesis_mobile/src/features/yonetici_iletisim/presentation/yonetici_iletisim_screen.dart';

class _FakeLauncher implements CallLauncher {
  String? dialed;
  @override
  Future<bool> dial(String telUri) async {
    dialed = telUri;
    return true;
  }
}

void main() {
  testWidgets('Yoneticiyi Ara -> tel: URI ceviriciye gider', (tester) async {
    final fake = _FakeLauncher();
    const kart = YoneticiKart(
      userId: 'u1', adSoyad: 'Ayse Yilmaz', telefon: '+90 532 111 22 01');

    await tester.pumpWidget(ProviderScope(
      overrides: [callLauncherProvider.overrideWithValue(fake)],
      child: const MaterialApp(
        home: Scaffold(body: YoneticiKartTile(kart: kart)),
      ),
    ));

    await tester.tap(find.text('Yöneticiyi Ara'));
    await tester.pump();

    expect(fake.dialed, 'tel:+905321112201');
  });

  testWidgets('telefonu olmayan yoneticide arama butonu yok', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: YoneticiKartTile(
            kart: YoneticiKart(userId: 'u2', adSoyad: 'Numarasiz', telefon: null)),
        ),
      ),
    ));
    expect(find.text('Yöneticiyi Ara'), findsNothing);
  });
}
```

- [ ] **Step 2: Testi çalıştır, BAŞARISIZ olduğunu gör**

Run: `cd mobile && flutter test test/yonetici_iletisim_test.dart test/home_menu_test.dart`
Expected: FAIL — dosya/enum yok.

- [ ] **Step 3: Model**

```dart
/// Yonetici iletisim dizini — `GET /yonetici-iletisim`.
library;

class YoneticiKart {
  const YoneticiKart({
    required this.userId,
    required this.adSoyad,
    this.telefon,
  });

  final String userId;
  final String adSoyad;

  /// Numara sunucudan ACIKCA doner (auth.md gizlilik istisnasi: yonetici
  /// hizmet rolüdür). C1a'daki gibi gizlenmez — kartta gosterilir.
  final String? telefon;

  factory YoneticiKart.fromJson(Map<String, dynamic> json) => YoneticiKart(
        userId: json['user_id'] as String,
        adSoyad: json['ad_soyad'] as String,
        telefon: json['telefon'] as String?,
      );
}

class YoneticiIletisim {
  const YoneticiIletisim({required this.yoneticiler, this.yonetimEmail});

  final List<YoneticiKart> yoneticiler;
  final String? yonetimEmail;

  factory YoneticiIletisim.fromJson(Map<String, dynamic> json) => YoneticiIletisim(
        yoneticiler: ((json['yoneticiler'] as List<dynamic>?) ?? const [])
            .map((e) => YoneticiKart.fromJson(e as Map<String, dynamic>))
            .toList(),
        yonetimEmail: json['yonetim_email'] as String?,
      );
}
```

- [ ] **Step 4: API**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/yonetici_iletisim_models.dart';

class YoneticiIletisimApi {
  YoneticiIletisimApi(this._dio);

  final Dio _dio;

  Future<YoneticiIletisim> getir() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/yonetici-iletisim');
      return YoneticiIletisim.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final yoneticiIletisimApiProvider = Provider<YoneticiIletisimApi>((ref) {
  return YoneticiIletisimApi(ref.watch(dioProvider));
});

final yoneticiIletisimProvider = FutureProvider<YoneticiIletisim>((ref) async {
  ref.watch(authControllerProvider.select((s) => s.status));
  return ref.watch(yoneticiIletisimApiProvider).getir();
});
```

- [ ] **Step 5: Ekran**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/tr.dart';
import '../../call/data/call_launcher.dart';
import '../../call/domain/tel_uri.dart';
import '../data/yonetici_iletisim_api.dart';
import '../domain/yonetici_iletisim_models.dart';

/// Yonetici iletisim dizini: tenant'in tum yoneticileri (birincil ilk) +
/// yonetim maili. Numara sunucudan acikca gelir (auth.md gizlilik istisnasi);
/// arama mevcut CallLauncher ile yapilir — tel: mantigi kopyalanmaz.
class YoneticiIletisimScreen extends ConsumerWidget {
  const YoneticiIletisimScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(yoneticiIletisimProvider);
    return Scaffold(
      appBar: AppBar(title: Text(trUpper('Yönetici İletişim'))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Yönetici bilgileri alınamadı.')),
        data: (d) {
          if (d.yoneticiler.isEmpty && (d.yonetimEmail ?? '').isEmpty) {
            return const Center(child: Text('Yönetici iletişim bilgisi tanımlı değil.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final k in d.yoneticiler) YoneticiKartTile(kart: k),
              if ((d.yonetimEmail ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: const Text('Yönetim maili'),
                    subtitle: Text(d.yonetimEmail!),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Tek yonetici karti — testte dogrudan pump edilebilsin diye ayri widget.
class YoneticiKartTile extends ConsumerWidget {
  const YoneticiKartTile({super.key, required this.kart});

  final YoneticiKart kart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = (kart.telefon == null) ? null : telUri(kart.telefon!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kart.adSoyad,
                style: Theme.of(context).textTheme.titleMedium),
            if (kart.telefon != null) ...[
              const SizedBox(height: 4),
              Text(kart.telefon!,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (uri != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final ok = await ref.read(callLauncherProvider).dial(uri.toString());
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Arama başlatılamadı')),
                    );
                  }
                },
                icon: const Icon(Icons.phone),
                label: const Text('Yöneticiyi Ara'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```
> `core/ui/tr.dart` (`trUpper`) yolunu mevcut bir ekrandan DOĞRULA; yoksa düz `Text('Yönetici İletişim')` kullan.

- [ ] **Step 6: Menü + rota**

`home_menu.dart` — enum'a ekle:
```dart
  /// Yonetici Iletisim — tenant'in yoneticileri (ad + telefon + arama) +
  /// yonetim maili. Saha rolleri + sakin gorur; YONETICI kendisi GORMEZ.
  yoneticiIletisim,
```
`security`, `tesisGorevlisi`, `resident` listelerinin **EN SONUNA** `HomeMenuEntry.yoneticiIletisim,` ekle. `yonetici`/`admin` listelerine EKLEME.

`home_screen.dart` `_tileData` switch'ine:
```dart
      case HomeMenuEntry.yoneticiIletisim:
        return (
          icon: Icons.contact_phone,
          title: 'Yönetici İletişim',
          onTap: () => context.push(AppRoutes.yoneticiIletisim),
          badge: null,
        );
```
`app_router.dart`:
```dart
  static const yoneticiIletisim = '/yonetici-iletisim';
```
```dart
    GoRoute(
      path: AppRoutes.yoneticiIletisim,
      builder: (context, state) => const YoneticiIletisimScreen(),
    ),
```

- [ ] **Step 7: Testler + build**

```bash
cd /home/kerem/tesis-platform/mobile
flutter analyze && flutter test && flutter build apk --debug
```
Expected: analyze 0 issue; testler PASS; APK derlenir.

- [ ] **Step 8: Commit**

```bash
git add -A mobile/
git commit -m "feat(iletisim): Yonetici Iletisim ekrani (saha rolleri + sakin)

Menu girisi (tab bar yok — rol ikon izgarasi) security/tesis_gorevlisi/
resident'te EN SONDA; yonetici kendini gormez. Kart: ad-soyad + telefon +
'Yoneticiyi Ara' -> mevcut CallLauncher (tel: mantigi kopyalanmadi).
CallButton KULLANILMADI: o /call-target'a cozumler ve numarayi kasten
gizler; bu kart numarayi gosterir (auth.md gizlilik istisnasi).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019PQv4ATndrTUEpBNWypYmS"
```

---

### Task 13: Mobil — birincil kapısı + ön-doldurma + ayarlardan yeniden adlandırma

**Files:**
- Modify: `mobile/lib/src/features/profile/domain/profile.dart` (+`birincil`)
- Modify: `mobile/lib/src/features/home/presentation/home_gate.dart`
- Modify: `mobile/lib/src/features/tenant/presentation/setup_tenant_screen.dart`
- Modify: `mobile/lib/src/features/tenant/data/tenant_api.dart` (+`updateAd`)
- Modify: `mobile/lib/src/features/settings/presentation/settings_screen.dart`

**Interfaces:**
- Consumes: `GET /me/profile.birincil`, `PATCH /tenant/settings {ad}` (Task 9).

- [ ] **Step 1: Profile modeline `birincil`**

`profile.dart`'taki profil sınıfına ekle (mevcut alan deseniyle):
```dart
  /// Tenant'in birincil yoneticisi mi? Tesisi ilk giriste adlandirma kapisi
  /// yalniz buna acilir (yonetici disi rollerde daima false).
  final bool birincil;
```
Constructor'a `this.birincil = false`, `fromJson`'a `birincil: json['birincil'] as bool? ?? false,` ekle.

- [ ] **Step 2: HomeGate — yalnız birincil**

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    if (role != UserRole.yonetici) return const HomeScreen();

    // Kapi YALNIZ BIRINCIL yoneticiye acilir; digerleri dogrudan ana ekran
    // (tesis adsizsa app-bar'da yer tutucu gorunur — bilincli karar).
    final profil = ref.watch(myProfileProvider);
    final birincil = profil.value?.birincil ?? false;
    if (!birincil) return const HomeScreen();

    return ref.watch(tenantSettingsProvider).when(
          data: (settings) => settings.kurulumTamamlandi
              ? const HomeScreen()
              : const SetupTenantScreen(),
          error: (_, _) => const HomeScreen(),
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        );
  }
```
> `myProfileProvider`ın gerçek adını `profile` feature'ından DOĞRULA. Yükleme sırasında `value` null → `birincil=false` → kısa süre HomeScreen; profil gelince kapı açılır. Hata → fail-open (mevcut desen).

- [ ] **Step 3: SetupTenantScreen ön-doldurma**

Controller'ı mevcut ada göre başlat — **yer tutucu ASLA gösterilmez**:
```dart
  static const _placeholder = '(Kurulum bekliyor)';

  late final TextEditingController _ad = TextEditingController(
    text: () {
      final ad = ref.read(tenantSettingsProvider).value?.ad ?? '';
      return ad == _placeholder ? '' : ad;
    }(),
  );
```
> `ConsumerStatefulWidget` değilse dönüştür; `initState` içinde `ref.read` güvenlidir.

- [ ] **Step 4: `tenant_api.dart` — `updateAd`**

```dart
  /// `PATCH /tenant/settings` — yonetici tesis adini degistirir (yalniz `ad`;
  /// baska alan gonderilirse backend 403 doner). slug DEGISMEZ.
  Future<TenantSettings> updateAd(String ad) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/tenant/settings',
        data: {'ad': ad},
      );
      return TenantSettings.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
```

- [ ] **Step 5: Ayarlar ekranı — Tesis bölümü**

`settings_screen.dart`'a, "Görünüm" bölümünün üstüne, YALNIZ `yonetici` rolünde:
```dart
    final role = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    ...
    if (role == UserRole.yonetici) ...[
      Text('Tesis', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      const _TesisAdiKarti(),
      const SizedBox(height: 24),
    ],
```
`_TesisAdiKarti`: `tenantSettingsProvider`ı izler, `TextFormField` (mevcut ad ile dolu) + "Kaydet" → `ref.read(tenantApiProvider).updateAd(ad)` → `ref.invalidate(tenantSettingsProvider)` → SnackBar `'Tesis adı güncellendi'`. Hata → `ApiException` mesajıyla SnackBar. Boş ad → Kaydet pasif.
> `settings_screen.dart` `ConsumerWidget` değilse dönüştür.

- [ ] **Step 6: Testler + build + elle doğrula**

```bash
cd /home/kerem/tesis-platform/mobile
flutter analyze && flutter test && flutter build apk --debug
```
Elle: birincil yönetici (`+905321112201` / `Yonetici123!`) → tesis adsızsa setup ekranı; ikinci yönetici (`+905321112206`) → setup GÖRMEZ. Ayarlar → Tesis adı değiştir → ana ekran app-bar'ı güncellenir.

- [ ] **Step 7: Commit**

```bash
git add -A mobile/
git commit -m "feat(tesis): adlandirma kapisi yalniz birincil yoneticide + ayarlardan yeniden adlandirma

HomeGate artik /me/profile.birincil'e bakiyor; birincil olmayan yonetici
dogrudan ana ekrani gorur. SetupTenantScreen mevcut adi on-doldurur — yer
tutucu '(Kurulum bekliyor)' ASLA kullaniciya gosterilmez. Ayarlarda yonetici'ye
ozel 'Tesis adi' alani -> PATCH /tenant/settings {ad} -> provider invalidate
-> app-bar guncellenir. slug degismez.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019PQv4ATndrTUEpBNWypYmS"
```

---

### Task 14: Contracts — yeni özelliklerin sözleşmesi

**Files:**
- Modify: `contracts/openapi.yaml`, `contracts/auth.md`, `contracts/README.md`

- [ ] **Step 1: openapi.yaml**

- `/yonetici-iletisim` GET path'i (200 → `YoneticiIletisimOut`; 401) + `YoneticiKart`/`YoneticiIletisimOut` şemaları.
- `TenantAdminCreate`: `required: [yoneticiler]`, `ad`/`yonetim_email` nullable, `yoneticiler` → `YoneticiCreate` dizisi (`minItems: 1`). Yeni `YoneticiCreate`, `YoneticiCreatedOut`; `TenantAdminCreatedOut` → `{tenant_id, yoneticiler[]}`.
- `TenantSettings`: `+yonetim_email`. `TenantSettingsUpdate`: `acil_durum_telefon` çıktı (Task 3), `+yonetim_email`; açıklamaya "admin: hepsi; yonetici: yalniz ad (aksi 403)".
- `MeProfileOut`: `+birincil`.
- `/tenant/setup` açıklaması: "YALNIZ birincil yonetici (aksi 403); zaten kuruluysa 409".

- [ ] **Step 2: auth.md — matris satırları**

```
| GET /yonetici-iletisim | ✅ | ✅ | ✅ | ✅ | ✅ |
```
(beş rolün beşi de; tenant üyeliği yeterli). `PATCH /tenant/settings` satırını: admin ✅ (tüm alanlar), yonetici ✅ (yalnız `ad`), diğerleri ❌. `POST /tenant/setup`: yalnız **birincil** yonetici ✅.

- [ ] **Step 3: auth.md — gizlilik istisnası notu**

Rol-bazlı arama (C1a) bölümünün SONUNA:
```markdown
- **YONETICI ILETISIM KARTI (`GET /yonetici-iletisim`) — BILINCLI C1a ISTISNASI:**
  bu uc, yukaridaki UC KAPIYI (YON + RIZA + NUMARA VARLIGI) ve "listede numara
  YOK" kuralini YALNIZ yonetici kartlari icin deler: tenant'in HERHANGI bir
  kimlikli uyesi tum aktif yoneticilerin `ad_soyad` + `telefon` bilgisini ve
  tenant'in `yonetim_email`ini gorur.
  - **GEREKCE:** `yonetici` bir HIZMET rolüdür (kisisel iletisim degil); numarayi
    admin, tesis olusturulurken BILEREK girer; sahadaki personelin ve sakinin
    yonetime ulasabilmesi urun geregidir.
  - **KAPSAM (dar):** YALNIZ bu uc, YALNIZ `role='yonetici'` kullanicilar,
    YALNIZ `ad_soyad`+`telefon`. `aranabilir` rizasi bu ucta YOKSAYILIR —
    yonetici rizayi kaldirsa bile kartta listelenir.
  - **DEGISMEYENLER:** C1a modeli baska HER SEY icin aynen gecerlidir —
    `/call-target` uc kapili kalir; `GET /users` numara tasimaz; `PATCH
    /me/contact` rizasi diger roller icin baglayicidir. Yoneticilere kayitta
    `aranabilir=true` verilir ki `/call-target` de tutarli calissin.
  - **UX:** mobil kartta numara METIN olarak gorunur ve `tel:` ile aranir
    (`CallButton` DEGIL — o numarayi kasten gizler; paylasilan parca
    `CallLauncher`dir).
```

- [ ] **Step 4: auth.md — birincil + adlandırma kuralları**

`yonetici` rol notuna (L426 civarı) ekle:
```markdown
  - **BIRINCIL yonetici (`app_user.birincil`):** tenant olusturulurken girilen
    ILK yonetici birincildir (`uq_app_user_birincil` kismi unique index: tenant
    basina EN FAZLA bir). Tesisi ILK GIRISTE adlandirma kapisi (`POST
    /tenant/setup`) YALNIZ ona acilir (digeri 403); mobil kapi da yalniz ona
    gosterilir. Birincil olmayan yonetici, tesis adsizken ana ekrani gorur
    (engelleyici ekran YOK — bilincli).
  - **Tesis adini degistirme:** TUM yoneticiler `PATCH /tenant/settings {ad}`
    ile yeniden adlandirabilir (admin de). `timezone`/`yonetim_email` admin'de
    kalir — yonetici gonderirse 403. **`slug` ve tenant `id` ASLA degismez.**
  - **Bireysel kullanici silme ucu YOKTUR** (yalniz `DELETE /tenants/{id}` tum
    tenant'i siler; kullanici pasiflestirilir). Bu yuzden "birincil silinince
    terfi" senaryosu olusmaz; pasiflestirme birincil bayragini DEGISTIRMEZ.
```

- [ ] **Step 5: contracts/README.md**

`tenant.yonetim_email` + `app_user.birincil` + `uq_app_user_birincil` açıklaması; uç listesine `/yonetici-iletisim`.

- [ ] **Step 6: Commit**

```bash
git add contracts/
git commit -m "docs(sozlesme): yonetici-iletisim + coklu yonetici + birincil + tesis adi

openapi: /yonetici-iletisim + semalar; TenantAdminCreate coklu yonetici;
TenantSettings.yonetim_email; MeProfileOut.birincil.
auth.md: matris satirlari + C1a gizlilik ISTISNASI (dar kapsam: yalniz bu uc,
yalniz role=yonetici, aranabilir yoksayilir; C1a baska her seyde korunur) +
birincil/adlandirma kurallari + 'bireysel silme ucu yok' invaryanti.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_019PQv4ATndrTUEpBNWypYmS"
```

---

### Task 15: Uçtan uca doğrulama

**Files:** Yok (yalnız doğrulama + gerekirse düzeltme).

- [ ] **Step 1: Temiz kurulum + seed + tüm testler**

```bash
cd /home/kerem/tesis-platform/infra
docker compose down -v && docker compose up -d --build
docker compose --profile seed run --rm seed
cd /home/kerem/tesis-platform/backend && python -m pytest -q
```
Expected: tümü PASS. **SKIP = geçmiş DEĞİL** — skip varsa API ayakta değildir, düzelt ve tekrar çalıştır.
> `test_rezervasyon` 21:xx'te saat-flake verirse: bu işle ilgisiz (bilinen sorun), 22:00 sonrası tekrar dene.

- [ ] **Step 2: Mobil + web**

```bash
cd /home/kerem/tesis-platform/mobile && flutter analyze && flutter test && flutter build apk --debug
cd /home/kerem/tesis-platform/admin-web && npm run build
```
Expected: hepsi başarılı.

- [ ] **Step 3: SOS artığı kalmadığını doğrula**

```bash
cd /home/kerem/tesis-platform
grep -rni "emergency\|acil_durum\|acil durum\|panik" \
  backend/ mobile/lib mobile/test admin-web/app admin-web/lib admin-web/components \
  contracts/ docs/CIHAZ-TESTI.md infra/ \
  | grep -v "docs/superpowers" | grep -v "test_sos_kaldirildi"
```
Expected: boş çıktı.

- [ ] **Step 4: slug/ID değişmezliğini DB'den doğrula**

```bash
cd /home/kerem/tesis-platform/infra
docker compose exec -T db psql -U tesis_owner -d tesis -c \
  "SELECT id, ad, slug FROM tenant WHERE slug='acme-plaza';"
```
`ad`ı mobil ayarlardan değiştir, sonra AYNI sorguyu tekrar çalıştır: `id` ve `slug` AYNI, yalnız `ad` değişmiş olmalı.

- [ ] **Step 5: Kabul kriterleri — elle akış**

1. Panelde admin: "Tesis adı" + "Yönetim maili" + 2 yönetici ile tesis oluştur → iki geçici kod listelenir, ilki "birincil".
2. Mobilde birincil yönetici girer → setup ekranı, ad ÖN-DOLU (admin girmişse) → onayla → ana ekran.
3. İkinci yönetici girer → setup ekranı GÖRMEZ.
4. Güvenlik/sakin/tesis görevlisi → menüde EN ALTTA "Yönetici İletişim" → iki yönetici kartı (birincil ilk) + yönetim maili → "Yöneticiyi Ara" çeviriciyi açar.
5. Yönetici → Ayarlar → Tesis adı değiştir → ana ekran app-bar'ı + panel listesi yeni adı gösterir.
6. Hiçbir rolde acil durum/panik girişi YOK.

- [ ] **Step 6: Push**

```bash
cd /home/kerem/tesis-platform && git push origin main
```

## Self-Review

**Spec kapsamı** — her bölüm bir task'a bağlı: Değişiklik 1 → Task 1-5; Değişiklik 2 → Task 8 (backend), 12 (mobil), 14 (sözleşme); Değişiklik 3 → Task 6 (migration), 7 (backend), 11 (panel); Değişiklik 4 → Task 6 (birincil), 9 (backend), 13 (mobil); Seed → Task 10; Testler → ilgili task'lara gömülü + Task 15. Boşluk yok.

**Tip tutarlılığı** — `TenantSettings` (Task 1: `tenantId`/`ad`/`kurulumTamamlandi`, `acilDurumTelefon` YOK) Task 13'te aynı; `YoneticiKart` (Task 8 backend `user_id`/`ad_soyad`/`telefon` ↔ Task 12 mobil `userId`/`adSoyad`/`telefon`) tutarlı; `birincil` Task 6 (DB) → 9 (API) → 13 (mobil) boyunca aynı ad.

**Spec'ten düzeltilen iki hata:** (1) seed'in ikinci yönetici telefonu 204 **değil 206** — 204 zaten Acme Cleaner'da ve `telefon` global benzersiz; (2) `/tenant/setup` + `PATCH /tenant/settings` `update_tenant_ad`ı KULLANMAZ — ORM ile yazarlar (o fonksiyon admin'in cross-tenant ucuna ait). İkisi de spec'te düzeltildi.

**Bilinen risk (Task 7, Step 4):** `create_tenant_with_yoneticis` sonrası yönetici id'lerini okuma `SessionLocal()` (tenant context'siz) ile yapılır; RLS 0 satır döndürürse çözüm adımda yazılı — `ad`/`birincil`i fonksiyonun `RETURNING`inden döndür (SECURITY DEFINER RLS'i bypass eder). Eşleme HER durumda `telefon` ile yapılmalı; `INSERT ... RETURNING` satır sırası garanti değildir.
