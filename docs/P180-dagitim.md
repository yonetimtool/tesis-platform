# P180 — Dağıtım

Kararlar: `docs/P180-kararlar.md`. Prod dağıtımını kullanıcı yapar; geliştirme
ortamında (192.168.20.101) uygulanıp doğrulandı.

## 1. Şema göçü (ZORUNLU)

Yeni göç: **`0069_yonetici_by_email`** (SSO kayıtta e-posta ile mevcut yönetici
hesabı eşleşmesi — kriter 4). `migrate` her açılışta idempotent uygular:

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build migrate api worker
# /health -> schema.database == schema.beklenen == 0069_yonetici_by_email
```

## 2. Çalışma zamanı değişkeni (ZORUNLU — `.env.prod`)

**`OAUTH_KAYIT_DONUS`** — niyet=kayıt callback dönüşü (yönetici kayıt tamamlama
sayfası). **BOŞ = SSO KAYIT KAPALI** (`basla` 503; giriş akışı etkilenmez).

```env
OAUTH_KAYIT_DONUS=https://app.yonetiyor.com/kayit
```

- Compose'a geçişi **eklendi** (api servisi; `test_compose_oauth` kanıtlıyor).
- Mevcut `OAUTH_WEB_DONUS` / `OAUTH_MOBIL_DONUS` **değişmedi** — giriş akışı aynen.

## 3. Backend — YAPILDI ve DOĞRULANDI (bu commit)

- `/auth/oauth/baslat/{saglayici}`: `niyet ∈ {giris, kayit}` (varsayılan `giris`
  → mevcut davranış). `kayit` için iki zorunlu onay **backend'de de** doğrulanır
  (yoksa 422 `onay_gerekli`). Onaylar IP + zaman ile state'e yazılır.
- Callback: niyet **state'ten** okunur (istekten değil → open-redirect yok); dönüş
  adresi niyete göre (`OAUTH_KAYIT_DONUS`). `_kayit_coz`: kimlik bağlı→giriş,
  e-posta tek yönetici eşleşmesi→mevcut_hesap (yeni kimlik bağlanır), aksi→kayıt.
- `/auth/oauth/sonuc`: `durum ∈ {giris, baglama_gerekli, kayit, mevcut_hesap}`.
  `kayit` → `baglama_jetonu` (onaylar gömülü) + ad/eposta; `mevcut_hesap` → oturum
  + "zaten hesabınız var" (kriter 4).
- `/auth/kayit/tesis-olustur`: `baglama_jetonu`'daki onaylar **append-only
  audit_log**'a yazılır (onay+IP+zaman) + `user.pazarlama_eposta = onay_ticari`.
- Apple: private relay geçerli (e-posta zaten eşleşmede kullanılmaz); ad yalnız ilk
  yetkilendirmede alınır, boş gelince üzerine yazılmaz (mevcut `Kimlik.ad`).
- Testler: `test_oauth`, `test_compose_oauth`, `test_tesis_olustur`,
  `test_tesis_kodu_ve_coklu_yonetici`, `test_rol_secimli_kayit` — **hepsi yeşil**.

**Build gerektiren backend değişkeni YOK** (yalnız çalışma zamanı `OAUTH_KAYIT_DONUS`).

## 4. Frontend — KALAN İŞ (build-time; bir sonraki artım)

Backend hazır; arayüz `niyet`i taşımalı. Değişecek dosyalar ve davranış:

### 4a. Tanıtım — `apps/tanitim-web/components/SsoDugmeleri.tsx`
- Şu an: `href={\`${APP_ADRESI}/login?saglayici=${s.kod}\`}` → kullanıcı **giriş**
  ekranına düşüyor (asıl kusur). Kayıt akışına yönlendir:
  `${APP_ADRESI}/kayit?saglayici=${s.kod}&niyet=kayit` — onay durumu da taşınır
  (`onay_sozlesme`, `onay_kvkk`, `onay_ticari`). Butonlar zaten iki zorunlu onay
  işaretlenmeden `kilitli` (mevcut `onaylarTamam`).

### 4b. admin-web — OAuth başlatma (`components/SosyalGiris.tsx` / `/kayit`)
- `/api/auth/oauth/baslat/{saglayici}` gövdesine **`niyet` + `onay_*`** ekle
  (kayıt yolunda). Giriş yolunda `niyet` gönderme (varsayılan `giris`).
- BFF `baslat` çağrısına `x-istemci-ip` başlığını ekle (onay IP'si için) —
  diğer `/api/kayit/*` uçlarındaki desenle aynı.

### 4c. admin-web — sonuç işleme (`app/giris/oauth/page.tsx`)
- `durum="kayit"` → kayıt tamamlama: eksik alan (telefon) sorulur, **parola
  sorulmaz**, `baglama_jetonu` ile `tesis-olustur` (site adı = tesis_ad). Mevcut
  `/kayit` SSO makinesi bunu zaten yapıyor; `durum` dalını ekle.
- `durum="mevcut_hesap"` → oturum açıldı; "Bu e-posta ile zaten hesabınız var,
  giriş yapıldı" mesajı göster, ana ekrana geç (kriter 4).

### 4d. admin-web giriş — hesap yok bağlantısı (`components/SosyalGiris.tsx`, kriter 6)
- `durum="baglama_gerekli"` ekranına "Hesabınız yok mu? **yonetiyor.com/yonetici/
  kayit**" bağlantısı ekle. Backend zaten sessizce hesap açmaz (giriş niyeti
  yaratmaz); bu yalnız yönlendirme.

> Frontend `NEXT_PUBLIC_*` build-time gömülür → değişiklikten sonra `--build`
> (yalnız `up -d` yetmez).

## 5. Kabul kriterleri — durum
- 1,2,3,7 backend tarafı hazır; uçtan uca için 4a-4c gerekiyor.
- 4 (mevcut hesap) backend'de tam; arayüz mesajı 4c.
- 5 (Apple) backend'de tam.
- 6 backend'de tam (sessiz açma yok); bağlantı 4d.
