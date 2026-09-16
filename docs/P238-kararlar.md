# P238 — kararlar · Uygulama güncelleme uyarısı

## §0 ÖNCE ÖLÇÜM — bugün ne durumda

Kullanıcının beş sorusu, ölçülen yanıtlar:

| Soru | Yanıt | Kanıt |
|---|---|---|
| `/surum/kontrol` çalışıyor mu? | **Evet.** Pre-auth, platform+sürüm alır, `guncel`/`onerilen`/`zorunlu` döner | `backend/app/routers/surum.py:70` |
| Panelde ekran var mı, ne ayarlanıyor? | **Var:** "Uygulama sürümü" (`/surum-politikasi`, **yalnız platform admini**). Platform başına **asgari sürüm**, **önerilen sürüm**, **7 dilde mesaj** | `admin-web/app/(protected)/surum-politikasi/page.tsx`, `menu.ts:317`, `yuzey.ts:45` |
| Prod'da eşik ayarlı mı? | **ÖLÇEMEDİM** — bu makine dev; prod'a erişimim yok. **Dev'de İKİSİ DE BOŞ** (aşağıda) | `select * from surum_politikasi` |
| Mobilde uyarı nasıl görünüyor? | Zorunlu: **tam ekran, atlanamaz**. Önerilen: **üst şerit** (pop-up DEĞİL) | `surum_kapisi.dart` |
| "Güncelle" doğru mağazaya mı gidiyor? | **Evet.** Adres sunucudan, platforma göre: iOS → `app_store_url`, Android → `play_store_url`; ikisi de `settings`te dolu. Boşsa düğme gönderilmiyor, açılamazsa kullanıcıya söyleniyor | `surum.py:_magaza_url`, `config.py:166-169` |

### İSTENEN DAVRANIŞ — madde madde ne vardı, ne yoktu

| İstenen | Durum |
|---|---|
| Açılışta uyarı | **VARDI** (açılış + arka plandan dönüş, `SurumGozcusu`) |
| **POP-UP** | **YOKTU** — üst şeritti. **Bu turda yapıldı** |
| "Yeni sürüm var, lütfen güncelleyin" metni | **VARDI**, 7 dilde (`surumOnerilenBaslik`/`Metin`) |
| İki düğme | **VARDI** (Şimdi güncelle / Sonra) |
| Güncelle → doğru mağaza | **VARDI** |
| Daha sonra → makul süre sormasın | **VARDI** — 24 saat (`kOnerilenErteleme`) |
| Zorunlu ayrımı korunsun | **VARDI ve KORUNDU** |

Yani tek gerçek eksik **pop-up**tı. Geri kalanı P202'de yapılmış; yeniden
yazmadım.

### DEV'DE EŞİKLER BOŞ — bu ne demek

```
 platform | asgari_surum | onerilen_surum | mesaj
 ios      |              |                | {}
 android  |              |                | {}
```

Eşik boşken uç **her zaman `guncel`** döner: özellik sessizdir, hiçbir
uyarı çıkmaz. **Prod'da da boşsa bugüne kadar hiç uyarı gösterilmemiş
demektir** — prod loglarındaki `POST /surum/kontrol` satırları isteğin
gittiğini kanıtlar, politikanın dolu olduğunu değil.

Prod'da kontrol etmenin yolu: panel → **Uygulama sürümü**. Ya da:

```
curl -s -X POST https://api.yonetiyor.com/surum/kontrol \
  -H 'Content-Type: application/json' \
  -d '{"platform":"android","surum":"1.0.0"}'
```

`{"durum":"guncel"}` dönüyorsa eşik boştur. 1.4.0 yayınlandıktan sonra
**önerilen sürüm = 1.4.0** girilmeli; asgari ancak eski istemciler
gerçekten çalışmaz hale geldiğinde yükseltilmeli.

---

## §1 — Önerilen uyarısı: şerit → POP-UP

### Neden şerit yetmiyordu

Şerit içeriği aşağı itiyor ve bir süre sonra "arayüzün parçası" gibi
görünüyor; okunmadan yaşanıp gidiyor. Yani **önerilen seviye pratikte
hiçbir şey yapmıyordu**. Pop-up bir karar istiyor: iki düğmeden birine
basmadan geçilmiyor.

### Neden `showDialog` değil, elde çizilen katman

Kapı `MaterialApp.builder` içinde yaşıyor; orası **Navigator'ın üstü**
(Navigator builder'a `child` olarak geliyor). `showDialog` bir Navigator
**atası** ister ve orada yoktur. Rota olarak açmak ise zorunlu ekranın
bilerek kaçındığı şeyi geri getirirdi: derin bağlantı ve yönlendirme
rotaların üstünden atlayabilir.

Bu yüzden pop-up `Stack` + `ModalBarrier` + `Dialog` olarak elde
çiziliyor — zorunlu ekranla aynı yerde, aynı kurallarla.

### Perdeye dokunmak = "Daha sonra"

Kapatmayı tamamen engellemek (zorunlu ekranın kuralı) burada yanlış
olurdu: uyarı **önerilen**. Ama kapatmayı **erteleme saymamak** da yanlış
olurdu — perdeye dokunup geçen kullanıcıya bir sonraki açılışta aynı
pop-up çıkardı ve uyarı bir engele dönüşürdü.

### Metinler yeniden çevrilmedi

`surumOnerilenBaslik` ("Yeni sürüm var") ve `surumOnerilenMetin` ("Daha
iyi bir deneyim için uygulamayı güncelleyin.") zaten 7 dilde vardı ve
istenen anlamı taşıyor. Tek değişiklik: Türkçe **"Sonra" → "Daha sonra"**
(diğer altı dil zaten "Later / Plus tard / Más tarde" diyordu).

### Doğrulama — kullanıcının istediği dört ölçüm

| Ölçüm | Sonuç |
|---|---|
| Eski sürüm bildiren istemcide pop-up çıkıyor | ✔ |
| Güncel sürümde hiçbir şey çıkmıyor | ✔ (mevcut test) |
| "Daha sonra" çalışıyor, yeniden açılışta sormuyor | ✔ (mevcut test) |
| Zorunlu modda pop-up **görünmüyor**, tam ekran çıkıyor | ✔ (yeni test) |

`mobile/test/p202_zorunlu_guncelleme_test.dart` — **15 test** (4 yeni).

**KIRMA DENEMELERİ:**

| Kırma | Sonuç |
|---|---|
| `onDismiss` erteleme yapmasın | "PERDEYE DOKUNMAK…" **kırmızı** ✔ |
| Pop-up yerine yeniden şerit (`Column`) | **dört test birden kırmızı** ✔ |

**Bir testim zayıf çıktı ve düzelttim.** "İçeriği itmez" testi önce
"Daha sonra"dan önce/sonra konumu karşılaştırıyordu ve **şerit kırma
denemesinde de geçti** — çünkü şerit kapanınca içerik zaten yerine
oturuyor. Ölçülmesi gereken şey **pop-up açıkken** içeriğin nerede
durduğuydu; test ona çevrildi ve `surum-kapi-govde` anahtarı eklendi.
Bu kusur kırma denemesi yapılmasaydı fark edilmeyecekti.

---

## §2 — PUSH BİLDİRİMİ: değerlendirme ve ÖNERİ

**Bu bölümde kod yazılmadı.** Brief "değerlendir ve öner" diyor; aşağıda
öneri ve onu kuran ölçüm var. Onaylarsanız uygularım.

### ÖNERİM

| Seviye | Push | Gerekçe |
|---|---|---|
| **Önerilen** | **GÖNDERİLMESİN** | Uygulamayı açmayan kullanıcı için önerilen güncellemenin faydası yok — o kullanıcı zaten uygulamayı kullanmıyor. Bedeli yüksek: bildirim yorgunluğu, ve kullanıcı bildirimleri kapatırsa **görev, aidat, güvenlik** bildirimleri de kaybolur. Bir kolaylık için kritik kanalı riske atmak |
| **Zorunlu** | **GÖNDERİLSİN, eşik başına TEK KEZ** | Burada eski istemci **çalışmıyor**. Kullanıcı uygulamayı açtığında kilit ekranıyla karşılaşacak. Push o anı önceden haber verir: "açtım, çalışmıyor" hiç yaşanmaz |

**Kaç kez:** eşik değiştiğinde bir kez. Tekrar yok, günlük hatırlatma
yok. Ayrı bir "gönderildi" tablosu da gerekmiyor: PUT ucu eski ve yeni
asgari değeri zaten biliyor, sadece **değiştiğinde** gönderir; aynı
değeri yeniden kaydetmek push üretmez.

**Dokununca ne olsun:** uygulama açılır ve **zorunlu ekranı görür** —
o ekranda zaten mağaza düğmesi var. "Doğrudan mağazaya" götürmeyi
vaat etmiyorum: FCM bildirimine dokunmak uygulamayı açar, harici bir
adresi güvenilir biçimde açtırmaz.

### AMA — ÖNCE ŞU ÖLÇÜMÜ OKUYUN: bugün hedefleyemeyiz

Sürüme göre push göndermek için "kim eski sürümde" bilinmeli. **Bugün
bilinmiyor:**

- `user_device` tablosunda **uygulama sürümü kolonu yok** (fcm_token,
  platform, dil, cihaz_kimligi, aktif).
- `/surum/kontrol` sürümü **taşıyor** ama **pre-auth** — kimlik yok,
  cihazla eşleştirilemez (ve bu bilinçli: kırıcı bir API değişikliğinde
  eski istemci giriş bile yapamayabilir).

Kolonu eklemek kolay. **Asıl sorun şu:** bir cihaz sürümünü ancak
**o alanı gönderen bir yapımı çalıştırdığında** bildirir. Yani bugün
sahada olan 1.3.x istemciler sürümlerini **hiçbir zaman bildirmeyecek**
— tam da hedeflemek istediğimiz kitle görünmez kalır.

**Sonuç: bu özellik 1.4.0 için kimseye ulaşmaz.** Değeri 1.4.0'dan
*sonraki* sürümlerde başlar.

### KARAR VERİLDİ (kullanıcı, P238 §4)

**Push mantığı 1.5.0'a bırakıldı. Ama veri toplama BUGÜN başladı** —
gerekçesi aşağıdaki §4. Aşağıdaki iki seçenek kaydı, kararın nasıl
alındığını göstermek için duruyor.

### İKİ SEÇENEK (sunulan)

1. **Şimdi kurulumu yap** (`user_device.uygulama_surum` + istemci
   bildirimi + eşik değişiminde tek seferlik push). 1.4.0'da kimseye
   gitmez, 1.5.0'dan itibaren çalışır.
2. **Şimdi yapma.** Zorunlu güncelleme zaten uygulama açılınca
   kilitliyor; push yalnızca "daha erken haber" kazandırıyor.

**Benim tercihim (1)** — ama sizin onayınızla: kurulum küçük değil
(göç + istemci + tenant-ötesi SECURITY DEFINER sorgu + SQL'de semver
karşılaştırması + yeni bildirim tipi + 7 dil metin) ve karşılığı bir
sürüm gecikmeli.

### Malik/kiracı benzeri ayrım gerekmiyor

Sürüm bildirimi kişiye değil **cihaza** gider; rol ayrımı anlamsız.

---

## §3 — ÖLÇEMEDİKLERİM

- **Prod eşikleri** — prod'a erişimim yok. Yukarıdaki `curl` ile siz
  bakabilirsiniz.
- **Cihazda pop-up** — emülatör yok; pop-up widget testinde ölçüldü,
  gerçek telefonda görülmedi.
- **Mağaza düğmesinin gerçekten mağazayı açması** — `url_launcher`
  çağrısı testte taklit; cihazda sürülmedi.


---

## §4 — Veri toplama bugün başladı (push mantığı 1.5.0'da)

### Karar ve gerekçe

Push mantığı yazılmadı. Ama `user_device.uygulama_surum` **bugün**
açıldı ve istemci sürümünü göndermeye başladı.

Gerekçe kullanıcıdan ve doğru: bir cihaz sürümünü ancak **o alanı
gönderen bir yapımı çalıştırdığında** bildirir. Kolon bugün açılmazsa
1.5.0 geldiğinde **1.4.x istemciler de görünmez** olur ve aynı sorun bir
tur sonra tekrarlanır. Yani maliyet bugün küçük (göç + bir alan), bir
tur sonra ise aynı iş + bir sürüm daha kayıp.

**Bilinçli olarak YAPILMADI** (1.5.0'a kaldı): bildirim tipi,
tenant-ötesi SECURITY DEFINER sorgu, SQL'de semver karşılaştırması,
7 dil push metni, eşik değişiminde gönderim.

### Yapılanlar

| Katman | Değişiklik |
|---|---|
| Göç **0138** | `user_device.uygulama_surum text` — nullable, **indekssiz** |
| `models.py` | alan + neden bugün açıldığı |
| `DeviceRegister` | `uygulama_surum` (max 64, opsiyonel) |
| `DeviceOut` | alan döner — "bildirim gelmiyor" diyen cihazın sürümünü görmek için (`GET /devices` zaten admin-only) |
| `devices.py` | upsert'te `coalesce` — **gönderilmezse mevcut değer korunur** |
| `contracts/openapi.yaml` | iki şema |
| Mobil `DeviceApi` | `uygulamaSurum` parametresi; null ise anahtar **hiç gönderilmez** |
| Mobil `PushRegistrar` | `PackageInfo.fromPlatform().version`; **okunamazsa kayıt yine yapılır** |

### Üç karar, üç gerekçe

**1. İndeks eklenmedi.** Bu kolon bugün hiçbir sorguda süzgeç değil;
indeksi şimdi eklemek kullanılmayan bir yapıyı her INSERT/UPDATE'te
güncellemek olurdu. 1.5.0'da hedefleme sorgusu yazılınca ölçülür.

**2. Gönderilmezse mevcut değer KORUNUR** (`coalesce`, `cihaz_kimligi`
ile aynı kural). Uygulama her açılışta cihazı yeniden kaydeder; bir
yükseltmede alanın geçici olarak boş gelmesi öğrenilmiş sürümü
**silmemeli**. Silseydi cihaz "sürümü bilinmiyor"a düşer ve 1.5.0'daki
hedefleme onu elerdi.

**3. Sürüm okunamazsa kayıt yine yapılır.** Sürüm, bildirimin gitmesi
için gerekli değil; yalnız ileride hedefleme yapabilmek için toplanan
meta veri. Okunamadı diye cihaz kaydını atlamak, **çalışan** bir
özelliği (push) **henüz yazılmamış** bir özellik uğruna kırmak olurdu.

### KVKK

Uygulama sürümü kişisel veri değil; cihazın teknik meta verisi ve kayıt
zaten `platform`, `dil`, `cihaz_kimligi` taşıyor. Yeni rıza gerekmiyor;
saklama süresi cihaz kaydıyla aynı (cihaz silinince gider).

### Doğrulama

`backend/tests/test_p238_cihaz_surumu.py` — **5 test**:
sürüm kaydedilir ve okunur; **gönderilmezse korunur**; yeni sürüm
eskisini ezer; sürümsüz kayıt kabul edilir; 64'ten uzun sürüm **422**.

`mobile/test/push_registrar_test.dart` — kayıt gövdesinde sürümün
gerçekten gittiği ölçüldü. `PackageInfo` taklidi **setUp'a eklendi**:
kurulmasaydı `fromPlatform()` fırlatır, kayıt sürümsüz geçer ve
beklenti sessizce anlamsızlaşırdı.

| Kırma denemesi | Sonuç |
|---|---|
| İstemci `uygulamaSurum`u göndermesin | `push_registrar_test` **kırmızı** ✔ |
| Upsert'te `coalesce` kaldırıldı | "GÖNDERİLMEZSE KORUNUR" **kırmızı** ✔ |

### ÖLÇEMEDİĞİM

Gerçek cihazda `PackageInfo`'nun sürümü doğru okuduğu sürülmedi
(emülatör yok); testte taklit edildi. Paket içeriğinden de ölçülemez —
sürüm çalışma zamanında okunuyor.


---

## §5 — Yayın paketi 1.4.1+14

### Sürüm numarası

`1.4.0+13` üretildi ama **yayınlanmadı**; sonra güncelleme uyarısı
şeritten pop-up'a çevrildi. Aynı numarayı farklı içerikle ikinci kez
üretmek "hangi 13'ü test ettim" karışıklığı yaratırdı (P236 §2'de
verilen aynı karar). Bu yüzden **`1.4.1+14`**; sürüm notları da
yeniden adlandırıldı ve gerekçe paragrafı güncellendi.

Notların İÇERİĞİ değişmedi: pop-up, güncel sürümü kuran kullanıcının
görmediği bir değişiklik (yalnız bir sonraki güncellemede karşısına
çıkar); mağaza notuna koymak gürültü olurdu.

### P221 doğrulamaları

| Kontrol | APK | AAB |
|---|---|---|
| Paket / versionCode / versionName | `com.app.yonetiyor` / `14` / `1.4.1` | aynı (manifest protobuf) |
| Gömülü adres | `https://api.yonetio.site`, emülatör adresi yok | aynı |
| İmza | upload anahtarı, SHA-256 `dd1f5964…20f5` | `META-INF/UPLOAD.*` |
| Sesler / ikon | 3/3, `ic_launcher` var | 3/3 |
| Boyut | 75.4 MB | 72.4 MB |

### Değişiklikler pakette mi — ölçüldü

`lib/arm64-v8a/libapp.so` içinde: `surum-onerilen-popup`,
`surum-kapi-govde`, `Daha sonra`, `uygulama_surum` — **hepsi var**.

**APK boyutu bir önceki yapımla BİREBİR AYNI çıktı** (75 366 635 bayt)
ve bu beni şüphelendirdi. Ölçtüm: `versionCode` 14, pop-up anahtarları
ve yeni `Daha sonra` dizesi pakette. Yani yapım yeni; boyut eşitliği
rastlantı (değişen dizelerin uzunlukları denk geldi, AOT çıktısı
hizalanıyor).

### DART DİZE SAKLAMA — P237'deki notumu düzelttim

P237 §5'te "saf ASCII dizeler tek baytlı saklanır" yazmıştım. Kural
bundan **geniş** ve o hâliyle yanlış sonda üretiyor:

| Kod birimleri | Saklama | Örnek |
|---|---|---|
| Hepsi < 256 | **Latin-1, tek bayt** | `Yeni sürüm var` (`ü` = 252) |
| Herhangi biri ≥ 256 | **UTF-16LE** | `Alt adımlar` (`ı` = 305) |

`Yeni sürüm var` ne UTF-8'de ne UTF-16'da bulunur — **Latin-1'de**
bulunur. Paket içeriği sondalanırken **üç kodlama da** denenmeli; tek
kodlamayla arayan bir sonda sahte "YOK" raporlar. P237 kararlarına da
düzeltme notu eklendi.

### ÖLÇEMEDİĞİM

Cihazda kurulum ve duman testi yapılmadı (emülatör yok) — APK'yı
yükleyip test etmek sizde. `.ipa` bu makinede üretilemez.
