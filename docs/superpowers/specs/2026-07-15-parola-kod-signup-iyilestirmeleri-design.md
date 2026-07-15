# Parola politikası + geçici kod kopyalama + signup iyileştirmeleri

Tarih: 2026-07-15 · Kapsam: backend + mobil + contracts · Branch: main

## Kararlar (onaylandı)

1. **Sakin oluştururken parola verilirse geçici kod ÜRETİLMESİN** (verilmezse üretilsin).
2. **Geçici kod kopyalanabilsin** (panoya kopyala butonu — 3 dialog).
3. **Signup ipucu:** "örn. Acme Plaza" → "örn. Örnek Sitesi".
4. **Parola koşulu:** en az 8 karakter + ≥1 büyük harf + ≥1 rakam + ≥1 sembol
   (backend tek doğrulayıcı; mobil anlık).
5. **"Tesis oluştur" (5-A):** giriş öncesi rol bilinmediğinden role göre gizlenemez;
   bağlantının altına "yalnızca site yöneticileri için" etiketi.

## Backend

- `schemas.py`: `_validate_password_strength(v)` (len≥8, büyük harf, rakam, sembol;
  Türkçe harfler dahil). `field_validator` ile: `SetPasswordRequest.new_password`,
  `SignupRequest.password`, `PasswordChangeRequest.new_password`,
  `UserCreate.password` (opsiyonel), `ResidentCreate.password` (YENİ, opsiyonel).
- `ResidentCreate`: `password: str | None` eklenir; `ResidentCreatedOut.temp_code`
  → `str | None` (parola verilirse null).
- `residents.py create_resident`: parola verilirse `password_hash`+`password_set=
  true` (temp_code None); verilmezse geçici kod (mevcut).

## Contracts
- `auth.md`: parola politikası kısa notu.
- `openapi.yaml`: password alanlarına açıklama; ResidentCreate password + temp_code nullable.

## Mobil
- Paylaşımlı `showTempCodeDialog(context, code, message)` — **Kopyala** (Clipboard)
  + Tamam; staff_screen + residents_screen (ekle + reset) bunu kullanır.
- `login_screen`: "Tesis oluştur" altına "Yalnızca site yöneticileri için" caption.
- `signup_screen`: tesis adı hint "örn. Örnek Sitesi".
- Paylaşımlı `passwordError(String)` (len/upper/digit/symbol) — signup, set-password,
  profil parola-değiştir, staff/sakin ekle parola alanlarında validator.

## Test
- Backend: mevcut testlerdeki create/set/change parolaları koşula uygun hale getir
  (ör. "Parola123!"); test_signup/test_profile/test_auth_phone/test_users/test_residents.
  Yeni: zayıf parola → 422; sakin parola ile → temp_code null.
- `flutter analyze` temiz. Full down -v gerekmez (şema/migration değişmez).

## Kabul
Sakin parola ile açılınca kod yok; kod kopyalanabilir; signup jenerik örnek;
parolalar güçlü; "Tesis oluştur" yönetici-için etiketli. Testler yeşil.
