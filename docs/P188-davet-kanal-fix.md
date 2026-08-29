# P188 — Davet mailleri gitmiyor: kanal E-POSTA'ya çevrildi

## Kök neden
`davet_gonder` (davet.py) "SMS ASIL KANAL" varsayımıyla yazılmıştı: SMS'i ÖNCE
deniyor ve panel özetini SMS sonucundan yazıyordu. Prod'da `SMS_AKTIF=false`
olduğu için SMS sağlayıcısı `KapaliSms`'tir ve `sms_kanali_kapali` döner. Özet
SMS'e sabitlendiğinden davet tablosu:
```
son_kanal: sms · son_durum: yapilandirilmadi · son_hata: sms_kanali_kapali
```
gösteriyordu. Kod e-postayı da deniyordu ama özet SMS'i yansıttığı için
e-posta hiç görünmüyor, kayıt akışı tamamen kilitleniyordu (kimse Tesis ID'yi
öğrenemiyor → kimse kaydolamıyor).

## Yapılan

### 1) E-POSTA BİRİNCİL kanal
`davet_gonder` yeniden sıralandı: **önce e-posta** (hedef e-posta varsa DAİMA
denenir), panel özeti e-postadan yazılır. `DavetGonderimSonucu(kanal=...)`
çağrıları `"sms"` → `"eposta"` (residents/users).

### 2) SMS kapalıyken HİÇ denenmez
SMS yalnız `settings.sms_aktif` ise denenir (`if user.telefon and
settings.sms_aktif`). Kapalıyken SMS bloğu tümden atlanır — "sms_kanali_kapali"
gürültüsü ve yanıltıcı "başarısız" özeti üretilmez. SMS açılınca (tek satır
`SMS_AKTIF=true`) ek kanal olarak devreye girer.

### 3) Başarısız davetler yeniden gönderilebilir
`POST /davet/{user_id}/yeniden` zaten `davet_gonder`'i çağırıyor → düzeltmeyle
artık e-postadan gider. Mevcut iki başarısız davet bu uçla yeniden gönderilir
(hesap parolasız olduğu sürece; koşul davet router'da). Ek kod gerekmedi.

### 4) Aynı kalıp taraması (OTP / parola sıfırlama / hoş geldin)
- **Davet:** SMS-birincil olan TEK otomatik gönderimdi → düzeltildi.
- **Kayıt/giriş OTP:** `eposta_kodu_uret_ve_gonder` (e-posta) — `rol-eposta-basla`,
  `giris/eposta-kod-iste`. ✓ E-posta.
- **Parola sıfırlama** (`sifre_sifirla`): `eposta_kodu_uret_ve_gonder`
  (amac=`sifre_sifirla`). ✓ E-posta.
- **Hoş geldin** (yönetici tesis açınca): `_eposta_gonder`. ✓ E-posta.
- **Telefon-yolu kod alternatifleri** (`kod_uret_ve_gonder`: `kayit/rol-basla`,
  `giris/kod-iste`, `hesap-sil/kod-iste`, oauth SMS bağlama): SMS-tasarımı
  gereğidir (kullanıcı telefon yolunu seçer). SMS kapalıyken `KapaliSms` no-op
  yapar ve `[SMS/kapali] gonderim YAPILMADI` loglar — davet gibi e-postayı
  maskeleme sorunu YOK (maskelenecek e-posta yok). E-posta muadilleri
  (`eposta-kod-iste`/`eposta-basla`) desteklenen yoldur. Bu alternatifleri bu
  turda yeniden yazmadım (davet dışı, ürün kararı); notu bıraktım.

### 5) Yapılandırılmamış kanal sessiz kaybolmasın
- **Log:** birincil kanal (e-posta) ulaşmazsa `davet_gonder` açık **WARNING**
  düşer (`[davet] E-POSTA ULASMADI ... SMTP yapilandirmasini kontrol edin`);
  hiç hedef kanal yoksa da uyarır. INFO log görünür (P134).
- **Panel:** `GET /davet` (yönetici davet paneli) `son_kanal/son_durum/son_hata`
  döndürür. Düzeltmeyle bunlar artık **e-posta** kanalını yansıtır
  (`eposta / yapilandirilmadi / saglayici_yok` gibi) — yani "SMTP yapılandır"
  mesajı doğru kanaldan görünür; eskiden yanıltıcı `sms / sms_kanali_kapali`
  yazıyordu.

## ÖNEMLİ — prod SMTP yapılandırması
Bu düzeltme e-postayı **birincil ve görünür** yapar. E-postanın gerçekten
GİTMESİ için tesisin/ortamın SMTP'si yapılandırılmış olmalı (`smtp_host` env ya
da tesisin mesaj ayarları). Yapılandırılmamışsa sağlayıcı `LogEposta`'dır: mail
gitmez ama artık davet paneli + WARNING log bunu **açıkça** gösterir
(`son_durum=yapilandirilmadi`). Prod'da davetlerin ulaşması için SMTP env'i
(ör. Resend) doğrulanmalı.

## Test
`test_davet` + `test_eposta_kanali` güncellendi (kanal `sms`→`eposta`; yeni
regresyon testi: e-postalı sakinde YALNIZ eposta gönderim kaydı, SMS kaydı YOK).
Backend tam takım koşuldu.

## Dağıtım
`docker compose build api worker` → restart. SMTP env'ini doğrula. Sonra mevcut
başarısız davetleri `POST /davet/{id}/yeniden` ile yeniden gönder.
