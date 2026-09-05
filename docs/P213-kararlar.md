# P213 — gürültü eşiği ayarı, kamera görüntüleme ve kayıt

## §1 — Gürültü eşikleri yönetici ayarında

### ÖLÇÜM — biri eksikti, üçü SESSİZCE bozuktu
| Ayar | Şema | `_to_settings` (GET) | Yönetici yazabilir mi |
|---|---|---|---|
| `gurultu_esigi` | ✅ | ✅ | ✅ |
| `gurultu_pencere_gun` | ✅ (P208) | ❌ **yok** | ❌ **403** |
| `gurultu_susma_gun` | ✅ (P208) | ❌ **yok** | ❌ **403** |
| `gurultu_sakin_uyarisi` | ✅ (P208) | ❌ **yok** | ❌ **403** |
| eskalasyon eşiği | ❌ **yok** (kod sabiti `asama >= 2`) | — | — |

İkinci sütun sessiz bir kusurdu: `TenantSettings` şeması alanları
tanımlıyor ama `_to_settings` doldurmuyordu → **GET her tesiste şema
varsayılanını dönüyordu** (30/7/true), yani ekran gerçek değeri hiç
göstermemişti. P165'te birebir aynı sınıf ölçülmüş ve o zaman
`rezervasyon_gecmis_ay` için not düşülmüştü — aynı tuzağa üç alan daha
düşmüş.

Web tarafında alanlar **zaten çizilmişti** (`lib/tesis-ayar-alanlari.ts`);
yani arayüz vardı, sunucu tarafı eksikti. Kullanıcının gördüğü şey
"değiştiriyorum ama değişmiyor"du.

### KARAR K1.1 — Dört ayar da yöneticide, dördü de yanıtta
`_YONETICI_YAZABILIR` kümesine ve `_to_settings`e eklendi. Gerekçe P37/P34
ile aynı: eşiği ve pencereyi **komşuluk ilişkisini bilen kişi** ayarlar;
platform operatörüne bırakmak her değişikliği destek talebine çevirirdi.

### KARAR K1.2 — Eskalasyon eşiği ayar oldu (göç 0105)
`gurultu_eskalasyon_esigi` (1..10, varsayılan **1**): N. eşik aşımından
**sonraki** her aşımda güvenliğe gider. Varsayılan 1 ⇒ ikinci 5'te —
P212'nin bugünkü davranışı **aynen** korunur.

**Neden 0 yok:** "her uyarıda güvenliği çağır" demek olurdu ve birinci
eşiğin anlamını silerdi. **Neden üst sınır 10:** daha büyüğü pratikte
"hiç çağırma"dır ve bunu ifade etmenin doğru yolu ayrı bir açma/kapama
anahtarıdır, kocaman bir sayı değil.

### KARAR K1.3 — Eşik 1: **uç reddetmez, arayüz uyarır**
İstek "1 yaparsa kullanılamaz hale gelir; uyar" diyordu. Eşiği 1'de
yasaklamadım: küçük bir sitede bu **bilinçli** bir tercih olabilir ve 422
dönmek meşru bir kullanımı imkânsız kılardı. Bunun yerine alan 1 olunca
ipucu satırı **uyarıya** dönüşüyor: *"Eşik 1: her gürültü şikâyetinde
daireye uyarı gider… 3 ve üzeri önerilir."* (7 dil)

### KARAR K1.4 — Değişiklikler denetime
Bu ayarlar paraya değil **bildirime** dönüşüyor: eşiği 1 yapan her
şikâyette daireye anons gönderir, eskalasyon eşiğini düşüren güvenliği
daha sık çağırır. "Kim ne zaman değiştirdi" bir anlaşmazlıkta sorulacak
ilk sorulardan. Denetim kaydı **eski + yeni** değerleri taşır ve yalnız
**gerçekten değişen** alanlar için yazılır.

Sınırlar üç yerde **aynı**: Pydantic `Field`, DDL `CHECK`, web alan
tablosu. Tesis bazında — testle kilitli (A'nın eşiği B'yi etkilemiyor).

### Kilit
Backend 7 test (dördü de yanıtta; yönetici değiştirebiliyor ve yanıt
**gerçek** değeri dönüyor; 7 geçersiz değer 422; eşik 1 kabul; denetim
kaydı; tesis izolasyonu; denetçi 403) + eskalasyon eşiğinin **gerçekten
kullanıldığı** (eşik 2 → üçüncü aşımda eskalasyon) P212 dosyasına eklendi.
Web 2 DOM testi (alan çizilir ve gönderilir; eşik 1'de uyarı görünür).
Göç geri alınabilir — downgrade→upgrade koşuldu.

---

## §2 — RTSP canlı yayın açılmıyordu: kök neden **MediaMTX API yetkisi**

### ÖLÇÜM — zinciri sırayla sürdüm
```
1) GET  http://mediamtx:9997/v3/paths/list      -> 401     ← KIRILMA NOKTASI
2) POST /v3/config/paths/add/cam<id>            -> 401
3) backend bunu "yol zaten var" sanıp PATCH     -> 401 (sonucu OKUNMUYOR)
4) GET  /cam<id>/index.m3u8                     -> 404 (yol hiç oluşmadı)
5) kullanıcı: "Canlı yayın henüz hazır değil"
```

MediaMTX 1.9'un **gömülü varsayılan** `authInternalUsers` ayarında iki iç
kullanıcı var:
* `any` → publish/read/playback (her IP)
* `any` → **api**/metrics/pprof ama **yalnız `ips: [127.0.0.1, ::1]`**

`api` servisi geçide docker ağının IP'siyle (172.x) bağlandığı için **her
API çağrısı 401** alıyordu.

**Kare neden çalışıyordu:** ızgaradaki kareyi ffmpeg **kameradan
doğrudan** çekiyor; MediaMTX'e hiç uğramıyor. Kullanıcının gözlemi
("kare var, canlı yok") bu ayrımın birebir yansıması.

### KARAR K2.1 — `infra/mediamtx.yml` (dosya, ortam değişkeni değil)
`api` izni özel ağ aralıklarına (`10/8`, `172.16/12`, `192.168/16`) +
yerel döngüye açıldı. **API portu dışarı açılmıyor** (compose'da `ports`
yok): özel ağ aralığını yetkilendirmek, API'yi internete açmak değildir.

Önce `MTX_AUTHINTERNALUSERS_1_IPS=…` ortam değişkeni denendi ve **etki
etmedi** (401 sürdü) — liste öğelerini env ile ezmek bu sürümde güvenilir
değil. Dosya hem çalışıyor hem kararı **okunur** kılıyor.

### KARAR K2.2 — Yetki hatası artık **yutulmuyor**
Eski kod POST'un 4xx'ini idempotent kabul edip PATCH deniyor, **onun
sonucunu hiç okumuyordu**. Artık:
* **401/403** → `kamera_gecit_yetkisiz` ("sunucudaki mediamtx
  yapılandırması düzeltilmeli") — çünkü düzeltilecek yer kamera değil;
* `"already exists"` içeren 4xx → **normal**, idempotent kayıt;
* başka 4xx/5xx → `kamera_gecit_yapilandirma` + gövde loglanır.

Böylece dört durum dört ayrı cümle: geçide **ulaşılamıyor** /
geçit **reddetti** / geçit **yolu kaydedemedi** / **yayın hazır değil**.
Dördünü tek mesaja indirmek, yöneticiyi yanlış yere gönderiyordu.

### ÖLÇÜM — zincirin tamamı sentetik bir yayınla sürüldü
Gerçek kamera yok; bu yüzden ikinci bir MediaMTX konteynerini "kamera"
yapıp ffmpeg ile test deseni yayınladım:

```
paths/add            -> 200
index.m3u8 (geçit)   -> 200  (varyant playlist)
main_stream.m3u8     -> 200
BACKEND VEKİLİ:
  /cameras/{id}/canli/index.m3u8       -> 200
  /cameras/{id}/canli/main_stream.m3u8 -> 200
  /cameras/{id}/canli/<seg>.ts         -> 200, 59 784 bayt gerçek video
```

Segment adı `e251157e82b2_main_seg0.ts` — vekildeki dosya deseni
(`^[A-Za-z0-9._-]+\.(m3u8|ts|mp4)$`) bunu kabul ediyor; iki kademeli
playlist (index → main_stream → segment) vekilden ayrı istekler olarak
geçiyor.

**Dev'de canlı izleme artık açık:** `infra/.env`e `MEDIAMTX_URL` ve
`MEDIAMTX_API_URL` eklendi — kök neden ancak zincir çalışırken ölçülebilir.

### Kilit
10 test: dört geçit hatasının **ayrı ayrı** metinleri (7 dil, dördü de
birbirinden farklı ve yetki hatası "sunucu" diyor), 401/403 → ayrı kimlik,
"already exists" → hata değil, başka 4xx → hata, 5 gezinti denemesi 404.
Kırma denemesi: 401 dalı devre dışı bırakıldığında tam olarak o iki test
düştü.

### Ölçemediğim
**Gerçek kamerayla prod**. Prod'da `mediamtx.yml` mount edilene kadar API
401 dönmeye devam eder — dağıtımda `infra/mediamtx.yml` sunucuya
gitmeli ve `docker compose up -d mediamtx` ile yeniden oluşturulmalı.

---

## §3 — HLS kameralarda da anlık kare

### ÖLÇÜM
Uç, `tur != "rtsp"` olan her kamerada **422 "yalnız RTSP"** dönüyordu.
Yani kullanıcının gördüğü davranış kamera **türüne** göre değişiyordu:
RTSP kamerada ızgarada kare var, HLS kamerada yok.

### KARAR K3.1 — Tür kullanıcıya görünmez; kare her ikisinde de
`rtsp://` **ve** `http(s)` (HLS) sunucu tarafında çekilir. ffmpeg
argümanları taşıyıcıya göre seçilir:
* RTSP → `-rtsp_transport tcp`
* HLS → `-protocol_whitelist http,https,tcp,tls,crypto`
  — playlist segmentlere gittiği için alt istek izni **şart**; liste
  **dar** ve `file` **yok**: yerel dosya izni, kare ucunu bir dosya
  okuyucusuna çevirirdi.

### KARAR K3.2 — SSRF sınırı nereye kondu
Klasik "özel IP aralıklarını engelle" listesi **burada uygulanamaz**:
kameralar çoğunlukla yerel ağda ve `192.168.x.x` tam da geçerli bir
kamera adresi. Bunun yerine üç katman:
1. `stream_url`i **yalnız yönetim** yazar — bu kullanıcı girdisi değil
   **yapılandırma**dır (RTSP'de de böyleydi);
2. çıktı ffmpeg'in ürettiği bir **JPEG**: hedef medya değilse kare
   çıkmaz, yani rastgele bir ucun gövdesi istemciye dönmez;
3. **bulut meta-veri uçları açıkça engellenir** (`169.254.169.254`,
   `metadata.google.internal`, `100.100.100.200`) — orada kamera olmaz,
   sızarsa bedeli ağır.

### ÖLÇÜM — gerçekten çalıştığı görüldü
Kendi geçidimizin yayınladığı test akışını HLS kamera olarak kaydettim:
```
HLS  kare -> 200, 14 913 bayt, image/jpeg
RTSP kare -> 200, 15 478 bayt        (gerileme yok)
IMDS kare -> 422 "bu adresten çekilemez"
```

### Kilit
8 yeni test + `test_cameras.py`'de **bilinçli olarak değiştirilen** P190
kilidi (`kare_yalniz_rtsp_422` → `kare_HLS_ICIN_DE_denenir`), gerekçesi
testin içinde. Kırma denemesi: yasak-konak kontrolü devre dışı
bırakıldığında tam olarak üç meta-veri testi düştü.

### Yan bulgu — testler ortama göre dallanıyor artık
Dev'de canlı geçidi açınca `test_cameras.py`'deki beş iddia düştü:
`oynatilabilir` bayrağı P190'dan beri `canli_yol`a da bakıyor, yani aynı
kamera **geçit varsa** oynatılabilir, **yoksa** değil. **İkisi de gerçek
bir dağıtım hâli**; testler `CANLI_ACIK` ile dallanıyor ve geçitsiz
kurulumu ölçen test `skipif` ile işaretlendi. Tek hâli sabitlemek,
ötekini kusur gibi gösterirdi.

### §3-ek — SSRF denetimi: **ad değil, çözülen IP**
Otomatik güvenlik incelemesi ilk yazımı haklı olarak işaretledi: konak
**adını** bir listeyle karşılaştırmak atlatılabilir bir denetimdir.
Ölçülen atlatma yolları:

| Girdi | Neden liste ıskalardı |
|---|---|
| `http://169.254.169.254./…` | sondaki nokta |
| `http://[::ffff:169.254.169.254]/…` | IPv4-eşlemeli IPv6 |
| `http://2852039166/…` | ondalık IP kodlaması |
| `http://0177.0.0.1/…` | sekizlik IP |
| `kamera.ornek.com` → IMDS | **DNS** ile yönlendirme |

Denetim artık konağı **çözüyor** ve dönen **her adresi** ölçüyor;
engellenen küme: `169.254.0.0/16` (tüm bulut meta-veri servisleri),
`127.0.0.0/8`, `::1/128`, `fe80::/10`, `fd00:ec2::254/128`. Ad tabanlı
liste **belt-and-braces** olarak duruyor (DNS çözülemese de geçmemeli).

**Neden özel aralıkların tamamı değil:** kameralar yerel ağda yaşar;
`192.168.x.x`'i engellemek ürünü çalışmaz kılardı. Bunu ölçen bir test
de var (`test_YEREL_AG_kamerasi_ENGELLENMEZ`).

**Kalan risk — bilinçli:** çözümleme ile ffmpeg'in kendi çözümlemesi
arasında DNS değişirse (rebinding) engel aşılabilir. Kapatmanın yolu
çözülen IP'yi ffmpeg'e vermektir, ama o zaman HTTPS kameralarda
SNI/sertifika doğrulaması kırılırdı. Risk sınırlı: `stream_url`i yalnız
yönetim yazar ve çıktı bir JPEG'dir.

Kırma denemesi: IP kontrolü devre dışı bırakıldığında **5 test** düştü.

---

## §4 — Kareler ana ekranda (backend)

### KARAR K4.1 — **Ayrı bayrak** (`ana_ekranda`), `sakin_gorebilir` değil
İki farklı soru: `sakin_gorebilir` bir **yetki** sorusudur ("sakin bu
kamerayı görebilir mi"), `ana_ekranda` bir **yerleşim** sorusudur ("bu
kamera özetin bandında dursun mu"). Tek bayrakla yönetmek, otopark
kamerasını sakinlere açan yöneticinin özetini de kendiliğinden
doldururdu. Göç **0106**, geri alınabilir (downgrade→upgrade koşuldu).

### KARAR K4.2 — Seçilmemişse **hiçbiri gösterilmez**
Varsayılan `false`. "İlk N kamerayı otomatik göster" gibi bir kural
**uydurma** olurdu: hangi kameranın öne çıkacağı yöneticinin bilgisidir,
alfabetik sıranın değil. Varsayılan `true` ise 20 kameralı bir sitede
özet açılır açılmaz **20 ffmpeg süreci** başlatırdı.

Seçim yoksa ana ekranda kamera bandı **hiç çizilmez** — boş bir kutu
değil, yok.

### KARAR K4.3 — Sınır **4** (ayar, şema kısıtı değil)
Her kare ayrı bir ffmpeg sürecidir (10 sn kare önbelleğiyle). Sınır
`KAMERA_ANA_EKRAN_SINIR` ile ayarlanır; şema kısıtı yapmak, sınırı
değiştirmeyi göç işine çevirirdi. Aşımda **422** ve mesaj **sınırı
söyler** ("en çok 4 kamera… önce birini kaldırın") — yönetici neden
ekleyemediğini bilir. Zaten açık bir kamerayı güncellemek sınıra
takılmaz; kaldırınca yer açılır.

### KARAR K4.4 — Süzgeç rol kapısının **üstüne biner**
`GET /cameras?ana_ekranda=true` rol görünürlüğünü **değiştirmez**:
sakinin ana ekranında yalnız kendisine açık kameralar çıkar. Testle
kilitli.

### Kilit
9 test (varsayılan kapalı, seçim yoksa boş, seçilen listede,
`sakin_gorebilir` ile karışmıyor, sınır 422 + mesaj, PATCH yolunda da
sınır, açık kamerayı güncellemek takılmıyor, kaldırınca yer açılıyor,
sakin görünürlüğü).

### Yan bulgu — kendi hatam, testler yakaladı
`ana_ekranda`yı eklerken `sakin_gorebilir`in `= False` varsayılanı kazara
düştü ve alan **zorunlu** oldu: kamera oluşturan her çağrı 422 almaya
başladı. `test_cameras.py`'de **23 test** düştü ve kusuru anında
gösterdi.

## §4 — Kareler ana ekranda, hangi kameralar gösterilecek (web + mobil)

**Karar:** seçim **kamera başına kalıcı bir bayrak** (`camera.ana_ekranda`, göç
0106), süzgeç **sunucuda** (`GET /cameras?ana_ekranda=true`), sınır
**yapılandırılabilir ve varsayılan 4** (`kamera_ana_ekran_sinir`).

**Neden bayrak, neden "ilk N" değil:** karar yöneticinin olmalı. Kamera listesi
alfabetik ya da ekleme sırasına göre gelir; "ilk 4"te otoparkın çöp konteyneri
kamerası ana ekranı işgal edebilir, giriş kapısı görünmeyebilir. Bayrak ayrıca
kameralar sayfasında tek onay kutusuyla yönetilebiliyor — ayrı bir "ana ekran
düzeni" ekranı açmaya değmezdi.

**Neden süzgeç sunucuda:** 20 kameralı bir sitede 20 kayıt indirip 4'ünü çizmek
gereksiz trafik; dahası her kart sunucudan bir **kare** çeker, istemci
süzgeciyle yanlışlıkla 20 kare isteği doğabilirdi.

**Neden sınır ve neden 4:** her kare bir ffmpeg çağrısı demek; sınırsız bırakmak
"ana ekranı aç → 15 ffmpeg" anlamına gelirdi. 4, iki sütunlu ızgarada iki tam
satır ve tipik telefon ekranında kaydırmasız görünen miktar. Sabit değil, ayar:
`kamera_ana_ekran_sinir`. Sınırı aşan işaretleme **422 `kamera_ana_ekran_sinir`**
ile reddedilir — sessizce kırpmak, yöneticinin işaretlediği kameranın neden
görünmediğini açıklanamaz kılardı.

**Ölçüm:** backend `test_p213_ana_ekran_kamera.py` (9), web
`p213-ana-ekran-kamera.dom.test.ts` (6) — özet sayfasının isteğinde
`ana_ekranda=true` bulunması, karede `rtsp://`/parola sızmaması, pasif kameranın
çizilmemesi dahil.

## §5 — Mobil kamera ızgarası: satır başına iki kart, tam genişlik

**Kök neden:** bant yatay kaydırmalı bir şeritti ve kart genişliği "ekrana dört
kart sığsın" (P25c) kuralından türüyordu; tipik telefonda kart ~85 dp'ye düşüyor,
sağda boş şerit kalıyor ve kare okunmuyordu.

**Karar:** `GridView` ya da yatay `ListView` değil, **iki sütunlu `Wrap`**.
Genişlik `(kullanılabilir - aralık) / 2` ile hesaplanır, yani satır **tam
doldurulur**; üçüncü/dördüncü kamera kendiliğinden alt satıra geçer. `Wrap`
seçildi çünkü kamera sayısı 1–4 arasında değişiyor ve `GridView` sarmalayıcı bir
kaydırma kısıtı gerektiriyor — ana ekran zaten kaydırılabilir bir gövde.

**Kapsam:** yalnız kamera ızgarası. Hızlı erişim ve istatistik ızgaraları kendi
`crossAxisCount: sutun` hesabını **koruyor**; bu, kaynak kilidiyle ölçülüyor
(`p213_kamera_bandi_test.dart`, "DIGER IZGARALAR DOKUNULMADI").

**Ölçüm:** 7 test. Kilidin tuttuğu, `kKameraSutun`'u 3 yapıp 6 testin düşmesi ve
2'ye dönünce hepsinin geçmesiyle kanıtlandı.

## §6 — Geçmiş kayıt izleme (NVR/DVR): uygulama kararları

Analiz ve seçenek karşılaştırması ayrı belgede:
`docs/P213-06-gecmis-kayit-analiz.md`. Siteden istenecek bilgi listesi:
`docs/P213-06-nvr-bilgi-listesi.md`. Aşağıdakiler onay sonrası verilen
**uygulama** kararlarıdır.

### 6a — Güvenlik amirini yönetici atar

**Kök durum (ölçüldü):** `guvenlik_amiri` rolü vardı ama
`YONETILEBILIR_ROLLER["yonetici"]` kümesinde **yoktu** — amiri yalnızca
platform operatörü atayabiliyordu. Dahası rol **hiçbir yüzeye
giremiyordu**: web'de "yakında" mesajı alıyor, mobilde ekran seti yoktu.
Yani backend'de yetkileri olan ama giriş yapamayan bir rol.

**Karar:** yönetici `guvenlik_amiri` atayabilir. **Yetki yükseltmesi
değil** — amirin açabildiği tek rol `security` ve yönetici zaten onu
açıyor; yani yönetici yalnızca kendi yetkisinin bir alt kümesini
devrediyor. Bu, testle de ölçülüyor
(`yonetilebilir("guvenlik_amiri") <= yonetilebilir("yonetici")`).

**Sınır korundu:** amirin kendisi amir açamaz. Aksi halde bir kez atanan
amir sınırsız amir üretebilir ve yönetici denetimden çıkardı.

**Yüzey:** amire web açıldı ama **dar** — `/kamera-kayitlari`,
`/dashboard`, `/profil`. Kamera **yönetimi** (`/kameralar`) yöneticide
kaldı: amir kamera ekleyemez, silemez, NVR kimliği giremez (backend
`_WRITER` da onu istemiyor), o sayfayı açmak hiçbirini yapamayacağı bir
form göstermek olurdu.

### 6b — `stream_url`'deki düz parola (ayrı güvenlik düzeltmesi)

**Kusur:** adres `rtsp://kullanici:parola@...` biçiminde **düz** duruyordu.
Üç sonucu vardı: DB dökümü parolayı açıyordu, `GET /cameras` adresi
olduğu gibi döndürüyordu (parola yetkili her istemciye gidiyordu),
günlüğe yazılan adres parolayı da yazıyordu.

**Karar:** kimlik adresten **ayrıldı** — `stream_kullanici` (düz) +
`stream_parola_sifreli` (AES-GCM, mevcut `app/crypto.py` deseni). Adres
kimliksiz saklanır ve kimliksiz döner; parola yalnızca sunucunun kendi
kullandığı anda geri takılır (ffmpeg, MediaMTX).

**Neden "yanıtta maskele" değil:** maskeleme veriyi hâlâ düz saklamanın
üstüne bir katman koymaktır; yedek/döküm/günlük yolları açık kalırdı.
Ayrıca maskeyi bir yerde unutmak **sessiz** bir sızıntıdır — ayırmak,
unutulunca **çalışmayan** (yani fark edilen) bir tasarımdır.

**Göç 0107 mevcut kayıtları taşır** ve `downgrade` parolayı çözüp adrese
geri takar. Çift yönlü olarak gerçek veriyle doğrulandı:
`rtsp://kul:GizliParola9@10.5.5.5:554/s` → adres temizlendi + şifreli
blob; downgrade → adres aynen geri geldi.

**Yan bulgu:** göç şifreleme yaptığı için `SDM_KEK` ister; `migrate`
servisine bu değişken geçirilmemişti ve göç zinciri düştü. İki compose
dosyasına eklendi. **Düşmesi doğrudur** — sessizce atlamak parolaları düz
bırakır ve kimse fark etmezdi.

**Çözülemeyen kimlik artık sessizce geçmiyor:** parolada kaçışsız `#`
varsa `urlsplit` konağı kaybediyor, ayırma atlanıyor ve adres parolayla
birlikte düz saklanıyordu — yani tam olarak kapatmaya çalıştığımız durum,
hem de fark edilmeden. Artık 422 ve kullanıcıya parolayı ayrı alana
yazması söyleniyor (o yolun gerçekten çalıştığı ayrıca ölçülüyor).

### 6c–6f — Adaptörler

Tek `KayitSaglayici` arayüzü, iki metot: `araliklari_listele` ve
`oynatma_adresi`. **Ayrı olmaları önemli:** arama API'si kapalı bir
kurulumda listeleme çalışmaz ama oynatma çalışır; tek metotta
birleştirmek ikinci yeteneği birincinin eksikliğine kurban ederdi.

- **`sablon`** — aramasız oynatma. Pilot sitenin markası bilinmediği ve
  çoğu kurulumda yalnız 554 yönlendirildiği için **birinci sınıf** bir
  yol, geçici çözüm değil. Şablon dili kasten küçük (sabit yer tutucu
  listesi): metni yazan kullanıcı, değerlendiren sunucu — genel amaçlı
  bir şablon motoru sunucu tarafı şablon enjeksiyonu yüzeyi açardı.
- **`hikvision`** — ISAPI XML araması; cihazın kendi `playbackURI`si
  tercih edilir, arama çökerse **oynatma vazgeçmez**, standart şablona
  düşer.
- **`dahua`** — üç adımlı durumlu CGI araması. Bulucu `finally` içinde
  **kapatılır**: kapatılmayan bulucular cihazda birikir ve bir süre sonra
  arama tamamen çalışmaz olur (bu satır ayrıca testle ölçülüyor).
- **`onvif` bilerek yok.** Profile G standart ama sahada güvenilmez; iki
  satıcı adaptörü gerçek cihazda doğrulandıktan **sonra** eklenecek.
  Önce eklemek, doğrulanmamış bir yolu varsayılan gibi göstermekti.

Tanınmayan sağlayıcı **fail-closed** reddedilir: varsayılan bir adaptöre
düşmek, yanlış markaya yanlış istekler göndermek ve teşhisi çok zor bir
hata sınıfı üretmek olurdu.

### 6g — Uçlar, yetki, KVKK

- Erişim **yönetici + güvenlik amiri**; amir olmayan `security` **hariç**
  (geriye dönük gözetim kapıdaki görevlinin işi değil). Kapı **sunucuda**,
  iki uçta da ayrı ayrı ölçülüyor.
- **Her arama ve her izleme denetim kaydına yazılır** (kim, hangi kamera,
  hangi zaman aralığı). Sonradan eklenmesi imkânsıza yakın: geçmişe dönük
  üretilemez.
- Pencere **en çok 24 saat**: bu cihazların arama API'leri yavaş ve tek iş
  parçacıklı; "son bir yıl" isteği cihazı kilitlerdi.
- **IDOR:** kayıt yolu adı `kayit<kamera-hex><imza>` ve ilk parçası
  istekteki kamerayla eşleşmek zorunda — yoksa rol kapısı geçildikten
  sonra bile A kamerasının ucundan B'nin kaydı çekilebilirdi.
- Oynatma zinciri **canlıyla aynı**; `_mediamtx_yol_kaydet` ortaklaştırıldı
  ki §2'nin kök nedeni (yutulan 401) iki yerde birden yaşamasın.

### 6h — Web

Ayrı sayfa `/kamera-kayitlari`. "Arama desteklenmiyor" ile "kayıt yok"
arayüzde de **ayrı** mesajlar — ikisini aynı göstermek, kaydı olan bir
günü boş gibi gösterip kullanıcıyı vazgeçirirdi.

Kameralar formunda NVR ayarları yalnız onay kutusu işaretlenince çizilir.
**Boş parola gönderilmez:** `null` göndermek "parolayı sil" demekti ve her
düzenlemede NVR erişimini sessizce koparırdı.

### Bu turda bulunan gerçek hata (§4'ün eksiği)

`/api/cameras` BFF rotası yalnız `limit`/`offset` iletiyordu; §4'te
eklenen `ana_ekranda=true` süzgeci **backend'e hiç ulaşmıyordu** ve Özet
tüm kameraları çekiyordu. Sayfa "çalışıyor" görünüyordu çünkü dönen
listenin ilk kameraları zaten doğruydu. DOM testi istemci→BFF adımını
ölçmüştü, BFF→backend adımını değil — **P200 dersi birebir tekrar etti**.
Yeni kilit rota işlevini doğrudan çağırıyor ve kırılarak doğrulandı.

### Ölçemediğim şey — açıkça

Elimde gerçek **Hikvision/Dahua NVR yok**. Adaptörler taklit HTTP
taşımasında (`httpx.MockTransport`) birebir istek/gövde/yanıt düzeyinde
ölçüldü: "protokolü doğru uyguluyoruz" diyebilirim, **"bu cihazda
çalışıyor" diyemem**. Bu yüzden her adım ayrıntılı hata günlüğü yazıyor
ve ağ hatası ile cihaz hatası ayrı mesajlar veriyor — ilk saha denemesi
teşhis edilebilir olsun diye (§2'de MediaMTX 401'ini bulan şey buydu).
