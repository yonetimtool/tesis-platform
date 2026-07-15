# Güvenlik "Turlarım": bugünün turları + anında tamamlanma

**Tarih:** 2026-07-15
**Sorun:** Güvenlik "Turlarım > Aktif" yalnız TAM O AN aktif pencereyi gösteriyor;
tur o dakika aktif değilse "pencere yok" diyor. Ayrıca tur ancak pencere bitince
(5 dk'lık tespit görevi) 'tamamlandı' oluyor.

## Onaylanan kararlar
- **Aktif = bugünün TÜM turları** (her pencere X/N ilerlemesiyle; aktif olan
  taranabilir, geçmiş/gelecek durumlarıyla görünür).
- **Tamamlanma = hepsi okutulunca HEMEN** (pencere bitmesini beklemeden).

## Backend
### 1. `GET /me/patrol-window` — bugünün pencereleri
- WHERE `pencere_baslangic <= now AND pencere_bitis > now` (aktif) → BUGÜN'e
  ait (tenant tz gün sınırı) tüm pencereler: `pencere_bitis > :day_start AND
  pencere_baslangic < :day_end`. Her pencere checkpoint + canlı okutma durumuyla.
- `window`/`checkpoints` (odak) = ŞU AN aktif pencere (varsa; tarama odağı), yoksa
  null. `windows[]` = bugünün tüm pencereleri (sıralı). Response şeması aynı.
- RBAC değişmez (admin + security).

### 2. `POST /scans` — anında tamamlanma
- Tarama kaydedildikten sonra: taranan checkpoint'in planlarına ait, taramanın
  zaman aralığını içeren AKTİF ('bekliyor') pencereler için — planın TÜM aktif
  checkpoint'leri o pencerede taranmışsa pencere durum='tamamlandi' yapılır
  (scheduler'ın tamamlandı tanımıyla aynı; ama pencere-bitişini beklemeden).
- Boş plan (checkpoint yok) dokunulmaz (scheduler zaten bitişte vacuously
  tamamlar). detect_missed 'kacirildi' mantığı değişmez.

## Mobil
- `patrol_screen` "Aktif" sekmesi: bugünün pencereleri LİSTESİ. Her kart: plan adı
  · saat aralığı · X/N · durum rozeti (Şimdi aktif / Yaklaşan / Bitti / Tamamlandı
  / Kaçırıldı). Nokta okut (NFC) butonu YALNIZ aktif pencere seçiliyken. Seçili
  pencerenin checkpoint listesi + okutuldu ✓. Boş-durum metni: bugün plan yoksa.
- "Geçmiş" sekmesi: BUGÜNDEN ÖNCEKİ pencereler (bugün Aktif'te; Geçmiş yalnız
  geçmiş). `GET /patrol-windows` mevcut; mobil bugün-öncesi filtreler (veya bitis
  parametresi).

## Testler
- Backend: /me/patrol-window bugünün TÜM pencerelerini döner (aktif olmayan dahil);
  scan ile son checkpoint okutulunca pencere ANINDA 'tamamlandi'; eksik varsa
  'bekliyor' kalır. Mevcut me_patrol/scans testleri güncellenir.
- Mobil analyze/test yeşil.

## Riskler
- Gece vardiyasi (baslangic>bitis) pencereleri gece yarisini asar; "bugün" gün
  siniri overlap ile alinir (bitis>day_start AND baslangic<day_end). Post-gece-yarisi
  pencereler ertesi güne düşebilir — kabul (nadir; ana akış same-day).
- Migration YOK.
