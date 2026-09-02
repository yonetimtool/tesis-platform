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

## K2.5 — Arayüz

**Web — girişte seçim.** Tesis kodu alanı artık **zorunlu değil**.
Şikâyetin kendisi buydu: kullanıcı ezberlemesi gerekmeyen bir kodu
ezberlemek zorundaydı. Boş bırakılırsa:

| Sonuç | Davranış |
|---|---|
| 0 üyelik | Normal giriş denenir → standart 401 (sızdırmama korunur) |
| 1 üyelik | **Seçim çıkmaz**, doğrudan girilir |
| N üyelik | Seçim çizilir; her satırda **o tesisteki rol** yazar |

Tesis kodu yazıldıysa üyelik ucu **hiç çağrılmaz** — kolaylık katmanı
asıl yolu yavaşlatmamalı. Üyelik çağrısı hata verirse **boş liste**
döner ve kullanıcı kodu yazarak yine girebilir.

**Web — uygulama içi geçiş.** Kullanıcı menüsünde, **yalnızca birden çok
üyelik varsa**. Başarıda `location.assign("/")` ile **tam sayfa
yenileme**: jeton değişti ve rol değişmiş olabilir; Next'in istemci
önbelleği eski tesisin verisini ve eski role göre çizilmiş kabuğu
tutuyor — yumuşak geçiş, yeni tesiste eski menüyü göstermek olurdu.

BFF `/api/me/tesis-degistir` jetonu **httpOnly çereze yazar** (giriş
yolunun aynı kuralı) ve **yüzey kapısını burada da uygular**: yeni
jetonun rolü farklı olabilir, kapıyı yalnız girişte uygulamak kullanıcıyı
`panel.*`ta sakin jetonuyla bırakırdı — P126.1'de ölçülen kusurun aynısı.

**Mobil — ölçülen sınır.** Mobil giriş **telefonladır** ve
`uq_app_user_telefon` global benzersizdir: bir numara **tek** bir tesis
satırına karşılık gelir. Yani "hangi tesise gireyim" sorusu mobilde
**girişte sorulamaz**; kişi bir tesise girer ve uygulama içinden geçer.
Seçici Ayarlar ekranında, **rolden bağımsız** (kişi bir tesiste sakin,
ötekinde yönetici olabilir — sakine göstermemek tam da geçmesi gereken
kullanıcıyı engellerdi).

## §2 kilit kanıtı (arayüz)

| Bozma | Düşen test |
|---|---|
| Tek tesiste de seçim gösterilse | TEK TESİS VARSA SEÇİM ÇIKMAZ |
| Seçicide bulunduğu tesis tıklanabilir olsa | BULUNDUĞU TESİS İŞARETLİ |
| Mobilde yeni jeton saklanmasa | GEÇİŞ: JETON SAKLANIR |

## §2 ölçemediğim

* **Gerçek tarayıcıda tam sayfa yenileme sonrası kabuğun yeni role göre
  çizildiğini görmedim** — DOM testi `location.assign` çağrısını ölçüyor,
  sonrasını değil.
* **Mobilde gerçek cihazda geçiş** denenmedi (widget testi).

---

# §3 — Ziyaretçi: daire otomatik seçimi (BİTTİ)

## Önce ölçtüm — iki şey beklediğimden farklıydı

**1. Bildirim ZATEN VAR.** İstek "daire seçilince o dairenin sakinine
bildirim gidebilmeli — mevcut bildirim altyapısına bağla" diyor.
`routers/visitors.py` başlığı ve kodu ölçüldü: kayıt oluşunca seçilen
hedef sakine push + kalıcı bildirim **zaten yazılıyor**. Yeniden
yapmadım.

**2. Güvenliğin daire listeleme yetkisi VAR.** Şemadaki yorum
*"güvenlik daire listesine RBAC'i yoktur"* diyordu; rol matrisi bunu
**yalanlıyor**: `GET /units` ve `GET /units/by-no/{no}/residents`
güvenliğe açık. Yani eksik olan **yetki değil, adla aramaydı.**

## Kusur: numara elle yazılıyordu

Mobil formda `_unitNo` serbest metindi; görevli numarayı yazıp
"Sakinleri getir"e basıyordu. Kapıdaki görevli çoğu zaman *"Ayşe
Hanım'a geldim"* duyar, *"A-12'ye geldim"* duymaz. Numarayı tahmin
etmek **sessiz bir kusurdur**: kayıt oluşur ve bildirim **başka bir
sakine** gider.

## K3.1 — `GET /units/ara` — numara VEYA sakin adıyla

RBAC `by-no/.../residents` ile **aynı** (admin + yönetici + security).
Güvenliğe **yeni yetki verilmiyor.**

**KVKK — yeni bir ifşa değil, aynı verinin başka indeksi.** Güvenlik
zaten bir dairenin aktif sakinlerinin adını görüyor. Amaç sınırlı
kalsın diye: yalnız **aktif** bağlantılar · yalnız `user_id` + `ad`
(telefon/e-posta/borç yok) · **en az 2 karakter** · limit tavanı 50.
Boş/tek harf sorgu **boş liste** döner — uç bir **döküm aracı değildir.**

Sonuç **sakinleri de taşır**: hedef sakin seçimi zorunlu olduğu için
ayrı bir çağrı **her zaman** yapılırdı; görevliye ikinci bir bekleme
yaşatırdı.

## K3.2 — Serbest metin: EKLENMEYECEK — gerekçesiyle

Önce bir düzeltme: **bugün serbest metin yok.** `unit_no` sunucuda bir
daireye çözülür, bulunamazsa 422. Yani soru "kalsın mı" değil,
"eklensin mi".

**Kararım: eklenmeyecek.** Üç ölçülmüş sebep:

1. `visitor.unit_id` **NOT NULL** ve `target_resident_user_id` de
   **NOT NULL**. Kaydın tüm anlamı budur: **bir** sakin bilgilendirilir
   ve kaydı **yalnız o** görür. Yönetim ofisine gelen ziyaretçinin
   hedef sakini **yoktur** — kaydın çekirdek semantiği çöker.
2. İkisini nullable yapmak, aynı tabloda **semantik olarak ikinci bir
   kayıt türü** yaratırdı; bildirim, "şu an içeride kim", sakin
   görünürlüğü — her tüketicinin null dalı olurdu.
3. İhtiyaç **gerçek** ama **başka bir özellik**: hedef sakini olmayan,
   ortak alan/ofis ziyaretçisi kaydı. Onu bu kaydın içine sıkıştırmak,
   iki farklı şeyi tek tabloya gömmek olurdu.

**Bunu yarım bırakmıyorum, kapsam dışına alıyorum ve söylüyorum:**
ortak alan ziyaretçisi bugün kaydedilemiyor. Gerekirse ayrı bir tur —
`ziyaret_hedefi` (daire | ortak alan | yönetim) ayrımı ve hedefsiz
kayıtta bildirimin yöneticiye gitmesi.

## K3.3 — Arama gecikmeli, seçim eski hedefi düşürür

Her tuşta istek atmak, dokuz harflik bir isim için dokuz istek demekti
→ **350 ms gecikme**.

Arama metni değişince **seçili hedef düşer**. Sessizce durursa: görevli
daireyi değiştirir, hedef eski dairenin sakini olarak kalır ve bildirim
**yanlış kişiye** gider — düzeltmeye çalıştığımız kusurun ta kendisi.

## Ölçüm

Rota sırası tuzağı testler tarafından yakalandı: `/units/ara`
`/units/{unit_id}`den **önce** tanımlanmalı, yoksa FastAPI "ara"yı UUID
sanıp **422** döner (`admin-web`de `[id]` segmentinde ölçülen P189
sınıfının aynısı).

| Kilit kanıtı — bozma | Düşen test |
|---|---|
| Rota sırası geri alındı | 6 test birden |
| Boş sorgu koruması kaldırıldı | BOŞ/TEK HARF BOŞ DÖNER |
| Arama değişince eski hedef dursa | ESKİ HEDEF DÜŞER |
| Gecikme kaldırıldı | İKİ HARFTEN KISA İSTEK ATMAZ |

Testler: backend 7, mobil 5.

## §3 ölçemediğim

* **Gerçek cihazda** arama akışı denenmedi (widget testi).
* **Web tarafındaki `/ziyaretciler` sayfasına dokunmadım**: orası
  yönetim için **salt izleme** (kayıt yalnız güvenlikte, yani mobilde).
  Kayıt formu web'de yok, dolayısıyla seçicinin web karşılığı da yok.

---

# §4 — Vardiya planlama (BACKEND BİTTİ, arayüz sırada)

## Önce ölçtüm: mevcut model planlama YAPAMIYOR

```
shift            = ŞABLON (ad + başlangıç/bitiş saati + gün_tipi)
shift_assignment = (tenant, shift_id, user_id)      ← TARİH YOK
```

Bugün söylenebilen tek şey *"Ali gece vardiyasındadır"* — **hangi gün
olduğu yok.** İstenen her şey tarih boyutu gerektiriyor: haftalık plan,
gün içi değişiklik (şablonu değiştirmek geçmişi **ve tüm gelecek
günleri** değiştirirdi), çakışma kontrolü ("aynı an" ancak tarihle
tanımlanır) ve §5'in planlanan/gerçekleşen karşılaştırması.

## K4.1 — İki tablo, iki farklı soru

Göç 0093 `vardiya_plani` (tarih taşır) ekledi. **`shift_assignment`
silinmedi**: anlamı netleşti — **varsayılan kadro** ("Ali normalde gece
vardiyasında çalışır"). Hafta ondan **tohumlanır**
(`haftayi-doldur`), sonra gün bazında düzenlenir.

Tek tabloya inmek "her hafta baştan atama" demekti — yirmi kişilik bir
ekipte haftada yüzlerce tıklama.

## K4.2 — İptal SİLMEZ

Gün içi değişiklikler denetime yazılıyor (istek §4.3) ve **silinen bir
satırın denetim kaydı "neyin değiştiğini" gösteremezdi**. *"Ali
çıkarıldı, Veli eklendi"* iki ayrı satır olarak durmalı. Kısmi tekil
indeks (`WHERE durum='planli'`) iptal edilmiş bir satırın yeniden
planlamayı engellememesini sağlıyor; aynı satır **canlandırılıyor**.

## K4.3 — Saat sınırı: KOŞTURUNCA KARARI DEĞİŞTİRDİM

İlk yazımda 4857/63'e dayanarak **günlük 11 saati kesin red** yaptım.
Akışı çalıştırınca ölçtüm:

```
[4] dün GECE (20:00-08:00) -> 422 "Günlük çalışma süresi 11 saati aşamaz"
```

**12 saatlik gece vardiyası tek başına reddediliyordu** — güvenlik
sektörünün **standart kalıbı**. Fiilen 1 saat ara dinlenmeyle 11 saat
çalışmadır, ama **model ara dinlenmeyi bilmiyor**: 12 saatlik bir kaydın
11 mi 12 mi saat çalışma olduğunu ayırt edemez.

Doğrulayamadığımız bir şeyi "kanuna aykırı" diye reddetmek, meşru ve
yaygın bir planı imkânsız kılmak olurdu. **Karar değişti:**

| Kural | Sertlik | Gerekçe |
|---|---|---|
| Çakışma | **Kesin red (422)** | Aynı kişi aynı anda iki yerde olamaz — tercih değil, fiziksel imkânsızlık. Doğrulayabildiğimiz tek şey. |
| Günlük > 11 saat | **Uyarı** | Ara dinlenme modellenmemiş; 12 saatlik vardiya 11 saat çalışma olabilir. |
| Haftalık > 45 saat | **Uyarı** | 45 üstü **fazla mesaidir** (md. 41): yasal, ama maliyetli — ve §5 tam olarak onu gidere yazıyor. Engellemek, sistemin desteklemesi gereken durumu imkânsız kılardı. |

**Gece çalışması (md. 69, 7,5 saat) bilinçli olarak uygulanmadı:** "gece
dönemi" tanımı ve istisnaları (güvenlik hizmetleri dâhil) burada
sağlıklı modellenemez; yanlış bir kesin red meşru bir planı engellerdi.
Uyarı listesine de konmadı — doğrulanamayan bir uyarı gürültü üretip
ötekileri de okunmaz yapardı. Kayıt altında: gerekirse ayrı tur.

**Uç uca eklenen vardiyalar çakışma sayılmaz** (`<` değil `<=`
kullanmak meşru bir devir teslimi engellerdi). **Geceyi aşan vardiya
ertesi günün sabahıyla çakışır** — tarihi yok saymak bunu kaçırırdı.

## K4.4 — Akışı koşturmak ikinci bir kusur daha gösterdi

Aynı kişiyi aynı vardiyaya ikinci kez atamaya çalışınca *"bu kişi aynı
saatte başka bir vardiyada"* diyordu — çakışma denetimi **kendi
satırıyla** çakışıyor sanıyordu. Yanlış ve kafa karıştırıcı. Kontrol
sırası değişti: aynı-atama denetimi çakışmadan **önce**.

## K4.5 — "Gelmedi" nasıl anlaşılıyor — ve sınırı

İstek "görevli vardiyaya başlamadıysa/gelmediyse belli olsun" diyor.
**Sistemde gerçek bir varış kaydı (turnike/QR giriş) YOK.** Uydurmak,
gelmiş bir görevliyi "gelmedi" diye işaretlemek olurdu.

`/vardiya-plani/simdi` bugün **kimin görevde olması gerektiğini** ve
**sıradakini** döndürüyor. Devriye okutmasına bakan bir "geldi mi"
göstergesi **§4 arayüzünde** ele alınacak ve adı `okutma_var` olacak —
"gelmedi" **demeyecek**.

## Ölçüm — akış gerçekten çalıştırıldı

```
[1] hafta            -> 200, 7 gün, 2 slot/gün, hepsi BOŞ
[2] ata (gündüz)     -> 201, uyarı yok
[3] AYNI atama       -> 422 "o gün bu vardiyaya zaten atanmış"
[4] dün GECE (uç uca)-> 201 + ["gunluk_sinir_asildi"]   (eskiden 422)
[6] gündüz slotu     -> boş: False, ["Guard A"]
[7] çıkar            -> 200, durum: iptal
[8] sonra            -> boş: True
[9] şimdi            -> 200, sonraki: "Gece", ["Guard A"]
[10] denetim         -> {"islem":"cikar","not":"hastalik","tarih":...}
```

| Kilit kanıtı — bozma | Düşen test |
|---|---|
| Çakışma kontrolü kaldırıldı | 2 test |
| Geceyi aşma göz ardı edildi (naif çıkarma) | 6 test |

Testler: kurallar 7, uç davranışı 20.

## K4.6 — Arayüz

**Web (`/vardiya-plani`, admin + yönetici).** Gün × vardiya ızgarası;
yöneticinin sorusu *"bu hafta kim ne zaman çalışıyor"* ve bu soru **iki
boyutludur**. Liste hâlinde göstermek, boş kalan vardiyayı görmeyi
imkânsızlaştırırdı: **boş slot, listede hiç görünmeyen şeydir.**

Boş slot **sarı çerçeve + rozet** ile işaretli, ayrıca üstte "N vardiya
boş" sayacı: yönetici tabloyu taramadan önce "eksik var mı" sorusunu
yanıtlayabilmeli.

Uyarılar **sessiz geçmiyor**: 45 saat aşımı bir **maliyettir** (§5 onu
gidere yazıyor) ve yönetici atamayı **yaparken** görmeli.

**Web'de saha rolleri yok — ve bu bir kilidin bulduğu şey.** İlk yazımda
`/vardiya-plani`yi security'ye de açmıştım; `rol-menusu` testi düşürdü:
**P129 kararı — saha rollerinin ürünü mobil uygulamadır, `app.*`ta
hiçbir sayfa görmezler.** Doğrusu: web'de yalnız yönetim, saha **mobilde
görür**.

**Mobil.** Günlük **liste**, haftalık tablo değil: yedi gün × vardiya
ızgarası telefona sığmaz ve yatay kaydırma en çok gereken bilgiyi
(bugün) görünmez yapardı. Boş vardiya ikon + renkle ayrı.

**Mobilde "basit değişiklik" = yalnız ÇIKARMA, atama yok.** Atama;
personel listesi, çakışma geri bildirimi ve uyarı akışı ister —
telefonda yarım bir atama akışı, yöneticiyi yanlış atama yapıp web'de
düzeltmeye zorlardı. Çıkarma ise **acil durumun ta kendisi**
(hastalık/izin) ve sahada gerekir. Her iki yüzeyde de **sebep sorulur**.

## §4 kilit kanıtı (arayüz)

| Bozma | Düşen test |
|---|---|
| Boş slot görsel olarak ayrılmasa | HAFTALIK IZGARA / BOŞ VARDİYA |
| Uyarılar sessiz geçilse | HAFTALIK SINIR UYARISI |
| Saha rolüne çıkarma düğmesi gösterilse | SAHA ROLÜ DÜĞMEYİ GÖRMEZ |
| Sebep sorguda taşınmasa | YÖNETİCİ ÇIKARABİLİR + SEBEP |

Ayrıca üç tasarım-sistemi kilidi düştü ve hepsi haklıydı: elle `<table>`
yazılamaz (P138 — ortak ilkel var), ham `<th>/<td>` yazılamaz, ve
`--yz-warn` diye bir token **yok** (doğrusu `--yz-warning`). Izgara
`<div>`lerle yeniden kuruldu — bu ızgara zaten bir **veri tablosu
değil**: sabit sütunları yok ve hücreleri tıklanabilir kartlar.

## §4 ölçemediğim

* **"Şu an görevde" alanını gerçek zamanla doğrulayamadım**: sunucu
  saati testte sabitlenemiyor, bu yüzden testler **geleceğe** vardiya
  koyup `sonraki` alanını ölçüyor. `gorevdekiler` alanı canlı ölçümde
  (`[9]`) doğru davrandı ama zamana bağlı olduğu için teste
  bağlanmadı.
* **Gerçek cihazda** mobil ekran denenmedi.
* **"Görevli gelmedi mi" göstergesi YOK** — sistemde gerçek varış kaydı
  (turnike/QR) bulunmuyor; uydurmak, gelmiş bir görevliyi "gelmedi" diye
  işaretlemek olurdu. §4.2'nin bu maddesi **karşılanmadı** ve nedeni
  budur.

---

# §5 — Fazla mesai ve finans bağlantısı (BACKEND BİTTİ)

## Önce ölçtüm: ne var, ne yok

**Var:** `personel_kayit.maas_kurus` (aylık ücret) · `app_user_id`
(vardiya planıyla bağı kuran alan) · **`finansal_hareket.durum =
'onay_bekliyor'`** — P167'de eklenmiş onay kuyruğu. İstenen "otomatik
yazma yapma, onaya düşsün" şartı için **yeni bir şey gerekmiyor.**

**Yok:** saatlik ücret, mesai katsayısı. Göç 0094 **yalnızca o ikisini**
ekliyor.

## K5.1 — TEK DEFTER korundu (kabul kriteri 12)

Mesai gideri **ayrı bir tabloya yazılmaz**: `finansal_hareket`e
`tip='gider'` olarak düşer — çünkü o bir **giderdir**. İkinci bir tablo,
"bu ay ne kadar gider yaptık" sorusunu iki yerden toplamak demekti ve
P192 tam olarak bunu ortadan kaldırmıştı.

Bunu bir testle **yapısal olarak** kilitledim: şemada `%mesai%` /
`%overtime%` adında tablo **olmamalı**.

## K5.2 — Otomatik yazma yok (kabul kriteri 11)

Hareket `durum='onay_bekliyor'` ile yazılır ve **bakiyeyi düşürmez**.
Bir hesaplamanın kasayı kendiliğinden azaltması, yöneticinin görmediği
bir sayının parayı hareket ettirmesi olurdu.

## K5.3 — Fazla mesai HAFTA HAFTA hesaplanır

4857 md. 41 **haftalık** eşiğe bakar. Ay toplamıyla hesaplamak yanlış
sonuç verir ve bunu ölçtüm:

```
1. hafta 60 saat · 2. hafta 24 saat  ->  ay toplamı 84
ay toplamıyla:  84 < 90 (2 hafta × 45)  ->  "fazla mesai YOK"   ← YANLIŞ
hafta hafta:    (60-45) + 0            ->  15 saat fazla        ← DOĞRU
```

İlk haftada 15 saat fazla çalışma **doğmuştur** ve ikinci haftanın azlığı
onu silmez.

## K5.4 — Saatlik ücret türetilir, ama sıfır sayılmaz

Verilmemişse `maas_kurus / 225` (30 gün × 7,5 saat — Türkiye'de standart
bölen). Ölçüm: 2.250.000 / 225 = **10.000 kuruş/saat**.

İkisi de yoksa kişi **`ucret_tanimsiz`** işaretlenir ve tutar `null`
döner — **sıfır değil.** Sıfır yazmak, yöneticiye "mesai yok" demenin
sessiz ve yanlış yoluydu. Gidere yazarken de **sessizce atlanmaz**, 422
döner: atlamak "yazıldı" deyip yazmamak olurdu.

## K5.5 — Katsayı 1,50 ama değiştirilebilir

4857 md. 41: fazla çalışma ücreti normal saat ücretinin **yüzde elli
fazlasıdır**. Varsayılan yasal orandır; toplu iş sözleşmesi daha yüksek
belirleyebilir ve yazılım meşru bir sözleşmeyi imkânsız kılmamalı.

## K5.6 — Planlanan vs gerçekleşen: dürüstçe

**Sistemde gerçek bir mesai kaydı (turnike/QR giriş-çıkış) YOK** — §4.2
ile aynı bulgu. Hesap **planlanan** saatler üzerinden yapılır ve yanıt
bunu açıkça söyler: `kaynak: "plan"`. Yönetici gidere yazarken saati
**düzeltebilir**.

Uydurma bir "gerçekleşen" üretmek — örneğin devriye okutmalarından
çıkarım yapmak — gelmiş bir görevliyi eksik, gelmemiş birini tam
göstermeye açıktı **ve o sayı paraya dönüşüyor.**

## Ölçüm — akış gerçekten çalıştırıldı

```
[1] ozet        -> 200, kaynak=plan, katsayi=1.5
                   Guard A: toplam=84s fazla=15s saatlik=10000 tutar=225000
[2] gidere yaz  -> 201, 1 hareket
[3] defter      -> ('gider','cikis',225000,'onay_bekliyor',
                    'Fazla mesai 2026-09 · Guard A · 15 saat x 1.5')
[4] tekrar ozet -> gidere_yazildi: True
```

**Koşturmak bir hata gösterdi:** kolon adını `gerceklesme_durumu`
sanmıştım, gerçek ad `durum` — 500 aldım ve düzelttim.

| Kilit kanıtı — bozma | Düşen test |
|---|---|
| `onay_bekliyor` yerine `odendi` | TEK DEFTERE + ONAY BEKLİYOR |
| Fazla mesai ay toplamından hesaplansa | 9 test birden |

Testler: hesap 12, uç 13.

## K5.7 — Arayüz (`/finans/mesai`)

**Finans bölümünde**, vardiya bölümünde değil: ürettiği şey bir
**giderdir** (P192 tek defter). Vardiyanın içine koymak, parayı
operasyonun içine gizlemek olurdu.

Ekran üç şeyi **açıkça söylüyor**, çünkü üçü de sessiz kalırsa yanlış
karara yol açar:

1. **Hesabın kaynağı plan** — sistemde giriş-çıkış kaydı yok. Gizlemek,
   paraya dönüşen bir sayıyı ölçülmüş gibi göstermek olurdu.
2. **Ücreti tanımsız kişiye `0,00 TL` yazılmaz**, uyarı çizilir — o
   kişinin fazla mesaisi *var*, bilinmeyen şey ücreti.
3. **Onay adımı** — gider onay bekleyen olarak yazılır ve kasadan
   düşmez; yönetici "yazdım, bitti" sanıp onayı atlarsa gider **hiç
   gerçekleşmez**.

"Gidere yaz" yalnızca **yazılabilir** kişileri gönderir: ücreti tanımsız
olanlar ve zaten yazılmış olanlar hariç.

**Denetçi okur, yazamaz.** `rol-menusu` kilidi burada da bir hatamı
buldu: birincil ucu yazma ucu olarak bildirmiştim, denetçi menüde
sayfayı görüp uçta 403 alıyordu. Denetçinin oradaki işi **okumaktır**
(salt-okuma mali denetim rolü; personel gideri denetimin doğal konusu),
birincil uç okuma ucu olarak düzeltildi.

## §5 kilit kanıtı (arayüz)

| Bozma | Düşen test |
|---|---|
| Ücreti tanımsız kişiye 0 TL yazılsa | ÜCRETİ TANIMSIZ 0 TL YAZILMAZ |
| Yazılabilir süzgeci kaldırılsa | ZATEN YAZILMIŞ + GİDERE YAZ (2 test) |

## §5 ölçemediğim / yapılmadı

* **Gerçek mesai kaydı yok** — hesap plan üzerinden; yukarıda.
* **Personel ücret alanları için ayrı ekran yazmadım.**
  `saatlik_ucret_kurus` şemaya ve `PersonelKayitCreate/Update`e eklendi,
  yani **Tanımlar → Personel kayıtları** ekranı alanı taşıdığı sürece
  girilebilir; o ekranın alan listesini **görsel olarak doğrulamadım.**
* **Mobil tarafı yok:** mesai bir yönetim/finans işi ve web'de.

---

# Tam takımların yakaladıkları (bölüm testleri yeşilken)

Bu turda **hedefli testler yeşilken tam takımlar altı gerçek kusur
daha buldu.** Hepsi haklıydı ve düzeltildi:

| Kilit | Ne dedi | Ne yaptım |
|---|---|---|
| `rol-menusu` (P129) | Web'de saha rolüne sayfa açtım | Web yalnız yönetim; saha mobilde görür |
| `tasarim-token` (P138) | Elle `<table>` + ham `<th>/<td>` | Izgara `<div>`lerle kuruldu |
| `tasarim-token` (P160) | `--yz-warn` diye token **yok** | `--yz-warning` |
| `rol-menusu` | Mesai birincil ucu yazma ucuydu; denetçi menüyü görüp 403 alıyordu | Birincil uç okuma ucu |
| `erisilebilir-etiket` | Tek `<label>` iki seçiciyi sarmalıyordu — ekran okuyucu yılı da "Dönem" diye okur | İki ayrı `AlanSarmal` |
| `denetleyici_atma` | Dialog `TextEditingController`'ı **dispose edilmiyor** | Dialog kendi controller'ına sahip |

Son ikisi **iki adımda** düzeldi: `dispose`u dialog kapanır kapanmaz
çağırınca *"A TextEditingController was used after being disposed"*
aldım — dialog çıkış animasyonu sırasında hâlâ ağaçta. Doğrusu,
controller'ı **dialogun kendisinin** sahiplenmesi.

Ayrıca §3'ün ziyaretçi formu değişikliği **iki eski testi** kırdı
(`visitors_screen_test`, `enteg_ziyaret_rapor_i18n_test`) — kaldırdığım
"Sakinleri getir" düğmesini arıyorlardı. Bilinçli davranış değişimi;
testler yeni akışı ölçecek şekilde güncellendi. **Bunu §3'te kaçırdım:**
hedefli testlerle commit'ledim, tam mobil takım henüz bitmemişti.

Bir de **kodla ilgisi olmayan** bir düşüş: `p200-parola-sifirlama`nın
akış testi tam takımda 5 sn'yi aşıyor (tek başına ~1 sn). Dört alana
`userEvent.type` + iki `waitFor` — paralel yük altında doğal. Süresi
açıkça 20 sn'ye çıkarıldı ve **neden** olduğu teste yazıldı; testi
bölmek akışı parçalara ayırmak olurdu ve P198'de tam o yüzden bir kusur
kaçmıştı.
