# Ölçülmeyen durumlar (tur 36 envanteri)

> **BU BELGE KAPANDI (tur 45).** A–F bölümlerinin tamamı tur 37–48 arasında
> kapatıldı. Kapanıştan SONRA kalan kör noktalar için bkz.
> [OLCULMEYEN-DURUMLAR-2.md](OLCULMEYEN-DURUMLAR-2.md) (tur 49 envanteri).

**Tarih:** 2026-07-29 · **Kapsam:** mobil (Flutter) + panel (admin-web)

Tur 23–35 arası yedi sürüş ekseni kuruldu: dil, dar ekran, yazı ölçeği, ekran
okuyucu, koyu tema, klavye, fotoğraflı veri. Her turun sonunda "BULGU: 0"
raporlandı. Ama **bir sürüş yalnız ÇİZDİĞİ durumu ölçer** — çizilmeyen ekran,
açılmayan form, gelmeyen veri hakkında hiçbir şey söylemez. Tur 34/35 bunu
somut gösterdi: fotoğraflı veri hiç çizilmediği için altı eksen de fotoğraflı
düzeni kaçırmıştı ve seed'in **kırık görsel** ürettiği görülmemişti.

Bu belge, "temiz" raporlarının **arkasındaki kör noktaları** ölçümle listeler.
Tahmin yok: her madde ya kapsam (coverage) verisinden, ya canlı sayfadan, ya
da veritabanı sayımından geliyor.

## Yöntem

| Ölçüm | Nasıl |
|---|---|
| Mobil ekran kapsamı | `flutter test --coverage` → `coverage/lcov.info`, `presentation/` katmanı |
| Panel veri durumu | `admin-web/tools/durum-envanteri.mjs` — 23 sayfayı canlı seed ile gezip satır/kart/etkileşim sayar |
| Veri durumu dağılımı | seed veritabanında enum sayımı (owner bağlantısı) |

**Mobil presentation kapsamı: 7 928 / 13 226 satır = %59,9.**
47 ekran dosyasının **8'i hiç çizilmiyor**, 23'ü kısmi, 15'i iyi kapsanıyor.

---

> **GÜNCELLEME (tur 37).** A bölümündeki saha akışı **kapatıldı**:
> `saha_akisi_surus_test.dart` devriye / NFC / görev detayı / kuyruk /
> kategoriler / daire kayıtları ekranlarını beş eksende sürüyor. Kapsam
> %59,9 → **%65,3**; beş hata bulundu (dile duyarsız büyük harf, Riverpod
> `onDispose` ihlali, iki taşma, koyu tema kontrastı). Kalan maddeler
> (B–F) hâlâ açık; `set_password_screen` ve `temp_code_dialog` de açık.

## A. Hiç çizilmemiş ekranlar (mobil)

Bu ekranlar **hiçbir** sürüş ekseninde çizilmedi: çevirisi, dar ekranda
taşması, koyu tema kontrastı, klavye erişimi ve ekran okuyucu etiketleri
hakkında **elimizde hiçbir ölçüm yok**.

| Ekran | Kapsam | Ne kaçırılıyor |
|---|---|---|
| `tasks/task_detail_screen.dart` | **0 / 249** | Görev detayı: durum geçişleri, atama, kanıt fotoğrafı, yorum |
| `patrol/patrol_screen.dart` | 3 / 242 | Devriye başlatma/yürütme — saha rolünün ana ekranı |
| `patrol/patrol_tracking_screen.dart` | 3 / 189 | Tur takibi (okutulan/beklenen, canlı ilerleme) |
| `nfc/nfc_screen.dart` | 1 / 189 | NFC okutma ekranı (saha operasyonunun çekirdeği) |
| `tasks/task_categories_screen.dart` | 1 / 103 | Kategori yönetimi (dinamik görev tipi) |
| `unit_access/unit_access_records_screen.dart` | **0 / 85** | Daire erişim kayıtları listesi |
| `auth/set_password_screen.dart` | 1 / 83 | Geçici parola → kalıcı parola akışı (ilk giriş!) |
| `scan/outbox_screen.dart` | 1 / 65 | Çevrimdışı kuyruk ekranı |

Yanında duran, ekran olmayan ama aynı ölçüde çizilmemiş parçalar:
`task_complete_controller` (0/128), `patrol_controller` (1/116),
`patrol_history_view` (1/88), `core/ui/temp_code_dialog` (0/25),
`tasks/task_ticket_widgets` (1/57).

> **Tek cümleyle: saha (görevli/güvenlik) operasyonunun tamamı — devriye,
> NFC okutma, görev tamamlama — yedi eksenin hiçbirinde sürülmedi.**

> **GÜNCELLEME (tur 40).** B3 (onay diyalogları) **kapatıldı**: 5 silme onayı
> beş eksende sürülüyor; yıkıcı düğmenin kontrastı düzeltildi. B bölümünün
> tamamı kapandı — sırada C (panelde dolu veri) ve E (hata/çevrimdışı).
>
> **GÜNCELLEME (tur 39).** B2 (fotoğraf YÜKLEME yolu) **kapatıldı**: üç hâl
> (yükleniyor / hata / yüklendi) duyuru formu ve görev kanıtı için beş
> eksende sürülüyor; iki taşma bulundu. B3 (onay diyalogları) hâlâ açık.
>
> **GÜNCELLEME (tur 38).** B1 (formlar ve alt sayfalar) **kapatıldı**: 9 form
> beş eksende sürülüyor (`fabAc` ile açılır ve açıldığı doğrulanır); dört
> taşma/ölçek hatası bulundu. B2 (fotoğraf YÜKLEME yolu) ve B3 (onay
> diyalogları) hâlâ açık.

## B. Çizilen ekranlarda ölçülmemiş bloklar

Kısmi kapsanan 23 ekranda açık kalan satırlar rastgele dağılmıyor; üç
kümede toplanıyor:

1. **Oluşturma/düzenleme formları ve alt sayfalar (bottom sheet).**
   `_UnitFormState` (bina düzenleme, 52 satır), `_ConvertSheetState`
   (talep → iş emri, 29+24 satır), duyuru/etkinlik form gövdeleri.
   Sürüşler listeyi çiziyor, **formu açmıyor**.
2. **Fotoğraf yükleme yolu.** `_photoBusy`, `_fotoBekliyor`, `_fotoYukle`,
   yükleme hata dalları (etkinlik 30+17+13, duyuru 20+17+13 satır).
   Tur 34 fotoğrafı *göstermeyi* ölçtü; **yüklemeyi** değil.
3. **Onay diyalogları ve hata dalları.** `_confirmDelete`, `if (!mounted)
   return` sonrası hata gösterimi, `uploadPending` uyarıları.

> **GÜNCELLEME (tur 41).** C **kapatıldı**: seed'e devriye alanı + bildirim +
> çözülmüş destek bileti eklendi; rapor sonuçları `tools/rapor-surusu.mjs`
> ile sürülüyor (42 sonuçlu ölçüm). Beş bulgu — en ağırı `/reports/tasks`
> özet kartlarındaki **"undefined"** (panel, kaldırılmış API alanlarını
> okuyordu). Sırada E (hata/çevrimdışı) ve F (rol varyantları).

## C. Panelde veri olmadan sürülen sayfalar

`durum-envanteri.mjs` çıktısından (canlı seed):

| Sayfa | Durum | Ne kaçırılıyor |
|---|---|---|
| `/dashboard` | Tüm sayaçlar **0**, "Bugün için tur yok" | Canlı panelin dolu hâli: tur satırları, alarm kartı, ilerleme |
| `/notifications` | "Bildirim yok · Toplam 0" (DB'de 0 kayıt) | Bildirim satırı, okundu/okunmadı rozeti ve süzgeç sonuçları |
| `/reports/dues`, `/reports/patrols`, `/reports/tasks` | Yalnız sorgu formu | **Rapor tablosunun kendisi** — sürüş "Raporu getir"e hiç basmıyor |
| `/support` | Yalnız `açık` bilet | `çözüldü` durumu + **admin cevap görseli** dalı |

Bunlar "boş durum" testi olarak değerli — ama dolu hâli hiç ölçülmedi.

## D. Hiç görülmemiş veri durumları (enum)

Seed'deki dağılım (tur 36 sayımı):

| Enum | Seed'de var | **Yok** |
|---|---|---|
| `complaint_durum` | acik (4), cozuldu (2), is_emri (1) | **reddedildi** |
| `kargo_durum` | bekliyor (1) | **teslim_alindi** |
| `access_request_durum` | — | **bekliyor / onaylandi / reddedildi** — `unit_access_permission` tablosu seed'de **boş** |
| destek durumu | acik (1) | **cozuldu** |
| `notification` | **0 kayıt** | tümü |

`rezervasyon_durum` (onaylandi + iptal) ve `user_role` (5 rolün hepsi)
seed'de tam.

> **GÜNCELLEME (tur 45).** **Push gelişi** kapatıldı — ve bu maddede gerçek
> bir ürün hatası çıktı: ön planda gelen push hiçbir yerde gösterilmiyordu.
> Böylece tur 36 envanterindeki **A–F bölümlerinin tamamı** kapandı.
>
> **GÜNCELLEME (tur 44).** **403** ve **yükleniyor/iskelet** kapatıldı
> (panelde 152 sayfa-dil-kip, mobilde 2 sürüş). İki bulgu — `/building-editor`
> ve `/dues` yükleniyor göstergesi yoktu; 12 hardcoded Türkçe daha çıktı.
> E'de yalnız **push bildirimi gelişi** açık kaldı.
>
> **GÜNCELLEME (tur 42).** E'nin ilk iki maddesi (**çevrimdışı/ağ hatası** ve
> **sunucu hatası**) kapatıldı: panelde 152 sayfa-dil-kip, mobilde 4 sürüş.
> Üç bulgu — `/dues` sessiz hatası, "Failed to fetch" ham metni, devriye hata
> bandının taşması. Kalanlar açık: 403, yükleniyor/iskelet, push gelişi.

## E. Çalışma zamanı durumları

Hiçbir sürüşte üretilmedi:

* **Çevrimdışı / ağ hatası** — mobilde `AkisHatasi.agHatasi` dalları,
  panelde `ErrorBox`. (Widget testlerinde tekil olarak var; **sürüşlerde** yok.)
* **403 / yetki reddi** — rol kapılarının kullanıcıya gösterdiği hâl.
* **Yükleniyor / iskelet** — sürüşler `pumpAndSettle` sonrası ölçüyor, yani
  iskelet ve dönen gösterge durumları hiç ölçülmüyor.
* **Push bildirimi gelişi** — ön planda bildirim, rozet artışı.
* **Süresi dolmuş presigned URL** — tur 35'te `Foto` bileşeniyle karşılandı,
  ama gerçek 900 sn sonrası davranış sürülmedi.

> **GÜNCELLEME (tur 43).** F **kapatıldı**: sekiz rol varyantı sürüldü
> (sakin / salt-okunur saha / yönetici / tesis görevlisi). Bir bulgu —
> izin kartının Onayla/Reddet çifti 320 dp'de taşıyordu. Kalan açık
> maddeler: E'nin 403 / iskelet / push satırları.

## F. Rol varyantları

Sürüş kurucuları ekran başına **tek rol** kullanıyor (çoğunlukla `yonetici`).
`canRespond`, `role ==` gibi koşullarla değişen 17 ekran var; bunların
"düşük yetkili" dalları çoğunlukla ölçülmemiş. Ana ekran istisna: üç rol de
sürülüyor (sakin / saha / yönetici).

## Kör nokta OLMAYANLAR (bilerek dışarıda)

* `features/*/data/*_api.dart` düşük kapsamlı — sürüşler API'yi **bilerek**
  sahteliyor; gerçek uçlar backend testlerinin işi.
* Panelde `/settings`, `/reports/*` form kısımları veri gerektirmez.
* Para biçimi (TL + Türkçe gruplama) dile göre değişmez — politika.

## Öneri sırası (etkiye göre)

1. **Saha akışı** (A) — devriye + NFC + görev tamamlama: kullanıcı sayısı en
   yüksek, ölçüm sıfır.
2. **Formlar ve alt sayfalar** (B1) — her modülde var, hepsi ölçüsüz.
3. **Panelde dolu veri** (C) — rapor tablosu, bildirim listesi, dolu dashboard.
4. **Hata/çevrimdışı durumları** (E) — sürüşe "uç hata veriyor" varyantı eklemek.
5. **Eksik enum durumları** (D) — seed'e reddedildi/teslim_alindi/bildirim.
6. **Rol varyantları** (F) — mevcut sürüşleri ikinci rolle tekrarlamak.
