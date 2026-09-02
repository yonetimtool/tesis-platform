# P203 — NFC hatası · çoklu tesis · ziyaretçi · vardiya · mesai

**Tarih:** 2026-09-02

---

# §1 — NFC noktası 500 hatası (BİTTİ)

## Kök neden: sunucuda değil, PANELDE — ve zincir üç halkalıydı

`PATCH /checkpoints/{id}` koordinat girilince 500 dönüyordu.

**1. Panel koordinatı PARA gibi ayrıştırıyordu.** Form `sayiCoz`
kullanıyordu; o bir para/miktar ayrıştırıcısıdır ve Türkçe yazımı çözer:
noktadan sonra **2'den fazla** basamak varsa noktayı **binlik ayracı**
sayıp siler. Para için doğru ("1.234" bin iki yüz otuz dörttür),
koordinat için felaket. Ölçüldü:

```
sayiCoz("41.008238") -> 41008238        ← 41.008238 DEĞİL
sayiCoz("28.978359") -> 28978359
sayiCoz("41,008238") -> 41.008238       ← virgülle DOĞRU çalışıyordu
```

Yani virgülle yazan kullanıcı sorun yaşamıyor, **noktayla yazan 500
alıyordu** — haritadan kopyalayıp yapıştıran herkes.

**2. Sunucu bu sayıyı doğrulamadan kabul ediyordu.** `gps_lat: float`,
aralık yok.

**3. Sütun `Numeric(9, 6)`** — üç tam basamak sığar. 41008238 taştı,
psycopg `NumericValueOutOfRange` attı, yakalanmadı → **500**.

### Ölçüm (canlı uç, düzeltmeden önce)

```
41.008238 / 28.978359  -> 200
91.0      /      0.0   -> 200   ← imkânsız enlem SESSİZCE kabul
0.0       /    181.0   -> 200   ← imkânsız boylam SESSİZCE kabul
1234.5    /   5678.9   -> 500   ← KUSUR
```

İkinci bulgu ilkinden bağımsız: **91 enlem diye bir şey yok** ama sistem
kaydediyordu — haritada bir noktayı hiçbir yere koymak demek.

## K1.1 — İki tarafı da düzelttim, biri yetmez

**Panel:** koordinat için ayrı ayrıştırıcı (`koordinatEnlemCoz` /
`koordinatBoylamCoz`). Koordinatın **binlik ayracı yoktur** (enlem ≤ 90,
boylam ≤ 180 — üç basamağı aşamaz), dolayısıyla nokta da virgül de
**ondalıktır**. Kullanıcı haritadan kopyaladığını yapıştırır; hangi
ayracı kullandığı önemli olmamalı.

**Sunucu:** `Enlem` / `Boylam` tipleri (`ge/le`). İstemciye güvenmek,
aynı 500'ü bir sonraki istemcide (mobil, entegrasyon, curl) yeniden
üretmek olurdu.

**Aralık, sütun genişliğinden dar ve bu bilinçli:** `Numeric(9,6)`
999.999999'a izin verir; fiziksel olarak imkânsız bir koordinatı
saklamak, sessizce yanlış veri üretmektir.

## K1.2 — Aynı kalıbı taradım: kural vardı, GPS'te uygulanmamıştı

`TenantSettingsUpdate.konum_lat` **zaten** `ge=-90, le=90` taşıyordu.
Yani kural depoda vardı, 13 GPS alanında unutulmuştu. Tek tek düzeltmek
yerine **toptan bir tarama testi** yazdım: `gps_lat`/`gps_lng`/
`konum_lat`/`konum_lon` içeren her şema alanı alt **ve** üst sınır
taşımalı. Tarama, ben fark etmeden `TenantSettings.konum_lat` ve
`konum_lon`u da (okuma şeması) yakaladı ve onlar da kapatıldı.

Kapsanan alanlar: checkpoint (3 şema), scan (4), görev tamamlama (2),
demirbaş teslim/iade (3), tesis ayarları (2).

## Ölçüm (düzeltmeden sonra)

```
41.008238 / 28.978359   -> 200
90.0      / 180.0       -> 200   (sınırın KENDİSİ kabul)
-90.0     / -180.0      -> 200
91.0      / 0.0         -> 422
0.0       / 181.0       -> 422
90.000001 / 0.0         -> 422   (sınırın kıldan dışı)
1234.5    / 5678.9      -> 422   ← eski 500
41008238  / 28978359    -> 422   ← panelin ÜRETTİĞİ değer
null      / null        -> 200   (silme niyeti, hata değil)
"abc"                    -> 422
```

## Kilit kanıtı

`CheckpointUpdate`in aralığını geri aldım → **5 test birden düştü**
(taşan koordinat + aralık dışı vakalar). Geri koydum.

Panel tarafında 18 test: para ayrıştırıcısının koordinatı bozduğu
**kayıt altına alındı** (birinin bir gün yine `sayiCoz`a dönmesi hâlinde
neden yanlış olacağı görünür kalsın diye).

## Ölçemediğim

* **Kullanıcının gerçekte hangi değeri girdiğini görmedim.** Kök nedeni
  panelin ayrıştırıcısını çalıştırarak yeniden ürettim; 500'ün bildirilen
  örneğindeki ham girdi elimde yok. Eğer kullanıcı virgülle yazdıysa
  başka bir yol daha olabilir — o durumda sunucu artık 422 döneceği için
  hata mesajı bize kalanı söyler.
