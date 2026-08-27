# P184 — Dağıtım notları

P184 **backend + mobil (Flutter)**. Web'e dokunulmadı.

## Backend — ne değişti

- **Yeni uç (2):** `POST /auth/oauth/rol-tamamla` + `POST /auth/oauth/rol-tamamla-dogrula`
  — SSO kimliğini bir rol hesabına bağlar (SMS'siz). `oauth.py`.
- **Hata düzeltmesi:** `kayit.py:_ROLLER` `"gorevli"` → `"tesis_gorevlisi"` (DB
  `user_role` enum'uyla hizalandı; latent görevli-kaydı hatası). Bkz. P184-kararlar K7.
- **Kilit registreleri güncellendi:** `contracts/openapi.yaml` (2 yol),
  `tests/test_denetci_salt_okuma.py` (2 uç), `tests/yetki/rol-matrisi.txt` (yeniden
  üretildi). Yeni APIError kodu YOK, yeni SECURITY DEFINER YOK, yeni göç YOK.
- **Test:** `tests/test_p177_kayit_akisi.py`'ye 6 SSO tamamlama testi + 2 kapalı-bayrak
  (503) parametresi eklendi.

### Bayrak — `YENI_KAYIT_AKISI`

Yeni uçlar `YENI_KAYIT_AKISI` bayrağına tabidir (varsayılan **kapalı → 503**). Prod'da
mobil kayıt/tamamlama çalışsın diye bu bayrak **açık** olmalı:

```
YENI_KAYIT_AKISI=true docker compose up -d api worker beat
```

Kapalıyken mobil kayıt ekranı da (parola + SSO) çalışmaz (uçlar 503 döner). Test iki
kipte de koşuldu (açık: happy-path'ler; kapalı: 503).

### Backend derleme + test (dev, konteyner içi)

```
cd infra
docker compose build api            # kod imaja gömülü — rebuild şart
YENI_KAYIT_AKISI=true docker compose up -d api
docker compose exec -T api python -m pytest -q -rs \
  tests/test_p177_kayit_akisi.py tests/test_denetci_salt_okuma.py \
  tests/test_sozlesme_sapmasi.py tests/test_yetki_kapsam.py
```

## Mobil — ne değişti

- **Kayıt ekranı yeniden kuruldu** (`kayit_screen.dart`): "Kayıt ol" → **"Tesis ID ile
  giriş/tamamlama"**. Roller: yalnız **sakin / güvenlik / tesis görevlisi** (yönetici
  YOK — web'den kaydolur). Parola yolu **e-posta OTP** (`rol-eposta-*`); SSO yolu
  **`rol-tamamla`** (email_verified=true → OTP yok). E-posta ZORUNLU, telefon isteğe
  bağlı iletişim. `onay_bekliyor` durumu için bilgilendirme kartı.
- **Giriş ekranı** (`login_screen.dart`): parolasız **SMS** kod bloğu KALDIRILDI
  (SMS ölü + mobil `tenant_slug` bilmez). SSO bağlama formu (`sosyal_baglama_formu.dart`)
  SMS yerine **rol + Tesis ID → `rol-tamamla`** kullanır.
- **API/denetleyici/depo:** `rolEpostaBasla/Dogrula`, `oauthRolTamamla(+Dogrula)`
  eklendi. Eski SMS metotları (`rolKayitBasla/Dogrula`, `oauthBaglan*`, `girisKodu*`)
  **DURUYOR ama UI ARTIK ÇAĞIRMIYOR** (SMS ileride açılabilir).
- **i18n:** 15 yeni anahtar × 7 dil + 2 değişen değer; `lib/l10n/gen/` yeniden üretildi.

### Kullanıcının yapacağı (APK üretimi + cihaz testi)

1. **APK üret (elle `flutter build` DEĞİL):**
   ```
   bash mobile/yayin-yap.sh apk
   ```
   Elle `flutter build apk` prod API adresini/`google-services.json`'u atlar.
2. **google-services.json** release paketinde gerekli (com.app.yonetiyor).

### Cihazda test edilecekler (bende üretilemez — gerçek cihaz + SSO gerekir)

- Google/Microsoft/Apple ile **yeni rol üyesi** tamamlama: rol + Tesis ID → oturum
  (email_verified=true → OTP sorulmadan).
- Apple **privaterelay** ile tamamlama (email_verified sayılır → OTP yok).
- Yöneticinin **eklemediği** e-posta ile deneme → "yönetici onayı bekleniyor" kartı,
  hesap açılmaz.
- Geçersiz Tesis ID → **aynı** "onay bekleniyor" mesajı (sızdırmama).
- Parola yolu: rol + Tesis ID + e-posta OTP → parola → oturum.
- Üç SSO butonunun kayıt + giriş ekranlarında görünmesi (P183 iOS URL şeması).

## Bilinen kapsam-dışı (P184'te DEĞİŞMEDİ)

- **Ayarlar → Hesabı sil → "kodla onayla"** hâlâ **SMS** koduna dayanır
  (`/me/hesap-sil/kod-iste`, `user.telefon` + SMS). Backend'de e-posta karşılığı YOK.
  Bu ikincil akış P184 kapsamı dışıdır (kayıt/giriş yüzeyi hedeflendi). Parolasız
  (SSO) kullanıcıların kendi hesabını silmesi için ileride bir **e-posta hesap-sil
  ucu** gerekir — ayrı iş.
- SMS uçları backend'de duruyor; `SMS_AKTIF` açılırsa telefon yolları yeniden
  kullanılabilir (mobil UI'ye geri bağlanması ayrı iş).
