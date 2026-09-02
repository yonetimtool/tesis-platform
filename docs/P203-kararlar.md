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

---

# §2 — Çoklu tesis (BACKEND BİTTİ, arayüz sırada)

## Önce ölçtüm: model bunu ZATEN destekliyor

```
uq_app_user_tenant_email        UNIQUE (tenant_id, email)
uq_app_user_tenant_email_lower  UNIQUE (tenant_id, lower(email))
uq_app_user_telefon             UNIQUE (telefon) WHERE telefon IS NOT NULL
```

**E-posta tesis içinde benzersiz, platform genelinde değil.** Yani aynı
kişi N tesiste **N ayrı `app_user` satırı** olarak durur ve **her satırın
kendi rolü** vardır. İstenen davranış ("birinde yönetici, diğerinde
sakin") **şema değişikliği gerektirmiyor.** Eksik olan tek şey,
kullanıcının bu satırları görebilmesi ve arasında geçebilmesiydi.

**Telefon ise global benzersiz** — aynı kişi iki tesiste aynı telefonu
taşıyamaz. Akışı engellemiyor (P197'den beri kimlik e-postadır) ama
bilinen bir sınır ve teste bağlandı: biri bir gün "telefonla çoklu tesis
girişi" isterse önce o kısıt kalkmalı.

## K2.1 — Üç uç

| Uç | Kimlik | Ne yapar |
|---|---|---|
| `POST /auth/tesislerim` | **yok** (parola ister) | Giriş ekranı: bu kimlik hangi tesislerde geçerli |
| `GET /me/tesislerim` | oturum | Uygulama içi seçici |
| `POST /me/tesis-degistir` | oturum | Hedef tesis için **yeni jeton** |

## K2.2 — Liste parola ister, sızdırmaz

Üyelik listesi bir **sızıntı yüzeyidir**: parolasız sorulabilseydi uç,
*"bu e-posta hangi sitelerde oturuyor"* sorgusuna dönüşürdü. Parola
doğrulanır ve liste **yalnızca parolanın tuttuğu** üyelikleri taşır.
**Yanlış parola ile hiç üyelik olmaması ayırt edilmez** — ikisi de boş
liste.

Hız sınırı var ve **mesajı ayrı**: bu bir kod isteği değil, parola deneme
yüzeyi. Kullanıcıya "çok fazla kod isteği" demek, yapmadığı bir şeyi
yaptığını söylemekti (`cok_fazla_deneme`, 10/15dk).

## K2.3 — Geçiş parola sormaz; bedelini açıkça yazıyorum

İstek "yeniden giriş gerektirmeden" diyor. Dayanağım: **bu sistemde
kimlik e-postadır.** P197'den beri e-posta zorunlu; davet, parola
sıfırlama, doğrulama hepsi ondan geçer. Bir yönetici X e-postasıyla
kullanıcı açtığında *"X'i kontrol eden kişi bu tesise girebilir"* demiş
olur. Aynı e-postayı taşıyan iki satır **kuruluş gereği aynı kişidir.**

**Bedeli:** A'daki oturumu ele geçiren biri, aynı e-posta B'de de varsa
B'ye de geçebilir — B'nin parolasını bilmeden. Bunu kabul ediyorum çünkü
alternatif daha kötü: kişiye N tesis için N parola ezberletmek, gerçekte
herkesin aynı parolayı kullanmasıyla sonuçlanır — aynı risk, üstüne
parola yorgunluğu.

Sınırlar yine de uygulanır: hedef satır **aktif** olmalı, denetçi görev
penceresi kuralı burada da geçerli (girişle aynı kapı), ve geçiş
**denetime yazılır** (`tesis_degistir`, kaynak tenant meta'da).

## K2.4 — İzolasyon: en kritik kısım

Jeton **tek** bir `tenant_id` taşır; RLS onu kullanır. Geçiş = hedef için
yeni jeton. İzolasyon **yapısal olarak** korunur: değişen tek şey
jetondaki tenant, veri yolu aynı.

Üye olmayan tesise geçiş **403**, ve *"böyle bir tesis yok"* ile *"üye
değilsin"* **aynı yanıtı** alır — aksi hâlde uç, tenant kimliği sorgulama
aracı olurdu.

## Ölçüm — akış gerçekten çalıştırıldı

```
[1] POST /auth/tesislerim        -> 200: A(yonetici) + B(sakin)
[2] YANLIS parola                -> 200 {"tesisler": []}      (sızdırmaz)
[3] A'ya giris                   -> 200
[4] GET /me/tesislerim           -> 200: [A yonetici, B sakin]
[5] POST /me/tesis-degistir      -> 200 (yeni jeton)
[6] yeni jetonla GET /me         -> role: resident   ← A'da yonetici
[7] A jetonu  GET /users         -> 200, 7 kayit
[8] B jetonu  GET /users         -> 200, 2 kayit     ← FARKLI veri
[9] UYE OLMAYAN tenant'a gecis   -> 403 tesis_uyeligi_yok
```

## Kilit kanıtı

`tesis-degistir`den üyelik kontrolünü kaldırdım → **5 test birden düştü**
(rol taşınması, üye olmayan tesis, olmayan tenant, izolasyon, denetim).
Geri koydum.

İzolasyon testi `/announcements` üzerinden ölçüyor, `/blocks` üzerinden
değil: `/blocks` sakine kapalı olduğu için test izolasyonu değil **rol
kapısını** ölçmüş olurdu — B jetonu 403 alırdı ve "veri görünmüyor" diye
yanlış bir güvence verirdi.

## Kilit registreleri (tam takım yakaladı)

`/me/tesis-degistir` rol kapısız (bilinçli — denetçi de başka tesiste
sakin olabilir) ve `tenant_uyelikleri` SECDEF envanterine gerekçesiyle
eklendi. Rol matrisi yeniden üretildi.
