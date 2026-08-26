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

## Program notu (dürüstlük)

P181 on bir bölümlük büyük bir programdır (auth altyapısı + göçler, 6 web düzeltme,
özet yeniden tasarım, rapor grafikleri, rezervasyon, mobil push). Bölümler SIRAYLA,
her biri yeşil + ayrı commit olarak ilerletilir; "kesintiye uğrarsan nerede
kaldığın belli olsun" gereği bu belge + commit'ler durumu taşır. Bölüm 0 ve 1
bitti; sıradaki Bölüm 2 (parola sıfırlama).
