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

## Bölüm 1 — E-posta zorunlu (TASARIM; uygulama sıradaki commit'lerde)

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

---

## Program notu (dürüstlük)

P181 on bir bölümlük büyük bir programdır (auth altyapısı + göçler, 6 web düzeltme,
özet yeniden tasarım, rapor grafikleri, rezervasyon, mobil push). Bölümler SIRAYLA,
her biri yeşil + ayrı commit olarak ilerletilir; "kesintiye uğrarsan nerede
kaldığın belli olsun" gereği bu belge + commit'ler durumu taşır. Bölüm 0 bitti;
Bölüm 1 tasarımı yukarıda.
