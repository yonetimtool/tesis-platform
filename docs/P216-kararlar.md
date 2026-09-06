# P216 — H265 kameralar: HLS varyantı, yol yarışı, kodek teşhisi

## Kök neden (yeniden üretildi)

Dev'de sentetik bir H265 kaynağı (`rtsp://testcam:8554/cam265`, ffprobe:
`hevc`) kurup prod logunun **birebir aynısını** ürettim:

```
INF [path olcum265] [RTSP source] ready: 1 track (H265)
INF [HLS] [muxer olcum265] destroyed: the MPEG-TS variant of HLS
    supports H264 video only
HLS durum: 404
```

## 1. Kodek — seçenekler ölçüldü

| Seçenek | Ölçüm | Karar |
|---|---|---|
| `mpegts` + H265 | muxer anında yok ediliyor, HLS 404 | mevcut kusur |
| **`fmp4` + H265** | **HLS 200, `CODECS="hvc1.4.10.L63.9e.8"`** | **seçildi** |
| `fmp4` + H264 | HLS 200, `CODECS="avc1.f40016"` | bozulmadı |
| `lowLatency` + H265 | HLS 200 (çalışıyor) | **reddedildi** |
| Sunucuda transcode 1080p25 | ffmpeg `speed=0.693x` | **reddedildi** |
| Sunucuda transcode 720p15 | ffmpeg `speed=1.12x` | **reddedildi** |

**Neden `fmp4`, `lowLatency` değil:** ikisi de H265'i destekliyor, ama
LL-HLS `CAN-BLOCK-RELOAD=YES` ile playlist isteklerini **sunucuda
bekletir**. Bizim HLS vekilimiz her isteği 15 sn zaman aşımıyla vekilliyor
ve eş-zamanlı kamera sınırını Redis'te tutuyor; bekletilen istekler o
sınırın altını oyar ve zaman aşımı hatalarına yol açar. Kazanç gecikmede,
bedel karmaşıklıkta olurdu — site kamerasında yarım saniye fark etmez.

**Neden transcode değil — sayıyla:** 4 çekirdekli bu makinede 1080p25
H265→H264 dönüştürme **gerçek zamandan yavaş** (`0.693x`): tek akış bile
yetişemiyor. 720p15'te `1.12x`, yani tek akış bir çekirdeği neredeyse
doyuruyor ve %12 pay bırakıyor. 8 kameralı bir site için bu, yalnızca
transcode'a ayrılmış 8 çekirdek demek. Ayrıca MediaMTX kendi başına
transcode yapmaz; `runOnDemand` ile ffmpeg süreçleri doğurmak ve RTSP
sunucusunu (şu an kapalı) açmak gerekirdi — saldırı yüzeyi de büyürdü.

**Birincil öneri kameradan H264 istemek:** maliyeti sıfır, çoğu kamerada
ikinci (alt) akış zaten H264 ve kalite site izlemesi için fazlasıyla
yeterli. Bu, kullanıcıya gösterilen hata mesajının içine yazıldı.

## Mobil

`fmp4` + H265 mobilde **çalışması beklenir**: Android ExoPlayer ve iOS
AVPlayer HEVC'yi donanım kod çözücüyle oynatır. **Ölçemedim** — elimde
cihaz yok (bkz. "Ölçemediğim" bölümü). Önemli olan şu: sunucu H265'i
**sunuyor**, engellemiyor; mobil tarafta ek bir değişiklik gerekmedi.

## 2. "path already exists" — yarış değil, yanlış soru sırası

Eski akış her istekte körü körüne `add` deniyordu. Yol zaten varsa
(ikinci izleyici, sayfa yenileme, ardışık istekler) MediaMTX bunu **hata**
olarak yazıyor, biz de arkasından gereksiz bir `patch` atıp
yapılandırmayı **yeniden yüklettiriyorduk** — hem de izleyen varken.

Doğru sıra: **var mı → yoksa ekle, varsa ve kaynak aynıysa dokunma,
farklıysa güncelle.** İki `add` yarışırsa ikincisinin aldığı "already
exists" artık **beklenen sonuç** olarak kabul ediliyor (INFO, hata değil).

"Dokunma" kuralı fazla geniş olmasın diye ayrıca ölçülüyor: kaynak
değiştiğinde yol **güncelleniyor** — yoksa kamera adresi değiştirildiğinde
eski yayın sonsuza dek yaşardı.

## 3. Hata mesajı: kodek ayrı bir teşhis

HLS 404'ün üç sebebi olabilir ve üçü de aynı 404'ü üretir: kaynak henüz
hazır değil / kaynağa bağlanılamıyor / **kodek desteklenmiyor**.
Sonuncusunda "adresi kontrol edin" demek, hiçbir sorunu olmayan kamerayı
kurcalatmaktı.

Artık 404 alındığında MediaMTX'e **yolun izleri soruluyor**; sorunlu bir
kodek görülürse `code: codec_unsupported` ve 7 dilde şu mesaj dönüyor:
*"Bu kamera H265 ile yayın yapıyor ve tarayıcıda izlenemiyor. Mobil
uygulamadan izleyebilir ya da kameranın H264 (alt) akışını açıp adresi
onunla değiştirebilirsiniz."*

**Ama asıl karar sunucuda değil.** `fmp4` ile H265 artık HLS'e giriyor,
yani sunucu yayını **sunuyor**. "H265 gördüm, 502 döneyim" demek Safari
kullanıcısına ve mobil uygulamaya da yayını kapatmak olurdu — ikisi de
oynatabiliyor. Karar istemcide: oynatıcı playlist'ten `CODECS`'i okuyup
**kendi tarayıcısına** `MediaSource.isTypeSupported` ile soruyor;
desteklenmiyorsa hls.js'i hiç başlatmadan ne yapılacağını söylüyor.

*(İlk uygulamamda sunucu H265'i topyekun reddediyordu; bunu ölçüm
sırasında fark edip düzelttim — Safari ve mobil kullanıcısını da
kapatıyordu.)*

## 4. "Bağlantıyı test et" artık kodeki de söylüyor

`POST /cameras/test-baglanti` yanıtına `kodek` ve `tarayicida_oynatilir`
eklendi (ffprobe ile, gerçek ölçüm: `hevc` / `h264`). **"Kare geldi"
yeterli değildi:** kareyi sunucudaki ffmpeg çeker ve H265'te de çalışır;
tarayıcıda oynatma ayrı bir sorudur. Yönetici bunu eskiden ancak kamerayı
kaydedip ana ekrana koyduktan sonra, ilk tıklamada öğreniyordu.

Sorunlu kodek **kaydetmeyi engellemez** (kamera mobilde izlenebilir ve
kaydı anlamlıdır), uyarı olarak gösterilir.

## Ölçüm sırasında çıkan üçüncü bulgu

Dosyada `hlsVariant: fmp4` yazıp `restart` ettikten sonra geçit **hâlâ
`mpegts` çalıştırıyordu**: konteyner P215 öncesinden kalma
`MTX_HLSVARIANT=mpegts` ortam değişkenini taşıyordu ve `restart` env'i
güncellemez. `up -d --force-recreate` gerekti.

Bu, P215'te prod için yazdığım uyarının dev'deki birebir karşılığı ve
artık **testle** de yakalanıyor: dosyadaki varyant ile **çalışan** geçidin
varyantı karşılaştırılıyor.

## Kilitler

`backend/tests/test_p216_kodek.py` (9): varyantın H265 destekleyen bir
değer olması, **çalışan** geçidin dosyayla aynı varyantı kullanması,
ffprobe kodek tespiti (gerçek H265/H264 kaynaklarla), test-bağlantı
raporu, yol kaydının tekrarlanabilir olması ve kaynak değişince
güncellenmesi, ve **uçtan uca**: H265 kamerada canlı yayın playlist'inin
gerçekten üretilmesi.

`admin-web/tests/p216-kodek.dom.test.ts` (8): kodek okuma, tarayıcıya
sorma, MSE yokken denemeye izin verme, H265'te ne yapılacağını söyleme ve
hls.js'i boşuna indirmeme.

Her iki kilit de **kırılarak** doğrulandı: varyant `mpegts`'e çevrildiğinde
backend testi *"H265 kaynak yayında ama canlı yayın üretilmedi (502)"*
diyerek düştü; ön kontrol kaldırıldığında web testi düştü.

**Bir zayıflığı düzelttim:** uçtan uca test ilk yazımda 200 gelmeyince
`skip` ediyordu — yani kök neden geri geldiğinde susuyordu. Artık önce
kaynağın gerçekten H265 yayınladığı ölçülüyor; yayınlıyorsa 200 **zorunlu**.

## Ölçemediğim

- **Gerçek tarayıcılarda H265 desteği.** Playwright'ın Chromium'u açık
  kaynak derleme ve tescilli kodek içermiyor (H264 bile `false` döndü);
  gerçek Chrome kanalı bu makinede kurulamıyor (sudo). Firefox/WebKit
  kurulu değil. Bu yüzden "Chrome H265 oynatır mı" sorusunu **ölçmedim** —
  ve tasarım tam da bu yüzden kararı çalışma anında kullanıcının kendi
  tarayıcısına soruyor.
- **Mobilde H265 oynatma.** Cihaz yok; ExoPlayer/AVPlayer'ın HEVC
  desteğine dayanıyorum. Sunucu tarafı engellemiyor, yani denenebilir.
- **Prod'da doğrulama** sizde: `up -d --force-recreate mediamtx` (restart
  yetmez) ve `docs/P216-dagitim.md`.
