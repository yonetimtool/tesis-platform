# iOS TEŞHİS TURU — kamera yayını + NFC (P119)

**Bu belge tek bir koşum içindir.** İki iOS hatası (kamera açılmıyor, NFC
"Missing required entitlement") üst üste iki tur **körlemesine** düzeltilmeye
çalışıldı ve ikisi de cihazda düşmeye devam etti. Bu turda ürün koduna
teşhis eklendi; amaç, **tek bir `flutter run` çıktısının** iki soruyu da
kapatmasıdır.

---

## 0) Koşum

```bash
cd mobile
flutter run --release \
  --dart-define=API_BASE_URL=https://api.yonetio.site \
  -d <iphone-udid>
```

`--release` **bilinçli**: Kerem'in gördüğü hata TestFlight'ta, yani bir
yayın yapımında. Teşhis kayıtları `debugPrint` iledir ve yayın yapımında da
yazar — hata ayıklama yapımı, ölçmek istediğimiz yapımdan farklı davranabilir.
(Konsol yerine cihazdan bakılacaksa: Xcode → Window → Devices and Simulators
→ Open Console; süzgeç `Yonetio`.)

`--dart-define` verilmezse uygulama Android emülatörü adresine bağlanmaya
çalışır ve **hiçbir ekran veri göstermez** (bkz. ios-build-runbook.md).

---

## 1) Açılışta gelen blok — ilk 10 satır

Uygulama açılır açılmaz şu blok yazılır. **Aynen kopyalanacak yer burası:**

```
[TESHIS] === PAKET GERCEKLERI (calisan yapim) ===
[TESHIS] paket      : site.yonetio.app 1.0.0(3)
[TESHIS] ats.sozluk : true
[TESHIS] ats.medya  : true
[TESHIS] ats.keyfi  : YOK
[TESHIS] nfc.aciklama: true
[TESHIS] nfc.aid    : D2760000850101,D2760000850100
[TESHIS] nfc.felica : YOK
[TESHIS] === /PAKET GERCEKLERI ===
```

Bu blok **çalışan paketin kendi `Info.plist`ini** okur — depodaki dosyayı
değil. "Kaynak doğru ama pakete girdi mi?" sorusunun tek kesin cevabı budur
(`GENERATE_INFOPLIST_FILE`, yanlış `INFOPLIST_FILE`, hedef karışması,
eski bir TestFlight yapımı… hepsi buradan görülür).

**Nasıl okunur:**

| Satır | Beklenen | Değilse ne demek |
|---|---|---|
| `ats.medya` | `true` | **ATS anahtarı pakete girmemiş** → kamera hatasının sebebi budur; `Info.plist` hedefe bağlanmamış demektir. |
| `nfc.aid` | iki AID | AID listesi pakete girmemiş → ISO7816 bağlanması reddedilir. |
| `nfc.felica` | `YOK` | Doğru. `.iso18092` tarama seçeneğini kaldırdık; beyan da gerekmiyor. |
| `[TESHIS] kanal YOK` | görünmemeli | Görünüyorsa yapım **eski**; TestFlight'tan değil bu koddan derleyin. |

---

## 2) KAMERA — teşhis öncelikli, kök neden HENÜZ YOK

Bu tarafta doğrulanmış bir kök neden **yoktur**; hipotezler aşağıda
sıralı. Kerem'in yapacağı tek şey **bir kamerayı açmak** ve çıkan dört
satırı kopyalamak.

### Adım
Ana ekran → **Kameralar** → herhangi bir kamera kartına dokun.

### Beklenen kayıtlar
```
[YAYIN] kamera="Ana Kapı" tur=hls oynatilabilir=true
[YAYIN] stream   = https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8
[YAYIN] restream = YOK
[YAYIN] SECILEN  = https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8
[YAYIN] initialize() basladi
[YAYIN] HAZIR 842ms boyut=Size(1280.0, 720.0)
```

Adresler **maskelenir**: `rtsp://kullanici:parola@…` → `rtsp://***@…`, sorgu
dizesi `+sorgu(41)` olur. Günlüğü olduğu gibi yapıştırmak güvenlidir.

### Hipotezler — olasılık sırasına göre, her biri hangi satırla düşer

**H1 — İki platform AYNI kaydı oynatmıyor (en olası).**
Android karşılaştırması dev sunucusunda tohumlanmış **genel HLS test
yayınlarıyla** yapıldıysa, iOS ise **prod**'daki gerçek tesise bakıyorsa
ortada bir iOS hatası yoktur: sahadaki kamera ya `rtsp://` (AVPlayer bunu
**hiç** oynatamaz, ExoPlayer oynatabilir) ya da telefonun mobil veriden
erişemediği bir **yerel ağ adresi**dir (`http://192.168.…`).
*Tohumlanan demo tesisinde kamera **hiç yoktur** — `demo_tenant.py` kamera
yazmaz. Yani prod'da görülen kameralar Kerem'in kendi tesisine aittir.*
→ **`SECILEN` satırı bunu tek başına kapatır.** `tur=rtsp` ya da özel bir IP
görünüyorsa hata burada biter.

**H2 — ATS anahtarı pakete girmemiş.**
Kaynakta `NSAllowsArbitraryLoadsForMedia` var (test kilitli), ama pakete
girdiği hiç ölçülmedi. → **`ats.medya` satırı** kapatır.

**H3 — Hazırlık SONRASI reddedilen varyant/kodek.**
AVPlayer ana listeyi yükleyip "hazır" olur, sonra varyantı reddeder;
`initialize()`in Future'ına **hiç yansımaz**. Kod bunu zaten yakalıyor ama
ham metin yayın yapımında ekranda gizli.
→ **`HAZIRLIK SONRASI HATA -> …` satırı** kapatır.

**H4 — 15 sn'de yanıt yok.**
→ `DUSTU 15003ms -> TimeoutException…`. Bu, adresin cihazdan **erişilemez**
olduğu anlamına gelir (H1'in kardeşi).

**H5 — `video_player`/iOS 26 gerilemesi.** En düşük olasılık; bu belirtiyi
bildiren güncel bir kayıt bulunamadı. Yalnız H1–H4'ün hepsi elenirse
gündeme gelir; ayırt edici işaret `HAZIR … boyut=Size(0.0, 0.0)`
(ses var, görüntü yok).

---

## 3) NFC — kök neden BULUNDU, düzeltme bu yapımda

### Bulgu
Hata bir yetkilendirme eksikliği **değildi**. Kerem'in kanıtları doğruydu:
imzada ve gömülü profilde NDEF/TAG vardı, portalda yetenek açıktı. Eksik
olan şey `Info.plist`teki bir **beyandı**.

Okuma oturumu `.iso18092` (FeliCa) tarama seçeneğiyle açılıyordu. CoreNFC,
`.iso18092` isteyen bir `NFCTagReaderSession`ı ancak uygulama
`com.apple.developer.nfc.readersession.felica.systemcodes` altında
okuyacağı sistem kodlarını beyan etmişse açar. Beyan yoksa oturumu
`begin()` anında **NFCError code 2 — "Missing required entitlement"** ile
geçersiz kılar. Mesaj yanıltıcıdır; kırmızı ışık yetkilendirmeyi gösterir,
sorun beyandadır.

Aynı belirtiyi **birebir aynı üç seçenekle** bildiren iki forum kaydı:
* `developer.apple.com/forums/thread/811220` — iPhone 15 / iOS 26.2,
  bizimkiyle neredeyse aynı yapılandırma (TAG, aynı AID, aynı üç seçenek).
  "Resolved" işaretlenmiş ama çözüm yazılmamış.
* `developer.apple.com/forums/thread/735183` — bildiren kişi:
  "`.iso18092`yi çıkarınca her şey çalıştı."

### Düzeltme
`.iso18092` **kaldırıldı** (`pollingSecenekleri`). FeliCa sistem kodu
**beyan edilmedi**: FeliCa Japonya'ya özgü ulaşım/e-para kart ailesidir,
bizim etiketimiz NTAG424 DNA (ISO 14443 Type A). Kullanmadığımız bir sistem
kodunu beyan etmek, denetimde savunamayacağımız gerçek dışı bir beyan
olurdu — AID listesinde de aynı ilke uygulanmıştı.

Yetkilendirme dosyasına **dokunulmadı** (TAG-only kaldı): Build 2 NDEF+TAG
ile imzalanmıştı ve **yine düştü**, yani NDEF bu hatanın değişkeni değil.
Kanıtla elenmiş bir değişkeni kurcalamak, bu turda bırakılan alışkanlığın
ta kendisi olurdu.

### İkinci düzeltme — hata ARTIK DOĞRU ADLANDIRILIYOR
Eklenti oturum hatasının **kodunu** veriyordu (`NfcReaderErrorCodeIos`);
bizim kod yalnız `message`i alıp her geçersizleştirmeyi `okumaIptal`
sayıyordu. Cihazda "Missing required entitlement" ekrana **"Okuma iptal
edildi: Missing required entitlement"** diye çıktı — iptal "tekrar deneyin"
demektir, oysa yapım düzelmeden hiçbir deneme tutmaz. İki tur tam bu yüzden
yanlış yerde arandı. Artık kod sınıflandırılıyor ve yapılandırma hataları
ayrı bir kimliğe (`yapilandirmaEksik`, 7 dilde) düşüyor.

### Adım
Güvenlik hesabıyla gir → **Tur / Kontrol Noktaları** → **NFC okut** →
etiketi telefonun arkasına yaklaştır.

### Beklenen kayıtlar
```
[NFC] startSession — iso14443,iso15693
```
ve okuma başarılıysa başka satır **gelmez**.

Hâlâ düşüyorsa **tek önemli satır** budur:
```
[NFC] gecersiz kilindi — kod=<KOD> mesaj="<METIN>"
```

| `kod` | Ne demek |
|---|---|
| `readerErrorSecurityViolation` | Hâlâ beyan/yetkilendirme. Bu kez **`nfc.aid` ve `ats` satırlarıyla birlikte** gönderin — kalan tek şüpheli AID listesinin pakete girip girmediğidir. |
| `readerSessionInvalidationErrorUserCanceled` | Sistem sayfası kapatıldı — hata değil. |
| `readerSessionInvalidationErrorSessionTimeout` | ~60 sn etiket görülmedi. |
| `readerErrorRadioDisabled` | Cihazda NFC kapalı. |
| `readerTransceiveError…` | Oturum açıldı, **etiketle konuşurken** düştü — bu artık bambaşka (ve çok daha iyi) bir hata; etiket çekilmiş ya da SDM okunamamıştır. |

---

## 4) Kerem tek koşumda neyi yapıştırsın

1. Açılıştaki `=== PAKET GERCEKLERI ===` bloğunun tamamı.
2. Bir kamera açıp çıkan tüm `[YAYIN]` satırları (hata ekranı çıkana kadar
   bekleyin — en fazla 15 sn).
3. Bir NFC okutma denemesinden çıkan tüm `[NFC]` satırları.

Bu üçü, yukarıdaki tabloların hepsini doldurmaya yeter.
