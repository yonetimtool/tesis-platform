# P250 — Ad/soyad, ödeme kodları, e-postalar, eğitim videoları, otomasyon

Bu belge P250'nin kararlarını, ölçümlerini ve **ölçülemeyenlerini** tutar.
Her bölüm ayrı commit. Bir maddeye "yapıldı" demek için gerçek akış
sürülmüş olmalı; sürülemeyen halka ayrıca **ÖLÇÜLEMEDİ** diye yazılır.

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
