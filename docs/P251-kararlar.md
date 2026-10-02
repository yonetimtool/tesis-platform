# P251 — Test bulguları: alarm durumu, bildirim, tablolar, görseller, menü, mesaj günlüğü, mobil ızgara

Her bölüm ayrı commit. Ölçüm önce, düzeltme sonra.

# §1 — ACİL DURUM ÇAĞRILARI

## Ölçüm (dev, gerçek akış + gerçek Chromium)

Akış API üzerinden sürüldü: güvenlik alarm başlattı → yönetici kapattı;
ikinci alarm yayından sonra iptal edildi (yanlış alarm). Ardından
`/panik` sayfası gerçek tarayıcıda görüntülendi.

* **Sunucu doğru:** kapatılan alarm `kapandi`, iptal edilen
  `yanlis_alarm` döndü; yayın görevi iptal penceresinden sonra kapanmış
  alarmı ezmiyor (`panik_yayin.py` korumalı). BFF önbelleklemiyor
  (`force-dynamic`, `no-store`).
* **(a) + (b) kök neden web'de, iki kusur:**
  1. "Açık çağrı" istemcide `kapandi_at == null` ile sayılıyordu. İptal
     ve yanlış alarm `kapandi_at` **yazmaz** (yalnız `iptal_at`), yani
     sonsuza kadar "açık" sayılıyordu. Ekranda "Açık çağrı: 1" ve tek
     kayıt "Yanlış alarm" olarak ölçüldü.
  2. Sayılar ayrı bir istekten (200 kayıt) geliyordu ve o istek **hiç
     yenilenmiyordu**: liste 15 sn'de bir tazelenirken şerit eski
     kalıyordu; web'de "Kapat" da yalnız listeyi tazeliyordu. "Kapattım
     ama hâlâ açık" görüntüsü buydu.
* **(c)** Süzgeç elle yazılmış bir listeden çiziliyordu ve
  `yanlis_alarm` eksikti. Ayrıca bilinmeyen bir `?durum=` değeri
  veritabanında tür hatasına (500) dönüşüyordu.
* **(d)** "/ gördü" başlığı, satır metninin (`{goren}/{toplam} gördü`)
  yer tutucuları boş verilerek yapılmıştı. Eylem sütununun başlığı
  `aria-label` ile verilmişti ama paylaşılan `Th` bileşeni bu özelliği
  **tanımlamıyordu**: tireli özellik TypeScript'te hata vermediği için
  9 tabloda sessizce yutuluyordu — başlık hem görünmez hem ekran
  okuyucuya boştu. `Tr` ve `Td` de `data-test`i aynı şekilde yutuyordu.
* **Mobil:** takip ekranı satırda **durumu hiç yazmıyordu** (yalnız
  ikon rengi; yanlış alarm ile kapandı aynı görünüyordu), sayı ve
  süzgeç yoktu, tatbikatlar karışıktı.

## Kararlar

* **Sayılar sunucuda, durumdan:** `GET /panik` yanıtı `ozet` taşır.
  Tek tanım: **açık = beklemede | açık | müdahale**.
* **"Kapanan" = sonuçlanan her alarm** (kapandı + iptal + yanlış alarm).
  Gerekçe: üç kart toplamı tüm alarmları karşılamalı; yanlış alarm ve
  iptal de "artık müdahale beklemeyen" kayıttır. Ayrıntı kartın altında:
  "1 yanlış alarm · 0 iptal".
* Sayılar **durum ve tatbikat süzgecinden bağımsız** (P244 §8c) ve
  listeyle aynı yanıtta geldiği için 15 sn'de bir birlikte yenilenir.
  "Bugün" tesisin saat diliminde.
* **Durumlar enum'dan:** yanıt `durumlar` = `PANIK_DURUM.enums`. Süzgeç
  (web + mobil) bundan çizilir; yeni bir durum eklenince eksik kalmaz.
  Bilinmeyen durum 422 (`gecersiz_durum`, 7 dil).
* **Tatbikat:** ayrı süzgeç — Gerçek alarmlar / Tatbikatlar / Gerçek ve
  tatbikat. **Varsayılan gerçek alarmlar**: tatbikatın kendi bölümü ve
  raporu aynı sayfada (web) / ayrı ekranda (mobil); acil durum
  listesine karışmaları görünürlüğü bulandırıyordu. Tatbikat satırı
  "Tatbikat" rozeti taşır. Özet tatbikatları açık sayısına katmaz
  (`ozet.tatbikat` ayrı).
* **Başlıklar:** "Gören" ve görünür "İşlem" başlığı. Paylaşılan `Th`
  artık `aria-label`'ı görünmez metin olarak çizer (diğer 8 tablonun
  eylem sütunu da ekran okuyucuda adlandı); `Tr`/`Td` `data-test`
  geçirir.

## Testler

* Sunucu `test_p251_panik_ozet.py` (3): iptal + yanlış alarm açık
  sayılmaz, kapatma açık sayısından düşer, özet durum süzgecinden
  bağımsız; `durumlar` = enum, `yanlis_alarm` süzer, bilinmeyen 422;
  tatbikat süzgeci + özet tatbikatı saymaz.
* Web `p251-panik-takip.dom.test.ts` (4), mobil
  `p251_panik_takip_test.dart` (3, büyük yazı 2x taşma dahil).
* Gerçek tarayıcı (sonra): Açık 0, Kapanan 2 ("1 yanlış alarm · 0
  iptal"), başlıklar dolu.

## Testte bulunan kusur

* Mobilde süzgeç değişince yeni istek yüklenirken durum listesi
  boşalıyor, seçili durum açılır listede kalmadığı için ekran çöküyordu
  (Flutter assert). Son bilinen liste korunur, ilk yüklemede yedek
  liste kullanılır.
