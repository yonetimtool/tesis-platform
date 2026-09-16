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

### KARAR SİZE AİT — iki seçenek

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
