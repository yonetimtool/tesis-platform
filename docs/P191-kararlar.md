# P191 — kararlar

Kapsam: (1) kayıt yönlendirmesi + davetli SSO girişi, (2) bildirim teslimi,
(3) kamera teşhisi, (4) banka entegrasyonu v1.

---

## §1 — Kayıt yönlendirmesi bozuk (acil)

### K1.1 — Kök neden: iç port yönlendirmeye sızıyordu

**Belirti:** `panel.yonetiyor.com` → Google ile giriş → "Bu hesap henüz bir
tesise bağlı değil" → *Kaydol* → `app.yonetiyor.com:3000/kayit` →
`ERR_CONNECTION_TIMED_OUT`.

**Ölçüm (varsayım değil).** admin-web canlı olarak 3111 portunda çalıştırıldı
ve gerçek dağıtım taklit edildi:

```
curl -H 'Host: panel.yonetiyor.com' http://127.0.0.1:3111/kayit
→ location: http://app.yonetiyor.com:3111/kayit      # İÇ PORT SIZDI
```

İki tuzak üst üste binmişti:

1. **`req.nextUrl` ters vekilin ARKASINDAKİ adrestir.** Next onu dinlediği
   konak/porttan kurar, `Host` başlığından değil. Aynı konak içinde bu
   görünmez, çünkü Next aynı-origin yönlendirmeyi **göreli** yazar
   (`location: /login`) — bu yüzden `/login` akışı yıllardır sağlamdı ve kusur
   yalnız **konak değiştiğinde** ortaya çıktı.
2. **`URL.prototype.host` ataması portu SIFIRLAMAZ.** WHATWG kuralına göre
   `u.host = "app.yonetiyor.com"` (portsuz dize) mevcut portu olduğu gibi
   bırakır; `hostname` ataması da öyle. P190 §1'deki `url.host = app` satırı
   "konağı değiştirdim" diyordu ama portu temizlemiyordu.

`.env.prod` **doğruydu** (`OAUTH_KAYIT_DONUS=https://app.yonetiyor.com/kayit`,
portsuz). Port oradan gelmiyordu — middleware üretiyordu.

### K1.2 — Karar: konak-ötesi adresler ORTAM DEĞİŞKENİNDEN kurulur

Yeni tek kaynak: `admin-web/lib/konak-adres.ts`.

* Kanonik `app.*` kök adresi `NEXT_PUBLIC_APP_ADRESI`'den gelir (compose build
  arg `ADMIN_WEB_APP_ADRESI`, varsayılan `https://app.yonetiyor.com`).
  **Derleme argümanıdır**: middleware edge çalışma zamanında koşar,
  `process.env` orada derleme anında gömülür.
* Değişken verilmezse adres **iletilmiş başlıklardan** türetilir
  (`x-forwarded-host` > `host`, şema `x-forwarded-proto`, yoksa `https`) —
  `req.nextUrl`den **asla**.
* Her iki yolda da **port atılır**.
* Aynı-konak yönlendirmeleri de artık başlıklardan kurulur
  (`ayniKonakAdresi`): Next'in iç normalizasyonuna dayanan bir şansı
  bağımlılık olmaktan çıkardık. Portu burada **korur** — yerel geliştirmede
  `localhost:3000` istemcinin gerçekten kullandığı adrestir.

**Kilit test:** `tests/konak-adres.test.ts` + `tests/middleware.test.ts`
içindeki "konak-ötesi yönlendirme: PORT SIZMAZ" bloğu; sonuncusu üretilen
**her** yönlendirmeyi tarar ve port içeren adreste düşer.

Düzeltmeden sonra, aynı canlı sunucuda:

```
/kayit      → location: https://app.yonetiyor.com/kayit
/dashboard  → location: https://panel.yonetiyor.com/login
```

### K1.3 — İkinci kusur: oturum çerezi konak-özeldi

P190 §1 tesis rollerini `panel.*`tan `app.*`a taşımaya başladı; çerezlerde
`Domain` yoktu, yani **konak-özeldi**. Zincir: `panel.*`ta giriş → çerez
`panel.` konağına yazılır → middleware `app.*`a taşır → orada çerez YOK →
`/login`. Yani "yanlış konağa düşeni doğru konağa taşı" düzeltmesi oturumu her
seferinde düşürüyordu. SSO dönüşünde de aynısı: `OAUTH_WEB_DONUS` tek konaktır.

**Karar:** `COOKIE_DOMAIN` (çalışma zamanı; imaj derlemesi gerektirmez).
Prod'da `.yonetiyor.com` → iki yüzey tek oturum. **Boş bırakılırsa davranış
bugünküyle aynıdır** (konak-özel). Çıkışta iki varyant da silinir (alan-adlı +
konak-özel), aksi halde "çıkış yaptım ama hâlâ içerideyim" olurdu.

*Değiştirilebilir:* çerezi paylaşmak istemeyen bir kurulum `COOKIE_DOMAIN`u
boş bırakıp SSO dönüşünü yüzey başına ayrı yapılandırmalıdır.

### K1.4 — Davet edilmiş kişi SSO ile giremiyordu

**İz:** Giriş akışı (`niyet=giris`) yalnız `_kimligi_coz`e bakar: kimlik
`oauth_kimlik`te bağlı değilse `baglama_gerekli` döner ve web arayüzü bunu
doğrudan "Kaydol"a çeviriyordu (P185). Oysa kişinin **hesabı var** — yönetici
panelden eklemiş, tesis kodlu davet e-postası gitmiş.

P184'te tam bu iş için yazılmış uç zaten vardı: `POST /auth/oauth/rol-tamamla`
(Tesis ID + e-posta sahipliği, SMS yok). Kullanılmıyordu ve iki yerde
tıkanıyordu:

* **`rol` zorunluydu.** Davet edilen kişi kendi rol kodunu bilmek zorunda
  değil; yanlış seçim `onay_bekliyor` çıkmazıydı.
* **`password_set=true` reddediliyordu** (`hesap_kullanimda`). Ama bu bir
  *kayıt* değil, **mevcut hesaba SSO yöntemi eklemek**tir.

**Karar:** `rol` **opsiyonel** oldu (`_tamamla_uygunluk`):

| `rol` beyanı | Mod | Kural |
|---|---|---|
| var | kayıt akışı (mobil, değişmedi) | `_liste_kontrolu` aynen: rol uyuşmalı, `password_set=false` olmalı |
| yok | **girişte tamamlama** (web SSO) | rol hesaptan okunur; `password_set=true` engel değil |

Gerekçe: sağlayıcı e-postayı doğruladıysa kanıt, üründe **zaten tek başına
oturum açan** e-posta kodu (`/auth/giris/eposta-kod-iste`) ile aynı sınıftadır.
P180'de yönetici için verilen `mevcut_hesap` kararının diğer tesis rollerine
genişletilmesidir. Platform `admin` rolü dışarıdadır. Sızdırmama (K4) aynen
durur: geçersiz Tesis ID ile liste dışı e-posta **aynı** `onay_bekliyor`
yanıtını alır.

**Web akışı (yeni):** `/giris/oauth` → "bağlı değil" → *Tesis ID* formu →
`giris` (oturum) | `otp_gerekli` (e-posta kodu) | `onay_bekliyor`. "Tesisim
yok, yeni kayıt oluştur" bağlantısı duruyor.

### K1.5 — Yönlendirme kalıbının taranması

| Yer | Adres nereden | Durum |
|---|---|---|
| middleware `panel.*→app.*` (`/kayit`, rol kapısı) | `NEXT_PUBLIC_APP_ADRESI` → yoksa `x-forwarded-*` | **düzeltildi** |
| middleware aynı-konak (`/login`, kök, yüzey/rol kapısı) | `x-forwarded-*` → yoksa `nextUrl` | **düzeltildi** (portu korur) |
| OAuth dönüşleri (`OAUTH_WEB_DONUS`/`KAYIT_DONUS`/`MOBIL_DONUS`) | backend ayarları, **istekten alınmaz** (açık yönlendirme koruması) | zaten doğruydu |
| Sağlayıcıya bildirilen `redirect_uri` | `OAUTH_CALLBACK_TABAN` | zaten doğruydu |
| Davet / parola sıfırlama / e-posta bağlantıları | `PORTAL_BASE_URL` (ayar) | zaten doğruydu |
| Caddy 301'leri (eski yollar, IDN, kanonik dışı) | Caddyfile'da sabit `https://…` | zaten doğruydu |

Kural: **kullanıcıya gösterilecek hiçbir adres istek URL'sinden kurulmaz.**

### Dağıtım (§1)

`ADMIN_WEB_APP_ADRESI` bir **build arg**'tır → `docker compose build admin-web`
gerekir. `COOKIE_DOMAIN` çalışma zamanıdır → `up -d` yeter.

---

## §2 — Bildirimler telefona gelmiyor (acil)

### Zincirin altı halkası — ne bulundu

| # | Halka | Durum | Bulgu |
|---|---|---|---|
| a | Uygulama açılışta FCM jetonu alıyor mu | **Sağlam** | `PushRegistrar.registerCurrentToken()` ilk oturumdan sonra izin ister, `getToken()` çağırır; hatalar yutulur ve loglanır. Firebase kurulamazsa push devre dışı kalır, uygulama çökmez. |
| b | Jeton backend'e kaydediliyor mu | **Sağlam** | `POST /devices` idempotent upsert (`uq_user_device_tenant_token`); rotasyonda eski jeton pasifleştirilip yenisi yazılır; logout'ta pasifleştirilir. |
| c | Olay push görevini tetikliyor mu | **KOPUK — düzeltildi** | `dispatch_external` çağıran 12 yol vardı; **görev atama ve aidat borçlandırma bunların arasında YOKTU.** Kullanıcının şikâyeti tam buydu: "görev oluşturdum, bildirim gelmedi". |
| d | Worker FCM'e istek atıyor, yanıt ne | **Görünmezdi — düzeltildi** | `FcmProvider` istek atıyordu ama sonuç yalnız konteyner logundaydı. Artık **token bazında** sonuç dönüyor (`PushResult.token_sonuc`) ve `push_gonderim` tablosuna yazılıyor. |
| e | `bildirim_mobil` varsayılanı | **Sağlam** | Sunucu varsayılanı `true` (göç 0055). Kapalı olan kullanıcı sayısı artık teşhis ekranında görünüyor. |
| f | FCM servis hesabı prod'da doğru mu | **BÜYÜK OLASILIKLA BURASI** | `PUSH_PROVIDER` varsayılanı **`noop`**'tur (`infra/.env.prod.example`). `noop` bir hata gibi görünmez: her şey "başarılı" akar, hiçbir bildirim gitmez. Teşhis ekranı bunu artık **kırmızı uyarı** olarak söylüyor. |

> **Dağıtımda ilk bakılacak yer:** `.env.prod` içinde `PUSH_PROVIDER=fcm` ve
> `infra/secrets/fcm-service-account.json` mevcut mu. Panelde
> **Bildirimler → Push teşhisi** kartı ikisini de tek bakışta gösterir.

### K2.1 — `push_gonderim` (göç 0077): her denemenin izi

Alıcı başına bir satır: `kimlik` (olay), `user_id`, `token_son6`, `platform`,
`saglayici`, `durum`, `hata_kodu`, `created_at`.

* **Satır başına bir cihaz.** Toplu duyuruda 200 satır olur; olay başına tek
  özet satır "Ahmet'e gitti mi?" sorusunu cevaplayamazdı — teşhisin bütün
  değeri o soruda.
* **Hedefi olmayan deneme de yazılır** (`durum='hedef_yok'`, sebep
  `cihaz_yok` / `tercih_kapali`). "Push hiç tetiklenmedi" ile "tetiklendi ama
  cihaz yok" tamamen farklı iki arızadır.
* **Tam jeton saklanmaz**, son 6 karakter. **Metin saklanmaz** (o zaten
  `notification` tablosunda ve KVKK saklama görevine bağlı).
* **Saklama 30 gün** (gecelik temizlik, `retention.py`). Denetim kaydı
  değildir, işletim telemetrisidir.

Durum kümesi: `gonderildi` · `gecersiz_token` (FCM kalıcı reddetti, jeton
budandı) · `basarisiz` (geçici/ağ/kota — jeton korunur) · `noop` (sağlayıcı
kapalı) · `yapilandirilmadi` (servis hesabı yok) · `hedef_yok`.

### K2.2 — Yönetici görünürlüğü

* `GET /push/teshis` — sağlayıcı, yapılandırma, kayıtlı cihaz, cihazı olan
  kişi, mobil bildirimi kapalı kişi, son 24 saatin sonuç dağılımı, son 50
  deneme (kime/ne zaman/sonuç).
* `POST /push/test` — **kendi** cihazlarına gerçek bir gönderim. "Test" adı
  altında tüm tesise bildirim atabilen bir düğme, ilk yanlış tıklamada
  gerçek bir olay gibi görünen gürültü üretirdi.
* Panel: **Bildirimler** sayfasının en üstünde `PushTeshis` kartı — yalnız
  `admin` / `yonetici`. Kullanıcı bu sayfaya zaten "bildirimlerim nerede?"
  diye geldiği için cevabın yeri burası.

### K2.3 — Olay → alıcı tablosu

| Olay | Kimlik | Kime gider | Nerede |
|---|---|---|---|
| **Görev atandı / atama değişti** | `gorev_atandi` | Atanan kişi (atama yoksa **kimseye**) | `routers/tasks.py` **(P191'de eklendi)** |
| **Aidat / borç yazıldı** | `aidat_borc` | Hedef kişi; hedef yoksa dairenin aktif sakinleri. Kişi başına **tek** bildirim (tutarlar toplanır) | `routers/dues.py`, `routers/borclandirma_uc.py` **(P191'de eklendi)** |
| Duyuru yayınlandı | `duyuru` | admin, yonetici, security, tesis_gorevlisi, resident | `routers/announcements.py` |
| Etkinlik yayınlandı | `etkinlik` | resident | `routers/events.py` |
| Yeni talep açıldı | `yeni_talep` | admin, yonetici | `routers/complaints.py` |
| İş emri atandı | `is_emri_atandi` | Atanan kişi | `routers/complaints.py` |
| Talep iş emrine çevrildi / çözüldü / reddedildi | `talep_is_emri`, `talep_cozuldu`, `talep_reddedildi` | Talebi açan | `ticketing.py` |
| Kargo geldi | `kargo` | Dairenin sakinleri | `routers/kargo.py` |
| Ziyaretçi geldi | `ziyaretci` | Seçilen hedef sakin | `routers/visitors.py` |
| Rezervasyon onaylandı | `rezervasyon` | Rezervasyonu yapan | `routers/reservations.py` |
| Daire erişim talebi / sonucu | `erisim_talebi`, `erisim_onaylandi`, `erisim_reddedildi` | Sakinler / talebi açan yönetici | `routers/unit_access.py` |
| Gürültü uyarısı | `gurultu_uyarisi` | admin, yonetici | `gurultu_akisi.py` |
| Kaçırılan tur | `kacirilan_tur` | admin, security, guvenlik_amiri | `scheduler/notify.py` |
| Gecikmiş okutma (tekrarlı alarm) | `gecikmis_okutma` | Görevlinin kendisi + admin, yonetici, guvenlik_amiri | `scheduler/notify.py` |
| Uzak okutma | `uzak_okutma` | Görevli + admin, yonetici, guvenlik_amiri | `uzak_okutma.py` |
| Vardiya özeti (vardiya sonu, batching) | `vardiya_ozeti` | admin, yonetici | `scheduler/service.py` |
| Test | `test` | Yalnız çağıranın kendisi | `routers/push_teshis.py` **(P191)** |

Her satırda tercih kuralı aynıdır: `bildirim_mobil = false` diyen kullanıcıya
**push gitmez** (in-app bildirim yine yazılır — push EK gönderimdir).

### K2.4 — Teşhis logları

`scheduler/notify.py` artık her gönderimde tek satırda özet basar:
`kimlik`, tenant, sağlayıcı, cihaz sayısı ve durum dağılımı. Hedef
bulunamadığında ayrıca **neden** yazılır (tercih kapalı kaç kişi / hiç cihazı
olmayan kaç kişi). `NoopPushProvider` logu artık açıkça "PUSH_PROVIDER=noop:
hiçbir bildirim gönderilmez" der; `push_unconfigured` logu beklenen dosya
yolunu yazar. Değerler değil **alan adları** loglanır (P134 kuralı).

### Açık madde — mobil tıklama yönlendirmesi

`routeForPushData` (mobile/lib/src/routing/app_router.dart) bilinmeyen `tip`
için `null` döner: bildirim **düşer ve görünür**, ama tıklanınca uygulama
olduğu yerde kalır. Bu turda eklenen üç tip (`gorev_atandi`, `aidat_borc`,
`aidat_odendi`) o durumda — doğal hedefleri `/tasks` ve aidat ekranıdır.

**Neden bu turda yapılmadı:** mobil değişiklik ancak `flutter test`
TAMAMIYLA doğrulanabilir (yerleşim/menü/sözlük kilitleri yalnız tam koşumda
kırılır) ve bu makinede Flutter kurulu değil. Körlemesine düzenlemek,
doğrulanmamış bir mobil sürüm bırakmak olurdu. Tek satırlık iş: üç `case` +
mevcut rotalar.

### Değiştirilebilir varsayılanlar (§2)

* `push_gonderim` saklama süresi 30 gün.
* Hedefsiz daire borcunda dairenin **tüm** aktif sakinleri bilgilendirilir
  (alternatif: yalnız malik).
* Görev **atanmamışsa** (havuz görevi) bildirim gönderilmez.

---

## §3 — Kamera

### K3.1 — Hata mesajları artık arızayı adlandırıyor

**Ölçülen kusur:** her arıza aynı cümleydi ("Yayın açılamadı. Adresi ve ağ
erişimini kontrol edin.") ve ızgarada "Görüntü yok". Yöneticinin elinde
**eylem** yoktu.

Sebep basitti: `ffmpeg`'in `stderr`'i **`DEVNULL`'a yazılıyordu.** Arızanın
adını yalnız o söylüyor. Artık okunuyor ve sınıflandırılıyor
(`_ffmpeg_teshis`):

| ffmpeg çıktısı | Hata kimliği | Yöneticiye söylenen |
|---|---|---|
| `401 Unauthorized`, `Authentication failed` | `kamera_kimlik_hatali` | Kullanıcı adı/parola kabul edilmedi — **kayıttaki adresi** düzeltin |
| `Connection refused`, `No route to host` | `kamera_ulasilamiyor` | Kamera kapalı olabilir / sunucuyla aynı ağda mı |
| `Failed to resolve` | `kamera_adres_cozulemedi` | Ad çözülemedi — IP yazmayı deneyin |
| zaman aşımı | `kamera_zaman_asimi` | Ağ yavaş ya da akış kapalı |
| `404 Not Found`, `Stream not found` | `kamera_yol_bulunamadi` | RTSP **yolu** yanlış (örn. `/Streaming/Channels/101`) |
| `Invalid data found` | `kamera_yayin_okunamadi` | Akış biçimi desteklenmiyor |
| ffmpeg **yok** (FileNotFoundError) | `kamera_ffmpeg_yok` (**503**) | Sunucuda ffmpeg kurulu değil — **dağıtım** işi |
| MediaMTX'e ulaşılamıyor | `kamera_gecit_yok` | mediamtx servisi çalışmıyor olabilir |
| Geçit ayakta, yayın yok | `kamera_yayin_hazir_degil` | Birkaç saniye sonra tekrar deneyin |

* **503 vs 502 ayrımı bilinçli:** 502 "karşı taraf bozuk" der ve yöneticiyi
  ağ aramaya gönderir; ffmpeg eksikse düzeltilecek yer **sunucudur**.
* **Ham ffmpeg çıktısı istemciye GİTMEZ** — içinde `stream_url`, yani kamera
  parolası geçebilir. İstemci bir hata kimliği alır; operatör ayrıntıyı
  logda (kırpılmış) görür.
* **Negatif önbellek de teşhis taşır** (`YOK:<kimlik>`). Eskiden 5 saniyelik
  pencere içindeki her istek sebebi kaybediyordu.

### K3.2 — "Bağlantıyı test et" (kaydetmeden)

`POST /cameras/test-baglanti` — yalnız `admin`/`yonetici`, yalnız `rtsp://`
(SSRF sınırı, kayıt yolundaki kuralın aynısı), tesis başına dakikada 20
deneme (aşımda 429). **Hiçbir kayıt yazmaz.** Başarıda alınan karenin bayt
boyu döner ("gerçekten görüntü geldi" kanıtı), başarısızlıkta yukarıdaki
tanılı hata.

Kamera formunda: **örnek adres** (`rtsp://kullanici:parola@192.168.1.50:554/Streaming/Channels/101`,
yolun markaya göre değiştiği notuyla) + **Bağlantıyı test et** düğmesi
(yalnız `tur=rtsp` seçiliyken).

### K3.3 — Prod'da ne kontrol edilmeli (varsayma, doğrula)

`infra/docker-compose.prod.yml` **mediamtx servisini içeriyor** ve
`backend/Dockerfile` **ffmpeg kuruyor** — yani eksik olan kod değil,
büyük olasılıkla **dağıtımın uygulanmamış olması**. Doğrulama komutları
`docs/P191-dagitim.md` §3'te.

---

## §4 — Banka entegrasyonu v1

### Mimari sınır (kullanıcının koyduğu kural, aynen uygulandı)

| Kural | Ne yapıldı |
|---|---|
| Yeni site/apartman/sakin tablosu AÇMA | Açılmadı: `tenant`, `unit`, `app_user`, `unit_resident` kullanılıyor |
| Daireye özel referans `app_user.odeme_kodu` | Aynen; kod açıklamadan `odeme_kodu.ayikla` ile çıkarılıyor (P30) |
| Muhasebe kaydı `finansal_hareket`e | Evet — tahsilat satırı oraya yazılıyor, DELETE yok, iptal ters kayıt |
| Kuyruk Celery, depo MinIO, DB PostgreSQL | Yeni altyapı eklenmedi; makbuz PDF'i MinIO'da |
| Yalnız üç yeni tablo | `bank_transaction`, `payment_match`, `receipt` (göç 0079) |

**Borç kapanışı `dues_payment` üzerinden gider** ve bu bir tercih değil
zorunluluk: daire bakiyesi (`/units/{id}/dues`) o tablodan hesaplanıyor.
İkinci bir "ödeme" tablosu açmak, biri güncellenip diğeri unutulduğunda
hangi bakiyenin doğru olduğunu belirsiz bırakırdı.

### K4.1 — Mükerrer koruması

`external_transaction_id` tenant içinde **benzersiz**. Banka referans
veriyorsa o; vermiyorsa `(tarih|tutar|yön|açıklama|satır sırası)` beşlisinden
kararlı bir kimlik türetilir. Sıra numarası **şart**: aynı gün, aynı tutarda,
aynı açıklamayla iki gerçek havale olabilir ve onları tek satıra indirmek
gerçek bir ödemeyi yok saymak olurdu. Aynı ekstre ikinci kez yüklenince
`eklenen=0, yinelenen=N` döner — sessiz başarı değil.

`raw_data`, `tutar_kurus`, `yon`, `islem_tarihi` ve
`external_transaction_id` bir **tetikleyiciyle değiştirilemez**: ham kayıt
delilin kendisidir.

### K4.2 — Kaynak katmanı takılabilir

`banka_kaynak.py` her kaynağı tek bir `HamHareket`e çevirir; motor ve
uygulama katmanı kaynağı **bilmez**. Bugün iki kaynak var:

* **ekstre** — CSV/Excel **panelde** ayrıştırılır (XLSX ayrıştırma sunucuda
  bir saldırı yüzeyidir: zip bombası, XXE, formül enjeksiyonu — P28/P29
  kararı), sunucuya yapılandırılmış satır gelir ve **yeniden doğrulanır**.
* **MT940** — düz metin olduğu için **sunucuda** ayrıştırılır (`:61:`/`:86:`).
  Çelişki değil: zip/XML yok ve dosya panelin okuyamayacağı uzantılarla
  (`.sta`, `.940`) iner.

Açık bankacılık **v1'de yok**. İkinci kaynak olarak eklendiğinde
`HamHareket` üretmesi yeter; motor değişmez.

### K4.3 — Eşleştirme önceliği ve güven puanı

1. **Ödeme referansı** (`odeme_kodu`) → 100
2. **Gönderen IBAN**, daha önce *onaylanmış* bir eşleşmede görülmüşse → 85
3. **Ad + tutar + açık borç** → ad tam 60 / soyad 30, tutar tam 25 / altında 10

**Otomatik uygulama eşiği 80.** Altındaki her şey `manuel_inceleme`.
Değiştirilebilir: `banka.ESIK_OTOMATIK`.

Manuel incelemeye düşüren özel durumlar:

| Durum | Neden |
|---|---|
| Referans A'yı, IBAN geçmişi B'yi gösteriyor | **Çelişki.** Kirasını başkasının hesabından gönderen ya da eski referans kopyalayan kullanıcıda sessizce yanlış kişiye yazardık |
| Aynı IBAN iki kişiye bağlı (ortak hesap, eşler) | Seçim insanın |
| İki aday **eşit puan** | Boş bırakmak yanlış eşleştirmekten iyidir |
| Ad tutuyor ama tutar/borç tutmuyor | Ad eşleşmesi **tek başına yeterli değil** (kullanıcının kuralı) |
| Ad tutmuyor, yalnız tutar tutuyor | Aday bile sayılmaz: aynı aidatı ödeyen 200 kişilik sitede kura çekmek olurdu |
| **Çıkış** hareketi (banka masrafı/komisyon) | Otomatik gider **yazılmaz** |

### K4.4 — Varsayılan kurallar (değiştirilebilir)

| Kural | Varsayılan | Nerede |
|---|---|---|
| Kısmi ödeme | **FIFO** — en eski vadeden kapat (vade yoksa dönem) | `banka.fifo_dagit` |
| Fazla ödeme | Daire **alacağında** bekler (`assessment_id=NULL` ödeme satırı); sonraki borçtan kendiliğinden mahsup olur | `banka_servis.karari_uygula` |
| Banka masrafı/komisyon | **Yönetici onayına** düşer; otomatik gider yazılmaz — yalnız `masraf` işaretlenir | `routers/banka.isaretle` |
| Referans yoksa ad eşleşmesi | Denenir ama **tek başına yeterli değil** | `banka.eslestir` |
| Eşleşmeyenler | Yönetici paneline düşer, elle atanır | `/finans/banka` |
| Otomatik eşik | 80 | `banka.ESIK_OTOMATIK` |

### K4.5 — Senaryolar ve nerede ölçüldüğü

| Senaryo | Test |
|---|---|
| Referans doğru + tam / eksik / fazla | motor: `test_REFERANS_*` |
| Çok açık borç (FIFO) · tek transferle birkaç ay | motor + uç: `test_TEK_TRANSFER_IKI_AYI_KAPATIR_FIFO` |
| Referanssız + IBAN tanıdık | motor: `test_REFERANSSIZ_ama_IBAN_TANIDIK` |
| Referanssız + ad eşleşmesi | motor: `test_AD_*` |
| Hiç eşleşmeyen | motor + uç: `test_ESLESMEYEN_hareket_MANUEL_INCELEMEYE_duser` |
| **Yanlış referans** (IBAN geçmişiyle çelişiyor) | motor: `test_YANLIS_REFERANS_IBAN_GECMISIYLE_CELISIYORSA_MANUEL` |
| Bir kişi çok daire | motor: `test_BIR_KISI_COK_DAIRE_her_daire_ayri_aday` |
| Bir daire çok kişi (eşler/kiracı) | motor: `test_AYNI_IBAN_IKI_KISIYE_BAGLIYSA_MANUEL` |
| Borç öncesi peşin ödeme | motor: `test_BORC_YOKKEN_pesin_odeme_tamami_alacaga` |
| Açıklama boş/kesik | motor: `test_ACIKLAMA_BOS_ya_da_KESIK` |
| Aynı hareket iki kez (idempotent) | uç: `test_AYNI_EKSTRE_IKI_KEZ_yuklenince_MUKERRER_YOK` |
| İade / ters kayıt (borç yeniden açılır) | uç: `test_YANLIS_ESLESMEYI_GERI_ALMA_borcu_YENIDEN_ACAR` |
| Banka masrafı | motor + uç: `test_BANKA_MASRAFI_isaretlemesi_GIDER_YAZMAZ` |
| Eşleşme sonrası borç düzenlemesi | Geri alma + yeniden eşleştirme: `test_GERI_ALINAN_hareket_YENIDEN_eslestirilebilir` |
| Yanlış tesisin hesabı | **Tesisler arası taşıma YOK** — RLS engeller; hareket `ilgisiz_gelir` işaretlenir ve doğru tesiste yeniden yüklenir (`test_TESIS_IZOLASYONU`) |
| Elden/nakit | Banka akışının dışında: mevcut `/finans/tahsilat` yolu (değişmedi) |
| Manuel eşleştirme | uç: `test_MANUEL_ESLESTIRME_borcu_kapatir` |
| Yanlış eşleşmeyi geri alma | uç: yukarıdaki |
| "İlgisiz gelir" işaretleme | uç: `test_ILGISIZ_GELIR_isaretlenir` |
| Gecikme faizi | Mevcut `gecikme_uygula` alanı ve `borclandirma.gecikme_kurus` yolu — banka eşleştirmesi faizi **yeniden hesaplamaz**, açık borcun kalanını kapatır |

### K4.6 — Güvenlik

* **IBAN maskeli** (`TR***...4567`) her yanıtta; tam IBAN yalnız veritabanında
  ve yalnız "bu IBAN kiminle eşleşti" sorgusunda.
* **Her finansal işlem idempotent**: anahtar hareketten türer
  (`banka:<tx>:<deneme>:<sıra>`). `deneme` sayacı, geri alınmış bir hareketin
  yeniden eşleştirilebilmesi için gerekli (ölçüldü: tek anahtar
  `uq_payment_tenant_idempotency`e takılıyordu).
* **Silme yok, ters kayıt var**: `dues_payment='iptal'`, defterde
  `tip='iptal'` + `ters_kayit_id`, `payment_match='geri_alindi'`.
* **Her değişiklik denetim kaydına** (`audit_user`).
* **Tesis izolasyonu RLS** — üç tabloda da `FORCE ROW LEVEL SECURITY`.
* Uçların hepsi `admin`/`yonetici`; rol matrisi kilidi güncellendi.

### K4.7 — Bilinen davranışlar (kusur değil, karar)

* **Geri alınan eşleşmenin makbuzu SİLİNMEZ.** Belge iptal edilmez, defterde
  ters kayıt görünür; yeniden eşleştirme YENİ bir belge numarasıyla yeni bir
  makbuz üretir. Makbuzu silmek "bu belge hiç olmadı" demek olurdu.
* **Eş zamanlı iki "Eşleştir" tıklaması** para iki kez yazmaz
  (`uq_payment_tenant_idempotency`); ikinci istek 500 değil, hareketi
  `manuel_inceleme` bırakır (`not_metni='es_zamanli_islem'`).
* **Eşleştirme koşumu hareket başına adayları yeniden toplar.** 500 satırlık
  bir ekstrede bu yavaştır ama DOĞRUDUR: bayat aday listesiyle çalışmak aynı
  borcu iki kez kapatmaya çalışmak olurdu.

### K4.8 — Bitenler / bitmeyenler

**Biten (v1 kapsamı):** ekstre içe aktarma (CSV/Excel/MT940, takılabilir
kaynak), eşleştirme motoru, borç kapatma + defter kaydı, makbuz üretimi +
bildirim, eşleşmeyenler ekranı (elle atama, işaretleme, geri alma).

**Bilinçli olarak YOK:** açık bankacılık API'si (ikinci aşama; sözleşme,
kimlik saklama ve banka seçimi kararları önce verilmeli — `docs/banka-entegrasyonu-notu.md`),
gecikme faizinin banka akışında yeniden hesaplanması, tesisler arası hareket
taşıma.

---

## §1-ek — Cihaz jetonu hijyeni (UNREGISTERED birikmesi)

**Belirti:** push nihayet FCM'e ulaştı ve **7/7 deneme `UNREGISTERED`**
döndü. 18 kayıtlı cihaz vardı, **hepsi tek kullanıcıya ait** bayat jetonlar.

### KE1 — Budama yolu eksikti (asıl kusur)

`dispatch_external` UNREGISTERED jetonları zaten pasifleştiriyordu —
ama **`POST /push/test` yapmıyordu.** Yöneticinin elindeki tek araç test
düğmesiydi; her basışta ölü jetonlar tabloda kalıyor ve bir sonraki
gönderimde yeniden deneniyordu. Artık test yolu da buduyor
(`_jetonlari_buda`, ortak yardımcı) ve budanan sayısı yanıtta döner.

**Silme değil pasifleştirme:** `/devices` kaydının geçmişi korunur ve aynı
jeton yeniden kaydedilirse upsert onu geri açar.

### KE2 — Tekillik yanlış anahtardaydı

`UNIQUE (tenant_id, fcm_token)`. **Jeton bir cihaz kimliği değildir**,
cihazın o anki *adresidir*: yeniden kurulumda / veri temizliğinde / uzun
aradan sonra FCM yeni bir jeton verir ve her yeni jeton **yeni satır**
açıyordu. 18 kaydın hikâyesi budur.

**Karar:** `user_device.cihaz_kimligi` (göç 0082) + kısmi UNIQUE indeks
`(tenant_id, user_id, cihaz_kimligi) WHERE cihaz_kimligi IS NOT NULL AND aktif`.
Kayıtta aynı cihazın önceki jetonları pasifleştirilir.

* **Kurulum kimliği, donanım kimliği DEĞİL.** Donanım kimliği (androidId /
  IDFV) kalıcı bir izleyicidir, uygulama silinse bile kalır ve KVKK
  açısından gereksiz bir veridir. Kurulum kimliği ilk açılışta üretilir,
  güvenli depoda yaşar, uygulama silinince kaybolur — "aynı kurulum mu?"
  sorusuna cevap vermeye yeter. (Yeni paket eklenmedi: 16 rastgele bayt.)
* **Alan NULLABLE ve öyle kalmalı:** göndermeyen eski sürümler sahada
  çalışıyor. Zorunlu kılmak, güncellemeyen kullanıcının bildirimlerini
  tamamen kesmek olurdu.
* Kimlik **gönderilmeyen** bir istek, daha önce öğrenilmiş kimliği
  **silmez** (sürüm yükseltmesinde alan geçici boş gelirse tekilleştirme
  sessizce kapanırdı).

### KE3 — "Geçersiz jetonları temizle" düğmesi

`POST /push/cihaz-temizle` (admin/yönetici) — panelde **Bildirimler → Push
teşhisi** kartında.

* **Bildirim GÖNDERMEZ.** FCM `validate_only=true` ile doğrular: mesaj
  işlenir, teslim edilmez, kayıtsız jeton için yine `UNREGISTERED` döner.
  Bu bir bakım aracıdır; her tıklamada tesisteki herkesin telefonunun
  çalması kabul edilemezdi.
* **"Bakamadım" ile "hepsi sağlam" ayrı yanıtlardır** (`desteklenmiyor`).
  Sağlayıcı `noop` ya da kimliksiz `fcm` ise hiçbir jeton budanmaz ve
  arayüz bunu hata tonuyla söyler — ikisini karıştırmak ölü jetonları
  sağlam ilan etmekti.
* **Geçici hata jetonu öldürmez:** ağ/kota hatası `belirsiz` sayılır,
  jeton korunur ve bir sonraki temizlikte yeniden bakılır.
* Budanan her jeton `push_gonderim`e `kimlik='temizlik'` satırı olarak
  yazılır: "jetonlar neden azaldı" sorusu panelde cevaplanabilmeli.

### Mevcut 18 bayat jeton ne olacak

Prod'da `PUSH_PROVIDER=fcm` olduğu için **düğme onları temizler**
(doğrulama gerçek FCM'e gider). Alternatif olarak bir kez push gönderilmesi
de yeter: artık her yol buduyor.

### Mobil — bu makinede KOŞULAMADI

`mobile/` değişiklikleri (kurulum kimliği üretimi + `/devices` gövdesine
eklenmesi + test sahtesinin güncellenmesi) yazıldı, ama **`flutter test`
bu makinede çalıştırılamıyor** (Flutter kurulu değil, bkz. göç notu).
Mobil tarafın doğrulanması Windows makinede `flutter test` ile
yapılmalıdır. Sunucu tarafı mobil olmadan da güvenlidir: kimlik
gönderilmezse eski davranış sürer, budama yine çalışır.

---

## §3-ek — Kamera formu (görünüm + tasarım)

### KE4 — Görünüm bozuktu: ÖLÇÜLEN NEDEN

Form gövdesi `grid gap-3 sm:grid-cols-2`. P191 §3'te eklediğim **örnek
adres paragrafı ve test düğmesi doğrudan grid'in çocuğuydu** — her biri
BİR HÜCRE kapladı, sonraki alanlar yanlış sütuna kaydı ve ipuçları üst üste
bindi. Adres bloğu artık tek bir `sm:col-span-2` kutusudur.

### KE5 — "Bağlantıyı test et" neden görünmüyordu

Düğmeyi `form.tur === "rtsp"` koşuluna bağlamıştım; **yeni kamera formunda
tür varsayılanı `hls`** olduğu için düğme hiç çizilmiyordu. "Ekledim"
dediğim şey kullanıcıya görünmüyordu — özür değil, kilit: artık her zaman
çizilir, rtsp dışı adreste **pasiftir** ve yanındaki not nedenini söyler.
Gizlemek, kullanıcıyı "hani nerede?" diye aratmaktı.
`tests/kamera-oynatici.dom.test.ts` bunu kilitliyor.

### KE6 — Üç adres yerine TEK adres

P190'ın mimarisi zaten şuydu: **ızgarada ffmpeg karesi, tıklayınca MediaMTX
HLS** — yani sistem ikisini de **tek RTSP adresinden kendisi üretir**.
Yöneticiden ayrıca "yeniden yayın adresi" ve "anlık kare adresi" istemek,
cevabını bilemeyeceği iki soru sormaktı.

* Form artık **yalnız kamera adresi** ister.
* **Tür adresten türetilir** (`adrestenTur`): `rtsp://` → RTSP, `.mp4` →
  MP4, diğer http(s) → HLS. Kullanıcıya zaten yazdığı şeyi ikinci kez
  sormak, yanlış cevaplanabilecek bir soru eklemekti (ve yanlış tür
  sunucuda 422 üretiyordu). Türetilemeyen (yarım yazılmış) adreste mevcut
  seçim **korunur** — her tuş vuruşunda türü sıfırlamak, kullanıcının
  yazdığını altından çekmek olurdu.
* **Alanlar SİLİNMEDİ**, "Gelişmiş ayarlar" altına indi (varsayılan
  kapalı): kendi geçidini (Frigate/go2rtc) çalıştıran kurulumlar onları
  kullanıyor ve silmek çalışan bir kurulumu kırardı. Düzenlemede dolu bir
  gelişmiş alan varsa bölüm **açılır** — kaydettiği değeri göremeyen
  kullanıcı onu "silinmiş" sanır.
