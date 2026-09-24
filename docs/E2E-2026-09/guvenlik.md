# Bulgular — `guvenlik` (Plan §5 Güvenlik operasyonu)

Tesis: `e2e-guvenlik-sitesi-32bd75` (tenant 2a590ab4-0947-41d8-9e18-dc65d62d13ee). Betikler: `$S/guvenlik/`.

ORTAM NOTLARI (ürün bulgusu DEĞİL):
- Ana web dev sunucusu `:3000` oturum başında bozuktu (chunks 404, hidrasyon yok). Ana ajan yeniden başlattıktan sonra web ölçümleri `:3000`'da YENİDEN yapıldı; aşağıdaki web sonuçları o ölçümdendir.
- Makine aşırı yüklü (load 26→55, RAM dolu): BFF zaman zaman 503, basit PATCH 60 sn zaman aşımı.
- `testpub` ve `testpub265` yayıncıları ~15:17 UTC'de `Broken pipe` ile ÇIKTI (Exited 224); o saatten sonra `testcam`'de `/cam` ve `/cam265` 404. Konteyner yeniden başlatma yasak olduğundan sonraki kamera ölçümleri kaynaksız kaldı.

ÖZET: 58 madde — 41 GEÇTİ, 6 KALDI, 7 KISMEN, 4 ÖLÇÜLEMEDİ. 18 bulgu (GUVENLIK-00…17): 1 Engelleyici, 5 Ciddi, 5 Orta, 4 Küçük (biri toplu), 3 Öneri.

## KONTROL LİSTESİ (§5.1–5.6)

| Madde | Sonuç | Kanıt |
|---|---|---|
| 5.1 Bağlantı testi RTSP H264 | GEÇTİ | `rtsp://testcam:8554/cam` → 200 `kodek:h264, tarayicida_oynatilir:true` |
| 5.1 Bağlantı testi RTSP H265 | GEÇTİ | `/cam265` → 200 `kodek:hevc, tarayicida_oynatilir:false` |
| 5.1 Bağlantı testi HLS | GEÇTİ | `http://mediamtx:8888/cam<id>/index.m3u8` → 200 h264 |
| 5.1 Test hata mesajları (yol yok / DNS / port kapalı) | GEÇTİ | 404→"akış yolu bulunamadı", DNS→"sunucu adı çözülemedi", port→"ağ üzerinden ulaşılamıyor"; kodek sorunu "adres hatalı" demiyor |
| 5.1 Kamera ekle RTSP (H264/H265) + HLS | GEÇTİ | 4 kamera 201; tür/şema uyuşmazlığı 422 Türkçe |
| 5.1 H265 kamerada alt akış (H264) | GEÇTİ | `alt_stream_url` kabul; canlı playlist `CODECS="avc1…"` (alt akış kullanılıyor), kare ana akıştan |
| 5.1 Canlı yayın (API) | GEÇTİ | H264: playlist+init+segment 200 (10 s soğuk); H265: 200 `hvc1` (tarayıcı sorunu bilinen madde) |
| 5.1 Canlı yayın (web oynatıcı) | ÖLÇÜLEMEDİ | yayıncılar (testpub) düştükten sonra web yeniden açılabildi; kaynak yok. API düzeyinde H264 manifest+segment 200 (yukarıda) |
| 5.1 Ana ekran kamera seçimi + sınır | GEÇTİ | `ana_ekranda` 4 sınırı: 5. → 422 "Ana ekranda en çok 4 kamera…" |
| 5.1 Özet'te kareler (web) | KISMEN | `:3000`'da özet şeridi işaretli 3 kamerayı (K264/K265/K265alt) gösteriyor, KHLS (işaretsiz) yok → seçim çalışıyor (`ekran/dash-alt.png`). Kare 502'de karo kırık resim+alt metin çiziyor, kameralar sayfası ise "Bağlantı yok" diyor; hata/yüklemede "seçilmedi" metni — GUVENLIK-07 |
| 5.1 Kameralar sayfası (web) | GEÇTİ | 4 kamera, "Görüntü veren 1 / alınamayan 3", karolar "Bağlantı yok" (yayıncılar düşük) — `ekran/yonetici-kameralar.png` |
| 5.1 Parola `stream_url`'de yok (API/DB) | GEÇTİ | DB `stream_url` temiz, `stream_parola_sifreli` şifreli; izleyici rollerde `rtsp://***` |
| 5.1 Parola loglarda | KALDI | ffmpeg stderr ham URL'yi (parolayla) api.log'a yazıyor — GUVENLIK-01 |
| 5.1 Rol görünürlüğü | GEÇTİ | sakin/tesis_görevlisi yalnız `sakin_gorebilir`; denetçi 403; yazma yalnız yönetici |
| 5.1 Mobil ızgara 2 sütun | GEÇTİ (kod) | `kameralar_screen.dart:86 crossAxisCount: 2` |
| 5.2 NVR 3 sağlayıcı yapılandırma | KISMEN | sablon/hikvision/dahua kaydediliyor; geçersiz sağlayıcı (`foo`) 200 ile kabul; hatalı şablon 500 — GUVENLIK-03 |
| 5.2 Geçmiş kayıt arama | GEÇTİ (kısmen ölçülebilir) | sablon `arama_destekli:false`; hikv./dahua ulaşılamaz→502 anlamlı mesaj; ters/24 s+ aralık 422 |
| 5.2 Oynatma | ÖLÇÜLEMEDİ | test yayıncıları (testpub) 15:17'de düştü; kayıt HLS 502 ("Canlı yayın henüz hazır değil" — metin kayıt için yanlış, GUVENLIK-04) |
| 5.2 Oynatma denetim kaydı | KISMEN | başarılı arama/oynatma audit'e yazılıyor; BAŞARISIZ olanlar geri alınıyor — GUVENLIK-02 |
| 5.2 Erişim yalnız yönetici+amir | GEÇTİ | security/tesis_görevlisi/denetçi/sakin → 403 |
| 5.3 NFC noktası + koordinat | GEÇTİ | ondalık, ±90/±180 sınır, 6+ hane yuvarlama, "41.0082" string 201; aşım/NaN/virgül 422 (500 YOK) |
| 5.3 NFC UID tekilliği | KALDI | büyük/küçük harf ve `:` farklı UID olarak kaydediliyor → okutmada 500 — GUVENLIK-05 |
| 5.3 Devriye planı haftalık gün / ek gün / vardiya | GEÇTİ | gunler [1..7] doğrulanıyor; ek_tarih penceresi üretildi; shift_id bağlanıyor |
| 5.3 Pencere oluşumu | GEÇTİ | plan kaydından ~3 sn sonra pencereler; gece planı ertesi güne sarkıyor |
| 5.3 NFC okutma (security) | GEÇTİ | 201, pencere `tamamlandi`; bilinmeyen etiket 404; sakin 403; Idempotency-Key zorunlu |
| 5.3 Kaçırılan tur alarmı | KALDI | plan oluşturulduğu an geçmiş 18 pencere için 18 sahte "kaçırıldı" alarmı — GUVENLIK-06 |
| 5.3 Eski/yürümeyen pencerelerin temizliği | KISMEN | gün değişince gelecek pencereler siliniyor; PASİF yapılan planın pencereleri KALIYOR — GUVENLIK-08 |
| 5.5 Panik mobil: yer, tek dokunuş, 7 kategori, 5 sn | GEÇTİ (kod) | drawer üst-sağ SOS (`home_drawer.dart:59-87`); 7 kategori; istek HEMEN gider, sunucu 5 sn bekletir, iptal→`iptal` ve bildirim yok |
| 5.5 Sakin paniği | KALDI (ENGELLEYİCİ) | çalışan imajda `POST /panik` sakin → 500, alarm satırı YOK — GUVENLIK-00 |
| 5.5 Güvenlik paniği alıcıları | GEÇTİ | security → security2+amir+yönetici (tetikleyen hariç), DB `panik_alici`+`notification` |
| 5.5 Yönetici anonsu → tüm site | GEÇTİ | 8 alıcı (tüm sakinler+saha); denetçi hariç (tasarım) |
| 5.5 5 sn içinde iptal | GEÇTİ | durum `iptal`, `panik_alici` 0, bildirim 0 |
| 5.5 Gönderildikten sonra iptal | GEÇTİ | `yanlis_alarm` + 8 alıcıya `panik_yanlis_alarm` |
| 5.5 Takip: gördü / müdahale / kapat | GEÇTİ | `goruldu_at`, `mudahale_at`, `mudahale_suresi_sn` detayda |
| 5.5 112/155 uyarısı mobil+web | GEÇTİ | `panikYasalUyari` mobil (butonlardan önce) + web sözlüğü |

| 5.4 Izgara: personel satırı, rol grupları, saat toplamları | GEÇTİ | web: "Güvenlik 2 kişi / Tesis Görevlisi 1 kişi", "23.25s / 45s" (6.75×3+3, mola düşülmüş) — `ekran/vardiya-yonetici.png` |
| 5.4 Atanmamış bölümü | GEÇTİ | `vardiya_duzeninde`: yönetici ve (vardiyasız) amir false → listede yok; kadro/vardiya geçmişi olan true |
| 5.4 Rol süzgeci / amir kapsamı | KISMEN | amir cizelgesi yalnız security+amir; amir ekip dışına toplu → 403; ama YAYINLA ekip dışını da yayınlıyor — GUVENLIK-11 |
| 5.4 Takvimden çoklu gün (keyfi günler) | GEÇTİ | `toplu` `gunler:[D0,D2,D4]` → 3 satır |
| 5.4 Gece/gündüz kalıbı + farklı günlere farklı saat | GEÇTİ | `kalip-uygula` `gruplar`: 2 gün 08-20 + 1 gün 20-08 |
| 5.4 Önizleme sayısı | GEÇTİ | `kuru:true` → `eklenecek:3`, satır satır liste + `gunluk_sinir_asildi` uyarısı |
| 5.4 Çakışma sessizce atlanmıyor | GEÇTİ | 409 yerine `uygulandi:false` + gün gün `cakisma`; gün aşırı çakışma (D0 22-06 vs D1 04-08) yakalandı |
| 5.4 Toplu işlem geri alma | KISMEN | kalıp partisi geri alındı (3→iptal); toplu/Excel geri alınamaz — GUVENLIK-13 |
| 5.4 Gün aşırı 22:00-06:00 + Europe/Istanbul | GEÇTİ | DB `tarih=D0, 22:00-06:00`; cizelge `D0T22:00 → D1T06:00`; `simdi.zaman` tenant yerel saati |
| 5.4 Molalar (yasal+şirket) | GEÇTİ | 60+15 dk → çalışma 6.75 s; `mola-onerisi` 12 s → 60 dk |
| 5.4 İzin → o güne vardiya atanamıyor | GEÇTİ | tekil `ata` → 422 "Bu kişi o gün izinli"; toplu → `cakisma` |
| 5.4 Vardiyalı güne izin | KALDI | izin kabul, vardiya planlı kalıyor — GUVENLIK-12 |
| 5.4 Taslak → yayınla → bildirim | KISMEN | personel cizelgesi taslakta boş, yayından sonra dolu; `vardiya_yayinlandi` bildirimleri doğru kişilere; ama Excel dışa aktarım taslağı sızdırıyor — GUVENLIK-10 |
| 5.4 Excel dışa/içe aktarım | GEÇTİ | xlsx 200; içe aktarma önizleme 6 eklenecek/3 hata (tarih, e-posta, saat) Türkçe mesajlı; yazma 6 eklendi (`22.00` reddi GUVENLIK-17) |
| 5.4 Haftalık/aylık/takvim görünümleri | GEÇTİ | web sekmeleri Gün içi/Hafta/Ay/Takvim; API 31 gün 200, 32 gün 422 |
| 5.4 Vardiya durumu kartı (şu an görevde) | KALDI | şablonsuz vardiyalar görünmüyor — GUVENLIK-09; web kartı yüklenirken "Şu anda planlı görevli yok" diyor (GUVENLIK-07 ile aynı desen) |
| 5.5 Web: tetikleme yok, takip var | GEÇTİ | web /panik: yalnız liste/takip ("Kim bastı, kim gördü…", "0/8 gördü"), tetikleme düğmesi yok; kapat `apiSend .../kapat` |
| 5.5 Sakin 7 kategori → site geneli (deprem vb.) | ÖLÇÜLEMEDİ | sakin yolu 500 (GUVENLIK-00); aynı genişleme amir `guvenlik/yangin` ile ölçüldü → tüm sakinler+saha (8 alıcı) GEÇTİ |
| 5.6 Araç geçişi | GEÇTİ | giriş 201 (plaka normalize `34ABC123`), içerideki araç tekrar giriş 409, çıkış 200, ikinci çıkış 409, plaka araması |
| 5.6 Otopark doluluk | GEÇTİ | kapasite yok → `oran:null`; 50 → 2/50 %4; çıkış sonrası 1 |
| 5.6 Ziyaretçi kaydı (API/mobil) | GEÇTİ | security 201; hedef başka dairenin sakini → 422; kiracıya `ziyaretci` bildirimi ("Ziyaretçiniz kaydedildi: Mehmet Misafir — A-1"), oturmayan malike yok |
| 5.6 Sakin adıyla arama | GEÇTİ (mobil) | `GET /units/ara?q=Can` / `Zeynep` / `kira` → A-1 + sakinler |
| 5.6 Web ziyaretçi formu (daire listeden) | ÖLÇÜLEMEDİ (tasarım) | sayfa P129 ile park (`lib/yuzey.ts:526`); park edilmiş form çalışmaz — GUVENLIK-14 |

## BULGULAR (detay)

### GUVENLIK-00: Sakin paniği 500 veriyor — alarm hiç oluşmuyor (çalışan imajda)
- Sınıf: Engelleyici
- Rol / yüzey: resident (kiraci, malik_oturan) / API (mobil SOS aynı ucu çağırır)
- Adımlar: `POST /panik {"tip":"sakin","kategori":"saglik"}` (kiracı A-1); ayrıca `{"tip":"sakin","kategori":"deprem"}` (malik_oturan B-5).
- Beklenen: 201, 5 sn sonra güvenlik+amir+yönetici'ye (deprem'de tüm siteye) bildirim.
- Olan: 500 Internal Server Error. `panik_alarm` tablosunda kiracının satırı 0 (işlem geri alındı). api.log: `AttributeError: 'Unit' object has no attribute 'daire_no'` (`/app/app/routers/panik.py:142 _govde`). Celery'ye 5 sn gecikmeli `panik.yayinla` görevi transaction geri alınmadan ÖNCE gönderiliyor → hayalet görev.
- Tekrarlanabilir: evet (dairesi olan her sakin paniği)
- Şüpheli kök neden: çalışan imajdaki `routers/panik.py:142` `birim.daire_no` ve `panik_yayin.py:105` `birim.daire_no` — `Unit` modelinde alan adı `no` (`models.py:1549`). NOT: çalışma ağacında (commit edilmemiş, `git status`: `M backend/app/routers/panik.py`, `M backend/app/panik_yayin.py`) `birim.no` olarak DÜZELTİLMİŞ görünüyor; api imajı kodu gömdüğü için yeniden build edilmeden etkisiz. Mevcut `test_p240_panik.py`/`test_p243_panik_kategori.py` bu yolu (unit'li sakin) yakalamamış.
- Önerilen düzeltme: düzeltmeyi commit + api/worker imajını yeniden build; unit'li sakin paniği için test ekle. Ayrıca `_yayin_planla` çağrısını commit SONRASINA taşımak (ya da görevde alarm yoksa sessizce çıkmak) hayalet görevi önler.

### GUVENLIK-01: Kamera parolası API loguna düz metin yazılıyor (LOG_PII'den bağımsız)
- Sınıf: Ciddi
- Rol / yüzey: yönetici / API (log)
- Adımlar: `POST /cameras/test-baglanti {"stream_url":"rtsp://kul:GizliParola77@testcam:8554/yokyol"}` → 502 (doğru mesaj).
- Beklenen: kimlik bilgisi hiçbir logda görünmez (kodun kendi yorumu: "kimlik bilgisi kimsenin isi degil").
- Olan: `api.log:1889` → `WARNING app.routers.cameras | [kamera] kare alinamadi: teshis=kamera_yol_bulunamadi ffmpeg='... Error opening input file rtsp://kul:GizliParola77@testcam:8554/yokyol.'`. Kayıtlı kamerada da aynı: `/kare` başarısız olursa `etkin_stream_url(obj)` (parola geri takılmış) ffmpeg'e verilir ve stderr aynen loglanır. Maskeleme `gunlukleme.py`deki yardımcılardan geçmiyor, yani LOG_PII=0 (prod) iken de sızar.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `backend/app/routers/cameras.py:866-870` (`logger.warning(... ffmpeg=%r, hata[:300])`) — stderr ham yazılıyor.
- Önerilen düzeltme: loglamadan önce stderr'deki `scheme://user:pass@` kısmını `***@` ile maskele (regex), ya da URL'yi stderr'den tamamen çıkar.

### GUVENLIK-02: Başarısız kayıt arama/oynatma denemeleri denetim kaydından siliniyor (KVKK)
- Sınıf: Orta
- Rol / yüzey: güvenlik amiri / API
- Adımlar: kamerada hikvision/dahua sağlayıcı + ulaşılamaz `kayit_adres`; `GET /cameras/{id}/kayit/araliklar` ×4 (hepsi 502).
- Beklenen: kod yorumu (`cameras.py:1311-1313` "DENETIM KAYDI ONCE... gecit hata verse bile iz kalsin") gereği her deneme audit_log'da.
- Olan: `camera_kayit_arama` sayısı 4 başarısız denemeden sonra 1'de kaldı; hatalı şablonla 500 dönen 2 oynatma da `camera_kayit_izleme`'ye yazılmadı.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `deps.py:59-62` `get_tenant_db` tek `session.begin()`; APIError fırlayınca audit satırı da ROLLBACK olur. `cameras.py:1262` ve `1316`daki audit aynı transaction'da.
- Önerilen düzeltme: denetim satırını ayrı bir kısa transaction'da (ya da owner bağlantısıyla) commit et; ya da hata yolunda audit'i yeniden yaz.

### GUVENLIK-03: Geçersiz kayıt şablonu 500; geçersiz sağlayıcı adı kabul ediliyor
- Sınıf: Orta
- Rol / yüzey: yönetici (yapılandırma), güvenlik amiri (oynatma) / API
- Adımlar: `PATCH /cameras/{id} {"kayit_saglayici":"sablon","kayit_adres":"rtsp://testcam:8554/{yokalan}"}` → 200; ardından `POST /cameras/{id}/kayit/oynat` → **500**. `kayit_adres":"rtsp://.../{"` → yine 500. `kayit_saglayici:"foo"` → 200 ile kaydedildi.
- Beklenen: kaydederken 422 ("şablonda bilinmeyen yer tutucu {yokalan}"; "sağlayıcı sablon/hikvision/dahua olmalı").
- Olan: 500 Internal Server Error (KeyError/ValueError `str.format`); geçersiz sağlayıcı ancak aramada `kamera_kayit_saglayici_yok` olarak ortaya çıkıyor.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `kamera_kayit/sablon.py:55` `self._sablon.format(...)` istisnası yakalanmıyor; `cameras.py:1323-1327` yalnız `httpx.HTTPError` yakalıyor. `schemas.py:1175/1229` `kayit_saglayici: str | None` — Literal değil.
- Önerilen düzeltme: şablonu kayıt anında `string.Formatter().parse` ile doğrula; `kayit_saglayici`yı `Literal["sablon","hikvision","dahua"]` yap.

### GUVENLIK-04: Kayıt oynatma hatasında "Canlı yayın henüz hazır değil" deniyor
- Sınıf: Küçük
- Rol / yüzey: güvenlik amiri / API (web /kamera-kayitlari)
- Adımlar: sablon kaynağı 404 veren bir kayıt aralığını oynat → `GET .../kayit/<yol>/index.m3u8`.
- Beklenen: "Kayıt bulunamadı / kayıt cihazından görüntü alınamadı".
- Olan: 502 `kamera_yayin_hazir_degil` = "Canlı yayın henüz hazır değil. Geçit çalışıyor ama kameradan görüntü alamadı; birkaç saniye sonra tekrar deneyin." — MediaMTX logu kaynağın 404 döndüğünü söylüyor (`[RTSP source] bad status code: 404`); kullanıcıyı boşuna tekrar denemeye yollar. Kayıt HLS vekilinde canlıdaki gibi hazırlanma bütçesi/kodek teşhisi de yok (15 sn sabit).
- Tekrarlanabilir: evet
- Şüpheli kök neden: `cameras.py:1375-1377`.
- Önerilen düzeltme: kayıt için ayrı hata kimliği; `_yol_kodegi` benzeri teşhisle kaynak 404'ü ayır.

### GUVENLIK-05: NFC UID normalize edilmeden kaydediliyor → aynı etiket iki kez, okutmada 500
- Sınıf: Ciddi
- Rol / yüzey: yönetici (tanım), security (okutma) / API
- Adımlar: `POST /checkpoints` UID `04A1B2C3D4E500` (201), sonra `04a1b2c3d4e500` (201!) ve `04:A1:B2:C3:D4:E5:00` (201). Security `POST /scans {"nfc_tag_uid":"04A1B2C3D4E500"}`.
- Beklenen: ikinci kayıt 409 "Bu etiket bu tesiste zaten kayıtlı"; okutma 201.
- Olan: iki ayrı checkpoint; okutma **500** (`sqlalchemy.exc.MultipleResultsFound`, api.log:13488). Etiket fiilen devre dışı kalıyor → tüm turlar "kaçırıldı". `:` ayraçlı UID mobilin ürettiği biçimle (`nfc_service.dart:98`, ayraçsız büyük harf) hiç eşleşmez.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `routers/checkpoints.py:88` UID'yi olduğu gibi yazıyor; tekillik `models.py:936` ham değerde. `scans.py:383-389` ise `upper(btrim())` ile karşılaştırıp `scalar_one_or_none()` çağırıyor.
- Önerilen düzeltme: create/patch'te `norm_nfc` + ayraç (`:`/`-`/boşluk) temizliği uygula; DB'de `upper(btrim(nfc_tag_uid))` üzerine unique index (göç + mevcut çiftlerin raporu).

### GUVENLIK-06: Yeni devriye planı, oluşturulduğu günün GEÇMİŞ saatleri için sahte "tur kaçırıldı" alarmları üretiyor
- Sınıf: Ciddi
- Rol / yüzey: yönetici (plan), yönetici+amir+güvenlik (alarm alıcıları) / API
- Adımlar: yerel 18:45'te `POST /patrol-plans {"baslangic_saat":"00:00","bitis_saat":"23:00","periyot_dakika":60}` + 2 checkpoint.
- Beklenen: yalnız plan oluşturulduktan sonraki pencereler; geçmiş saatler için alarm yok.
- Olan: bugünün 00:00-18:00 arası 18 pencere `bekliyor` üretildi, ~90 sn içinde `detect_missed` hepsini `kacirildi` yaptı → 18 `kacirilan_tur` bildirimi + 18 push (`MISSED_TOUR` worker.log ×18). Yönetici bildirim listesinde 18 adet "A Gün boyu turu kaçırıldı (2 eksik kontrol noktası)".
- Tekrarlanabilir: evet (günün ortasında oluşturulan / saati değiştirilen her plan)
- Şüpheli kök neden: `scheduler/windows.py:100-108` (bugün+ufuk döngüsü) günün tüm pencerelerini üretiyor; "geçmişi atla" filtresi (`w_end > now_utc`, `:98`) yalnızca gece-sarkan planın DÜN kolunda var. Docstring'deki niyet ("plan olusmadan onceki zamana sahte 'kacirildi' yazilmasin") normal kolda uygulanmamış.
- Önerilen düzeltme: tüm kollarda `w_end > now_utc` (ya da `w_start >= plan.created_at`) filtresi; `detect_missed`te pencere planın `created_at`'inden önce bitiyorsa atla.

### GUVENLIK-07: Özet kamera şeridi ve vardiya kartı — hata/yükleme anında "boş" mesajı; karede kırık resim
- Sınıf: Küçük
- Rol / yüzey: yönetici / web /dashboard
- Adımlar: 3 kamera `ana_ekranda=true` iken /dashboard (BFF `/api/cameras?ana_ekranda=true` 503 döndü — yük altında).
- Beklenen: "Kameralar yüklenemedi" / iskelet.
- Olan: "Ana ekranda gösterilecek kamera seçilmedi. Kameralar sayfasından bir kamerayı düzenleyip…" — yöneticiyi zaten yaptığı ayarı tekrar yapmaya yolluyor (ekran: `$S/guvenlik/ekran/ozet-yonetici.png`, konsol: `[HTTP 503] GET /api/cameras?ana_ekranda=true…`). Veri gelmeden önce de aynı mesaj yanıp söner.
- Tekrarlanabilir: evet (istek hata verdiğinde / ilk yüklemede)
- Şüpheli kök neden: `admin-web/app/(protected)/dashboard/page.tsx:557-559` yalnız `data` alınıyor, `error`/`isLoading` yok; `:738` `kameraYanit?.items ?? []` → `KameraSeridi.tsx` boş listeyi "seçilmedi" sayıyor.
- Ek ölçüm (`:3000` düzeldikten sonra): veri gelince şerit işaretli 3 kamerayı doğru gösteriyor (`ekran/dash-alt.png`). Ama kare 502 döndüğünde özet karosu kırık resim ikonu + alt metin çiziyor (kameralar sayfası aynı durumda "Bağlantı yok" diyor) — `KameraSeridi.tsx` `<img>`inde `onError` yok. Aynı "yükleniyor = boş" deseni /vardiya-plani'de: ilk ölçümde kart "Şu anda planlı görevli yok" + ızgara "Bu filtrelerle personel bulunamadı" (Filtreler 0) gösterdi; 90 sn bekleyince API'nin döndürdüğü "Ali Güvenlik — Akşam 17:00–20:00" ve 3 kişi çizildi (`vardiya-plani/page.tsx:715-735` `simdiDurum` undefined → "kimse yok").
- Önerilen düzeltme: SWR `error`/`isLoading`'i şeride/karta geçir; hata→hata metni, yükleniyor→iskelet; karo `<img onError>` → "Bağlantı yok".

### GUVENLIK-08: Pasif yapılan devriye planının gelecek pencereleri silinmiyor → pasif plan için "kaçırıldı" alarmı
- Sınıf: Ciddi
- Rol / yüzey: yönetici / API
- Adımlar: plan C (yarın 10:00-12:00 pencereleri) → `PATCH /patrol-plans/{C} {"aktif":false}`; 30 sn bekle.
- Beklenen: yarının `bekliyor` pencereleri silinir.
- Olan: iki pencere `bekliyor` olarak DURUYOR (DB). `detect_missed` plan aktifliğine bakmıyor → yarın 11:00/12:00'de pasif plan için alarm gidecek. (Karşılaştırma: gün değiştirme — B planı cumartesiye çekilince bugünkü 19:00 penceresi doğru silindi; plan silinince pencereler gitti.)
- Tekrarlanabilir: evet
- Şüpheli kök neden: `scheduler/service.py:233` yalnız `aktif = true` planları dolaşıyor, silme adımı (`:264`) bu döngünün içinde → pasif plana hiç uğramıyor; `detect_missed` (`:302`) `p.aktif` süzmüyor.
- Önerilen düzeltme: pasif planların gelecek `bekliyor` pencerelerini sil (PATCH aktif=false anında ve materialize'da); `detect_missed`e `p.aktif = true` koşulu.

### GUVENLIK-09: "Şu an görevde" (`/vardiya-plani/simdi`) şablonsuz (serbest) vardiyaları görmüyor
- Sınıf: Ciddi
- Rol / yüzey: yönetici/amir / API (web özet vardiya kartı ve mobil aynı uç)
- Adımlar: yerel 18:54'te security'ye şablonlu "Akşam 17-20" (`POST /vardiya-plani`), tesis_görevlisine AYNI saatlerle serbest vardiya (`POST /vardiya-plani/toplu`). `GET /vardiya-plani/simdi`.
- Beklenen: ikisi de `gorevdekiler`de.
- Olan: yalnız "Ali Güvenlik" döndü; Hasan Temizlik (serbest vardiya, cizelge'de 17:00-20:00 görünüyor) YOK. Hızlı ekle, Excel içe aktarım ve kalıp-uygula serbest satır yazdığı için (DB: 14 serbest satırdan hiçbiri şablonlu değil) kart pratikte çoğu vardiyayı kaçırır. Ayrıca şablonlu satırda da satırın kendi saatleri değil şablon saatleri kullanılıyor; taslak (yayınlanmamış) satır "görevde" sayılıyor.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `routers/vardiya_plani.py:1379` INNER `join(Shift, …)` + `vardiya_araligi(plan.tarih, shift.baslangic_saat, shift.bitis_saat)`; cizelge'nin kullandığı `outerjoin` + `plan_araligi(plan, shift)` deseni burada uygulanmamış.
- Önerilen düzeltme: `outerjoin` + `plan_araligi`; slot adı için `shift_ad or vardiya_rolu or "Serbest"`; yayın durumunu kararlaştır (taslak görevde sayılmamalı).

### GUVENLIK-10: Personel, Excel dışa aktarımla TASLAK planı ve tüm personelin e-postasını görüyor
- Sınıf: Orta
- Rol / yüzey: security / API (`GET /vardiya-plani/disa-aktar`)
- Adımlar: yayınlanmamış 6 satır varken security `GET /vardiya-plani/disa-aktar?baslangic=<hafta>&gun=14`.
- Beklenen: cizelge ile aynı kural — personel yalnız YAYINLANMIŞ planı görür (P241 §2; `cizelge` bunu uyguluyor: security cizelgesi bloksuz döndü).
- Olan: 200, xlsx'te 6 taslak satır + tesis görevlisi dahil tüm personelin e-posta adresleri.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `routers/vardiya_plani.py:1854` `disa_aktar` `_OKUR` (security/tesis_görevlisi dahil) ile açık ve `yayinlandi_at` süzgeci yok (cizelge `:590`'daki koşul kopyalanmamış).
- Önerilen düzeltme: aynı yayın süzgeci; ya da dışa aktarımı `_YAZAR`'a kısıtla; personele e-posta sütunu verme.

### GUVENLIK-11: Güvenlik amiri "Yayınla" ile ekip DIŞI personelin (tesis görevlisi) planını yayınlıyor ve ona bildirim gönderiyor
- Sınıf: Orta
- Rol / yüzey: guvenlik_amiri / API (web /vardiya-plani "Yayınla")
- Adımlar: yönetici tesis görevlisine taslak vardiya girer; amir `POST /vardiya-plani/yayinla?baslangic=…&gun=14`.
- Beklenen: amir yalnız kendi ekibini (security/amir) yayınlar — ekle/sil/toplu için zaten 403 `vardiya_yalniz_kendi_ekibin` (ölçüldü: amir tesis_görevlisine toplu → 403).
- Olan: `{"yayinlanan":6,"bildirilen_kisi":3}`; DB'de tesis_görevlisi satırı yayınlandı, tesis görevlisine "1 vardiya yayınlandı" bildirimi gitti. `yayin-ozeti` de aynı genişlikte sayıyor.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `routers/vardiya_plani.py:1458-1463` `_yayin_kosullari` `user`ı alıyor ama `_rol_kosulu(user)` eklemiyor.
- Önerilen düzeltme: `*_rol_kosulu(user)` koşulunu ekle (join AppUser ile).

### GUVENLIK-12: Vardiyası olan güne izin verilebiliyor; vardiya planlı kalıyor
- Sınıf: Orta
- Rol / yüzey: yönetici / API
- Adımlar: security'nin bugün 17:00-20:00 planlı vardiyası varken `POST /vardiya-izin {"user_id":security,"tur":"mazeret","baslangic":bugün,"bitis":bugün}`.
- Beklenen: uyarı/red ya da o günkü vardiyanın iptali (izinli güne vardiya yazılamıyor → ters yön de tutarlı olmalı).
- Olan: 201 `onaylandi`; vardiya `planli` duruyor (DB 1 satır) → hem izinli hem görevde; mesai hesabı vardiyayı çalışma sayar, "şu an görevde" kartı onu gösterir.
- Tekrarlanabilir: evet
- Şüpheli kök neden: `routers/vardiya_izin.py:173` izin oluşturma/onaylama çakışan `vardiya_plani` satırlarına bakmıyor (yalnız vardiya→izin yönü `_izin_denetle` ile korunuyor).
- Önerilen düzeltme: onaylanan izin aralığındaki planlı vardiyaları listele ve (onayla) iptal et ya da 409 ile sor.

### GUVENLIK-13: Hızlı ekle (toplu) ve Excel içe aktarımı geri alınamıyor
- Sınıf: Öneri
- Rol / yüzey: yönetici/amir / API
- Adımlar: `POST /vardiya-plani/toplu` (3 gün) ve `POST /vardiya-plani/ice-aktar` (6 satır).
- Beklenen: plan maddesi "toplu işlem geri alınabilir mi".
- Olan: `kalip-uygula` `parti_id` veriyor ve `parti/{id}/geri-al` çalışıyor (3 satır → `iptal`, GEÇTİ). Ama toplu ve içe aktarım satırları `parti_id=NULL` (DB: 14 serbest satırın 11'i) → tek tek silmek gerekiyor.
- Şüpheli kök neden: `routers/vardiya_plani.py` `toplu_ekle` (`VardiyaPlani(... )` parti_id yok) ve `ice_aktar`.
- Önerilen düzeltme: her iki yola da `parti_id` ver ve yanıtta döndür.

### GUVENLIK-14: Web ziyaretçi formu hiçbir rolde çalışamaz (daire serbest metin, hedef sakin yok)
- Sınıf: Öneri
- Rol / yüzey: web /ziyaretciler
- Adımlar: kod incelemesi + API: web formunun gövdesi `{unit_no, ziyaretci_ad, notlar}` (`app/(protected)/ziyaretciler/page.tsx:97-103`).
- Beklenen (plan): daire listeden seçilir, sakin adıyla aranır.
- Olan: sayfa P129 kararıyla PARK (`lib/yuzey.ts:526` `"/ziyaretciler": []`) — hiçbir web rolü açamıyor, yani TASARIM gereği ölçülemedi. Park edilmiş form geri açılırsa çalışmaz: `target_resident_user_id` zorunlu (API ölçümü: gövde web'deki gibi → 422 `Field required`), daire serbest metin; kayıt yetkisi yalnız `security` (yönetici/amir → 403). Mobil tarafta ise daire/sakin arama VAR ve çalışıyor (`GET /units/ara?q=Can` → A-1 + sakinler; `by-no/A-1/residents`).
- Önerilen düzeltme: sayfa geri açılacaksa mobildeki `units/ara` + hedef sakin seçicisini web'e taşı; açılmayacaksa ölü formu kaldır.

### GUVENLIK-15: Bağlantı testi ayrı parolayı / kayıtlı parolayı kullanamıyor (düzenleme akışı)
- Sınıf: Küçük
- Rol / yüzey: yönetici / web /kameralar (kod incelemesi)
- Adımlar: parolalı kamerayı düzenlemek için aç → "Bağlantıyı test et".
- Beklenen: kayıtlı parola ile test.
- Olan: form yalnız temizlenmiş `stream_url`i gönderiyor (`kameralar/page.tsx:340-343`), `KameraTestIstek` (`schemas.py:1116-1127`) ne `stream_parola` ne `camera_id` alıyor → parolalı kamerada düzenleme sırasında test "kimlik hatalı" döner, kamera aslında çalışırken. (dev test kamerası kimlik istemediği için canlı ölçülemedi — kod bulgusu.)
- Önerilen düzeltme: teste `camera_id` (sunucu kayıtlı kimliği takar) ya da `stream_kullanici/stream_parola` ekle.

### GUVENLIK-16: Canlı yayın eşzamanlılık sınırı platform geneli (tüm tesisler tek havuzda)
- Sınıf: Öneri
- Rol / yüzey: tüm izleyiciler / API
- Adımlar: kendi tesisimde 3 kamerayı izledikten sonra 4. (HLS) kamera canlı ucu.
- Olan: 429 "Aynı anda izlenebilecek kamera sınırına ulaşıldı". Anahtar `redis.keys("kamera:canli:*")` tenant içermiyor (`cameras.py:1128-1131`), `kamera_canli_sinir=3` (`config.py:148`) → prod'da bir tesiste 3 izleyici diğer TÜM tesislerin canlı yayınını kilitler. (Tasarım "CPU sınırı" diyor; ama tesis başı adillik yok.) Ayrıca `KEYS` üretimde O(N) tarama.
- Önerilen düzeltme: tesis başı alt sınır + global üst sınır; `KEYS` yerine sayaç/SET.

### GUVENLIK-17: Küçük doğrulama/metin kusurları (toplu)
- Sınıf: Küçük
- `security` rolü checkpoint eklemeye çalışınca mesaj "…güvenlik amiri değiştiremez" (rol yanlış adlandırılıyor). `POST /checkpoints` (security) → 403.
- Koordinat hatalarında ana mesaj Türkçe ama `details` İngilizce ham pydantic ("Input should be less than or equal to 90").
- Yalnız `gps_lat` verilip `gps_lng` boş bırakılınca 201 (yarım koordinat kaydediliyor).
- Devriye planı: `periyot_dakika` (60) > süre (30 dk) → 201, hiç pencere üretmeyen sessiz plan; geçmiş `ek_tarihler` (2020-01-01) kabul.
- Excel içe aktarım `22.00` saat biçimini reddediyor ("08:00 biçiminde yazın") — TR kullanıcıların yaygın yazımı.
- Mobil panik: istek butona basınca gider, geri sayım yanıt geldikten SONRA başlar; yavaş ağda ekrandaki "5 sn" sunucudaki pencereden uzundur → kullanıcı iptal ettiğini sanırken `yanlis_alarm` gider (`panik_sayfasi.dart:112-131`). Öneri: sayacı `created_at`e göre hesapla.
