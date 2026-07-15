# Yönetici devriye planı (checkpoint kümesi + saatler + tur sıklığı)

**Tarih:** 2026-07-15
**Kapsam:** Yönetici, "Devriye takibi" ekranından her gün tekrar eden devriye
planı oluşturur/düzenler/siler: ad + başlangıç/bitiş saati + tur sıklığı (dk) +
kontrol noktaları (TÜMÜ veya spesifik). Scheduler pencereleri üretir, saha okutur,
yönetici gün-gün takip eder (mevcut akış).

## Onaylanan kararlar
- Plan **her gün tekrar eden** (mevcut patrol_plan modeli: baslangic_saat/
  bitis_saat + periyot_dakika). Yönetici saatleri + noktaları düzenler, siler.
- **Tur sıklığı** (periyot_dakika) yöneticinin girdiği alan (ör. 60 = saatte bir).

## Mevcut altyapı (hazır)
- `patrol_plan`: ad, shift_id (opsiyonel), baslangic_saat, bitis_saat,
  periyot_dakika, aktif. Checkpoint atama `PUT /patrol-plans/{id}/checkpoints`
  (sirali). Scheduler plandan patrol_window üretir; saha `POST /scans` ile okutur.
- Yönetici `GET /patrol-windows` (takip) + Parça D `GET /scans` (gün-gün rapor)
  ZATEN görebiliyor.
- **Eksik:** patrol_plan CRUD + checkpoint atama **admin-only**; yönetici plan
  OKUYAMIYOR bile. Mobilde plan oluşturma UI'ı yok.

## Backend (yalnız RBAC — migration YOK)
`app/routers/patrol_plans.py`:
- `_READER` (GET list/detail/checkpoints): admin/security/tesis_gorevlisi'ye
  **+ yonetici** eklenir.
- POST/PATCH/DELETE + `PUT /{id}/checkpoints`: `_ADMIN` → **admin + yonetici**
  (`_WRITER`). shift_id opsiyonel kaldığı için shift'siz plan serbest.
Şema değişikliği yok (PatrolPlanCreate zaten tüm alanları taşır).

## Mobil
- "Devriye takibi" AppBar'ına **"Devriye planları"** aksiyonu (Kontrol noktaları
  deseniyle) → `PatrolPlansScreen`.
- `patrol_plan_api`: PatrolPlan model + list/create/update/delete + getCheckpoints
  + setCheckpoints (checkpoint_ids sirali).
- `PatrolPlansScreen`: plan listesi (ad · saat aralığı · her N dk · nokta sayısı ·
  aktif) + FAB "Plan ekle" + satırda PopupMenu (Düzenle/Sil).
- `PatrolPlanForm`: ad, başlangıç saati (TimePicker), bitiş saati, tur sıklığı
  (dk), aktif switch + **kontrol noktası çoklu seçim** ("Tümü" düğmesi + tek tek).
  Kaydet: POST/PATCH plan → `PUT /{id}/checkpoints` (seçili noktalar, sira=index).

## Contracts
auth.md: patrol_plan CRUD + checkpoints satırlarına yonetici ✅. openapi
summary'leri (admin → admin+yonetici) küçük güncelleme.

## Testler (backend `test_patrol_plans.py`/yeni)
- yönetici plan oluşturur/düzenler (saat/periyot)/siler → 200/201/204 (artık admin
  değil). Checkpoint atar (`PUT`) → 200. Saha/resident yazamaz → 403; yönetici okur.
- Mobil analyze/test yeşil (menü/route testleri güncellenir gerekirse).

## Riskler
- Migration YOK → hedefli testler yeterli (down -v gerekmez; saat-flake'ten kaçın).
- Checkpoint "Tümü": mobil aktif checkpoint'lerin tümünü sira ile atar.
