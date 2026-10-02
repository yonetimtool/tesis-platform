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
