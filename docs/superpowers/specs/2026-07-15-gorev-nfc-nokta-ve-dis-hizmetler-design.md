# Göreve NFC noktası bağlama + Dış Hizmetler

**Tarih:** 2026-07-15
**Kapsam:** Kullanıcının iki isteği: (1) görevi NFC okutarak tamamlama (eksik olan
tek parça: göreve nokta bağlama UI'ı), (2) Dış Hizmetler bölümü (güvenilir esnaf
listesi + yönetici notu).

## Feature 1 — Göreve kontrol noktası (NFC) bağlama
**Mevcut:** Görev tamamlama akışı `nfc_tag_uid`'i görevin `checkpoint_id`'siyle
doğruluyor; mobil tamamlama ekranı NFC adımını `task.checkpointId != null` iken
gösteriyor. Backend `TaskCreate`/`TaskUpdate` `checkpoint_id` kabul ediyor.
**Eksik:** mobil görev formunda checkpoint seçimi YOK → hiçbir göreve nokta
bağlanamıyor → NFC adımı tetiklenmiyor.

**Değişiklik (yalnız mobil):**
- `task_form_sheet`'e **"Kontrol noktası (NFC)"** dropdown'ı: `checkpointsProvider`
  (Parça D) aktif noktalar + "— yok —". Seçim `checkpoint_id` olarak create/edit'te
  gider (null = yok).
- Sonuç: yönetici göreve nokta bağlarsa, o görevi tamamlayan saha çalışanı
  tamamlamadan önce NFC okutur (mevcut `_NfcStep` + backend doğrulama). Backend
  değişikliği YOK.

**Test:** mobil widget — form'da checkpoint seçici var; seçilince checkpoint_id
gönderilir. (Backend NFC-tamamlama zaten test_tasks'ta kapsanıyor.)

## Feature 2 — Dış Hizmetler
Site yöneticisinin güvendiği esnaf/hizmet kişilerini (çilingir, elektrik, tesisat…)
girdiği bölüm + bir açıklama notu ("yıllardır güvendiğimiz esnaflar; site güvenliği
için yabancı kişileri sokmayın" gibi). Görünürlük: **yönetici + güvenlik + sakin**
okur; **yönetici + admin** yazar.

### Backend
**Migration (0001 içine):**
- Yeni tablo `dis_hizmet`: `id`, `tenant_id` (FK CASCADE, RLS), `tur` (text),
  `ad` (text), `soyad` (text), `telefon` (text), `aciklama` (text null),
  `created_at`, `updated_at`. RLS FORCE + tenant policy (diğer tablolarla aynı).
- `tenant` tablosuna `dis_hizmet_notu text` (nullable) kolonu.

**Router `/external-services`:**
- `GET /external-services` → `{ not: str|null, items: [DisHizmetOut] }`. RBAC:
  admin/yonetici/security/resident (tüm mobil roller). Sıra: tur, ad.
- `POST /external-services` (admin+yonetici) → DisHizmetCreate → 201.
- `PATCH /external-services/{id}` (admin+yonetici) → DisHizmetUpdate (kısmi).
- `DELETE /external-services/{id}` (admin+yonetici) → 204.
- `PUT /external-services/note` (admin+yonetici) → `{ not: str|null }` → notu ayarla.

**Şemalar:** DisHizmetCreate (tur, ad, soyad, telefon zorunlu; aciklama ops.),
DisHizmetUpdate (kısmi), DisHizmetOut, DisHizmetListResponse (`not` + `items`),
DisHizmetNoteUpdate (`not`).

### Mobil
- Yeni menü **"Dış Hizmetler"** (`home_menu`): yönetici + security + resident.
- `dis_hizmet_api` (GET liste+not, POST/PATCH/DELETE, PUT note) + model.
- Ekran: üstte **not kartı** (yönetici "Düzenle" ile değiştirir), altında **türe
  göre** kişi listesi — ad soyad · tür · açıklama + **`tel:` arama** butonu.
  Yönetici FAB "Kişi ekle" + satırda PopupMenu (Düzenle/Sil). Güvenlik/sakin
  salt-okuma (yalnız görür + arar).

### Contracts
openapi.yaml (path'ler + şemalar) + auth.md (RBAC satırları).

### Testler (backend `test_external_services.py`)
- yönetici kişi ekler/düzenler/siler; not ayarlar → GET'te döner.
- GET tüm roller (admin/yonetici/security/resident) 200; yazma yalnız admin+yonetici
  (security/resident → 403).
- tenant izolasyonu (RLS).

## Sıra
Feature 1 (küçük mobil) + Feature 2 (backend→mobil) birlikte, tek epik commit'i
(veya ikisi ayrı commit). Migration değiştiği için tam döngü (`down -v`) gerekir.

## Riskler
- Migration değişikliği → test için `down -v` + seed + full/targeted pytest.
- `tel:` arama: mevcut CallButton `/call-target` rıza kapısına bağlı; dış hizmet
  telefonu KVKK kapsamı DIŞI (esnaf, site sakini değil) → düz `tel:` link kullan
  (rıza kapısı YOK).
