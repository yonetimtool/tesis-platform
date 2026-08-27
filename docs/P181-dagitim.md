# P181 — Dağıtım notları (prod)

Geliştirme ortamında çalışıldı (192.168.20.101). Prod'u kullanıcı uygular. Bu
belge her bölümün prod'a taşınması için GEREKENLERİ toplar: göçler, yeniden
derlenecek servisler, yeni env değişkenleri.

**Kanonik dağıtım komutu** (kısmi derleme YAPMA — bkz. RUNBOOK §6.1):
`docker compose build migrate api admin-web worker beat` (ya da argümansız
`up -d --build` — TÜM kod-taşıyan servisleri kapsar, ÖNERİLEN). `migrate` göçleri
uygular; `api`/`admin-web` kod gömülü olduğu için mutlaka yeniden derlenir.

> ⚠️ **`beat`'i UNUTMA (P181 10.2 gerçek olayı):** Eski kanonik liste `beat`'i
> ATLIYORDU. Celery `beat_schedule` (zamanlanmış görevler) `celery_app.py`'de kod
> olarak gömülüdür ve **yalnız `beat` imajında** yaşar. `beat` yeniden
> derlenmezse yeni bir zamanlanmış görev (vardiya özeti gibi) prod'da HİÇ
> koşmaz — `api`/`worker` güncel görünürken `beat` eski çizelgeyle döner. Zamanlama
> değişikliğinde ya `beat`'i listeye ekle ya argümansız `up -d --build` kullan.
> (`infra/RUNBOOK-PROD.md` §6.1'deki kısmi liste de aynı boşluğu taşıyor.)

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

## Bölüm 8.0/8.1/8.2 — Rapor doğrulama + web + PDF/Excel grafikleri

- **Göç:** YOK. **Yeni env:** YOK.
- **Yeniden derle:** `api` (katalog grafik config + şema + `rapor_ciktilari`
  PDF/Excel grafik gömme) + `admin-web` (RaporGrafik). Geriye dönük uyumlu
  (grafik yoksa yalnız tablo). Bağımlılık: `reportlab`/`openpyxl` ZATEN kurulu
  (rapor hattı mevcut) — yeni paket YOK.

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

## Bölüm 9 — Web rezervasyon (yönetim + alan yönetimi)

- **Göç:** YOK. **Yeni env:** YOK. **Backend:** DEĞİŞMEDİ (mevcut
  `/common-areas` + `/reservations` uçları kullanıldı).
- **Yeniden derle:** yalnız `admin-web` (yeni `/rezervasyon-yonetimi` sayfası +
  BFF `common-areas` POST/PATCH + menü/rol + i18n).

---

## Bölüm 10 — Mobil bildirimler (BACKEND) + SSO/iOS

### Backend (BİTTİ — bu oturum)

- **Göç:** `0073_vardiya_ozeti_bildirim` — `ALTER TYPE notification_tip ADD
  VALUE 'vardiya_ozeti'` (idempotent, geriye dönük güvenli). **Yeni env:** YOK.
- **Yeniden derle:** `api` (FCM kanal kapısı + dedup + vardiya özeti scheduler +
  push metni), **`worker`** ve **`beat`** (yeni celery task `scheduler.
  summarize_shifts` + beat schedule). `migrate` göçü uygular.
- **10.3 kanal tercihi:** MEVCUT göç 0055 (`bildirim_mobil`) kullanıldı — yeni
  göç YOK. FCM artık `bildirim_mobil=false` kullanıcıya push atmaz.
- **10.3 dedup:** çok-rollü/hem-kişi-hem-rol kullanıcı tek push (token dedup).
- **10.2 batching:** vardiya sonu tek `vardiya_ozeti` özeti (beat) + `uzak_okutma`
  yönetim push kısması (aynı görevli 30 dk tekrarında yönetime tek push; `api`).
  **Göç/env YOK** — yalnız `api` yeniden derlenir.
- **10.5 (web):** dashboard `/dashboard/live` `revalidateOnFocus:false` → yalnız
  `admin-web` yeniden derlenir.

### Mobil + SSO (KULLANICI — Flutter, Windows'ta)

- **iOS `Info.plist`:** `CFBundleURLTypes` (`com.app.yonetiyor`) EKLENDİ →
  yeni iOS build gerekir. Katkısal; telefon/e-posta girişini etkilemez.
- **KRİTİK — yayın APK'sı:** MUTLAKA `bash mobile/yayin-yap.sh apk` (ya da
  `appbundle`) ile üretilmeli — elle `flutter build` `--dart-define=API_BASE_URL=
  https://api.yonetio.site`'ı atlıyor ve APK `http://10.0.2.2:8000`'e (emülatör)
  gidiyor → API'ye ulaşamıyor. Script bu adresi geçer + şifresiz/yerel reddeder.
- **Google Cloud (teyit edildi — çalışıyor):** `https://api.yonetio.site/auth/
  oauth/callback/{google,microsoft,apple}` panelde ekli.
- **Prod .env kontrolü:** OAuth client id/secret dolu mu (`acik_saglayicilar()`
  `.hazir` → mobil butonlar buna bakar).
- **10.1/10.4 mobil kodu (talimat, docs/P181-kararlar.md §10.1):** firebase_
  messaging background handler + izin akışı (iOS requestPermission, Android 13+
  POST_NOTIFICATIONS) + bildirim `data.tip`/`data.*` ile go_router derin bağlantı.
  `data` alanları backend'te ZATEN gönderiliyor. Flutter kodu bu oturumda YAZILMADI
  (kullanıcı uygular).

---

## Göç sırası özet

```
0069_yonetici_by_email      (P180)
0070_eposta_dogrulandi      (P181 Böl.1)
0071_kod_amaci_sifre_sifirla (P181 Böl.2)
0072_notification_silindi_at (P181 Böl.6.5)
0073_vardiya_ozeti_bildirim  (P181 Böl.10.2)
```

Göçler ileri-uyumlu ve geriye dönük güvenli (enum ADD VALUE + nullable-default
kolon). `create_type=False` enum'ları model tarafında da güncellendi.
