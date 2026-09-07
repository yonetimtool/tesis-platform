# F7 — Kota düzeltmesi + mobil telefon-OTP: kararlar

> `ONCELIK.md`'deki **ürünü engelleyen iki madde**. SMS başlığı onayı
> beklenmeden yapıldı: ikisi de başlık gelene kadar *tam olarak*
> sürülemez, ama başlık geldiği gün **tek satır `SMS_BASLIK=`** ile
> çalışır hâle gelir. Kod değişmez.

---

## §1 — Başarısız SMS kotayı yemesin (göç 0122)

### Ölçülen kusur

Davet kotası `3 + 2×etkinlik` (30 günlük pencere). `kullanilan` sayacı
`yorum_daveti` satırlarının **hepsini** sayıyordu — SMS gitmiş mi
gitmemiş mi bakmadan.

Bugün prod'da onaylı SMS başlığı **yok**; her davet `baslik_yok` ile
başarısız oluyor. Yani başlığın onaylandığı gün, ilk işletmeler
kotalarını **hiç SMS gitmeden** tüketmiş olacaktı — ve bunu ancak işletme
"neden gönderemiyorum" diye şikâyet edince fark edecektik.

### Aynı dertten muzdarip **ikinci** sayaç

Ölçüm sırasında çıktı: "aynı numaraya 90 günde bir davet" kuralı da tüm
satırları sayıyordu. Gönderilemeyen bir davet, o numarayı **üç ay
boyunca** kilitliyordu — müşteri hiçbir şey almamışken işletme tekrar
deneyemiyordu. Bu, kotadan daha sinsi: kota en azından görünüyor.

### Karar: göç 0116'nın kalıbı birebir kopyalandı

`yorum_daveti`'ye `gonderim_durumu` + `gonderim_hatasi` + `saglayici`,
ve `WHERE gonderim_durumu = 'gonderildi'` kısmi indeksi. Değerler
`telefon_dogrulama` ile **birebir aynı** — kalıbı ikinci kez *yazmak*
yerine kopyalamak, iki sayacın ileride ayrışma ihtimalini de ortadan
kaldırıyor.

Başarısız deneme kayıtta **durur** (teşhis için) ama kotayı yemez.

### Geçmiş satırların varsayılanı: `saglayici_yok`

Mevcut davetlerin gerçekte gönderilip gönderilmediği **bilinmiyor**
(kayıt tutulmuyordu). Varsayılanı `gonderildi` yapmak, gitmemiş davetleri
gitmiş **saymak** olurdu — yani düzeltmenin tam tersi. `saglayici_yok`
seçildi çünkü bugüne kadar onaylı başlık hiç olmadı: elimizdeki en doğru
tahmin. Yan etkisi de doğru yönde — işletmeler başlığın geldiği gün tam
kotayla başlıyor.

### Sıra değişti: **önce gönder, sonra yaz**

Önce yazıp sonra `UPDATE` etmek de olurdu. Tek `INSERT` seçildi çünkü
UPDATE unutulduğunda kayıt sessizce `saglayici_yok` kalır ve kotayı
yemez — yani **hatanın yönü yanlış** olurdu (herkese sınırsız davet).
Tek yazımda böyle bir ara durum yok. `kimlik.kod_gonder_ve_kaydet` zaten
bu sırada çalışıyordu.

Kırma testi bunu doğruladı: durum sütunu yazılmayınca **dört** test
kırmızı yandı, ikisi kotanın var olan kilitleriydi.

### Yanıttaki `kalan` da düzeltildi

Gönderilmediyse kota düşmüyor. Yanıtta düşürüp veritabanında
düşürmemek, arayüzü sunucuyla **çeliştirirdi** — ve işletme "kotam bitti"
sanıp denemeyi bırakırdı.

---

## §2 — Mobil telefon-OTP: %27'lik duvar

### Neden engelleyiciydi

Ölçüldü: Yönetiyor'daki 3104 kullanıcının **837'sinde (%27) telefon yok.**
SSO köprüsü onlara 409 `telefon_gerekli` dönüyor — çünkü Dukkan kimliği
telefona çapalı (`dukkan_kullanici.telefon` UNIQUE) ve köprü **salt
okunur**: Yönetiyor'a telefon **yazamaz** (sınır AST testiyle kilitli).

F4–F6 boyunca bu dal "dukkan.yonetiyor.com'a gidin" diyordu. Her dört
kullanıcıdan biri akışın ortasında tarayıcıya gönderiliyor, pratikte
orada kayboluyordu. Onlar için mobil Dukkan **arama ekranından
ibaretti**: talep açamıyor, teklif göremiyor, panele giremiyorlardı.

### Karar: OTP ekranı, köprünün 409 dalına bağlı

Backend uçları **zaten vardı** ve web'de çalışıyordu
(`/dukkan/auth/telefon/kod`, `/dogrula`). Yazılan şey mobil yüzey.

**Yönetiyor'a telefon yazılmıyor.** Bu kasıtlı ve bir sınır kararı:
Dukkan'ın Yönetiyor'a yazması, projenin ilk gününde konan kısıtın ihlali
olurdu. Bedeli: OTP ile açılan hesapta `dukkan_yonetiyor_bag` satırı
**yok**. Aynı kişi web'de SSO ile girerse, telefonu **aynıysa** aynı
Dukkan hesabına düşer (telefon UNIQUE); Yönetiyor'da telefonu hiç
olmadığı için pratikte bu durum zaten oluşmaz.

### Jeton artık **cihazda kalıyor** — ve bu zorunluydu

F7'ye kadar Dukkan jetonu yalnız bellekteydi ve her açılışta köprüden
alınıyordu. Telefonu olmayan kullanıcı için köprü **her seferinde**
409 döner: jeton bellekte kalsaydı, OTP ile giren kullanıcı ertesi gün
**yeniden OTP** yapardı — yani her açılışta bir SMS. Akış kullanılamazdı.

Sıra da değişti: **önce cihazdaki jeton, sonra köprü.** Köprü önce
denenseydi, aynı kullanıcı yine 409 alır ve tekrar OTP'ye sokulurdu.

### Saklamanın açtığı sızıntı — ve kapatılması

"Jetonu sakla" demek tek başına bir sızıntı açıyor: A çıkış yapmadan
uygulamayı öldürür, aynı telefonda B giriş yapar, B **A'nın pazar yeri
kimliğiyle** içeri girer. F6-ek'te bellekte olan aynı kusurun kalıcı
hâli.

Bu yüzden jeton, alındığı andaki **Yönetiyor kullanıcı kimliğiyle
birlikte** saklanıyor (`sub`, access token'dan okunuyor) ve okuma o kimlik
eşleşmezse `null` dönüyor — ayrıca kayıt **siliniyor**: cihazda
başkasının jetonunun durması, okunamıyor olsa bile gereksiz bir risk.

Çıkışta silmek de yapılıyor, ama tek başına yetmez: çıkış yapılmadan
öldürülen uygulama o yolu hiç çalıştırmaz. Kilit
`dukkan_otp_jeton_deposu_test.dart`, kırılarak doğrulandı.

**Kullanıcı kimliği neden `AuthState`'ten değil jetondan okunuyor:**
`AuthState` kullanıcı kimliği taşımıyor, ve `authControllerProvider`ı
depodan okumak iki yönlü bir provider bağı kurardı (`AuthController`
zaten `DukkanOturum`u okuyor).

### Süresi dolmuş jeton yok sayılıyor

30 günlük jetonun süresi dolmuşsa döndürmek, kullanıcıyı her ekranda 401
alan bir akışa sokardı. `exp` istemcide **yalnızca bu amaçla** okunuyor —
yetki kararı değil, "boşuna deneme" kararı.

### Kimliksiz uçlar: interceptor'a küçük bir ekleme

OTP uçları jeton **üretir**, jeton istemez. Ama `AuthInterceptor` her
isteğe Yönetiyor jetonunu koyuyor; koysa ve uç 401 dönse, kullanıcı
**Yönetiyor'dan atılırdı** (F4'te ölçülen kusur). Çözüm:
`extra[dukkanJetonu]` **boş dize** = "Dukkan'ın kimliksiz ucu" —
işaretin *varlığı* refresh dalını kapatıyor, başlık ise yalnız gerçek bir
jeton varsa ekleniyor.

### `telefon_gerekli` artık çıkmaz sokak değil

Beş ekran aynı dalı elle kopyalamıştı ve hepsi web'e yolluyordu. Ortak
`DukkanHataGovdesi`'ne alındı; orada artık bir **düğme** var.

**Talep oluşturmada özel dal:** oraya kadar gelen kullanıcı formu
doldurmuş durumda. "Web'e gidin" demek, girdiği her şeyi çöpe atmasını
istemekti. Doğrulama ekranı açılıyor ve başarılıysa **gönderim kaldığı
yerden tekrarlanıyor**.

### SMS başlığı gelmeden ne oluyor — açıkça söyleniyor

Uç 503 `sms_baslik_yok` dönüyor; ekran bunu "bir hata oluştu" diye
göstermiyor, **beklemekten başka yapılacak bir şey olmadığını** söylüyor.
Üç SMS hatasının metni ayrı, çünkü kullanıcının yapacağı şey farklı
(bekle / tekrar dene / işe yaramaz). Metinler `dukkan-web`'deki
ayrımlarla **aynı**: iki istemcinin aynı koda farklı şey demesi, destek
konuşmasını imkânsız kılardı.

**Adım yalnız gönderim başarılıysa ilerliyor.** 503 alındığında da kod
ekranına geçseydik, kullanıcı gelmeyecek bir kodu beklerdi.

---

## Ölçemediklerim

1. **Gerçek SMS teslimi — hâlâ ölçülmedi.** Onaylı başlık yok; Verimor'a
   bu turda da hiç istek atılmadı. OTP akışının uçtan uca sürülmesi
   başlığa bağlı. Dev'de sağlayıcı `konsol` olduğu için kod **konsola**
   düşüyor ve akış oradan sürülebilir — ama bu gerçek teslim değil.
2. **Kota düzeltmesinin gerçek koşulda etkisi.** Dev'de `konsol`
   sağlayıcısı **başarılı** dönüyor; başarısız dal, satır doğrudan
   yazılarak ölçüldü (uç canlı sunucuda koştuğu için süreç dışından
   sağlayıcı değiştirilemiyor). Ölçülen şey **ucun kullandığı sorgu**.
3. **Cihazda OTP ekranı.** Emülatör yok; klavye/otomatik-kod davranışı
   görülmedi.
4. **Geçmiş davet satırlarının gerçek durumu.** `saglayici_yok`
   varsayımı en doğru tahmin, kanıt değil.
