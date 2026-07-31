# Kamera yayınları — ne oynar, ne oynamaz, neden

> MASTER-PLAN **P25(b)**. Şikayet: *"internetteki genel yayınlar oynamıyor."*
> Bu belge nedeni, yapılan düzeltmeyi ve desteklenen adres sınıflarını yazar.

## 1. Kök neden: cleartext HTTP **sürüm derlemesinde kapalıydı**

Uygulama `usesCleartextTraffic="true"` bayrağını **yalnızca**
`android/app/src/debug/AndroidManifest.xml` içinde taşıyordu — yani geliştirme
derlemesinde açık, **sürüm (release) derlemesinde kapalı**. Android 9'dan
(targetSdk ≥ 28) beri cleartext varsayılan olarak yasaktır. Sonuç:

* **`http://` ile başlayan her yayın adresi sürüm derlemesinde sessizce
  düşüyordu.** Oynatıcı bunu ayırt edemeyip tek bir genel "Yayın açılamadı"
  cümlesi gösteriyordu.
* Bu, yalnızca kamu test yayınlarını değil **P17'nin restream özelliğini de**
  vuruyordu: Frigate/go2rtc geçidi neredeyse her zaman düz `http`tir
  (`http://frigate.site.local:5000/...`). Yani "RTSP kamerayı oynatılabilir
  yap" özelliği **yayında çalışmıyordu** — geliştirmede çalıştığı için de
  fark edilmemişti.

iOS tarafında karşılığı **App Transport Security**tir: `http` yüklemeleri
varsayılan olarak engellenir ve `Info.plist`te hiçbir istisna yoktu.

### Yapılan

| Platform | Değişiklik | Kapsam |
|---|---|---|
| Android | `res/xml/network_security_config.xml` (`cleartextTrafficPermitted="true"`) + manifest'te `android:networkSecurityConfig` | Uygulama geneli — Android'de **medyaya özel bir kapsam yoktur** |
| iOS | `NSAppTransportSecurity` → `NSAllowsArbitraryLoadsForMedia` | **Yalnız AVFoundation medya yüklemeleri**; `URLSession` (API çağrıları) ATS korumasında kalır |

**Neden alan adı kapsamı yok:** kamera adresleri kullanıcı tarafından çalışma
anında girilir; derleme anında bilinen bir alan adı listesi yoktur.

**Bu neyi zayıflatmaz:** cleartext izni `https`i düşürmez — yalnızca açıkça
`http` istenirse buna izin verir. Uygulamanın API adresi derleme anında
sabittir (`AppConfig.apiBaseUrl`) ve üretimde `https`tir. Kullanıcı forma
`http://` yazdığında artık **uyarı** görür (hata değil — adres geçerlidir).

## 2. İkinci neden: bozuk adres **yakalanmamış istisna** atıyordu

`Uri.parse(...)` çağrısı oynatıcıda `try` bloğunun **dışındaydı**. İçinde
boşluk veya satır sonu taşıyan bir adres (yapıştırma artığı) `FormatException`
fırlatıyor ve bu hiç yakalanmıyordu. Artık adres önce `Uri.tryParse` ile
çözülür; çözülemezse **"Yayın adresi geçersiz"** gösterilir.

## 3. Hata artık **nedene göre** konuşuyor

Tek cümle yerine dört ayrı neden (`YayinHatasi`):

| Neden | Kullanıcıya | Kullanıcının yapacağı |
|---|---|---|
| `adresBozuk` | "Yayın adresi geçersiz…" | adresi düzeltir |
| `semaDesteklenmiyor` | "Bu adres türü doğrudan oynatılamaz…" | restream adresi tanımlar |
| `sifrelenmemisEngellendi` | "Şifrelenmemiş (http) yayın cihaz tarafından engellendi…" | kurumsal profil/VPN'e bakar |
| `ulasilamadi` | "Kamera kapalı olabilir ya da ağ yayına ulaşamıyor." | kamerayı/ağı kontrol eder |

Eski tek cümle (`ulasilamadi` metni) her başarısızlıkta gösteriliyordu ve
adres yanlış yazıldığında kullanıcıyı **kamerayı kontrol etmeye** yolluyordu.

## 4. Desteklenen adres sınıfları

| Sınıf | Oynar mı | Not |
|---|---|---|
| `https://…​.m3u8` (HLS) | **Evet** | Android ExoPlayer / iOS AVPlayer yerel destek |
| `http://…​.m3u8` (HLS) | **Evet** (P25'ten sonra) | Kurumsal profil/VPN yine kesebilir |
| `https://…​.mp4` / `http://…​.mp4` | **Evet** | Aşamalı indirme; canlı değil |
| `rtsp://…` | **Hayır** — tek başına | `restream_url` tanımlıysa geçit oynatılır (P17) |
| `rtmp://`, `srt://`, `webrtc` | **Hayır** | Platform oynatıcısında yok; restream gerekir |
| DASH (`.mpd`) | **Android'de evet, iOS'ta hayır** | Kayıt türü olarak sunulmuyor; HLS kullanın |

### Ölçüm (2026-07-31, `curl`)

Kamu adresleri, yönlendirme ve içerik tipi açısından ölçüldü. Bu ölçüm cihaz
davranışını birebir taklit **etmez** (ExoPlayer/AVPlayer ayrı yığınlardır),
ama aday nedenleri ayırır:

| Adres | Kod | Yönlendirme | İçerik tipi |
|---|---|---|---|
| `test-streams.mux.dev/x36xhzz/x36xhzz.m3u8` | 200 | 0 | `audio/mpegurl` |
| `devstreaming-cdn.apple.com/…/master.m3u8` | 200 | 0 | `application/x-mpegURL` |
| `test-streams.mux.dev/pts_shift/master.m3u8` | 200 | 0 | `audio/mpegurl` |
| `demo.unified-streaming.com/…/.m3u8` | 200 | 0 | `application/vnd.apple.mpegurl` |

**Bulgu:** HLS çalma listeleri üç farklı içerik tipiyle sunuluyor
(`audio/mpegurl`, `application/x-mpegURL`, `application/vnd.apple.mpegurl`) —
her üçü de oynatıcılarca tanınır, yani içerik tipi bir neden **değil**.
Örneklemde **çapraz protokol yönlendirmesi (https→http) yok**; bu önemli,
çünkü ExoPlayer bunu varsayılan olarak reddeder ve `video_player` bayrağı
dışarı açmaz. Böyle bir adresle karşılaşılırsa çözüm bir restream geçididir.

> Ölçüm sırasında `bitdash-a.akamaihd.net` ve `commondatastorage.googleapis.com`
> **403** döndü. Bu adreslerin kendi kısıtı ya da ölçüm yapılan ağın çıkış
> kuralı olabilir; **cihazda tekrar denenmeden** "desteklenmiyor" diye
> yazılmadı.

## 5. Adres uzunluğu (P25a)

`stream_url` ve `restream_url` **en fazla 2048 karakter**. Üç katmanda:

1. mobil form (gönderilmeden uyarır),
2. `schemas.dogrula_url_tur` / `dogrula_restream` → 422 `kamera_url_cok_uzun`
   (7 dilde),
3. `0015` revizyonunda `CHECK` kısıtı.

2048, HTTP yığınlarının fiili URL sınırıdır. Sınırsız `text` sütunu,
yapıştırılan bir DVR yapılandırmasının tamamını kabul edip listeyi ve mobil
kart çizimini şişiriyordu.

## 6. Cihazda doğrulanacaklar

MASTER-PLAN P11 device-verify listesine yazıldı: **sürüm** derlemesiyle bir
`http://` HLS adresi oynatılmalı (asıl ölçüm budur — `flutter run` varsayılan
olarak debug derler ve debug'da bu hata **hiç görünmez**).
