# P177 — Verilen kararlar, gerekçeleri ve bulunan eksikler

Bu belge, brief'te **karara bırakılan** noktaları ve çalışma sırasında
ortaya çıkan **çakışma/eksiklikleri** kayda geçirir. "KARAR VERİLDİ"
işaretli maddeler tartışılmadı; onlar yalnızca *uygulandığı yerde*
referans verilerek geçiyor.

---

## 0. Özet — bir bakışta kararlar

| # | Konu | Karar | Neden kısaca |
|---|------|-------|--------------|
| 1 | Bayrak nerede | `YENI_KAYIT_AKISI` **yalnız backend'de** | İki bayrak ayrışır; kapalı olan sessizce kazanmaz |
| 2 | Tesis oluşturma adımı | Tanıtım sitesinde (3. adım) | app-test/mobil giriş ekranlarına dokunmamak için |
| 3 | Site tek dilli | Türkçe | Okuyucu Türkiye'deki site yöneticisi |
| 4 | Adaptif ikon zemini | `#FFFFFF` | Mağazalar arası tek kimlik (ölçüm aşağıda) |
| 5 | Favicon/PWA zemini | Beyaz (saydam değil) | Koyu tema sekmede lacivert marka kaybolur |
| 6 | Eski yollar | `test.yonetio.site` → app-test'e **301** | `/_next/*` çakışması yol-bazlı bölmeyi imkânsız kılıyor |
| 7 | SSO | Butonlar app-test'e devreder | Pazarlama alanında oturum açmamak için |
| 8 | Yazı tipi | Yalnız Inter (yerel, latin + latin-ext) | Ağ bağımlılığı yasak; 2. aile için dosya yok |
| 9 | Hukuki metinler | admin-web'den **birebir kopya** + kayma testi | İki ayrı Docker yapım bağlamı |
| 10 | Çok tesisli üyelik | `tesis_uyelik` tablosu bugün açıldı | Sonradan eklemek şema göçü gerektirirdi |
| 11 | Parola politikası | Yeni akış da `validate_password_strength` | İki kapı, iki farklı güç sınırı olmamalı |
| 12 | `yonetici_basvuru` kolonları | `tenant_id`/`user_id` **kaldırıldı** | Politikasız tablo "tenant kapsamlı" görünmemeli |
| 13 | SMS ana şalteri | Panelin "hazır" rozetini de bağlar | Kapalı kanalda "hazır" demek yalan olurdu |

---

## 1. Uygulama ve dağıtım

### 1.1 `apps/tanitim-web` — depo kökünde `apps/` dizini yoktu

Brief iki kez `apps/tanitim-web` diyor; uygulandı. Ancak depoda mevcut
Next uygulaması **kökte** (`admin-web/`), yani artık iki farklı yerleşim
var: `admin-web/` ve `apps/tanitim-web/`.

Bu bir tutarsızlıktır ve bilerek bırakıldı: `admin-web`i taşımak
`infra/docker-compose*.yml`, `Dockerfile` yapım bağlamları, CI ve tüm
göreli test yollarını kırardı — brief'in istemediği bir risk. Tek
yerleşime geçmek ayrı bir iş paketidir.

### 1.2 Next sürümü ve paket yöneticisi ayrıştırılmadı

`next@^14.2.35`, `react@18.3.1`, `tailwindcss@3.4.6`, `typescript@5.5.3`,
npm + `package-lock.json` — hepsi `admin-web` ile aynı. `Dockerfile` de
aynı üç aşamalı desen (deps → builder → runner, `output: "standalone"`).

### 1.3 Caddy — eski yollar 301'lendi, yol bazlı bölme YAPILMADI

**Bu turun en kritik teknik kararı.**

`test.yonetio.site` bugün `admin-web`i sunuyor ve üzerinde **çalışan
yollar** var:

| Yol | Ne | Kim kullanıyor |
|-----|-----|----------------|
| `/davet/<jeton>` | Davet bağlantısı | `PORTAL_BASE_URL` ile üretilen her davet e-postası |
| `/gizlilik`, `/kosullar` | Hukuki belgeler | Mağaza listelemeleri, mobil uygulama |
| `/hesap-silme` | Play veri silme adresi | Play Console |
| `/.well-known/*` | Universal Links / App Links | iOS + Android doğrulayıcıları |

İlk düşünülen çözüm — bu yolları `admin-web`e, gerisini `tanitim-web`e
vekillemek — **çalışmaz**: iki Next uygulaması da varlıklarını
`/_next/static/...` önekinden ister. Aynı önek iki upstream'e
bölünemez; yanlış uygulamadan gelen bir parça sayfayı **sessizce** bozar
(200 döner, JS çalışmaz).

`assetPrefix` ile ayrıştırma da denenebilirdi (`/tanitim-varlik/_next/...`
+ `handle_path`), ama bu her Next yükseltmesinde yeniden doğrulanması
gereken kırılgan bir katman ekler.

**Seçilen:** dört yol grubu `app-test.yonetio.site`e **301** ile gider.
`{uri}` korunur, yani jeton ve derin yollar kaybolmaz; eski davet
bağlantıları çalışmaya devam eder. Tarayıcı 301 izler.

`.well-known` dosyaları **yönlendirilmez** — iOS/Android doğrulayıcıları
3xx izlemez. Onlar Caddy'nin kendi `file_server`ından (`./portal` mount'u)
doğrudan servis edilir; bu mekanizma zaten vardı (`(wellknown)` snippet).

`PORTAL_BASE_URL` **değiştirilmedi**: yeni davetler de
`test.yonetio.site/davet/...` üretir ve 301 ile hedefe varır. Değiştirmek,
"app-test'e dokunulmayacak" maddesine daha çok dokunmak olurdu.

### 1.4 Depodaki Caddyfile'ın varsayılanı `tanitim.localhost`

Prod dondurulmuş. `TANITIM_DOMAIN` verilmezse blok `tanitim.localhost`
konağına bağlanır: Caddy `.localhost` adlarına **ACME'ye hiç gitmeden**
dahili sertifika verir. Yani prod'da blok var ama dışarıya açılmaz ve
Let's Encrypt'e tek bir istek bile gitmez. Bloğu tümden silmek
`docker compose config` çıktısını depodan ayrıştırırdı.

### 1.5 `.env.prod` satır tekrarı

`.env.prod` depoda yok (gitignore). `.env.prod.example` **önce okundu**,
sonra eklendi; `grep -o "^[A-Z_]*=" | sort | uniq -d` ile tekrar olmadığı
doğrulandı. Sunucudaki `.env.prod` için `docs/P177-dagitim.md`
grep-korumalı bir ekleme adımı veriyor.

---

## 2. Tanıtım sitesi

### 2.1 Tasarım dili ve imza öğesi

Panelin metalik/neumorphic dili **taşınmadı** ve buradaki dil de panele
taşınmayacak; iki ayrı paket, iki ayrı `tailwind.config.ts`. Bu sitede
gölge yok, kabartma yok, koyu tema yok — düz zeminler, 1 px kenarlık ve
tipografi taşıyor.

**İmza öğesi: iki kapılı kahraman.** Bu ürünün ön kapısındaki en
karakteristik gerçek, kapıya iki farklı insanın gelmesi ve **yalnız
birinin** kayıt olabilmesi. Çoğu yazılım sitesi bunu gizler ve herkese
aynı "Ücretsiz dene" düğmesini gösterir; sonra sakin kaydolmaya çalışır,
olmaz ve desteğe yazar. Burada ayrım sayfanın kendisi: kahraman iki tam
yükseklikte kapıya bölünmüş (koyu = yönetici/kaydolan, açık =
sakin/bilgilendirilen), masaüstünde eğik bir dikişle buluşuyor, mobilde
alt alta yığılıyor.

**Numaralandırma yalnız "Nasıl çalışır"da.** 01/02/03 dekorasyon değil:
o bölüm gerçekten bir sıra. Yetenek kartlarında numara yok.

**Güven şeridinde müşteri logosu ve referans YOK.** Elimizde
yayımlanabilir bir referans yok; uydurmak yalan olurdu. Şerit ürünün
gerçekten taşıdığı özelliklerden kurulu (KVKK saklama/imha, değiştirilemez
denetim kaydı, rol bazlı yetki, iOS + Android).

### 2.2 Palet — logodan örneklendi

`assets/marka/yonetiyor-logo.png` içindeki 126.295 opak piksel kümelendi:

| Küme | Örneklenen | Oran | Rol |
|------|-----------|------|-----|
| Lacivert (koyu) | `#0D2352` | %26,1 | Marka laciverdi |
| Mavi (ana) | `#2C65AC` | %24,9 | Marka mavisi |
| Lacivert (açık) | `#132B63` | %18,8 | Lacivert ara ton |
| Mavi (koyu kenar) | `#22599A` | %11,2 | Gradyan durağı |
| Mavi (orta) | `#2961A5` | %5,2 | Gradyan durağı |
| Lacivert ara | `#15326C` / `#193471` | %6,1 | Gradyan durağı |
| Mavi (açık kenar) | `#1A4E89` | %2,2 | Gradyan durağı |

Gradyan taraması (altıgen gövde, y=350): `#245B9C → #285FA0 → #142B61 →
#2E66B0` — yani işaret soldan sağa açık maviden lacivere ve tekrar maviye
gidiyor.

Brief'in verdiği **#2060A0 / #102060 / #EAF1FA** bu ölçümün
yuvarlatılmış hâlidir ve **kanonik kabul edildi**; token adları
`mavi`, `lacivert`, `zemin`.

**Kontrast ölçümleri (WCAG 2.1):**

| Çift | Oran | Sonuç |
|------|------|-------|
| lacivert `#102060` / zemin `#EAF1FA` | 13,21 | AA ✓ |
| lacivert / kart `#FFFFFF` | 15,03 | AA ✓ |
| mavi `#2060A0` / zemin | 5,69 | AA ✓ |
| mavi / kart | 6,48 | AA ✓ |
| beyaz / lacivert | 15,03 | AA ✓ |
| gövde `#34435F` / zemin | 8,73 | AA ✓ |
| soluk `#4A5A78` / zemin | 6,10 | AA ✓ |
| `#B9D4F0` / lacivert (koyu bloklar) | 9,83 | AA ✓ |
| yeşil `#0E6E4E` / `#E3F4EC` (rozet) | 5,48 | AA ✓ |

**Form denetimi kenarlığı ayrı bir ton (`cizgiDenetim` `#6E88AB`).**
Dekoratif kart kenarlığı `#CFDDEF` beyazda yalnız **1,38** kontrast
taşıyor; WCAG 1.4.11 denetim sınırları için **3:1** ister. Ölçülen:
`#6E88AB` beyazda **3,64**, `#EAF1FA` üzerinde **3,20**.

### 2.3 Tek dil — Türkçe

Panel yedi dilli çünkü içinde yaşayan kullanıcılar yedi dilli. Tanıtım
sitesinin okuyucusu Türkiye'deki site yöneticisidir. Yedi dilli bir
tanıtım sitesi, yedi kez güncellenmesi gereken bir pazarlama metni
demekti ve bugün karşılığı yok.

Sonuç: Inter'in yalnız `latin` ve `latin-ext` dilimleri taşınıyor
(Türkçe'nin ihtiyacı `latin-ext`te). Kiril/Yunanca dilimleri imaja
konmadı — hiçbir ziyaretçinin istemeyeceği ~160 KB.

### 2.4 İkinci bir yazı tipi kullanılmadı

Brief "display + body ayrı aileler" demiyor ama tasarım açısından bir
kayıp: kişilik yalnız Inter'in **muamelesinden** geliyor (800 ağırlık +
`-0.035em` sıkı aralık başlıklarda, 700 + `0.16em` geniş aralıklı versal
etiketlerde). İkinci bir aile eklemek ya dış bir dosya indirmek (yasak)
ya da depoya lisanslı bir font koymak demekti; ikincisi ayrı bir karar.

### 2.5 `HataDurumu` — P175 kusuru tekrarlanmadı

Buradaki kural panelinkinden **daha dar**: `mesaj` null, undefined, boş
dizge ya da yalnız boşluk ise bileşen `null` döner. **Genel yedek metin
bilerek konmadı** — P175'teki sahte hatayı tam olarak o yedek üretiyordu.

`tests/hata-durumu.test.ts` üç şeyi ölçer: bileşenin boş girdide `null`
dönmesi, kaynağında sabit bir hata cümlesi bulunmaması, ve **her çağrı
yerinin** boş geçebilen bir değer vermesi (`mesaj={hata}` + durumun
`null` başlaması).

### 2.6 Dış istek yok — taranarak kilitlendi

`tests/harici-istek.test.ts` `app/`, `components/`, `lib/`, `config/`
ağacını gezer ve yasaklı alan adlarından biri geçerse düşer (Google
Fonts, Analytics, Tag Manager, Maps, Facebook, jsdelivr, unpkg, cdnjs,
hotjar, segment, sentry). İzinli mutlak adresler **açıkça listelenir** ve
hepsi kullanıcının tıkladığı bağlantılardır — kaynak yüklemesi değil.

Derlenmiş çıktı da doğrulandı: yayınlanan HTML'de `app-test.yonetio.site`,
`play.google.com` ve `mailto:` dışında dış adres yok. (Next'in kendi JS
paketinde `fonts.googleapis.com` dizgeleri **sabit olarak** bulunur —
onun font optimizasyonu izin listesidir, istek üretmez; `admin-web`
derlemesinde de aynısı var.)

### 2.7 Mağaza rozetleri metin düğmesi

Apple/Google'ın resmî rozet görselleri kendi CDN'lerinden servis edilir
(ağ bağımlılığı yasak). Depoya kopyalamak ise marka kılavuzlarına tabi
(ölçü, boşluk, dil varyantı) ve yanlış kullanımı mağaza denetiminde sorun
çıkarır. Metin düğmesi ikisini de yapmaz.

**App Store adresi boşsa düğme çizilmez** — mağaza id'si henüz yok, boş
bir id ile kırık bağlantı göstermek hiç göstermemekten kötüdür. Aynı
kural backend'de (`settings.app_store_url`) ve panelde
(`lib/magaza.ts`) de geçerli.

---

## 3. Fiyat hesaplayıcı

KARAR VERİLDİ maddeleri (1–500, adım 1, varsayılan 50, kademe yok,
daire × 100 TL, KDV cümlesi, ücretsiz rozeti + `NEXT_PUBLIC_TANITIM_UCRETSIZ`)
birebir uygulandı; sabitler `apps/tanitim-web/config/fiyat.ts`te.

**Sürgü ve kutu tek durumdan besleniyor**, ama kutunun *metni* ayrı
tutuluyor (`ham`). Sebebi ölçülebilir: kullanıcı "50"yi silip "120"
yazmak isterse önce alanı boşaltır; metni doğrudan sayıdan türetseydik
boş alan anında "1"e sıçrar ve kullanıcı "1" ile "20"nin arasına yazmaya
çalışırdı. Hesap **her zaman sınırlı** değerden yapılır.

`aria-live` **konmadı**: değer sürgü sürüklendikçe her adımda değişiyor;
canlı bölge her adımı okuyup ekran okuyucuyu boğardı. Sürgünün kendi
değeri zaten duyuruluyor.

---

## 4. Yönetici kaydı ve tesis oluşturma

### 4.1 KARAR: tesis oluşturma adımı tanıtım sitesinde

Brief §5 "yönetici ilk kez giriş yaptığında (web veya mobil) *Site adı*
alanı çıkar" diyor. **Bu, tanıtım sitesinin 3. adımı olarak uygulandı.**

Gerekçe §0'ın sert sınırı: *"MEVCUT KİMLİK SİSTEMİ BOZULMAYACAK. Play
kapalı testi mevcut sistemle yapılacak."* app-test'in ve mobilin giriş
ekranlarına yeni bir ilk-giriş adımı eklemek, tam da o testin dayandığı
akışa dokunmak olurdu.

Yolculuk aynı: yönetici kaydolur → e-postasını doğrular → site adını
yazar → Tesis ID'sini **ekranda görür ve e-postayla alır** → app-test'e
**hazır** bir tesisle girer. Kullanıcı açısından fark yok; değişen yalnız
adımın hangi konakta çizildiği.

### 4.2 Neden üç adım, tesis neden sonda

Tesis 3. adımda açılıyor çünkü **doğrulanmamış bir adresle açılan tesis,
sahibine ulaşılamayan bir tesis** olurdu. Mevcut `tesis-olustur` ucu
(telefon kimliğiyle, tek adım) **duruyor ve değişmedi**; iki yol
birbirini bozmadan yan yana yaşıyor.

### 4.3 SSO — üç buton yerleşti, sosyal yol app-test'te bitiyor

Üç buton da çizilir. Microsoft ve Apple varsayılan kapalı: `disabled` +
`aria-disabled` + "Yakında" rozeti. Açmak için **yalnız bayrak**
(`NEXT_PUBLIC_SSO_*`), kod değişmiyor.

**Google butonu OAuth turunu tanıtım sitesinde başlatmıyor**, kimlik
yüzeyine (app-test) devrediyor. Sebep: OAuth dönüşü bir **oturum**
üretir. Oturumu tanıtım alan adında açmak, (a) yeni bir `redirect_uri`yi
Google/Microsoft/Apple konsollarına kaydetmek, (b) yeni bir CORS kökeni
açmak, (c) jetonları bir **pazarlama** alan adında saklamak demekti. Üç
yeni güvenlik yüzeyi, sıfır kazanç.

**Bilinen boşluk:** sosyal yolda onay kutularının kaydı tanıtım sitesinde
tutulmuyor (parola yolunda tutuluyor). Bugün pratikte etkisiz — Microsoft
ve Apple kapalı, Google app-test'e gidiyor ve orada mevcut akış işliyor.
Sosyal yolun onay kaydı ayrı bir iştir; aşağıda "Eksikler"e yazıldı.

### 4.4 Zorunlu iki onay hem parola hem sosyal yolu kilitler

`dugmeKilitli` tek yerden hesaplanır ve hem gönder düğmesine hem
`SsoDugmeleri`ne verilir. Parola yolunda onay arayıp sosyal yolda
aramamak, onayı bir formaliteye çevirirdi.

Kapı **üç katmanda**: arayüz (`disabled`), sunucu şeması
(`YoneticiBasvuruRequest._zorunlu_onaylar` → 422) ve veritabanı kısıtı
(`ck_yonetici_basvuru_zorunlu_onay`). Üçüncüsü, ileride yazılacak bir
ucun onayı atlamasını **yapısal olarak** engeller.

### 4.5 Ticari ileti: rıza saklanır, gönderim kapalı — ve bayrak GERÇEKTEN okunuyor

`onay_ticari` `yonetici_basvuru` satırında zaman damgası + IP + tarayıcı
ile saklanır ve tesis açılırken `app_user.pazarlama_eposta`ya yazılır.

`TICARI_ILETI_AKTIF=false` (varsayılan) **gönderim yolunda okunuyor**:
`routers/mesajlar.py` içinde, `amac='pazarlama'` şablonlar için **rıza
kontrolünden önce** kapı kapanır — yani rızası olan kişiye bile ileti
gitmez. Bir ayar tanımlayıp hiçbir yerde okumamak en sinsi kusur
türlerindendir; `test_p177_sms_ve_ileti.py::test_ticari_ileti_kapisi_GONDERIM_YOLUNDA`
bunu kaynak taramasıyla kilitliyor.

### 4.6 Parola politikası birleştirildi — **ölçülmüş bir kusur**

İlk yazımda `YoneticiBasvuruRequest.parola` yalnız `min_length=8`
taşıyordu. Ölçüldü: `"GucluParola123"` yeni kayıt yolundan **geçiyor**,
aynı parola `POST /auth/set-password` ucundan **422** alıyordu (sembol
eksik). Yani yeni kapı eskisinden zayıftı.

Düzeltildi: alan `validate_password_strength` kullanıyor (8+ karakter,
büyük harf, rakam, sembol). Formdaki yardım metni de politikanın aynısını
yazıyor — yalnız "8 karakter" demek, kullanıcıyı sunucunun reddedeceği
bir parolayı yazmaya davet etmek olurdu.

### 4.7 Onay kaydı için IP başlıktan geliyor

Tarayıcı kendi IP'sini bilemez. BFF `X-Istemci-Ip` (X-Forwarded-For'un
**ilk** değeri) ve `X-Istemci-Ajan` başlıklarını ekler. İstemcinin
uydurabileceği bir değer olduğu için **yetki kararında kullanılmaz**,
yalnız kaydedilir.

Uçtan uca doğrulandı: `x-forwarded-for: 203.0.113.42, 10.0.0.1` gönderen
bir istek `yonetici_basvuru.onay_ip = 203.0.113.42` bıraktı.

### 4.8 Hoş geldin e-postası sade ve tek fonksiyonda

`_yonetici_hosgeldin_metni()` — brief "tasarıma vakit harcama, şablonu
tek yerden değiştirilebilir tut" diyor. Düz metin; içerik: Tesis ID,
web giriş adresi (`PORTAL_BASE_URL`), yapılandırılmış mağaza bağlantıları.
HTML şablonu geldiğinde değişecek yer **yalnız bu fonksiyon**.

---

## 5. Rol kaydı — üç şart (§6)

KARAR VERİLDİ; uygulandı ve **iki kez** kontrol ediliyor (`basla` ve
`dogrula`). Tekrar değil gereklilik: iki adım arasında dakikalar geçer ve
o arada yönetici kişiyi listeden çıkarmış, rolünü değiştirmiş ya da hesap
başka bir yoldan sahiplenilmiş olabilir.

**"Listede olmak" ölçülebilir tanımı:** o tenant'ta, verilen e-postayla,
**aktif**, **istenen rolde** ve **parolası henüz belirlenmemiş** bir
`app_user` satırı var demektir. Son şart önemli — parolası olan hesap bu
yoldan geçmez, yoksa uç ikinci bir **parola sıfırlama yüzeyi** olurdu
(telefon yolundaki kuralın aynısı).

**Kuyruk sebebi ayırt edilebilir** (`liste_disi` / `rol_uyusmuyor` /
`hesap_kullanimda`): yöneticinin panelinde ilkinde kişiyi eklemek,
ikincisinde rolü düzeltmek gerekir. "Bir şey oldu" demek yöneticiyi
tahmine bırakırdı.

**Uygun olmayan adrese kod GÖNDERİLMEZ.** Yanıt aynıdır ama kod
üretilmez: göndermek, adresin sistemde olup olmadığını gelen kutusundan
okutmak olurdu.

### 5.1 Rol listesinde `yonetici`/`admin` yok

`_ROLLER = ("resident", "security", "gorevli")`. Yönetici kendi yolundan
(başvuru) gelir; ek yöneticiyi mevcut yönetici ekler. Bu uç, yöneticinin
**önceden eklediği** kişiler içindir.

### 5.2 Çok tesisli üyelik bugün açıldı

`tesis_uyelik` tablosu göç 0068'de açıldı ve **mevcut her e-postalı
kullanıcı için geriye dolduruldu**. Kimlik anahtarı **e-postadır**
(`user_id` tenant'a bağlı, e-posta kişiye).

Bugün kimse **sorgulamıyor** — açıldığında yapılacak iş, giriş yolunun
tek bir `app_user` yerine bu tablodan üyelik listesi çıkarması ve
kullanıcıya tesis seçtirmesi. Bugün yapılmadı çünkü o, çalışan giriş
akışını değiştirmek demekti (§0).

E-postası olmayan kullanıcılar atlandı: `app_user.email` sakinlerde NULL
olabilir ve boş bir anahtarla satır yazmak ileride "aynı kişi"
eşleşmesini bozardı.

### 5.3 SMS kapısı ayrı bir sınıf

`KapaliSmsSaglayici`, `LogSmsSaglayici`den **ayrı** ve bu bilinçli: ikisi
de göndermez ama söyledikleri şey farklı. "Yapılandırılmadı" → ayarları
doldur; "kapalı" → yapılacak bir şey yok. Yöneticiyi ayarlar sayfasına
yollamak boşuna bir yolculuk olurdu.

Ana şalter `_ayardan_veya_env`**den önce** okunuyor. Sonra bakılsaydı,
arayüzden SMS ayarı girmiş bir tesiste şalter **etkisiz** kalırdı —
`test_kapali_bayrak_saglayiciyi_EZER` bunu ölçüyor.

---

## 6. Marka ve ikon üretimi

### 6.1 Logo kaynağı tek yere taşındı

Aynı dosya iki yerdeydi (`docs/` altında iki izlenmeyen kopya,
`mobile/assets/branding/Yönetiyor-logo.png` izleniyor ama **hiçbir yerden
referans verilmiyor**). Kanonik kaynak
`assets/marka/yonetiyor-logo.png` (git mv ile taşındı, ASCII ad).

**SVG yok** — depoda hiçbir SVG bulunamadı; PNG kullanıldı.

### 6.2 Kırpma kutusu — KARAR VERİLDİ, ölçümle doğrulandı

Kaynak 1072×992 RGBA. Markanın **ölçülen** alfa sınır kutusu:
`(303, 182) – (768, 810)` = **466×629** — brief'in verdiği rakamlarla
birebir aynı. Kırpma `(303, 182, 769, 641)` → **466×459**.

`scripts/ikon-uret.py` her koşumda kaynağın boyutunu **ve** sınır
kutusunu doğrular; uymuyorsa **açıkça durur**. Kutu bir karardır ve
kaynak dosya değişirse sessizce kaymamalı.

### 6.3 KARAR: adaptif zemin `#FFFFFF`

Alternatif `#EAF1FA` idi. Ölçüldü: `#EAF1FA`nın L\* değeri ≈ **93,4**,
beyazınki 100 — yani **ΔL\* ≈ 6,6**. Bu yan yana **görülebilir** bir fark;
"48 px'te fark edilmez" demek doğru olmazdı.

Yine de beyaz seçildi: iOS 1024 ve Play 512 ikonları brief gereği
**zorunlu beyaz**. Android plakasını farklı yapmak, aynı ürünün ikonunu
mağazalar arasında **iki farklı renk** yapardı; çapraz platform tanıtım
görsellerinde Android ikonu beyaz iOS ikonunun yanında gri bir halka
gibi okunurdu. Diğer ikonlardan ayrışma, plakayı boyayarak değil
**işaretin kendisiyle** (ayırt edici mavi altıgen) sağlanıyor.

### 6.4 KARAR: favicon ve PWA ikonları beyaz zeminli

Marka mürekkebi koyu lacivert. Saydam bir favicon, koyu temalı tarayıcı
sekme şeridinde neredeyse görünmez olurdu; `purpose: "any"` PWA ikonu da
bazı başlatıcılarda düz çizilir.

### 6.5 ALFA KONTROLÜ — programatik sonuç

`scripts/ikon-uret.py` üretimden sonra **IHDR renk tipine** bakar
(değerlere değil): renk tipi 4/6 alfa taşır, `tRNS` parçası da alfa
sayılır.

```
ios-appstore-1024.png              alfa kanali: YOK
play-store-512.png                 alfa kanali: YOK
apple-touch-icon.png               alfa kanali: YOK
icon-192.png                       alfa kanali: YOK
icon-512.png                       alfa kanali: YOK
android-adaptive-foreground.png    alfa kanali: VAR
android-monochrome.png             alfa kanali: VAR
android on katman isaret kutusu: 675x664 (sinir 675x675) -> %65.9
dairesel maske disinda kalan isaret pikseli: %3.78
TUM DENETIMLER GECTI
```

`flutter_launcher_icons` çıktısı da doğrulandı: **21 iOS ikon dosyasının
hiçbirinde alfa kanalı yok.**

**"Saydamlığı 255'e çekmek" yetmez:** dosya yine 4 kanallı olur ve App
Store yüklemesi (ITMS-90717) alfa kanalının **varlığına** bakar. Bu
yüzden `yaz_opak()` PNG'yi renk tipi 2 (truecolor, 3 kanal) olarak yazar
ve `tRNS` parçası **yazılmaz**.

### 6.6 Dairesel maske ölçümü — dürüst rakam

İşaret pikselinin **%3,78'i** %66'lık dairenin dışında kalıyor (altıgenin
köşe bölgeleri). Kutu-oturtma yerine **daire**-oturtma yapılsaydı işaret
`675/√2 ≈ 477` px'e, yani tuvalin **%46,6'sına** inerdi — 48 px launcher
boyutunda işareti okunamaz kılan tam da bu.

Brief güvenli alanı **kutu** olarak tanımlıyor ("tuvalin en fazla %66'sı")
ve kabul kriteri de öyle; kutu-oturtma uygulandı, ölçüm buraya yazıldı.
Kırpılan bölgeler işaretin **boş köşeleri**dir.

### 6.7 `tools/png-arac.py` genişletildi — ortamda görüntü aracı yok

Ortamda PIL/ImageMagick/sharp/pip **yok**. Mevcut saf-Python
`tools/png-arac.py` (P162) genişletildi: `kutu_kirp`, `buyut` (ön
çarpımlı bilinear), `yeniden_boyutla`, `bos_tuval`, `uzerine_ciz`,
`beyaza_boya`, `yaz_opak`, `alfa_var_mi`, `ico_yaz`.

**Büyütme için ayrı bir yol gerekti:** mevcut `olcekle()` kutu
ortalamasıdır ve yalnız küçültmede doğru sonuç verir; büyütmede kutu tek
piksele düşüp en-yakın-komşuya çöker. İkonların çoğu büyütmedir
(466 px kırpma → 1024 px tuval).

**Ön çarpım zorunlu:** saydam pikselin RGB'si bu dosyada 0 (siyah); ham
RGB'yi harmanlamak işaretin çevresine siyah bir hale bırakırdı.

### 6.8 Mobil bağlama — `icon_master.png`e dokunulmadı

`flutter_launcher_icons` artık `../assets/marka/ikon/` altını okuyor
(`adaptive_icon_monochrome` de eklendi, Android 13+ temalı ikon).

`icon_master.png` **dokunulmadan duruyor**: o bir **çalışma zamanı**
varlığıdır (giriş ekranı + splash, `yonetio_logo.dart`), launcher girdisi
değil. Değiştirmek istenmeyen bir arayüz değişikliği olurdu.

`targetSdk`, `versionCode`, imzalama alanlarına **dokunulmadı**.
`flutter_launcher_icons` aracının `Runner.xcodeproj/project.pbxproj`
içinde yaptığı yan etki (`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`
= `YES` → `AppIcon`) **geri alındı** — istenmeyen bir yapı ayarı
değişikliğiydi.

---

### 6.9 SMS ana şalterinin YAN ETKİSİ — ölçülüp düzeltildi

`SMS_AKTIF=false` eklenince `sms_saglayicisi()` artık `KapaliSmsSaglayici`
dönüyor. Bu, `routers/mesajlar.py`deki hazırlık rozetini **sessizce
bozdu**:

```python
sms_hazir = not isinstance(kanal_saglayicisi("sms", ayar), LogSmsSaglayici)
```

`KapaliSmsSaglayici`, `LogSmsSaglayici` **olmadığı** için bu satır
"hazır" diyordu. Sonuç: panel yarım yapılandırılmış bir tesise
**"SMS hazır"** gösteriyor, rozet **"genel ayardan çalışıyor"** diyordu.
İkisi de yanlıştı ve bu tam olarak P168'de kapatılan kusur sınıfı —
gönderilmeyecek bir mesajı gönderilecekmiş gibi göstermek.

`test_mesaj_ayarlari.py::test_YAPILANDIRMA_YOKKEN_kaynak_YOK` bunu
yakaladı (`assert 'genel' == 'yok'`). Düzeltme: her iki sınıf da
"hazır değil" sayılıyor.

İkinci sonuç: **tam yapılandırılmış** bir tesis de kanal kapalıyken
"hazır" değildir — ve bu doğrudur. `test_HAZIR_BAYRAGI_gercek_secimle_AYNI_yoldan`
buna göre güncellendi: yarım yapılandırma **her kipte** hazır değil;
tam yapılandırmanın sonucu ana şaltere bağlı, iki daldan tam biri
tutmalı.

Aynı sınıf üçüncü bir yerde: `test_kvkk_riza.py::test_pazarlama_gonderimi_RIZAYA_bagli`
"rıza verilince gider" diyordu. `TICARI_ILETI_AKTIF=false` ile artık
**rıza verilse bile gitmez**. Test iki kipi de kabul edecek ama
**tam birini** zorunlu kılacak şekilde güncellendi.

### 6.10 Yeni şema nesnelerinin envanterlere kaydı

Depoda dört ayrı "yeni bir şey eklendiyse kaydet" kapısı var ve
dördü de bu turda düştü — **doğru davrandılar**:

| Kapı | Ne istedi | Yapılan |
|------|-----------|---------|
| `test_rls_kapsam::test_her_tablonun_politikasi_var` | Politikasız tablo ya platform tablosu olmalı ya politikası olmalı | `yonetici_basvuru`dan `tenant_id`/`user_id` **kaldırıldı** — tablo gerçekten platform tablosu oldu (artık 2/2 tavan içinde) |
| `test_secdef_kapsam::test_envanter_katalogla_ortusuyor` | Her SECURITY DEFINER fonksiyon rol kapısıyla envantere yazılmalı | 6 fonksiyon `public` kapısıyla ve **neden keşif yüzeyi açmadıklarının dört kuralıyla** eklendi |
| `test_indeks_kapsam::test_her_fk_en_az_oncu_kolon_indeksine_sahip` | Her FK'nin öncü kolonu indeksli olmalı | `ix_tesis_uyelik_user` eklendi (`uq_tesis_uyelik`te `user_id` **ikinci** kolon, karşılamıyordu) |
| `test_denetci_salt_okuma::test_ROL_KAPISI_OLMAYAN_mutasyon_uclari_BEKLENEN_KUME` | Rol kapısı olmayan her mutasyon ucu açıkça listelenmeli | 5 yeni uç, neden kapı konamayacağı ve neden yüzey açmadıklarıyla eklendi |
| `test_yetki_kapsam::test_rol_matrisi_kilidi` | Rol matrisi kilidi güncel olmalı | Kilit yeniden üretilip depoya kopyalandı (5 yeni satır) |

`yonetici_basvuru.tenant_id`in kaldırılması bir **bilgi kaybı değil**:
tamamlanan başvurunun e-postası `app_user.email`de ve
`tesis_uyelik.eposta`da duruyor; "bu başvuru hangi tesis oldu" sorusu
e-posta üzerinden yanıtlanır. İki kolon için bir izolasyon kuralını
bulandırmak doğru olmazdı.

## 7. Bulunan eksikler ve çelişkiler

### 7.1 ⚠️ Kullanım Koşulları §2 yeni akışla ÇELİŞİYOR

Mevcut metin (`admin-web/lib/hukuki/kosullar.ts`, TR, madde 2):

> "Hesaplar tesis yönetimi tarafından açılır; **herkese açık bir kayıt
> formu yoktur**."

Bu turda açılan yönetici self-signup formu bu cümleyle doğrudan çelişir.
**Metin değiştirilmedi** — "METİN UYDURMA" kuralı ve bu bir hukukçu
kararıdır. Bayrak açılmadan önce bu maddenin güncellenmesi gerekir.

### 7.2 ⚠️ Müstakil çerez politikası belgesi YOK

P160–P176 arasında arandı: müstakil bir çerez politikası **hiç
yazılmamış**. Var olan tek çerez metni, KVKK Aydınlatma Metni'nin
8. bölümüdür.

`/cerez-politikasi` sayfası o bölümü **olduğu gibi** gösteriyor
(kopyalamıyor — KVKK metninden türetiyor, yani orası güncellenirse burası
da güncellenir) ve üstünde belgenin tamamlanmadığını açıkça söyleyen bir
not taşıyor. Not hukuki metin değil, site bildirimidir.

### 7.3 ⚠️ Hukuki metinler iki yerde — kayma testiyle kilitlendi

`apps/tanitim-web/lib/hukuki.ts` panelin TR bloklarının **birebir
kopyasıdır**. Kopya değil import olamazdı: iki Next uygulaması ayrı
Docker yapım bağlamlarında derleniyor.

`tests/hukuki-esitlik.test.ts` iki dosyayı okuyup bölüm başlıklarını
karşılaştırır; panelde bir madde eklenip burada unutulursa test düşer.
**Kalıcı çözüm** (tek paylaşılan paket) ayrı bir iştir.

### 7.4 Sosyal yolda onay kaydı tutulmuyor

§4.3'te açıklandı. Bugün etkisiz (MS/Apple kapalı, Google app-test'te),
ama Google yolu tanıtım sitesine taşınırsa kapatılması gereken bir boşluk.

### 7.5 Mobil kayıt ekranları bu turda YAZILMADI

§6'nın mobil akışı (Kayıt Ol → rol seç → telefon/parola veya SSO → Tesis
ID → e-posta OTP) **backend tarafında tamamen hazır ve test edilmiş**
(`/auth/kayit/rol-eposta-basla`, `/auth/kayit/rol-eposta-dogrula`), ama
**Flutter ekranları bağlanmadı**.

Ölçülebilir sonuç: kabul kriteri 9 ve 10 API düzeyinde geçiyor
(`test_p177_kayit_akisi.py`), kullanıcı düzeyinde **geçmiyor** — mobil
uygulamada bu akışa giden bir ekran yok. Ayrı bir iş paketi olarak
raporlanıyor; bu turda yapılmamasının sebebi kapsam, teknik bir engel
değil.

### 7.6 Onay kuyruğu paneli YAZILMADI

`kayit_onay_kuyrugu` tablosu doluyor ve doğru sebeple doluyor
(test edildi), ama yöneticinin bu kuyruğu **göreceği panel ekranı ve
listeleme/onaylama ucu** bu turda yazılmadı. Yani deneme kaybolmuyor ama
bugün yalnız veritabanından görülebiliyor. Ayrı iş paketi.

### 7.7 Prod'a hiçbir şey uygulanmadı

`infra/.prod-dondurma` dosyasına dokunulmadı, prod deploy tetikleyen
hiçbir şey yazılmadı. `TANITIM_DOMAIN` tanımsızken Caddy bloğu
`tanitim.localhost`a bağlanır ve ACME'ye gitmez.

`api.yonetio.site` ve `storage.yonetio.site` isimlerine **dokunulmadı**.

---

## 8. Ölçüm özeti

Hepsi bu turda **koşuldu**; rakamlar ölçümdür, tahmin değil.

| Ne | Sonuç |
|----|-------|
| `apps/tanitim-web` derlemesi | ✓ 13 rota, `next lint` temiz |
| `apps/tanitim-web` testleri | ✓ **24/24** (fiyat, boş-hata kuralı, dış istek yasağı, hukuki kayma, erişilebilirlik) |
| Yayınlanan HTML'de dış adres | ✓ **yok** (7 sayfa tarandı; yalnız `play.google.com` ve `app-test` — ikisi de kullanıcının tıkladığı bağlantı) |
| Rendere edilmiş sayfalarda `alt` / `label` | ✓ 5 sayfa: **0** alt'sız görsel, **0** etiketsiz form alanı |
| Backend — TAM SUİT (bayrak AÇIK) | ✓ **1875 geçti**, 7 atlandı, 2 geçici bağlantı hatası* |
| Backend — bayrak KAPALI | ✓ 6 geçti (11 atlandı: açık-kip ölçümleri) |
| Backend — bayrak AÇIK (P177 dosyası) | ✓ 11 geçti (6 atlandı: kapalı-kip ölçümleri) |
| SMS / ticari ileti kapıları | ✓ **9/9** |
| Sözleşme sapması + yetki matrisi kilidi | ✓ (kilit yeniden üretildi: 5 yeni satır) |
| RLS / SECDEF / indeks / denetçi envanterleri | ✓ (dördü de güncellendi) |
| İçe aktarım geri alma | ✓ backend **12/12**, zincir testi **4/4** |
| `admin-web` tam suit | ✓ **1406/1406** (151 dosya) |
| `mobile` tam suit | ✓ **1925/1925** (3 atlandı) — ikon değişikliği hiçbir şeyi kırmadı |
| İkon üretimi + alfa denetimi | ✓ tüm denetimler geçti, **deterministik** (iki koşum bit bit aynı) |
| Üretilen iOS ikon dosyaları | ✓ **21 dosyanın hiçbirinde alfa kanalı yok** |
| Göç 0068 downgrade → upgrade | ✓ tersinir (üç kez koşuldu) |
| Caddyfile (depo + snippet) | ✓ `caddy validate` ikisinde de geçti |
| Uçtan uca kayıt (tanıtım sitesi BFF → API → DB) | ✓ başvuru → kod → tesis; IP `203.0.113.42` onay kaydına yazıldı |

\* **İki geçici hata neydi:** `test_guvenlik_amiri.py::test_ADMIN_HER_IKI_MODDA_yazar`
30 dakikalık koşumun ortasında `psycopg.OperationalError` verdi — oturum
kapsamlı `owner_conn` bağlantısı `[BAD]` duruma düşmüştü. Şema ya da
mantık hatası değil, **bağlantı düşmesi**: aynı dosya tek başına
koşulduğunda **15/15** geçiyor (doğrulandı).

**İlk koşumda çıkan 10 başarısızlık + 15 hata ne oldu:**
* 4'ü `test_sms_gecidi` — ana şalter eklendiği için `_Ayar` saplamasında
  `sms_aktif` yoktu; saplama güncellendi (§6.9).
* 2'si `test_mesaj_ayarlari` — **gerçek regresyon**, düzeltildi (§6.9).
* 1'i `test_kvkk_riza` — ticari ileti şalteri; test iki kipi de ölçecek
  şekilde güncellendi (§6.9).
* 3'ü RLS / SECDEF / indeks envanterleri — yeni şema nesneleri kaydedildi (§6.10).
* 15 hata + 1 denetçi kümesi — 14'ü `uq_tenant_kayit_kodu` çakışması:
  **iki pytest koşumu üst üste bindiği** için `world` fixture'ı aynı
  `AXXX-<tarih>` kodunu iki işlemde üretti. Tek başına koşulduğunda hepsi
  geçiyor; şema ile ilgisi yok. (Bu tuzak kalıcı nota yazıldı.)

---

## 9. Bu turda YAPILMAYANLAR — açıkça

1. **Mobil kayıt ekranları** (§7.5). Backend hazır ve test edildi;
   Flutter ekranları bağlanmadı.
2. **Onay kuyruğu paneli** (§7.6). Tablo doğru sebeple doluyor; yönetici
   arayüzü ve listeleme ucu yazılmadı.
3. **Sosyal yolda onay kaydı** (§7.4). Bugün etkisiz (MS/Apple kapalı,
   Google app-test'te).
4. **Kullanım Koşulları 2. maddesinin güncellenmesi** (§7.1) — hukukçu
   kararı, metin uydurulmadı.
5. **Müstakil çerez politikası** (§7.2) — metin uydurulmadı, eksik
   olduğu sayfada yazıyor.
6. **Tarayıcı konsolu ölçümü** (§9.15). Bu ortamda tarayıcı yok; dış
   istek yokluğu HTML ve kaynak taramasıyla doğrulandı, konsol hatası
   `docs/P177-dagitim.md` §7g'de kullanıcının bakacağı adım olarak duruyor.
7. **Kayıt e-postasının GERÇEKTEN ulaşması** (§9.7). Dev'de SMTP yok;
   kod yolu ve metin içeriği test edildi, teslimat doğrulaması dağıtım
   belgesinin §7f adımıdır.
