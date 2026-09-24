# Bulgular — `yetki` (giriş yolları, çok tesis, rol sınırları, hesap işlemleri, oturum)

Tesisler: `yetki` (547fd15e…) ve `yetki2` (0e9b7ffe…), `kur.py` ile açıldı; tohum verisi
`$S/yetki/tohum*.py`. Tüm betikler ve ham çıktılar `$S/yetki/` altında
(`tarama.json` = GET taraması, `yazma.json` = mutasyon taraması, `web.json`).

## Sistematik tarama — özet

* **GET taraması** (`tara.py`): openapi'deki 224 GET ucundan 214'ü (dukkan + oauth-callback hariç)
  × 10 rol (yonetici, guvenlik_amiri, security, security2, tesis_gorevlisi, denetci, malik, kiraci,
  malik_oturan, malik2) × {kendi tesis id'si, yetki2 id'si} = **2370 istek**.
  Durumlar: 200:660, 403:1389, 404:240, 422:73, 502:8 (kamera — sahte URL, bilinen).
  * Rol matrisinde (`backend/tests/yetki/rol-matrisi.txt`) **RED olup 2xx dönen uç: 0**.
  * **yetki2 id'siyle 2xx dönüp yetki2 verisi içeren uç: 0** (tesisler arası sızıntı yok).
  * İçerik taraması (rol başına yasak dizeler: sakin adları/e-postaları, başka daire kalemleri,
    para alanları) → 4 isabet: 3'ü amirin şikâyet/ziyaretçi okuması (biri gerçek bulgu: YETKI-04,
    ikisi P231 tasarımı — amir ziyaretçi kayıtlarını okur), 1'i kiracının `/me/dues`'u (YETKI-06).
* **Mutasyon taraması** (`yaz.py`): matriste RED olan her (rol, POST/PATCH/PUT/DELETE) çifti `{}`
  gövdeyle → **2390 isteğin 2390'ı 403** (denetçi 287/287 dahil). Yönetici + yetki2 id'leri
  (145 uç) → 86×404, 58×422 (gövde doğrulaması); 422'lerin kritik 27'si geçerli gövdeyle
  tekrarlandı (`capraz2.py`) → hepsi 404/422, DB'de değişiklik yok.

## KONTROL LİSTESİ

| Madde | Sonuç | Kanıt |
|---|---|---|
| 2.1 E-posta + parola | GEÇTİ | 200; büyük harfli e-posta da 200 |
| 2.1 Telefon + parola, tek alan (0532…, 532…, +90 532 …, 90532…, 0090…, tireli) | GEÇTİ | 8 biçimin 8'i 200; `login-phone` da 200 |
| 2.1 E-posta + kod (OTP) | GEÇTİ | kod log'dan, 200 + jeton; kod ikinci kez 422; 5 yanlış denemeden sonra doğru kod da 422 (MAX_DENEME=5) |
| 2.1 Telefon + kod (SMS kapalı) | KISMEN | 200 `onay_bekliyor`, SMS gitmiyor (log: `sms_kanali_kapali`), **hiç hız sınırı yok** → YETKI-03 |
| 2.1 Google/Microsoft/Apple | ÖLÇÜLEMEDİ | dev'de yapılandırılmamış: `/auth/oauth/saglayicilar` → `[]`, `baslat/*` → 503 `service_unavailable` |
| 2.1 Yanlış parolada jenerik hata (gövde/kod) | GEÇTİ | var/yok hesap: ikisi de 401, gövde birebir aynı |
| 2.1 Yanlış parolada zamanlama | KALDI | var olan hesap medyan **454 ms**, olmayan **37 ms** → YETKI-02 |
| 2.1 Hız sınırı (5+ yanlış deneme) | KALDI | `/auth/login` 20 yanlış denemede hep 401, hiç 429 yok; `/auth/login-phone` aynı → YETKI-01 (`/auth/tesislerim` 11. denemede 429 — çalışıyor) |
| 2.1 Başarısız gönderim hız sınırını yemiyor mu | KISMEN | e-posta kodunda sayaç gönderimden ÖNCE artıyor, başarısız gönderim de kotayı yiyor; telefon kodunda sınır hiç yok → YETKI-03 |
| 2.1 Mobil aynı uçları mı çağırıyor | KISMEN | `/auth/login`, `/auth/login-phone`, `/auth/tesislerim`, `/auth/giris/kod-*` aynı; mobilde **e-posta OTP girişi ve "şifremi unuttum" yok** (web'de var) → YETKI-13 |
| 2.1 Web giriş formu | ÖLÇÜLEMEDİ | Next dev sunucusu statik dosyaları 404 veriyor (`/_next/static/chunks/main-app.js` 404) — sayfa hidrate olmuyor (`admin-web/.next/static/chunks` içinde hash'li PROD derleme dosyaları var — biri dev sunucusunun `.next`ine `next build` yazmış gibi; yeniden başlatma yasak olduğu için dokunulmadı). BFF `/api/auth/login` curl ile 200 |
| 2.2 Aynı e-posta iki tesiste yönetici → seçim | GEÇTİ | slug'sız `/auth/login` → 409 `tesis_secimi_gerekli`; `/auth/tesislerim` iki tesis |
| 2.2 Tek tesisli kullanıcı seçim görmüyor | GEÇTİ | denetçi slug'sız 200 |
| 2.2 Uygulama içinden tesis değiştirme | KISMEN | `/me/tesis-degistir` çalışıyor ve yeni jeton doğru tenant'ta — ama davetle açılan hesapta **403** (e-posta doğrulanmış sayılmıyor) → YETKI-08 |
| 2.2 Seçili tesis dışının verisi (P228: bildirimler, arama, /me, üyelikler, tesislerim) | GEÇTİ | yetki oturumunda `/notifications`, `/arama`, `/me`, `/me/profile`, `/me/etkinlik`, `/me/cihazlar` yetki2 izi taşımıyor; P228 senaryosu (başka tesiste doğrulanmamış aynı e-posta) → listede yok, geçiş 403 |
| 2.3 Amir: personel listesi yalnız güvenlik | GEÇTİ | `/users` → {security:2, guvenlik_amiri:1}; `?role=resident` boş; tekil kiracı/tesis görevlisi/yönetici/denetçi 404 |
| 2.3 Amir: vardiya planında yalnız güvenlik | KISMEN | liste/çizelge/`/shifts` süzülüyor, POST tesis görevlisine 403 — ama DELETE/PATCH/yayınla/haftadan-kopyala süzmüyor → **YETKI-05** |
| 2.3 Amir: finans ve ücret erişimi yok | GEÇTİ | `/mesai/ozet`, `/mesai/ayar` (GET+PATCH), `/finans/ozet`, `/dues/assessments` → 403 |
| 2.3 Amir: yönetici ucuna doğrudan istek 403 | GEÇTİ | `/admin/overview`, `/tenant/settings` GET/PATCH, `/residents`, `/raporlar/isler` → 403; yetki yükseltme (`security→yonetici`, kendi rolü, sakin düzenleme, yönetici silme) → 403 |
| 2.3 Amir: şikâyetler yalnız güvenlik kategorisi | KALDI | liste boş ama **kategorisiz şikâyet tekil GET ile 200** (açan sakinin adıyla) → YETKI-04 |
| 2.3 Amir: web menüsü | ÖLÇÜLEMEDİ | web dev sunucusu kırık (yukarıda) |
| 2.3 Sakin: yalnız kendi dairesi | GEÇTİ | başka dairenin `/units/{id}`, `/units/{id}/dues`, `/units/{id}/residents` → 403; ziyaretçi/kargo/rezervasyon tekil → 404; `/unit-complaints` şikâyet edeni hedef daireye göstermiyor |
| 2.3 Sakin: başka dairenin akıllı ev cihazı | GEÇTİ | liste yalnız kendi dairesi; A-2 cihazına komut → 403 "Bu cihaz sizin dairenize ait değil" |
| 2.3 Sakin: başka sakinin borcu | GEÇTİ | malik2 yalnız A-2; `?unit_id=A-1` süzgeci yok sayılıyor |
| 2.3 Sakin: yönetim ekranları | GEÇTİ | `/residents`, `/users`, `/finans/ozet` → 403 |
| 2.3 Kiracı vs malik (P218) | KALDI | kiracı `/me/dues`'ta malike hedeflenmiş kalemi görüyor; `/me/odeme-bilgileri` ile `/me/dues` farklı borç gösteriyor → YETKI-06, YETKI-07 |
| 2.3 Denetçi salt okuma | GEÇTİ | matriste RED 287 mutasyonun 287'si 403 |
| 2.3 Güvenlik görevlisi kendi bildirimleri (P242) | GEÇTİ | yönetici ve amirin atadığı görevler için `gorev_atandi` satırı doğru kişiye (Ali/Veli) düştü ve `/notifications`'ta görünüyor |
| 2.3 Güvenlik görevlisi kendi vardiyası/görevleri | GEÇTİ | `/tasks` yalnız kendine atananlar; çizelge okunuyor |
| 2.3 Tesisler arası (yetki2 id'leriyle) | GEÇTİ | GET: 0 sızıntı; yazma: 0 başarı (yukarıdaki tarama) |
| 2.4 Parola sıfırlama | KISMEN | kod log'da, yeni parola 200, eski 401, kod tekrar 422 — ama **eski oturumlar yaşıyor** (YETKI-09) ve **davetle açılan hiçbir hesap sıfırlama kodu alamıyor** (YETKI-08) |
| 2.4 E-posta değiştirme | ÖLÇÜLEMEDİ | dev'de SMTP yok → `/me/eposta/kod-iste` **502** döndürüp kodu geri alıyor (log'a yazılan kod geçersiz). Ölçülen kısım: kod yeni adrese gidiyor; eski adrese bildirim ölçülemedi |
| 2.4 Hesap silme (kod) | ÖLÇÜLEMEDİ | `/me/hesap-sil/eposta-kod-iste` dev'de 502 (aynı sebep); doğrulanmamış e-postada 422 `no_email` |
| 2.4 Hesap silme (parola) + anonimleştirme (P189) | KISMEN | geçmişi olan kiracı → `deleted:false`, "Silinmiş Kullanıcı", e-posta/telefon temizlendi, daire bağı kapandı, eski jeton 401 ✔; yalnız vardiya planı olan personel **tamamen silindi, vardiya geçmişi CASCADE ile gitti** → YETKI-11 |
| 2.4 Profil fotoğrafı yükle / kaldır | GEÇTİ | presign + PUT + `PATCH /me/avatar` 200, başka tenant anahtarı 422, kaldırma 200; security'ye 403 (tasarım, me.py:82) |
| 11.4 Access TTL / refresh | GEÇTİ | access 900 sn, refresh 30 gün; süresi dolmuş jeton 401; refresh rotasyonu çalışıyor |
| 11.4 Refresh tekrar kullanımı | GEÇTİ | eski refresh 401 ve **aile iptal** (yeni refresh de 401) |
| 11.4 Başka cihazdan giriş | GEÇTİ (tasarım) | iki oturum bağımsız, ilk oturum yaşıyor (çoklu cihaz serbest) |
| 11.4 Çıkışta jeton geçersiz mi | KALDI | backend'de logout ucu yok; web çıkışı sonrası eski refresh 200, eski access 200 → YETKI-10 |

## BULGULAR

### YETKI-01: `/auth/login` ve `/auth/login-phone` uçlarında hiç hız sınırı yok (kaba kuvvet + DoS)
- Sınıf: Ciddi
- Rol / yüzey: kimliksiz / API (web ve mobil giriş bu uçları kullanıyor)
- Adımlar: aynı hesaba (`e2e.yetki2.security2…`) 20 kez yanlış parolayla `POST /auth/login`; ardından doğru parola. Aynısı `login-phone` için 12 kez. Ayrıca 10 paralel yanlış giriş sırasında `GET /health` ölçüldü.
- Beklenen: N (ör. 10) denemeden sonra 429 — `/auth/tesislerim`'deki gibi (`DENEME_SINIRI=10`).
- Olan: 20/20 → 401, 21. doğru parola 200; `login-phone` 12/12 → 401. `/auth/tesislerim` 11. denemede 429 veriyor — yani aynı parola-deneme yüzeyinin **bir kapısı kilitli, yanındaki iki kapı açık** (saldırgan `/auth/login`'i kullanır). Ek olarak bcrypt doğrulaması async uçta olay döngüsünü bloke ediyor (`verify_password` senkron): 10 paralel yanlış girişte `/health` 30 ms → **2813 ms** (tek worker, `API_WORKERS` varsayılan 1). Sınırsız deneme + döngü blokajı = tek betikle tüm API'yi yavaşlatma.
- Tekrarlanabilir: evet (`$S/yetki/giris.py`, `blok.py`)
- Şüpheli kök neden: `backend/app/routers/auth.py:213-294` (`login`) ve `:296-377` (`login_phone`) `kod_istegi_say` çağırmıyor; yalnız `tesislerim` (`:180`) çağırıyor. Bcrypt: `auth.py:245` ve `:345` `verify_password` doğrudan async gövdede.
- Önerilen düzeltme: `login`/`login-phone`'a kimlik başına `kod_istegi_say(kapsam="giris_parola", sinir=DENEME_SINIRI, hata=DENEME_ASILDI)`; bcrypt'i `run_in_threadpool` ile çağır.

### YETKI-02: Parola girişinde zamanlama farkı hesap varlığını sızdırıyor
- Sınıf: Orta
- Rol / yüzey: kimliksiz / API
- Adımlar: 8'er kez var olan e-posta + yanlış parola, olmayan e-posta + yanlış parola.
- Beklenen: yanıt süresi hesap varlığından bağımsız (gövde/kod zaten aynı).
- Olan: var olan hesap medyan **454 ms** (400–638), olmayan **37 ms** (22–44). Telefonda da aynı: olmayan numara 25 ms, var olan 405 ms. Kodda "hesap varlığını sızdırmama" açıkça hedeflenmiş (auth.py:223-229) ama bcrypt yalnız satır varsa çalışıyor. YETKI-01 ile birlikte hesap listesi çıkarmak kolay.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `auth.py:248-251` — `uygun` listesi boşsa `verify_password` hiç çağrılmıyor; `login_phone` `:326-329` erken 401.
- Önerilen düzeltme: eşleşme yoksa sabit bir sahte hash'e karşı `verify_password` çalıştır (sabit iş).

### YETKI-03: Telefon kodu isteğinde hız sınırı yok; e-posta kodunda başarısız gönderim de kotayı yiyor
- Sınıf: Orta (SMS açıldığı gün Ciddi — para + taciz)
- Rol / yüzey: kimliksiz / API + mobil (`auth_api.dart:103`)
- Adımlar: `POST /auth/giris/kod-iste` aynı numaraya 7 kez; `POST /auth/giris/eposta-kod-iste` aynı adrese 5 kez (dev'de her e-posta gönderimi `smtp_yapilandirilmadi` ile başarısız).
- Beklenen: telefon: `KOD_ISTEK_SINIRI=3`/15 dk (modül başlığı "kod gönderen uçlar her çağrıda bir SMS üretir" diyerek bu sınırı tam bu uç için tanımlıyor). Başarısız gönderim kotayı yememeli (Dukkan'da F7/SMS-entegrasyonu.md §"Başarısız gönderim hız sınırını yemiyor" kuralı).
- Olan: telefon 7/7 → 200, her istekte yeni `kayit_dogrulama` satırı + SMS denemesi; SMS kapalıyken yanıt yine `onay_bekliyor` (kullanıcı hiç gelmeyecek kodu bekliyor, P196 notuna rağmen). E-posta: 3 istekten sonra 429 — üçü de başarısız gönderimdi.
- Tekrarlanabilir: evet (`$S/yetki/kodgiris.py`)
- Şüpheli kök neden: `backend/app/routers/auth.py:712-744` `giris_kodu_iste` `redis` bağımlılığı bile almıyor; `hiz_siniri.py:83-110` sayaç gönderimden önce artıyor, sonuçla ilgilenmiyor.
- Önerilen düzeltme: `giris_kodu_iste`'ye `kod_istegi_say(redis, phone, kapsam="giris")`; başarısız gönderimde sayacı `DECR` ile geri al (Dukkan kuralıyla eşitle); SMS kapalıyken istemciye ayırt edici bir durum dön (mobil "SMS ile kod" düğmesini gizlesin).

### YETKI-04: Güvenlik amiri kategorisiz (güvenlikle ilgisiz) şikâyeti tekil GET ile okuyabiliyor
- Sınıf: Ciddi (P231'in açık kuralının ihlali, sakin kişisel verisi)
- Rol / yüzey: guvenlik_amiri / API
- Adımlar: kiracı kategorisiz şikâyet açar ("su akıyor"); amir `GET /complaints` → boş liste; amir `GET /complaints/{id}`.
- Beklenen: 404 (P231 §3: "Kategorisiz şikayet amire görünmez").
- Olan: **200**, gövdede `acan_ad: "Can Kiracı"`, `acan_user_id`, `mesaj`. (PATCH 403 — yalnız okuma sızıyor.)
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/routers/complaints.py:228-244` `_get_or_404` yalnız `_own_scope` uyguluyor, `_amir_kapsami` (`:247`) yalnız liste ucunda. Aynı `_get_or_404`'ü kullanan alt uçlar (geçmiş/yorum vb.) de etkilenir.
- Önerilen düzeltme: `_get_or_404` içinde `_amir_kapsami(_own_scope(...), user)`.

### YETKI-05: Güvenlik amiri tesis görevlisinin vardiyasını silebiliyor/değiştirebiliyor/yayınlayabiliyor
- Sınıf: Ciddi (rol içi IDOR; P231 "tam yetki, yalnız güvenlik")
- Rol / yüzey: guvenlik_amiri / API (web'de `/vardiya-plani` amire açık)
- Adımlar: yönetici tesis görevlisine (Hasan) vardiya atar. Amir: (a) `DELETE /vardiya-plani/{id}`, (b) `PATCH /vardiya-plani/{id}` `{"not_metni":"amir"}`, (c) `POST /vardiya-plani/yayinla?baslangic=…`, (d) `POST /vardiya-plani/haftadan-kopyala` `hedefi_temizle=true`.
- Beklenen: hepsi 403 `vardiya_yalniz_kendi_ekibin` (POST `/vardiya-plani` tesis görevlisi için zaten 403 veriyor).
- Olan: (a) 200 → Hasan'ın satırı `iptal`; (b) 200; (c) 200 `{"yayinlanan":1,"bildirilen_kisi":1}` → Hasan'ın satırı yayınlandı ve Hasan'a bildirim gitti; (d) 200 → hedef haftadaki Hasan satırı `iptal` (kopyalanmadı, ama temizlendi).
- Tekrarlanabilir: evet (`$S/yetki/amir.py`, `amir2.py`)
- Şüpheli kök neden: `backend/app/routers/vardiya_plani.py` — `_hedef_gorunur` yalnız `ata` (:351), `toplu_ekle` (:766), `kalip_uygula` (:1063), `ice_aktar` (:1964) içinde. `cikar` (:436), `guncelle` (:1223), `haftayi_doldur` (:476), `parti_geri_al` (:1181), `yayinla` (:1491, `_yayin_kosullari` :1458 rol süzmüyor), `haftadan_kopyala` (:1680, temizleme kısmı) denetlemiyor.
- Önerilen düzeltme: satırı yükleyen her uçta hedef kullanıcının rolünü `_hedef_gorunur` ile denetle; toplu uçlarda (`yayinla`, `haftadan-kopyala`, `haftayi-doldur`) sorguya `user_id IN (görünür roller)` koşulu ekle.

### YETKI-06: Kiracı `/me/dues`'ta malike hedeflenmiş borçları görüyor (malik de kiracınınkini)
- Sınıf: Ciddi (P218 §D kuralı yalnız bir uçta uygulanmış; mobil ve web borç ekranı bu ucu kullanıyor)
- Rol / yüzey: resident (kiracı/malik) / API + mobil (`dues_api.dart:20`) + web (`app/api/me/dues`)
- Adımlar: A-1'de malik Zeynep (oturmuyor), kiracı Can. Yönetici `hedef_kurali=malik` tanımlı "Çatı onarımı" (33.300) ve `kiraci_oncelikli` "Isınma" (44.400) tahakkuk eder → DB'de `hedef_user_id` sırasıyla Zeynep ve Can (doğru). Kiracı ve malik `GET /me/dues`.
- Beklenen: kiracı malik kalemini görmez (P218 §D: "kiracı malik kalemini görmez"), kalemin hedefi kendisi değilse göstermez.
- Olan: ikisi de dairenin **tüm** kalemlerini görüyor (bakiye 284.700, `hedef_ad` alanı da boş dönüyor). Aynı anda `/me/odeme-bilgileri` kiracıya 44.400, maliğe 240.300 diyor → iki ekran farklı borç.
- Tekrarlanabilir: evet (`$S/yetki/tanim.py`, `odeme.py`)
- Şüpheli kök neden: `backend/app/routers/dues.py:853-873` `me_dues` sakinin dairelerinin `_unit_status`'unu olduğu gibi döndürüyor — `hedef_user_id` ve P218 rol kuralı hiç uygulanmıyor. Kural yalnız `routers/sakin_odeme.py:77-135` `_borc_kurus` içinde.
- Önerilen düzeltme: tek bir "sakinin gördüğü kalemler" sorgusu yaz (hedef = ben VEYA hedefsiz ∧ P218 kuralı) ve iki uç da onu kullansın.

### YETKI-07: `/me/odeme-bilgileri` kiracının tanımsız (daireye yazılmış) aidatını SQL NULL mantığı yüzünden düşürüyor
- Sınıf: Ciddi (sakine eksik borç gösteriliyor — ödeme ekranı)
- Rol / yüzey: resident (kiracı) / API + mobil ödeme ekranı
- Adımlar: A-1'e türsüz (tanımsız) 150.000 aidat + türsüz 57.000; kiracıya hedefli 44.400. Kiracı `GET /me/odeme-bilgileri`.
- Beklenen: P218 §D: yalnız "tanımı `malik` diyen hedefsiz kalem" kiracıdan gizlenir; türsüz eski kalemler görünür → 251.400.
- Olan: `borc_kurus: 44400` — türsüz 207.000 kaybolmuş. Malik için doğru (240.300).
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/routers/sakin_odeme.py:121-128` — `~DuesAssessment.gelir_gider_tanim_id.in_(subquery)`; `gelir_gider_tanim_id IS NULL` iken `NULL NOT IN (...)` → NULL → satır elenir.
- Önerilen düzeltme: `(gelir_gider_tanim_id IS NULL) OR NOT IN (...)`.

### YETKI-08: Davetle aktifleşen hesapların e-postası "doğrulanmamış" kalıyor → şifremi unuttum sessizce çalışmıyor, tesis değiştirme 403
- Sınıf: Ciddi (hesap kurtarma)
- Rol / yüzey: tüm davetli roller (yönetici tarafından eklenen herkes) / API + web + mobil
- Adımlar: `kur.py` her hesabı standart yolla açar (`POST /users` / `/residents` → e-postadaki davet bağlantısı → `POST /davet/parola`). Ardından: (1) DB `eposta_dogrulandi`; (2) `POST /auth/sifre/kod-iste` (yetki kiracısı); (3) aynı e-postayla iki tesiste yönetici → `GET /me/tesislerim`, `POST /me/tesis-degistir`.
- Beklenen: davet bağlantısı e-postaya gönderildiği ve tıklandığı için adres kanıtlanmıştır → doğrulanmış.
- Olan: (1) 10/10 hesap `eposta_dogrulandi=f`; (2) 200 `onay_bekliyor` ama **hiç e-posta gitmiyor** (sızdırmama gereği sessiz) — kullanıcı sonsuza kadar bekler; (3) `/me/tesislerim` yalnız kendi tesisini listeliyor, geçiş 403 `tesis_uyeligi_yok`. Her iki tesiste bir kez e-posta kodu ile giriş yapınca (bayrak açılıyor) liste ve geçiş çalıştı. Ayrıca `/me/hesap-sil/eposta-kod-iste` 422 `no_email` ("doğrulanmış e-posta yok") — parolasını unutmuş davetli kullanıcı hesabını da silemez.
- Tekrarlanabilir: evet (`$S/yetki/coklu.py`, `hesap.py`)
- Şüpheli kök neden: `backend/app/routers/davet.py:163-205` `davet_parola` (ve muhtemelen `davet_sosyal`) `user.eposta_dogrulandi = True` yazmıyor. OTP girişi yazıyor (`auth.py:885-886`).
- Önerilen düzeltme: davet jetonu tüketildiğinde, davet e-postayla gönderildiyse `eposta_dogrulandi=True`.

### YETKI-09: Parola sıfırlama/değiştirme mevcut oturumları kapatmıyor
- Sınıf: Ciddi
- Rol / yüzey: tüm roller / API
- Adımlar: iki cihazda giriş (A, B). "Şifremi unuttum" ile yeni parola kur. A'nın access'i ve B'nin refresh'i ile istek.
- Beklenen: sıfırlama (hesabın ele geçirildiği senaryonun kurtarma yolu) tüm refresh ailelerini iptal eder.
- Olan: eski parola 401, yeni 200 ✔ — ama eski access `/me` **200**, eski refresh `/auth/refresh` **200** (yeni jeton çifti verdi). Saldırgan 30 gün boyunca oturumu yenileyebilir.
- Tekrarlanabilir: evet (`$S/yetki/hesap.py`)
- Şüpheli kök neden: `auth.py:949-994` `sifre_sifirla` ve `me.py:217-261` `change_my_password` Redis'teki `refresh:*` ailelerine dokunmuyor; refresh aileleri kullanıcıya göre indekslenmiyor (`auth.py:98-106`), iptal için kullanıcı başına bir "oturum sürümü" yok.
- Önerilen düzeltme: `app_user`'a `oturum_surumu` (veya `parola_degisti_at`) ekle, access/refresh jetonuna göm, `get_current_user` ve `/auth/refresh`'te karşılaştır.

### YETKI-10: Çıkış jetonları geçersiz kılmıyor — backend'de logout ucu yok
- Sınıf: Ciddi
- Rol / yüzey: tüm roller / web + mobil + API
- Adımlar: BFF `POST /api/auth/login` (denetçi) → çerezlerdeki `tesis_at`/`tesis_rt` alınır → `POST /api/auth/logout` (200) → eski değerlerle backend'e `POST /auth/refresh` ve `GET /me`.
- Beklenen: refresh ailesi iptal (401).
- Olan: eski refresh **200** (yeni çift), eski access **200**. Web çıkışı yalnız çerezi siliyor (`admin-web/lib/backend.ts:342-346`), mobil yalnız yerel depoyu (`auth_repository_impl.dart:169-172`). `/me/cihazlar/tumunden-cik` de bilerek oturum kapatmıyor (me.py:730-735). Yani "telefonumu kaybettim"/"paylaşımlı bilgisayardan çıktım" senaryosunda çalınan refresh 30 gün geçerli ve kullanıcının bunu iptal etmenin HİÇBİR yolu yok (parola değiştirmek de etmiyor — YETKI-09).
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/routers/auth.py` — `_revoke_family` var ama onu çağıran bir `POST /auth/logout` ucu yok.
- Önerilen düzeltme: `POST /auth/logout {refresh_token}` → `_revoke_family`; web ve mobil çıkışı bu ucu çağırsın; "tüm cihazlardan çık" YETKI-09'daki oturum sürümünü artırsın.

### YETKI-11: Personel kendi hesabını silince vardiya geçmişi CASCADE ile siliniyor (anonimleştirilmiyor)
- Sınıf: Orta
- Rol / yüzey: tesis_gorevlisi (tüm personel) / API
- Adımlar: yetki2 tesis görevlisine vardiya planı atandı; görevli `POST /me/hesap-sil {current_password}`.
- Beklenen: P189/hesap_silme.py: geçmişi olan hesap anonimleştirilir; "tur/okutma kayıtları anonim kalır".
- Olan: `{"deleted":true}` — `app_user` satırı tamamen silindi ve `vardiya_plani` satırları (0'a düştü) **CASCADE** ile gitti. Mesai hesabı `vardiya_plani`'den okunduğu için (vardiya_plani.py:1453 notu) o kişinin geçmiş çalışma kaydı da kayboluyor. Geçmişi olan sakin (şikâyet) doğru anonimleşti — kural FK'nin RESTRICT olmasına bağlı.
- Tekrarlanabilir: evet (`$S/yetki/sil.py`, `sil2.py`)
- Şüpheli kök neden: DB `fk_vardiya_plani_user` `ON DELETE CASCADE` (`confdeltype=c`); `hesap_silme.py:69-104` "FK RESTRICT geçmiş olduğunu söyler" varsayımına dayanıyor. Diğer CASCADE FK'ler de (ör. vardiya_izin?) aynı sessiz kaybı yapıyor olabilir — taranmadı.
- Önerilen düzeltme: çalışma kaydı taşıyan tabloların `user_id` FK'lerini RESTRICT yap (ya da hesap_silme'de açık "geçmiş" kontrolü).

### YETKI-12: Sakin panik alarmı 500 veriyor
- Sınıf: Ciddi (sakin panik butonu çalışmıyor) — yetki kapsamı dışı, tohumlama sırasında çıktı
- Rol / yüzey: resident / API (`POST /panik`)
- Adımlar: kiracı `POST /panik {"tip":"sakin","kategori":"saglik","aciklama":"e2e"}` (iki tesiste de).
- Beklenen: 201.
- Olan: **500**; traceback `routers/panik.py:142 _govde: out.daire_no = birim.daire_no → AttributeError: 'Unit' object has no attribute 'daire_no'` (api.log). Alarmın kaydedilip kaydedilmediği ölçülmedi (panik ajanına bırakıldı).
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/routers/panik.py:142` — `Unit` modelinde alan adı `no`.
- Önerilen düzeltme: `birim.no`; `_govde`'yi unit_id'li alarmla test et.

### YETKI-13: Mobilde e-posta kodu ile giriş ve "şifremi unuttum" yok (web'de var)
- Sınıf: Orta (parite kuralı)
- Rol / yüzey: tüm mobil roller / mobil
- Adımlar: `mobile/lib/src/features/auth/data/auth_api.dart`'taki uçlar listelendi.
- Beklenen: web ile aynı giriş yolları (web: "Parola yerine e-postaya kod gönder", "Şifremi unuttum" — `admin-web/app/api/auth/eposta-kod`, `…/sifre`).
- Olan: mobil `/auth/giris/eposta-kod-*` ve `/auth/sifre/*` çağırmıyor; mobilde parolasız giriş yalnız **telefon+SMS kodu** (SMS kapalı → çalışmıyor). Mobilde parolasını unutan kullanıcının uygulama içi yolu yok.
- Tekrarlanabilir: evet (kod okuması)
- Şüpheli kök neden: parite açığı — `auth_api.dart` yalnız P149 telefon kodu yolunu uyguluyor.
- Önerilen düzeltme: mobil giriş ekranına e-posta OTP + şifremi unuttum; ya da istisna kararını yazılı hale getir.

### YETKI-14 (Küçük): Amir tesis görevlisine görev atayınca hata metni yanıltıcı
- Sınıf: Küçük
- Rol / yüzey: guvenlik_amiri / API
- Olan: `POST /tasks` hedef tesis görevlisi → 422 "Yönetici görevi yalnız güvenlik/tesis görevlisi kullanıcılara atayabilir." — reddin sebebi amirin kapsamı, metin tesis görevlisini "izinli" sayıyor ve "Yönetici" diyor.
- Önerilen düzeltme: amir dalı için ayrı metin ("Yalnız güvenlik personeline görev atayabilirsiniz").

### YETKI-15 (Küçük/Öneri): Dev'de e-posta kodu isteyen uçlar tutarsız — biri 200, biri 502
- Sınıf: Öneri
- Olan: SMTP yokken `/auth/giris/eposta-kod-iste` ve `/auth/sifre/kod-iste` 200 + kod geçerli; `/me/eposta/kod-iste` ve `/me/hesap-sil/eposta-kod-iste` 502 ve kod satırı geri alınıyor (log'daki kod geçersiz). Dev'de e-posta değiştirme ve kodla hesap silme uçtan uca test edilemiyor. Kimlikli uçta 502 dürüst bir tasarım olabilir; ama dev'de log sağlayıcısı "başarısız" sayıldığı için bu akışlar hiçbir ortamda (prod dışında) sürülemiyor.
- Önerilen düzeltme: `log-eposta` sağlayıcısını dev'de "gonderildi" say (ya da `EPOSTA_LOG_BASARILI=1`).

## Notlar (bulgu değil)
- `me.py:188` `update_my_avatar` docstring'i "resident 403" diyor, kod resident'e izin veriyor (bayat yorum).
- Amirin ziyaretçi kayıtlarında sakin adını görmesi P231 §3 tasarımı ("Ziyaretçi kayıtları: okur").
- Saha rolleri vardiya çizelgesinde tüm personeli görüyor — P231 "P232 gerilemesi" bölümündeki bilinçli karar.
- **Test aracı uyarısı:** `ortak.kod_bul()` e-posta gövdesindeki İLK 4-8 haneli sayıyı alıyor ve bu, adresin içindeki zaman damgası (ör. `…17505148@example.com`) oluyor → yanlış kod. `re.findall(r"Kod: (\d{6})", …)` kullanılmalı.
