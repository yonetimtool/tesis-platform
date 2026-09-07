# F6-ek — Mobil bildirim ekranı + FCM kaydı: kararlar

> Bu ek fazın tek görevi vardı: **bildirimi işe yarar hâle getirmek.**
> F6'da bildirim *altyapısı* (satır + push + `hedef_yol`) yazılmıştı ama
> iki istemcide de okunacak ekran yoktu ve mobil hiçbir cihaz jetonu
> kaydetmiyordu. Yani `dukkan.bildirim` tablosuna yazılan her satır,
> hiç kimsenin göremediği bir kayıttı.

---

## 1. Kanal kararı: **yeni kanal** (`yonetio_dukkan_v1`)

**Soru:** Dukkan bildirimleri mevcut `yonetio_bildirim` sesli kanaldan mı
gitsin, yeni kanal mı açılsın?

**Karar: yeni kanal, tek tane.**

`push_kanal.py` boyunca tekrarlanan bir kural var ve haklı:
*"nadir bir olay için kullanıcının sistem ayarlarına bir satır daha
eklemek, o ekranı okunmaz yapmaya doğru giden yoldur."* P208'de gürültü,
P210'da vardiya için bu kural bilerek **esnetildi**, çünkü onlarda ayrışan
şey **sesti**.

Burada ayrışan şey ses değil, **ürün**:

- Android'de bildirim kapatma **kanal başınadır**. Dukkan bildirimleri
  `yonetio_genel_v2`den gitseydi, pazar yeri pinglerinden bunalan bir
  sakin **sitesinin duyurularını da** susturmak zorunda kalırdı.
- Tersi de doğru: iş bekleyen bir usta tesis duyurularını kapatıp
  tekliflerini açık tutabilmeli.

**Neden tek kanal, olay başına değil:** "teklif geldi", "iş verildi",
"işletmen onaylandı" ayrı kanallar olsaydı ayar ekranı okunmaz olurdu —
yani modülün kendi kuralı. Dukkan'ın tamamı **bir satır**.

**Ses: sistem sesi (`default`), `yonetio_bildirim` değil.**
`yonetio_bildirim` Yönetiyor'un **kimlik sesidir** ve "binanla ilgili bir
şey oldu" der. Bir teklif bildirimi önemlidir ama o değildir; aynı sesi
vermek, sesin tek işini (bakmadan ne olduğunu anlatmak) bozardı. Ayrıca
özel ses **yeni sürüm yayını** ister; sistem sesiyle başlamak bu fazı bir
ses dosyasına bağımlı kılmıyor. Özel ses eklenirse kanal `_v2` olarak
**yeniden açılmalı** (Android'de var olan kanalın sesi programla
değiştirilemez — P208).

### Kanal seçimi **önekten** türetiliyor, listeden değil

```python
DUKKAN_ONEK = "dukkan_"
if tip and tip.startswith(DUKKAN_ONEK):
    return KANAL_DUKKAN
```

Elle tutulan bir liste olsaydı, F7'de eklenecek bir tip **sessizce**
Yönetiyor kanalına düşerdi — ve kullanıcı pazar yeri bildirimlerini
kapattığını sanıp almaya devam ederdi. Kilit:
`test_ONEK_ESLEMESI_LISTEDEN_BAGIMSIZ` (henüz var olmayan bir tiple
ölçüyor).

### Yan etki: bildirim tipleri yeniden adlandırıldı

`teklif_geldi` → `dukkan_teklif_geldi` (yedisi de). İki sebep:

1. Önek, kanalı seçen kuraldır; öneksiz tip **doğru çalışıyor gibi
   görünür** ama yanlış kanaldan gider.
2. **`yeni_talep` Yönetiyor'da zaten vardı** ve `KRITIK_TIPLER` içinde.
   Öneksiz bırakmak iki ürünün tipini çakıştırırdı: bir Dukkan talebi,
   yöneticinin telefonunda **site şikâyeti sesiyle** çalardı.

Kilit: `test_TUM_DUKKAN_TIPLERI_ONEKLI` + `test_ONEK_CAKISMASI_YOK`
(Yönetiyor'un hiçbir tipi `dukkan_` ile başlamıyor).

---

## 2. Ayrı kapatma: **evet, ayrı** (göç 0121)

**Soru:** Kullanıcı Dukkan bildirimlerini ayrı kapatabilmeli mi, yoksa
Yönetiyor'un `bildirim_mobil` ayarından mı yönetilsin?

**Karar: ayrı — `dukkan_kullanici.bildirim_acik` + `bildirim_sesli`.**

İki sebep, ikisi de belirleyici:

1. **Dukkan kullanıcısının Yönetiyor hesabı olmayabilir.** Telefonla
   kaydolmuş bağımsız kullanıcının `app_user` satırı yoktur; tercihini
   orada tutmak **imkânsız** — `dukkan_app` rolü o tabloya zaten
   erişemiyor (göç 0113).
2. **İki ürünün bildirimleri farklı şeyler** (§1'deki gerekçe).

**Varsayılan açık, bilinçli:** bildirim bir **tercihtir**, rıza değil
(pazarlama rızasından farkı bu; Yönetiyor'da `bildirim_mobil` için aynı
ayrım yazılı). Talep/teklif akışının kalbi bildirim: kapalı başlasaydı,
ilk teklifini göremeyen kullanıcı pazar yerinin çalışmadığını düşünürdü.

**`bildirim_sesli` ayrı bir soru:** "gelsin mi" değil "**sesli mi**
gelsin". Tek anahtara bağlamak, "gece çalıyor" diyen kullanıcıya
bildirimin **tamamını** kapattırırdı (P207'de birebir bu karar verildi).

**Kapalı tercih push'u susturur, satırı silmez.** `bildir()` içinde sıra
kasıtlı: satır **önce** yazılır, tercihe **sonra** bakılır. Kullanıcı push
istemiyor olabilir ama olayı kaybetmeyi istemez. Kilit:
`test_TERCIH_KAPALIYSA_PUSH_YOK_AMA_SATIR_VAR` — kırılarak doğrulandı
(satır silinecek şekilde bozuldu, test kırmızı yandı).

---

## 3. Yönlendirme: hedef **tipten** çevriliyor, sunucunun yolundan değil

**P211'de yönetici erişemediği ekrana gidiyordu.** Aynı hataya düşmemek
için iki karar:

**(a) Sunucunun `hedef_yol`u mobilde doğrudan kullanılmıyor.** O yol
**web** yoludur (`/panel/{isletme_id}`, `/taleplerim/{talep_id}`) ve
mobilde o yollar yok. `context.go(hedef_yol)` demek, P211'in birebir
tekrarı olurdu. Çeviri `tip` üzerinden yapılıyor; sunucu yarın web
yolunu değiştirse mobil kırılmaz.

**(b) Dukkan dalı Yönetiyor'un rol süzgecinden ÖNCE.** Yönetiyor'un
haritası hedefi rolün **menüsünden** türetilen bir kümeyle doğruluyor.
Dukkan ekranları menüde değil (tek `yerelIsletmeler` kartı var), o yüzden
süzgeçten geçselerdi **hepsi `null` dönerdi** — yani bütün Dukkan
bildirimleri dokunulamaz olurdu. Süzgeç burada güvenlik sağlamaz,
yalnızca yanlış ölçerdi.

Bu bir **yetki gevşemesi değil, başka bir kapıya devir**: Dukkan'ın rolü
yoktur, yetki **Dukkan jetonundan** gelir ve hedef ekranların hepsi jetonu
kendisi ister; sunucu her uçta `_sahiplik_dogrula` çalıştırıyor.

Kilit dosyası `mobile/test/dukkan_bildirim_yonlendirme_test.dart` üç şeyi
birden ölçüyor: (1) sunucudaki her tipin mobil karşılığı var mı,
(2) üretilen her hedef **router'da tanımlı mı**, (3) Dukkan hedefleri rol
süzgecine takılmıyor mu. İkisi de kırılarak doğrulandı.

---

## 4. Ölçüm sırasında bulunan üç kusur

Bunlar bu fazın planında yoktu; bildirimi bağlarken **ortaya çıktılar**.

### 4.1 Ölü bağlantı: mobilde gelen teklifler görülemiyordu

F4'te `dukkan_taleplerim_screen.dart` her karta
`context.push('/dukkan/taleplerim/{id}')` koymuştu ama **o rota router'a
hiç eklenmemişti**. Karta dokunmak go_router'ın hata ekranını açıyordu.
Yani mobilde bir kullanıcı **gelen teklifini göremiyordu** — pazar
yerinin talep tarafı yarım kalmış.

Metin anahtarları (`dukkanTeklifler`, `dukkanIsiVer`, `dukkanTeklifYok`…)
F4'te **yedi dile zaten eklenmişti**; kullanan yer yoktu. Sözlük doğru,
ekran eksikti.

**Düzeltildi:** `dukkan_talep_detay_screen.dart` + rota. Kilit: yönlendirme
testinin "üretilen her hedef router'da tanımlı" maddesi bu sınıfın
tekrarını imkânsız kılıyor.

### 4.2 Çıkışta Dukkan jetonu temizlenmiyordu (**oturum sızıntısı**)

`DukkanOturum._jeton` **bellekte** tutuluyor ve `temizle()` **hiçbir
yerden çağrılmıyordu**. Aynı telefonda ikinci bir kullanıcı giriş
yapınca jeton hâlâ öncekinindi: yeni kullanıcı "Taleplerim"i açınca
**öncekinin taleplerini görürdü**.

Yönetiyor jetonunun geçersizleşmesi Dukkan jetonunu geçersiz **kılmaz**
(ayrı imza, ayrı ömür, 30 gün) — bu yüzden ayrıca temizlenmesi zorunlu.

**Düzeltildi:** `AuthController.logout()` ve `onSessionExpired()` ikisi de
`temizle()` çağırıyor; `temizle()` ayrıca cihaz kaydını **sunucudan da**
düşürüyor (yoksa telefondaki sonraki kişi öncekinin teklif bildirimlerini
alırdı).

### 4.3 `bildir()` kanal/ses **göndermiyordu**

F6'daki `get_push_provider().send(...)` çağrısında `kanal=`/`ses=` hiç
yoktu. Bildirimler Android'in **isimsiz varsayılan kanalına** düşerdi —
P207'de ölçülen kusurun aynısı. Kilit:
`test_BILDIR_KANALI_VE_SESI_SAGLAYICIYA_VERIYOR`, taklit **sağlayıcı
sınırına** konarak (P200 dersi: repo düzeyinde taklit tam da kırılan
katmanı atlardı).

---

## 5. FCM kaydı **ne zaman** yapılıyor

**Girişte değil — Dukkan jetonu alındığı an.**

En kolay yol, Yönetiyor girişinden sonra köprüyü çağırıp cihazı
kaydetmekti. Yapılmadı: köprü çağrısı Dukkan'da **kullanıcı oluşturur**.
Pazar yerini hiç açmamış binlerce kişi için hesap açmak olurdu — KVKK
açısından savunulamaz (kişi o ürüne kaydolmadı) ve "kayıtlı kullanıcı"
sayısını anlamsız şişirirdi.

Kayıt, kullanıcı Dukkan'ın kimlik isteyen bir yüzeyini **kendisi
açtığında** yapılır. O noktada hesap zaten oluşuyor; cihazı eklemek ek
bir şey açmıyor.

Hata **yutuluyor ama sessiz değil** (`debugPrint`): P191'de ölçülen tuzak,
bildirimin gitmemesi **ve hiçbir yerde yazmamasıydı**.

---

## 6. Mobil eşlik: panel **uyarlandı**, kopyalanmadı

Web panelinde altı iş var: profil düzenleme, hizmet alanı seçimi, belge
yükleme, telefon doğrulama, yorum daveti, gelen talepler.

Mobilde **yalnızca sonuncusu + durum** var. Gerekçe: ilk beşi masa başı,
tek seferlik kurulum işleri; gelen talebe teklif vermek ise **sahada,
dakikalar içinde** yapılması gereken iş. Mobilin kazandırdığı şey o.

Eksik olanlar **sessizce atlanmıyor**: ekranın altında "profil, hizmet
alanı, belge ve değerlendirme daveti dukkan.yonetiyor.com'da yapılır"
satırı var. Kullanıcının aramasına yol açmak, eksiği söylememekten kötüdür.

**Ana ekrana yeni kart eklenmedi.** "Yerel işletmeler" tek kart olarak
duruyor; taleplerim / panel / bildirimler o ekranın başlık çubuğundan
açılıyor. Üç kart daha eklemek, pazar yerini hiç kullanmayan çoğunluğa üç
ölü kutu göstermek olurdu (ana ekran zaten yoğun — P184'te küçültme
çalışması yapıldı).

---

## 7. Web tarafı da eksikti — kapatıldı

Aynı boşluk **web'de de** vardı: `bildirim` ve `cihaz` BFF vekilleri F6'da
yazılmış ama `dukkan-web`'de bildirim sayfası **yoktu**. `/bildirimler`
sayfası eklendi (liste + tercih anahtarları), `/panel` ve `/taleplerim`
başlıklarından bağlandı. BFF sözleşme kapısı yeni `bildirim-tercihi`
vekilini yakaladı ve `openapi.yaml`a eklenmesini zorladı — **dördüncü
kez** işe yaradı.

**Web push yok ve bu bilinçli:** service worker altyapısı kurulmadı. Web
kullanıcısı bildirimi sayfayı açtığında görür. `cihaz` ucu duruyor;
gerekirse F7'de bağlanır.

---

## 8. Ölçemediklerim

1. **Gerçek push teslimi hâlâ ölçülmedi.** Dev'de `PUSH_PROVIDER=noop`.
   Ölçülen şey, `bildir()`in sağlayıcıya **doğru kanal ve sesi verdiği**;
   Android'in o kanalı gerçekten çalıp çalmadığı değil. Prod ölçümü
   `F6-ek-dagitim.md` §4'te.
2. **Kanalın cihazda görünümü.** `yonetio_dukkan_v1` ilk kez bu sürümde
   oluşturuluyor; sistem ayarlarında "Yerel işletmeler" satırının
   göründüğü **emülatör olmadığı için** doğrulanamadı.
3. **Bildirime dokunup ekrana varış.** Yönlendirme haritası ve rotaların
   varlığı testle ölçüldü; gerçek bir cihazda tepsiden dokunma
   sürülmedi.
4. **Eski cihaz jetonları.** Bu sürümden önce Dukkan'a hiç cihaz
   kaydedilmediği için geçmiş yok — ama `dukkan_cihaz` için **retention
   yok** (F6-dagitim §8'deki açık madde duruyor).
