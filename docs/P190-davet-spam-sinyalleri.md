# P190 — Davet e-postası spam sinyallerini azaltma

Kimlik doğrulama temiz (SPF/DKIM/PTR pass); asıl sorun IP itibarı (zamanla
düzelir). Yine de şablon/başlık tarafındaki spam sinyalleri azaltıldı.

## 1) List-Unsubscribe (RFC 8058) — EKLENDİ
Davet e-postasına iki başlık eklendi:
```
List-Unsubscribe: <https://api.yonetiyor.com/davet/vazgec/{jeton}>, <mailto:vazgec@yonetiyor.com?subject=davet-vazgec>
List-Unsubscribe-Post: List-Unsubscribe=One-Click
```
- **Tek-tık uç:** `POST /davet/vazgec/{jeton}` (PUBLIC, oturumsuz). Gmail bu uca
  `List-Unsubscribe=One-Click` body'siyle POST atar; kişi davet
  e-postalarından çıkarılır (`app_user.davet_vazgecti=true`, göç 0075). Yönetici
  yeniden gönderse bile e-posta **atlanır** ve panelde `son_hata=davet_vazgecildi`
  görünür.
- **Yetki:** kimlik ÖNCESİ; jeton `{user_id}.{tenant_id}.{HMAC(jwt_secret)}`.
  Tenant jetondan çözülür ve RLS o bağlamla sağlanır — **SECURITY DEFINER
  gerekmez**. Başkasını iptal ettirmeye kapalı (HMAC imza). Geçersiz jetonda da
  200 (varlık sızdırmama).
- **Config:** `api_public_url` (varsayılan `https://api.yonetiyor.com`) — tek-tık
  bağının host'u; backend'e DOĞRUDAN POST'lanmalı (web aracısız). Prod'da bu
  adres public ve POST kabul eden backend olmalı.
- Kilitler: göç 0075, openapi (`/davet/vazgec/{jeton}`), denetçi KAPISIZ_
  MUTASYONLAR, rol-matrisi (regen; public=IZIN).

## 2) Metin/HTML paritesi — DOĞRULANDI (zaten iyi)
`davet_eposta` düz-metin karşılığı HTML ile AYNI bilgiyi taşıyor: selam, tesis
adı, **Tesis Kimliği**, davet bağlantısı, mağaza bağları, adımlar, telif yılı.
Boş/eksik plain-text yok. Çok-parçalı gönderim (text/plain kök + text/html
alternatif) SmtpEpostaSaglayici'de.

## 3) Konu satırı — İŞLEMSEL yapıldı
Eski: "{tenant} sizi Yönetiyor'a davet etti" (davet/promosyon çağrışımı).
**Yeni (uygulandı):** "{tenant} — tesis erişim bilgileriniz" (+ 6 dil).

Önerilen alternatifler (istenirse değiştirilebilir):
- "{tenant} — Tesis Kimliğiniz ve giriş"
- "{tenant} hesabınız hazır — Tesis Kimliği"
- "{tenant} — tesis uygulamasına erişim"

## 4) Bağlantı sayısı/türü — DOĞRULANDI
"Daveti Aç" düğmesi doğrudan `bag`e (`https://yönetiyor.com/davet/<jeton>`)
gider — **kısaltıcı/yönlendirme YOK**, kanonik yonetiyor.com alan adı. Diğer
bağlar: iki mağaza URL'si (gerçek) + List-Unsubscribe (api.yonetiyor.com).

## 5) Görsel/metin dengesi — DOĞRULANDI
Dış görsel YOK: logo metin işareti (`Yönetiyor` wordmark; `logo_url=None`),
mağaza düğmeleri metin-tabanlı. Görsel-ağırlıklı içerik yok.

## 6) Message-ID + Date — EKLENDİ
`SmtpEpostaSaglayici` artık her e-postaya `Date` (`formatdate`) ve `Message-ID`
(`make_msgid`, alan adı gönderen adresinden) ekliyor — smtplib bunları otomatik
EKLEMİYORDU ve eksikliği bir spam sinyaliydi. Bu TÜM e-postaları kapsar (davet,
OTP, parola sıfırlama, hoş geldin).

## Test
`test_davet` (jeton roundtrip + tek-tık iptal davet e-postasını durdurur +
geçersiz jeton 200) + registries (contract/denetçi/yetki-matris/secdef) yeşil.
Backend tam takım koşuldu.

## Dağıtım
`docker compose build migrate api worker` → göç 0075 → restart. `api_public_url`
prod'da doğru public API adresine ayarlı olmalı (List-Unsubscribe host'u).
SPF/DKIM zaten pass; IP itibarı zamanla + düşük hacim + düşük şikayet oranıyla
iyileşir.
