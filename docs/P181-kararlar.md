# P181 — Kararlar, gerekçeler, bulunan eksikler

Kesintisiz mod. Her ana bölüm ayrı commit + push. Geliştirme ortamında çalışıldı
(192.168.20.101, docker-compose.yml). Sert sınırlar korundu: SMS yok (tek kanal
e-posta, mail.yonetiyor.com/noreply@yonetiyor.com); mevcut giriş yolları + api.
yonetio.site bozulmadı (yeni akışlar EK yol); P180 email_verified kuralı korundu;
yeni env → .env.prod.example + docker-compose.prod.yml birlikte güncellenir.

Bu belge bölüm bölüm doldurulur; her bölüm bitince ilgili commit'e referans verir.

---

## Bölüm 0 — P180 artığı: "Hesabınız yok mu?" bağlantısı

**Durum:** Giriş ekranında (`GirisFormu`) zaten `/kayit`'a bir kayıt bağlantısı
VAR (app.yonetiyor.com'un kendi kayıt akışı). Eksik olan **bağlama ekranı**:
sosyal giriş yapıp hesabı olmayan kullanıcı `/giris/oauth` "tesis" (tesis kodu +
telefon) adımına düşüyor ve oradan kayda dönüş yok.

**Karar:** Bağlama ("tesis") ekranına "Hesabınız yok mu? → Yönetici olarak
kaydolun" bağlantısı eklendi; hedef **kanonik** `https://yonetiyor.com/yonetici/
kayit`.

**Neden env değil, sabit kanonik URL:** Bu, adres politikasındaki SABİT tanıtım
kayıt adresidir (P179). Yeni bir build-time değişken eklemek (ve compose/örnek
dosyaya geçirmek) statik bir pazarlama URL'si için gereksiz yüzey olurdu. Test
sunucusu (rollback) ayrıca ele alınır. Backend giriş niyetinde **sessizce hesap
açmaz** (P180 kuralı); bu yalnız yönlendirme afordansıdır — güvenlik değişmez.

- i18n: `sosyalHesabinYok`, `sosyalKayitOl` 7 dile eklendi (parity testi yeşil).
- **Commit:** be451002.

---

## Bölüm 1 — E-posta zorunlu + doğrulama beklemede (BİTTİ)

**E-postasız kullanıcı raporu:** dev DB'de 73/73 aktif kullanıcı e-postasız
(seed/test verisi — anlamlı değil). Prod sayısı için:
`SELECT count(*) FILTER (WHERE email IS NULL OR email='') , count(*) FROM app_user
WHERE is_active=true;`

**Kritik bulgu (eksik):** `app_user`'da doğrulama-durumu kolonu YOK — yalnız
`email` (nullable). E-posta doğrulama KODLARI `kayit_dogrulama`'da (göç 0067) ama
kullanıcının e-postasının doğrulanmış olup olmadığını tutan kalıcı bir bayrak yok.

**Kararlar:**
- **Göç (yeni):** `app_user.eposta_dogrulandi boolean NOT NULL DEFAULT false`.
  Geriye dönük: mevcut e-postalı kullanıcılar **false** başlar (güvenli varsayılan)
  — doğrulanmamış sayılırlar; reset/OTP ancak doğrulayınca çalışır (kriter 7).
  Parola-yolu kaydında e-posta kodu doğrulanınca / SSO'da provider email_verified=
  true ise **true** yazılır.
- **Yeni kayıt:** e-posta zorunlu alan (şema + form). SSO'da sağlayıcı e-postası
  kullanılır.
- **Mevcut e-postasız kullanıcı KİLİTLENMEZ:** giriş yapar; oturum düşmez; bir
  "E-posta ekleyin (beklemede)" durumu gösterilir. Girilen adrese doğrulama kodu
  (`kayit_dogrulama`, amaç=`eposta_ekle`) gider; doğrulanana dek `eposta_dogrulandi
  =false` (beklemede).
- **Bağımlılık:** bu bayrak Bölüm 2 (reset) ve Bölüm 4 (OTP) için ÖN KOŞUL —
  "doğrulanmamış e-postaya kod/bağlantı gönderilmez" hepsi bu kolona bakar.

**Uygulama:**
- Göç `0070_eposta_dogrulandi`: `kod_amaci` enum'una `eposta_ekle` değeri +
  `app_user.eposta_dogrulandi boolean NOT NULL DEFAULT false`. **DEFAULT korunur**
  (ham-SQL `create_tenant_with_yoneticis` fonksiyonu kolonu adlandırmaz → NOT NULL
  ihlali olmasın; ilk denemede default düşürülünce 225 test hata verdi).
- Model/şema: `AppUser.eposta_dogrulandi`; `UserOut`/`MeProfileOut` alan olarak
  döner. `MeEpostaEkleRequest`, `MeEpostaDogrulaRequest` (extra=forbid).
- Uçlar (kimlik-doğrulamalı, hız-sınırlı, sızıntısız):
  `POST /me/eposta/kod-iste` (adres geçerli mi → başkasında mı 409 → kod gönder),
  `POST /me/eposta/dogrula` (kod doğru → `email` yaz + `eposta_dogrulandi=true` +
  audit `USER_CONTACT_UPDATE`). openapi.yaml'a eklendi (sözleşme testi yeşil).
- `eposta_dogrulandi=true` yazılan yollar: rol-eposta-doğrula, yönetici tesis
  oluşturma, SSO (yalnız provider `email_verified=true` ise). Mevcut kullanıcı
  false başlar → beklemede.
- Web: `/api/me/eposta/{kod-iste,dogrula}` BFF; `EpostaDogrulaKart` bileşeni;
  profil sayfasında doğrulanmamışsa "beklemede" kartı. 7 dile `profilEposta*`
  anahtarları (parity yeşil).
- Testler: `backend/tests/test_eposta_dogrula.py` (5, geçer).
- **Kilit kayıtları** (yeni uç + kod → deterministik bekçiler): `hata_metinleri.py`
  `METINLER`'e `eposta_gecersiz`, `eposta_kullanimda` (+ P180'den eksik kalan
  `onay_gerekli`) 7 dilde; `test_denetci_salt_okuma` beklenen kümeye iki uç;
  `test_secdef_kapsam` `ENVANTER`'e P180 `yonetici_by_email`; `tests/yetki/
  rol-matrisi.txt` yeniden üretildi (iki satır, hepsi IZIN — kimlik zorunlu, rol
  kapısı yok). Bunlar atlanınca tam suite 4 deterministik + kırmızı verdi.

**Test durumu:** tam backend suite 1883 geçti / 12 atlandı; tek düşen
`test_patrol_windows::test_range_status_order_and_counts` — izolasyonda geçer,
sıra-bağımlı tenant pollution (filtresiz sorgu tenant-geneli sayı bekler), Böl.1 ile
ilgisiz, kapsam dışı. admin-web: `npm run build` + i18n (33 test) yeşil.

**Not (kabuk-yüzeyi yorum kuralı):** i18n tur-22 taraması `//` satır yorumlarını
soyar (`split("//")[0]`) ama `/** */` blok ve ÇOK SATIRLI `{/* */}` JSX yorumunu
SOYMAZ → içindeki Türkçe "sızıntı" sayılır. Bu bölümdeki yeni yorumlar `//` ya da
TEK SATIR `{/* */}` yapıldı.

---

## Bölüm 2 — Parola sıfırlama ("şifremi unuttum") (BİTTİ)

**Karar:** E-POSTA TABANLI, SMS YOK. İki uç, ikisi de public (kimlik öncesi),
`/auth/giris/eposta-kod-*` ile birebir aynı sınıf:
- `POST /auth/sifre/kod-iste` {tenant_slug, eposta} → **SIZINTISIZ**: hesap
  var/yok/pasif/doğrulanmamış her durumda AYNI 200. Kod yalnız
  `eposta_dogrulandi=true` aktif kullanıcıya gider (Bölüm 1 ön koşulu). Hız
  sınırı ayrı kapsam `sifre_sifirla` (giriş kodu bütçesini paylaşmaz).
- `POST /auth/sifre/dogrula-ve-ayarla` {tenant_slug, eposta, kod, yeni_parola} →
  kod doğruysa yeni parola kurulur (güç: `validate_password_strength` — 8+,
  büyük harf, rakam, sembol), kod tüketilir, audit `PASSWORD_RESET`.

**Karar — OTURUM AÇMAZ:** Sıfırlama sonrası token DÖNMEZ; kullanıcı yeni
parolayla taze giriş yapar. Gerekçe: ikinci bir parolasız token yolu açmamak +
görev-penceresi/denetçi kurallarını tek yerde (giriş) tutmak.

**Karar — amaç enum'u:** göç 0071 `kod_amaci`'ya `sifre_sifirla` ekler.

**KRİTİK DÜZELTME (Bölüm 1 gizli hatası):** `kod_amaci` SQLAlchemy ENUM'u
(`models.py`) `eposta_ekle`'yi (göç 0070) İÇERMİYORDU — DB enum'unda vardı ama
Python tarafında yoktu. Bölüm 1 testleri `/me/eposta/dogrula` (kod OKUMA) yolunu
hiç çalıştırmadığından hata GİZLİ kaldı; prod'da o uç 500 verirdi
(`LookupError: 'eposta_ekle' is not among the defined enum values`). Bölüm 2'nin
`sifre_sifirla` okuması bunu ortaya çıkardı. Düzeltme: modele iki değeri de ekle
+ `test_eposta_dogrula.py`'a dogrula (kod-okuma) regresyon testi eklendi.

**Web:** `/giris/sifremi-unuttum` sayfası (2 adım, self-contained, public fetch);
GirisFormu'da e-posta yüzeyinde "Şifremi unuttum" bağlantısı (tesis/e-posta
prefill). BFF `/api/auth/sifre/{kod-iste,dogrula-ve-ayarla}` (token üretmez). 9
i18n anahtarı × 7 dil (parity yeşil).

**Kilit kayıtları:** `test_denetci_salt_okuma` (2 public uç), `rol-matrisi.txt`
(regen), openapi.yaml (2 path + 2 şema). Yeni APIError kodu YOK (reset mevcut
`invalid_code` + parola-güç hatasını kullanır).

**Test:** `backend/tests/test_sifre_sifirla.py` (7) + eposta regresyon (1).

---

## Bölüm 3 — Parola değiştirme (giriş sonrası) (ZATEN VARDI, DOĞRULANDI)

**Bulgu:** Bu özellik P181'den ÖNCE tamamen mevcuttu ve testliydi — yeni kod
gerekmedi (fabrikasyon YAPILMADI):
- Backend `PATCH /me/password` (`change_my_password`): mevcut parola doğrulanır
  (yanlışsa 400 `mevcut_parola_hatali`), yeni parola gücü şema düzeyinde ölçülür,
  başarıda `PASSWORD_CHANGE` audit. Oturum (refresh) devam eder.
- Frontend `SifreDegistir` bileşeni (profil sayfası): mevcut/yeni/yeni-tekrar,
  tekrar-eşleşme istemcide, `apiSend PATCH /api/me/password`, toast.
- Testler: `test_profile.py` 7/7 geçer (happy path, yanlış mevcut 400, kısa yeni
  422, sakin kendi parolası).

**Karar — parolasız kullanıcı dalı DOKUNULMADI (kapsam):** `change_my_password`,
`password_hash IS NULL` kullanıcıda telefon KODU (`amac='hesap_silme'`, SMS)
ister. Bu:
1. Web profil arayüzünden ERİŞİLEMEZ (personel her zaman parolalıdır; UI'da kod
   alanı yok) — yani Bölüm 3'ün web kapsamı dışında.
2. Yalnız MOBİL sakin (P148) senaryosunda anlamlı; parolasız hesap silme kodu
   yeniden kullanımıdır, P181 öncesinden gelir.
3. P181 "SMS YOK" kuralı YENİ akışlara EK SMS koymamaktır; bu var olan mobil yol
   sökülmedi. İleride mobilde e-posta-tabanlı eşdeğere taşınabilir (Bölüm 10
   sonrası ayrı iş olarak NOT edildi) — web Bölüm 3 kapsamında değil.

**Sonuç:** Bölüm 3 yeni kod olmadan DOĞRULANDI; bu bölüm belge-güncellemesi
olarak işlenir.

---

## Bölüm 4 — E-posta OTP ile giriş (VARDI + P181 dokunuşu)

**Bulgu:** E-posta kodu ile parolasız giriş P172 §5'ten mevcuttu:
`POST /auth/giris/eposta-kod-iste` + `/auth/giris/eposta-kod-dogrula` (backend),
GirisFormu'da e-posta yüzeyinde "Parola yerine e-postaya kod gönder" (frontend,
BFF `/api/auth/eposta-kod?adim=iste|dogrula`). Sızıntısız, telefon yoluyla aynı
mekanizma (süre/deneme/hız `telefon_kodu`dan).

**P181 dokunuşu (yeni kod):** `eposta-kod-dogrula` başarısında
`eposta_dogrulandi=true` yazılır. Gerekçe: **e-posta kodunu girmek adresin
kontrolünü kanıtlar — doğrulamanın ta kendisidir.** Böylece e-posta'lı ama hiç
doğrulamamış MEVCUT kullanıcılar (Bölüm 1'de false başlayanlar) OTP ile girip
OTOMATİK doğrulanır; bu da parola sıfırlamayı (Bölüm 2, gate=`eposta_dogrulandi`)
onlar için açar. GATE koymadık (döngü olurdu: doğrulamak için kod, kodu almak
için doğrulama); kod her aktif e-postaya gider, başarı doğrular.

**Kapsam:** yeni uç/enum/i18n/kilit YOK — yalnız bir bayrak set + test.
**Test:** `test_eposta_kanali.py::test_EPOSTA_KODU_GIRISI_ADRESI_DOGRULAR` (16/16).

---

## Bölüm 5 — E-posta şablonları (5 adet) (BİTTİ)

**Önce:** TÜM amaç için TEK sabit metin gidiyordu (`telefon_kodu.py`:
"Yönetiyor doğrulama kodunuz: {kod} ({dk} dk)"). Amaç ayrımı YOK, markalama YOK,
kimlik-avı savunması YOK.

**Karar:** `app/eposta_sablonlari.py` — amaç başına konu+açıklama haritası +
`eposta_kod_metni(amac, kod, dk) -> (konu, govde)`. 5 markalı şablon:
`kayit`, `giris`, `eposta_ekle`, `sifre_sifirla`, `hesap_silme`. Her gövde: amaca
özel açıklama + `Kod: NNNNNN` + `{dk} dakika geçerli` + kimlik-avı satırı ("siz
istemediyseniz yok sayın") + imza (`— Yönetiyor` / `noreply@yonetiyor.com`).
`telefon_kodu.eposta_kodu_uret_ve_gonder` artık bunu çağırır.

**Kararlar (gerekçeli):**
- **Düz metin, HTML değil:** mevcut `SmtpEpostaSaglayici.gonder` `set_content`
  (text/plain) kullanıyor; HTML eklemek SMTP katmanını değiştirmek olurdu —
  düşük risk için düz metinde kaldık, markalama başlık+imza satırıyla.
- **Kod-içi harita, DB değil:** kimlik-doğrulama e-postaları PLATFORM düzeyidir,
  tenant'a özel değil; ayrıca DB `MesajSablonu` FARKLI bir enum (`pazarlama/
  operasyonel`) kullanır — `KOD_AMACI` ile uyuşmaz.
- **i18n YOK (yalnız TR):** backend tek dilli; `app_user`/`tenant`'ta dil alanı
  yok (yalnız `UserDevice.dil` push için). Mevcut davranışla tutarlı; çok-dilli
  e-posta ayrı bir iş (NOT edildi).
- **`hesap_silme` şablonu var ama e-posta yolu şu an telefon:** hesap silme kodu
  bugün `kod_uret_ve_gonder` (telefon) ile gidiyor; e-posta şablonu haritada
  hazır (e-posta silme yolu ileride bağlanırsa kullanılır). Backend Türkçe
  metinler i18n taramasına TABİ DEĞİL (o tarama yalnız admin-web + APIError'lar).

**Kapsam:** yeni uç/enum/göç/kilit YOK. **Test:** `test_eposta_sablonlari.py`
(5 saf-fonksiyon testi) + `test_eposta_kanali`/`test_sifre_sifirla`/
`test_eposta_dogrula` regresyonu yeşil.

---

## Bölüm 6 — Web arayüz düzeltmeleri (5 alt madde)

Sıra: 6.5 → 6.1 → 6.2 → 6.4 → 6.3 (kullanıcı belirledi).

### 6.5 — Bildirimler: toplu işlem (BİTTİ)

**Önce:** yalnız tekil "okundu" (PATCH /notifications/{id}). Toplu YOK, silme YOK.

**Uygulama:**
- Göç 0072: `notification.silindi_at` (nullable) — YUMUŞAK silme (satır kalır,
  listede gizli, kurtarma+denetim mümkün). Model + `_canli()` süzgeci list/patch
  ve toplu uçlarda uygulanır.
- 3 uç (kapsam `_kapsam` ile zorlanır — başkasının/yönetim alarmını sakin
  işleyemez; RLS + rol kapısı `_VIEWER`, denetçi RED):
  `POST /notifications/toplu-okundu` {ids[], okundu}, `/tumunu-okundu` (kapsamdaki
  tüm okunmamışlar), `/toplu-sil` {ids[]} → silindi_at=now + audit
  `NOTIFICATION_DELETE` (adet meta'da).
- Web: bildirimler sayfası — tekil onay kutusu + "tümünü seç" + "seçilenleri
  okundu" + "seçilenleri sil" (tehlike) + "tümünü okundu". 3 BFF uç. 7 i18n
  anahtarı × 7 dil (parity yeşil).
- Kilit: openapi (3 path+3 şema), rol-matrisi regen (denetçi/gorevli RED).
  denetci_salt_okuma DEĞİŞMEZ (uçlar rol-kapılı, kapısız-küme dışı).
- Test: `test_notifications_toplu.py` (6: okundu/sil/tekrar/tümü/kapsam/denetim).

### 6.1 — Daireler: sakin adı (UUID yerine) (BİTTİ)

**Hata:** `UnitDetail.tsx` daire sakinlerini `user_id.slice(0,8)` (UUID) ile
gösteriyordu — ad-soyad değil. Kök neden: `GET /units/{id}/residents`
(`UnitResidentOut`) sakinin ADINI döndürmüyordu, yalnız `user_id`.

**Çözüm:** `UnitResidentOut`'a `user_ad` eklendi; endpoint `AppUser` LEFT JOIN'iyle
adı doldurur (kullanıcı silinmişse null). Frontend `r.user_ad ?? kisaKimlik(...)`
gösterir (ad varsa düz, yoksa mono kısa-kimlik). openapi `UnitResident.user_ad`.

**TÜM ekran taraması (kural gereği):** yalnız `UnitDetail.tsx:437` ham UUID
gösteriyordu. Diğer ekranlar kişiyi zaten çözümlü adla gösteriyor: şikayet
`acan_ad`, görev/rezervasyon/ziyaretçi/kargo `userName()`/kullanıcı-listesi
yardımcılarıyla. Başka çözümlenmemiş-kimlik gösterimi YOK.
Test: `test_residents.py::test_units_residents_SAKIN_ADINI_dondurur`.

### 6.2 — Daireler: "bina düzenleme" düğmeye çevrildi (BİTTİ)

`units/page.tsx` sağ üstteki düz-metin `<Link>` (altı çizili) → `Dugme
tur="birincil"` (router.push /building-editor). Salt görünüm; "Blok Ekle"ye
dokunulmadı. i18n yeni anahtar yok (mevcut `daireBinaDuzenlemeGit`).

### 6.4 — Şikayet haritası: yakınlaştırma (BİTTİ)

`plan-haritasi.tsx`: `maxZoom` 4→8 (plan çözünürlüğünce yakınlaşma); `fitBounds`
varsayılan açılışı `maxZoom: 6` ile DAHA YAKIN başlatır (eski tavan 4 uzaktı);
`scrollWheelZoom`/`doubleClickZoom`/`touchZoom` açıkça etkin (tekerlek + çift
tıklama + dokunmatik sıkıştırma).

### 6.3 — Görevler: kategori yönetimine erişim (BİTTİ)

**Doğrulama:** `/tanimlar` `gorev-kategorileri` defteri CRUD'u ZATEN çalışıyor
(ad alanı + soft-delete `aktif`; wizard "Görev alanları" adımı buraya bakar).
Eksik olan KEŞFEDİLEBİLİRLİKTİ. **Çözüm:** Görevler sayfası başlığına
"Kategorileri yönet" (ikincil) düğmesi — `/tanimlar?defter=gorev-kategorileri`
derin bağlantısı (`useSorguSecimi` `?defter=` okur). 1 i18n anahtarı × 7 dil.

---

## Program notu (dürüstlük)

P181 on bir bölümlük büyük bir programdır (auth altyapısı + göçler, 6 web düzeltme,
özet yeniden tasarım, rapor grafikleri, rezervasyon, mobil push). Bölümler SIRAYLA,
her biri yeşil + ayrı commit olarak ilerletilir; "kesintiye uğrarsan nerede
kaldığın belli olsun" gereği bu belge + commit'ler durumu taşır. Bölüm 0-5 bitti;
sıradaki Bölüm 6 (web arayüz düzeltmeleri — 6 alt madde).
