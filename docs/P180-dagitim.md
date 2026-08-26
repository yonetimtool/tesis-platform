# P180 — Dağıtım

Kararlar: `docs/P180-kararlar.md`. Geliştirme ortamında (192.168.20.101) uygulandı
ve doğrulandı; prod dağıtımını kullanıcı yapar.

## 0. Callback adresleri DEĞİŞMEDİ (önemli)

Sağlayıcı panellerindeki callback'ler **aynen kalır**:
```
https://api.yonetiyor.com/auth/oauth/callback/{google,microsoft,apple}
```
Bu adres `OAUTH_CALLBACK_TABAN`'dan (`https://api.yonetiyor.com`) üretilir ve
P180'de **dokunulmadı**. `OAUTH_KAYIT_DONUS`, callback SONRASI tarayıcının
gönderileceği **dönüş** adresidir (sağlayıcıya bildirilen `redirect_uri` DEĞİL) —
panel güncellemesi GEREKMEZ.

## 1. `.env.prod`'a eklenecek satır (ZORUNLU)

```env
# niyet=kayit callback dönüşü (yönetici kayıt tamamlama). BOŞ = SSO KAYIT KAPALI
# (basla 503; giriş akışı etkilenmez).
OAUTH_KAYIT_DONUS=https://app.yonetiyor.com/kayit
```
Başka yeni env YOK. Mevcut `OAUTH_WEB_DONUS`/`OAUTH_MOBIL_DONUS` değişmedi.

## 2. Şema göçü (ZORUNLU)

**`0069_yonetici_by_email`** — SSO kayıtta e-posta ile mevcut yönetici hesabı
eşleşmesi (kriter 4). `migrate` her açılışta idempotent uygular:
```bash
cd infra
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build \
  migrate api worker admin-web tanitim-web
# /health -> schema.database == schema.beklenen == 0069_yonetici_by_email
```

## 3. Hangi servisler BUILD gerektiriyor

| Servis | Build? | Neden |
|--------|--------|-------|
| `migrate`, `api`, `worker` | **Evet** | Backend kodu + göç 0069 imaja gömülü |
| `admin-web` | **Evet** | `/kayit` auto-start, `/giris/oauth` durum dalları, SosyalGiris niyet+onay, i18n |
| `tanitim-web` | **Evet** | SSO butonları artık `/kayit?niyet=kayit`; `NEXT_PUBLIC_*` derlemeye gömülü |
| `caddy`, `db`, `redis`, `minio` | Hayır | Değişmedi |

Kanonik komut zaten hepsini kurar (§2). `OAUTH_KAYIT_DONUS` çalışma zamanıdır →
api yeniden yaratılması yeter; **frontend** `NEXT_PUBLIC_*` build-time → `--build`.

## 4. Backend — YAPILDI + DOĞRULANDI

- `/baslat`: `niyet ∈ {giris,kayit}` (varsayılan giris → mevcut davranış); kayıt
  için 2 zorunlu onay backend'de de doğrulanır (422); onaylar IP+zaman ile state'e.
- Callback: niyet **state'ten**; dönüş niyete göre (`OAUTH_KAYIT_DONUS`);
  `_kayit_coz` (kimlik bağlı→giriş, e-posta tek yönetici eşleşmesi→mevcut_hesap,
  aksi→kayıt). **Güvenlik:** e-posta eşleşmesi yalnız `email_verified`.
- `/sonuc`: `durum ∈ {giris, baglama_gerekli, kayit, mevcut_hesap}`.
- `tesis-olustur`: onaylar append-only audit_log'a + `pazarlama_eposta`.
- Göç 0069; Apple private relay geçerli + ad yalnız ilk yetkilendirmede.
- Testler: test_oauth (email_verified dahil), test_compose_oauth, test_tesis_olustur,
  test_tesis_kodu_ve_coklu_yonetici, test_rol_secimli_kayit — **yeşil**.

## 5. Frontend — YAPILDI + BUILD YEŞİL

- **Tanıtım `SsoDugmeleri`**: butonlar artık `/login` yerine
  `app.yonetiyor.com/kayit?saglayici=X&niyet=kayit&os=&ok=&ot=` (onaylar taşınır;
  iki zorunlu onay işaretlenmeden zaten kilitli).
- **admin-web `SosyalGiris`**: `niyet="kayit"` + `onaylar` desteği; `baslat`
  gövdesine niyet+onay; BFF `baslat` route'u **gerçek istemci IP'sini** iletir
  (`x-istemci-ip`) — onay IP'si için.
- **admin-web `/kayit`**: `?niyet=kayit&saglayici` ile gelince OAuth'u niyet=kayit
  + onaylarla **otomatik başlatır** (kullanıcı giriş ekranına DÜŞMEZ); dönüşte
  `kayitSosyalSonuc` ile 3. adımdan (ad ön-dolu, **parola sorulmaz**) devam →
  site adı = `tesis-olustur`.
- **admin-web `/giris/oauth`**: `durum=kayit` → `/kayit` tamamlama;
  `durum=mevcut_hesap` → oturum + "zaten hesabınız var" mesajı (kriter 4). Mesaj
  yalnız `mevcut_hesap`'ta (yani `email_verified`) görünür → **hesap varlığı
  sızmaz** (var olmayan/doğrulanmamış hesap aynı yola, `durum=kayit`, düşer).
- i18n: `sosyalMevcutHesap` 7 dile eklendi (parity testi yeşil).
- Build: admin-web ✓ · tanitim-web ✓.

### KALAN — küçük (kriter 6 afordansı, güvenlik zaten backend'de)
`/giris/oauth` "tesis" (baglama_gerekli, giriş niyeti) ekranına "Hesabınız yok mu?
→ yonetiyor.com/yonetici/kayit" bağlantısı eklenecek. Backend giriş niyetinde
**sessizce hesap açmaz** (kural mevcut); bu yalnız yönlendirme bağlantısıdır. İki
i18n anahtarı (sosyalHesabinYok/sosyalKayitOl × 7) + URL gerektirir.

## 6. Kabul kriterleri
1,2 ✓ (tanıtım→SSO→kayıt tamamlama→site adı; giriş ekranı görünmez) · 3 ✓ (onay
kilidi + backend doğrulaması) · 4 ✓ (mevcut hesap bağla+giriş+mesaj) · 5 ✓ (giriş
değişmedi) · 6 backend ✓ (sessiz açma yok), link afordansı §5-kalan · 7 ✓ (state,
sunucu doğrulamalı, açık yönlendirme yok).
