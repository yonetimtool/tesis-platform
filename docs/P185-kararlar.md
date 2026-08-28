# P185 — Kayıt ve giriş akışının yeniden konumlandırılması — kararlar

Kesintisiz mod. Kararlar gerekçeleriyle. Prod dağıtımı + cihaz testi kullanıcıda.

**Amaç:** Kayıt/giriş akışı parça parça yapıldığı için tutarsız kaldı. Bu tur
akışın tamamını (web + backend + mobil) tek tutarlı modele oturtur. Mevcut
davranış korunmaz; aşağıdaki model geçerlidir. Mevcut kullanıcıların girişi
BOZULMAZ (kabul 13) — bu tek sınır.

---

## K0 — Keşif özeti: backend zaten büyük ölçüde DOĞRU

Dört alanda tam keşif yapıldı. Bulgu: **yönetici kaydının backend'i zaten doğru
modelde** — sorun ağırlıkla WEB FRONTEND'de SMS/telefon varsayımlarının kalması:

- `/auth/kayit/yonetici-basvuru → -dogrula → -tesis` (3 adım, **e-posta koduyla**
  doğrulama): yöneticiden **Tesis ID İSTEMEZ**, tesis adını alır, **Tesis ID'yi
  trigger üretir** (`trg_tenant_kayit_kodu`, göç 0037), telefon OTP YOK. ✓ §2 doğru.
- `/auth/kayit/tesis-olustur` (SSO, `baglama_jetonu`): `email_verified=true` ise
  `eposta_dogrulandi=True` yazar, **OTP/telefon SORMAZ**. ✓ §3 doğru.
- `/auth/oauth/rol-tamamla` (P184): SSO rol tamamlama, email_verified→OTP yok. ✓

Web ise hâlâ eski `tesis-olustur` (parola, e-posta doğrulamasız) + SMS-bağlama
(`baglan/*`, `rol-basla`) uçlarını kullanıyor. Rework ağırlıkla web + küçük backend.

## K1 — Üç yüzey, üç iş (KESİN)

- **panel.yonetiyor.com** → PLATFORM ADMİNİ. Bu kayıt/giriş sistemiyle İLGİSİZ,
  ayrı tutulur. SSO butonları buradan kaldırılır (§5). Yüzey `konakYuzeyi` ile
  `platform` olarak çözülüyor (`admin-web/lib/yuzey.ts`).
- **yonetiyor.com + app.yonetiyor.com** → YÖNETİCİ. Web'den kaydolur + giriş yapar.
- **Mobil** → YÖNETİCİ (kayıt+giriş) VE sakin/güvenlik/tesis görevlisi (tamamlama+giriş).

Sakin/güvenlik/görevli web'de YOK: `admin-web/lib/yuzey.ts` `MOBIL_ROLLERI` +
`rolYuzeyeGirebilir` bu rolleri app.* yüzeyinde 403 `mobil_uygulama` ile reddediyor
(kabul 8 zaten enforce; web signup'ta bu roller sunulmuyor).

## K2 — Yönetici kaydı: "Yeni tesis oluştur" / "Mevcut tesise katıl" AÇIK seçim

Bugün web'de varsayılan "yeni tesis" + "Zaten bir sitem var" bağı var. Bunun yerine
İKİ AÇIK DÜĞME (hem web hem mobil, aynı):

**YENİ TESİS OLUŞTUR** (Tesis ID İSTENMEZ):
- Kullanıcı **Tesis ADINI** girer.
- **Parola yolu:** 3 adımlı e-posta-kodlu akış (`yonetici-basvuru` → e-posta kodu →
  `yonetici-dogrula` → `yonetici-tesis`). Tesis ID trigger'la üretilir, ekranda
  gösterilir + e-posta ile gider. (Web bugün `tesis-olustur`-parola kullanıyordu —
  o e-posta DOĞRULAMAZ; 3 adımlı akışa geçilir → e-posta tek doğrulama kanalı, §3.)
- **SSO yolu:** `tesis-olustur` + `baglama_jetonu` (email_verified→OTP yok, telefon
  sorulmaz). Zaten doğru.

**MEVCUT TESİSE KATIL** (Tesis ID GİRİLİR):
- **Karar (model): ALLOWLIST + onay kuyruğu BİRLİKTE** — P184 3-şart modelinin
  aynısı, yalnız `rol="yonetici"`. Gerekçe: Bir yönetici, sakin/güvenlik/görevli ile
  AYNI şekilde "mevcut bir yönetici tarafından eklenmiş" olabilir; eklenmişse
  (allowlist) e-posta OTP / SSO ile tamamlar, eklenmemişse **onay kuyruğuna**
  (`kayit_onay_kuyrugu`) düşer ve mevcut yönetici onaylar. Böylece şartname'nin
  "onayına düşer VEYA allowlist" seçeneklerinin İKİSİ de tek mekanizmayla karşılanır
  ve P184 altyapısı (rol-eposta/rol-tamamla) yeniden kullanılır — paralel bir onay
  sistemi yazılmaz.
- **Backend değişikliği:** `kayit.py:_ROLLER` ve `rol-eposta-*` + `rol-tamamla*`
  `"yonetici"` rolünü de kabul eder. `_liste_kontrolu` zaten role bakıyor. AYRICA
  `roller.py:YONETILEBILIR_ROLLER["yonetici"]`'ye `"yonetici"` eklenir ki bir
  yönetici, add-user formundan bir **eş-yöneticiyi** ekleyebilsin (o da e-posta/SSO
  ile tamamlar). Gerekçe: kendi tesisinin yöneticilerini o tesisin yöneticisi
  belirler; platform admini (tenant açan) ayrı kalır.
- **NOT (dürüstlük):** `kayit_onay_kuyrugu`nun İŞLEME (liste/onayla/reddet) ucu ve UI'si
  BUGÜN YOK (P184 yalnız yazıyordu). Bu yüzden BİRİNCİL katıl yolu **allowlist**
  (ön-ekleme); ön-eklenmemiş bir yönetici denemesi kuyruğa yazılır ama işleme UI'si
  ayrı bir iştir (bu turda kuyruk-inceleme paneli YAZILMADI, dağıtım notunda belirtildi).

## K3 — Doğrulama: TELEFON DEĞİL, E-POSTA (§3)

- SMS YOK. Telefon **yalnız iletişim**. "Cep telefonu (giriş anahtarı)" ifadesi HER
  YERDEN kalkar (web `kullaniciTelefon`/`kullaniciTelefonIpucu`/`tesisTelefonIpucu`,
  mobil `sakinGirisAnahtari`, `types.ts` yorumu).
- E-posta ZORUNLU: `UserCreate.email` `EmailStr | None` → **zorunlu**; formda
  "E-posta (opsiyonel)" → "E-posta". Manager akışlarında e-posta zaten zorunlu.
- SSO'da `email_verified=true` → **OTP yok, telefon sorulmaz** (web'deki
  Google-sonrası Tesis ID+telefon+SMS ekranı KALDIRILIR — bkz. K6).
- `email_verified=false` → e-posta OTP (gevşetilmez). Apple privaterelay geçerli.

## K4 — Kullanıcı ekleme formu (§4)

Alanlar: Ad Soyad (zorunlu), **E-posta (ZORUNLU)**, Telefon (isteğe bağlı, iletişim),
Rol (sakin/güvenlik/tesis görevlisi), **Blok+Daire (rol SAKİN veya YÖNETİCİ ise
görünür+zorunlu)**, Aranabilir (mevcut).

**Daire ↔ rol modeli:** Daire ataması ROLE BAĞLI DEĞİL ayrı bilgi. Bir yönetici aynı
zamanda sakin olabilir → yöneticiye de daire atanabilir. Backend
`POST /units/{id}/residents` bugün `target.role != "resident"` ise 422 veriyor →
**`resident` VEYA `yonetici`** kabul edecek şekilde gevşetilir. Form yalnız hangi
rollerde alanı GÖSTERECEĞİNE karar verir (sakin + yönetici).

Davet maili Tesis ID içerir (mevcut `davet.py`); app.yonetiyor.com bağlantısı
konmaz (bu roller web'e girmez — davet maili yalnız mağaza + tesis kodu). Kişi
kaydını mobilden tamamlar; daireyi KİŞİ girmez (yönetici atamıştır).

## K5 — Panel SSO kaldırılır (§5)

`SosyalGiris` bileşeni giriş+kayıtta çiziliyor, yüzey kapısı YOK. `yuzey="platform"`
(panel.*) iken SSO butonları ÇİZİLMEZ. Yalnız tesis kodu + e-posta + parola kalır.

## K6 — "Bağlama isteği geçersiz" KÖK NEDEN (§6, kabul 11)

**Kök neden:** `backend/app/routers/oauth.py:_baglama_coz` (satır ~445) şu durumlarda
`_BAGLAMA_GECERSIZ` (400 `oauth_baglama_gecersiz`) atar: (a) `baglama_jetonu` JWT'si
**süresi dolmuş** (`oauth_baglama_ttl_seconds=900` sn = 15 dk), (b) `type != "oauth_link"`,
(c) imza/biçim bozuk. **AMA web'de görülen asıl tetikleyici:** `baglan_basla` (satır
~581) Tesis Kodu'nu `tenant_id_by_kayit_kodu` ile çözer; **kod GEÇERSİZ/BOŞSA
`tenant_id=None` → `_BAGLAMA_GECERSIZ`**. Web login OAuth akışı (niyet=giris, kimlik
bağlı değil) `durum="baglama_gerekli"` dönüp kullanıcıdan **Tesis Kodu + telefon +
SMS** istiyor. Google ile GİREN ama henüz bağlı olmayan bir yönetici (ör. yeni
yönetici) elinde Tesis Kodu OLMADAN bu ekrana düşüyor; geçersiz/boş kod → "Bağlama
isteği geçersiz". Yani hata, **kaldırılacak olan SMS-bağlama ekranının** kendisinden
kaynaklanıyor.

**Aynı kalıp başka yerde:** `admin-web/app/kayit/page.tsx` "Zaten bir sitem var"
(katıl) yolu da `baglan/basla`+SMS kullanıyor (kayıt yüzeyinde aynı ekran). İkisi de
K2/K3 gereği e-posta/SSO modeline geçirilir; SMS-bağlama web UI'sinden kaldırılır.
Backend `baglan/*` uçları DURUR (P184 kararı: SMS ileride açılabilir), web ÇAĞIRMAZ.

## K7 — Dil (§7, kabul 12)

Mobil tamamlama ekranının TÜM Türkçe çevirileri app_tr.arb'de MEVCUT (7 dil parity
`sozluk_denetimi_test` yeşil). Cihazda İngilizce açılması **çeviri eksikliği DEĞİL**:
`localeCozumle` cihaz dilini izler — cihaz İngilizceyse app İngilizce açılır (doğru
davranış). Türkçe cihazda Türkçe açılır. Yeni eklenen P185 anahtarları da 7 dile
eklenir; parity korunur. (Aksiyon: parity testini koştur + doğrula.)

## K8 — İleriye dönük: ödeme/abonelik ŞEMASI (§8, KOD YOK)

`tenant` tablosu forward-compatible: yeni kolonlar eklemek mevcut kodu tıkamaz
(migration ile eklenir). Önerilen (ŞİMDİ YAZILMAZ) alanlar:
`plan_tipi text default 'ucretsiz'` (ucretsiz|deneme|pro), `deneme_baslangic
timestamptz`, `deneme_bitis timestamptz`, `abonelik_durumu text default 'aktif'`
(aktif|askida|iptal), `abonelik_bitis timestamptz`. Tesis oluşturma tek transaction
(`create_tenant_with_yoneticis`) — deneme başlangıcı orada set edilebilir. Gate
(deneme bitti → salt-okuma) ileride bir middleware/deps ile eklenir; şu an hiçbir
şey bu genişlemeyi engellemiyor. Kod yazılmadı, yalnız not.

## K9 — Giriş girişi (login input) — kabul 13 sınırı

Mevcut: app.* (tesis) = **telefon + parola** (`/auth/login-phone`); panel.* =
tenant_slug + e-posta + parola. Yeni modelde e-posta anahtar; ama telefonla giren
MEVCUT yöneticiler bozulmamalı (kabul 13). **Karar:** `login-phone` backend'i
DURUR (bozulmaz); app.* girişine **e-posta + parola** (Tesis ID ile) seçeneği +
**SSO** eklenir; telefon alanının "giriş anahtarı" etiketi düşer. Böylece e-posta ile
kaydolan yeni yöneticiler e-posta/SSO ile, telefonla açılmış eski hesaplar telefonla
girebilir. Not: telefon-girişini tamamen kaldırmak ayrı bir göç işi (bu turda değil).

---

## Kabul kriterleri → nerede

1. Yeni tesis/katıl ayrımı (web+mobil) → K2. 2. Yeni tesiste Tesis ID istenmiyor,
üretiliyor → K2/K0. 3. Katılan Tesis ID giriyor → K2. 4. SSO'da OTP/telefon yok →
K3/K6. 5. Telefon "giriş anahtarı" yok → K3. 6. E-posta zorunlu → K3/K4. 7. Blok/daire
sakin+yönetici; yöneticiye daire → K4. 8. Roller web'de yok → K1. 9. Yönetici web+mobil
→ K1/K2. 10. Panel SSO yok → K5. 11. Bağlama hatası kök neden → K6. 12. Mobil TR +
parity → K7. 13. Mevcut giriş bozulmadı → K9 (login-phone durur).

## Teslim durumu

Uygulama parça parça commit'lenir (single-trunk main). Cihazda/prod'da doğrulanacaklar
(SSO gerçek sağlayıcı, e-posta SMTP, gerçek cihaz dili) `docs/P185-dagitim.md`'de
açıkça işaretlenir.
