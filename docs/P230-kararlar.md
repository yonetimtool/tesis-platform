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

---

## §3 — Mobilde arama

### Ölçüm: uç zaten var, yeni uç açılmadı

`GET /arama?q=` mevcut ve web onu kullanıyor: **17 kaynak** (kişi, daire,
blok, firma, görev, duyuru, talep, finans, demirbaş, etkinlik, araç,
nokta, kamera, plan, vardiya, icra, sayaç), rol süzgeci **sunucuda**.

Süzgecin zarif yanı: `kaynak.roller` her router'ın kendi `require_role`
kümesinden okunuyor (`_rol_kumesi`), yani bir router'ın rol kümesi
değiştiğinde arama kendiliğinden aynı değişimi alıyor. Mobil için ikinci
bir uç yazmak, o kümelerin **ikinci bir kopyası** demekti ve biri
güncellenip öteki eskidiğinde sessiz bir yetki sapması doğururdu.

### Bulunan gerçek eksik: Türkçe harf duyarsızlık yoktu

Arama düz `ILIKE` kullanıyordu. **"cekmekoy" yazan kullanıcı "Çekmeköy"ü
bulamıyordu** — ve boş sonuç, arama hatalarının en kötüsü: kullanıcı
kaydın *olmadığını* sanır, aramanın çalışmadığını değil.

Çözüm iki tarafta katlama: `lower(translate(kolon, 'çğıİöşüÇĞÖŞÜ',
'cgiiosucgosu'))`.

* **Neden `unaccent` değil:** `ı`/`İ` Latin-1 aksanlı harf **değildir**;
  `unaccent` `ı`yı `i`ye çevirmez. Türkçe için özel katlama şart.
* **Neden iki tarafta:** yalnız deseni katlamak, "Çekmeköy" yazanı
  bulamaz hale getirirdi (kolon hâlâ `ö` taşıyor).
* **İndeks kullanılmıyor, kabul:** tablolar tesis kapsamlı (RLS) ve her
  kaynak `_KAYNAK_SINIRI` ile sınırlı. 17 kaynak için 17 ifade indeksi,
  kazancı ölçülmeden ödenecek bir bedeldi.

### Mobil ekran kararları

| karar | gerekçe |
|---|---|
| Karşılama satırında **simge**, kutu değil | Dar ekranda metin kutusu karşılama satırını yer kalmayacak kadar daraltırdı — P229 §1'de ölçülen taşmanın aynısı. Dokunma hedefi `IconButton` varsayılanıyla 48×48. |
| 300 ms gecikme | Tuşlama başına istek, her harfte 17 kaynaklık tam metin taraması demekti. Web'deki değerle aynı. |
| Önceki istek **iptal edilir** | Yavaş bir yanıt, sonradan yazılan daha dar aramanın sonucunu ezebilirdi (yarış koşulu). |
| İki harf eşiği istemcide de var | Sunucu zaten 422 veriyor; istemci uygulamasaydı her tek harfte boşuna bir hata alınırdı. |
| Ekranı olmayan kaynak **gizlenmez**, dokunması kapatılır | Gizlemek "kayıt yok" izlenimi verirdi — **yanlış**: kayıt var, mobilde gösterilecek ekran yok. 17 kaynağın 12'sinin mobil ekranı var. |
| Kaynak adı sunucudan **kimlik** olarak gelir | Metin gelseydi yedi dilde çevrilemezdi. |

### Ölçemediğim

Gerçek cihazda gezinme (sonuçtan ekrana gidiş) — emülatör yok. Ölçtüğüm,
rota eşlemesinin ve dokunma davranışının widget testleri.

---

## §4 — Görev takibi

### Ölçüm: üç alanın üçü de yoktu

| ihtiyaç | ölçülen durum |
|---|---|
| durum | **yok** — P229'da yalnız tamamlama eklendi; "başlandı mı", "gecikti mi" yanıtlanamıyordu |
| son tarih | **yok** — gecikme hesaplanamıyordu |
| kim atadı | **yok** — `atanan_user_id` kime atandığını söylüyordu, kimin verdiğini değil |

### Karar: durum **saklanmaz, türetilir**

Dört durumun üçü zaten başka verilerden türüyor:

```
atandi     : kayıt var, başlama yok, tamamlama yok
baslandi   : baslama_zamani dolu, tamamlama yok
tamamlandi : task_completion satırı var (P229)
gecikti    : son_tarih geçmiş ve tamamlama yok
```

Ayrı bir `durum` kolonu bu üç kaynakla **senkron tutulmak** zorunda
olurdu: tamamlama silinince (P229 geri açma) durumu geri almayı unutan
bir kod yolu, görevi "tamamlandı" görünür bırakırdı. Türetilmiş durum
böyle bir ayrışma üretemez.

`baslama_zamani` **tek yeni gerçektir** — başka hiçbir yerden türetilemez.

**Sıra önemli:** `tamamlandi` her şeyden önce gelir. Son tarihi geçmiş
ama tamamlanmış bir görevi "gecikti" göstermek, biten işi bitmemiş gibi
raporlamak olurdu. Kilidi bunu kırarak doğruladım: sırayı ters çevirince
2 test düştü.

**`gecikme_gun` son tarih yoksa `null`, sıfır değil.** Sıfır "bugün son
gün" demektir; "ölçüsü yok" ile karıştırılamaz.

### "Başlandı" durumu — evet, gerekli

Önceden yalnız iki hal vardı. Arada geçen sürede yönetici, işin **ele
alındığını** mı yoksa **öylece durduğunu** mu bilmiyordu. "Gecikti"
uyarısının değeri de buna bağlı: başlanmış ama uzayan bir iş ile hiç
dokunulmamış bir iş aynı şey değil.

* **Kim:** `_COMPLETER` (admin + yönetici + saha). Saha rolü **yalnız
  kendine atanan** görevi başlatabilir — tamamlama ile aynı kural. Farklı
  olsaydı, başkasının görevini "başlatıp" tamamlayamayan bir kullanıcı
  ortaya çıkardı.
* **İdempotent:** ikinci çağrı zamanı **ezmez**. Ezseydi, yanlışlıkla iki
  kez dokunan kullanıcı gerçek başlama anını kaybederdi — ve "ne zaman
  başlandı" takip ekranının taşıdığı bilgiydi.
* Denetim kaydına yazılıyor (`task_start`).

### Gecikme neye göre

`son_tarih` (yeni alan). `sonraki_planlanan`**dan ayrı**: o yalnız
periyodik görevlerde dolu ve anlamı "bir sonraki tekrar". Tek seferlik bir
görevin son tarihi oraya yazılsaydı, tamamlanan görev periyot
ilerletmesine girerdi.

### Kim atadı

`olusturan_user_id` **gövdeden alınmaz, oturumdan gelir** — istemcinin
gönderebileceği bir alan olsaydı başkasının adına görev atanabilirdi.
FK yok (bilinçli): atayan hesap silinse/anonimleşse de görevin geçmişi
kalmalı, `audit_log.actor_user_id` ile aynı gerekçe.

`olusturan_ad` ve `atanan_ad` sunucuda çözülüyor: saha rolü kullanıcı
listesini göremiyor (403), yani "bu işi bana kim verdi" sorusunu istemci
kendi çözemezdi. P229'daki `tamamlayan_ad` kararının aynısı.

### Durum süzgeci **sunucuda**

İstemcide süzmek sayfalamayı bozardı: sunucu 50 satır döner, istemci
7'sini gösterir ve kullanıcı "toplam 300" yazan bir sayfalayıcıda boş
sayfalar gezerdi. Süzgeç, türetmenin SQL'deki karşılığını tekrarlıyor —
ve "geciken görev `baslandi` listesinde çıkmaz" kuralı test edilmiş
durumda (ayrışsaydı aynı görev iki listede birden görünürdü).

### Ek bulgu: P229'un sözleşme düzenlemesi yanlış şemaya gitmişti

`tamamlandi` ve `son_tamamlama` alanları `Task` yerine **`Device`**
şemasına eklenmişti (aynı `aktif: { type: boolean }` satırı iki şemada da
var ve ilk eşleşme `Device`'a düşüyor). P230 alanları da aynı tuzağa
düştü. İkisi de düzeltildi: `Device` temizlendi, dokuz alan `Task`'a
taşındı.

### Yapılmadı, açıkça söylüyorum

**Gecikmiş göreve bildirim gönderilmiyor.** Gerekçe: bildirim bir
zamanlayıcı (beat) görevi ister ve "her gün kaç kez, kime, hangi eşikle"
sorularının yanıtı ürün kararıdır — tahmin edip göndermek, yöneticiye her
sabah tekrarlayan bir gürültü üretme riski taşır. Alan ve durum artık
hazır; kural verildiğinde eklenebilir.

---

## §2 — Erişilebilirlik: yaşlı kullanıcılar

### Ölçüm önce — beş maddenin ikisi zaten çözülmüş

| madde | ölçülen durum |
|---|---|
| **(b) sistem metin ölçeği izleniyor mu** | **Evet.** `main.dart`'ta bir `textScaler` geçersiz kılması **yok** (arandı) — Flutter varsayılanı sistem ölçeğini uygular. |
| **(b) büyük ölçekte düzen bozuluyor mu** | P229 §1 kilidi 320dp'de **1.0 ve 1.3** ölçeği zaten sürüyordu; ana ekranlar 7 dilde istisnasız geçiyor. |
| **(d) dokunma hedefleri** | 48×48 kuralı P220'de kilitli; büyük modda hücreler **zaten büyüyor** (2 sütun), ayrıca bir şey yapmak gerekmedi. |
| **(e) kontrast** | **Zaten ölçülüyor**: beş eksen sürüşü `meetsGuideline(textContrastGuideline)` — Flutter'ın WCAG AA denetimi. |

Yani (b), (d) ve (e) için yeni altyapı gerekmedi. Eksik olan, sistem
ayarını **bilmeyen** kullanıcı için uygulama içi bir yol ve "az öğe"
kararıydı.

### Karar: tek ayar — Ayarlar → Görünüm (Standart / Büyük)

İsteğin kendi cümlesi: *"yaşlı kullanıcı beş ayrı ayarla uğraşmasın"*.
Yazı boyutu, ikon boyutu, sütun sayısı ve karo sayısı ayrı ayrı
ayarlanabilir şeyler; ama onları ayrı ayrı sunmak, **en çok yardıma
ihtiyacı olan kullanıcıya en çok karar yükleyen** tasarım olurdu.

Büyük mod aynı anda: metin ×1.3, ızgara 2 sütun, karo 8 → **4**.

### "Az öğe" > "küçük öğe" — hangi dördü kalır

Sekiz karoyu büyütüp ekrana sığdırmaya çalışmak her karoyu yeniden
küçültürdü; yani ayar **hiçbir şey yapmamış** olurdu.

Kalan dört karo: **kullanıcının kendi ızgara sırasının ilk dördü**
(`izgara_duzenle` ekranında düzenlediği sıra). "Büyük mod için ayrı
liste" kavramı eklemek, kullanıcıya **ikinci bir düzenleme ekranı**
öğretmek olurdu.

### Metin ölçeği sistem ayarını **ezmez, üstüne çarpar**

En kritik kural. Sistemde zaten 1.5 kullanan biri büyük modu açınca
1.3'e **düşmemeli** — sabit bir ölçek yazmak tam olarak bunu yapardı ve
zaten büyük yazı kullanan kullanıcı için bir **gerileme** olurdu.
`_Carpan` cihazın gerçek ölçeğini koruyup çarpıyor. Kilidi kırarak
doğruladım: sabit ölçeğe çevirince test düştü.

**Çarpan neden 1.3:** 1.5 ve üstü, iki satırlık kart başlıklarını 8
puntoya kadar küçültürdü (P229 §1'de ölçülen taban) — yani "büyüt" ayarı
başlıkları **küçültürdü**.

### Sarmalayıcı en dışta

`MaterialApp.builder` tüm rotaları sarıyor, yani büyük mod tek ekranda
değil **uygulamanın tamamında** geçerli. Ekran ekran sarmak birini
unutmak demekti — ve unutulan ekran tam da yaşlı kullanıcının takılacağı
yer olurdu.

### Kalıcılık: cihaz-yerel, hesap düzeyinde değil

Tema tercihiyle **aynı depo ve aynı desen** (`ui.theme_mode` →
`ui.gorunum_modu`). Hesap düzeyine taşımak bir göç + uç + web paritesi
demekti; bedeli, kazançtan (aynı kişinin ikinci cihazında ayarı tekrar
açması) büyük.

**Takas açıkça kayıtlı:** kullanıcı tablet ve telefonda ayrı ayrı açmak
zorunda. Tema de bugün böyle davranıyor, yani tutarsızlık yok.

Bozuk depo değeri **standarda düşüyor**, hata atmıyor: Keystore sorunu
olan bir cihazda uygulama açılmalı.

### Kontrast testi gerçek bir kusur yakaladı

§4'te eklediğim durum rozeti Material'ın varsayılan
`Colors.green/red/blue/grey` tonlarını kullanıyordu. WCAG denetimi 12
puntoda **2.31** ölçtü — eşiğin (4.5) **yarısından az**. Yaşlı göz düşük
kontrastı zaten zor seçer; §2'nin amacı tam da buydu. Tonlar `shade900`'a
çekildi, zemin saydamlığı düşürüldü, test yeşillendi.

### Web paritesi — yapılmadı, gerekçesi

§2 mobil için istendi ("ana ekrandaki ızgara 8 öğeden 4 öğeye") ve web'de
karşılığı olan bir ızgara yok; web zaten tarayıcının kendi yakınlaştırma
ve yazı boyutu ayarlarını kullanıyor. **Web'e görünüm modu eklenmedi.**
