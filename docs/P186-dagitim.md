# P186 — Dağıtım notları

P186 **backend + web (admin-web)**. Mobil KOD DEĞİŞMEDİ (yalnız doğrulama +
mevcut testler). Prod dağıtımı + cihaz testi kullanıcıda. Kararların gerekçesi
`docs/P186-kararlar.md`.

## Ne değişti

### Backend
- **`users.py` `PATCH /users/{id}` (kullanıcı düzenleme):**
  - Tamamlanmamış (`password_set=false`) hesapta **e-posta değişince davet
    yeniden gönderilir** (yeni jeton eski bağı geçersizler) — `davet_olustur_ve_gonder`.
  - Tamamlanmış hesabın e-postası **değiştirilemez** → `409`
    `eposta_tamamlanan_hesapta_degistirilemez` (yeni hata metni, 7 dil).
  - Rol **daire-tutan kümeden çıkınca** (resident → security/görevli/denetçi)
    aktif `unit_resident` bağları **kaldırılır**; denetime yazılır.
  - `GET /users/{id}` yanıtına `kayit_tamamlandi` (password_set) ve `daire_id`
    (aktif atama) eklendi — düzenleme formu bunlarla ön-dolar.
  - Denetim meta'sına `davet_yeniden` / `daire_baglari_kaldirildi` eklendi
    (hassas değer YOK).
- **Davet e-postası — yeni modül `davet_eposta.py`:** 7 dilde HTML + düz-metin
  çifti; tablo tabanlı, Outlook `mso`, karanlık mod, Tesis ID seçilebilir metin,
  mağaza düğmeleri metin-tabanlı, dinamik telif yılı, Arapça RTL,
  `html.escape`. **app.yonetiyor.com bağı YOK.**
- **Çok-parçalı e-posta:** `MesajSaglayici.gonder(..., html=None)` geriye-uyumlu
  eklendi; `SmtpEpostaSaglayici` `html` verilince `add_alternative` ile
  multipart gönderir. Davet e-postası bu yolla HTML + düz-metin taşır.
- **Excel içe aktarım (`ice_aktarim.py`):** kişi türüne **opsiyonel `eposta`
  sütunu** eklendi; içe aktarımla açılan her kişiye tekil eklemeyle **aynı davet
  (SMS + varsa HTML e-posta)** gönderilir (eskiden HİÇ gitmiyordu).
- **Dil:** davet e-postası ekleyen yöneticinin istek dilinde (Accept-Language →
  `istek_dili`, varsayılan tr). SMS kısa Türkçe kalır.

### Web (admin-web)
- Kullanıcı düzenleme formu (`users/page.tsx`):
  - **Blok/daire düzenlemede de görünür** (sakin+yönetici); açılışta mevcut
    atama ön-dolar, değişirse ata/kaldır (`/api/units/{id}/residents`).
  - Tamamlanmış hesapta **e-posta alanı salt-okunur** + açıklama ipucu
    (`kullaniciEpostaKilitli`, 7 dil).
- Yeni i18n anahtarı `kullaniciEpostaKilitli` (7 dil). `UserDetail` tipine
  `kayit_tamamlandi` + `daire_id` eklendi.

### Mobil
- **Kod değişikliği YOK.** Yönetici SSO+parola girişi zaten çalışıyor
  (bağlı SSO kimliği → oturum; telefon+parola → oturum); mobil kayıtta yönetici
  rolü zaten yok. Mevcut testler kapsıyor (bkz. kararlar Böl 1).

## Mağaza bağlantıları — DEĞERLER ALINDI (P186)

Her iki mağaza da yayında; **config varsayılanları artık dolu**, prod'da ayrıca
env vermeye gerek yok (override istenirse `.env.prod.example`'da örnek var):
- **PLAY_STORE_URL** = `https://play.google.com/store/apps/details?id=com.app.yonetiyor`
- **APP_STORE_URL** = `https://apps.apple.com/tr/app/id6797316863`

Davet e-postası ve SMS'i her iki mağaza düğmesini de gösterir. Bir mağaza
ileride çekilirse ilgili env'i boşaltmak düğmeyi otomatik gizler (kod değişmez).

## Prod'da doğrulanacaklar (burada üretilemez)
- E-posta SMTP: davet HTML e-postasının gerçekten gitmesi; **Gmail / Outlook /
  Apple Mail**'de render (tablo/mso/karanlık mod), görsel engelliyken Tesis ID
  okunur (kabul 11/13).
- İki mağaza düğmesinin çalışması; App Store id'si girilince düğmenin çıkması
  (kabul 12).
- Toplu Excel içe aktarımda çok sayıda davet e-postası **eşzamanlı** gönderilir;
  SMTP sağlayıcı yavaşsa istek süresi uzayabilir (Log sağlayıcıda etkisiz).
  Büyük dosyalarda gözlenmeli.
- Mevcut yöneticilerin telefon/SSO ile mobil girişinin bozulmadığı (kabul 2/3).

## Test durumu (bu makinede koşuldu)
- Backend: hedefli takım (davet_eposta + users + ice_aktarim + davet) **58
  yeşil**; tam takım koşumu dağıtım anında teyit (bkz. commit mesajı).
- admin-web: **1433 yeşil** (tsc temiz; i18n/leak dahil).
- Mobil: auth testleri (sosyal_giris + kayit_rol_secimi + login_screen_phone)
  koşuldu; mobil kod değişmediğinden takım P185'teki gibi yeşil.
