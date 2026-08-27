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

## Bölüm 7 — Özet (dashboard) sayfası

### 7.1 — Düzenlenebilir yerleşim + 7.2 Banner'lar (BİTTİ)

**Önce:** yerleşim TEK BOYUTLU bir listeydi; her bölümün `genişlik` (tam/yarım)
SABİT ve satırlar otomatik eşleşiyordu. Satır başına sütun seçilemiyordu; banner
yoktu.

**Karar (mimari — KESİNTİSİZ MOD gerekçesi):** `PanoTercihi`ye opsiyonel
`satirlar: [{sutun:1-4, idler:[], baslik?}]` eklendi. Verildiğinde yerleşimi O
kurar (her satır kendi `sutun`uyla CSS ızgara); VERİLMEZSE eski tam/yarım eşleşme
çalışır → **mevcut kullanıcılar geriye dönük uyumlu.** Kullanıcı başına
`app_user.pano_tercihi` (JSONB) — göç YOK. Varsayılan `satirlar`, bugünkü
tam/yarım düzenden türetilir (derli toplu).

- **7.1:** her satırda 1/2/3/4 sütun (düzenleme modunda buton); bölümler satır
  içi (←/→) ve satırlar arası (yukarı/aşağı) taşınır; "satır ekle" (boş satır);
  gizle/göster korundu.
- **7.2:** her satıra opsiyonel BANNER başlığı (7.2 "başlıklı bölümler").

**Karar — sürükle-bırak yerine BUTON:** Mevcut kod sürükle-bırağı BİLEREK
reddetmişti (iki-eksen erişilebilirlik/klavye maliyeti — `pano-tercihi.ts`
gerekçesi). Aynı ilkeyle buton-tabanlı taşıma korundu (klavye erişilebilir); asıl
istenen "satır bazında yerleşim değişir ve saklanır" (kabul 11) sağlanır.
Sürükle-bırak ileride framer-motion ile eklenebilir.

**Kapsam:** göç YOK. Backend `PanoSatir` şeması + openapi + `satirlariCoz`/
`varsayilanSatirlar`/`satirGovdesi` (lib). 7 i18n anahtarı × 7 dil. Test:
`test_takvim.py` satırlar round-trip + sütun 1-4 doğrulama.

### 7.3 — Devriye turu görsel bileşeni (BİTTİ)

**Önce:** düz cümle ("X / Y checkpoint" + zaman) — `KahramanBlok`.

**Çözüm:** `DevriyeGorunumu` bileşeni: ilerleme HALKASI (SVG; merkezde yüzde
METNİ — bilgi renk-yalnız değil), tamamlanan/beklenen + KALAN nokta sayısı, ve
**son okutma zamanı**. Durum rozeti (sürüyor=olumlu/sıradaki=bilgi), plan adı,
/patrol-plans bağlantısı korundu.

**Backend (son okutma yoktu):** `_AKTIF_TURLAR_SQL`'e `max(s.okutma_zamani) AS
son_okutma`; `AktifTurOut.son_okutma` + openapi `AktifTur.son_okutma`; frontend
`AktifTur.son_okutma` tipi. Test: `test_dashboard.py` son_okutma dolu.
i18n: `devriyeTamamlanan/Kalan/SonOkutma/OkutmaYok` × 7 dil.

### 7.4 — 3D maket kamera hatası (BİTTİ)

**Kök neden (teşhis):** `autoRotate` zaten kapalıydı; sorun `KameraSurucusu`ydu —
`useFrame` HER KARE kamerayı hesaplanmış hedefe (`easing.damp3`) çekiyordu.
`damp3` hedefe asimptotik yaklaşır, asla "bitmez"; kullanıcı fareyle döndürünce
bir sonraki kare kamerayı hedefe geri çekiyor → **bırakınca başa dönüyordu.**

**Çözüm:** Sürüş artık yalnız "uçuş" sırasında çalışır:
- `ucusAktifRef` — seçim (dolayısıyla hedef) değişince `true` (yeni bloğa/kata/
  daireye uç); hedefe varınca (`distance < 0.05`) kendini `false` yapar.
- `useFrame` uçuş aktif değilken kameraya DOKUNMAZ → OrbitControls (kullanıcı)
  sahibidir; bırakılan açı + yakınlık KORUNUR (kabul 12).
- `OrbitControls onStart` → kullanıcı kamerayı tuttuğu an `ucusAktifRef=false`
  (uçuşla kullanıcı çekişmesin).
- Hareket-azaltmada (reduced-motion) anında oturur, uçuş yok.

Frontend-only (bina-sahnesi.tsx); göç/i18n/backend YOK. Görsel/etkileşim
davranışı — otomatik test yok, `npm run build` yeşil; el ile doğrulanacak.

---

## Bölüm 8 — Raporlar (grafik + PDF/Excel doğrulama)

### 8.0 — PDF/Excel çıktı doğrulaması (BİTTİ)

**Spec:** "13 raporun PDF/Excel çıktıları hiç doğrulanmadı — her birini üret,
açılıp açılmadığını test et, sonucu raporla."

**Sonuç:** `test_HER_KOD_EXCEL_ve_PDF_GECERLI_URETIR` katalogdaki **16 raporun
HER BİRİ için** hem excel hem pdf üretir ve dosyanın GEÇERLİ (açılabilir)
olduğunu magic-byte ile doğrular: xlsx = ZIP imzası `PK\x03\x04`, pdf = `%PDF`,
boyut > 100B. **Hepsi geçti — bozuk/açılmayan çıktı YOK.** Senkron uç
(`POST /raporlar/{kod}?bicim=excel|pdf`) her kod için çalışıyor (`agir` yalnız
istemciye "kuyruğa yolla" ipucu; senkron üretim yine mümkün).

Kod (`rapor_ciktilari.py` reportlab/openpyxl) SAĞLAM bulundu; değişiklik
gerekmedi. Test-only, ekleme; üretim kodu değişmedi.

### 8.1 — Web grafikleri (KISMİ — altyapı + 3 rapor)

**Altyapı (tek kaynak):** Katalog `KatalogKaydi.grafik = GrafikTanimi(tip, x,
seriler)` — web/PDF/Excel aynı yapılandırmayı okur (kod SÜTUN kimlikleri).
Katalog ucu `grafik`i döner (`RaporGrafikTanimi` şema + openapi).

**Web:** `RaporGrafik` bileşeni (recharts) rapor tablosunun ÜSTÜNDE:
- `cizgi` (zaman serisi), `sutun` (karşılaştırma), `pasta` (dağılım).
- Erişilebilirlik: renk TEK sinyal DEĞİL — legend + eksen etiketi + tooltip
  değeri; ayırt edilebilir palet.
- **Veri yoksa** "veri yok" durumu (boş grafik değil).
- **Örnekleme:** >60 nokta eşit aralıkla örneklenir (tarayıcı kilitlenmesin),
  kullanıcıya "N noktaya örneklendi" notu.
- kuruş serileri TL'ye çevrilir (okunur eksen).

**Bağlanan 3 rapor:** `donemsel_bakiye` (çizgi: dönem→borç/tahsilat/bakiye),
`hesap_ekstresi` (çizgi: tarih→bakiye), `gelir_gider_ozet` (sütun: kalem→
gelir/gider). i18n: `raporGrafikVeriYok`, `raporGrafikOrneklem` × 7 dil.

### 8.2 — Grafik PDF/Excel'e gömüldü + rapor kapsamı (BİTTİ)

**PDF (reportlab.graphics) + Excel (openpyxl chart) gömme:** `rapor_ciktilari.py`'a
tek kaynak grafik hattı eklendi — katalogdaki `GrafikTanimi` hem web hem PDF hem
Excel'e aynı yapılandırmayı besler. Çıktı katmanı `_grafik_verisi(sonuc, grafik)`
ile satırlardan (etiketler, seriler, örneklendi_mi) üretir; kuruş serileri TL'ye
çevrilir.

- **Excel:** `_excel_grafik` — tablonun sağında adanmış kaynak bloğu + YERLİ
  (düzenlenebilir) grafik (LineChart/BarChart/PieChart, cell referanslı).
- **PDF:** `_pdf_grafik` — son sayfada `reportlab.graphics` çizimi
  (HorizontalLineChart/VerticalBarChart/Pie).
- **Erişilebilirlik (renk TEK sinyal DEĞİL):** çizgide her seriye AYRI İŞARET
  (marker — daire/kare/elmas…), pastada dilim etiketi+YÜZDE, hepsinde legend
  (metin) + eksen başlığı; renk körü dostu palet (Okabe-Ito).
- **Veri yok:** satır yoksa grafik ÇİZİLMEZ — Excel'de "Grafik için veri yok."
  notu, PDF'te grafik sayfası eklenmez.
- **Örnekleme:** >30 nokta eşit aralıkla örneklenir (gömülü/kağıt grafik okunur
  kalsın); "(örneklendi)" notu düşer.
- **Sağlamlık:** grafik üretimi try/except içinde — grafik SÜStür, başarısızlığı
  raporu DÜŞÜRMEZ (logo ele alışıyla aynı ilke).

**Grafik türü seçimleri (neden):**
- `donemsel_bakiye` → **çizgi**: dönem zaman serisi (borç/tahsilat/bakiye).
- `hesap_ekstresi` → **çizgi**: tarih ekseninde yürüyen bakiye eğilimi.
- `gelir_gider_ozet` → **sütun**: kalem bazında gelir vs gider karşılaştırması.
- `tahsilat_performansi` → **çizgi** (yeni): dönem ekseninde borçlandırılan vs
  tahsil (ikisi de TL); `oran` (%) FARKLI ölçek olduğu için seriye katılmadı.

**Grafik BAĞLANMAYAN raporlar (gerekçeli — zorlamak yanıltırdı):**
`firma_ekstresi`, `isletme_defteri`, `finansal_hareketler`, `makbuz_dokumu`,
`kasa_ekstresi`, `borc_alacak`, `detayli_borc` HAREKET DÖKÜMLERİDİR (tarih
sıralı satır listeleri); doğal tek bir x-ekseni + karşılaştırılabilir sayısal
seri YOK — anlamlı bir grafik ancak sunulmayan bir toplama (aggregation)
gerektirir. `site_sakinleri`/`dokuman_listesi`/`notlar` liste; `denetim_raporu`/
`ihtar_yazisi` serbest METİN (tablosuz, `metin_pdf`). Bu raporlarda grafik
YOK — "veri/anlam yoksa çizme" ilkesi.

**Test:** `test_rapor_kuyruk.py` — `test_GRAFIK_EXCELE_gomulur_ve_PDF_sayfa_ekler`
(xlsx'te `xl/charts/`, PDF'te ek sayfa), `test_GRAFIK_VERI_YOKSA_bos_grafik_cizmez`,
`test_GRAFIK_pasta_ve_sutun_tipleri_uretilir`, `test_GRAFIK_cok_nokta_ORNEKLENIR`
(örnekleme + kuruş→TL). Deterministik (canlı seed'e bağlı değil). Mevcut
`test_HER_KOD_EXCEL_ve_PDF_GECERLI_URETIR` (canlı, tüm katalog) yeşil kalır.

---

## Ara iş — admin-web tam test paketi yeşillendirildi (Bölüm 0-8 borcu)

**Bulgu (dürüstlük):** Bölüm 0-8 commit'leri push edilirken admin-web için
YALNIZ `npm run build` + i18n parity koşulmuştu; TAM vitest DOM paketi hiç
koşmamıştı. Sonuç: HEAD'de **22 kırmızı test / 15 dosya** birikmişti — hepsi
Bölüm 0-8 UI değişikliklerinin kırdığı ama görülmeyen gerilemeler. A-D'den önce
bunlar yeşillendirildi (yeni gerileme EKLENMEDİ; baseline=değişiklikli=22 idi,
tespit stash karşılaştırmasıyla yapıldı).

**Kök nedenler + düzeltmeler:**
- **useRouter invariant (4 dosya):** Units/Tasks sayfaları 6.2/6.3'te `useRouter`
  aldı; DOM testlerinde app-router yok → invariant. Standart `vi.mock("next/
  navigation")` eklendi (mevcut `pano-widget-tiklama` kalıbı).
- **link→button (yz-tasima):** 6.2 "Bina düzenleme"yi bağlantıdan düğmeye çevirdi;
  test rolü `link`→`button` güncellendi (niyet aynı: afordans duruyor).
- **DevriyeGorunumu tanımsız token (7.3):** `var(--yz-olumlu, var(--yz-accent))`
  → `var(--yz-success)` (tanımlı pozitif jeton; ayrıca virgüllü string
  sabit-metin taramasını tetikliyordu — düzeldi). Rozet `durum` kimlikleri
  (`notr|bilgi|olumlu|uyari|kritik`) sabit-metin `UCLU_TEKNIK` beyaz listesine
  eklendi (renk kimlikleri gibi — kullanıcıya görünen metin değil).
- **profil EpostaDogrulaKart (Böl.1):** `--yz-text-muted`/`--yz-surface-card`
  TANIMSIZ jetonlardı → `--yz-text-2`/`--yz-surface-1`. Kartın iki input'una
  `aria-label` eklendi (erişilebilir ad — placeholder ad değildir). profil DOM
  testi fixture'ına `eposta_dogrulandi:true` (kimlik testi doğrulama akışını
  ölçmüyor; doğrulanmamışta kart mevcut e-postayı ön-doldurup çift eşleşme
  üretiyordu).
- **bildirim toplu (6.5):** vardiya-nokta testi satır "Okundu" düğmesini `/Okundu/i`
  ile arıyordu; toplu "…okundu işaretle" düğmeleri eklendiğinden TAM ad `"Okundu"`.
- **kayit ham-fetch (P180):** OAuth başlat gövdesi büyüyünce `r.ok` denetimi
  12-satır penceresinin dışına itilmişti (sessiz-fetch taraması) → gövde
  değişkene alınıp `fetch`+`.ok` yakınlaştırıldı (davranış aynı).
- **dış bağımlılık allowlist:** `yonetiyor.com` (Böl.0 kanonik kayıt bağlantısı)
  bizim alan adımız; `bizim` regex'ine eklendi (`yonetio` yalnız `.site`
  alt-alanlarını eşliyordu).
- **Caddy yüzey testi:** app.* blok başlığı P154/P179'da `{$APP_DOMAIN},
  {$APP_DOMAIN_IDN} {`'e döndü; test eski `app.{$PORTAL_DOMAIN}` işaretini
  arıyordu → güncel başlığa çevrildi (ölçülen: admin-web:3000'e proxy).

**Sonuç:** 1405 test / 1403 geçer + 2 (bu düzeltmelerle) → **hepsi yeşil**;
tsc temiz. Bunların çoğu TEST güncellemesi, birkaçı GERÇEK ürün kusuru (tanımsız
CSS jetonu = kırık stil, adsız input = erişilebilirlik).

---

## Prod düzeltmeleri A-D — "şifremi unuttum" (BİTTİ, web)

Prod doğrulamasında Bölüm 2 sıfırlama akışı için dört bulgu; hepsi WEB'de
giderildi (mobil karşılığı Bölüm 10 ile — bu makinede Flutter YOK, derlenemez).

- **(A) Her yüzeyde:** "Şifremi unuttum" bağlantısı yalnız `panel.*`
  (e-posta) yüzeyindeydi. Artık `GirisFormu`'nda HER İKİ yüzeyde (app.* telefon +
  panel.* e-posta), parola adımında görünür. Sıfırlama e-posta tabanlıdır ve
  kendi sayfası tesis+e-posta sorar; e-posta yüzeyinde bilinenler ön-doldurulur,
  telefon yüzeyinde sayfada girilir. Aynı akış, aynı güvenlik (sızıntısız).
- **(B) Görsel dil:** Sayfa beyaz-zemin-tek-karttı. Yeni **`GirisKabuk`**
  (`components/giris/kabuk.tsx`) — giriş ekranının vitrini (orbital sahne +
  marka + sol tanıtım + cam kart) tek yerde toplanıp sıfırlama sayfasına verildi.
  `GirisFormu`'nun kendi iç yerleşimi (başarı animasyonu forma bağlı)
  DEĞİŞMEDİ — düşük gerileme riski; palet aynı kaynaktan (`giris/palet`).
- **(C) Doğrulama (sızıntısız):** Tesis (slug) BİÇİMİ (`^[a-z0-9]+(?:-[a-z0-9]+)*$`
  — `slugify_tenant` ile aynı) ve e-posta biçimi İSTEMCİDE denetlenir; hatalı
  alan KIRMIZI kenar + anlaşılır metin, gönderim engellenir. Bu yalnız BİÇİM
  denetimidir; hesabın var olup olmadığını SIZDIRMAZ (o denetim sunucuda ve
  sessiz — kod yalnız doğrulanmış e-postalı aktif hesaba gider). Kırmızı kenar
  rengi palet sabiti `CAM_KENAR_HATA` (ternary'de satır-içi string sabit-metin
  taramasını tetiklerdi).
- **(D) İlk kullanım açıklaması:** `sifreSifirlaAciklama` netleştirildi (7 dil):
  "Kod yalnızca doğrulanmış e-postalı hesaplara gönderilir; birkaç dakikada bir
  e-posta almazsanız e-postanız henüz doğrulanmamış olabilir. Güvenlik gereği
  bir hesabın bulunup bulunmadığını belirtmeyiz." — hesap varlığını sızdırmadan
  "hiçbir şey gelmedi = bozuk" yanılgısını giderir.

**Kapsam:** göç YOK, yeni env YOK, yeni backend uç YOK (Bölüm 2 uçları kullanılır).
Yeni i18n: `girisSlugGecersiz`, `girisEpostaGecersiz` × 7 dil + `sifreSifirlaAciklama`
yeniden yazıldı (parity yeşil). **Mobil (A):** giriş telefonla; e-posta tabanlı
sıfırlama için ayrı ekran gerekir — Bölüm 10 mobil işiyle birlikte, Flutter'sız
derlenemediğinden dağıtımda işaretli.

---

## Bölüm 9 — Web rezervasyon (yönetim + alan yönetimi) (BİTTİ, web)

**Bulgu:** Web'de `/rezervasyonlarim` ZATEN vardı — SAKİN self-servis
(oluşturma + listeleme + iptal). "Web'de yok" olan, mobildeki **yönetim**
tarafıydı: mobil rezervasyon ekranının "Alanlar" sekmesi (rezerve edilebilir
alanların yönetimi) + yönetim rezervasyon listesi web'de HİÇ yoktu (BFF
`/api/common-areas` yalnız GET'ti, yönetim sayfası yoktu).

**Karar:** Yeni yönetim sayfası **`/rezervasyon-yonetimi`** (admin/yönetici),
mobil ile birebir iki sekme:
- **Alanlar:** liste (pasifler dahil) + yeni alan + düzenle + pasifleştir/
  aktifleştir (soft-delete `aktif=false`; rezervasyon geçmişi korunur).
- **Rezervasyonlar:** yönetim TÜMÜ + süzgeç (alan / tarih / aktif-geçmiş) +
  herhangi birini iptal.

**Aynı veri modeli / aynı uçlar — YENİ TABLO YOK:** `GET/POST /common-areas`,
`PATCH /common-areas/{id}`, `GET /reservations` (yönetim=tümü, süzgeçli),
`POST /reservations/{id}/cancel`. Backend DEĞİŞMEDİ.

**İş kuralları SUNUCUDA (mobil ile birebir):** çakışma kontrolü + zamanlama
(`reservations_timing.py`) + saklama süresi (göç 0054, `tenant.rezervasyon_
gecmis_ay`) + alan adı benzersizliği (409) + saat tutarlılığı (kapanış>açılış,
422). İstemci KOPYALAMAZ — hata metni tenant dilinde sunucudan gelir.

**Karar — rezervasyon OLUŞTURMA yönetimde YOK (RBAC):** backend `POST
/reservations` YALNIZ resident'tir (`_REQUESTER`); yönetim rezervasyon üretmez
(403 olurdu). Sakin `/rezervasyonlarim`'dan oluşturur (zaten var). Yeni bir
"yönetim adına rezerve et" ucu AÇILMADI — spec "mobil modeli birebir, yeni
tablo/uç yok" diyor ve mobilde de yönetim rezerve etmez.

**Karar — "düzenleme" = ALAN düzenleme:** Rezervasyonun KENDİSİ düzenlenebilir
değil (backend'de `PATCH /reservations` YOK; mobilde de yok — düzeltme = iptal
+ yeniden). Dolayısıyla Böl.9'un "düzenleme"si rezerve edilebilir ALANLARA
uygulanır (mobil "Alanlar" sekmesiyle aynı).

**Kapsam:** yalnız `admin-web`. BFF: `common-areas` POST + `[id]` PATCH,
`reservations` GET süzgeç iletimi. Rol: `ROTA_ROLLERI["/rezervasyon-yonetimi"]
= ["admin","yonetici"]` + menü (tesis grubu). i18n: `kabukRezervasyonYonetimi`
+ 20 `rezYon*` × 7 dil (parity yeşil). **Göç/env/backend YOK.**
**Test:** `rezervasyon-yonetimi.dom.test.ts` (alan listesi + pasifleştir PATCH +
yönetim rezervasyon listesi/iptal); tsc + tam admin-web vitest yeşil.

---

## Bölüm 10 — Mobil bildirimler / SSO / yoklama (İNCELEME + kısmi düzeltme)

**Ortam kısıtı (dürüstlük):** Bu geliştirme makinesinde **Flutter YOK** (bkz.
memory: göç 2026-08). Mobil Dart kodu YAZILABİLİR ama DERLENİP TEST EDİLEMEZ.
SERT SINIR: "yayındaki App Store/Play sürümleri api.yonetio.site'a bağlı; mevcut
giriş yollarını BOZMA." Bu yüzden mobil için YALNIZ test edilmeden GÜVENLİ
(katkısal, mevcut girişi etkilemeyen) değişiklik yapıldı; gerisi TAM TEŞHİS +
plan olarak bırakıldı (APK derleme/test KULLANICIDA).

### 10.4 — SSO ÇALIŞMIYOR + APK API'ye ulaşamıyor (KÖK NEDEN BULUNDU)

**Bulgu 1 — "POST /auth/login-phone prod loglarında HİÇ görünmüyor" (asıl kusur):**
`mobile/lib/src/core/config/app_config.dart` → `apiBaseUrl =
String.fromEnvironment("API_BASE_URL", defaultValue: "http://10.0.2.2:8000")`.
Bu adres **yalnız Android emülatör loopback'i** (ve şifresiz http). Yani APK
`--dart-define=API_BASE_URL=https://api.yonetio.site` OLMADAN derlendiyse prod'a
DEĞİL emülatör-yerel adrese gider → gerçek cihazda API'ye HİÇ ulaşamaz → giriş
isteği prod'a varmaz. **Doğru yol `mobile/yayin-yap.sh`** (dart-define'ı geçer
VE yerel/şifresiz adresi reddeder) ya da `codemagic.yaml` (CI). Sorunlu APK bu
scriptler YERİNE elle `flutter build` ile üretilmiş. → **Düzeltme: yayın APK'sı
`bash mobile/yayin-yap.sh apk` (ya da appbundle) ile üretilmeli**; elle build
YASAK. (Script başlığı zaten "önce bu unutulmuştu" diyor — regresyon.)

**Bulgu 2 — SSO butonları görünmüyor:** `SosyalGirisDugmeleri`, sunucudan
`GET /auth/oauth/saglayicilar` (`acik_saglayicilar()` → `.hazir` sağlayıcılar)
listesini okur; liste boşsa `SizedBox.shrink()` (hiç buton). API'ye
ulaşılamadığında (Bulgu 1) bu çağrı da düşer → boş liste → buton yok. Yani
**#2, #1'in DOWNSTREAM'i**: APK doğru API'ye baktığında butonlar görünür —
prod env'de sağlayıcı kimlikleri `.hazir` ise. `acik_saglayicilar` `TANITIM_SSO_*`
bayraklarına BAKMAZ (yalnız sağlayıcı yapılandırmasına) → web bayrakları mobili
ETKİLEMEZ (spec'in kaygısı karşılandı). **Prod kontrolü (kullanıcı):** Google/
Microsoft/Apple client id/secret + dönüş adresleri prod .env'de dolu mu.

**Bulgu 3 — iOS URL şeması EKSİKTİ (DÜZELTİLDİ):** `oauth_mobil_donus =
com.app.yonetiyor://oauth`. Android'de `AndroidManifest.xml` intent-filter
KAYITLI; iOS `Info.plist`'te `CFBundleURLTypes` HİÇ YOKTU → iOS'ta tarayıcı
akışı uygulamaya GERİ DÖNEMİYORDU (Safari'de boş sekme). **Düzeltme:** iOS
`Info.plist`'e `CFBundleURLTypes` (`com.app.yonetiyor`) eklendi (plist geçerli
doğrulandı; katkısal, telefon/e-posta girişini ETKİLEMEZ). iOS build ile
doğrulanmalı (bu makinede Flutter yok).

**Bulgu 4 — Google Cloud redirect adresi (spec: "TAM adresi yaz"):** Mobil
tarayıcı akışı (flutter_web_auth_2) WEB istemcisinden geçer; Google'ın gördüğü
`redirect_uri` SUNUCU callback'idir: `_callback_adresi` =
`{oauth_callback_taban}/auth/oauth/callback/{saglayici}`. Özel şema
(`com.app.yonetiyor://oauth`) Google redirect'i DEĞİL, sunucunun tarayıcıyı
uygulamaya geri yolladığı adrestir (uygulama tarafı — manifest/plist).
**Panele eklenecek (Authorized redirect URIs), prod `oauth_callback_taban`'a
göre:** `https://api.yonetio.site/auth/oauth/callback/google` (ve `/microsoft`,
`/apple`) — kanonik kullanılıyorsa `https://api.yonetiyor.com/...`. AYRI bir
"mobil redirect" GEREKMEZ; sunucu callback'i yeterli, özel şema app'te kayıtlı.

**Site sakini mobilden kaydolma:** akış (yönetici ekler → Tesis ID'li mail →
sakin mobilden tamamlar) SSO gerektirmez; #1 düzeltilince (doğru API) telefon/
e-posta + kod yolu zaten çalışır. SSO tercih edenler için #1+#2+#3 yeterli.

### 10.3 — Kanal tercihi + çok-rollü dedup (BACKEND BİTTİ)

**Kanal tercihi = MEVCUT göç 0055 (yeni göç DEĞİL).** Spec "göç 0055" diyor;
o zaten VAR: `app_user.bildirim_eposta/sms/mobil` + `GET/PATCH /me/bildirim-
tercihleri`. EKSİK OLAN, FCM gönderiminin `bildirim_mobil`'e UYMASIYDI. Düzeltme:
`_fetch_device_tokens*` SQL'ine `AND u.bildirim_mobil = true` (`_KANAL_KOSULU`) —
`bildirim_mobil=false` diyen kullanıcı push ALMAZ (in-app bildirim yine yazılır;
push EK gönderimdir). (İlk denemede topic-bazlı yeni bir JSONB kanal sistemi +
göç 0073 yazıldı, sonra göç 0055'in DELIVERY-kanalı olduğu görülünce GERİ ALINDI —
spec'in kastı buydu.)

**Çok-rollü dedup:** `_push_to_devices` artık `target_roles` VE `target_user_ids`'i
BİRLİKTE çözer ve TOKEN bazında dedup eder. Eskiden `uzak_okutma` ve
`gecikmis_okutma` İKİ ayrı `dispatch_external` çağrısı yapıyordu (biri görevliye
kişi, biri yönetime rol); görevli AYNI ZAMANDA yönetici ise İKİ push duyardı.
Artık TEK çağrı iki hedefi taşır, dedup tek push garanti eder. Görevli hâlâ KİŞİ
olarak hedeflenir (rol yayınına bırakılmaz).

**Rol yönlendirme:** her çağrı yerinde ZATEN doğru rollere/kişilere gidiyor
(dağıtık; announcements/complaints/reservations/kargo/unit_access/events/uzak_
okutma/notify). Merkezi bir yeniden-yazım YAPILMADI (regresyon riski; mevcut
yönlendirme çalışıyor). Vardiya özeti yeni olduğundan yönetici(admin/yönetici)
rollerine yönlendirildi (spec 10.3).

**Test:** `test_push.py` — `bildirim_mobil=false → hedeften çıkar` (canlı DB);
`ROL+KİŞİ birlikte → TOKEN dedup`. `test_uzak_okutma_hedef.py` tek-çağrı+dedup'a
güncellendi. Tümü yeşil.

### 10.2 — Vardiya sonu özeti (batching) (BACKEND BİTTİ)

Yeni bildirim tipi `vardiya_ozeti` (göç 0073 `ALTER TYPE ... ADD VALUE`; models.py
enum aynası; `push_metinleri` 7 dil). Yeni scheduler işi `summarize_ended_shifts`
(+ celery task `scheduler.summarize_shifts` + beat, `detect` periyoduyla): her
tenant, her vardiya için BUGÜN yerel tarihinde BİTMİŞ oluşumu bulur
(`_son_biten_vardiya`; gündüz=aynı gün, gece `bas>bit`=dün başlar bugün biter),
`gun_tipi`'ne göre koşup koşmadığını denetler (`_gun_uyar`; `resmi_tatil` takvim
yok → atlanır, DÖKÜMANTE sınırlama), vardiyanın aktif planlarının DISTINCT aktif
checkpoint'lerini (beklenen) ve vardiya aralığında en az bir kez okutulanları
(okutulan) sayar, TEK `vardiya_ozeti` bildirimi yazar (`dedup_key =
vardiya_ozeti:{shift}:{başlama_günü}` → IDEMPOTENT; beat sık koşsa da tekrar yok)
ve yönetime push atar. Okutmalar TEK TEK push üretmez; özet vardiya SONUNDA gider.

**Karar — gerçek-zamanlı ALARMLAR toplanmadı:** `kacirilan_tur`/`gecikmis_okutma`/
`uzak_okutma` bir PROBLEM anlatır ve GECİKTİRİLEMEZ (güvenlik); vardiya sonuna
ertelemek alarmı işe yaramaz kılardı. Batching yalnız RUTİN ilerleme özetine
uygulandı (spec örneği "24/26 okutuldu" = tamamlanma raporu). Diğer yüksek-hacim
(toplu tahakkuk/import) tek işlemde tek bildirim üretiyor; per-satır spam YOK.

**Sıklık kararı (beat):** 5 dk (300 s), SABİT (detect'ten AYRI). Gerekçe: özet
bir RAPOR (alarm değil) + IDEMPOTENT → sık koşmak zararsız/hafif; ama bir
vardiyanın "özetlenebilir penceresi" `[bitiş, ertesi yerel gece-yarısı]`dır
(gece-yarısında `bugün` dönünce oluşum değişir), gece-yarısına yakın biten
vardiyada bu pencere kısadır → 5 dk kaçırma penceresini <5 dk'ya indirir.
`detect_interval`e BAĞLANMADI: operatör onu (büyük kampus için) uzatınca özetin
sessizce gece-yarısı vardiyalarını kaçırması demekti.

**PROD OLAYI — beat konteyneri eski imajla kaldı:** İlk turda `beat` yeniden
derlenmedi (kanonik kısmi liste `beat`'i atlıyordu) → `beat_schedule`'daki yeni
`summarize-shifts` girdisi prod'a HİÇ ulaşmadı, özet çalışmadı. Kod DOĞRUYDU;
eksik olan DAĞITIMDI. Düzeltmeler: (a) `docs/P181-dagitim.md` kanonik komutuna
`beat` eklendi + uyarı; (b) **beat_schedule kilidi** `test_beat_schedule.py`:
her zamanlanan görev kayıtlı bir task + her `scheduler.*` periyodik task
zamanlanmış (tanımlanıp ZAMANLANMAYAN görevi yakalar — bu hatanın tam kendisi).
Mevcut testler fonksiyonu DOĞRUDAN çağırdığı için çizelge kaydını görmüyordu.

**Test:** `test_scheduler_vardiya_ozeti.py` (okutulan/beklenen sayımı + yönetime
tek push + idempotent + vardiya bitmeden özet yok + `hafta_ici` gün-tipi + GECE
vardiyası: gece-yarısını aşan pencere, önce/sonra okutma sayılır). `test_beat_
schedule.py` (çizelge kilidi, iki yön + on-demand doğrulama). Yeşil.

### 10.5 — Agresif yoklama (WEB düzeltildi)

Web (`admin-web`) dashboard `/api/dashboard/live` **15 sn** aralık; `revalidate
OnFocus` **true→false** çevrildi — her sekmeye dönüşte ek istek 15 sn'lik tazeliğe
bir şey katmadan gereksiz tekrar üretiyordu (odak/blur churn'ü). Aralık sekme
GİZLİYKEN zaten durur (SWR `refreshWhenHidden:false` varsayılanı = "görünmezken
yoklamayı durdur"). Kamera LİSTESİ tek sefer, kare tazeleme `visibilitychange` ile
zaten duruyor. Prod'daki "saniyeler içinde onlarca" 15 sn aralıkla AÇIKLANMAZ →
baskın kaynak büyük olasılıkla **MOBİL** (kullanıcının kapsamı: `yonetici_home_
screen`/`kameralar_screen` yoklama aralığı + görünürlük durdurması denetlenmeli).

### 10.1 — mobil push + izin + derin bağlantı (BİTTİ — dev makinesine Flutter kuruldu)

**Bulgu (dürüstlük):** Mobil push altyapısının ÇOĞU ZATEN vardı
(`lib/src/features/push/`): `Firebase.initializeApp`, token kaydı (`POST /devices`),
`requestPermission` (Android 13+ POST_NOTIFICATIONS manifest'te + iOS istemi),
ön-plan (`onMessage`→SnackBar), arka-plan DOKUNMA (`onMessageOpenedApp`), KAPALI
DOKUNMA (`getInitialMessage`), `routeForPushData` derin bağlantı eşlemesi. EKSİK
olan iki şey vardı:

- **Arka-plan mesaj HANDLER'ı (`onBackgroundMessage`) YOKTU** → eklendi:
  top-level `@pragma('vm:entry-point') firebaseMessagingBackgroundHandler` +
  `FirebasePushMessaging.initialize()` içinde `FirebaseMessaging.onBackgroundMessage(...)`
  kaydı (ana izolasyonda bir kez → native KALICI; kapalıyken de çalışır).
  Handler EK bildirim GÖSTERMEZ (backend `notification` gönderir, FCM tepsiyi
  kendi düşürür → çift olurdu); yalnız Firebase'i izolasyonda yeniden başlatıp
  loglar; data-only mesaj ileride buraya bağlanır.
- **`routeForPushData` DEVRİYE/VARDİYA tiplerini eşlemiyordu** (bu bildirimler
  güvenlik/yönetici cihazlarına gidiyor ama dokununca hiçbir yere gitmiyordu) →
  eklendi: `gecikmis_okutma`/`uzak_okutma`→`/patrol`, `kacirilan_tur`→
  `/patrol-plans`, `vardiya_ozeti`→`/vardiyalar`.

**Doğrulama (dev makinesinde Flutter 3.47.1 kuruldu):** `flutter analyze` temiz,
`flutter test` tüm mobil paket + yeni route-mapper testleri YEŞİL, `flutter build
apk --debug` başarılı (Gradle 9.1/AGP 9/Kotlin 2.3.20/NDK r28c). KGP uyarısı
(flutter_web_auth_2/nfc_manager) yalnız uyarı, mevcut Flutter'da derleniyor.

**CİHAZDA test (kullanıcı):** gerçek push teslimi + kilitli-ekran dokunma +
derin bağlantı ancak gerçek cihaz + prod FCM ile doğrulanır (izole ortamda
push gönderilemez). Yayın APK'sı `bash mobile/yayin-yap.sh apk`.

### 10.4 — SSO
- iOS URL şeması EKLENDİ; APK `yayin-yap.sh` ile derlenmeli (dart-define).
  Google callback zaten panelde (kullanıcı teyit etti).

---

## Program notu (dürüstlük)

P181 on bir bölümlük büyük bir programdır (auth altyapısı + göçler, 6 web düzeltme,
özet yeniden tasarım, rapor grafikleri, rezervasyon, mobil push). Bölümler SIRAYLA,
her biri yeşil + ayrı commit olarak ilerletilir; "kesintiye uğrarsan nerede
kaldığın belli olsun" gereği bu belge + commit'ler durumu taşır. Bölüm 0-5 bitti;
sıradaki Bölüm 6 (web arayüz düzeltmeleri — 6 alt madde).
