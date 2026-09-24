# mobil — E2E bulguları

Tesis: `e2e-mobil-sitesi-8eabcb` (+ çok-tesis testi için `mobil2`). Cihaz/emülatör YOK.
Kanıt dosyaları (`$S/mobil/`): `sozlesme.py` → `sozlesme.json` (mobile/lib'deki 309 Dio çağrısı ↔ openapi.json),
`yanit.py` (fromJson ↔ yanıt şeması), `canli1.py`, `canli2.py`, `canli_panik*.py`, `cok_tesis.py`,
`rol_tarama.py` → `rol_matris.json` (mobilin çağırdığı 84 GET ucu × 7 rol), `flutter_test.txt`, `analyze.txt`.

## KONTROL LİSTESİ

| Madde | Sonuç | Kanıt |
|---|---|---|
| **İstek gövdesi ↔ backend şeması (309 çağrı)** | KALDI (1 gerçek uyuşmazlık) | 12 aday çıktı, 11'i elle doğrulanıp yanlış pozitif çıktı; `POST /residents` email eksik → 422 (MOBIL-2) |
| Sorgu parametreleri ↔ openapi | GEÇTİ | literal `queryParameters` anahtarlarında bilinmeyen parametre yok (ana ekran sayaçları elle tarandı) |
| Yanıt ayrıştırma (fromJson ↔ yanıt şeması) | GEÇTİ (kısmi otomatik) | 22 aday; hepsi yanlış pozitif (Dukkan yanıtları openapi'de tipsiz; patrol `checkpoint` bilinçli zenginleştirme) |
| İlk açılış — senkron ağır iş | GEÇTİ | `main.dart`: runApp öncesi yalnız 3 secure-storage okuması (try/catch'li); sürüm/panik/push işleri ilk kareden sonra |
| Soğuk açılış oturum | GEÇTİ (tasarım) | `auth_controller.dart:158` soğuk açılış HER ZAMAN login (WP2.3 bilinçli karar) |
| Arka plandan dönüş — token yenileme | GEÇTİ | 401→`/auth/refresh` tek-uçuş; canlı: refresh 200, eski refresh tekrar 401 (rotasyon çalışıyor) |
| Bildirime dokunma, uygulama kapalıyken (`getInitialMessage`) | KISMEN | işleniyor (`push_registrar.dart:75`), ama yalnız GİRİŞTEN SONRA; rol sağlayıcısı yüklenirken `asData` null → hedef kaybolabilir (yarış, ÖLÇÜLEMEDİ) |
| Push tipi → yönlendirme haritası eksiksiz mi | KALDI | backend 45 `data.tip`; push yönlendirmede 15 tip eşlemesiz (MOBIL-5) |
| Derin bağlantı (davet) | KALDI | manifest/entitlements `yonetiyor.com`+`yonetio.site`; davet bağı `https://yönetiyor.com/davet/…` (IDN) → eşleşmez (MOBIL-6); AASA/assetlinks yer tutucu (bilinen konsol işi) |
| Kamera/konum/bildirim izni reddi | KISMEN | konum reddi → okutma `izin_yok` ile sürer (iyi); bildirim reddi akışı durdurmaz (iyi); 3 ekranda kamera reddi yakalanmıyor (MOBIL-7) |
| Zorunlu güncelleme atlanamaz | GEÇTİ (kod) | `MaterialApp.builder` içinde, `PopScope(canPop:false)`, alt ağaç çizilmez |
| "Daha sonra" 24 saat | GEÇTİ (kod) | `surum_erteleme.dart` `kOnerilenErteleme = 24h`, secure storage |
| Sunucu erişilemezken kilitlemez | GEÇTİ | `SurumApi.kontrol` her hatada `guncel` döner. Yan etki: Öneri MOBIL-11 |
| `/surum/kontrol` canlı | GEÇTİ | 5 gövde → 200 `guncel` (dev'de politika tanımsız; zorunlu dalı ÖLÇÜLEMEDİ — politika global, başka ajanları etkiler) |
| Dukkan "yakında" | GEÇTİ | `GET /ozellikler` → `{"dukkan": false}` (anonim+oturumlu); tüm Dukkan rotaları `DukkanKapisi` ile sarılı, hata→kapalı |
| Ekran döndürme | ÖLÇÜLEMEDİ | tüm uygulama yatay açık (Info.plist + manifest); yatayda yerleşim testi yok |
| Düşük pil / bellek | ÖLÇÜLEMEDİ | cihaz yok |
| Giriş: tek alan e-posta/telefon | GEÇTİ | canlı: e-posta 200, +90 telefon 200, `0…` yerel biçim 200, `login-phone` 200, yanlış parola 401 |
| Giriş: OTP | GEÇTİ (tasarım) | login ekranında kod yolu YOK (SMS ürün genelinde kapalı); `girisKoduIste` ölü kod |
| Giriş: Google/MS/Apple | ÖLÇÜLEMEDİ | dev'de `/auth/oauth/saglayicilar` → `[]`, düğmeler gizli (doğru davranış) |
| Çok tesisli seçim | GEÇTİ | aynı e-posta 2 tesiste: slugsuz login 409 `tesis_secimi_gerekli`, `/auth/tesislerim` 2 tesis, slug'lı login 200 |
| Panik: sol menü üst sağ, tek dokunuş | GEÇTİ (kod) | `home_drawer.dart:75` başlık satırında sağda SOS; menü açıkken tek dokunuşla sayfa, kategori opsiyonel, tip düğmesi tek dokunuş |
| Panik: 7 kategori metni farklı/doğru | GEÇTİ | canlı: 7 `panik_kategori_*` bildirim metni hepsi farklı ve içerikle uyumlu; 7 dilde arb çevirileri dolu |
| Panik: 5 sn iptal, iptalde bildirim yok | GEÇTİ | `iptal_penceresi_sn: 5`; iptal edilen alarm: 0 alıcı, 0 bildirim |
| Panik: "112/155 yerine geçmez" | GEÇTİ | `panikYasalUyari` düğmelerden ÖNCE, 7 dilde |
| **Panik: SAKİN tipi** | **KALDI** | 500 — MOBIL-1 |
| Kamera ızgarası 2 sütun | GEÇTİ | `kameralar_screen.dart:86` `crossAxisCount: 2` |
| Bildirim okunmuş/okunmamış + rozet | GEÇTİ | canlı: okunmamış 9→8 (PATCH), okunmuş 0→1, tümünü-okundu 8, `q` araması 3 sonuç; rozet `okundu=false&limit=1` meta.total |
| Ön planda push SnackBar | KISMEN | iki dinleyici aynı messenger'a yazıyor (MOBIL-8) |
| Arama simgesi ve kapsamı | KALDI | amir, sakin ad+telefonlarını görüyor (MOBIL-4) |
| Görünüm modu Büyük + sistem ölçeği | KISMEN | çarpımsal (×1.3), üst sınır yok (MOBIL-12 Öneri); p230 testleri geçiyor |
| 320dp taşma | GEÇTİ (test) | `small_screen_overflow_test` ve "beş eksen" sürüşleri geçiyor; sabit genişlik taraması: 4 yer (≤150dp), risk düşük |
| 7 dil arb | GEÇTİ | 2091 anahtar × 6 dil: eksik 0, fazla 0; `l10n_eksikler.txt` = `{}`; TR ile aynı kalanlar yalnız şablon/özel ad (`{plaka} ({tanim})`, "Profil", "SOS") |
| Hesap silme | GEÇTİ | canlı: yanlış parola 400, parola ile 200 `deleted:true`, sonra giriş 401, eski jeton 401 |
| Rol × mobil menü uçları | KALDI | güvenlik amiri menüsündeki 5 modül 403 (MOBIL-3) |
| `flutter test` tam takım | KALDI | 2361 geçti, 3 atlandı, **8 KALDI** — hepsi koyu tema kontrastı (MOBIL-9) |
| `flutter analyze` | GEÇTİ | 0 hata, 5 uyarı (1'i lib: kullanılmayan import `dukkan_taleplerim_screen.dart:8`) |
| Web–mobil parite | KALDI | web'de olup mobilde hiç olmayan ana özellikler listesi (MOBIL-10) |

Toplam: 38 madde → GEÇTİ 23, KALDI 8, KISMEN 4, ÖLÇÜLEMEDİ 3.

---

### MOBIL-1: Sakin panik alarmı 500 veriyor, alarm hiç oluşmuyor
- Sınıf: Engelleyici
- Rol / yüzey: resident (malik/kiracı) / mobil → API
- Adımlar: kiraci ile `POST /panik {"tip":"sakin","kategori":"diger"}` (mobilin gönderdiği gövde, `panik_api.dart:26`)
- Beklenen: 201 + 5 sn iptal penceresi
- Olan: **500**; api.log: `AttributeError: 'Unit' object has no attribute 'daire_no'` (routers/panik.py:142 `_govde`). İşlem geri alınıyor (`panik_alarm` 0 satır), worker `panik.yayinla` → `{'durum':'yok'}`. Yani sakinin SOS'u HİÇ gitmiyor, ekranda da genel hata çıkıyor. `guvenlik`/`yonetici_anons` tipleri (unit_id yok) çalışıyor.
- Tekrarlanabilir: evet (her sakin alarmında)
- Şüpheli kök neden: `backend/app/routers/panik.py:142` `out.daire_no = birim.daire_no` ve `backend/app/panik_yayin.py:105` `birim.daire_no`. `Unit` modelinde alan adı `no` (`models.py:1549`). İkisi de düzeltilmeli; yalnız birini düzeltmek yayında (`_veri`) yeniden patlar.
- Önerilen düzeltme: `birim.no`; sakin tipi için API testi ekle (mevcut testler bu dalı kapsamıyor).

### MOBIL-2: Mobilden sakin ekleme her zaman 422 (e-posta gönderilmiyor)
- Sınıf: Ciddi
- Rol / yüzey: yonetici / mobil "Sakinler → ekle"
- Adımlar: `POST /residents {"telefon":"+905349990011","unit_no":"A-3","blok":"A"}` (tam olarak `residents_api.dart:92` gövdesi)
- Beklenen: 201 ya da formda e-posta alanı
- Olan: 422 `{"field":"email","message":"Field required"}`. Mobil formda e-posta alanı yok (`residents_screen.dart:606` yalnız telefon+daire+blok); kullanıcı genel hata metni görür, sakin EKLENEMEZ.
- Tekrarlanabilir: evet
- Şüpheli kök neden: P197'de `ResidentCreate.email` zorunlu yapıldı (`backend/app/schemas.py:4665`), mobil istemci güncellenmedi. Sözleşme taramasının bulduğu TEK gerçek gövde uyuşmazlığı.
- Önerilen düzeltme: mobil formu e-posta alanıyla genişlet (davet yalnız e-postadan gidiyor); widget testine gövde anahtarı kilidi.

### MOBIL-3: Güvenlik amiri mobil menüsündeki 5 modül backend'de 403
- Sınıf: Ciddi
- Rol / yüzey: guvenlik_amiri / mobil ana menü + API
- Adımlar: amir jetonuyla mobil modüllerin liste uçları (`rol_tarama.py`)
- Beklenen: menüde görünen her modül açılır (menü yorumu: "auth.md §4a amire ACIK: … ARAÇ GEÇİŞİ VE İHLAL OKUMA")
- Olan: `GET /announcements` 403, `/site-rules` 403, `/violations` 403, `/vehicle-passes` 403, `/integrations/anpr/events` 403 → menüde `announcements`, `siteKurallari`, `ihlaller`, `aracGecis`, `plakaOlaylari` kartları açılınca hata. Ayrıca amirin ana ekranı (SahaHomeScreen) `/weather` 403 ve `/activity` 403 alıyor.
- Tekrarlanabilir: evet
- Şüpheli kök neden: backend rol kümeleri amiri içermiyor — `routers/violations.py:43`, `vehicle_passes.py:60`, `anpr.py:60`, `announcements.py:47`, `site_rules.py:46`; mobil `home_menu.dart:309-342` bunları amire açıyor. `contracts/auth.md` §4a "araç geçişi ve ihlal okuma" amire açık diyor → backend sözleşmeyle çelişiyor (duyuru/kural için karar yok).
- Önerilen düzeltme: sözleşmeye göre backend `_READER`lara `guvenlik_amiri` ekle (ihlal/araç/plaka); duyuru/kural için karar ver ve menüyü ona göre daralt. Ayrıca `izgara_koprusu.dart:73` `_amireKapali` hâlâ `/visitors` içeriyor ama P231'den beri amir menüsünde ziyaretçi var ve backend 200 dönüyor (tutarsızlık).

### MOBIL-4: Global arama güvenlik amirine sakinlerin ad + telefonunu açıyor (KVKK)
- Sınıf: Ciddi
- Rol / yüzey: guvenlik_amiri / mobil arama (web aramasını da etkiler — aynı uç)
- Adımlar: amir `GET /arama?q=Zeynep` / `q=Elif` / `q=Ali`
- Beklenen: amir sakin kişisel verisi göremez (auth.md §4a: "KAPALI: sakin listesi … Gerekçe KVKK"); `/users` amir için `gorunur_roller` ile daraltılıyor
- Olan: 200 `[{"kaynak":"kisi","baslik":"Zeynep Malik","ayrinti":"+905343574290"}]`, `Elif Oturan +90534628…`, yönetici/ikinci malik de listede. Karşılaştırma: security/tesis_gorevlisi/kiraci aynı sorgularda `[]`.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/routers/arama.py:145` `_kisi` rol kümesini `users._READER`dan alıyor (amir dahil) ama `users.py:206`daki `gorunur_roller(user.role)` süzgecini UYGULAMIYOR.
- Önerilen düzeltme: `_kisi`de `AppUser.role.in_(gorunur_roller(u.role))` süzgeci; amir için arama kilidi testi.

### MOBIL-5: Push dokunma yönlendirmesinde 15 backend tipi eşlemesiz
- Sınıf: Orta
- Rol / yüzey: tüm roller / mobil push tıklaması (arka plan + kapalı)
- Adımlar: backend `dispatch_external(... data={"tip": …})` çağrılarından tip listesi çıkarıldı (36 çağrı + dukkan) ve `mobile/lib/src/routing/push_yonlendirme.dart` `_hamHedef` ile karşılaştırıldı
- Beklenen: kullanıcıya giden her tipin bir hedefi olsun
- Olan: şu tipler `default → null` (dokununca hiçbir yere gitmiyor): `akilli_ev_kacak`, `akilli_ev_yangin` (su/gaz kaçağı, YANGIN), `panik_kapandi`, `panik_yanlis_alarm`, `bakim_yaklasti/bugun/gecikti`, `entegrasyon_koptu`, `vardiya_yayinlandi`, `gorev_tamamlandi`, `gorev_adim_ilerleme`, `anket_acildi`, `aidat_onizleme`, `gider_onay`, `aylik_ozet`. İlginç olan: uygulama İÇİ liste haritası (`notifications/presentation/bildirim_rotasi.dart`) bunların 11'ini eşliyor — iki ayrı tablo ayrışmış. (`panik_alarm` push'u eşlemesiz ama `PanikGozcusu` yoklamasıyla tam ekran uyarı zaten çıkıyor.) Ters yönde liste haritasında da eksik: `duyuru`, `etkinlik`, `aidat_*`, `anket_acildi`, `gurultu_*`, `erisim_*` → listede dokununca yalnız "okundu"; ayrıca liste haritası rol süzgeci uygulamıyor (sakin `talep_cozuldu` → `/complaints`, güvenlik `uzak_okutma` → `/patrol-tracking`; P217'nin push için düzelttiği hata burada duruyor).
- Tekrarlanabilir: evet (kod karşılaştırması; FCM teslimi ÖLÇÜLEMEDİ)
- Şüpheli kök neden: `push_yonlendirme.dart:143-247` ve `bildirim_rotasi.dart:29-60` iki bağımsız tablo.
- Önerilen düzeltme: tek tabloya indir (tip+rol → rota) ve backend tip listesini kilitleyen bir test ekle.

### MOBIL-6: Davet derin bağlantısı uygulamayı açmaz — e-postadaki alan adı IDN
- Sınıf: Orta
- Rol / yüzey: davet edilen herkes / mobil (Android App Links, iOS Universal Links)
- Adımlar: `davet_bagi()` (`backend/app/davet.py:118`) → `settings.portal_base_url` = `https://yönetiyor.com` (config.py:133 varsayılanı ve `infra/.env.prod.example:66`)
- Beklenen: bağlantı konağı manifest/entitlements'taki konaklardan biri olsun
- Olan: e-postadaki bağ `https://yönetiyor.com/davet/<jeton>` = `xn--ynetiyor-n4a.com`; `AndroidManifest.xml:56-57` ve `Runner.entitlements` yalnız `yonetiyor.com` + `yonetio.site`. IDN konak 301 ile kanonik adrese yönleniyor, ama iOS/Android doğrulayıcıları 3xx izlemez → bağlantı her zaman tarayıcıda açılır. (Buna ek olarak AASA `REPLACE_TEAMID`, assetlinks parmak izi yer tutucu — bilinen konsol işi.)
- Tekrarlanabilir: evet (yapılandırma okuması; cihazda ÖLÇÜLEMEDİ)
- Şüpheli kök neden: `PORTAL_BASE_URL` SMS okunaklılığı için Unicode seçildi (env yorumu), derin bağlantı bunu hesaba katmıyor.
- Önerilen düzeltme: davet bağı için ASCII `https://yonetiyor.com` kullan (ya da IDN konağı da manifest+entitlements+well-known'a ekle).

### MOBIL-7: Üç ekranda kamera izni reddi / kamera hatası yakalanmıyor
- Sınıf: Küçük
- Rol / yüzey: saha + yönetici / mobil
- Adımlar: kod okuması — `pickImage(source: camera)` try/catch'siz: `tasks/presentation/task_detail_screen.dart:775` (adım fotoğrafı), `finans/presentation/gider_screen.dart:71` (fiş), `finans/presentation/sayac_okuma_screen.dart:82` (sayaç fotoğrafı). Diğer 11 çağrı sarılı.
- Beklenen: izin reddinde kullanıcıya mesaj + ayarlara yönlendirme; belirgin açıklama (Play) önce gösterilsin
- Olan: iOS `camera_access_denied` PlatformException yakalanmayan async hata olarak düşer; düğme tepkisiz kalır. Bu üç yer `belirginAciklamaGoster` de çağırmıyor.
- Tekrarlanabilir: cihazda ÖLÇÜLEMEDİ (kod kanıtı)
- Önerilen düzeltme: diğer 11 çağrıdaki try/catch + hata metni desenini uygula.

### MOBIL-8: Ön planda gelen push iki SnackBar üretiyor; "Aç" düğmesi hemen gizleniyor ve çevrilmemiş
- Sınıf: Küçük
- Rol / yüzey: tüm roller / mobil
- Adımlar: kod okuması — `main.dart:76-92` `rootScaffoldMessengerKey` ile "Ac" eylemli SnackBar; `home_shell.dart:77-103` aynı olayda `hideCurrentSnackBar()` + kendi "Göster" SnackBar'ı (aynı kök messenger).
- Olan: hedef ekrana götüren "Ac" SnackBar'ı anında kapanıyor, kullanıcı yalnız bildirim sekmesine giden SnackBar'ı görüyor. `'Ac'` sabit Türkçe metin (l10n dışı, `ç` de yok).
- Önerilen düzeltme: tek dinleyici; eylem etiketini l10n'dan al.

### MOBIL-9: `flutter test` tam takım — 8 test kırmızı (koyu tema kontrastı)
- Sınıf: Orta
- Rol / yüzey: resident/yönetici/saha ana ekranları, koyu tema
- Olan: `flutter test` → +2361 ~3 **-8**. Kırılan testler: `resident_home_screen_test` (KOYU TEMA 7 dil, FOTOĞRAFLI), `yonetici_home_screen_test` (aynı ikisi), `saha_home_screen_test` (aynı ikisi), `push_gelisi_surus_test` (2 kabuk testi). Hepsi WCAG: alt gezinme "Ana Sayfa" 4.12:1 (12sp), "Geçmiş Ödemeler" 3.91:1 (13sp), rozet "3" 3.75:1 (11sp). Ön plan `#7CA9FF`, arka plan ~`#3B4650`/`#394960`.
- Tekrarlanabilir: evet (`$S/mobil/flutter_test.txt`)
- Şüpheli kök neden: `mobile/lib/src/core/theme/home_tokens.dart` (son değişiklik `dcde3b63` P244 §10d, 52 satır) — `0xFF2563EB → 0xFF7CA9FF` koyu eşlemesi seçili sekme/metin zemininde yetersiz.
- Önerilen düzeltme: koyu temada seçili gezinme/etiket rengini açılt (≥4.5:1) ya da zemini koyulaştır.

### MOBIL-10: Web'de olup mobilde hiç olmayan ana özellikler (parite kuralı)
- Sınıf: Orta
- Rol / yüzey: yonetici / mobil
- Yöntem: `admin-web/app/(protected)/**/page.tsx` rotaları ↔ `app_router.dart` rotaları + mobilin çağırdığı uçlar (`sozlesme.json`) + `docs/web-mobil-esitlik.md` ve `docs/P204-parite-analizi.md` gerekçeleri.
- Mobilde HİÇ olmayan, belgede "bilinçli fark" olarak GEREKÇELENDİRİLMEMİŞ ya da P204'te "Evet" denmiş olanlar:
  - **Davetler** listesi / yeniden gönder (`/davetler`; P204: "Evet — sahada gerçek ihtiyaç") — mobil `GET /davet`, `POST /davet/{id}/yeniden` çağırmıyor
  - **Gelir kaydı** (`/finans/gelirler`; P204 "Evet") — mobil yalnız gider yazıyor
  - **Tekil aidat tahakkuku** (`/dues`; P204 "Evet")
  - **Fazla mesai** (`/finans/mesai`; P204 "Kısmen — özet evet, yazma evet") — mobilde `/mesai` çağrısı yok
  - **Virman / İade** (`/finans/virman`, `/finans/iade`; P204 "Evet ama nadir")
  - **İcra takibi** (`/icra`; P204 "Kısmen")
  - **SMS/e-posta mesajları** (`/mesajlar`; P204 "Kısmen")
  - **Kamera kayıtları** (NVR oynatma, `/kamera-kayitlari`) — iki belgede de yok
  - **Gürültü uyarıları** (`/gurultu-uyarilari`; esitlik.md: "uç hazır, ekran yok")
  - Denetim kaydı (`/audit`) — belgede yok
- Bilinçli (atlanmalı): rapor motoru, karar defteri, doküman yükleme, KVKK metni yayını, içe aktarım, banka, otomasyon, toplu borçlandırma, açılış fişleri.
- Önerilen düzeltme: ya ekranları yaz ya da her biri için esitlik.md'ye "bilinçli fark" gerekçesi ekle (memory kuralı: istisna ÖNCEDEN gerekçelendirilir).

### MOBIL-11: Zorunlu güncelleme, ağ kesilince kalkıyor (Öneri)
- Sınıf: Öneri
- Olan: `SurumDenetleyici.kontrolEt` her ön plana dönüşte yeniden sorar; `SurumApi.kontrol` hata olursa `guncel` döner ve durum ÜZERİNE yazılır (`surum_denetleyici.dart` → `state = SurumDurumState(karar: karar…)`). Zorunlu ekrandaki kullanıcı uçak moduna geçip uygulamayı arka plana alıp geri getirince kapı açılır. Planın "sunucu erişilemezken kilitlememeli" şartı karşılanıyor; bu ikisini birlikte karşılamak için son bilinen `zorunlu` kararını oturum boyunca tutmak yeterli.
- Kaynak: `mobile/lib/src/features/surum/data/surum_api.dart` catch-all, `presentation/surum_denetleyici.dart`.

### MOBIL-12: Görünüm "Büyük" × sistem yazı ölçeği üst sınırsız (Öneri)
- Sınıf: Öneri
- Olan: `core/gorunum/gorunum_modu.dart` `_Carpan.scale = taban × 1.3`, sınır yok. iOS erişilebilirlik boyutlarında (≈3.1×) sonuç ≈4×. p230 testleri bu uçları kapsamıyorsa taşma riski var (cihazda ÖLÇÜLEMEDİ).
- Önerilen düzeltme: çarpımı `clamp` et (ör. toplam ≤ 2.0–2.4) ya da bu uçları test eksenine ekle.

### MOBIL-13: Küçük notlar
- Sınıf: Küçük
- `flutter analyze`: `lib/src/features/dukkan/presentation/dukkan_taleplerim_screen.dart:8` kullanılmayan import (lib'deki tek uyarı).
- `auth_controller.dart` `girisKoduIste/girisKoduDogrula` (P149 SMS kodlu giriş) UI'dan kaldırılmış, ölü kod.
- Aynı kullanıcı açık alarmı varken yeni kategoriyle SOS'a basınca sunucu MEVCUT alarmı döndürüyor (yeni kategori yok sayılıyor; canlıda `saglik` isteği `deprem` alarmının id'sini döndü) — mobil yine 5 sn geri sayım gösteriyor ama pencere çoktan geçmiş; iptal düğmesi "yanlış alarm" üretir. Tasarım olabilir; ekranda "zaten açık alarmınız var" demek daha doğru olur.
- `panik_kapandi` metni `yer` yoksa "… kapatıldı — -" (tire yer tutucu görünüyor).
- Hesap silme: davetle etkinleşmiş (e-postadaki bağı tıklamış) sakinde `POST /me/hesap-sil/eposta-kod-iste` → 422 `no_email` ("doğrulanmış e-posta yok"). Parolası olan kullanıcı etkilenmiyor; parolasız (SSO) yolda ölçülmeli.
- iOS Info.plist'te `NSLocationAlwaysAndWhenInUseUsageDescription` var ama uygulama arka planda konum almıyor (App Review sorusu çıkarabilir).
