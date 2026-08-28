# P185 — Dağıtım notları

P185 **backend + web (admin-web) + mobil (i18n)**. Prod dağıtımı + cihaz testi
kullanıcıda. Kararların gerekçesi `docs/P185-kararlar.md`.

## Bayrak — `YENI_KAYIT_AKISI` (PROD'DA AÇIK ŞART)

Yönetici e-posta-kodlu kaydı (`yonetici-basvuru/-dogrula/-tesis`) ve rol-tamamlama
(`rol-eposta-*`, `rol-tamamla*`) bu bayrağa tabidir; **kapalıyken 503** döner ve web
yeni kayıt akışı çalışmaz. P184'te prod varsayılanı `true` yapıldı
(`docker-compose.prod.yml`). Doğrula:
```
docker compose -f docker-compose.prod.yml exec api \
  python -c "from app.config import settings; print(settings.yeni_kayit_akisi)"  # True olmalı
```

## Ne değişti

### Backend (commit b302ab9f)
- `kayit.py:_ROLLER` += `"yonetici"` → `rol-eposta-*` ve `rol-tamamla*` `rol="yonetici"`
  kabul eder (yönetici "mevcut tesise katıl" akışı P184 3-şart modeliyle).
- `roller.py:YONETILEBILIR_ROLLER["yonetici"]` += `"yonetici"` → bir yönetici
  add-user'dan eş-yönetici ekleyebilir (allowlist).
- `schemas.py:UserCreate.email` artık **zorunlu** (`EmailStr`). `ResidentCreate.email`
  opsiyonel kaldı (o uç admin-web formu tarafından kullanılmıyor).
- `units.py`: daire ataması `resident` VEYA `yonetici` kabul eder.
- Docker'da 182 test yeşil. Yeni uç/error kodu/göç YOK; rol-matrisi/openapi kilitleri
  değişmedi.

### Web (admin-web)
- **Panel SSO kaldırıldı** (commit 3c0af468): `GirisFormu` `yuzey==="tesis"` (app.*)
  değilse SSO çizilmez; panel.* yalnız tesis kodu + e-posta + parola.
- **Add-user formu** (3c0af468): e-posta ZORUNLU; telefon "giriş anahtarı" değil
  ("Cep telefonu / yalnızca iletişim"); blok/daire **sakin VE yönetici** rolünde
  görünür (sakinde zorunlu). i18n 7 dil.
- **Signup rework + baglama hatası** (bkz. aşağıdaki commit): yönetici kaydında AÇIK
  "Yeni tesis oluştur / Mevcut tesise katıl" seçimi; yeni tesis → tesis ADI (Tesis ID
  üretilir+gösterilir+mailenir); katıl → Tesis ID + e-posta OTP / SSO. SMS/telefon-kod
  ekranları KALDIRILDI. OAuth login'de "Tesis Kodu+telefon+SMS" bağlama formu
  KALDIRILDI → **"Bağlama isteği geçersiz" kök nedeni giderildi** (bkz. kararlar K6).

### Mobil (commit 4461635a)
- `sakinGirisAnahtari` metni "giriş anahtarı" → "yalnızca iletişim" (7 dil).
- Tamamlama ekranı TR çevirileri zaten mevcut; parity testi yeşil. (Cihazda İngilizce
  açılması cihaz-dili kaynaklıydı, çeviri eksikliği DEĞİL — kabul 12.)

## Kabul kriterleri durumu

| # | Kriter | Durum |
|---|--------|-------|
| 1 | Yeni tesis / katıl ayrımı (web+mobil) | Web ✓ · **Mobil: yönetici kaydı ertelendi (aşağıda)** |
| 2 | Yeni tesiste Tesis ID istenmiyor, üretiliyor | ✓ (web; backend zaten) |
| 3 | Katılan Tesis ID giriyor | ✓ (web) |
| 4 | SSO'da OTP/telefon yok | ✓ (web binding formu kaldırıldı) |
| 5 | Telefon "giriş anahtarı" değil | ✓ (web + mobil) |
| 6 | E-posta zorunlu | ✓ (form + backend) |
| 7 | Blok/daire sakin+yönetici; yöneticiye daire | ✓ (form + backend) |
| 8 | Roller web'de yok | ✓ (zaten enforce: `MOBIL_ROLLERI` 403) |
| 9 | Yönetici web+mobil kaydolur | Web ✓ · **Mobil yönetici kaydı ertelendi** |
| 10 | Panel SSO yok | ✓ |
| 11 | Bağlama hatası kök neden | ✓ (kararlar K6'da yazıldı + web'de giderildi) |
| 12 | Mobil TR + parity | ✓ |
| 13 | Mevcut giriş bozulmadı | ✓ (`login-phone` durur; telefon zorunlu kaldığından yöneticiler telefonla/SSO ile girer) |

## Bilerek ERTELENEN (dürüstlük — bu turda YAPILMADI)

1. **Mobil YÖNETİCİ kaydı (kabul 1/9 mobil tarafı):** P184'te mobil kayıt yalnız
   sakin/güvenlik/görevli tamamlamasına indirgenmişti. P185 mobilde yöneticinin de
   (yeni tesis / katıl) kaydolmasını istiyor. Bu, Flutter kayıt ekranına yönetici
   akışının (tesis oluştur = `yonetici-basvuru/-dogrula/-tesis`; katıl = `rol-tamamla`
   rol=yonetici) yeniden eklenmesi demek — ayrı bir mobil iş. Backend HAZIR (yalnız
   mobil UI eksik). Web yönetici kaydı tamamdır.
2. **Telefonu tamamen opsiyonel yapmak:** telefon backend'de global-benzersiz anahtardı
   (`tenant_id_by_phone`, benzersizlik kısıtı, davet SMS). Etiketi "giriş anahtarı"ndan
   arındırıldı (kabul 5 ✓) ama alan hâlâ zorunlu. Opsiyonele çevirmek bir göç + login
   işi; kabul 13 (mevcut girişi bozma) riski taşır → ayrı iş.
3. **Onay kuyruğu inceleme paneli:** `kayit_onay_kuyrugu` yazılıyor ama yöneticinin
   listeleyip onayladığı UI YOK (P184'ten beri). "Mevcut tesise katıl"ın BİRİNCİL yolu
   allowlist (ön-ekleme); ön-eklenmemiş denemeler kuyruğa düşer ama işlenmez → kuyruk
   inceleme paneli ayrı iş.

## Cihazda / prod'da doğrulanacaklar (burada üretilemez)

- Gerçek Google/Microsoft/Apple ile web yönetici kaydı (yeni tesis + katıl) → OTP/
  telefon sorulmadığı; Apple privaterelay geçerli.
- E-posta SMTP: yönetici-basvuru/rol-eposta kodlarının gerçekten gitmesi.
- Prod'da `YENI_KAYIT_AKISI=true` (yoksa 503).
- Mevcut yöneticilerin telefon/SSO ile app.* girişinin bozulmadığı (kabul 13).
