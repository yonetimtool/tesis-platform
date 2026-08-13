# P155r2 — Kayıt ve giriş sisteminin yeniden inşası

> Dal: `main` · Commit'ler: `1def845`, `4ef6beb` · **Canlıya deploy YOK,
> build numarasına dokunulmadı** · GitHub'a push edildi · Doğrulama test
> sunucusunda (`api-test.yonetio.site`).

Şartnamenin en çok vurguladığı madde envanterdi ("**en önemlisi**"), o
yüzden rapor oradan başlıyor.

---

## 1. ESKİ AKIŞ ENVANTERİ — ne vardı, ne silindi

Depoda **üç ayrı** kayıt yolu birikmişti. Şartnamenin saydığı her maddeyi
tek tek ölçtüm:

| # | Yol | Uçlar / ekranlar | Yeni sistemde karşılığı | Karar |
|---|---|---|---|---|
| 1 | **P148 — sakin kendi başvurur** | `POST /auth/kayit/basla`, `POST /auth/kayit/dogrula`, `/kayit-basvurulari` (listele/onayla/reddet) | **YOK** | 🗑 **SİLİNDİ** |
| 2 | **P154 — rol seçimli kayıt** | `POST /auth/kayit/rol-basla`, `/rol-dogrula` | **VAR** — şartname ADIM 3'ün ta kendisi | ✅ korundu, sırası değişti |
| 3 | **P155r1 — davet bağı** | `/davet/*` | **VAR** — birincil yol | ✅ korundu, SMS metni zenginleşti |

### 1a. Silinen: P148 onay akışı

**Ne yapıyordu:** tesis kodu + blok/daire + telefon ile başvuru açılır, SMS
ile telefon doğrulanır, başvuru **yönetici onayına** düşer, onaylanınca
hesap açılırdı.

**Neden karşılığı yok — iki bağımsız sebep:**

1. **Yeni kural bunun tam TERSİ.** Şartname KISITLAR: *"yalnız önceden
   eklenmiş telefonla eşleşen kaydolur"*. P148'de hesabı **olmayan** biri
   başvuruyordu ve doğrulama daire sahipliği değil, **tesis kodunu
   bilmekti**. Onay adımı (0038) zaten o açığı kapatmak için sonradan
   eklenmişti; açık kalkınca onayın da sebebi kalmadı.
2. **Hiç kullanılmıyordu.** Ölçüldü: ne mobil ne web bu uçları çağırıyor —
   yalnız testler. Yani silinen şey **canlı bir yol değil, ölü bir yoldu**.

**Silinenler (dosya dosya):**

- `backend/app/routers/kayit_basvurulari.py` — **dosya tamamen kaldırıldı**
- `backend/app/routers/auth.py` — `kayit_basla`, `kayit_dogrula` gövdeleri
  + artık ölü kalan `_telefon_maskele`, `_KAYIT_KOD_OMRU_DK`,
  `_KAYIT_MAX_DENEME` ve 6 ölü import
- `backend/app/schemas.py` — `KayitBaslaRequest/Response`,
  `KayitDogrulaRequest`, `KayitBasvuruOut/Listesi`
- `backend/app/main.py` — router kaydı
- `contracts/openapi.yaml` — 3 yol (`/auth/kayit/basla`, `/dogrula`,
  `/kayit-basvurulari` ×3 operasyon) + 5 şema
- `backend/tests/test_sakin_kaydi.py` — **dosya tamamen kaldırıldı**
- `backend/tests/yetki/rol-matrisi.txt` — 5 satır (kilit yeniden üretildi)

### 1b. VERİ ETKİSİ — silmeden önce ölçüldü

**Veri kaybı YOK.** Silinen şey kod; şema ve veri **duruyor**:

| Nesne | Karar | Gerekçe |
|---|---|---|
| `kayit_dogrulama` tablosu | **DURUYOR** | `amac='giris'` ve `'oauth'` kodları hâlâ kullanıyor |
| `kayit_durum` enum'u | **DURUYOR** | Enum değeri geri alınamaz; `göç-tersinirlik` kapısını kırardı |
| `Action.KAYIT_ONAY/KAYIT_RED` | **DURUYOR** | Geçmiş `audit_log` satırlarını tanımlıyor; kaldırmak onları anlamsızlaştırırdı |
| Bekleyen başvurular | **YOK** | Ölçüm: silme anında `kayit_dogrulama` = **0 satır** |

Yani **kimsenin bekleyen başvurusu kaybolmadı** ve göç geri alınabilir
(hiçbir DDL yazılmadı — bu turda **yeni göç YOK**).

### 1c. `POST /tenants` — silinmedi, bilinçli

Şartname bunu envantere sokmuştu. Kararım: **kaldırılmadı, birincil
olmaktan çıkarıldı.**

- **Kaldırılmama sebebi:** platform sahibinin destek işlerinde (bir tesisi
  elle açmak) ve **tohum/demo verisinde** tek yol. **KİLİTLİ KURAL 2**
  gereği iki mağazanın incelediği demo hesapları buna bağlı; kaldırmak
  onları kırardı.
- **Değişen:** yönetici artık ondan geçmiyor. Normal akışta admin adımı
  **yok**.

### 1d. RLS testleri silinmedi, TAŞINDI

`test_kayit_dogrulama_rls.py` iki testini P148 uçları üzerinden sürüyordu.
**Ölçülen risk hâlâ geçerli** (`kayit_dogrulama` kimlik öncesi okunuyor;
tenant çözücü + tenant-üzeri ezme). Bu yüzden testler silinmedi, yaşayan
bir uca (`/auth/giris/kod-iste` + `/kod-dogrula`) bağlandı — kapsam korundu.

---

## 2. YENİ KAYIT AKIŞI — ne yapıldı

### ADIM 1 · ROL — değişmedi
Mobil dört rol (Yönetici · Site sakini · Güvenlik · Tesis görevlisi).
Web ayrı küme sunuyor (yönetici + denetçi); denetçinin mobil yüzeyi yok
(KİLİTLİ KURAL 4).

### ADIM 2 · KİMLİK YÖNTEMİ — **sıra düzeltildi**
Eskiden `rol → tesis kodu+telefon → yöntem`. Şartname §2 yöntemi rol
seçiminden **hemen sonra** istiyor. Yeni sıra:

```
rol → YÖNTEM → bilgiler(ad, telefon[, parola]) → ROLE ÖZEL [→ kod]
```

Ekranda önce sosyal düğmeler, sonra `─── veya ───` ayracı, sonra
"E-posta/telefon ile kaydol" — şartnamenin çizdiği düzen.

**Sosyal seçilirse ad soyad forma otomatik dolar** ve kullanıcı
düzeltebilir (`Kimlik.ad`, `id_token`'ın `name` iddiası).

### ADIM 3 · ROLE ÖZEL

**Yönetici → "Tesis adını giriniz"** → `POST /auth/kayit/tesis-olustur`
tek istekte tesisi açar, kodu üretir, oturumu açar. **Admin paneli adımı
yok.** Ardından **tesis kodu ekranda gösterilir ve kopyalanabilir**
(şartname §4 — SMS sağlayıcısı bağlanana kadar tek dağıtım yolu bu).

**"Zaten bir sitem var"** → tesis kodu alanına geçer.

**Sakin / güvenlik / tesis görevlisi** → tesis kodu (+ sakinde daire) →
telefon + kod eşleşmesi.

### ADIM 4 · Ana ekran
`kurulum_tamamlandi=true` dönüyor, çünkü o bayrağın tek işi "birincil
yönetici tesisi adlandırdı mı" sorusunu yanıtlamaktı ve ad **bu istekte**
geldi. `false` bıraksaydık kullanıcıyı az önce yazdığı adı tekrar yazdığı
bir ekrana düşürürdük.

---

## 3. VERİLEN KARARLAR VE GEREKÇELERİ

### 3.1 "Zaten bir sitem var" — şartname kendi içinde çelişiyordu

**Çelişki:** §3 *"tesis kodu girme ekranı açılır, ikinci/üçüncü yönetici
böyle katılır"* diyor. KISITLAR ise *"Kod bilen biri kayıt olamamalı"*
diyor. Tesis kodu **kamuya açık ve tahmin edilebilir** (göç 0037 güvenlik
notu: adın ilk 4 harfi + kayıt tarihi).

İkisini birlikte uygularsak: **kodu bilen herkes yönetici olur** → tesisin
tamamen devralınması.

**Kararım — KISITLAR kazandı.** "Katılma" tesis açma değil, `rol=yonetici`
ile yapılan sıradan bir **rol eşleşmesidir**: ikinci yönetici de mevcut
yönetici tarafından **önceden eklenmiş** olmalı. Ekranda şartnamenin
istediği bağ duruyor, arkasındaki mekanizma güvenli olan.

### 3.2 Tesis kodu üretimi — **istemciden alınmıyor**

Kural veritabanı tetikleyicisinde (göç 0037, yerelden bağımsız hâle
getirilmesi 0041). Şartnamenin saydığı kenar durumlarının hepsi orada
çözülmüş durumda; bu tur onları **ölçtü**:

| Kenar durum | Davranış | Test |
|---|---|---|
| Türkçe harf (`Şişli Güneş`) | `SISL-` | ✅ |
| `i`/`I` (`istanbul konaklari`) | `ISTA-` (yerelden bağımsız) | ✅ |
| 4 harften kısa (`As`) | `ASXX-` (`X` ile doldurulur) | ✅ |
| Rakamla başlayan (`34. Cadde Sitesi`) | `CADD-` (rakam/noktalama atılır) | ✅ |
| Hiç harf yok (`1234 5678`) | `XXXX-` (500 değil) | ✅ |
| Aynı gün aynı ad | Rastgele **iki haneli** ek: `OLTU-260715-47` | ✅ |
| **Ad sonradan değişirse** | **Kod SABİT kalır** | ✅ |

Son satır bilinçli: kod bir **kimliktir**. Ad düzeltilince değişseydi
dağıtılmış kodlar (SMS'ler, panolar, yöneticinin not defteri) ölürdü.

### 3.3 Telefon normalizasyonu — zaten vardı, ölçüldü
`normalize_phone` `0532` / `532` / `+90532` / `0090532` biçimlerinin
hepsini `+90532…`'ye indiriyor. Dört biçim için test yazıldı.

### 3.4 Hata metinleri — ne ifşa ediliyor, ne edilmiyor

- **Eşleşme uçları** (`rol-basla`, `oauth/baglan/basla`): numaranın o
  tesiste kayıtlı olup olmadığı **söylenmez**; yanıt eşleşme olsa da
  olmasa da aynıdır ve SMS yalnız eşleşmede gider.
- **`tesis-olustur`** (409 `telefon_zaten_kayitli`): burada **ayırt edici**
  hata veriliyor ve gerekçesi farklı — numara **kullanıcının kendi
  numarası**. "Zaten kayıtlısın, giriş yap" demek onu doğru kapıya yollar.
  Belirsiz bir hata verseydik, hesabı olan yönetici her seferinde aynı
  duvara çarpar ve desteğe yazardı. **Numara taramasını engelleyen şey
  burada hata metni değil, önündeki hız sınırıdır.**

### 3.5 Kaba kuvvet koruması
`tesis-olustur` telefon başına **3 istek / 15 dk** (`hiz_siniri`, kapsam
`tesis_olustur` — kayıt/giriş sayaçlarından **ayrı**). Sayaç
**doğrulamadan önce** artar; sonra saymak ucu bir "bu numara kayıtlı mı"
sorgulama aracına çevirirdi.

### 3.6 Sosyal hesap + telefon çakışması → **tek hesap, iki yöntem**
`oauth_kimlik` satırı her zaman **var olan** bir `app_user`a bağlanır;
`tesis-olustur` sosyal yolda numara **boş olmak zorunda** (409). Yani aynı
telefon iki ayrı hesap açamıyor. Kullanıcı yöntemlerini sonradan
ekleyip kaldırabiliyor (`/auth/oauth/baglantilarim`) ve **son giriş yolu
kaldırılamıyor**.

### 3.7 Apple private relay
`…@privaterelay.appleid.com` **kalıcı değildir**, bu yüzden hiçbir yerde
eşleşme anahtarı değil — yalnız "hangi hesabı bağladım" sorusunu
yanıtlıyor ve `app_user.email`i **ezmiyor**.

**Apple ad soyad vermiyor** ve bu kabul edildi: Apple adı yalnız *ilk*
yetkilendirmenin `form_post` gövdesinde gönderir, `id_token`'da hiç yok.
Alan boş gelir, kullanıcı yazar — **yalnız ilk girişte çalışıp sonra
sessizce bozulan** bir özellikten iyidir.

### 3.8 Kayıt yarıda kesilirse → **böyle bir ara durum yok**
Tesis + yönetici + (sosyal yolda) kimlik bağı **tek transaction**.
Biri patlarsa hiçbiri kalmaz; kullanıcı yanıt almadan çıkarsa geriye tesis
de kalmaz. Bu özellikle sosyal yolda önemli: önce tesisi açıp sonra kimlik
bağlamak, bağlama patladığında (o Google hesabı başkasına bağlı)
**sahipsiz bir tesis** bırakırdı.

### 3.9 Parola iki kez sorulmuyor
Kullanıcı parolasını 3. adımda giriyor. Eşleşme yolunda sunucu kod
doğrulanınca `setup_token` döner ve normalde `/set-password` ekranı
açılırdı — az önce yazdığı parolayı tekrar sordururdu. Jeton alınır
alınmaz parola **otomatik** gönderiliyor; ekran hiç görünmüyor. (Ekran
korundu: davet ve geçici kod yolları hâlâ kullanıyor.)

---

## 4. SMS (§4) — şablon hazır, gönderim dürüst

Davet mesajına **tesis kodu** ve **mağaza bağlantıları** eklendi:

```
{Tesis} sizi Yönetio'ya davet etti. Tesis kodu: OLTU-260715.
Kaydolmak için: https://…/davet/‹jeton› Android: https://play.google.com/…
```

- **Kod neden de gidiyor** (bağ zaten her şeyi taşırken): bağ **tek
  kullanımlık ve süreli** (30 gün). Süresi dolarsa ya da tüketilirse elde
  kalan tek şey koddur ve kullanıcı elle kayıt yolundan devam eder.
- **App Store bağlantısı yapılandırılmamışsa EKLENMEZ** — uydurma bir id
  ile her alıcıya kırık bağlantı göndermek, hiç göndermemekten kötüdür.
- **Sağlayıcı yokken sessizce "gönderildi" DEMİYOR:** `gonderim` katmanı
  `YapilandirilmamisSaglayici` ile `durum='basarisiz'` döner; panel
  "gitmeyen davetler"i gösterir ve yönetici kodu kopyalayıp elle iletir.
- **Dürüst maliyet notu:** Türkçe karakter SMS'i 70 karaktere düşürür; bu
  metin **3–5 parçaya** bölünüyor. Kabul edildi (alternatif şartnamenin
  açık maddesini boşa düşürürdü). Doğru çözüm bağ kısaltmaktır ve
  **ayrı bir iştir** — burada yapılsaydı jeton uzunluğu ile güvenlik
  arasında aceleci bir takas yapılmış olurdu.

---

## 5. GÖÇ PLANI (§6) — **uygulanmadı, çünkü gerekmiyor**

Şartname "mevcut tesislere kural gereği kod üret, planı uygulamadan önce
raporla" diyor. **Ölçtüm: bu göç zaten yapılmış** (0036 kod sütununu ekledi
ve doldurdu, 0037 kuralı akılda kalıcı biçime çevirdi, 0041 yerel
bağımsızlığını kilitledi).

Canlı şemayla birebir aynı dev veritabanında ölçüm:

| Kontrol | Sonuç |
|---|---|
| Toplam tesis | 223 |
| `kayit_kodu IS NULL` | **0** |
| Biçimi bozuk (`^[A-Z]{4}-\d{6}(-…)?$` tutmayan) | **0** |
| Kod benzersiz mi | **evet** |
| Ad+tarihten türetilenle birebir | 20 |
| Aynı tabanı paylaşıp çakışma eki almış | 200 |
| Tabanı bile tutmayan | **3** |

**3 istisna açıklandı:** üçü de bu turun `test_ad_DEGISSE_BILE_kod_SABIT_kalir`
testinin ürettiği, **sonradan adı değiştirilmiş** tesisler
(`Ilk Ad …` → `Bambaska Ad …`, kod `ILKA-…` kalmış). Bu **kuralın ta
kendisi** — kod ada değil, kayda bağlıdır (§3.2).

**Karar: yeni göç YAZILMADI.** Yazılsaydı ya hiçbir şey yapmayan boş bir
revizyon olurdu ya da adı değişmiş tesislerin **dağıtılmış kodlarını
bozardı**. Bu tur **hiç DDL içermiyor**; dolayısıyla geri alınacak bir şey
de yok — geri alma `git revert` kadar basit.

**Mevcut kullanıcılar erişim kaybetmedi** (KİLİTLİ KURAL 3): giriş yolları
(`/auth/login`, `/auth/login-phone`, `/auth/giris/kod-*`, sosyal giriş)
**hiç değişmedi**. Kaldırılan uçları hiçbir istemci çağırmıyordu.

---

## 6. OAUTH KONSOL AYARLARI (§5)

Tam liste `docs/oauth-kurulum.md`'de — bu turda **alan adları
düzeltildi**. Belge `api.test.yonetiyor.com` yazıyordu; test sunucusu
Cloudflare Tunnel'a taşınınca adlar tek seviyeye inmişti.

| | TEST | CANLI |
|---|---|---|
| API (callback tabanı) | `api-test.yonetio.site` | `api.yonetio.site` |
| Web dönüş | `app-test.yonetio.site/giris/oauth` | `app.yonetio.site/giris/oauth` |
| Mobil dönüş | `com.app.yonetiyor://oauth` | aynı |

**Kaydedilecek geri dönüş adresi ortam başına TEK tanedir** (mobil için
ayrı istemci gerekmez): sağlayıcı yalnız `https://<api>/auth/oauth/
callback/<saglayici>` adresini görür, özel şemaya yönlendirmeyi biz
yaparız — Apple'ın "https olmalı" kuralı ihlal edilmez.

Belgede her sağlayıcı için **test ve canlı satırları ayrı ayrı** yazıldı
(Google redirect URI'leri, Microsoft app registration'ları, Apple **iki
ayrı Services ID**). Canlı istemciye test adresi eklenmiyor — sağlayıcılar
tam eşleşme doğruluyor ve canlıyı test için düzenlemek onu riske atardı.

**OAuth tıkanırsa normal kayıt tek başına çalışır:** yapılandırılmamış
sağlayıcı ne mobilde ne web'de düğme olarak çizilir
(`GET /auth/oauth/saglayicilar` boş döner), telefon/parola yolu etkilenmez.

---

## 7. TESTLER

| Nerede | Ne | Sonuç |
|---|---|---|
| `test_tesis_olustur.py` (**16 yeni**) | tesis+oturum uçtan uca · kod biçimi · Türkçe harf · `i` yerel bağımsızlığı · kısa/rakamlı/harfsiz ad · aynı gün çakışması · ad değişince kod sabit · telefon normalizasyonu (4 biçim) · ikinci tesis 409 · yöntem kuralı · hız sınırı | ✅ |
| `test_kayit_dogrulama_rls.py` | yaşayan uca taşındı, kapsam korundu | ✅ |
| `test_rol_secimli_kayit.py` | P148 kesişim testi kaldırıldı | ✅ |
| `test_sozlesme_sapmasi` · `test_yetki_kapsam` · `test_yetki_matrisi` · `test_denetci_salt_okuma` · `test_yuzey_yalitimi` | 79 yeşil, kilit yeniden üretildi | ✅ |
| `kayit_rol_secimi_test.dart` (**10**) | yeni sıra · tesis açma + kod kopyalama · "zaten sitem var" · sosyal ad ön-doldurma · sosyal+yönetici · parola otomatik gönderimi · daire yalnız sakinde | ✅ |
| **Mobil tam takım** | | **1862 ✓** |
| **Backend tam takım** | | **1632 ✓** (1 atlandı, 0 kırmızı — 28 dk) |
| `flutter analyze` | | temiz |

**Demo hesapları (KİLİTLİ KURAL 2):** giriş yolları hiç değişmediği için
`+905000000101/102/103/104` ve `+905777777777` etkilenmedi; tam backend
takımı (1632 test) bunu ölçüyor ve **tamamı yeşil**.

---

## 8. YAPILMAYAN İŞ — dürüst liste

### 8a. Elle kayıt yolunda SMS **kaldırılmadı**

**Durum:** sakin/güvenlik/tesis görevlisi (ve katılan yönetici) hâlâ
tesis kodu + telefon eşleşmesinden sonra **SMS kodu** giriyor.

**Şartname bunu istiyor gibi okunabilir** (ADIM 3 SMS'ten söz etmiyor,
"hız sınırı koy" diyor). **Yapmadım ve sebebini açıkça yazıyorum:**

- SMS'i kaldırmak, **var olan bir hesabı sahiplenmenin** tek kanıtını
  kaldırır. Sonrasında tesis kodunu (kamuya açık) ve bir sakinin telefon
  numarasını (sır değil) bilen herkes o hesabı **ilk gelen kapar**
  mantığıyla ele geçirebilir.
- Bu bir **güvenlik modeli değişimidir**; hız sınırı onu telafi etmez
  (hız sınırı hız sınırlar, yetkilendirmez).
- **Yönetici self-signup'ta SMS zaten yok** ve bu çelişki değil: orada
  sahiplenilecek hesap yok, hesap o anda yaratılıyor ve numara boş olmak
  zorunda — kanıtlanacak bir sahiplik yok.

**Bunun bugünkü sonucu — bilinmeli:** SMS sağlayıcısı bağlanana kadar
(§4, Netgsm başlık onayı bekliyor) **uçtan uca çalışan tek kayıt yolu
yönetici self-signup'tır**. Sakin/personel ne davet bağını (SMS ile
gidiyor) ne eşleşme kodunu alabiliyor. Bu, bu turun ürettiği bir kusur
değil — sağlayıcının yokluğunun sonucu.

**Sonraki adım (karar sizin):** SMS'i kaldırmak istiyorsanız ayrı bir tur;
tasarımı hazır (eşleşme ucu + tesis kodu ekseninde ikinci bir hız sınırı +
"hesap sahiplenilmiş mi" tek-seferlik kilidi). Ya da Netgsm bağlanınca
mevcut yol olduğu gibi çalışmaya başlar — **kod değişmez, yalnız ortam
değişkeni**.

### 8b. Web (`admin-web`) kayıt yüzeyi güncellenmedi
Mobil yeni sıraya geçti; web `/kayit` sayfası hâlâ eski sırada ve
`tesis-olustur` düğmesi yok. Backend ucu hazır olduğu için bu **saf arayüz
işi**. Web'de yöneticinin bugünkü yolu davet bağı + panel.

### 8c. `POST /auth/kayit/tesis-olustur` canlıda denenmedi
KİLİTLİ KURAL 1 gereği deploy yok. Aşağıdaki komutlar test sunucusunda
koşulacak.

---

## 9. TEST SUNUCUSUNDA DOĞRULAMA KOMUTLARI

```bash
# 0) Kod güncel mi + göçler (test sunucusunda)
git pull && docker compose -f infra/docker-compose.yml up -d --build api

# 1) Kaldırılan uçlar GERÇEKTEN yok (404 beklenir)
curl -s -o /dev/null -w '%{http_code}\n' -X POST \
  https://api-test.yonetio.site/auth/kayit/basla \
  -H 'Content-Type: application/json' -d '{}'                    # 404
curl -s -o /dev/null -w '%{http_code}\n' \
  https://api-test.yonetio.site/kayit-basvurulari                # 404

# 2) YÖNETİCİ SELF-SIGNUP — tesis açılır, kod üretilir, oturum döner
curl -s -X POST https://api-test.yonetio.site/auth/kayit/tesis-olustur \
  -H 'Content-Type: application/json' -d '{
    "tesis_ad": "Sinama Sitesi",
    "ad": "Ayse Yonetici",
    "telefon": "0532 111 22 03",
    "parola": "CokGizliParola1"
  }' | jq '{tesis_ad, tesis_kodu, jeton_var: (.jetonlar.access_token|length>0)}'
# beklenen: tesis_kodu "SINA-YYAAGG…", jeton_var true

# 3) Kod KURALA uyuyor mu (Türkçe harf + kısa ad)
for AD in "Şişli Güneş" "As" "34. Cadde Sitesi"; do
  curl -s -X POST https://api-test.yonetio.site/auth/kayit/tesis-olustur \
    -H 'Content-Type: application/json' \
    -d "{\"tesis_ad\":\"$AD\",\"ad\":\"Test\",\"telefon\":\"+9059$RANDOM$RANDOM\",\"parola\":\"CokGizliParola1\"}" \
    | jq -r '.tesis_kodu // .error.message'
done
# beklenen sırayla: SISL-…, ASXX-…, CADD-…

# 4) TELEFON NORMALIZASYONU — aynı numara ikinci hesap AÇMAZ (409)
curl -s -o /dev/null -w '%{http_code}\n' -X POST \
  https://api-test.yonetio.site/auth/kayit/tesis-olustur \
  -H 'Content-Type: application/json' \
  -d '{"tesis_ad":"Baska","ad":"X","telefon":"+905321112203","parola":"CokGizliParola1"}'
# beklenen: 409

# 5) HIZ SINIRI (4. istek 429)
for i in 1 2 3 4; do
  curl -s -o /dev/null -w "$i:%{http_code} " -X POST \
    https://api-test.yonetio.site/auth/kayit/tesis-olustur \
    -H 'Content-Type: application/json' \
    -d '{"tesis_ad":"Hiz","ad":"X","telefon":"+905339998877","parola":"CokGizliParola1"}'
done; echo
# beklenen: 1:201 2:409 3:409 4:429

# 6) DEMO HESAPLARI HÂLÂ GİRİYOR (KİLİTLİ KURAL 2)
for T in +905000000101 +905000000102 +905000000103 +905000000104 +905777777777; do
  printf '%s -> ' "$T"
  curl -s -o /dev/null -w '%{http_code}\n' -X POST \
    https://api-test.yonetio.site/auth/login-phone \
    -H 'Content-Type: application/json' \
    -d "{\"phone\":\"$T\",\"password\":\"<demo-parola>\"}"
done
# beklenen: hepsi 200

# 7) SOSYAL SAĞLAYICILAR (konsol işleri bitince dolacak)
curl -s https://api-test.yonetio.site/auth/oauth/saglayicilar
```

---

## 10. DEĞİŞEN DOSYALAR

- **Göç:** **YOK** (§5'teki gerekçe).
- **Backend:** `routers/kayit.py` (**yeni**) · `routers/kayit_basvurulari.py`
  (**silindi**) · `routers/auth.py` · `routers/oauth.py` · `oauth.py` ·
  `davet.py` · `config.py` · `schemas.py` · `main.py`
- **Sözleşme:** `contracts/openapi.yaml` (3 yol + 5 şema silindi;
  1 yol + 2 şema eklendi; `OauthSonucResponse.ad`)
- **Testler:** `test_tesis_olustur.py` (**yeni, 16**) ·
  `test_sakin_kaydi.py` (**silindi**) · `test_kayit_dogrulama_rls.py` ·
  `test_rol_secimli_kayit.py` · `test_denetci_salt_okuma.py` ·
  `yetki/rol-matrisi.txt`
- **Mobil:** `kayit_screen.dart` (yeniden yazıldı) · `auth_api.dart` ·
  `auth_repository{,_impl}.dart` · `auth_controller.dart` ·
  `oauth_sonuc.dart` · ARB ×7 (18 anahtar + `kayitAdim`) ·
  `kayit_rol_secimi_test.dart` + 4 sahte depo
- **Docs:** `oauth-kurulum.md` (alan adları + iki ortam) · bu rapor
