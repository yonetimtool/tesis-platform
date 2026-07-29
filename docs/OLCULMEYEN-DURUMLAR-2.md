# Ölçülmeyen durumlar — ikinci envanter (tur 49)

**Tarih:** 2026-07-29 · **Kapsam:** mobil (Flutter) + panel (admin-web) + veri

Tur 36'nın envanteri (A–F) tur 37–48 arasında **kapatıldı**. Bu belge, o
kapanıştan **sonra** kalan kör noktaları listeler. Yine tahmin yok: her madde
kapsam (coverage) verisinden, canlı sayfadan, veritabanı sayımından ya da
sürüş araçlarının kendi kodundan geliyor.

**Mobil presentation kapsamı: 9 001 / 13 302 = %67,7.**
Panelde 26 sayfanın 25'i en az bir sürüş listesinde.

---

> **GÜNCELLEME (tur 50).** A'nın büyük kısmı kapatıldı: 7 eylem zinciri beş
> eksende sürülüyor (personel/sakin menü eylemleri + vardiya atama). Bir
> **layout assertion** bulundu (`ListTile.trailing` 320 dp'de tile'ı yiyor).
> Açık kalan: `assets` `_ScannedCard`/`_HistoryCard` (NFC ile okutulmuş
> demirbaş durumu) ve fotoğraf seçiminden **vazgeçme** dalı.

## A. Kullanıcı EYLEMİ sonrası durumlar (en büyük küme)

Sürüşler ekranı çiziyor (tur 23–37), formu açıyor (tur 38), fotoğraf
yüklüyor (tur 39), onay diyaloğunu açıyor (tur 40). Ama **satır menüsü →
eylem → sonuç** zinciri hiç yürütülmüyor. Kapsam açıkları tam bu bloklarda
toplanıyor:

| Blok | Açık satır | Ne kaçırılıyor |
|---|---|---|
| `staff_screen` satır menüsü + parola sıfırlama | 132‑155, 159‑187 | personeli pasifleştirme, geçici kod diyalogu |
| `residents_screen` sil / parola sıfırla / düzenle sayfası | 112‑152, 213‑239 | sakin düzenleme alt sayfası hiç çizilmiyor |
| `assets_screen` `_ScannedCard`, `_HistoryCard` | 137‑192, 264‑302 | NFC ile okutulan demirbaş kartı ve zimmet geçmişi |
| `vardiyalar_screen` `_AtamaSheet` | 116‑193 | vardiya atama alt sayfası |
| foto seçiminden VAZGEÇME dalı (`file == null`) | 4 ekranda | kullanıcı kamerayı kapatınca ne oluyor |

> **GÜNCELLEME (tur 51).** `set_password_screen` kapatıldı: dört hâl beş
> eksende sürülüyor, kapsam %1 → **%88**. Açık kalan tek dosya
> `task_ticket_widgets` (1/60).

## B. Hiç çizilmemiş kalan iki dosya

| Dosya | Kapsam | Not |
|---|---|---|
| `auth/presentation/set_password_screen.dart` | **1 / 83** | tur 36'da listelenmişti, hâlâ açık: geçici parola → kalıcı parola akışı (ilk giriş!) |
| `tasks/presentation/task_ticket_widgets.dart` | **1 / 60** | talepten gelen iş emri rozetleri |

## C. Panelde mutasyon akışları

Bütün panel sürüşleri **yalnız okuma** yapıyor: `rapor-surusu` ve
`foto-surusu` birer düğmeye basıyor, gerisi GET. Dolayısıyla ölçülmeyenler:

* **oluşturma/güncelleme/silme sonrası** durumlar (başarı toast'ı, listenin
  tazelenmesi, satırın kaybolması),
* **doğrulama hataları** (422 alan hataları formda nasıl görünüyor),
* **çakışma** (409 — aynı kaydı iki sekmede düzenleme),
* **oturum düşmesi** (401 mid-session → `/login`e yönlendirme).
* `/tenants/[id]` **hiçbir sürüş listesinde yok** (26 sayfanın 1'i).

## D. Eksen değerleri sabit — ölçülmeyen kombinasyonlar

| Eksen | Ölçülen | Ölçülmeyen |
|---|---|---|
| Hareket | `reducedMotion: reduce` (panel), `pumpAndSettle` (mobil) | **animasyon sürerken** hiçbir şey ölçülmüyor — tur 30'da tam bu yanlış alarm vermişti, şimdi kör nokta |
| Yön | dikey (mobil), yatay yok | tablet/yatay yerleşim; kamera ekranı yatayı zorluyor ama ölçülmüyor |
| Yazı ölçeği | 1.0 ve 2.0 | 0.85 (küçültme), 1.3 (yaygın ara değer) |
| Genişlik | 320/430 (mobil), 360/1280 (panel) | tablet (768), ultra-geniş (1920+) |
| Yoğunluk | `devicePixelRatio = 1.0` | 2.0/3.0 (gerçek cihazlar) — piksel kırpma/kenar yuvarlama |
| Sistem ayarı | tema (açık/koyu) | **kalın yazı** (bold text), yüksek kontrast, renk körlüğü filtreleri |

> **GÜNCELLEME (tur 52).** B kapandı (`task_ticket_widgets` %2 → %96).
> **YENİ KÖR NOKTA (E'ye eklendi):** `textContrastGuideline` küçük/ince
> metinde yetersiz — sabit renk + tint zemin kalıbı koyu temada 2.06:1
> verirken kılavuz geçiyor. Bu kalıp `lib/src` içinde **29 yerde daha** var
> (`withValues(alpha: 0.1x)` ile tint zemin): complaints (3), transparency
> (2), reports (2), patrol_tracking (2), etkinlik (2), … Elle hesap ya da
> daha sıkı bir ölçüm gerekiyor.

## E. Kalite eksenleri (hiç kurulmamış)

* **Anlamsal okuma SIRASI.** Etiketlerin *varlığı* ölçüldü (tur 29/30), sırası
  değil. Ekran okuyucu yanlış sırada okuyabilir.
* **Canlı bölge duyurusu.** SnackBar/hata metinleri ekran okuyucuya
  duyuruluyor mu (`liveRegion` / `SemanticsService.announce`)? Kodda **hiç
  kullanılmıyor** — tur 45'te eklenen push SnackBar'ı da sessiz.
* **Görsel regresyon.** Tek bir golden testi var
  (`test/tools/home_referans_golden_test.dart`); geri kalan 46 ekranın
  görünümü hiçbir yerde kilitli değil.
* **Performans.** Uzun listede kaydırma, büyük fotoğrafın bellek etkisi.

## F. Veri durumu — hâlâ boş ya da BAYATLAYAN

| Durum | Şu an | Not |
|---|---|---|
| `unit_access_permission` | **0 kayıt** | daire erişim izni listesi hâlâ boş (tur 36'da da açıktı) |
| complaint `reddedildi` | yok | dört durumdan biri hiç görülmedi |
| kargo `teslim_alindi` | yok | |
| `patrol_window` `bekliyor` | **artık yok** | seed "bugün" penceresi açtı, zamanla `kacirildi`ya döndü |

> **SEED ZAMAN İÇİNDE BAYATLIYOR** — bu ayrı bir kör nokta sınıfı. Tur 41'de
> eklenen "bugün aktif tur" penceresi artık kaçırılmış görünüyor; yani
> `/dashboard`ın **aktif tur** hâli bugün sürülse yine boş çıkar. Sabit
> tarihli seed verisi, ölçümün sonucunu **takvime bağımlı** yapıyor.

## Kör nokta OLMAYANLAR (bilerek dışarıda)

* Backend uçlarının kendisi — 762 pytest testi kapsıyor.
* `data/*_api.dart` düşük kapsam — sürüşler API'yi bilerek sahteliyor.
* Para biçimi (TL + Türkçe gruplama) dile duyarsız — politika.

## Öneri sırası (etkiye göre)

1. **Eylem zincirleri** (A) — kapsam açığının en büyük kümesi, hepsi gerçek
   kullanıcı yolları.
2. **`set_password_screen`** (B) — ilk girişin tek yolu, hâlâ 1/83.
3. **Panelde mutasyon + 401/409** (C).
4. **Seed'in bayatlaması** (F notu) — "bugün" verisi koşum anına göre
   üretilmeli; aksi hâlde ölçüm takvime bağlı.
5. **Canlı bölge duyurusu** (E) — küçük değişiklik, ekran okuyucu için büyük
   fark.
6. Kalan eksen kombinasyonları (D).
