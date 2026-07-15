# Görev tipi: sabit enum → yönetici-tanımlı kategoriler (+ "Diğer")

Tarih: 2026-07-15 · Kapsam: migration + backend(3 router) + landscape SİL + reports + seed + contracts + mobil(~9) · Branch: main

## Kararlar (onaylandı)

- **(A) Sabit `task_tip` enum'u KALDIRILIR.** Görev sınıflandırması = `kategori_id`
  (yönetici-tanımlı `task_category`). **`kategori_id = null` → "Diğer".**
- **K1:** Peyzaj/landscape (`GET /landscape/schedule`, `tip='peyzaj'`) tamamen SİLİNİR
  (router + main kaydı + contract + matris + test).
- **K2:** Onboarding — yönetici hiç kategori tanımlamadıysa görev formunda
  "önce tiplerini tanımla" yönlendirmesi; tanımlayana kadar yalnız "Diğer".
- Rapor ("Görev özeti") tip yerine **kategori bazlı** sayıma döner (+ "Diğer").

## Backend

### Migration (`0001_initial_schema.py`)
- `CREATE TYPE task_tip ...` **kaldır**; `task.tip task_tip NOT NULL` kolonu **kaldır**;
  `ix_task_tip` **kaldır**; `ix_task_takvim` → `(tenant_id, sonraki_planlanan)`
  (tip'siz). `kategori_id` + `periyot_dakika` + `sonraki_planlanan` KALIR.

### `tasks.py`
- `TaskCreate`/`TaskUpdate`'ten `tip` çıkar; liste filtresi `?tip=` → `?kategori_id=`
  (özel değer `"diger"` → `kategori_id IS NULL`). `_ensure_kategori_in_tenant` kalır.
- Task çıktısında `kategori_id` + `kategori_ad` döner (join).

### `task_completions.py`
- Rapor (`GorevOzet` benzeri) tip-kırılımı yerine **kategori bazlı**: completion →
  task → kategori join, `GROUP BY kategori`; `{ kalemler: [{kategori_ad, sayi}], diger, toplam }`.
  (kategori_id NULL → "Diğer".)

### landscape (SİL)
- `app/routers/landscape.py`, `main.py` include, `tests/test_landscape.py`,
  openapi `/landscape/schedule` + şema, auth.md matris satırı + not.

### seed.py
- Görev oluşturmadan `tip` çıkar; birkaç `task_category` (örn. "Temizlik",
  "Kontrol", "Peyzaj") + görevlere `kategori_id` ata (bazıları kategorisiz = Diğer).

## Contracts
- `openapi.yaml`: Task/TaskCreate/TaskUpdate/TaskOut'tan `tip` çıkar; `?tip` → `?kategori_id`;
  `/landscape/schedule` + `LandscapeItem` sil; task-completions rapor şeması kategori bazlı.
- `auth.md`: `GET /landscape/schedule` matris satırı + peyzaj notu sil.

## Mobil (~9 dosya)
- `domain/task_models.dart`: `TaskTip` enum + `taskTipFromJson` **kaldır**; `Task.tip`
  ve `TaskDraft.tip` kaldır; `Task.kategoriId`/`kategoriAd` kullan.
- `presentation/task_tip_style.dart` → **kategori-stil**: ad'dan deterministik renk;
  "Diğer" nötr.
- `task_form_sheet.dart`: sabit tip seçici KALK; birincil seçim = yönetici kategorileri
  + "Diğer" (kategoriId null). **Onboarding:** kategori yoksa "önce tip tanımla"
  yönlendirmesi (Kategoriler ekranına buton) + yalnız "Diğer" ile devam.
- `tasks_screen.dart`: filtre çubuğu sabit tip yerine kategoriler + "Diğer";
  tile'da kategori adı/rengi.
- `tasks_controller.dart`: `tipFilter` → `kategoriFilter` (kategori_id | "diger" | null).
- `task_api.dart`: create/query `tip` yerine `kategori_id`.
- `task_detail_screen.dart`: tip yerine kategori göster.
- `reports`: `GorevOzet` (sabit alanlar) → kategori listesi; `reports_screen` render.
- Testler: `task_models_test` (TaskTip kalkar) güncellenir; landscape mobilde yok.

## Test
- `test_tasks.py`: `tip` kalkar; `?kategori_id=` + `"diger"` filtresi; create kategori ile.
- `test_task_completions.py`: rapor kategori bazlı.
- `test_landscape.py` **silinir**.
- `flutter analyze` temiz; task/report mobil testleri geçer.
- Full `down -v && up --build && seed && pytest` (gündüz saat penceresi tercih).

## Kabul
Yönetici görev açarken kendi tanımladığı tiplerden (veya "Diğer") seçer, tip ekler;
sabit tipler yok; peyzaj/landscape kaldırıldı; rapor kategori bazlı; testler yeşil.
