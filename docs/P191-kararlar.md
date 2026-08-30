
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
