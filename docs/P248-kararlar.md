# P248 — Kararlar

Konular: güvenlik amiri kaydı, telefon alanı, girdi güvenliği, oturum süresi.
Sıra §1 → §2 → §3 → §4. Her bölüm ayrı commit.

Yöntem E2E turuyla aynı: gerçek akış canlı API ve tarayıcı üzerinde
uçtan uca sürüldü, sonra kilit testine çevrildi.

---


## §1 Güvenlik amiri — doğrudan kullanıcı, yalnız mobil

**Kök neden (kusur yeniden üretildi).** Yönetici amiri zaten doğrudan
ekleyebiliyordu: web'de "Güvenlik Amiri" seçeneği P213 §6'dan beri var,
`POST /users` 201 döndü, davet e-postası Tesis ID'yi taşıyordu. Kusur
kayıt uçlarındaydı. Üç rol kümesi amiri tanımıyordu (`kayit._ROLLER`,
`oauth._TAMAMLA_ROLLERI`, `schemas.KayitRolu`) ve mobil kayıt ekranında
amir seçeneği yoktu. Ayrıca SMS yolunda (`auth.rol_kayit_basla`) aynı
katı rol karşılaştırması vardı.

Amir "Güvenlik"i seçince:

- e-posta yolunda `_liste_kontrolu` bunu `rol_uyusmuyor` saydı ve kişiyi
  onay kuyruğuna attı; **kod hiç gönderilmedi**,
- SSO yolunda sonuç `onay_bekliyor` oldu (kullanıcının gördüğü ekran),
- rol beyanı olmayan SSO tamamlaması da `onay_bekliyor` döndü.

"Güvenlik amiri" beyanı ise 422 ile reddediliyordu.

**Karar 1 — iki düzeltme birden.**

1. Kayıt ekranına ve üç sunucu kümesine `guvenlik_amiri` eklendi.
2. Beyan artık **rol ailesiyle** eşleşiyor (`roller.kayit_beyani_eslesir`).
   Tek aile var: `{security, guvenlik_amiri}`. Gerekçe: insanlar
   "güvenlikçiyim" ile "amirim"i ayırt etmiyor; bu karışıklık gerçek
   kullanıcılarda tekrar edecek.

**Yetki yükselmez.** Beyan hiçbir zaman yetki vermez. Açılan oturumun rolü
her zaman yöneticinin listesindeki hesaptan gelir: `rol_eposta_dogrula`
ve `set-password` hesabın kendi satırını okur.

- "Amir" beyan eden güvenlik görevlisi `security` olarak girer.
- Aile dışı beyan eskisi gibi kuyruğa düşer: tesis görevlisi "amir" derse
  `rol_uyusmuyor`.
- **Davet edilmemiş kişi** `liste_disi` ile kuyruğa düşer; kod gitmez.
  Onay akışı korundu.

**Karar 2 — amir yalnız mobilden girer.** P213 §6'daki web kararı geri
alındı.

- `yuzey.ts` içinde amir mobil-yalnız rollere taşındı ve web rotalarının
  hepsinden çıkarıldı (`/kamera-kayitlari` dahil).
- Bütün giriş yolları tek kapı olan `oturumAc`'tan geçiyor: parola, kod,
  SSO, davet/set-password, rol geçişi. `tesis-degistir` de aynı kararı
  kullanıyor.
- Amir red mesajını kendi rol adıyla alıyor ("Güvenlik amiri hesabı mobil
  uygulamadan kullanılır"). Yanıtta `mobil_uygulama` kodu dönüyor; bu kod
  mağaza bağlantılarının gösterilmesini sağlıyor.
- **Tarayıcıda kalmış eski oturum:** middleware mobil-yalnız rolün
  çerezlerini siliyor ve kullanıcıyı mesajlı giriş ekranına yolluyor.
  Eskiden bu roller panoya düşüp her kartta 403 görüyordu. Aynı düzeltme
  sakin, güvenlik ve tesis görevlisi için de geçerli.
- Backend yetkileri (`_KAYIT_IZLEYICI`, `gorunur_roller`) aynen kaldı;
  mobil bunları kullanıyor.
- Yönetici amiri web'de yönetmeye devam ediyor: ekleme, düzenleme, amir
  yapma ve güvenliğe düşürme ölçüldü, 200 dönüyor.

**Karar 3 — mobilde de yönetici amiri yönetir (web+mobil parite).**
Personel ekranında yalnızca admin ve yöneticiye "Güvenlik Amiri" seçeneği
çıkıyor ve listede amirler görünüyor. Bu yetki sunucudaki
`YONETILEBILIR_ROLLER`'ın aynası. Amirin kendisi bu seçeneği ve başka
amirleri görmüyor.


## §2 Telefon alanı — tek bileşen, her yüzey

**Kural.** Telefon girilen her alan ortak bileşeni kullanır:

- web: `components/TelefonAlani.tsx`,
- mobil: `core/ui/telefon_alani_widget.dart`.

Ülke kodu listeden seçilir, numara ülkeye göre biçimlenir ve uzunluğu
sınırlıdır. Sunucuya her yerden aynı biçim gider: E.164 (`+4915123456789`),
yani kullanıcı ekleme ekranının gönderdiği biçim.

**Envanter.** Ortak bileşeni kullanmayan yerler şunlardı:

- web giriş formu: düz `<input>`, `0543…` olduğu gibi gidiyordu,
- Excel içe aktarım tablosunun `telefon` / `sakin_telefon` hücreleri,
- tanımlar sayfasındaki firma defteri: rakamlar bitişik, sınırsız, ülke
  seçilemiyordu,
- tanıtım iletişim formu,
- dukkan-web ve tanitim-web formları,
- mobil giriş ekranı,
- mobil Dükkân telefon ekranı: "tam 10 hane" kuralı 11 haneli Alman
  numarasını reddediyordu.

Kayıt ekranı zaten ortak bileşeni kullanıyordu ama "ülke seçilmedi",
"fazla hane" ve "boş" hatalarının hepsini "numara eksik" diye
gösteriyordu. Hata metni artık ortak bileşenden geliyor.

Ziyaretçi kaydında telefon alanı yok. Diyafon ayarındaki "hedef dahili"
bir dahili numara, telefon değil; istisna.

**Bileşen genişletildi, ikinci bileşen yazılmadı.** Eklenen kipler:

- **hücre kipi**: Excel tablosu için. Birden çok hücreye yapıştırma
  korunuyor.
- **sabit hat kipi**: firma, işletme ve iletişim numarası için. TR'de `5`
  ön eki aranmıyor.
- **kimlik kipi**: giriş ekranı için (aşağıda).

**Giriş ekranı kararı (web + mobil).** Tek alan kalıyor; kullanıcıya
"e-posta mı, telefon mu" diye sorulmuyor (P205).

- Alan rakam, `+` veya `(` ile başlayıp yalnız telefon karakterleri
  içeriyorsa telefon kipine geçer: ülke kutusu belirir, numara biçimlenir.
- Harf veya `@` görülünce e-posta kipine döner, yazılan metin kaybolmaz.
- Ülkesiz yazılan numara TR sayılır. Giriş hiçbir şey kaydetmediği için
  yanlış tahmin yalnızca 401 üretir.
- Aynı input yerinde kalır ve ilk rakamda odak kaybolmaz.
- Klavye e-posta klavyesi kalır; telefon klavyesinde harf yok.

Ölçüm sırasında bir hata yakalandı ve düzeltildi: `+49`'dan sonra yazılan
boşluk alanı e-posta kipine düşürüyordu. Numara `+90151…` olarak gidip 401
alıyordu. Web ve mobilde ayrı testi var.

**Dükkân backend.** `telefon_normalize` her girdiye TR kuralı uyguluyordu:

- `+4915123456789` 422 alıyordu,
- `+4712345678` sessizce `+904712345678` oluyordu.

Açık ülke kodlu girdi (`+`, `00` veya `(+` ile başlayan) artık
`normalize_phone` ile E.164'e çevriliyor. TR biçimleri aynen kalıyor.

**İstisna.** dukkan-web ve tanitim-web ayrı Docker bağlamında derlendiği
için panelden import edemiyor. Bu yüzden:

- mantık dosyaları panelin bayt bayt kopyası,
- iki sitenin `TelefonAlani.tsx` dosyası birbirinin aynısı.

Eşitliği `tests/telefon-kapsam.test.ts` denetliyor.

**Kilit.** Ortak bileşen dışında bir telefon girdisi kurulursa iki test
düşüyor:

- web: `tests/telefon-kapsam.test.ts` (`app/`, `components/` ve iki site),
- mobil: `test/telefon_alani_kapsam_test.dart`.

Taranan desenler: `type="tel"`, `inputMode="tel"`, `autoComplete="tel"`,
adı telefon olan input, telefon etiketli düz alan. Kilidin çalıştığı
kanıtlandı: geçici bir ihlal eklenince test düştü, geri alınca geçti.

**Gerçek akış.** Playwright ile sürüldü ve DB'de doğrulandı:

- TR girişi,
- `+49` ile giriş,
- profilde DE numarası,
- sakin eklemede GB numarası,
- Excel aktarımında DE numarası,
- firmada sabit hat.

## §3 Girdi güvenliği ve uzunluk sınırı

### (a) Uzunluk sınırı

**Sunucu.** Tüm girdi metin alanları sunucuda dar sınırlı: 730 metin
girdisinin hepsi. Buna gövde alanları, iç içe modeller, liste elemanları,
sorgu ve form parametreleri dahil.

- Değerlerin tek kaynağı `app/girdi_siniri.py`.
- Dukkan şemaları pydantic'in düz `BaseModel`'ini kullandığı için P247'nin
  200 000 karakterlik taban tavanı orada hiç yoktu. Tüm Dukkan alanlarına
  açık sınır kondu.

**Sınıf tablosu:**

| Sınıf | Sınır |
|---|---|
| Ad | 100 (mevcut 120/150/160 korundu; ad alanı tavanı 200) |
| Başlık | 200 |
| E-posta | 254 |
| Telefon (ham) | 32 |
| Yeni parola / giriş parolası ve sırlar | 128 / 500 |
| URL | 2048 |
| Adres | 500 |
| Not / uzun not | 2000 / 5000 |
| Uzun metin (karar defteri, site kuralı) | 20 000 |
| Yasal metin (KVKK) | 100 000 (gerekçeli istisna) |
| Kod / slug | 64 / 120 |
| Jeton | 4096 |
| Dosya anahtarı / dosya adı | 500 / 255 |
| Arama (`q`) | 100 |
| İçe aktarım hücresi | 1000 |
| Blok / daire no | 32 / 50 |
| MT940 banka ekstresi | 2 000 000 (gerekçeli istisna; 5 MB gövde sınırının altında) |

**Hata mesajı.** 422 yanıtı alanı ve sınırı kullanıcının dilinde söylüyor
(7 dil), örneğin "'ad' alanı en fazla 100 karakter olabilir."

**İstemci.** Web ve mobil aynı sabitleri taşıyor; kilit testleri ikisini de
doğrudan `girdi_siniri.py` ile karşılaştırıyor. İstemcideki `maxLength`
yalnız kullanıcıyı durdurur, asıl koruma sunucudadır. Telefon alanlarının
uzunluğu §2'nin ortak bileşeninden geliyor.

**Mevcut veriler.**

- Mevcut sayısal sınırlar düşürülmedi.
- Yeni sınırlar dev veritabanındaki en uzun kayıttan büyük seçildi. Tek
  aşım `dues_assessment.aciklama` alanında 1 kayıt: 10 000 karakterlik bir
  E2E test artığı.
- Sınırı aşan eski bir kaydı düzenleyen kullanıcı, kısaltmadan
  kaydedemez; 422 mesajı alanı ve sınırı söyler.
- Veriyi kırpan bir göç bilinçli olarak yazılmadı, çünkü veri kaybı
  demek.

### (b) SQL enjeksiyonu

"1=1" gibi kalıplar süzülmüyor. Savunma parametreli sorgudur.

**Ham SQL taraması.** Sorgu metnine değer birleştiren bir yer yok.
Taramanın bulduğu 40 dinamik parçanın hepsi tanımlayıcı ya da sabit parça
(tablo/kolon adı sözlükleri, parametreli koşul parçaları); her biri
gerekçesiyle beyaz listede.

**LIKE jokerleri kaçışlanmıyordu.** Bu bir SQL enjeksiyonu değil, "her
şeyi getir" hatası. `%` araması şunları döndürüyordu:

- `/tenants`: 4042 tesisin tamamı,
- Dukkan işletme araması: 5286 işletmenin tamamı,
- mahalle araması: 21 mahallenin tamamı.

Aynı eksik `/users` ve `mesai` uçlarında da vardı. Ortak yardımcılar
(`tr_arama.like_kacis`, `like_icerir`) tüm arama uçlarına bağlandı.
Şimdi `%`, `' OR 1=1 --` ve `\` araması 200 ve 0 sonuç döndürüyor; normal
aramalar çalışıyor.

### (c) XSS ve formül enjeksiyonu

**XSS: açık bulunmadı.**

- Web'de `dangerouslySetInnerHTML` yalnız iki yerde: sabit tema betiği ve
  sunucuda beyaz listeyle temizlenmiş KVKK gövdesi.
- Bağlantı adresleri ya sunucunun imzaladığı URL'ler ya da sabit
  öneklerle kuruluyor; kullanıcı girdisinden `javascript:` adresine giden
  yol yok.
- E-posta HTML'inde tüm değişkenler kaçışlanıyor.
- PDF'te markup yorumlanmıyor.
- Mobilde WebView yok.

Kilit: `xss-innerhtml.test.ts`.

**Formül enjeksiyonu: kapatıldı.** Açık iki yerdeydi: backend XLSX
çıktıları ve web'in 4 CSV üreticisi.

- **XLSX:** `=`, `+`, `-`, `@`, sekme veya CR ile başlayan metin hücresi
  düz metin yazılıyor ve `quotePrefix` ile işaretleniyor. Metne `'`
  eklenmedi, çünkü dışa aktarılan vardiya planı geri yükleniyor ve kesme
  işareti her turda birikirdi.
- **Web CSV:** OWASP usulü `'` öneki kullanılıyor; saf sayılar hariç.
- İkisi de tek kapıya bağlı ve kilitli: `wb.save` yalnız `guvenli_kaydet`
  içinden çağrılabilir, CSV yalnız `lib/csv.ts` içinde üretilebilir.

Canlı ölçüm: bir sakin adı `=HYPERLINK(...)` yapıldı, rapor indirildi.
Hücre metin olarak kaldı; düzeltmeden önce formül olarak yazılıyordu.

### Kilitler

Her kilit geçici bir ihlalle kırmızıya düşürüldü, sonra geri alındı.

- `uc-guvenlik.tsv`'ye yeni **`girdi`** sütunu eklendi. Yeni bir uç dar
  sınırı olmayan serbest metinle gelirse test düşer.
- `test_p248_girdi_siniri.py` (her uç, her metin girdisi dar sınırlı)
- `test_p248_sql_tarama.py` (AST taraması + LIKE kuralları)
- `test_p248_formul_enjeksiyonu.py`
- Web: `girdi-siniri`, `girdi-maxlength-tarama`, `csv-formul`,
  `xss-innerhtml`
- Mobil: `girdi_siniri_test`, `girdi_maxlength_tarama_test`

## §1-kamera Geçmiş kamera kaydı mobile geldi

**Kullanıcı kararı:** "(a) Mobile getir". Amir web'e giremediği için
(§1) bu yetkiyi kaybetmemesi gerekiyordu.

**Kim görür.** Mobildeki "Kamera Kayıtları" ekranı admin, yönetici ve
güvenlik amirine açık. Bu küme sunucudaki `_KAYIT_IZLEYICI` ile aynı.
Güvenlik görevlisi bilerek dışarıda: geçmiş kayıt geriye dönük
gözetimdir.

**Sunucu değişmedi.** Şunlar aynen geçerli:

- 24 saatlik pencere sınırı,
- rol kapısı,
- her arama ve her izleme için ayrı işlemde yazılan denetim satırı.

Mobil oynatmanın `camera_kayit_izleme` satırı bıraktığı canlı API'de
ölçüldü. Güvenlik, sakin, tesis görevlisi ve denetçi 403 alıyor; 24 saat
+1 sn ve ters aralık 422 dönüyor.

**Kimlik doğrulama.** HLS vekili normal API yetkisiyle korunuyor. Mobil
oynatıcı `Authorization: Bearer` başlığını `video_player` üzerinden
veriyor; canlı kamera da aynı yolu kullanıyor.

- Dev'de gerçek MediaMTX üzerinde ölçüldü: playlist → varyant → init →
  segment zincirinin her halkası başlıkla 200, başlıksız 401 dönüyor.
- iOS'ta başlık `AVURLAssetHTTPHeaderFieldsKey` ile alt listelere ve
  segmentlere taşınıyor.
- İmzalı URL ya da çerez eklenmedi.

**Sarma.** MediaMTX kaydı kayan pencereli canlı HLS olarak yayınlıyor,
bu yüzden oynatıcının kendi çubuğu aralığın tamamında gezemiyor. Mobilde
±1 dk düğmeleri ve konum çubuğu, seçilen andan yeni bir `oynat` oturumu
açıyor. Her yeni oturum ayrı bir denetim satırı.

**Jeton ömrü (15 dk).** Uzun izlemede jeton dolar. Oynatma hata verirse
ekran kaldığı andan bir kez kendiliğinden yeniden açar ve jeton `oynat`
çağrısında tazelenir.

**Web.** `kamera-kayitlari` sayfası yöneticide kalıyor.


## §4 Hareketsizlik süresi

**Ölçüm (önce).**

- Web'de zamana bağlı tek sınırlar vardı: 15 dakikalık erişim jetonu ve
  30 günlük kayan yenileme jetonu.
- BFF, 401 aldığında sessizce yeniliyor (`lib/backend.ts`, tek uçuş +
  30 sn sonuç penceresi). Middleware yalnızca yenileme çerezinin
  **varlığına** bakıyor.
- Tarayıcıda erişim çerezi silinerek (15 dk dolmuş gibi) sayfalar ve
  40 sn'lik arka plan yoklaması sürüldü. **401 gelmedi, oturum düşmedi.**
- Refresh aile kaydı Redis'te 30 gün yaşıyor. Prod'da Redis `appendonly`
  ve `noeviction`; admin-web tek süreç, dolayısıyla tek uçuş koruması
  prod'da da geçerli.
- Çıkış yalnızca kendi ailesini kapatıyor; "her yerden çık" ancak açıkça
  istenirse çalışıyor.

**Sonuç:** "Kısa süre hareketsiz kalınca girişe dönme" davranışı dev
ortamında **yeniden üretilemedi**. Web oturumu fiilen 30 gün açık
kalıyordu; hareketsizlik diye bir kural yoktu. Prod'da gözlenen düşüşün
sebebi burada ölçülemedi (bkz. Ölçülemeyenler). En olası adaylar:

- aynı adla hem konak-özel hem alan-adı çerezi taşıyan eski tarayıcı
  durumu (P191),
- prod'da eski bir yapım.

**Karar.**

1. **Web (`app.*`): 2 saat hareketsizlikte oturum düşer.**
   **Platform paneli (`panel.*`): 30 dakika.**
   - Panelden tüm tesisler yönetilir; başı boş bırakılmış bir platform
     oturumu en geniş yetkidir.
   - Süreler `WEB_HAREKETSIZLIK_DK=120` ve `PANEL_HAREKETSIZLIK_DK=30`
     ile ayarlanabilir.
2. **Mobil: P247'nin 30 günlük kayan kuralı aynen kalır.** Mobil jeton
   yüzey taşımaz.
3. **Kural sunucuda uygulanır.** İstemci zamanlayıcısı atlatılabilir ve
   kapalı sekmede çalışmaz.
   - Jeton verilirken BFF `X-Oturum-Yuzeyi: web|platform` başlığını
     gönderir. Sunucu bunu jetona **iddia** olarak yazar (`yz`).
   - Başlık yalnızca oturumu **kısaltır**: göndermeyen istemci bugünkü
     davranışı alır.
   - Çalınan bir web jetonundan iddia silinip 30 günlük kurala
     geçilemez; iddia jetonun imzası altında.
4. **Etkinlik = kimlikli istek.**
   - Her kimlikli istek, ailenin `oturum:etkin:<fam>` anahtarını
     sınırın süresi kadar yeniler.
   - Yenileme ucu bu anahtarı bulamazsa aileyi kapatır ve
     `oturum_hareketsizlik` döner (7 dil).
   - Erişim jetonunun ömrü (15 dk) iki sınırdan da kısa olduğu için
     erişimde ayrıca denetim gerekmez.
5. **İkinci katman: kayan çerez.** Yenileme çerezi her başarılı BFF
   yanıtında aynı değerle, sınırın süresi kadar yeniden yazılır.
   Hareketsizlikte tarayıcı çerezi siler ve middleware sayfa çizilmeden
   `/login`'e yollar. Önce boş bir kabuk gösterip ilk istekte atmak
   gerekmez.
6. **Korunan:** çıkış ve parola değişikliği oturumu anında kapatmaya
   devam eder (E2E/P247 iptal damgası ve jti kara listesi aynı yerde;
   testle ölçüldü).

**Gerçek akış (Playwright + canlı API).** Webden giriş yapıldı:

- Yenileme çerezinin kalan ömrü 120 dk, jetonda `yz=web`.
- Gezinmeden sonra çerez yine 120 dk, yani kayıyor. Sunucudaki etkinlik
  anahtarının TTL'i yaklaşık 7200 sn.
- Sayfa boşaltılıp (yolda istek kalmadan) anahtar düşürüldü ve erişim
  çerezi silindi. Sonraki gezinmede tüm BFF istekleri **401** aldı,
  sayfa **`/login`**'e düştü, **bütün çerezler silindi**.

Ölçümde bir tuzak çıktı: yavaş dev sunucusunda bir önceki sayfanın hâlâ
yolda olan istekleri anahtarı yeniden kurdu. Bu doğru davranış, çünkü o
istekler gerçekten etkinlikti. Hareketsizliği ölçmek için sayfayı önce
boşaltmak gerekiyor.

**Testler:**

- `backend/tests/test_p248_hareketsizlik.py`:
  - web 2 sa, platform 30 dk,
  - yenilemede yüzeyin korunması,
  - hareketsizlikte ret ve ailenin kapanması,
  - mobilin değişmemesi,
  - bilinmeyen başlığın yok sayılması,
  - çıkışın anında kapatması.
- `admin-web/tests/backend.test.ts`:
  - başlık, konağa göre `web` / `platform`,
  - kayan çerez,
  - ret halinde çerezlerin silinmesi.

---

## Ölçülemeyenler

- **§1:** Aşağıdakiler ölçülemedi:
  - Gerçek Google/Apple SSO. Bağlama jetonu testte üretildi.
  - SMS kayıt yolu. Dev'de `SMS_AKTIF=false` olduğu için yalnızca kod
    düzeyinde düzeltildi.
  - Cihazda mobil kayıt. Yalnızca widget testleriyle ölçüldü.
- **§2:** Aşağıdakiler ölçülemedi:
  - dukkan-web ve tanitim-web dev'de çalışmadığı için tarayıcıda
    sürülemedi; yalnızca tsc ve kendi testleri koşuldu.
  - Web kayıt akışı sunucuda tamamlanamadı; dev'de `YENI_KAYIT_AKISI`
    kapalı olduğu için 503 dönüyor. İstek gövdesinin doğru gittiği
    ölçüldü.
  - Açık madde: telefon kutusu TR yer tutucusunu (`5XX…`) her ülkede
    gösteriyor.
- **§3:** Aşağıdakiler ölçülemedi veya açık kaldı:
  - **Prod'da sınırı aşan eski kayıtlar.** Bunları bulan salt okuma
    SQL'i hazır, prod'da koşulmalı.
  - **Mobilde sınırı aşan eski değer.** Flutter'ın sınır biçimlendiricisi
    böyle bir değeri ilk düzenlemede sessizce kısaltır.
  - **Başlıklar ve yol parametreleri** kapsam dışı; uzunlukları sunucunun
    başlık ve URL sınırlarına bırakıldı.
- **§1-kamera:** Gerçek HLS oynatımı iOS ve Android cihazda denenmedi;
  emülatör yok. Açık kalan noktalar:
  - AVPlayer'ın başlığı segmentlere gerçekten taşıması,
  - jeton dolunca oynatıcının hata üretmesi,
  - kayıt anının oynatıcı konumuyla eşleşmesi.

  Gerçek Hikvision veya Dahua NVR ile de denenmedi; ölçüm sentetik
  `testcam` ve `sablon` sağlayıcısıyla yapıldı.
- **§4:** prod'da gözlenen kısa süreli düşüşün kök nedeni. Bu makineden
  prod'a erişim yok; dev ortamında yeniden üretilemedi.
