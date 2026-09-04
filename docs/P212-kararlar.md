# P212 — web giriş hatası, profil fotoğrafı, gürültü eskalasyonu

## §1 — Web girişi kırıktı: BFF vekili eski sözleşmede kalmış

### ÖLÇÜM — kırılma noktası arayüz değil, **vekil**
`app.yonetiyor.com/login`de telefon + parola ile giriş
**"Tesis kodu, e-posta ve parola zorunlu."** hatası veriyordu.

Kaynağa bakıldığında zincir netleşti:

| Katman | Ne gönderiyor / ne bekliyor | Durum |
|---|---|---|
| Form (`GirisFormu`) | `{kimlik, password}` (P205 tek alan) | **doğru** |
| BFF `app/api/auth/login/route.ts` | `{tenant_slug, email, password}` **zorunlu** | **KIRIK** |
| Backend `POST /auth/login` | `LoginRequest.kimlik`, slug opsiyonel, çok tesiste 409 | **doğru** |

Vekil `tenant_slug` boş olduğu için isteği **backend'e hiç göndermeden**
400 dönüyordu. Yani P205 arayüzü ve backend'i güncellemiş, **aradaki
vekili güncellememişti**; mobil aynı akışı doğrudan backend'e konuştuğu
için çalışıyordu.

**Neden testler görmedi:** mevcut giriş testleri taklidi
`/api/auth/login` **sınırında** kuruyordu — yani tam da bozuk olan
katmanın *yerine*. P200 dersi birebir tekrarladı: taklit, ölçülecek
katmanın **altına** konur.

### KARAR K1.1 — Vekil sözleşmesi `kimlik` + `password`
`tenant_slug` **opsiyonel**: girişte sorulmaz, yalnız kullanıcı tesis
seçtiğinde ikinci çağrıda dolar. Eski `email` alanı da kabul edilir
(eski istemci/testler kırılmasın), `kimlik`e düşürülür.

### KARAR K1.2 — Kod yolu telefonda **dürüstçe** reddedilir
Kod **e-posta ile** teslim ediliyor (SMS kapalı) ve backend
`EpostaKodIstek.eposta` bir `EmailStr`. Telefon yazıp "Kod ile giriş"e
basınca istek gidiyor ve biçimsel bir **422** dönüyordu. Artık istek
**atılmadan** sebep söyleniyor: *"Kod ile giriş e-posta adresiyle
çalışır."* (7 dil).

Telefonla kod istemek için sunucunun numarayı hesaba çözüp kodu o
hesabın **e-postasına** göndermesi gerekir — ayrı bir iş; bu turda
yapılmadı, uydurma bir yol da açılmadı.

### Ölçüm — neyi sürdüm
* Form gerçekten sürüldü (jsdom): telefon ve e-posta ile giriş, giden
  gövde ölçüldü → `{kimlik, password}`, **`tenant_slug` yok**.
* **Gerçek route handler** çalıştırıldı, taklit **backend çağrısında**:
  backend'e giden gövde `{kimlik, password}`; seçimden sonra
  `tenant_slug` de iletiliyor; boş kimlik/parola backend'e **hiç
  gitmiyor** (400).
* Kırma denemesi: vekile eski `tenant_slug` şartı geri konduğunda tam
  olarak 2 test düştü ("backend'e istek GITMEDI"), geri alınca 8'i geçti.
* Çok tesisli akış (409 → `tesislerim` → seçim) ve hata mesajlarının
  hesap varlığını sızdırmaması **zaten** P203/P205 testleriyle kilitli;
  ikisi de yeşil.

### Ölçemediğim
Gerçek `app.yonetiyor.com` üzerinden giriş — prod'a erişimim yok. Ölçülen
şey, istemcinin ve vekilin gerçek kodla ürettiği isteklerdir.

---

## §2 — Profil fotoğrafı: ne bozuktu, ne bozuk değildi

### ÖLÇÜM 1 — Sunucu ve istemci API katmanı **çalışıyor**
Dev API'ye **gerçek istekler** gönderdim (taklit yok):

```
POST /uploads/presign            -> 200  (upload_url: 192.168.20.101:9000)
PUT  <presigned>                 -> 200
PATCH /me/avatar {key}           -> 200
GET  /me                         -> avatar_url DOLU
PATCH /me/avatar {avatar_key:null} -> 200
GET  /me                         -> avatar_url null
```

Aynı zinciri **mobil `AvatarApi` sınıfıyla** da sürdüm (gerçek Dio, dev
MinIO): `PRESIGN OK → UPLOAD OK → SET AVATAR → KALDIR (null)`. Yani
"kaldırılamıyor/güncellenemiyor" şikâyetinin sebebi **bu katman değil**.

Yan ölçüm — presigned PUT'un iki tuzağı (ikisi de gerçek yanıt):
* gövde **chunked** gönderilirse MinIO **411 MissingContentLength**;
* **farklı `Content-Type`** ile PUT edilirse **403 SignatureDoesNotMatch**.
Mobil kod ikisini de doğru yapıyor (`Content-Length` set ediliyor, presign
ile PUT aynı tipi kullanıyor).

### ÖLÇÜM 2 — Ekran **hatayı yutuyordu** (gerçek kusur)
`myAvatarUrlProvider` şöyleydi: `catch (_) { return null; }`. Sonuç:
`GET /me` başarısız olduğunda ekran **fotoğrafı olmayan** bir kullanıcı
gibi davranıyor, **"Kaldır" düğmesini gizliyor** ve kullanıcıya **hiçbir
şey söylemiyordu**. "Kaldıramıyorum" şikâyetinin ekranda hiçbir izinin
olmamasının sebebi bu.

**KARAR K2.1 — "fotoğraf yok" ile "okuyamadım" ayrı durumlar.** Hata artık
yukarı çıkar; profil kartı mesaj + **"Tekrar dene"** gösterir, app-bar
sessizce baş harflere düşer (orası bir durum ekranı değil).

### ÖLÇÜM 3 — Mobilde baş harf yoktu (kabul kriteri 7)
Web'de karar **zaten verilmişti** (`components/Avatar.tsx`: baş harfler +
addan türeyen kararlı renk). Mobil ise herkese aynı gri silueti çiziyordu.

**KARAR K2.2 — `BasHarfAvatar` (mobil), web ile aynı kurallar:** en fazla
iki harf, tek kelimede ilk iki harf, addan türeyen **kararlı** renk.
Türkçe büyütme **elle**: Dart'ın `toUpperCase()`i locale tanımaz ve
"ismail" → "IS" verirdi; doğrusu "**İ**S".

### Web tarafı — kontrol edildi, kusur bulunmadı
Yükleme presign + **doğrudan** PUT + `PATCH {avatar_key}`; kaldırma
`PATCH {avatar_key: null}`; fotoğraf yokken **baş harfler**; "Kaldır"
düğmesi yalnız fotoğraf varken. Dördü de artık testli.

### Kilit
Mobil 7 test (baş harf kuralları, renk kararlılığı, fotoğraflı/fotoğrafsız
çizim, presign→PATCH gövdesi, kaldırmada `avatar_key: null`'ın gerçekten
gitmesi, hatanın yutulmaması) + web 4 test. Kırma denemesi: web'de
kaldırma gövdesi `{}` yapıldığında ilgili test düştü, geri alınca geçti.

### Ölçemediğim — ve senden istediğim
**Cihazdaki hatayı yeniden üretemedim**: telefon bende yok ve prod'a
istemci olarak bağlanamıyorum. Ölçebildiğim her katman (backend, depo,
istemci API sınıfı) dev'de çalışıyor. Şimdi ekran hatayı **gösterecek**;
cihazda tekrar denediğinde **ekranda çıkan mesajı** bana ilet — sessiz
başarısızlık kalmadığı için artık teşhis edilebilir olacak.

---

## §3 — Gürültü eşiği: ikinci aşamada güvenliğe eskalasyon

### ÖNCE OKUNDU
`docs/P208-kararlar.md` (sakine sesli uyarı, pencere, susma süresi) ve
`docs/P209-kararlar.md` (sayaçlar tipe göre ayrı). Değişmeyecekler
listesine uyuldu: **harita**, **görüntü/diğer tiplerin davranışı**,
**tip bazlı sayaçlar** ve **ses/kanal tanımları** ellenmedi.

### KARAR K3.1 — VERİ MODELİ: yeni sayaç tablosu **YOK**, bir sütun **VAR**
"Bu daire için eşik kaç kez aşıldı" sorusunun yanıtı **zaten defterde**:
`unit_uyari` satır sayısı. İkinci bir sayaç tutmak, aynı gerçeği iki
yerde tutmak ve günün birinde ayrışmalarını beklemek olurdu.

Yine de `unit_uyari.asama` sütunu eklendi (göç **0104**) ve o anki
değeriyle **damgalanıyor** — gerekçesi `esik`/`sayac`/`metin`
sütunlarıyla birebir aynı: pencere ayarı sonradan değişirse geçmiş bir
uyarının kaçıncı aşama olduğu **yeniden hesaplandığında başka çıkar**.
Damga, "o gün ne yapıldı" sorusunun yanıtını sabitler.
Göç **geri alınabilir**: `downgrade` sütunu düşürür (test edildi:
downgrade → sütun yok → upgrade → sütun var). Enum değerleri bırakılır
(Postgres'te `DROP VALUE` yok — göç 0102/0103 ile aynı karar).

**Aşama sayımı da pencerelidir** (`gurultu_pencere_gun`): uyarıları
sınırsız saymak, üç yıl önce bir kez uyarılmış daireyi bugün doğrudan
"güvenliği çağır" aşamasına sokardı. Şikâyet sayımı ve uyarı sayımı
**aynı** pencereyi kullanır.

### KARAR K3.2 — Hangi ses? **`yonetio_bildirim`** (kritik kanal)
`yonetio_gurultu` **kullanılmadı**. O ses **sakine yapılan anonstur**
(7,4 sn) ve amacı daireye "sesini kıs" demek. Görevlinin ihtiyacı bir
anons değil, **kısa bir "şimdi bak" işareti** — kaçan vardiya uyarısında
verilen kararın aynısı (P208 §2). Üçüncü bir kanal da açılmadı: nadir bir
olay için kullanıcının sistem ayarlarına bir satır daha eklemek, o ekranı
okunmaz yapmaya giden yoldur.

Kullanıcı sesli uyarıları kapatmışsa eskalasyon da **sessiz kanaldan**
gider — tercih görmezden gelinmez (P207 kararı), testle kilitli.

### KARAR K3.3 — Güvenlik vardiyada değilse: **herkese gönder + yöneticiye kopya**
Sistemde "şu an vardiyada olan görevli" bilgisi **plandan** gelir; gerçek
giriş-çıkış kaydı **yok** (P203 §5'te yazılı kısıt). Plana bakıp yalnız
"vardiyadaki" kişiye göndermek, plan boş ya da yanlış olduğunda bildirimi
**hiç göndermemek** demekti — kimsenin fark etmediği bir sessizlik.

Bu yüzden bildirim **tüm aktif `security` + `guvenlik_amiri`** rollerine
gider ve **yöneticiye ayrı bir bilgi bildirimi** düşer. Gürültülü ama
**görünür** bir fazlalık, görünmez bir kayıptan iyidir. Ayrıca her iki
tarafa **in-app satır** da yazılır: push kapalı/başarısız olabilir ve o
zaman "bana geldi mi" sorusunun kalıcı yanıtı kalmazdı.

### KARAR K3.4 — Üçüncü ve sonraki kezler: **aynı eskalasyon, artan sayı**
Sistemde daha üst bir merci **yok** — polis zaten eskalasyonun kendisi.
Yeni bir "aşama 3 davranışı" uydurmak, olmayan bir yetkiyi varmış gibi
göstermek olurdu. Bildirim metni kaçıncı kez olduğunu (`kez`) taşır;
görevli ciddiyeti oradan okur. Testle kilitli: aşamalar `[1,2,3]`,
eskalasyon `kez` değerleri `[2,3]`.

### KARAR K3.5 — Sistem **kimseyi aramaz**
Metin "kontrol edin ve **gerekirse** polise haber veriniz" der. Arama
kararı ve eylemi görevlinindir. Otomatik arama, yanlış alarmda kamu
kaynağını boşuna meşgul etmek ve sorumluluğu yazılıma yüklemek olurdu.

### Şikâyet edenin kimliği
Eskalasyon metninde geçen üç şey var: **daire** (güvenliğin gideceği
yer), **sayı** ve **kaçıncı kez**. Kişi yok, şikâyet eden yok. Denetim
kaydına da güvenlikçilerin kimliği yazılmaz (denetim kaydı da bir sızıntı
yüzeyidir) — aşama ve eskalasyon bayrağı yeter.

### Susma süresiyle ilişkisi (bilinçli davranış)
Bir daire uyarıldıktan sonra `gurultu_susma_gun` boyunca **yeniden
uyarılmaz**; bu, ikinci eşiğin de o süre boyunca **beklemesi** demektir.
Bilinçli: her gece tekrarlanan bir uyarı kendisi gürültüye dönüşür. Süreyi
0 yapan tesiste eskalasyon anında çalışır (testte böyle sürüldü).

### Ölçüm — ne sürdüm
`esik_kontrol` **gerçek veritabanıyla** sürüldü (taklit yalnız push
gönderiminde, yani HTTP sınırında):
* 5 gürültü → aşama 1, sakine uyarı, **güvenliğe hiçbir şey** (gerileme kapısı);
* 5 gürültü daha → aşama 2, güvenliğe bildirim (`daire`,`sayi`,`kez`),
  yöneticiye bilgi, **sayaç sıfır**;
* 5 daha → aşama 3, aynı eskalasyon, `kez=3`;
* araya **5 görüntü kirliliği** şikâyeti → gürültü akışı **hiç
  tetiklenmedi** ve görüntü şikâyetleri **açık kaldı** (bir tipin eşiği
  ötekinin defterini silmez);
* denetim kaydında `asama` ve `eskalasyon` bayrağı;
* 7 dil parite, sesli/sessiz kanal seçimi.

**Kırma denemesi:** `eskalasyon = False` yapıldığında tam olarak 4 test
düştü (güvenliğe bildirim, yöneticiye bilgi, üçüncü kez, denetim aşaması);
geri alınca 17'si geçti.

### Ölçemediğim
Gerçek bir cihazda eskalasyon bildiriminin **duyulması**: push gönderimi
dev'de `PUSH_PROVIDER=noop` ve dev tesiste kayıtlı cihaz yok (günlükte
"PUSH hedef yok" satırları bunun kanıtı). Kanal/ses **seçimi** birim
testiyle kilitli; teslimin kendisi cihazda doğrulanmalı.

---

## §1-ek — Profil e-postası: doğrulama kodu HİÇ gönderilmiyordu

### ÖLÇÜM — kod yolunu izledim, sonra sürdüm
Akış: form → `PATCH /api/me/contact` (ad/telefon) → **`POST
/api/me/eposta/kod-iste`** → backend `me.py::eposta_dogrulama_kodu_iste`
→ `_kod_gonder_ve_dogrula` → `telefon_kodu.eposta_kodu_uret_ve_gonder`.

Gönderimi tetiklemeyen yer bulundu: uç, adres **başka bir kullanıcıda
kayıtlıysa** kod **üretmeden** `{"durum": "gonderildi"}` dönüyordu
(P184-ek §9'un sızdırmama kararı). Dev'de sürdüm:

```
SERBEST ADRES     -> 502  | mesaj_gonderim: 0 -> 1   (gönderim DENENDİ)
BAŞKASININ ADRESİ -> 200  | mesaj_gonderim: 0 -> 0   (hiç denenmedi)   <-- KUSUR
```

İkinci satır senin ölçümünle birebir aynı: **kayıt bile oluşmuyor**.

### NEDEN P196 BU AKIŞI KAPSAMADI
P196, *"gönderim **denendi** ama başarısız oldu, yine de başarılı
dendi"* hâlini kapattı: sağlayıcının sonucunu okuyup 502 dönmeye başladı.
Buradaki hâl ise *"gönderim **hiç denenmedi**"*ydi ve akış o kontrolden
**önce** `return` ediyordu. P196'nın kapısı doğru yerdeydi; **kapının
önünden geçen bir yol** vardı.

### KARAR K1.3 — Adres başkasındaysa: sessiz "gönderildi" değil, **409**
P184-ek §9'un kararı **değiştirildi**. Gerekçe:
1. **Bu uç kimlik doğrulanmış ve tenant'a kapalı.** `auth.py`'deki
   giriş-kodu / parola-sıfırlama uçları **kimliksizdir**; onlarda tek
   biçimli yanıt zorunlu ve **dokunulmadı**. Burada soran kişi zaten o
   tesisin üyesi; öğrendiği şey "bu adres tesisimde kayıtlı" — sakin,
   personel ve daire listeleri ona zaten görünüyor.
2. **Bedeli kalıcı bir çıkmazdı**: kullanıcı kendi e-postasını
   düzeltemiyor ve nedenini öğrenemiyor. Bilgi sızdırmayan ama
   **kullanılamaz** bir akış.
3. Kaba kuvvet zaten sınırlı: `kod_istegi_say` adres başına hız sınırı
   uyguluyor ve bu daldan **önce** çalışıyor.

Yanıt **kimin** kullandığını söylemez, yalnız "kullanımda" der.

### KARAR K1.4 — Yapısal kapı: **iz yoksa "gönderildi" yok**
`_kod_gonder_ve_dogrula` artık sonuca değil **ize** bakıyor: gönderim
denendiyse `telefon_kodu` **ayrı oturumda** bir `mesaj_gonderim` satırı
yazar (başarılı ya da başarısız). Satır yoksa → **502** + log.

Bu, "bir sonraki erken `return`" için de geçerlidir: kapı, çağıranın
hangi yeni dalı eklediğinden **bağımsız** çalışır. Aradığı şey bir
karar değil, bir **iz**.

### §4 — Aynı kalıp tüm kod gönderen akışlarda tarandı
İki sınıf, iki farklı kural:

| Akış | Sınıf | Kural | Test |
|---|---|---|---|
| Profil e-posta (`/me/eposta/kod-iste`) | kimlik doğrulanmış | iz yoksa **hata** | ✅ 3 test |
| Hesap silme kodu (`/me/hesap-sil/eposta-kod-iste`) | kimlik doğrulanmış | iz yoksa **hata** | ✅ |
| Giriş kodu (`/auth/giris/eposta-kod-iste`) | **kimliksiz** | yanıt tek biçim; **hedef varsa iz olmalı** | ✅ 2 test |
| Parola sıfırlama (`/auth/sifre/kod-iste`) | **kimliksiz** | aynı | ✅ |
| Davet e-postası (`POST /users`) | yönetim | "gönderildi" diyorsa iz olmalı | ✅ |

Kimliksiz akışlarda hatayı kullanıcıya yansıtmak **"hata = adres
kayıtlı"** anlamına gelirdi; orada kilit **yanıtı değil davranışı**
ölçer: hedef varsa gönderim gerçekten denenmiş olmalı, hedef yoksa yanıt
aynı kalır ve iz de olmaz.

### Kırma denemeleri
* Eski sessiz `return {"durum": "gonderildi"}` geri konduğunda 409 testi
  düştü; geri alınca 8'i geçti.
* Test yazarken **hız sınırı** (429) iki testi anlamsız yere kırdı: sabit
  adres kullanmak, tekrarlanan koşumlarda aynı sayaç anahtarına
  vuruyordu. Testler artık her koşumda **taze adres** üretiyor — bu da
  ölçülmüş bir ders.

### Ölçemediğim
Prod'da gerçek SMTP ile teslim. Dev'de SMTP yapılandırılmadığı için
`durum='basarisiz'` kaydı düşüyor ve uç 502 dönüyor — **doğru davranış**:
kullanıcı "bekleyin" ekranı yerine hatayı görüyor.
