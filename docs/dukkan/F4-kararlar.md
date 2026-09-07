# DUKKAN F4 — KARARLAR

Talep tarafı: talep oluşturma, KVKK paylaşım tercihleri, teklif akışı,
iş kabulü ve adresin açılması. Web + mobil.

---

## 1. Tablo adı `is` değil `is_kaydi` — ölçerek bulundu

İlk yazımda tablo `is`ti ve **tüm sorgular 500 verdi**:

```
syntax error at or near "i"
```

`IS` SQL'de **ayrılmış anahtar kelime** (`IS NULL`, `IS DISTINCT FROM`).
`FROM is i` ayrıştırılamıyor.

Çözüm *"her yerde tırnakla"* **değil**. Tırnak gerektiren bir tablo adı
kalıcı bir tuzaktır: bir gün yazılan bir sorguda tırnak unutulur ve kusur o
sorgu ilk kez çalıştığı anda — aylar sonra, belki prod'da — ortaya çıkar.
**Ad değiştirmek bir kereliktir; tırnak disiplini sonsuza kadar sürer.**

Göç henüz hiç push'lanmamıştı, o yüzden yerinde düzeltildi (`MIGRATION-
POLITIKASI` kuralı prod'a ulaşmış göçler için).

---

## 2. `paylas_*` üçü de `DEFAULT false` — hem şemada hem şemada

Varsayılan `true` olsaydı, formda onay kutusunu kaldırmayı unutan bir
kullanıcı verisini **paylaşmış** olurdu. `false` ile unutmanın cezası
*"veri paylaşılmadı"* — **güvenli yön**.

Bu bir arayüz tercihi değil **veritabanı varsayılanı**: ikinci istemci
(mobil) geldiğinde arayüzdeki bir kutu unutulsa bile sütun `false` başlar.
Bir test alanları hiç göndermeden talep açıp üçünün de `false` olduğunu
ölçüyor.

---

## 3. İzin yoksa adres **hiç saklanmıyor**

*"Nasılsa göstermeyiz"* diye saklamak KVKK veri minimizasyonuna aykırı ve
gereksiz bir sızıntı yüzeyi. `paylas_adres=false` ise `acik_adres`
veritabanına **hiç girmiyor**.

Arayüz de bunu söylüyor: *"Açık adresini paylaşmayı seçmediğin için adres
bilgisi kaydedilmez."* Kullanıcının *"yazdım ama işaretlemedim, duruyor
mu?"* sorusu cevapsız kalmamalı.

**Kırarak doğrulandı:** koşulu kaldırınca test *"izin verilmediği hâlde
adres VERİTABANINA yazıldı"* diyerek düştü.

---

## 4. Görünürlük kuralı tek fonksiyonda

`_talep_gorunumu()` bir talebi çağırana göre şekillendiren **tek** yer.
Dört uç da oradan geçiyor.

| Kim | Ne görüyor |
|---|---|
| Talep sahibi | Her şey + paylaşım tercihleri |
| Kabul edilen işletme | + açık adres, + telefon |
| Teklif verebilir işletme | Yalnız mahalle (+ kullanıcının izin verdikleri) |
| Bölgesi dışındaki işletme | **403** |
| Başkası | **403** |

`acik_adres` **anahtarı her zaman dönüyor**, değeri `null`. Alanı tamamen
çıkarmak, istemciyi *"alan yok mu, izin mi yok?"* ayrımını yapmak zorunda
bırakırdı.

**Talep akışı sorgusunda `acik_adres` hiç seçilmiyor** — seçip sonra silmek
yerine hiç okumamak, bir gün "sil" adımının unutulması riskini ortadan
kaldırır.

---

## 5. `04-api-sozlesmesi.md` §4'ün beş kilidi — hepsi yazıldı ve kırıldı

| # | Kilit | Kırma denemesi | Sonuç |
|---|---|---|---|
| 1 | Teklif aşamasında `acik_adres` yok | `if kabul_edilen:` → `if True:` | **3 test kırmızı** |
| 2 | `paylas_telefon=false` iken telefon hiçbir alanda yok | aynı | kırmızı |
| 3 | Kabul sonrası adres açılıyor | — | yeşil |
| 4 | Kabul edilmeyen işletme kabul sonrası da göremiyor | aynı | kırmızı |
| 5 | İşletme başka işletmenin teklifini göremiyor | — | yeşil |

Ek olarak **bölge kontrolü** (T6 talep hasadı) ve **veri minimizasyonu**
kilitleri de ayrı ayrı kırılarak doğrulandı.

Sızıntı araması **yanıt gövdesinin tamamında** yapılıyor, alan alan değil:
bir uç sızıntıyı iç içe bir alanda yapabilir ve alan alan bakmak, bakmayı
unuttuğumuz alanı savunmasız bırakırdı.

---

## 6. Bölge kontrolü — talep hasadına (T6) karşı

Bir işletme, hizmet alanı + kategorisi **eşleşmeyen** bir talebi okuyamıyor
(403).

Bu olmasaydı, kimse sahte işletme kurup dolandırıcılık yapmak zorunda
kalmazdı: **sadece talepleri okuyarak** bir bölgedeki sakinlerin ihtiyaç
açıklamalarını, adlarını ve telefonlarını toplayabilirdi.

---

## 7. `tutar_kurus` NULL olabilir

`NULL` = *"yerinde görmem gerek"*. Zorunlu yapmak ustayı **uydurma rakam**
yazmaya iter; sonra müşteri *"fiyat tutmadı"* diye şikâyet eder. Boş
bırakabilmek daha dürüst.

Arayüz `0` ile `NULL`'u **ayırıyor**: `0` ücretsiz iş demek olurdu.

---

## 8. Bir talepten bir iş (`talep_id` UNIQUE)

Aynı talebi iki ustaya vermek isteyen kullanıcı **ikinci bir talep** açar.
Aksi hâlde *"hangi işin yorumu bu?"* sorusu cevapsız kalırdı (F5).

Teklif kabul edilince **diğer teklifler reddediliyor** — "bekliyor" hâlinde
bırakmak, teklif veren ustayı gereksiz yere bekletirdi.

---

## 9. İşi kim "tamamlandı" işaretleyebilir

**İkisi de** — kullanıcı ya da işletme sahibi. Yalnız kullanıcıya bırakmak,
işini bitiren ustanın yorum hakkının doğmasını müşterinin unutkanlığına
bağlardı; yalnız işletmeye bırakmak ustaya "bitti" deme yetkisini tek
taraflı verirdi.

**Yorum hakkı yalnız kullanıcıda** — yanıt `yorum_hakki` ile bunu söylüyor.

---

## 10. Talep kimseye ulaşmadıysa söyleniyor

`POST /dukkan/talep` yanıtı `eslesen_isletme` **sayısını** döndürüyor.
Sessizce 0 işletmeye giden bir talep, kullanıcıyı boş yere bekletirdi
(P217'de ölçülen sınıf). Web ve mobil ikisi de bu sayıyı gösteriyor:

> *"Bu bölgede kayıtlı işletme yok, talebin şu an kimseye ulaşmadı."*

---

## 11. Mobil — iki gerçek kusur önlendi

### 11.1 İki jeton dünyası birbirine karışıyordu

**Bu, F4'ün en tehlikeli bulgusuydu.** `AuthInterceptor` **her** isteğe
Yönetiyor jetonunu koyuyor. Dukkan'ın korunan uçlarına o jetonla gidilirse:

1. uç 401 döner (Yönetiyor jetonu `tur: "dukkan"` iddiası taşımaz),
2. `onError` bunu *"oturum bitti"* sanıp **Yönetiyor refresh**'ini dener,
3. refresh de başarısız olursa `onSessionExpired()` çağrılır ve
   **kullanıcı Yönetiyor'dan atılır**.

Yani Dukkan'da talep listesi açmak, kullanıcıyı **tesis uygulamasından
çıkarabilirdi** — sessiz ve teşhisi çok zor bir kusur.

Çözüm: istek `extra[dukkanJetonu]` taşıdığında o jeton kullanılıyor ve
refresh/oturum mantığı **atlanıyor**. Üç testle kilitli, biri ters yönlü
kanıt (Dukkan jetonu yoksa Yönetiyor jetonu **konmaya devam ediyor**).

**Kırarak doğrulandı:** muafiyeti kaldırınca test *"Dukkan 401i Yönetiyor
oturumunu KAPATTI — kullanıcı tesis uygulamasından atılırdı"* dedi.

### 11.2 Dar ekrana uyarlama

| Web | Mobil | Neden |
|---|---|---|
| Tek sayfa form | **3 adımlı `Stepper`** | Uzun kaydırmada paylaşım tercihleri en altta, görülmeden geçilirdi |
| Paylaşım kutuları formun dibinde | **Kendi adımında** | Kullanıcı *"ne paylaşıyorum"* sorusunu kendi ekranında görüp karar versin |
| Durum/teklif sayısı sağ üstte | **Başlığın altında** | Telefonda sağ köşe kaydırma sırasında baş parmağın altında kalır |

---

## 12. SSO köprüsü F6'dan F4'e çekildi

Yol haritasında F6'daydı. Mobilde talep oluşturmak **Dukkan jetonu**
gerektiriyor ve mobil parite her fazda isteniyor — bu yüzden öne çekildi.

**%27 kenar durum değil:** ölçüldü, Yönetiyor kullanıcılarının 837/3104'ünde
telefon yok. Köprü 409 `telefon_gerekli` dönüyor ve mobil bunu **açıkça**
söylüyor (7 dilde), sessizce boş ekran göstermiyor.

Mobilde OTP akışı **henüz yok** — bu durumda kullanıcı web'e yönlendiriliyor.
Açık madde (§14).

---

## 13. Web'de bir derleme kusuru

`useSearchParams()` Next 14'te statik ön-üretimde **Suspense sınırı** ister;
yoksa derleme `prerender-error` ile düşüyor. İki sayfada da eklendi.

Sınır en dışta, çünkü `/talep-olustur` SEO sayfalarından parametreyle
geliyor (`?kategori=&il=&ilce=&mahalle=`) ve o bağlamı **kaybetmemeli** —
kullanıcı "Ücretsiz teklif al" dedikten sonra bölgeyi yeniden seçmek zorunda
kalmamalı.

---

## 14. Açık maddeler

| Madde | Durum |
|---|---|
| **Mobilde telefon-OTP akışı** | Yok. Telefonu olmayan Yönetiyor kullanıcısı (%27) web'e yönlendiriliyor. F6'da mobil OTP eklenmeli |
| **Bildirim** | Teklif geldiğinde / iş verildiğinde push **yok**. F5 veya F6 |
| **Talep süresi** | `son_gecerlilik` sütunu var ama **kullanılmıyor**; süresi dolan talep otomatik kapanmıyor |
| **Jeton `localStorage`** | Devam ediyor; ödeme fazında yeniden değerlendirilecek (kullanıcının kararı) |

---

## 15. Ölçemediğim

1. **Gerçek kullanıcı davranışı:** paylaşım kutularının kaçının işaretleneceğini
   bilmiyorum. Hepsi kapalı kalırsa işletmeler yalnız mahalle görecek ve
   iletişim platform üzerinden kurulacak — ürünün çalışıp çalışmayacağı
   buna bağlı ve **ancak gerçek trafikte görülür**.
2. **Mobil ekranların cihazda görünümü:** emülatör yok; widget testleri
   yerleşimi doğruluyor ama gerçek bir telefonda okunabilirliği ölçemedim.
3. **Eşzamanlılık:** iki kullanıcı aynı anda aynı teklifi kabul ederse
   `talep_id` UNIQUE kısıtı ikincisini reddeder — ama bu **yarış** davranışı
   testte tetiklenmedi.
