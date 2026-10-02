# P250 — Ad/soyad, ödeme kodları, e-postalar, eğitim videoları, otomasyon

Bu belge P250'nin kararlarını, ölçümlerini ve **ölçülemeyenlerini** tutar.
Her bölüm ayrı commit. Bir maddeye "yapıldı" demek için gerçek akış
sürülmüş olmalı; sürülemeyen halka ayrıca **ÖLÇÜLEMEDİ** diye yazılır.

---

# §1 — KULLANICI ADI: AD + SOYAD

## Kural

| Alan | Biçim | Örnek |
|---|---|---|
| Ad | Her kelimenin baş harfi büyük, gerisi küçük; tire de kelime ayırır | "mehmet ali" → "Mehmet Ali", "ayşe-nur" → "Ayşe-Nur" |
| Soyad | Tamamı büyük | "yılmaz" → "YILMAZ" |
| İkisi | Baş/son boşluk kırpılır, iç boşluk teke iner | "  ayşe   nur " → "Ayşe Nur" |

**Türkçe harf kuralı** üç yerde de **elle** uygulanır: önce i→İ, ı→I
(büyütmede) ya da I→ı, İ→i (küçültmede), sonra varsayılan dönüşüm.
Varsayılan dönüşüm yanlış sonuç verir ve bu testle kilitli:

* Python `"ilker".upper()` = "ILKER", `"İ".lower()` iki kod noktası ("i̇").
* JS `toUpperCase()` aynı hatayı yapar. `toLocaleUpperCase("tr")` doğru
  sonuç verir ama ortamın ICU verisine bağlıdır.
* Dart `toUpperCase()` yerel ayar almaz.

Üç uygulama birbirinin ikizi ve aynı örneklerle kilitli:

* sunucu `backend/app/kisi_adi.py`,
* web `admin-web/lib/kisi-adi.ts`,
* mobil `mobile/lib/src/core/kisi_adi.dart`.

Kullanıcının verdiği örneklerin hepsi testte: ışıl→Işıl, ilker→İlker,
çiğdem→Çiğdem, öztürk→ÖZTÜRK.

**Yazarken ve kaydederken:** yazarken yalnız harf büyüklüğü değişir.
Boşluk silinmez, yoksa "Mehmet " yazıldıktan sonra ikinci ad
yazılamazdı. Kaydederken kırpma ve tek boşluk uygulanır. Sunucu kuralı
**her girdide yeniden uygular**: eski istemci, API'yi doğrudan çağıran
ve Excel de aynı sonucu alır.

**Bilinen sonuç (kullanıcı kararı gereği):** Türkçe kuralı her dilde
uygulanır. Küçük harfle yazılmış yabancı bir ad etkilenir: "ingrid"
"İngrid" olur, "smith" soyadı "SMİTH" olur. Büyük harfle başlayan
yazımda ("Ingrid") ilk harf korunur. İstenirse kural kullanıcının
diline bağlanabilir; bu turda yapılmadı.

## Saklama kararı: tek alan + ayrı soyad sütunu

**Karar:** `app_user.ad` **tam görünen ad** olarak kalır ("Mehmet Ali
YILMAZ"). Yeni `app_user.soyad` sütunu (göç 0160, NULL olabilir)
soyadı ayrıca tutar. İkisi `kisi_adi.tam_ad` ile birlikte yazılır.

**Gerekçe:**

| Etki | Tek alan + soyad sütunu (seçilen) | `ad` = yalnız ilk ad |
|---|---|---|
| Görüntüleme | 30'dan fazla okuyucu (liste, vardiya, panik, arama, ziyaretçi, mesai, PDF/Excel) **değişmeden** tam adı gösterir | Her okuyucu ad + soyad birleştirmeli; biri unutulursa yalnız ilk ad görünür |
| Arama | `ad` üzerindeki ILIKE / `tr_katla_sql` soyadı **da** bulur, değişiklik yok | Her arama iki sütuna genişletilmeli |
| Sıralama | `ORDER BY ad` bugünkü gibi (ilk ada göre). Soyada göre sıralama artık mümkün (`soyad`), eski kayıtlarda NULL | Aynı |
| Eski kayıtlar | Dokunulmaz, geri doldurma yok | Eski "Ali Veli"nin hangi kısmı soyad? Tahmin gerekirdi |

**Mevcut kayıtlara dokunulmadı.** Göç geri doldurma yapmıyor. Testle
ölçüldü: fixture kullanıcılarının `soyad`ı NULL kalıyor.

**Düzenleme ön-dolumu:** soyadı bilinmeyen eski kayıt düzenlenirken
**son kelime soyad olarak önerilir** ("Ali Veli" → Ad "Ali", Soyad
"Veli"). Bu yalnız formun ön-dolumudur; kayıt ancak kullanıcı kaydedince
değişir ve o anda yeni kural uygulanır. Tek kelimelik eski adda soyad
boş gelir ve zorunlu alan kullanıcıya doldurtur.

## Sunucu: soyad OPSİYONEL — bilerek

Mağazadaki 1.8.0 ve önceki mobil sürümler `ad` alanına tam adı yazıp
soyadsız gönderiyor. Sunucu soyadı zorunlu tutsaydı bu sürümlerde kayıt,
davet tamamlama ve personel ekleme güncellemeye kadar 422 alırdı.

* **Yeni istemcilerde iki alan da zorunlu:** web her formda, mobil 1.9.0'dan
  itibaren.
* Sunucuya soyadsız gelen `ad` tam ad sayılır, kelime başı biçimlenir
  ve `soyad` sütunu boş kalır.
* Yalnız `soyad` gelirse ilk ad mevcut kayıttan korunur.

Ortak şema tabanı: `schemas.AdSoyadGirdisi`.

## Kapsam: her yazma yolu

| Yol | Sunucu | Web | Mobil |
|---|---|---|---|
| Kullanıcı ekleme / düzenleme (`/users`) | ✓ | ✓ kullanıcılar sayfası | ✓ personel ekranı |
| Sakin ekleme / düzenleme (`/residents`) | ✓ | (web'de sakin, kullanıcı ekleme formundan eklenir) | ✓ ekleme + düzenleme |
| Profil (`/me/contact`) | ✓ | ✓ | ✓ **yeni:** mobilde ad düzenlenemiyordu, parite için eklendi |
| Davet tamamlama (`/davet/parola`, `/davet/sosyal`) | ✓ | ✓ | ✓ |
| Kayıt: rolle katılma, yönetici başvurusu, sosyal ile tesis açma | ✓ | ✓ (soyad alanı vardı, artık her yolda gidiyor) | ✓ |
| Platform paneli: tesis + yönetici oluşturma, yönetici ekle / düzenle | ✓ | ✓ | — (platform paneli yalnız web) |
| Excel içe aktarım (`kisi`: `ad`+`soyad`; `daire`: `sakin_ad`+`sakin_soyad`) | ✓ soyad sütunu **zorunlu** | ✓ şablon güncellendi | — (içe aktarım yalnız web, P193) |
| Dış hizmet kişileri (zaten ad/soyad ayrıydı) | ✓ biçim eklendi | — | — |

**Mobil sakin ekleme — davranış değişikliği:** P154'te mobil sakin
eklemede ad **bilerek** kaldırılmıştı ("yönetici numarayı bilir, adı
çoğu zaman bilmez"). O durumda sunucu "A-12 sakini" yazıyordu. P250
"yeni kullanıcı ad ve soyadla eklenir" dediği için alan geri geldi ve
zorunlu. Web ile parite sağlandı.

**Excel içe aktarımında `soyad` zorunlu sütun.** Eski şablonla gelen
satır "soyad: zorunlu alan eksik" hatası alır. Yeniden yüklemede aynı
kişiyi tanımak için karşılaştırma Türkçe küçük harfle yapılır. P250
öncesi "Ali Veli" ile yeni biçimli "Ali VELİ" aynı kişi sayılır;
`casefold` "İ"yi "i̇" yapıp ikisini farklı sayardı.

**Platform paneli yönetici yolları:** `add_tenant_yonetici` ve
`update_tenant_yonetici` SQL fonksiyonlarının imzası değişmedi; değişseydi
eski imzanın düşürülmesi gerekirdi. Bu iki fonksiyon tam adı yazar,
soyad aynı işlemde tesis bağlamında ayrıca yazılır. Tesis oluşturma
fonksiyonu (`create_tenant_with_yoneticis`) jsonb'deki `soyad` anahtarını
okuyacak biçimde güncellendi (göç 0160, imza aynı).

**KVKK:** hesap silme / anonimleştirme `soyad`ı da siliyor
(`hesap_silme.py`).

## Bu bölümde bulunan iki ayrı kusur

1. **Platform paneli "yönetici ekle" formu e-postayı hiç göndermiyordu.**
   Sunucu e-postayı P197'den beri zorunlu tutuyor (`TenantYoneticiAdd.email`),
   dolayısıyla her ekleme 422 alıyordu. Ad/soyad alanlarıyla birlikte
   e-posta alanı eklendi.
2. **`p203-mesai.dom.test.ts` 1 Ekim'de kendiliğinden kırıldı.** Test
   beklenen ayı `9` diye sabit yazmıştı, sayfa ise bugünün ayını açıyor.
   Beklenen değer artık bugünden hesaplanıyor. P250 değişikliğiyle ilgisi
   yok.

## Testler

* Sunucu `test_p250_ad_soyad.py` (24 test):
  * kural örnekleri ve varsayılan dönüşümün yanlış olduğu,
  * kullanıcı ekleme, düzenleme (yalnız soyad / eski istemci),
  * boş adın reddedilmesi, profil,
  * sakin ekleme ve düzenleme,
  * içe aktarımda soyadın zorunlu olması ve biçimi,
  * mevcut kayda dokunulmaması.
* Web `p250-ad-soyad.dom.test.ts`: kural ikizi; kullanıcı formunda
  yazarken biçim ve gövdede ayrı ad/soyad; soyadsız kayıt engellenir.
* Mobil `p250_ad_soyad_test.dart`: kural ikizi; personel eklemede
  yazarken biçim ve **tel üzerindeki** gövdede ayrı ad/soyad; soyadsız
  kayıt engellenir; eski kayıtta son kelime soyad önerilir.
* Mevcut testler yeni zorunlu alana uyarlandı:
  * içe aktarım (6 dosya),
  * web: p212, p218, profil, p198, kayit-rolleri,
  * mobil: p248 amir.

## ÖLÇÜLEMEDİ

* **Gerçek cihazda klavye davranışı.** Biçimlendirici imleç konumunu
  korur, çünkü Türkçe harf dönüşümü uzunluğu değiştirmez. Yine de
  Android/iOS klavyelerinin otomatik büyük harf ve öneri çubuğuyla
  etkileşimi yalnız emülatörsüz testte ölçüldü.
* **Kayıt uçları canlı sürülemedi.** Dev'de `YENI_KAYIT_AKISI` kapalı.
  Bu yüzden `rol-eposta-basla`, `yonetici-basvuru` ve `yonetici-tesis`
  canlı API'de çağrılamadı; ilgili 30 test atlandı.
  * Yapılan değişiklik küçük: tam ad + ayrı soyad yazılıyor.
  * İstemci tarafı ölçüldü: web ve mobil kayıt testleri gövdede ayrı
    `soyad` gidiyor.
  * Sunucu tarafında kalan halka prod'da ölçülmeli: bir yöneticinin web
    `/kayit` ile kaydolup listede adının "Ad SOYAD" görünmesi.
* **Dev'de §1 sunucu testleri:** dokunulan uçların 456 testi geçti
  (davet, kayıt, tesis, sakin, kullanıcı, profil, oauth, hesap).

---

# §2 — ÖDEME KODLARI

## Yapılanlar

| İstek | Web | Mobil | Sunucu |
|---|---|---|---|
| Her kodun yanında KOPYALA | ✓ ortak `KopyaKod` | ✓ (panoya alır, bildirim) | — |
| Satır seçimi + tümünü seç | ✓ | ✓ | — |
| E-posta: tek kişiye | ✓ satır düğmesi | ✓ satır düğmesi | `POST /users/odeme-kodlari/eposta` — **hemen** gider |
| E-posta: seçilenlere toplu | ✓ "Seçilenlere e-posta gönder (n)" | ✓ alt düğme | aynı uç — **kuyruğa** yazılır |
| Yeni eklenen kişi EN ÜSTTE | sunucu sırası | sunucu sırası | `ORDER BY created_at DESC` (önce ada göreydi) |
| Kurumsal şablon, logolu | — | — | `odeme_kodu_eposta.py` + ortak kabuk `eposta_kabugu.py` |
| Teslim durumu listede | rozet | çip | `eposta_durumu`: kuyrukta / gönderildi / iletildi / geri döndü / başarısız / e-posta ayarı yok |
| Hız sınırı + tekrar koruması | — | — | aşağıda |

**Mobilde bu ekran hiç yoktu:** yalnız sakin kendi kodunu görebiliyordu.
Parite için yönetici ekranı eklendi. Giriş noktası "Sakinler"
ekranının üst çubuğunda **etiketli** bir düğme (P237 kuralı: başka
ekrana giden eylem etiketsiz olamaz).

## Şablon

Kullanıcının istediği içerik:

* kişinin adı ("Merhaba Işıl ÖZTÜRK"),
* daire,
* büyük ve seçilebilir **ödeme kodu çipi**,
* banka adı ve IBAN,
* "Havale / EFT yaparken açıklama alanına yalnızca ödeme kodunuzu
  yazın: TS-XXXXXX",
* kısa açıklama (kod sayesinde ödeme otomatik eşleşir, yazılmazsa elle
  eşleştirilir ve gecikebilir),
* uygulama satırı ve mağaza düğmeleri.

7 dilde, HTML + düz metin (multipart). Arapçada sağdan sola yazılır.

**Görünüm:** davet e-postasıyla aynı kurumsal kabuk. Lacivert başlıkta
"yönetiyor" logosu (`yonetio-marka-acik.png`), beyaz kart, koyu mod,
Outlook (MSO) desteği.

* **Ortak kabuk:** `eposta_kabugu.py`. §3 (hoş geldiniz) ve §7 (aidat
  hatırlatma) aynı kabuğu kullanacak.
* **Logo adresi:** `EPOSTA_LOGO_URL` ayarı. Varsayılan
  `https://app.yonetiyor.com/yonetio-marka-acik.png`; boş bırakılırsa
  metin işareti çizilir.

**Dil:** kişinin dili `app_user`da tutulmuyor. En son kullandığı aktif
cihazın dili (push ile aynı kaynak) kullanılır; cihaz yoksa yöneticinin
istek dili. Yardımcı: `islem_epostasi.alici_dili`.

**IBAN tanımlı değilse gönderim 422** (`odeme_kodu_iban_yok`): "önce
banka hesabı (IBAN) tanımlayın". E-postanın özü "bu hesaba, bu kodla
öde". Hesap bilgisi olmadan gönderilen e-posta sakini yönetime sormaya
yollardı. IBAN P27'den beri kasa tanımında; ikinci bir IBAN alanı
açılmadı.

## Teslim durumu (P234 Resend geri bildirimi)

* `mesaj_gonderim`e **`tur`** sütunu eklendi (göç 0161). Değerler:
  `odeme_kodu`, ileride `hosgeldin` ve `aidat_hatirlatma`. "Bu kişiye
  ödeme kodu e-postası en son ne zaman gitti, ne oldu?" sorusu ancak
  satırın hangi işten geldiği bilinirse cevaplanır.
* Listede kişi başına bu türdeki **en son** satır gösterilir. Ham durum
  arayüz durumuna çevrilir (`islem_epostasi.teslim_durumu`):
  * `iletildi` ve `okundu` → **iletildi**. `okundu` ayrı gösterilmedi;
    açılma pikseli güvenilir değil, Apple Mail önceden yükler.
  * `basarisiz` + `hata='bounce'` → **geri döndü**. P234 webhook'u bounce'u
    böyle yazıyor.
  * diğer `basarisiz` → **başarısız**; `yapilandirilmadi` → **e-posta
    ayarı yok**.
* Gönderilemeyen kişi seçilemez ve satırda sebebi görünür: **adres yok**
  ya da **e-posta bildirimleri kapalı**.

## Hız sınırı ve tekrar koruması

| Koruma | Değer | Neden |
|---|---|---|
| Toplu gönderim kuyruktan | tek kişi hemen, birden çok kişi kuyruğa | Yöneticinin tarayıcısı yüzlerce gönderimi beklemesin |
| Kuyrukta e-postalar arası aralık | 0,55 sn (`mesaj_kuyruk.EPOSTA_ARALIGI_SN`) | Resend saniyede 2 istek kabul ediyor; arka arkaya 200 e-posta ilk ikisinden sonra 429 alıyordu |
| Aynı kişiye tekrar | 15 dk içinde ikinci ödeme kodu e-postası **gitmez** (`yakin_zamanda`) | Çift tıklama ve "gitti mi?" diye yeniden basma. Geri dönen / başarısız gönderim sayılmaz, adres düzeltilip yeniden gönderilebilir |
| Uç hız sınırı | kullanıcı başına dakikada 10 istek | Kötüye kullanım |
| Günlük kota | mevcut tesis kotası (`kota_kontrol`) | Yarım gönderim yerine hiç gönderim |
| Liste boyu | istek başına en çok 500 kişi | Girdi sınırı |

**Kuyrukta iki düzeltme:**

1. **Yeniden deneme HTML'i kaybediyordu.** Kuyruk yalnız düz `govde`yi
   gönderiyordu. Kurumsal HTML e-posta ikinci denemede düz metne
   düşüyordu. `govde_html` artık saklanıyor ve yeniden denemede aynı
   haliyle gidiyor.
2. **Satır kilidi.** E-posta aralığı yüzünden bir tur 60 saniyeyi
   aşabilir ve beat bir sonraki turu başlatır. İki tur aynı satırı iki
   kez gönderirdi. Artık `FOR UPDATE SKIP LOCKED`: kilitli satır atlanır.

**Bildirim tercihi:** `bildirim_eposta=false` kişiye ödeme kodu
e-postası gitmez (`eposta_kapali`). Kişi yine kodunu uygulamada görür.

## Testler

* Sunucu `test_p250_odeme_kodu_eposta.py` (8):
  * yeni eklenen en üstte,
  * tek kişiye hemen gönderim; şablonda ad, kod, IBAN, açıklama
    talimatı ve logo,
  * 15 dk tekrar koruması,
  * toplu gönderim kuyruğa yazılır, kuyruk işlenince gönderilir, HTML
    korunur,
  * bounce → "geri döndü" ve yeniden gönderilebilir,
  * e-postası kapalı kişi atlanır,
  * IBAN yoksa 422,
  * sakin ve güvenlik 403.
* Web `p250-odeme-kodlari.dom.test.ts`: sıra, her kodda kopyala, durum
  rozetleri, tümünü seç yalnız gönderilebilirleri seçer, toplu ve tek
  gövde, adressiz kişinin düğmesi kapalı.
* Mobil `p250_odeme_kodlari_test.dart`: aynı ölçümler, tel üzerindeki
  gövde.
* Kilit kayıtları:
  * `rol-matrisi.txt`: yeni uç yalnız admin ve yönetici,
  * `uc-guvenlik.tsv`: sahiplik `rol`, hız `var`, denetim `ozel`,
  * openapi,
  * hata metni 7 dilde.

## ÖLÇÜLEMEDİ

* **Gerçek teslim.** Dev'de Resend anahtarı yok; gönderim konsol
  sağlayıcısıyla "gönderildi" oluyor. "İletildi" ve "geri döndü"
  durumları P234 webhook'unun yazdığı değerlerle testte kuruldu. Gerçek
  bir Resend olayıyla prod'da ölçülmeli.
* **E-postanın gerçek istemcide görünümü** (Gmail, Outlook, Apple Mail,
  koyu mod). HTML davet e-postasıyla aynı kalıpta. Logo görselinin
  `app.yonetiyor.com` üzerinden oturumsuz açıldığı prod'da
  doğrulanmalı.

---

# §3 — HOŞ GELDİNİZ E-POSTASI

## Ne zaman gider: kayıt tamamlanınca, bir kez

"Kayıt tamamlandı" beş yerde oluyor. Hepsi aynı yardımcıyı
(`hosgeldin.bir_kez_gonder`) **aynı işlemde** çağırır:

| Tamamlama | Uç |
|---|---|
| E-posta / telefonla rol kaydı (son adım: parola) | `POST /auth/set-password` |
| Davetle gelen kişi, parola | `POST /davet/parola` |
| Davetle gelen kişi, sosyal giriş | `POST /davet/sosyal` |
| SSO ile rol kaydı (doğrudan ve OTP'li iki yol) | `oauth._rol_tamamla_baglan` |
| Yeni tesis açan yönetici (e-posta yolu ve sosyal yol) | `kayit.yonetici_tesis`, `kayit.tesis_olustur` |

Yöneticinin kişiyi **eklemesi** kayıt değildir. E-posta, kişi kaydını
kendisi tamamlayınca gider; testte ölçüldü.

**Bir kez:** `app_user.hosgeldin_at` (göç 0162). Gönderim
`UPDATE … WHERE hosgeldin_at IS NULL RETURNING` ile yapılır.

* Aynı anda gelen iki tamamlama isteği (çift tık) yalnız **bir** e-posta
  üretir.
* Davetin yeniden kullanılması ya da rol değişimi işareti silmez; testte
  ölçüldü.
* **Parola sıfırlama bu yollardan değil.** `sifre/dogrula-ve-ayarla`
  hoş geldiniz göndermez.

**Mevcut hesaplara gitmez:** göç, kaydını zaten tamamlamış her hesabı
(parolası kurulmuş ya da sosyal kimliği bağlı) "karşılanmış" sayar.
Davet bekleyen, henüz tamamlanmamış hesaplar NULL kalır ve
tamamladıklarında e-postayı alır.

**Çoklu tesis:** işaret hesap satırı başına, yani tesis üyeliği başına.
İkinci bir tesise katılan kişi o tesis için de hoş geldiniz alır, çünkü
yeni tesiste ayrı bir rol ve ayrı modüller söz konusu. "Tekrar kayıt"
(aynı tesis, aynı hesap) e-posta üretmez.

**Kaydı düşürmez:** gönderim savepoint içinde. Şablon, dil ya da
sağlayıcı hatası parolayı ve oturumu geri aldırmaz. Sağlayıcı başarısızsa
satır kuyruğa düşer ve yeniden denenir (§2'deki kuyruk, HTML korunur).

## İçerik: role göre

| Rol | Anlatılanlar |
|---|---|
| Sakin | aidat, ödemeler ve kişisel ödeme kodu; duyuru ve anket; arıza/talep; rezervasyon; ziyaretçi onayı; acil durum çağrısı |
| Güvenlik / güvenlik amiri | ziyaretçi ve araç kaydı ile daire onayı; devriye ve kontrol noktaları; vardiya; acil çağrı takibi; kargo; daireye sesli mesaj |
| Tesis görevlisi | görev ve iş emirleri (fotoğrafla kapatma); talepler; bakım planı; sayaç okuma; vardiya ve mesai |
| Yönetici / admin | kurulum sihirbazı (videolu, §4); aidat ve finans; duyuru, anket, SMS/e-posta; personel, vardiya, devriye; otomasyon (§7, §9); raporlar |
| Denetçi | finans kayıtları, raporlar, karar defteri |

**Her rolde ortak:**

* mağaza düğmeleri (Google Play, App Store),
* "İstek ve önerileriniz için: destek@yonetiyor.com",
* 7 dil,
* §2'deki kurumsal kabuk (logo, koyu mod, Arapçada sağdan sola).

**Yalnız yönetim rollerinde:** web paneli adresi. Yeni tesis açan
yöneticide ayrıca Tesis ID çipi. Sakin, güvenlik ve görevliye web
adresi gösterilmez, çünkü o roller mobil-yalnız (P179, P248).

**Yönetici kaydındaki eski e-postanın yerini aldı:** yeni tesis açan
yöneticiye düz metin, yalnız Türkçe bir "Tesis ID'niz" e-postası
gidiyordu. O fonksiyonun kendi notunda "HTML şablonu geldiğinde değişecek
yer burası" yazıyordu. İçeriği (Tesis ID, web girişi, mağaza
bağlantıları) yeni e-postada; eski fonksiyonun testi yeni şablona
taşındı ve aynı garantileri ölçüyor.

**Dil:**

* önce kişinin cihaz dili,
* cihaz yoksa kaydı tamamlayan isteğin dili (`Accept-Language`); kişi
  kendi kaydını yaptığı için bu kendi dilidir,
* o da yoksa Türkçe.

## Parite

E-posta sunucu tarafında üretiliyor. Web (`/kayit`, `/davet`) ve mobil
(kayıt, davet ekranları) aynı tamamlama uçlarını çağırıyor, dolayısıyla
iki yüzeyden tamamlanan kayıt aynı e-postayı tetikliyor. Arayüz
değişikliği gerekmedi.

## Testler

* `test_p250_hosgeldin.py`:
  * şablon her rol × 7 dilde destek satırını, mağaza bağlantılarını ve
    kişinin adını taşıyor,
  * web adresi ve Tesis ID yalnız yönetim rollerinde,
  * Arapçada sağdan sola,
  * içerik dört rolde birbirinden farklı,
  * gerçek akış: kişi eklenince e-posta gitmiyor; davetle kayıt
    tamamlanınca İngilizce e-posta tam bir kez gidiyor; ikinci deneme ve
    rol değişimi yeni e-posta üretmiyor,
  * geri doldurma kontrolü.
* Mevcut `test_p177_sms_ve_ileti` (yönetici e-postası Tesis ID ve web
  girişini içerir) yeni şablona taşındı.

## ÖLÇÜLEMEDİ

* Yönetici yeni tesis yolları (`yonetici-tesis`, `tesis-olustur`) dev'de
  `YENI_KAYIT_AKISI` kapalı olduğu için canlı sürülemedi. Aynı yardımcıyı
  aynı biçimde çağırıyorlar.
* Gerçek posta kutusunda görünüm (§2 ile aynı not).

---

# §4 — KURULUM EĞİTİM VİDEOLARI (YouTube)

## Veri: bağlantı platformda, izlenme hesapta (göç 0163)

**`egitim_videosu`: platform tablosu.** Satırlar şunlardan oluşur:
`set_kodu`, `adim_kodu`, `youtube_id`, `baslik`, `aciklama`, `sira`,
`aktif`, `surum`.

* **Yalnız video kimliği saklanır** (11 karakter). Video sunucumuzda
  durmaz.
* Aynı videolar bütün tesislere gösterilir, bu yüzden tablonun tesisi
  yok.
* Desen `surum_politikasi` ile aynı: RLS açık + FORCE, politika yok.
  Erişim yalnız üç SECURITY DEFINER fonksiyonundan:
  `egitim_videosu_oku`, `egitim_videosu_yaz`, `egitim_videosu_sil`.
* Yazma ve silme yalnız platform admininde. Envanter kilidi bunu ölçüyor:
  yönetici 403 alıyor.
* Platform tablosu tavanı 4'ten 5'e bilinçli olarak yükseltildi.

**`egitim_izleme`: tesis kapsamlı, hesaba ait.** Web ve mobil aynı
satırı okur, dolayısıyla web'de izlenen video mobilde de işaretli.

**Video setleri:** bugün yalnız `yonetici` (kurulum sihirbazının 19
adımı). Sakin ve güvenlik için ayrı setler aynı tabloya yeni `set_kodu`
ile gelir. Hangi rolün hangi seti göreceği `SET_ROLLERI`'nde tanımlı;
şema değişmez. "Şimdilik yalnız yönetici görsün": diğer roller 403
alır.

**Anında yayın:** panelde kaydedilen satırı istemciler bir sonraki
listede görür. Uygulama sürümü gerekmez.

## Karar: video değişince "izlendi" sıfırlanır

**Karar: sıfırlanır.** Video kimliği değişirse `surum` bir artar. İzlendi
işareti hangi sürüm için konduysa ona aittir; eski işaret yeni videoya
sayılmaz.

**Gerekçe:** video, arayüz değiştiği için yeniden çekiliyor. Eski videoyu
izlemiş kişi yeni ekranı görmemiştir. Işareti korumak "izlendi" diyerek
yanlış bilgi verirdi.

**Sınır:** başlık, açıklama, sıra ya da aktiflik değişikliği sürümü
**artırmaz**. Yazım düzeltmesi kimseye videoyu yeniden izletmez.

Panel bu kuralı kaydetme alanının altında açıkça yazıyor. Testte
ölçüldü: başlık değişince sürüm 1 kalıyor, video değişince 2 oluyor ve
izlenen sayısı 0'a düşüyor.

## Bağlantı biçimleri

Kabul edilenler:

* `youtube.com/watch?v=` (`m.` ve `music.` alt alan adları dahil, `&t=`
  ve `&list=` gibi ek parametrelerle),
* `youtu.be/` (`?si=` izleyici parametresiyle),
* `youtube.com/shorts/`,
* `embed` bağlantıları ve yalnız kimlik.

Video kimliği ayıklanır. Geçersiz bağlantı için anlaşılır hata (7 dil)
gösterilir: "Geçerli bir YouTube bağlantısı girin
(youtube.com/watch?v=…, youtu.be/… ya da youtube.com/shorts/…)". Başka
bir alan adındaki `watch?v=` reddedilir.

Kural sunucuda ve web'de ikiz (`egitim_video.py`, `lib/youtube.ts`). Web
ikizi panel önizlemesi içindir.

## Oynatma

* **YouTube IFrame Player API** kullanılıyor. Oynatıcı
  `youtube-nocookie.com` üzerinden yerleşir (`host`), `rel=0`.
* **Video bitince (ENDED):** adım hesaba "izlendi" yazılır ve "Şimdi bu
  adımı yap" vurgulanır. Web'de birincil düğmeye, mobilde dolgulu
  düğmeye döner.
* **Ortada kapatılan video izlendi sayılmaz.** ENDED dışındaki durumlar
  (duraklatma vb.) istek üretmez; testte ölçüldü.
* **Hatalar:**
  * Gizli ya da yerleştirmeye kapalı video (oynatıcı hatası 100, 101,
    150): "Video oynatılamıyor: video gizli olabilir ya da yerleştirmeye
    izin verilmemiş."
  * YouTube erişilemezse (API yüklenmedi, web'de 10 sn, mobilde 15 sn
    zaman aşımı): anlaşılır mesaj gösterilir. Sayfanın geri kalanı
    çalışır.
* **Videosu girilmemiş adım "yakında" görünür;** kırık oynatıcı çizilmez.
  Pasif video da "yakında" sayılır.
* **Oynatma sırası:** panelde girilen `sira`; girilmemişse sihirbaz
  sırası. Panelin önerdiği varsayılan, adımın sihirbazdaki yerinin 10
  katı.

## İçerik güvenlik politikası (CSP)

**Panelde bugüne kadar hiç CSP yoktu** (yalnız Caddy'nin
X-Frame-Options ve nosniff başlıkları). P250 ile `next.config.mjs`'e
eklendi:

| Yönerge | Değer |
|---|---|
| `script-src` | `'self' 'unsafe-inline'` + **yalnız `https://www.youtube.com`** (IFrame API). Geliştirmede `'unsafe-eval'` (React yenileme); üretimde yok |
| `frame-src` | `'self'` + **`https://www.youtube-nocookie.com`** + mevcut harita gömüleri (`www.google.com`, `www.openstreetmap.org`; `SiteHarita`) |
| `worker-src` | `'self' blob:` (hls.js canlı kamera akışını blob işçisiyle çözüyor) |
| `object-src` / `base-uri` / `frame-ancestors` | `'none'` / `'self'` / `'none'` |

**Joker yok.** Kilit: `tests/p250-csp.test.ts`. Betik yönergesinde
YouTube'dan yalnız tek alan adı var; çerçeve yönergesinde `youtube.com`
yok (yalnız nocookie).

**Bilinçli olarak kısıtlanmayanlar:** `img-src`, `connect-src`,
`style-src`, `font-src`. MinIO imzalı görselleri, API ve yazı tipleri
ortama göre değişen alan adlarından geliyor. Bunları sabitlemek, ortam
başına kırılma demekti.

**Satır içi betik (`'unsafe-inline'`):** Next'in sayfa açılış betikleri
satır içi. Nonce tabanlı CSP ayrı ve büyük bir iş; bu tur kapsamında
değil.

## Web

| İstek | Yapılan |
|---|---|
| Ana sayfada kart, ilerlemeyle ("3/8 izlendi") | Özet sayfasında karşılama bandının hemen altında. Pano **bölümü değil**, "paneli düzenle" ile gizlenmez |
| Kart kurulum bitince küçülür, kaybolmaz | `kurulum_tamam` (zorunlu adımlar tamam) gelince ilerleme çubuğu kalkar ve düğme küçülür. Devralan yönetici yine erişir |
| Pencere: 16:9 video, adım numaraları (izlenende ✓, aktif vurgulu, tıklayınca geçiş), ileri/geri | ✓. Sol/sağ ok tuşları da gezer. Numaralar `aria-current="step"` taşır |
| "Şimdi bu adımı yap" | Pencere kapanır, sihirbazdaki hedef sayfaya gidilir; video bitince vurgulanır |
| Esc / dışarı tıklama | Ortak `Modal` |
| Sihirbazda her adımın yanında "Videoyu izle" | Yalnız videosu olan adımda gösteriliyor; pencereyi o adımda açar |

Hiç video girilmemişse kart çizilmez: "0/0" bir vaat değil, gürültü.

**Platform paneli `/egitim-videolari`:**

* sihirbazın 19 adımı, her biri için bağlantı, başlık, kısa açıklama,
  sıra ve aktiflik,
* **kaydetmeden önce önizleme:** oynatıcı hatası yakalanır ve gizli video
  uyarısı yönetici kaydetmeden görünür,
* "Videoyu kaldır".

Rota platform yüzeyinde ve yalnız admin'e açık (`yuzey.ts`, menü,
middleware matcher).

## Mobil

* **Tam ekran sayfa** (`/kurulum-videolari`, açılır pencere değil).
  * Video üstte; yatay çevrilince tam ekran oynatılır (paket içi).
  * Altında dikey adım listesi: numara, başlık, kısa açıklama, izlendi
    işareti.
  * Video alanı sağa/sola **kaydırılarak** adım değiştirilir (PageView).
    Ayrıca etiketli ileri/geri düğmeleri var.
  * "Şimdi bu adımı yap" altta sabit; video bitince dolgulu düğmeye
    dönüşür.
  * Adımın mobil karşılığı yoksa (ör. aidat, konum) düğme "bu adım
    web'de yapılır" der ve devre dışıdır.
* Yönetici ana ekranında aynı kart, hızlı erişim ızgarasının üstünde.
* Sihirbaz ekranında videosu olan adımda "Videoyu izle".
* **Paket: `youtube_player_iframe` 6.0.2.** Gerekçe:
  * YouTube'un resmî IFrame API'sini WebView'da çalıştırıyor; `ENDED`
    dahil oynatıcı durumları Dart akışına geliyor ("bitince izlendi"
    ancak bununla yapılabilir),
  * `privacyEnhancedMode` ile nocookie alan adı,
  * yatay çevirmede tam ekran,
  * 100/101/150 hata kodlarını ayrı veriyor.
  * `youtube_player_flutter` eski bir sarmalayıcı ve nocookie seçeneği
    yok.
* **`rel=0` mobilde:** paketin karşılığı `strictRelatedVideos`. YouTube
  2018'den beri `rel=0`'ı "yalnız aynı kanaldan öneri" olarak yorumluyor;
  iki yüzeyde de sonuç aynı.
* Testte WebView yok. Oynatıcı bir sağlayıcı üzerinden kuruluyor;
  testler sahte kurucuyla ENDED ve hata olaylarını tetikliyor.

## Testler

* Sunucu `test_p250_egitim_videolari.py` (14):
  * 9 bağlantı biçimi,
  * panel kaydında yalnız kimlik saklanıyor ve anlaşılır hata var,
  * sürüm kuralı (başlık artırmaz, video artırır),
  * bilinmeyen adım 404,
  * liste: pasif video "yakında", sihirbaz sırası, videosuz adıma
    izlendi yazılamaz,
  * izlendi işaretinin sayılması ve video değişince sıfırlanması,
  * işaret hesaba ait (admin'e sızmıyor),
  * rol kapıları.
* Web:
  * `p250-egitim-videolari.dom.test.ts`: açılış adımı, nocookie + rel=0,
    ENDED → istek + vurgu + yönlendirme, duraklatma istek üretmiyor,
    "yakında", gizli video uyarısı, kimlik ikizi,
  * `p250-egitim-panel.dom.test.ts`: geçersiz bağlantı, kaydetmeden önce
    önizleme uyarısı, PUT gövdesi,
  * `p250-csp.test.ts`.
* Mobil `p250_kurulum_videolari_test.dart`: açılış adımı, liste ve
  izlendi işareti, ENDED → istek + vurgu, kaydırma ile "yakında", gizli
  video uyarısı, kartın iki boyu.
* Kilit kayıtları güncellendi:
  * secdef envanteri (3 fonksiyon),
  * RLS platform tavanı,
  * rol matrisi,
  * uç güvenlik tablosu,
  * denetçi salt-okuma kümesi (izlendi kişinin kendi kaydı),
  * openapi,
  * 5 hata metni 7 dilde.

**Testte bulunan kusur:** pencere, liste yüklenmeden açılırsa
başlangıç adımını hiç ayarlamıyordu ve hep ilk adımda kalıyordu. Konum
artık veri geldiğinde bir kez seçiliyor.

## ÖLÇÜLEMEDİ

* **Gerçek YouTube oynatma.** Dev ortamında gerçek bir "liste dışı"
  video yok ve testler oynatıcıyı sahteliyor. Prod'da ölçülmesi
  gerekenler:
  * nocookie ile oynatma,
  * ENDED olayının gelmesi,
  * gizli video uyarısı (gizli bir videoyla),
  * CSP'nin tarayıcıda oynatıcıyı engellememesi.
* **Mobilde gerçek cihaz:** WebView'da oynatma, yatayda tam ekran,
  kaydırma hissi. Emülatör yok.
* **CSP'nin bütün sayfalara etkisi.** Bilinen iframe ve worker
  kaynakları tarandı, ama tarayıcıda tüm sayfalar gezilmedi.
  Dağıtımdan sonra tarayıcı konsolunda CSP ihlali aranmalı.

---

# §5 — GİRİŞ EKRANI E-POSTA SINIRI

## Ölçüm (değişiklikten önce)

| Yüzey | Alan | Önce | Şimdi |
|---|---|---|---|
| Web giriş (parola + kod ile giriş) | kimlik, e-posta kipi | 254 (sayı elle yazılmış) | 254 (`EPOSTA_SINIR`) |
| Web giriş | kimlik, telefon kipi | ülkenin uzunluğu | aynı |
| Web şifremi unuttum | e-posta | **256** (`EPOSTA_SINIR + 2`) | 254 |
| Web şifremi unuttum | tesis kodu | **254** (yanlışlıkla e-posta sınırı; sunucu 100) | 100 |
| Mobil giriş (parola + kod ile giriş) | kimlik, e-posta kipi | **SINIRSIZ** | 254 |
| Mobil şifremi unuttum | e-posta | **256** | 254 |
| Sunucu `LoginRequest.kimlik` | | 254 | 254 (`_G.EPOSTA`) |
| Sunucu `email`/`eposta` (giriş, kod, şifre sıfırlama) | | `EmailStr`, açık sınır yok | `GirisEposta` = `EmailStr` + `max_length=254` |

**Kusurun kökü (mobil):** P248'deki kimlik kipinin biçimlendiricisi
e-posta yazılırken metne **hiç dokunmuyordu**. Telefon kipinde ülke
uzunluğu sınırlıyordu ama e-posta kipinde hiçbir sınır yoktu.

**Sunucu zaten koruyordu:** `EmailStr` (email-validator) 254'ü aşan adresi
"too long" ile reddediyor; konteynerde ölçüldü (299 karakter → 422).
Sınır yine de şemaya **açıkça** yazıldı: doğrulayıcı kütüphane değişirse
giriş uçları sessizce sınırsız kalmasın.

**"+2" kaldırıldı:** `EpostaAlani` (web ve mobil) baştaki/sondaki boşluk
payı için 256'ya izin veriyordu. İstenen 254; ortak bileşen değiştiği
için kayıt, profil ve tanıtım formundaki e-posta alanları da 254 oldu.
Gönderimde değer zaten kırpılıyor.

## Testler

- Sunucu `test_p250_giris_eposta_siniri.py`: 255 karakterlik kimlik ve
  e-posta 4 uçta 422; 254 karakterlik geçerli adres sınır yüzünden
  reddedilmiyor.
- Web `p250-giris-eposta-siniri.dom.test.ts`: kimlik alanı e-posta
  kipinde 254, telefon kipinde daha kısa; şifremi unuttum e-posta 254,
  tesis kodu 100.
- Mobil `p250_giris_eposta_siniri_test.dart`: 300 karakter yazılınca kutuda
  254 kalıyor; 254'lük adres kırpılmıyor; telefon kipi biçimlenmeye devam
  ediyor; şifremi unuttum e-postası 254.

---

# §6 — HIZLI İŞLEMLER ÖZELLEŞTİRİLEBİLİR

## Ne değişti

P250 öncesi Özet sayfasındaki kart **sabit dört işlem** çiziyordu
(Tahsilat gir, Yeni talep, Duyuru yayınla, Personel ekle) ve bu
işlemler role göre süzülmüyordu. Şimdi:

| İstek | Yapılan |
|---|---|
| Hangi işlemlerin görüneceğini seçebilsin, sırasını değiştirsin | "Özelleştir" penceresi (web) / ekranı (mobil): onay kutusu + sıralama (web ↑/↓, mobil sürükle). En fazla 8 işlem |
| Seçenekler ROLE göre | Katalog **sunucuda** (`hizli_islem.KATALOG`, kimlik → roller). `GET /me/hizli-islemler` yalnız rolün görebildiklerini döner; yetkisiz kimlik yazılmaya çalışılırsa 422 |
| Hesaba kayıtlı, web ve mobilde aynı | `app_user.pano_tercihi.hizli_islemler` (P182'nin kaydı) |
| P182 altyapısı, ikinci sistem yok | Ayrı tablo ya da ayrı tercih kaydı açılmadı; aynı JSON kaydına yeni bir alan |
| Varsayılana dönme | `PUT /me/hizli-islemler {"secili": null}` → alan silinir, varsayılan (eski dört işlem) gelir |

**Katalog (14 işlem):** aidat (tahsilat gir), talep, duyuru, personel,
sakin, görev, ziyaretçi, borçlular, gider, rezervasyon, vardiya, anket,
rapor, kurulum.

* **Her işlemin web ve mobil karşılığı var.** Yalnız bir yüzeyde olan
  işlem kataloğa alınmadı (parite).
* **Rol süzmesi gerçek:**
  * güvenlik yalnız "ziyaretçi"yi,
  * denetçi yalnız "rapor"u,
  * güvenlik amiri görev / ziyaretçi / vardiyayı görür.
* **Bugün kartı gösteren yüzeyler:** web Özet (admin, yönetici) ve mobil
  yönetici ana ekranı. Katalog diğer roller için hazır.
* **Rol sonradan değişirse** yetkisi kalkan işlem okunurken sessizce
  düşer; kart yetkisiz bağlantı göstermez.

## Kayıt: neden ayrı uç

Web'in yerleşim kaydı (`PUT /me/pano-tercihi`) tercihi **bütün olarak**
yazıyor (P182 kararı) ve hızlı işlem seçimini taşımıyor. Seçim aynı
uçtan yazılsaydı:

* sürükle-bırak ile yapılan bir yerleşim değişikliği hızlı işlem
  seçimini silerdi,
* mobil, bilmediği web alanlarını ezerdi.

**Bu yüzden:**

* seçim kendi ucundan (`/me/hizli-islemler`) aynı JSON kaydına
  **birleştirilerek** yazılır,
* yerlesim kaydı, gövdede yoksa bu alanı **korur**.

İkisi de testle ölçüldü.

## Testler

* Sunucu `test_p250_hizli_islemler.py` (5):
  * varsayılan ve role göre seçenekler (yönetici, güvenlik, denetçi),
  * sıralı kayıt ve tekrar ayıklama, varsayılana dönüş,
  * yetkisiz ve bilinmeyen işlem 422,
  * yerleşim kaydı seçimi silmez,
  * 8 üst sınırı.
* Web `p250-hizli-islemler.dom.test.ts`: sıralı çizim; rol dışı seçenek
  görünmez; seç, sırala, kaydet gövdesi; varsayılana dön = `null`.
* Mobil `p250_hizli_islemler_test.dart`: aynı ölçümler, tel üzerindeki
  gövde.
* Kilit kayıtları:
  * rol matrisi ve uç güvenlik tablosu (sahiplik `kendi`),
  * denetçi salt-okuma kümesi (kişinin kendi ekran tercihi),
  * openapi,
  * hata metni.

## ÖLÇÜLEMEDİ

* Mobilde sürükle-bırak sıralamanın gerçek cihazdaki hissi (testte
  seçim + kayıt ölçüldü, sürükleme jesti ölçülmedi).

