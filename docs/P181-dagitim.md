# P181 — Dağıtım notları (prod)

Geliştirme ortamında çalışıldı (192.168.20.101). Prod'u kullanıcı uygular. Bu
belge her bölümün prod'a taşınması için GEREKENLERİ toplar: göçler, yeniden
derlenecek servisler, yeni env değişkenleri.

**Kanonik dağıtım komutu** (kısmi derleme YAPMA — bkz. RUNBOOK §6.1):
`docker compose build migrate api admin-web worker` (ya da argümansız
`up -d --build`). `migrate` göçleri uygular; `api`/`admin-web` kod gömülü olduğu
için mutlaka yeniden derlenir.

---

## Bölüm 1 — E-posta zorunlu + doğrulama beklemede

- **Göç:** `0070_eposta_dogrulandi` — `app_user.eposta_dogrulandi`
  (NOT NULL DEFAULT false) + `kod_amaci` enum `eposta_ekle`. Geriye dönük
  güvenli: mevcut kullanıcılar doğrulanmamış (false) başlar.
- **Yeniden derle:** `api` (yeni uçlar + model), `admin-web` (profil kartı + BFF).
- **Yeni env:** YOK.

## Bölüm 2 — Parola sıfırlama ("şifremi unuttum")

- **Göç:** `0071_kod_amaci_sifre_sifirla` — `kod_amaci` enum `sifre_sifirla`.
- **Model düzeltmesi (Böl.1 gizli hatası):** `models.py` `kod_amaci` ENUM'una
  `eposta_ekle` + `sifre_sifirla` eklendi; `api` yeniden derlenmeli (yoksa
  `/me/eposta/dogrula` ve `/auth/sifre/dogrula-ve-ayarla` 500 verir).
- **Yeniden derle:** `api` (2 yeni uç), `admin-web` (`/giris/sifremi-unuttum`
  sayfası + BFF).
- **Yeni env:** YOK. E-posta gönderimi mevcut `SMTP_*` ile (compose'da zaten
  tanımlı); SMS yok. Prod'da gerçek kod e-postası için `SMTP_HOST/USER/PASSWORD/
  FROM` dolu olmalı (boşsa gönderim LOG'a düşer, sessizce "gönderildi" demez).

## Bölüm 3 — Parola değiştirme (giriş sonrası)

- **Göç:** YOK. **Yeniden derle:** YOK. **Yeni env:** YOK.
- Zaten mevcuttu (`PATCH /me/password` + profil `SifreDegistir`), yalnız
  doğrulandı — dağıtım gerektirmez.

## Bölüm 4 — E-posta OTP ile giriş

- **Göç:** YOK. **Yeni env:** YOK. **Yeniden derle:** yalnız `api`
  (`eposta-kod-dogrula` başarısında `eposta_dogrulandi=true` yazan tek satır).
- Frontend/BFF zaten mevcuttu (P172), değişmedi.

## Bölüm 5 — E-posta şablonları (5 adet)

- **Göç:** YOK. **Yeni env:** YOK. **Yeniden derle:** yalnız `api` (yeni
  `app/eposta_sablonlari.py` + `telefon_kodu` şablonu çağırır).
- Not: prod'da gerçek e-posta için `SMTP_*` dolu olmalı (Bölüm 2'deki not).
  Gönderen adresi markası `noreply@yonetiyor.com` — tenant `smtp_gonderen` /
  env `SMTP_FROM` ile örtüşmeli.

## Bölüm 6.5 — Bildirimler: toplu işlem

- **Göç:** `0072_notification_silindi_at` (nullable kolon, geriye dönük güvenli).
- **Yeniden derle:** `api` (3 yeni uç + model) + `admin-web` (toplu UI + 3 BFF).
- **Yeni env:** YOK.

---

## Bölüm 6.1–6.4 — Daire/görev/harita düzeltmeleri

- **Göç:** YOK. **Yeni env:** YOK.
- **Yeniden derle:** 6.1 `api` (residents endpoint sakin adı) + `admin-web`
  (UnitDetail, units, plan-haritasi, tasks). 6.2/6.3/6.4 yalnız `admin-web`.

---

## Bölüm 7.1/7.2 — Düzenlenebilir yerleşim + banner

- **Göç:** YOK (JSONB `pano_tercihi`ye yeni anahtar). **Yeni env:** YOK.
- **Yeniden derle:** `api` (PanoSatir şeması) + `admin-web` (dashboard yerleşim).
- Geriye dönük uyumlu: eski kayıtlar (satirlar yok) tam/yarım eşleşmeyle çalışır.

## Bölüm 7.3/7.4 — Devriye görseli + 3D kamera

- **Göç:** YOK. **Yeni env:** YOK.
- **Yeniden derle:** 7.3 `api` (dashboard son_okutma) + `admin-web`. 7.4 yalnız
  `admin-web` (bina-sahnesi).

---

## Bölüm 8.0/8.1 — Rapor doğrulama + web grafikleri

- **Göç:** YOK. **Yeni env:** YOK.
- **Yeniden derle:** `api` (katalog grafik config + şema) + `admin-web`
  (RaporGrafik). Geriye dönük uyumlu (grafik yoksa yalnız tablo).

---

## Ara iş — admin-web test paketi + Prod düzeltmeleri A-D

- **Test paketi greening:** yalnız `admin-web` (test + birkaç bileşen/sayfa
  düzeltmesi). **Göç YOK, yeni env YOK.** Ürün etkisi olan düzeltmeler:
  DevriyeGorunumu/profil/eposta-dogrula-kart tanımsız CSS jetonları (kırık stil)
  ve adsız input'lar (erişilebilirlik) — `admin-web` yeniden derlenince gelir.
- **A-D "şifremi unuttum" (web):** **Göç YOK, yeni env YOK, yeni backend uç YOK.**
  **Yeniden derle:** yalnız `admin-web` (`GirisKabuk` + sıfırlama sayfası + link +
  2 i18n anahtarı). Bölüm 2 uçları (`/auth/sifre/*`) değişmedi.
- **A (mobil) — BEKLİYOR:** mobil giriş telefonla; e-posta tabanlı sıfırlama için
  ayrı ekran gerekir. Bu makinede **Flutter YOK** → derlenip test edilemedi;
  Bölüm 10 mobil işiyle birlikte ele alınacak ve APK derleme/test KULLANICIDA.

---

## Göç sırası özet

```
0069_yonetici_by_email      (P180)
0070_eposta_dogrulandi      (P181 Böl.1)
0071_kod_amaci_sifre_sifirla (P181 Böl.2)
0072_notification_silindi_at (P181 Böl.6.5)
```

Göçler ileri-uyumlu ve geriye dönük güvenli (enum ADD VALUE + nullable-default
kolon). `create_type=False` enum'ları model tarafında da güncellendi.
