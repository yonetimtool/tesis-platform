# P233 — konum, kısayol, telefon/e-posta sınırları, ikon

## §1 — Tesis konum bilgisi

### Ölçüm: alan vardı, **değer yoktu**

P193'te adres alanları (açık adres, ilçe, il, posta kodu) eklenmişti.
Enlem/boylam sorusunun yanıtı: **zaten var** — `tenant.konum_lat`,
`konum_lon`, `konum_ad` göç 0005'ten beri duruyor ve `/weather` onları
kullanıyor.

Ama dev veritabanındaki **tüm tesisler aynı değeri taşıyor**:

```
ad                      konum_ad   konum_lat   konum_lon
Bambaska Bir Ad         İstanbul   41.008200   28.978400
Oltu Sitesi Sinama      İstanbul   41.008200   28.978400
Coklu Yonetici Sitesi   İstanbul   41.008200   28.978400
...
```

Bu **sunucu varsayılanı** (`server_default`) — kimse hiç ayarlamamış.
Sonucu görünür ve yanlış: Erzurum'daki tesis **İstanbul havasını**
gösteriyor. Fark edilmesi en zor kusur sınıfından, çünkü ekran
**çalışıyor görünür**.

Alanlar `PATCH /tenant/settings` ile **yazılabilir durumdaydı**; eksik
olan şey, yöneticinin **enlem/boylam yazmadan** konumunu verebileceği bir
yoldu. Kimse tesisinin enlemini bilmez; alan bu yüzden boş kaldı.

### Karar: haritadan seçim değil, **adresten çözümleme**

Üç seçenek ölçüldü:

| seçenek | ölçüm | karar |
|---|---|---|
| Haritadan seçim | Web'de Leaflet **var** (`konum-haritasi.tsx`), **mobilde hiç harita paketi yok** (`pubspec.yaml`'da flutter_map/google_maps yok) | **reddedildi** — yeni bağımlılık + karo sağlayıcı + çevrimdışı davranış; yalnız web'e yapmak kalıcı parite kuralını bozardı |
| Dukkan hiyerarşisinden türetme | `dukkan.il/ilce/mahalle` 44.719 mahalle taşıyor ama **koordinat taşımıyor** (sütunlar: id/ad/slug/posta_kodu/tip) | **mümkün değil** |
| **Adresten çözümleme** | Open-Meteo coğrafi kodlama: anahtar istemiyor, **zaten kullandığımız sağlayıcı** (hava durumu aynı yerden) | **seçildi** |

Doğruluk **ilçe düzeyinde** — istenen iki kullanım (hava durumu, bölgesel
analiz) için tam yeterli; hava sokak hassasiyeti istemez.

Elle enlem/boylam yazma yolu **kapatılmadı** (`PATCH /tenant/settings`
duruyor): ücra bir konum için kaçış yolu kalsın.

### Aday listesi, tek sonuç değil

"Oltu" sorgusu üç farklı yer döndürüyor (ölçüldü):

```
Oltu     Erzurum         40.53945  41.98722
Oltush   Brest Oblast    51.68848  23.96978
Oltuca   Artvin          41.21180  42.25735
```

Sunucunun ilkini seçip "buldum" demesi, yöneticinin **hiç görmediği** bir
konumu tesise yazmak olurdu.

### Servis düşerse 503, sessiz boş liste değil

Boş liste "böyle bir yer yok" demektir; servis erişilemiyorsa bu **yanlış
bir cümledir** ve kullanıcıyı adresini yanlış yazdığını sanmaya iter.

### Dukkan hiyerarşisiyle eşleşme

**Şema sınırı korundu:** `app_rw`'nin `dukkan` şemasında sıfır yetkisi var
(P221'de kurulan kural) ve **yeni yazma yolu açılmadı**. Tesisin il/ilçe
bilgisi zaten `tenant` tablosunda **metin** olarak duruyor (P193);
Dukkan eşleşmesi gerektiğinde slug üzerinden yapılır — çapraz şema FK
yok.

### Zorunlu mu?

**Hayır.** Alan göç 0005'ten beri NOT NULL ve varsayılanı var; zorunlu
işaretlemek **bugün çalışan her tesisi bir gecede "eksik" ilan etmek**
olurdu — hiçbiri bozulmuş değil, yalnızca hava durumları yanlış. Kurulum
sihirbazı bunu **gösterir** ve düzeltmeyi kolaylaştırır; tesisi durdurmaz.

Sihirbaz ölçütü "alan dolu mu" **değil**, "varsayılandan farklı mı".
Gerçekten İstanbul'da olan bir tesis için bu yanlış negatif üretir (adım
"yapılmadı" görünür) — kabul edilebilir, çünkü adım zorunlu değil ve
yönetici konumu bir kez onaylayınca kapanır. Tersi — yanlış pozitif —
her tesise sessizce yanlış hava göstermekti.

### KVKK / yetki

| | kim |
|---|---|
| Konumu **görmek** (hava durumu) | herkes — tesisin genel bilgisi, sakinden saklamanın anlamı yok |
| Konumu **aramak** (`/konum/ara`) | admin + yönetici |
| Konumu **yazmak** (`PATCH /tenant/settings`) | admin + yönetici (saha rolü 403 — test edildi) |

### Ölçemediğim

Coğrafi kodlama servisinin **prod ağından** erişilebilirliği. Dev
makineden çalıştığı ölçüldü (HTTP 200); prod çıkış kuralları farklıysa uç
503 döner ve arayüz bunu **söyler** — sessizce boş liste göstermez.

---

## §2 — Mobil üst bar kısayolu: dil yerine arama

Üst barda dört kısayol vardı: ızgara düzenleme, bildirim zili, **dil**,
avatar. Dil simgesi kaldırıldı, yerine **arama** geldi.

Gerekçe isteğin kendisi: dil **zaten Ayarlar'dan** değiştirilebiliyor
(`settings_screen` içinde kendi kartı var) ve bir kez seçilip bir daha
dokunulmayan bir tercih; üst barda kalıcı yer kaplaması orantısızdı.

### Ölçüm sırasında çıkan bir yan sorun

P230 §3'te arama simgesini **karşılama satırına** koymuştum. Üst bara
taşıyınca **iki arama girişi** oluştu. İkisini de bırakmak, aynı işi iki
yerden yapan ve hangisinin "gerçek" olduğu belirsiz bir arayüz üretirdi;
karşılama satırındaki kaldırıldı.

**Üst bar seçildi** çünkü orada **her rolde aynı yerde** duruyor;
karşılama satırı rol ekranına göre değişiyordu.

`DilButonu` bileşeni silindi ama **`dilModaliniAc` duruyor**: modalin
kendisi hâlâ çağrılabilir, yalnızca üst bardaki girişi kalktı. Modali de
silmek, ileride başka bir yerden (örneğin ilk açılış) açmak isteyeni
sıfırdan yazmaya zorlardı.

Dokunma hedefi `IconButton` varsayılanıyla 48 dp (P220 kilidi) — test
ediliyor.

---

## §3 — Telefon: ülke kodu seçilir, uzunluk sınırı ülkeye göre

### Ölçülen kusur

`admin-web/lib/telefon.ts` ve `mobile/.../telefon_alani.dart` P123'ten beri
**TR'ye sabitti**: `telefonNormalle` her numaranın başına koşulsuz `+90`
koyuyordu. Yabancı uyruklu bir sakin ya da yurt dışındaki bir mal sahibi
numarasını girdiğinde ekranda hiçbir şey ters görünmüyor, ama **saklanan
değer başka bir numaraydı**. Telefon GLOBAL BENZERSİZ anahtar olduğu için
bunun iki sonucu var: ya başkasının gerçek numarasıyla çakışır, ya da hesap
erişilemez olur. Sessiz bir veri bozulmasıydı.

### Telefonun girildiği TÜM yerler (tarandı, atlanmadı)

| Yüzey | Yer |
|---|---|
| Web | `/tanimlar` (personel + firma defterleri) |
| Web | `/users` |
| Web | `/tenants` (yeni tesis + yönetici) |
| Web | `/tenants/[id]` (yönetici ekle + düzenle — 2 alan) |
| Web | `/dis-hizmetler` |
| Web | `/profil` |
| Web | `/kayit` ← **bileşeni kullanmıyordu**, kendi `<input>`u vardı |
| Mobil | sakin ekle + sakin düzenle |
| Mobil | personel |
| Mobil | dış hizmet |
| Mobil | kayıt |
| Mobil | profil |
| Mobil | Dükkân telefon girişi ← `prefixText: '+90 '` **sabit kodluydu** |

**Giriş ekranı (web + mobil) BU LİSTEDE YOK — gerekçesi aşağıda.**

### Giriş ekranı neden istisna (önceden söyleniyor, sessizce atlanmadı)

Görevde "hem giriş ekranında" yazıyor. Ölçtüm: P205 §1'den beri giriş
ekranı **tek alan** taşıyor — "E-posta **veya** telefon". Kimlik türünü
sunucu çözüyor (`app/kimlik.py`). O alana ülke kodu açılır listesi koymak,
e-posta yazan kullanıcıya anlamsız bir "ülke kodu seçin" kutusu göstermek
olurdu.

Bunun yerine **giriş ekranının yeni biçimi KABUL ETTİĞİ ölçüldü**:
`normalize_phone` boşluk/parantez/tire siliyor, yani `(+90) 541 922 23 88`
sunucuya `+905419222388` olarak varıyor. Giriş akışı değişmeden çalışıyor.

### Ülke kutusu neden BOŞ başlıyor

Önceden seçili bir `+90`, kutuya hiç bakmadan yabancı numara yazan
kullanıcının numarasını **sessizce** Türk numarasına çevirirdi — yani
düzeltmeye çalıştığımız kusurun aynısını üretirdi. Bir kerelik tek
dokunuşun karşılığı budur; **TR listenin başında**.

Mevcut kayıtta kutu boş değil: değer E.164 geldiği için ülke ondan
çözülür.

### Uzunluk sınırı neden ARALIK (enAz..enCok), tek sayı değil

Ülkelerin çoğunda cep numarası uzunluğu tek değil (IT 9-10, BG 8-9).
Maliyet **simetrik değil**: aralık gereğinden genişse yalnızca bir yazım
hatasını yakalayamayız; gereğinden darsa **gerçek bir insan kaydolamaz**.
Emin olmadığım yerde aralık genişletildi.

### Liste neden 50 ülke, 240 değil

Tam ITU listesi için 240 ülkenin aralığını **uydurmam** gerekirdi ve
uydurulmuş dar bir aralık, yukarıdaki asimetriye göre en kötü sonucu
verir. Liste = Türkiye + ürünün 7 dilinin konuşulduğu ülkeler + komşular +
sakin/çalışan olarak sık görülen ülkeler. Eksik bir ülke tabloya **tek
satır** eklenerek gelir (iki dosya: `lib/ulke-telefon.ts`,
`core/ui/ulke_telefon.dart`).

### Seçenek etiketi neden ülke ADI değil

50 ülke × 7 dil = **350 çeviri borcu**. Bayrak + ISO kodu + arama kodu
(`🇹🇷 TR +90`) dilden bağımsız okunur. Ayrıca `+1`i paylaşan US/CA ve `+7`yi
paylaşan RU/KZ yalnızca ISO koduyla ayrılır — arama kodu tek başına yetmez.

### Gösterim ile saklama AYRI (bozulmayan şey)

Sunucuya giden değer yine **E.164**. `normalize_phone` DEĞİŞMEDİ, göç
YAZILMADI, eski kayıtlar olduğu gibi okunuyor: `telefonParcala` hem eski
`0543…` biçimini hem `+90543…` biçimini hem de `905431992904` biçimini
çözüyor. Testlerdeki "ESKİ biçim de E.164 üretir" satırları bunun kilidi.

### Ölçüm sırasında çıkan bir kusur

İlk yazımda `905431992904` (çok yaygın bir yazım; backend `kimlik.py` bunun
için ayrıca telafi taşıyor) **taşma** sayılıyordu: `+` yok, baştaki `0` yok,
12 hane > TR sınırı 10. Test yakaladı. Düzeltme: `+` olmasa da ülke kodu
aranıyor — ama **yalnız hane sayısı tam tuttuğunda**. Tam eşleşme şartı
olmasaydı `5431992904` bir Arjantin numarası (`+54`) sanılırdı.

### Mobilde YENİ: paylaşılan alan bileşeni

Web'de `TelefonAlani` bileşeni P166 §9'dan beri vardı; **mobilde yoktu** —
yedi ekran kendi `TextField`ini kuruyordu, ortak olan yalnızca
biçimlendiriciydi. Ülke seçicisini yedi yere elle eklemek, sekizinci ekranın
onu unutması demekti. `core/ui/telefon_alani_widget.dart` yazıldı ve
yedisi de ona bağlandı.

**Kapsam kilidi sertleştirildi**: `telefon_alani_kapsam_test.dart` artık
"her alan biçimlendiriciyi kullanmalı" demiyor; `lib/src/features` altında
`TextInputType.phone` **veya** `TelefonBicimlendirici` geçmesini ihlal
sayıyor. Kilit, kasıtlı kusurlu örneklerle sınanıyor (4 dedektör vakası).

---

## §5 — Uygulama ikonu: zemin seçenekleri

Dört seçenek de `scripts/ikon-uret.py` ile üretildi (elle çizilmedi);
önizlemeler `assets/marka/ikon-onizleme/<varyant>/` altında, her varyantın
**tam seti** (iOS 1024, Play 512, adaptive fore/back, monokrom, favicon,
splash) var.

### Önce teknik gerçek: ikon SAYDAM OLAMAZ

İstek "zemin olmasın" olduğunda bunun neden mümkün olmadığını yazmak
gerekiyor — bu bir tercih değil, iki platformun kuralı:

* **iOS mağaza ikonu alfa taşıyamaz** (ITMS-90717 ile yükleme reddedilir);
  ana ekranda saydam piksel siyah çıkar.
* **Android adaptive ikonun ZEMİN KATMANI zorunludur**; saydam bırakılırsa
  launcher'a göre siyah/tanımsız görünür.

"Zeminsiz" görünüme en yakın sonuç düz **beyaz**dır. Saydamlığın korunduğu
yerler ayrı ve zaten alfalı yazılıyor: Android ön katmanı, monokrom
(Android 13 temalı ikon) ve web marka görselleri.

### Üretilen varyantlar

| Varyant | Zemin | İşaret | Not |
|---|---|---|---|
| `beyaz` | `#FFFFFF` | lacivert (özgün) | bugünkü varsayılan |
| `acik` | `#EAF1FA` | lacivert (özgün) | |
| `lacivert` | `#102060` | beyaz siluet | |
| `marka` | `#2060A0` | beyaz siluet | **P233 §5 — yeni** |
| `gradyan` | `#102060 → #2060A0` dikey | beyaz siluet | **yeni** |
| `buyuk` | `#102060` | beyaz siluet | **yeni** — renk değil **ORAN** |

### Gradyan neden DİKEY, neden köşegen değil

İkon 48 px'te de görülüyor ve köşegen bir geçiş o ölçekte kirli bir leke
gibi okunuyor; dikey geçiş "üst aydınlık / alt koyu" izlenimini koruyor.
Gradyan aralığı logonun kendi iç tonlarıyla (#102060–#2060A0) aynı — zemin
ve işaret aynı ekseni izleyince ikon tek parça okunuyor.

Ara renkler doğrusal harmanla üretiliyor; **gamma düzeltmesi bilinçli
olarak yapılmadı**: iki renk aynı tonun komşu değerleri, fark gözle ayırt
edilemiyor ve gamma hesabı aracı karmaşıklaştırırdı.

### "Daha büyük logo" neden ayrı bir varyant

Bu bir **renk** kararı değil **oran** kararı, yani bağımsız bir eksen:
`buyuk` varyantı mağaza oranını %72'den **%84**'e çıkarıyor (ölçüldü:
işaret 252×368 → 294×430 piksel, 512'lik tuvalde).

**Android adaptif oranı BÜYÜMEDİ ve büyüyemez**: dış %17 her maskede
kırpılır, %66 Android'in belgelediği güvenli bölgedir. Orayı büyütmek
işaretin launcher'da kesilmesi demekti. Yani "daha büyük logo" yalnızca
mağaza/favicon yüzeylerinde geçerli — bu, isteğin sessizce yarım
uygulanması değil, platformun sınırı.

### Seçim kullanıcıda

Varsayılan **değiştirilmedi** (`beyaz`). Seçilen varyant tek satırla
uygulanıyor:

```
python3 scripts/ikon-uret.py --varsayilan gradyan
```

Bu komut hem `assets/marka/ikon/`u hem mobil drawable'ları hem web
kopyalarını birlikte yazar (P184'te ölçülen kusur "aracı koşmayı
unutmak"tı; kopyayı elle taşımak aynı sınıfın ikinci yarısı).

---

## §4 — E-posta: uzunluk sınırı + biçim + anlaşılır hata

### Ölçüm önce: kural zaten vardı, SÖYLENMİYORDU

Backend `EmailStr` (pydantic/email-validator) kullanıyor. Konteynerde
ölçüldü:

| Girdi | Sonuç |
|---|---|
| 64 karakter yerel kısım | **kabul** |
| 65 karakter yerel kısım | **red** — "too long before the @-sign" |
| 265 karakter toplam | **red** |
| `bos@` | **red** |
| `a b@x.com` | **red** |

Yani sunucu doğru davranıyordu. Eksik olan **istemci tarafıydı**: altı web
alanının ve dört mobil alanın hiçbirinde uzunluk sınırı yoktu, kullanıcı
formu doldurup gönderdikten **sonra** jenerik bir hata görüyordu.

Ayrıca iki yerde **kopya kural** vardı ve ikisi de uzunluğu bilmiyordu:
`sifremi-unuttum/page.tsx` içinde `EPOSTA_RE`, `kayit_screen.dart` +
`staff_screen.dart` içinde `^[^@\s]+@[^@\s]+\.[^@\s]+$`. Sunucunun
reddettiği bir adres o ekranlarda **geçerli görünüyordu**.

### İstemci doğrulaması neden KASITLI OLARAK GEVŞEK

İstemci sunucudan **daha sıkı** olursa gerçek bir adresi reddeder ve
kullanıcı kaydolamaz — geri dönüşü olmayan taraf budur. `lib/eposta.ts` /
`core/ui/eposta.dart` yalnızca hiçbir sunucunun kabul etmeyeceğini
reddediyor: boşluk, `@` yokluğu/ikizi, noktasız alan adı, baş/son nokta,
çift nokta. Kesin karar sunucunun.

**Uzunluk sınırları ise kesin**: RFC 5321 — yerel 64, toplam 254. Ve
doğrulamada **uzunluk biçimden önce** soruluyor: çok uzun *ve* bozuk bir
adreste "biçim geçersiz" demek, kullanıcının adresi düzeltip yine
reddedilmesine yol açardı.

### Kapsam: telefonla aynı kalıp

| Yüzey | Yer | Nasıl |
|---|---|---|
| Web | `/users` | `<EpostaAlani>` |
| Web | `/tenants` (yönetim maili) | `<EpostaAlani>` |
| Web | `/tenants` (yönetici) | `<EpostaAlani>` |
| Web | `/kayit` | `<EpostaAlani>` |
| Web | `/profil` | `epostaHataMetni` çağrısı — **bileşen oturmuyor** |
| Web | `sifremi-unuttum` | `epostaHataMetni` çağrısı — kendi stil dili |
| Web | `TanitimForm` (tanıtım sitesi) | gönderimde `epostaHataMetni` |
| Mobil | sakin | `EpostaAlani` |
| Mobil | personel | `EpostaAlani` |
| Mobil | kayıt | `EpostaAlani` |
| Mobil | **giriş** | **MUAF** — aşağıda |

**Profil neden bileşene taşınmadı**: alanın *yanında* doğrulama rozeti,
*altında* OTP kod kutusu var; bunlar `AlanSarmal`ın tek-çocuk sözleşmesine
sığmıyor. Bileşen yerine **kural** paylaşıldı — aynı kimlikler, aynı
cümleler. Kapsam kilidi ikisini de kabul ediyor, **üçüncü bir yolu
etmiyor**.

**Giriş ekranı muaf** (§3'teki gerekçenin aynısı): alan "e-posta **veya**
telefon" taşıyor ve kimlik türünü sunucu çözüyor. E-posta biçim denetimi
uygulamak, telefonuyla giren kullanıcıyı engellerdi. Kilit bu muafiyeti
**adıyla** tanıyor, yani sessiz bir boşluk değil.

### Kilidin kendi kusuru da ölçüldü

Web kapsam kilidi ilk yazımda `GirisFormu.tsx`i ihlal bildirdi. Bakıldı:
oradaki `type="email"` bir **blok yorumun içinde** geçiyor (`type="text"`
tercihinin gerekçesi anlatılıyor). Yani kilit gerçek olmayan bir kusur
bildiriyordu; `yorumsuz()` blok yorumları da soyacak şekilde düzeltildi ve
bu durum dedektör vakası olarak teste eklendi.

### §3/§4 ölçüm sırasında çıkan iki kusur daha

**1. `05431992904` yapıştırınca numara bozuluyordu.** Ülke kutusu TR iken
ulusal kutuya baştaki `0` ile yapıştırılan numara `+90` ile birleşince 11
hane oluyor ve **taşma** veriyordu. Düzeltme: ulusal kutuya yazılan/
yapıştırılan metinden baştaki sıfırlar atılıyor — hiçbir ülkede ulusal
anlamlı numara `0` ile başlamaz. Web'de `ulusalTemizle`, mobilde
biçimlendiricinin içinde.

**2. §1'in BFF rotası sözleşmede yoktu.** `GET /konum/ara` için
`admin-web/app/api/konum/ara/route.ts` yazılmıştı ama `contracts/
openapi.yaml`a eklenmemişti; `uc-sozlesme-kapisi` kilidi bunu yakaladı —
yani §1 turunda o kilidi koşmamışım. Uç + `KonumAdayi`/`KonumAramaSonucu`
şemaları sözleşmeye eklendi.

**3. §2'yi tam mobil takım koşmadan commit etmişim.** Yalnız yeni test
dosyasını koşmuştum; `dil_modali_test.dart` kaldırılan `DilButonu`ya
bağlıydı ve derlenmiyordu. Düzeltildi: test modalı yerel bir açıcı
düğmeyle sürüyor, "44pt dokunma hedefi" ölçümü ise ARAMA düğmesinin
üzerindeki kilide taşındı (kendi kurduğu widget'i ölçen bir test hiçbir
şey kanıtlamaz).

### Mobilde ülke seçici neden `DropdownButtonFormField` DEĞİL

İlk yazımda dropdown kullandım ve **yerleşim kilitleri kırmızıya döndü**.
Sebep ölçüldü: Flutter'ın dropdown'u **kapalıyken de** elli seçeneğin
hepsini widget ağacına kuruyor (`IndexedStack`), dolayısıyla kilit dosyası
elli satır ülke adı içeriyordu:

```
 739,  52  76x24  🇫🇷 FR +33
 739,  52  76x24  🇨🇦 CA +1
 ... (48 satır daha)
```

Bu, kilidin ne ölçtüğünü değiştiriyordu: artık **ekran yerleşimini değil
ülke tablosunu** ölçüyordu — tabloya bir ülke eklemek, telefonla hiç
ilgisi olmayan iki kilidi kırardı.

Çözüm kaynakta: kutu kapalıyken **tek satır** çizen bir `InkWell` +
`InputDecorator`, dokununca **arama kutulu alt sayfa**. Yan faydası: elli
maddelik bir dropdown telefonda zaten kötü bir liste; artık `TR` ya da
`90` yazıp bulunuyor.

Web'de bu sorun yok (`<select>` seçenekleri DOM'da tek satır) ve orada
`Secim` bileşeni kullanılmaya devam ediyor.
