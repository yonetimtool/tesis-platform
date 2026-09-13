# P230 — erişilebilirlik, mobil arama, görev takibi, RTSP

## §1 — RTSP canlı yayın: zincir ölçüldü, **sunucuda kopmuyor**

Üç turda üç kök neden bulunup düzeltilmişti ve hâlâ çalışmıyordu. Bu turda
körlemesine düzeltme denemedim; zinciri adım adım sürdüm.

| adım | ölçüm | sonuç |
|---|---|---|
| **(a)** istemci → BFF/API | `/cameras/{id}/canli/index.m3u8` | vekil çalışıyor |
| **(b)** API → MediaMTX | `GET http://mediamtx:9997/v3/paths/list` | **HTTP 200**, 54 yol |
| **(c)** MediaMTX → RTSP kaynağı | mediamtx günlüğü | `[RTSP source] ready: 1 track (H265)` |
| **(d)** HLS üretimi | `GET http://mediamtx:8888/<yol>/index.m3u8` | **200**, `CODECS="hvc1.4.10.L63.9e.8"`, 640x360@15, alt playlist'te `init.mp4` + segmentler |
| **(e)** istemci çözme | — | **KOPMA BURADA** |

Ham çıktı:

```
mediamtx | [path cam308e...] [RTSP source] ready: 1 track (H265)
mediamtx | [HLS] [muxer cam308e...] is converting into HLS, 1 track (H265)

#EXT-X-STREAM-INF:BANDWIDTH=226996,CODECS="hvc1.4.10.L63.9e.8",RESOLUTION=640x360
video1_stream.m3u8
```

**Sunucu tarafı doğru çalışıyor.** Kamera H265 yayın yapıyor; masaüstü
tarayıcıların çoğu HEVC'yi MSE üzerinden çözemiyor (Chrome donanıma bağlı,
Firefox çoğu kurulumda hiç). Dördüncü turda da "sunucuyu düzeltmek"
denenseydi hiçbir şey değişmezdi.

### Kullanıcıya gösterilen mesaj zaten doğruydu — ama eksik

Web oynatıcı P216'dan beri playlist'ten kodeği okuyup
`MediaSource.isTypeSupported` ile **kendi tarayıcısının** gerçek yanıtını
alıyor ve "ağ erişimini kontrol edin" demiyor. Yani §1'in "yanlış
yönlendirme" endişesi web'de zaten giderilmişti.

Eksik olan, mesajın **ne yapılacağını** söyleme biçimiydi: "adresi H264
alt akışla **değiştirin**" diyordu.

### Karar: ana adres değiştirilmez — ayrı `alt_stream_url` alanı (göç 0132)

`stream_url` yalnız canlı izleme için kullanılmıyor:

* `GET /cameras/{id}/kare` ızgara karesini **ffmpeg** ile ondan çekiyor,
* NVR kayıt oynatma ve kayıt aralıkları ona bağlı.

**ffmpeg H265'i sorunsuz çözüyor.** Ana adresi alt akışla değiştirmek,
çözülmesi *gerekmeyen* bir yerde çözünürlüğü düşürmek olurdu. İki adres
ayrı saklanıyor: ana akış kare/kayıt için, alt akış **yalnız canlı** için.
`etkin_stream_url(obj, canli=True)` seçimi yapıyor.

`restream_url`'den ayrı: o, dışarıdaki bir geçidin (Frigate/go2rtc) hazır
HLS adresi; `alt_stream_url` kameranın kendi ikinci RTSP akışı ve yine
MediaMTX'ten geçiyor.

**Kimlik sızıntısı — testin yakaladığı hata.** İlk yazımda alt akış
`_kimligi_ayikla`'dan geçmiyordu ve `rtsp://kul:par@konak/sub` veritabanında
**düz** duruyordu: P213 §6b'de ana adres için kapatılan sızıntı ikinci bir
alanla yeniden açılmıştı. Alt akış artık aynı kuraldan geçiyor ve izleyici
rollerine maskeleniyor.

### Transcode — P216'nın sayısı yeniden ölçüldü

Kullanıcı "bir kamera için, izlenirken, düşük çözünürlükte yapılabilir mi?
Yeniden ölç" dedi. Ölçtüm (aynı 4 çekirdekli makine, H265→H264,
`veryfast` + `zerolatency`):

| kaynak | bit hızı | hız |
|---|---|---|
| 640x360 (alt akış tipik) | 1526 kb/s | **4.75×** |
| 1280x720 | 6511 kb/s | 2.61× |
| 1920x1080 | 15191 kb/s | 1.21× |

P216 720p15'te `1.12×` ölçmüştü; ben aynı çözünürlükte `2.61×` ölçtüm.
Fark muhtemelen ön ayar/kaynak farkından geliyor — **P216'yı yanlış ilan
etmiyorum**, ama sonucu şu yönde düzeltiyorum: **alt akış çözünürlüğünde
transcode teknik olarak mümkün.** Yine de birincil çözüm olarak
seçilmedi:

* **Bedeli sıfır olan bir alternatif var** (kameranın kendi H264 akışı) ve
  kalite site izlemesi için fazlasıyla yeterli.
* Ölçüm bu makinede ve **sentetik gürültülü** kaynakla yapıldı; prod
  donanımı ve gerçek kamera içeriği farklı. Tek kamera 4.75× iken dört
  eşzamanlı izleyici bu payı bitirir.
* MediaMTX kendi başına transcode yapmaz; `runOnDemand` ile ffmpeg
  süreçleri doğurmak ve RTSP sunucusunu açmak gerekir — saldırı yüzeyi
  büyür.

**Yapılmadı, açıkça söylüyorum:** isteğe bağlı sunucu-tarafı transcode
kurulmadı. Ölçüm, ileride istenirse yapılabilir olduğunu gösteriyor.

### Ölçemediğim

* Gerçek bir tarayıcıda H265 oynatma denemesi — bu makinede tarayıcı yok.
  Ölçtüğüm, sunucunun ürettiği playlist'in kodek dizgisi ve istemci
  tarafındaki tespit mantığının testleri.
* Mobil oynatıcının H265 davranışı — emülatör yok. Android platform
  kodekleri HEVC'yi yaygın olarak destekler, ama bunu **doğrulamadım**.
