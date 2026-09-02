# P205 — Çok yönlü giriş + vardiya zaman çizelgesi

**Tarih:** 2026-09-02

---

# 0. Uygulamadan ÖNCE yapılan iki ölçüm

Sen P204'te "ölçemediklerini uygulamadan önce doğrula" dedin. İkisini de
yaptım ve **ikisi de analizimi düzeltti.**

## 0.1 P204 tablosunda YANLIŞ olan üç satır

| İşlev | P204'te yazdığım | ÖLÇÜLEN gerçek |
|---|---|---|
| **Davet gönderme** | "mobilde yok, küçük iş" | **Kısmen VAR.** `residents_api.dart` / `staff_screen.dart`: mobilde sakin veya personel eklerken sunucu **otomatik davet gönderiyor**. Eksik olan şey davet **listesi + yeniden gönderme** (`/davetler`). |
| **Gider/gelir kaydı** | "mobilde yok, küçük iş" | **VAR.** `budget_api.dart` `POST /budget/entries` çağırıyor ve o uç **`FinansalHareket` yazıyor** (tek defter). Yani mobilde gelir/gider kaydı zaten yapılabiliyor. Eksik olan: fiş fotoğrafı ve onay akışı. |
| **Bütçe** | "salt okunur" | **Yazma var:** `POST /budget/categories` + `POST /budget/entries`. |

**Sonuç:** P204'ün öncelik listesindeki **3 (davet)** ve **4 (gider
kaydı)** maddeleri baştan yazılacak işler değil, **tamamlanacak** işler.
Bunu ölçmeden başlasaydım var olan bir şeyi yeniden yazıyor olacaktım —
uyarın yerindeydi.

## 0.2 SSO ile giren çok tesisli yönetici — ÖLÇÜLDÜ, hata YOK

Ölçüm (`pg_indexes` + `pg_proc`):

```
uq_oauth_kimlik_subject       UNIQUE (saglayici, subject)   ← PLATFORM GENELİNDE
uq_oauth_kimlik_user_saglayici UNIQUE (user_id, saglayici)

tenant_id_by_oauth: SELECT tenant_id FROM oauth_kimlik
                    WHERE saglayici = ? AND subject = ?
```

`(saglayici, subject)` **platform genelinde tekil**. Yani bir Google
hesabı tüm platformda **tek bir `app_user` satırına** bağlanabilir ve
`tenant_id_by_oauth` **belirsiz olamaz**.

**Cevap:** SSO ile giren çok tesisli yönetici, **kimliğini bağladığı
tesise** düşüyor. Rastgele değil, deterministik. **Ayrı bir hata yok.**

Gerçek sınır şu: aynı Google hesabını **ikinci** bir tesise
bağlayamıyor. Ama P203 §2'den beri uygulama içinden geçiş var, yani
bağlı olduğu tesise girip ötekine geçiyor.

**Karar:** SSO girişinden sonra da — parola girişinde olduğu gibi —
üyelik listesi >1 ise **tesis seçimi gösterilecek**. Böylece üç giriş
yolu (parola / kod / SSO) aynı davranışı gösterir.

---

# 1. Çok yönlü giriş — BACKEND BİTTİ

## K1.1 — Ayrım `@` işaretine bakar, sezgiye değil

`app/kimlik.py`: **`@` varsa e-postadır.** Tahmin değil — hiçbir telefon
numarası `@` içermez, hiçbir e-posta `@`sız olamaz (RFC 5321). Rakam
sayısına ya da uzunluğa bakan bir sezgi `1234@ornek.com` gibi adreslerde
yanılırdı; test onu da kapsıyor.

Telefon **E.164'e normalize edilir**: `"0532 111 22 03"`,
`"+90 532 111 22 03"`, `"(0532) 111-22-03"` aynı kişidir. Normalize
etmeden aramak, kullanıcının boşluk koyup koymamasına göre giriş
yaptırmak olurdu.

## K1.2 — Ölçüm bir kusur gösterdi: ülke kodu iki kez ekleniyor

```
normalize_phone("905321112203") -> +90905321112203     ← ölçüldü
```

`+` yoksa ve rakamla başlıyorsa başına `+90` ekliyor; girdinin **zaten
ülke kodu taşıdığını** görmüyor. `905...` numarayı yazmanın çok yaygın
bir biçimi — yeni tek alanda bu, **girişin sessizce başarısız olması**
demekti.

**`normalize_phone`'u değiştirmedim** ve bu bilinçli: o fonksiyon
**kullanıcı yaratma** anında da çalışıyor ve **saklama biçimini**
belirliyor. Davranışını değiştirmek, eskiden o yolla yazılmış satırları
erişilemez kılabilirdi — bu turda onları ölçmedim.

Telafi **yalnız giriş yolunda** (`kimlik.py::_ulke_kodunu_duzelt`), dar
bir kuralla: girdi tamamen rakamsa, `90` ile başlıyorsa ve 12 hane ise
başına `+` konur. Kusurun kendisi bir testle **kayıt altında** — biri
`normalize_phone`u düzeltirse test uyarıyor.

## K1.3 — `tenant_slug` artık opsiyonel

| Durum | Davranış |
|---|---|
| Tek üyelik | Doğrudan giriş — **seçim gösterilmez** |
| Birden çok | **409 `tesis_secimi_gerekli`**, jeton **üretilmez** |
| Slug verilmiş | Yalnız o tesis denenir (eski davranış) |

Rastgele birini seçmek, kullanıcıyı **bilmediği bir tesise sokmak**
olurdu. Slug'ı zorunlu bırakmak ise P203 §2'de web'de düzeltilen
şikâyetin ta kendisiydi.

## K1.4 — Sızdırmama: hepsi aynı 401

Çözülemeyen kimlik · bilinmeyen kimlik · yanlış parola · pasif hesap ·
üye olunmayan slug → **hepsi aynı durum + aynı kod + aynı metin**. Bir
test bu beş imzanın **tekil** olduğunu kilitliyor.

Metin de tür söylemiyor: eski `giris_bilgileri_hatali_email` yerine
**`giris_bilgileri_hatali`** ("Giriş bilgileri hatalı."). *"E-posta
hatalı"* demek, saldırgana girdisinin hangi dala girdiğini söylerdi.
Eski metinler duruyor — telefona özel `login-phone` ucu onları
kullanmaya devam ediyor.

`/auth/tesislerim`de çözülemeyen girdi **hata değil, boş liste**; ve
parolada `minLength` **yok**: bu bir doğrulama ucu değil **arama**
ucudur, "parolan çok kısa" demek hesabın varlığından bağımsız bir sinyal
vermek olurdu.

## K1.5 — Eski istemciler kırılmıyor

`LoginRequest.email` alanı **duruyor** ve `kimlik` boşsa ondan
dolduruluyor. Mobil uygulama mağazadadır; eski sürümler bir süre daha
`email` gönderecek ve alanı zorunlu kılmak **güncellemeyen kullanıcıların
girişini kırmak** olurdu (P202'de eklenen zorunlu güncelleme bile anında
yayılmaz).

## K1.6 — Telefon benzersizliği KALDIRILMADI

P204 kararı korundu. Göç 0095 kısıtı **görmezden gelmiyor, ondan
faydalanıyor**: telefonla eşleşme en fazla **bir** satır döndürür,
dolayısıyla telefonla girişte tesis seçimi zaten çıkmaz. Ölçüldü:
`tesislerim` e-postayla **2**, telefonla **1** tesis döndü.

## Ölçüm — akış gerçekten sürüldü

```
E-POSTA (tek tesis)      -> 200 jeton
TELEFON                  -> 200 jeton
TELEFON (5 farklı yazım) -> 200 jeton
ESKİ istemci (email)     -> 200 jeton
YANLIŞ parola            -> 401  ┐
BİLİNMEYEN e-posta       -> 401  │ hepsi AYNI kod + AYNI metin
BİLİNMEYEN telefon       -> 401  │
ÇÖZÜLEMEYEN girdi        -> 401  ┘
ÇOK TESİS (slug yok)     -> 409 tesis_secimi_gerekli, jeton YOK
ÇOK TESİS + slug         -> 200 jeton
tesislerim e-posta / tel -> 2 tesis / 1 tesis
```

| Kilit kanıtı — bozma | Düşen test |
|---|---|
| Çok tesiste ilkini seç | ÇOK TESİS SEÇİM İSTER |
| Çözülemeyen girdiye özel 422 | TÜM BAŞARISIZ DURUMLAR AYNI YANIT |

Testler: kimlik ayrımı 19, uç davranışı 18 (izolasyon kilidi dahil).
Kilit registreleri (sözleşme, hata metinleri, denetçi) 78 test yeşil.

## K1.7 — SSO ile giren çok tesisli yönetici hangi tesise düşüyor? (ÖLÇÜLDÜ)

Soru bir ölçüm sorusuydu; ölçüldü (`backend/tests/test_p205_sso_coklu_tesis.py`,
3 test):

```
uq_oauth_kimlik_subject   UNIQUE (saglayici, subject)   <-- GLOBAL (göç 0048)
```

Bir Google hesabı **platform genelinde tek bir kullanıcıya** bağlanır.
Sonuçlar:

1. **Yanlış tesise düşme diye bir şey yok.** SSO girişi daima bağlantının
   kurulduğu tesise düşer; belirsizlik yok çünkü eşleşme tek. Ölçüldü:
   A'ya bağlı kimlik `_kimligi_coz` ile A'ya çözüldü (`tur=giris`,
   `tenant_id=A`), B'ye değil.
2. **Ama ikinci tesise SSO ile ULAŞILAMIYOR.** Aynı Google hesabını B
   tesisindeki hesaba bağlamak benzersiz indeksle reddediliyor
   (`UniqueViolation` ölçüldü). Yani SSO'yla giren çok tesisli yönetici
   yalnız bir tesisine SSO ile girebilir.

(2) bir çıkmaz değil ve **kısıtı gevşetmiyoruz**: giriş sonrası
`/me/tesislerim` + `/me/tesis-degistir` (P203 §2) kişiyi öteki tesise
parola sormadan geçiriyor — uçtan uca sürüldü: A jetonu → liste (B'de rolü
`resident`) → geçiş → `/me` `tenant_id=B`.

Kısıtı kaldırmanın bedeli: `(saglayici, subject)` benzersizliği kalkarsa
SSO geri dönüşünde "bu Google hesabı hangi kullanıcı?" sorusunun tek
yanıtı olmaz; callback'in **jeton üretmeden önce** tesis sorması gerekir
ve o ekran, henüz kimliği doğrulanmamış bir oturumda tesis adlarını
listeleyen yeni bir sızıntı yüzeyi açar. Mevcut çözüm (tek bağ + uygulama
içi geçiş) aynı sonucu bu yüzey olmadan veriyor.

## K1.8 — Mobil: tek alan, biçimlendirici KALDIRILDI

Mobil giriş ekranındaki `TelefonBicimlendirici` **rakam dışını yutuyordu**
— yani aynı alana e-posta fiziksel olarak yazılamazdı. Kaldırıldı;
klavye `emailAddress`, alan doğrulaması yalnız **boşluk** denetimi yapıyor
("geçerli bir telefon girin" demek e-posta yazanı engellerdi). Geçersiz
kimlik sunucudan **jenerik 401** alır; belirsizlik orada bilinçli.

Taşıma ikiye ayrık kalıyor ve bu bilinçli: `@` içermeyen girdi
`/auth/login-phone`a gider çünkü **ilk giriş akışı** (geçici kod →
`setup_token`) yalnız orada. Kullanıcı bu ayrımı görmez.

**Mobilde kodla giriş EKRANI YOK** (ölçüldü: `girisKodla*` sözlük
anahtarları var ama hiçbir ekran kullanmıyor; P149'dan kalma). Yani
"kodla giriş de her iki kimlikle çalışsın" maddesi mobilde **kırılmadı,
zaten yoktu**. Web'de iki kimlikle de çalışıyor. Mobil kod ekranı ayrı bir
turun işi.

## K1.9 — Çok tesis seçimi mobilde: merkez pencere

Alt sayfa (`showModalBottomSheet`) **kullanılmadı**: tur 31'de uygulamada
tek pencere biçimine geçildi ve `merkez_diyalog_test` bunu kaynak
taramasıyla kilitliyor. Seçim penceresi **kapatılabilir**: kullanıcı
vazgeçip başka bir hesapla girmek isteyebilir.

Seçimden sonra **ikinci bir giriş** yapılır (aynı kimlik + parola + slug).
İlk istekte jeton üretip beklemek, kullanıcı seçmeden önce bir tesise
bağlanmak olurdu.

### Ölçüm — mobil akış sürüldü (taklit HTTP adapter'ında, P200 dersi)

`mobile/test/p205_coklu_kimlik_giris_test.dart` — 7 test:

```
e-posta yazıldı  -> POST /auth/login {kimlik, password}   (telefon ucu ÇAĞRILMADI)
telefon yazıldı  -> POST /auth/login-phone {phone:+905321112203}
409 geldi        -> seçim penceresi + roller; /auth/tesislerim {kimlik,password}
seçim yapıldı    -> ikinci /auth/login, tenant_slug=city-ambiance
tek tesis (200)  -> seçim YOK, üyelik ucu ÇAĞRILMADI
boş kimlik       -> hiç istek yok, alan hatası
```

Kilit kanıtı: `girisYap`taki `@` ayrımı bozulunca (her şey telefon yoluna
gider) 3 test düştü — `/auth/login` hiç çağrılmadı, seçim penceresi
çıkmadı. Geri alındı.

Bu turda güncellenen kilitler (davranış gerçekten değişti):
`denetim_notlari` (App Store denetim notu artık "tek alan" diyor,
demo hesapları için telefon sütunu öneriliyor), `giris_profil_personel_i18n`
(etiket + doğrulama metni + **yerleşim kilidi** yeniden üretildi),
`login_screen_phone`, `login_remember_checkbox`.

Mobil tam takım: **2012 geçti**, 3 atlandı.

---

# §2 — VARDİYA PLANLAMA ARAYÜZÜ (ZAMAN ÇİZELGESİ)

## Ölçüm — neyin eksik olduğu

P203 §4'te plan satırı saatlerini **daima şablondan** alıyordu
(`vardiya_plani.shift_id NOT NULL`, saat yok). §2'nin "Hızlı Vardiya
Ekle" penceresi ise **başlangıç/bitiş saati** soruyor. Yani istenen ekran
mevcut modelle **yazılamıyordu**: "bu hafta Ali 14:00–22:00 kalsın"
demek için önce kalıcı bir vardiya şablonu tanımlamak gerekirdi.

## K2.1 — Serbest saat: şablon KALDIRILMADI, yanına eklendi (göç 0096)

`shift_id` **nullable** oldu; satıra `baslangic_saat`/`bitis_saat`
eklendi. CHECK: satır ya bir şablona bağlıdır ya kendi saatlerini taşır
(ikisi de boşsa saati olmayan bir vardiya olurdu; çakışma ve mesai hesabı
onu sessizce 0 saat sayardı).

Şablon **duruyor**: varsayılan kadro ve `haftayi-doldur` tohumlaması ona
dayanıyor — kaldırmak, yirmi kişilik bir ekipte her hafta yüzlerce
tıklama demekti. Şablonlu satırda da saat doldurulabilir: o günlük sapma
("bugün 1 saat erken çıkıyor") **şablonu değiştirmeden** yazılır. Şablonu
güncellemek, o vardiyadaki **herkesin** saatini sessizce değiştirmek
olurdu (test: `test_SAAT_DEGISTIRME_SABLONU_DEGISTIRMEZ`).

Okuma kuralı **tek yerde**: `app/vardiya.py::plan_araligi`. Üç yerde
lazım (çizelge, çakışma denetimi, mesai) ve ayrı ayrı yazılsaydı, birinde
unutulan bir dal kullanıcının yazdığı saati sessizce şablondan okurdu.
Mesai sorgusu da `join` → `outerjoin` yapıldı: serbest vardiyalar
**ücret hesabından düşerdi**.

## K2.2 — Çakışan günler ASLA sessizce atlanmaz (isteğin en sert şartı)

Uç iki aşamalı ve **hata zarfı kullanmıyor**:

1. `cakisanlari_atla=false` (varsayılan) + çakışma varsa: **hiçbir şey
   yazılmaz**, `uygulandi=false` döner ve çakışan günler **tarih tarih**
   listelenir.
2. Kullanıcı "Çakışanlar hariç ekle" derse istemci bayrağı açar; o zaman
   çakışanlar atlanır ve yanıt gün gün ne olduğunu söyler.

`APIError` **kullanılmadı**: hata zarfı sözleşmede sabittir ve serbest
bir gün listesi taşıyamaz — kullanıcıya "bir yerde çakışma var" deyip onu
tek tek aramaya göndermek olurdu. Sessizce atlamak ise yöneticinin
"on dört gün ekledim" sanıp yedi gün eklemesi demekti; eksiği ancak
sahada fark ederdi.

Yazma **iki geçişlidir** (önce ölç, sonra yaz): "hepsi ya da hiçbiri"
kuralını yazdıktan sonra geri almaya çalışmak, yarım yazılmış bir plan
bırakma riski taşırdı. İkinci geçişte çakışma **yeniden** denetlenir —
aynı döngüde eklenen satırlar da çakışabilir.

**P203 kararı korundu**: kesin red yalnız çakışmada. Günlük 11 saat ve
haftalık 45 saat **uyarıdır** ve toplu eklemede de yanıtta döner
(`test_HAFTALIK_ASIM_UYARISI_toplu_eklemede_de_doner`) — uyarıyı yutmak,
maliyeti görünmez kılardı.

## K2.3 — Gece aşırı vardiya

`vardiya_araligi` (P203) zaten bitiş ≤ başlangıç olduğunda ertesi güne
taşıyor. §2'de iki şey eklendi: çizelge **bir gün geriye açık** sorgular
(önceki gecenin bloğu sabah saatlerinde ekranda hiç görünmezdi) ve
`gece_asiyor` bayrağı sunucuda üretilir — istemci `baslar`/`biter`den
çıkarabilirdi ama aynı kuralı web'de ve mobilde ayrı hesaplamak, birinin
sapması demekti.

## K2.4 — Bloklar SÜRÜKLENMİYOR (karar + gerekçe)

**Hayır.** Sürükleme "kolay" görünür ama bedeli sessizdir:

- Dokunmatik ekranda **kaydırma ile sürükleme aynı harekettir**; çizelge
  zaten yatay kaydırılıyor. Yanlışlıkla bırakılan bir blok, kimsenin fark
  etmediği bir vardiya değişikliği üretir.
- Değişiklik **denetime "yönetici değiştirdi" diye yazılır** — yani
  kazayla yapılan değişiklik, kasıtlı olandan ayırt edilemez.
- Bir vardiyanın saati **maaş demektir** (§5 fazla mesaiyi buradan
  hesaplıyor). Piksel hassasiyetiyle belirlenen bir saat, 15 dakikalık
  kaymalarla ücrete geçerdi.

Yerine: bloğa tıklanır, tarih/saat **yazılır**, kaydedilir (`PATCH`).
Açık, geri alınabilir ve denetim kaydı "önceki → yeni" olarak anlamlı.

## K2.5 — Mobilde çizelge YOK, gün gün LİSTE var (karar + gerekçe)

Mobile aynı zaman çizelgesi **getirilmedi**. 360 dp genişlikte 24 saatlik
eksen ancak ~15 px/saat'e sığar: blok üstündeki saat metni okunmaz,
dokunma hedefleri 44 dp'nin altına düşer ve bir satırı görmek için sürekli
yatay kaydırmak gerekir. Sahadaki soru zaten **"bugün kim var, sırada
kim var"**dır; liste bunu tek bakışta yanıtlar.

Ama mobil ekran **çizelge ucuna geçirildi**: izgara ucu yalnız şablona
bağlı slotları döndürüyor ve **web'den serbest saatle eklenen bir vardiya
sahada hiç görünmezdi** (ölçüldü, test `CIZELGE ucundan okur`). Mobilde
görüntüleme + hızlı ekleme + çıkarma var; blok saati düzenleme yok
(yazma alanı dar, web'de yapılır).

Mobil hızlı eklemede personel listesi `getFieldStaff` yerine yeni
`tumPersonel` kullanıyor: eski liste yalnız `security` +
`tesis_gorevlisi` döndürüyordu, oysa vardiya **güvenlik amirine** de
yazılabiliyor — listede olmayan birine mobilde vardiya yazmak imkânsız
olurdu.

## K2.6 — Görünüm seçici: saat ekseni her zoom'da anlamlı değil

GÜN İÇİ (56 px/saat) ve HAFTA (12 px/saat) ekseni **saattir**; hafta
görünümünde saat etiketleri yalnız 0/6/12/18'de yazılır (12 px'e "13:00"
sığmaz ve üst üste binen etiket hiçbir şeyi okunur yapmaz). AY
görünümünde eksen **gündür**: 31 × 24 = 744 sütun hiçbir ekranda okunmaz
ve yatay kaydırma bunu kullanılabilir yapmaz. Ayda sorulan soru zaten
"hangi **günler** çalışıyor"dur.

Sol isim sütunu **sabit**: yatay kaydırmada isim kaybolursa hangi satıra
bakıldığı anlaşılmaz. Vardiyası olmayan personel de satırda durur — "kim
boşta" da bir plan sorusudur ve atanacak kişi ekranda görünmeli.

P203'ün iki özelliği **korundu**: "şu an görevde / sıradaki" kartı ve
"haftayı kadrodan doldur".

## Ölçüm — akış gerçekten sürüldü

Backend (`test_p205_vardiya_cizelge.py`, **16 test**):

```
çizelge: saatler ÇÖZÜLMÜŞ döner (08:00–16:00, şablon adıyla)
vardiyası olmayan personel de listede
22:00–05:00 -> iki güne yayılır; ERTESİ GÜN sorgusunda da görünür
5 günlük aralık -> 5 kayıt
çakışma + atla=false -> uygulandi=false, eklenen=0, HİÇBİR ŞEY YAZILMADI
çakışma + atla=true  -> eklenen=2, çakışan=1, hangi gün olduğu yanıtta
ters aralık / 40 gün -> 422
70 saatlik hafta     -> haftalik_normal_asildi UYARISI (red değil)
şablonsuz vardiya çakışma denetimine GİRER (outerjoin)
PATCH saat -> satıra yazılır, ŞABLON değişmez; kendi satırıyla çakışmaz
PATCH -> denetime "önceki/yeni" ile yazılır
saha okur/yazamaz · sakin göremez · başka tesisin bloğu görünmez
```

Web (`p205-vardiya-cizelge.dom.test.ts`, **13 test**) ve mobil
(`p205_vardiya_cizelge_test.dart`, **7 test**) akışın tamamını sürüyor;
mobil taklidi HTTP adapter'ında (P200 dersi).

**Kilit kanıtı — bozma:** `toplu_ekle`de çakışma dalı kapatıldı
(sessizce atlansın); `test_CAKISAN_GUNLER_SESSIZCE_ATLANMAZ_once_SORULUR`
`assert True is False` ile düştü, diğer 15 test geçti. Geri alındı.

Bu turda güncellenen kilitler: `contracts/openapi.yaml` (3 uç + 7 şema),
`rol-matrisi.txt` (3 satır), `hata_metinleri.py` (2 kimlik),
`p203-vardiya-plani.dom.test.ts` → `p205-vardiya-cizelge.dom.test.ts`,
`p203_vardiya_plani_test.dart` → `p205_vardiya_cizelge_test.dart`.

**Ölçemediğim:** gerçek cihazda dokunma hedefleri ve yatay kaydırma
hissi; web çizelgesinin geniş ekrandaki performansı (31 günlük ay
görünümünde 20+ personel satırı) ölçülmedi — testler jsdom'da düzen
hesabı yapmaz.
