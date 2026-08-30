# P190 — Kararlar ve gerekçeleri

**Kapsam:** panel yetki hatası, mobil yönetici SSO doğrulaması, duyuru/kural
web yönetimi + görsel, bildirim rozeti, tema kalıcılığı, RTSP kamera
görüntüleme. Kesintisiz mod; her bölüm ayrı commit. Dağıtım notları
`docs/P190-dagitim.md`.

**Adlandırma notu:** Aynı numarayla daha önce iki hotfix dokümanı yazıldı
(`P190-davet-spam-sinyalleri.md` — davet e-postası spam sinyalleri). Bu
doküman kullanıcının verdiği 6 maddelik P190 listesinin kararlarını içerir.

---

## §1 — Yeni tesis sonrası panel boş / "yetkiniz yok" (HATA)

### Kök neden (ölçüldü, tahmin edilmedi)
1. **Rol ataması DOĞRUYDU**: `tesis-olustur` yeni yöneticiyi `role=yonetici`
   ile açar (`create_tenant_with_yoneticis`). Sorun yetki değil YÜZEYDİ.
2. `middleware.ts` rol kapısı, panel.*'daki bir `yonetici` için hedefi
   `kokRotaRol("platform", rol)` ile seçiyordu — o fonksiyon platformda
   **rolden bağımsız `/tenants`** döndürür. Kullanıcı ZATEN `/tenants`'ta
   olduğundan `pathname !== kok` koşulu sağlanmıyor, **yönlendirme hiç
   olmuyordu**: sayfa çiziliyor, her BFF çağrısı 403 dönüyor → ekranda iki
   ayrı "Bu işlem için yetkiniz yok" kutusu. Middleware hiçbir durumda
   **konak-ötesi** (panel→app) yönlendirme yapmıyordu.
3. Yönetici panel konağına nasıl girdi? `/kayit` sayfası `config.matcher`
   dışındaydı ve **panel.*'da da sunuluyordu**; orada kaydolan yöneticinin
   çerezleri panel konağına yazılıyor ve içeri düşüyordu.

### Düzeltme
- **Konak-ötesi yönlendirme:** oturumlu bir tesis rolü (yonetici/denetci)
  panel konağındaysa `app.<alan>` köküne 307. Yerel geliştirmede (localhost
  "platform" sayılır ama `app.` eşdeğeri yok) eski davranış korunur —
  `appKonagi()` yalnız ilk DNS etiketi tam `panel` ise dönüşüm yapar.
- **/kayit yüzeyli:** matcher'a alındı; panel konağında `app.*`'a taşınır
  (oturum kapısına girmeden erken çıkar), app.*'ta public sunulur.
- Yeni tesis kuranın ilk girişi: app.*'ta `/` → `kokRotaRol("tesis",
  "yonetici")` = `/dashboard` (mevcut davranış; kabul 1 sağlanır).

Testler: 6 yeni middleware testi (yonetici/denetci panel→app 307; admin
dokunulmaz; localhost korunur; /kayit panel→app, app'te public).

---

## §2 — Mobil yönetici SSO girişi (DOĞRULAMA — kod değişmedi)

**İz (dosya:satır ile):**
1. Giriş ekranı SSO düğmeleri `GET /auth/oauth/saglayicilar`'dan çizilir
   (`sosyal_giris.dart:34-46`); sağlayıcı listesi boşsa hiç çizilmez, doluysa
   üçü de görünür ve tıklanabilir (mobil test "ACIK saglayicilar dugme olur").
2. Web'de SSO ile kaydolan yöneticinin kimliği **bağlanır**:
   `kayit.py:244` (`tesis-olustur` → `OauthKimlik` insert) ve
   `oauth.py:517` (`rol-tamamla` yolu).
3. Mobil `oauthBaslat` niyet göndermez → varsayılan `giris`
   (`oauth.py:197`); bağlı kimlik → `tur=="giris"` → `sonuc` ucu ROL
   BAKMADAN jeton üretir (`oauth.py:502-549`) → mobil `girisYapildi` →
   oturum (`auth_controller.dart:391`).
4. Kayıt/giriş ayrımı: kayıt ekranı `KayitRolu` yalnız 3 rol
   (sakin/güvenlik/görevli — yönetici YOK, test `UC rol listeleniyor`);
   girişte bağlı-olmayan SSO kimliği rol-tamamlama formuna düşer (3 rol +
   Vazgeç) — yönetici oradan KAYDOLAMAZ, iki akış karışmaz.

**Kanıt koşumları:** mobil `sosyal_giris + kayit_rol_secimi +
login_screen_phone` 19/19; backend `test_oauth + test_tesis_olustur` 50/50.
Kırık bir şey bulunmadı; kod değişikliği yapılmadı. (Gerçek
Google/Microsoft/Apple hesaplarıyla cihaz doğrulaması kullanıcıda —
dagitim'de listeli.)

---

## §3 — Duyuru ve kural yönetimi: web'de oluşturma + görsel

### Keşif: backend + mobil ZATEN tamdı
- Duyuru: `GET/POST/PATCH/DELETE /announcements` + `foto_key` (tek görsel,
  MinIO presign, IDOR ad-alanı doğrulaması) mevcut; mobil oluşturma+görsel
  akışı mevcut; web'de düzenleme/silme + görsel VARDI, yalnız **oluşturma**
  eski bir ürün kararıyla kapalıydı (sayfadaki "admin'e 403" yorumu BAYATTI —
  backend `_CREATOR = yonetici+admin` zaten izinliydi).
- Kural: `site-rules` CRUD + `foto_key` uçtan uca mevcut; **mobil ekran
  görseli gösteriyor ve yüklüyordu**; web formunda görsel alanı YOKTU.
- Görünürlük: iki kaynağın GET'leri sakin/güvenlik/görevli dahil
  (`_READER`) — sunucu tarafında zaten doğru.

### Yapılan (yalnız web UI — yeni tablo YOK, aynı veriler)
- Duyuru: BFF'e POST eklendi (P173 sınıfı eksikti), sayfaya "Yeni duyuru"
  + aynı modal ile POST/PATCH; panel notu güncellendi (7 dil).
- Kural: forma görsel bloğu (presign → doğrudan MinIO PUT; yükleme sırasında
  ilerleme iskeleti, hata görünür, "görseli kaldır") + listede görüntüleme.

### Sınırlar (gerekçeli)
- **Görsel sayısı: kayıt başına 1.** Mevcut şema tek `foto_key`; duyuru/kural
  kısa bilgilendirme içerikleridir, çoklu görsel bir galeriye dönüşür ve iki
  yüzeyde galeri UI'ı ayrı bir iştir. Tek görsel iki yüzeyde de zaten uçtan
  uca çalışıyor — kapsamı bilinçli böyle tuttum.
- **Tür/boyut: sunucuda zorlanıyor** (`PresignRequest`): jpeg/png/webp/heic,
  ~8 MB üst sınır. İstemciler `image/*` seçtirir; asıl kapı sunucu.

---

## §4 — Bildirim rozeti anında güncellenmiyor (HATA)

Kök neden: üst bardaki rozet **kendi SWR anahtarını** kullanıyor
(`bildirim-merkezi`, 60 sn poll); bildirimler sayfası mutasyonlardan sonra
yalnız **kendi liste anahtarını** tazeliyordu → rozet poll'a/yenilemeye kadar
bayat. Dört işlemin DÖRDÜNDE de aynı sorun vardı (tekil okundu, seçili
okundu, seçili sil, tümünü okundu — hepsi `markRead`/`topluCalistir`).

Düzeltme: sayaç anahtarı dışa açıldı (`BILDIRIM_SAYAC_UC`) ve iki fonksiyon
da global `mutate(BILDIRIM_SAYAC_UC)` çağırıyor → rozet anında düşer.

---

## §5 — Tema tercihi kalıcı değil (HATA) + hesapta saklama

### Kök neden
- Tercih yalnız `localStorage`'daydı → cihaza/konağa bağlı (app.* ve panel.*
  ayrı origin: birinde seçilen öbüründe yok; başka tarayıcıda hiç yok).
- Dayanıklılık deliği: `ThemeToggle` mount'ta temayı YENİDEN UYGULAMIYORDU —
  satır-içi script herhangi bir sebeple koşamazsa (CSP vb.) tema hiç
  uygulanmıyordu.

### Tasarım
- **Hesapta saklama:** göç 0076 `app_user.ui_tema` (system|light|dark,
  CHECK). `GET /me` döner; `PATCH /me/tema` günceller (kapısız mutasyon
  sınıfı — `/me/password` ile aynı gerekçe: kişinin KENDİ kaydı; denetime
  yazılmaz çünkü kozmetik). Başka tarayıcıda aynı tema: açılışta `/me`
  senkronu (hesap kazanır; kullanıcı oturum içinde değiştirirse ref-guard
  hesap değerinin geri ezmesini engeller).
- **Titreme SIFIR:** `tema` çerezi **alan-genelinde** (`.yönetiyor.com`)
  yazılır → app.* ve panel.* paylaşır; `layout.tsx` SSR'da çerez `dark` ise
  `.dark` sınıfını İLK HTML'de basar (JS engelli olsa bile doğru). `system`
  modunda karar satır-içi script'te (OS tercihi yalnız istemcide bilinir) —
  bugünkü davranış.
- **Sistem tercihi:** mevcut `system` modu korunur; OS değişimi canlı izlenir.
- Sıra: çerez → localStorage → OS (script); PATCH fire-and-forget (sunucu
  hatası kullanıcının seçimini geri almaz, yalnız senkron gecikir).

Mobil zaten yerelde kalıcı (`ui.theme_mode`); mobilin `ui_tema` hesabıyla
senkronu bu tur kapsam dışı (istenirse ayrı iş).

---

## §6 — RTSP kamera görüntüleme

### Seçenek değerlendirmesi ve KARAR: (c) karma
- (a) *Yalnız sürekli dönüştürme (RTSP→HLS)*: gerçek canlı ama N kamera ×
  7/24 ffmpeg = prod (192.168.1.105, tek sunucu; api+worker+db+minio aynı
  makinede) için savurgan — kimse izlemezken de CPU yakar.
- (b) *Yalnız periyodik kare*: ucuz ve ızgara için doğru; ama "tıklayınca
  canlı izle" isteğini karşılamaz.
- **(c) KARMA (seçilen):** ızgara **sunucu çekimli tek kare**; tıklayınca
  **isteğe bağlı HLS** (MediaMTX, `sourceOnDemand`). İzleyici yokken hiçbir
  RTSP bağlantısı açık tutulmaz; CPU yalnız aktif izlemede harcanır.

### Bileşenler
1. **Kare:** `GET /cameras/{id}/kare` — ffmpeg (imaja eklendi) RTSP'den tek
   JPEG çeker. Redis 10 sn önbellek (çok izleyici tek çekim), başarısız
   deneme 5 sn negatif-önbellek (ölü kameraya çekiç yok), süreç başına 3
   eş-zamanlı ffmpeg (semafor), 8 sn zaman aşımı. Ulaşamazsa **502
   `kamera_baglanti_yok`** — istemci karoda "Bağlantı yok" çizer, boş kutu
   YOK.
2. **Canlı:** MediaMTX compose servisi (dev+prod; **public port YOK**).
   Backend `POST {api}/v3/config/paths/add/cam{id}` ile yolu kaydeder
   (`sourceOnDemand: true`) ve `GET /cameras/{id}/canli/{dosya}` HLS
   playlist/segmentlerini **kimlik-kapılı vekil** olarak geçirir. İstemci
   MediaMTX'i de RTSP adresini de görmez.
3. **Eş-zamanlılık:** aynı anda en çok `KAMERA_CANLI_SINIR` (3) FARKLI
   kamera dönüştürülür — Redis aktif kümesi (30 sn TTL, playlist istekleri
   tazeler); aşımda **429 `kamera_canli_sinir`**. Kimse izlemezken akış
   DURUR (`sourceOnDemand` + okuyucu kalmayınca kaynak kapanır).
4. **Kimlik bilgisi sızıntısı (kabul 11):** RTSP `stream_url` kullanıcı
   adı/parola taşıyabilir ve istemci onu zaten oynatamaz → **yönetim dışı
   rollere maskelenir** (`rtsp://***`); yönetici düzenleme formu için görür.
   Kare/canlı bağlantıyı SUNUCU kurar.
5. **SSRF sınırı:** sunucu-tarafı çekim YALNIZ `rtsp://` kaynaklara
   (`_rtsp_dogrula`); http(s) kaynaklar istemcide oynar (eski model).
   Eski "backend yayını hiç çekmez" kararı bilinçli olarak değişti; sınırı
   protokole daraltarak.
6. **Dev/test:** dev compose'ta MediaMTX servisi ayakta ama API env'i
   varsayılan BOŞ → test takımı "yapılandırılmamış" dalı ölçer (503 +
   `canli_yol=null`); denemek `infra/.env`e iki satır. Prod'da varsayılan
   DOLU.
7. **İstemciler:** web ızgara karosu `snapshot_url || /api/cameras/{id}/kare`
   (hata → "Bağlantı yok"); oynatıcı `canli_yol` doluysa `/api${canli_yol}`
   (BFF çerez kimliği; hls.js segmentleri göreli çözer). Mobil: kare Dio
   (Bearer) ile, canlı `video_player` `httpHeaders` ile.

Yapılmayanlar (dürüstçe): WebRTC (düşük gecikme) değerlendirilip
ertelendi — HLS 5-10 sn gecikme site kamerası için kabul edilebilir, WebRTC
NAT/TURN karmaşıklığı getirir. Kayıt (NVR) kapsam dışı.

---

## Kabul kriterleri eşlemesi

| # | Kriter | Durum |
|---|--------|-------|
| 1 | Yeni tesis → yönetici kendi ekranını görür | §1 fix ✓ (app.*'ta / → /dashboard) |
| 2 | Panel'e giren tesis yöneticisi doğru yere yönlendirilir | §1 ✓ (307 → app.*) |
| 3 | Yönetici mobilde 3 SSO ile girer | §2 doğrulandı (test kanıtları) — cihaz teyidi kullanıcıda |
| 4 | Duyuru+kural web'den CRUD | §3 ✓ |
| 5 | Mobil↔web çapraz görünürlük | Aynı tablolar ✓ |
| 6 | Görsel iki yüzeyde | §3 ✓ (kural formu web'e eklendi; gerisi mevcuttu) |
| 7 | Sakin/güvenlik/görevli mobilden görür | Sunucu `_READER` ✓ (değişmedi) |
| 8 | Rozet anında güncellenir | §4 ✓ (4 işlemde) |
| 9 | Tema kalıcı + sistem + titremesiz | §5 ✓ |
| 10 | Izgara + tıkla-izle | §6 ✓ (canlı: MediaMTX kurulu prod'da; dev'de opt-in) |
| 11 | RTSP kimlik bilgisi sızmaz | §6 ✓ (maske + sunucu-tarafı bağlantı) |
| 12 | Tam takım yeşil | Bölüm commit'lerinde koşuldu (dagitim'de sayılar) |
