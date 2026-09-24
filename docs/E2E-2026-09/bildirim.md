# BİLDİRİM / E-POSTA / İLETİŞİM — E2E bulguları (etiket: bildirim)
Tesis: e2e-bildirim-sitesi-c4c061 (f2714b10-…). Sahte FCM token'ları her hesaba `POST /devices` ile kaydedildi.
Not: dev'de PUSH_PROVIDER=fcm ama servis hesabı yok → push_gonderim.durum=`yapilandirilmadi` (gerçek gönderim yok).

## KONTROL LİSTESİ
| Madde | Sonuç | Kanıt |
|---|---|---|
| 3.1 Davet e-postası alıcı/dil/içerik | GEÇTİ | en/de/ar davetler doğru alıcıya, doğru dilde; `/davet/coz` bağlantı jetonu 200 |
| 3.1 Kod e-postası | KISMEN | doğru alıcı + kod; Accept-Language yok sayılıyor (tasarım: yalnız TR) — B-18 |
| 3.1 Resend webhook imza/idempotency | GEÇTİ | geçerli imza 200, bozuk/eski/imzasız 401, tekrar `tekrar` |
| 3.1 Panelde İletildi/Geri döndü | KALDI / ÖLÇÜLEMEDİ | dev'de `saglayici_mesaj_id` hiç dolu değil; kodla: davet paneli webhook'u hiç yansıtmıyor — B-15 |
| 3.2 Cihaz token kaydı (`POST /devices`, mobil device_api.dart) | GEÇTİ | 10 hesap 201 |
| görev atandı | GEÇTİ | notif+push → yalnız atanan (tesis_gorevlisi), kanal genel |
| görev tamamlandı | GEÇTİ | yönetici'ye; mobil push yönlendirmesi yok — B-11 |
| görev adım ilerleme | GEÇTİ | ilk adımda yöneticiye; 30 dk birleştirme tasarım |
| vardiya hatırlatma | KALDI | 15 dk kademesi çalıştı (beat, kanal `yonetio_vardiya_v2`) ama TASLAK vardiyaya da gitti — B-02; 5 dk kademesi yönetici tarafından açılamıyor — B-03; sonrasında liste 500 — B-08 |
| vardiya yayınlandı | GEÇTİ | yalnız yayınlanan kişilere; 15 dk birleştirme |
| vardiyaya başlamadı | KALDI | taslak plana da alarm — B-02; liste 500 — B-08 |
| gürültü uyarısı (eşik) | GEÇTİ | eşik=2 ile ölçüldü (5 ile mantık aynı): yöneticiye push, oturan sakine `gurultu_uyari_sakin` (kanal gürültü) |
| gürültü eskalasyonu (2. kez) | GEÇTİ | security+security2+amir'e satır+push, yöneticiye satır+push, kritik kanal |
| panik sakin | KALDI (Engelleyici) | 500, alarm kaydedilmiyor — B-04 |
| panik güvenlik / yönetici anons | KISMEN | alıcılar doğru, yanlış alarm/kapandı doğru; kategorili alarmlar GENEL kanal — B-05; push dokunma yönlendirmesi yok — B-11 |
| bakım yaklaşıyor/bugün/gecikti | GEÇTİ | beat görevi yalnız kendi tesisime daraltılarak tetiklendi: 3 satır, bugün→5 rol, diğerleri yönetim; ikinci koşu idempotent |
| anket açıldı | KISMEN | hedef rol/malik süzgeci doğru; personel hedeflenebiliyor ama oy veremiyor — B-07 |
| duyuru | KISMEN | push tüm roller (amir hariç), in-app satır yok, hedef kitle yok — B-12/13 |
| talep/şikayet | KISMEN | açık→çözüldü/reddedildi/iş emri bildirimleri + durum geçmişi doğru; yeni_talep / is_emri_atandi / otomatik çözümde in-app satır yok — B-10 |
| ziyaretçi / kargo | GEÇTİ | hedef sakine / daire sakinlerine satır+push (kargo oturmayan malike de — Öneri) |
| aidat borç / hatırlatma | KISMEN | alıcı doğru; metin "son ödeme: 22" — B-14 |
| Tercih: mobil kapalı → push gitmez | GEÇTİ | `hedef_yok/tercih_kapali`, in-app satır yine yazıldı |
| Tip bazında kapatma | KALDI (Öneri) | böyle bir ayar yok — B-17 |
| Ses kanalı | GEÇTİ (kodla) | kanal_sec tablosu doğrulandı; panik kategori istisnası B-05. Gerçek ses/APNs ÖLÇÜLEMEDİ |
| 3.3 varsayılan Okunmamış sekmesi | GEÇTİ | aria-pressed=true |
| 3.3 arama iki sekmede | KALDI | API çalışıyor, web BFF `q` düşürüyor — B-16 |
| 3.3 toplu okundu / toplu sil / tek okundu | GEÇTİ | web: satır sayısı ve DB değişti |
| 3.3 rozet anında güncelleme | GEÇTİ | 6→5 (tek), 5→3 (toplu okundu), 3→2 (sil), yenilemesiz, 4-6 sn |
| 3.3 liste kararlılığı | KALDI (Engelleyici) | vardiya satırları sonrası 500 — B-08 |
| Okundu/silme kişiye ait mi | KALDI | yönetim alarmları paylaşılan tek satır — B-09 |
| 7 Duyuru görselli | GEÇTİ | presign→PUT→duyuru; sakin foto_url 200 image/png |
| 7 Duyuru hedef kitle | KALDI | yok — B-12 |
| 7 Kural oluşturma | GEÇTİ | 201 (ilk denemede token süresi doldu, tekrarda OK); sakin okur; amir/denetçi 403 — B-13 |
| 7 Etkinlik + katılım | GEÇTİ | sakin katılır/katılmaz, değiştirme 409 (tasarım), sayaçlar doğru; push sakinlere |
| 7 Talep aç/çöz + geçmiş + sakine bildirim | GEÇTİ | geçmiş acik→is_emri→cozuldu (actor_role) |
| 7 Anket en az 2 seçenek | GEÇTİ | API 422; web form 2'de silme düğmesi disabled, ayrı kutular, "+" (kodla) |
| 7 Anket hedef çoklu seçim | GEÇTİ | resident+security, resident+malik süzgeci doğru |
| 7 Oy verme + sonuç | GEÇTİ | tekrar oy 409; adlı dökümde kişi, anonimde 409 |
| 7 Anonim anket kimlik saklanmıyor mu | KALDI | user_id NULL + audit'e oy yok AMA xmin ile oy→kişi eşlendi — B-06 |
| 7 Anonimlik PATCH ile değişmez | GEÇTİ | PATCH `anonim` → 422 extra_forbidden |
| 7 Davet gönderme ve takip | KISMEN | liste + yeniden gönder çalışıyor; teslim durumu yansımıyor — B-15; dil korunmuyor — B-18 |
| Ek güvenlik | KALDI | `PATCH /me/bildirim-tercihleri {"eposta_dogrulandi":true}` — B-01 |

ÖLÇÜLEMEDİ: FCM/APNs gerçek teslimi (servis hesabı yok → `yapilandirilmadi`), ses, uygulama kapalıyken teslim, gerçek e-posta teslimi/bounce.


### BILDIRIM-01: `PATCH /me/bildirim-tercihleri` ile kullanıcı kendi e-postasını "doğrulanmış" işaretleyebiliyor
- Sınıf: Ciddi (güvenlik)
- Rol / yüzey: herhangi bir oturumlu kullanıcı / API
- Adımlar: denetci ile `PATCH /me/bildirim-tercihleri {"eposta_dogrulandi": true}`
- Beklenen: alan yok sayılmalı / 422; doğrulama yalnız kodla (`/me/eposta/dogrula`, me.py:530).
- Olan: 200; DB'de `app_user.eposta_dogrulandi` false → **true** oldu.
- Tekrarlanabilir: evet
- Şüpheli kök neden: backend/app/schemas.py:737-739 — `BildirimTercihUpdate` içinde `eposta_dogrulandi: bool = False` alanı var (yorumu başka bir şemadan kopyalanmış gibi); routers/me.py:812-814 `model_dump(exclude_unset=True)` + `setattr` ile her alanı kullanıcıya yazıyor.
- Etki: doğrulanmış-e-posta kapısı baypas: şifre-sıfırlama kodu (auth.py:939), hesap silme kod kanalı (me.py:242), e-posta değiştirme bildirimi (me.py:375), P228 üyelik eşlemesi.
- Önerilen düzeltme: alanı `BildirimTercihUpdate`'ten sil (+ `extra="forbid"`), setattr'ı beyaz listeye bağla; regresyon testi.

### BILDIRIM-02: Yayınlanmamış (TASLAK) vardiyaya hatırlatma ve "vardiyaya başlamadı" alarmı gidiyor
- Sınıf: Ciddi
- Rol / yüzey: yönetici → security / tesis_gorevlisi; backend beat (scheduler.vardiya_hatirlatma)
- Adımlar: (1) yönetici bugün 18:15'te başlayan vardiyaya security2'yi atar, `POST /vardiya-plani/yayinla`; sonra aynı vardiyaya security'yi atar ve YAYINLAMAZ (`yayinlandi_at` NULL). (2) 17:38'de başlamış vardiyaya tesis_gorevlisi taslak olarak atanır.
- Beklenen: P241 §2.4 — "yeni satırlar taslak açılır, personel görmez". Taslak satır için hatırlatma/başlamadı uyarısı üretilmemeli.
- Olan: 18:00'de `notification(vardiya_hatirlatma)` + push hem security2 hem **security (taslak)** için yazıldı; `vardiya_baslamadi` "Hasan Temizlik 17:38" (taslak) yöneticiye gitti. worker.log: `scheduler.vardiya_hatirlatma ... {'hatirlatma': 0, 'baslamadi': 2}`.
- Tekrarlanabilir: evet
- Şüpheli kök neden: backend/app/scheduler/service.py:553-561 ve :662-669 — sorgular yalnız `vp.durum='planli'` süzüyor, `vp.yayinlandi_at IS NOT NULL` koşulu yok.
- Önerilen düzeltme: her iki sorguya `AND vp.yayinlandi_at IS NOT NULL` ekle (+ test).

### BILDIRIM-03: Yönetici vardiya hatırlatma / başlamadı sürelerini değiştiremiyor ama web formu alanı gösteriyor
- Sınıf: Orta
- Rol / yüzey: yönetici / API + web (/tesis-ayarlari, grup "vardiya")
- Adımlar: `PATCH /tenant/settings {"vardiya_hatirlatma_dk":"15,5"}` ve `{"vardiya_baslamadi_dk":20}` (yönetici)
- Beklenen: saha işletmesi ayarı; formda görünüyorsa kaydedilebilmeli (lib/tesis-ayar-alanlari.ts başlığı: "ikisi ayrışırsa yönetici formu doldurup kaydedemez").
- Olan: 403 `"Yönetici yalnız tesis adını ve hava konumunu değiştirebilir."` (mesaj da eskimiş: yönetici artık 20+ alan yazabiliyor).
- Tekrarlanabilir: evet
- Şüpheli kök neden: backend/app/routers/tenant.py:41-79 `_YONETICI_YAZABILIR` kümesinde `vardiya_hatirlatma_dk`, `vardiya_baslamadi_dk` yok; admin-web/lib/tesis-ayar-alanlari.ts:103-121 bu iki alanda `adminOnly` yok. Hata metni `yonetici_sinirli_alan_degistirir` (hata_metinleri) güncel değil.
- Sonuç: plandaki "vardiya hatırlatma (5 dk)" kademesi yönetici tarafından açılamıyor; varsayılan "15" (tek kademe). 15 dk kademesi ölçüldü, çalışıyor.
- Önerilen düzeltme: iki alanı `_YONETICI_YAZABILIR`'a ekle (P207 saha ayarı) ya da web'de `adminOnly: true`; hata metnini düzelt.

### BILDIRIM-04: Sakin panik butonu 500 veriyor — alarm KAYDEDİLMİYOR, kimseye gitmiyor
- Sınıf: Engelleyici
- Rol / yüzey: resident (kiraci, A-1) / API (`POST /panik`) → mobil panik düğmesi aynı ucu çağırır
- Adımlar: kiraci ile `POST /panik {"tip":"sakin","aciklama":"E2E sakin panik"}`
- Beklenen: 201, `beklemede` → 5 sn sonra güvenlik+amir+yönetici'ye `panik_alarm`.
- Olan: **500**; api log: `File "/app/app/routers/panik.py", line 142, in _govde` → `AttributeError: 'Unit' object has no attribute 'daire_no'`. İşlem geri alındığı için `panik_alarm` tablosunda satır YOK (0 satır), bildirim/push yok. (Aynı 500 başka ajanın tesisinde de api.log'da görünüyor.)
- Tekrarlanabilir: evet (dairesi olan her sakin — sakin paniğinde `unit_id` otomatik doldurulur, routers/panik.py:230-240)
- Şüpheli kök neden: `Unit` modelinde alan `no` (models.py:1549), `daire_no` yok. routers/panik.py:141 `out.daire_no = birim.daire_no` ve backend/app/panik_yayin.py:105 `f"{birim.blok or ''} {birim.daire_no}"` — ikisi de patlar (yayın tarafı da, API geçse bile, Celery görevinde düşerdi).
- Önerilen düzeltme: `birim.no` kullan (iki yerde) + dairesi olan sakinle uçtan uca test (şu anki testler `unit_id`siz alarm kuruyor olmalı).

### BILDIRIM-05: Kategorili panik alarmları (yangın, deprem, gaz, sağlık…) KRİTİK kanaldan değil GENEL kanaldan, sistem sesiyle gidiyor
- Sınıf: Ciddi
- Rol / yüzey: tüm alıcılar / backend push (FCM gövdesi)
- Adımlar: yönetici `POST /panik {"tip":"yonetici_anons","kategori":"yangin"}`; güvenlik `{"tip":"guvenlik","kategori":"guvenlik_tehdidi"}`.
- Olan: push_gonderim/worker.log kimliği `panik_kategori_yangin`, `panik_kategori_guvenlik_tehdidi` (notification.tip=panik_alarm ama mesaj_kimlik kategori). `kanal_sec("panik_kategori_yangin")` → `yonetio_genel_v2`, `ses_adi` → `"default"` (kodla doğrulandı). Kategorisiz `panik_alarm` ve `panik_yanlis_alarm` → `yonetio_kritik_v2` + `yonetio_bildirim.caf`.
- Beklenen: push_kanal.py:106-110 — "Duyulmayan bir panik bildirimi, hiç gönderilmemiş olanla AYNI ŞEYDİR"; kategori yalnız metni değiştirmeli, kanalı değil.
- Tekrarlanabilir: evet (kod yolu deterministik)
- Şüpheli kök neden: backend/app/panik_yayin.py:60-67 `kategori_kimligi()` push kimliğini `panik_kategori_<k>` yapıyor; notify.py:193-194 kanal/ses bu kimlikten seçiliyor; push_kanal.py `KRITIK_TIPLER` yalnız `panik_alarm` içeriyor (P243 §5c regresyonu).
- Önerilen düzeltme: `kanal_sec`/`ses_adi`'ye `panik_kategori_` öneki → KRİTİK kuralı (ya da dispatch'e ayrı `kanal_tip` parametresi); test_p207_push_kanal'a kategori vakası.

### BILDIRIM-06: ANONİM ankette oy, veritabanında kişiye bağlanabiliyor (xmin eşleşmesi)
- Sınıf: Ciddi (gizlilik / KVKK — "anonim" vaadi)
- Rol / yüzey: DB erişimi olan herkes (DBA, yedek alan, destek) / backend
- Adımlar: anonim anket (c29cb624…) → malik "A", kiraci "B" oyladı. `anket_oy.user_id` NULL ✔, `ck_anket_oy_anonim_kimliksiz` ✔, `audit_log`'a oy yazılmıyor ✔ (yalnız `anket_olustur`). AMA:
  `select k.user_id, s.metin from anket_oy o join anket_katilim k on k.xmin=o.xmin and k.anket_id=o.anket_id join anket_secenek s on s.id=o.secenek_id` → **Zeynep Malik = A, Can Kiracı = B** (2/2 doğru eşleşme).
- Beklenen: P237 §3 "anonimde kimlik veritabanında durmuyor".
- Olan: oy satırı ile katılım satırı AYNI işlemde yazılıyor (routers/anketler.py `oy_ver`: `db.add(AnketKatilim(...))` + `db.add(AnketOy(...))` tek flush) → aynı `xmin`; ayrıca `anket_oy.created_at` mikrosaniye hassasiyetinde ve sıra ile de eşlenebilir (katılım tablosunda damga yok ama erişim logu `POST /anketler/{id}/oy` zamanı var).
- Tekrarlanabilir: evet (vacuum/dump sonrası xmin kaybolabilir; canlı DB'de her zaman)
- Şüpheli kök neden: backend/app/routers/anketler.py:~355-368 (tek işlemde iki satır). 
- Önerilen düzeltme: oyu ayrı işlemde / kuyrukta, gecikmeli ve karıştırılmış (batch) yaz; `anket_oy.created_at`'i güne yuvarla ya da kaldır; ekran ve DB testine xmin kontrolü ekle.

### BILDIRIM-07: Anket hedef kitlesine personel seçilebiliyor, bildirim gidiyor ama personel OY VEREMİYOR (403) ve katılım paydasına sayılıyor
- Sınıf: Orta
- Rol / yüzey: yönetici (oluşturma) + security (oy) / API
- Adımlar: `POST /anketler {"hedef_roller":["resident","security"],"anonim":true,...}` → security'e `anket_acildi` bildirimi+push gitti; security `POST /anketler/{id}/oy` → 403 "Bu işlem için yetkiniz yok."; yanıtta `hedef_kisi: 9` (7 sakin + 2 güvenlik).
- Beklenen: hedef seçilebilen rol oy verebilmeli ya da hedef listesi yalnız oy verebilen rollerle sınırlanmalı.
- Tekrarlanabilir: evet
- Şüpheli kök neden: schemas.py:8119-8122 `ANKET_HEDEF_ROLLER` personel rollerini içeriyor; routers/anketler.py:72 `_OY_VEREN = require_role("resident")`.
- Önerilen düzeltme: ikisini hizala (tasarım "oy yalnız sakin" ise hedef listesini `resident` + sakin tipine indir, web/mobil çoklu seçimi buna göre).

### BILDIRIM-08: Vardiya hatırlatması / "başlamadı" uyarısı yazıldıktan sonra `GET /notifications` 500 — yönetim ve güvenlik için bildirim listesi tamamen çöküyor
- Sınıf: Engelleyici
- Rol / yüzey: yönetici, güvenlik_amiri, security, security2 (ve admin) / API → web `/notifications` ve mobil bildirim ekranı
- Adımlar: beat `vardiya_hatirlatma` ve `vardiya_baslamadi` satırlarını yazdıktan sonra (BILDIRIM-02 senaryosu) ilgili kullanıcılar `GET /notifications?limit=50`.
- Beklenen: 200 + liste.
- Olan: **500**. api log: `LookupError: 'vardiya_baslamadi' is not among the defined enum values. Enum name: notification_tip` (routers/notifications.py:196). Ölçüm: yonetici liste/okunmamış/arama 500; guvenlik_amiri, security, security2 liste 500 (sayfa bu satırı içermeyince 200 — ör. `okundu=false&limit=1` en yeni satır başka tipse). tesis_gorevlisi/sakinler 200 (satır onlara ait değil).
- Tekrarlanabilir: evet — varsayılan ayarlar (`vardiya_hatirlatma_dk="15"`, `vardiya_baslamadi_dk=15`) ile vardiya planı kullanan HER tesiste ilk hatırlatmadan sonra.
- Şüpheli kök neden: backend/app/models.py:80-131 `NOTIFICATION_TIP` ENUM'unda `vardiya_hatirlatma` ve `vardiya_baslamadi` YOK (DB enum'unda var; beat bunları ham SQL ile yazdığı için yazma tarafı hata vermiyor, ORM okuması patlıyor). Yeni tip eklerken model listesi güncellenmemiş.
- Önerilen düzeltme: iki değeri `NOTIFICATION_TIP`'e ekle; DB enum ↔ model enum eşitliğini test eden bir kilit testi (pg_enum ile karşılaştırma).

### BILDIRIM-09: Yönetim alarmları (user_id NULL) tek satır paylaşılıyor — bir güvenlik görevlisinin "okundu"su/silmesi yöneticinin bildirimini de okundu yapıyor/siliyor
- Sınıf: Orta
- Rol / yüzey: security, security2, guvenlik_amiri, yonetici / API + web + mobil
- Adımlar: (1) security2 `PATCH /notifications/{bakim_bugun id} {"okundu":true}` → yönetici ve güvenlik_amiri'nin "Okunmuş" sekmesinde görünür (DB `okundu=true`, tek satır). (2) yönetici `POST /notifications/toplu-sil` ile 4 `vardiya_baslamadi` satırını sildi → güvenlik_amiri listesinden de kayboldu (`silindi_at` dolu, tek satır).
- Beklenen: okundu/silme KİŞİYE ait olmalı — sakin_bildirimi.py:32-36'daki kendi ilke: "Tek satırı paylaştırsaydık bir kullanıcının okuması diğerininkini de okundu yapardı".
- Olan: `kacirilan_tur`, `vardiya_baslamadi`, `bakim_*`, `gurultu_eskalasyon_yonetim`, `gurultu_esik_yonetim`, `entegrasyon_koptu` gibi user_id NULL satırlar tüm yönetim gözünde tek durum taşıyor; rozet sayısı da buna göre düşüyor. Bir görevli "vardiyaya başlamadı" uyarısını okunmuş/silinmiş yaparak yöneticinin görmesini engelleyebilir.
- Tekrarlanabilir: evet
- Şüpheli kök neden: backend/app/routers/notifications.py:62-70 (`_kapsam` yönetim için `user_id IS NULL` satırlarını ortak veriyor) + :242-321 (PATCH / toplu-okundu / toplu-sil bu ortak satırı doğrudan günceller). Yazıcılar: scheduler/service.py:701, bakim_hatirlatma_isi.py:153, gurultu_akisi.py:347.
- Önerilen düzeltme: kişi başına okundu/silindi tablosu (`notification_okuma(user_id, notification_id)`) ya da yönetim alarmlarını da alıcı başına satır olarak yaz.

### BILDIRIM-10: Bazı olaylar yalnız push, kalıcı bildirim satırı YOK (bildirimi kaçıran listede bulamıyor)
- Sınıf: Orta
- Rol / yüzey: yönetici, tesis_gorevlisi, sakin / API (notification tablosu)
- Olan (ölçüldü, `notification` satırı 0, `push_gonderim` var):
  * `yeni_talep` (sakin talep açınca yöneticiye) — complaints.py:345-351
  * `is_emri_atandi` (talep iş emrine çevrilince atanan personele; ayrıca `gorev_atandi` da yazılmıyor) — complaints.py:448-458
  * iş emri görevi tamamlanınca OTOMATİK `talep_cozuldu` (sakine) — tasks.py:828 `notify_opener(...)` `db=` verilmeden çağrılıyor (elle çözmede satır yazılıyor)
  * `gurultu_uyarisi` (entegrasyonsuz yolda yöneticiye) — gurultu_akisi.py:303 (bekleyen uyarılar /gurultu-uyarilari'nda ayrıca görünüyor)
  * `duyuru`, `etkinlik` (içerikler kendi sayfalarında kalıcı; tasarım olabilir)
- Beklenen: P147 ilkesi "anlık push'un kalıcı ikizi" (sakin_bildirimi.py başlığı).
- Tekrarlanabilir: evet
- Önerilen düzeltme: bu çağrılara `sakin_bildirimi_yaz` ekle; tasks.py:828'e `db=db`.

### BILDIRIM-11: Mobil push'a dokununca yönlendirme eksik tipler (panik dahil)
- Sınıf: Orta
- Rol / yüzey: tüm roller / mobil (kodla doğrulandı; cihaz yok)
- Olan: `pushHedefi` (mobile/lib/src/routing/push_yonlendirme.dart:143-247) şu `data.tip` değerlerini tanımıyor → `null` → dokununca hiçbir ekran açılmıyor, ön planda SnackBar'da "Aç" yok: **`panik_alarm`**, `panik_yanlis_alarm`, `panik_kapandi`, `gorev_tamamlandi`, `gorev_adim_ilerleme`, `anket_acildi`, `bakim_yaklasti/bugun/gecikti`, `vardiya_yayinlandi`, `akilli_ev_kacak/yangin`, `entegrasyon_koptu`, `aidat_onizleme`, `aylik_ozet`, `gider_onay`. Aynı tiplerin çoğu uygulama içi listede (`bildirim_rotasi.dart`) yönlendiriliyor — iki tablo ayrışmış.
- Ayrıca `yeni_talep` push'u `data.tip="talep"` gönderiyor (complaints.py:350) — mobil bunu tanıyor, sorun yok.
- Tekrarlanabilir: evet (deterministik kod yolu)
- Önerilen düzeltme: iki yönlendirme tablosunu tek kaynağa bağla; panik için `AppRoutes.panikTakip?panik_id=`.

### BILDIRIM-12: Duyuruda hedef kitle seçimi YOK (A blok / malikler vb.) — duyuru herkese gidiyor
- Sınıf: Orta (plan maddesi karşılanmıyor)
- Rol / yüzey: yönetici / API + web (`/announcements`)
- Adımlar: `POST /announcements` şeması yalnız `baslik, govde, foto_key` (schemas.py:1830-1834); web formunda hedef alanı yok (announcements/page.tsx). Görselli duyuru oluşturuldu → push `kiraci, malik, malik2, malik_oturan, security, security2, tesis_gorevlisi, yonetici` (oluşturan yönetici de kendi duyurusunun push'unu alıyor).
- Beklenen: plan §7 "hedef kitle seçimi (yalnız A blok / yalnız malikler) — alıcı listesini doğrula".
- Olan: hedefleme hiç yok. docs/P244-kararlar.md:1647 "hedefleme kuralları P190 §3'te yönetim tarafında" diyor ama P190'da/kodda böyle bir kural yok (belge yanlış).
- Tekrarlanabilir: evet
- Önerilen düzeltme: anketteki `hedef_roller`/`hedef_sakin_tipi` desenini + blok seçimini duyuruya taşı; `dispatch_external`'da oluşturanı hariç tut.

### BILDIRIM-13: güvenlik_amiri ve denetçi duyuru / etkinlik / site kurallarını OKUYAMIYOR (403) ve duyuru push'u almıyor
- Sınıf: Orta
- Rol / yüzey: guvenlik_amiri, denetci / API (web `/announcements` app.* yüzeyinde bu roller için açık)
- Adımlar: `GET /announcements/{id}`, `GET /events`, `GET /site-rules` (guvenlik_amiri, denetci) → hepsi **403**; `GET /anketler` denetci → 403. Duyuru push hedefi `_ALL_ROLES` = admin,yonetici,security,tesis_gorevlisi,resident (guvenlik_amiri yok).
- Beklenen: güvenlik amiri personel duyurularını (ör. su kesintisi, tahliye tatbikatı) görmeli; denetçi (salt okuma) iletişim kayıtlarını okuyabilmeli.
- Şüpheli kök neden: routers/announcements.py:44-48 (`_READER`, `_ALL_ROLES`), events.py:67, site_rules.py:46.
- Önerilen düzeltme: `_READER`'lara `guvenlik_amiri` (+ denetçi için salt okuma), `_ALL_ROLES`'a `guvenlik_amiri`.

### BILDIRIM-14: Aidat hatırlatma metni "son ödeme: 22" — gün sayısı tarih gibi gösteriliyor
- Sınıf: Küçük
- Rol / yüzey: sakin (malik2) / push + uygulama içi liste
- Adımlar: yönetici `POST /finans/borclulara/hatirlat {"unit_ids":[A-2]}` (son ödeme 2026-09-01, 22 gün gecikmiş)
- Olan: `"₺1500.00 tutarında ödenmemiş borcunuz var (son ödeme: 22)."`; `mesaj_veri.vade = "22"`.
- Beklenen: "son ödeme: 01.09.2026" ya da "22 gün gecikmiş"; tutar Türkçe biçimde "₺1.500,00".
- Şüpheli kök neden: routers/finans_gosterge.py:~233 `params = {"tutar": _tl(...), "vade": str(daire.en_eski_gun)}` (en_eski_gun = yaş/gün); `_tl` (akis_metinleri) ondalık nokta ve binlik ayraçsız.
- Önerilen düzeltme: `vade`'ye gerçek tarih ver ya da şablonu "{gun} gündür gecikmiş" yap; `_tl`'yi yerel biçime çevir.

### BILDIRIM-15: Resend webhook "iletildi / geri döndü" durumu Davetler panelinde HİÇ görünmez; `okundu` durumu "Bekliyor"a geri düşer
- Sınıf: Orta
- Rol / yüzey: yönetici / web `/davetler` + backend webhook
- Adımlar: kendim Svix imzalı `email.delivered` / `email.bounced` gönderdim: imza geçerli → 200 `{"durum":"eslesmedi"}`; bozuk imza → 401; 10 dk eski zaman → 401; aynı svix-id tekrar → `{"durum":"tekrar"}`; bilinmeyen tür → 200 `yoksayildi`; imzasız → 401. (İmza/idempotency GEÇTİ.)
- Durum değişimi ÖLÇÜLEMEDİ: dev'de e-posta `log-eposta` sağlayıcısıyla gidiyor ve `mesaj_gonderim.saglayici_mesaj_id` hiçbir satırda dolu değil (tüm DB: 0) → webhook'un eşleyeceği satır yok.
- Kodla tespit: webhook yalnız `mesaj_gonderim.durum`u günceller (eposta_webhook.py son blok); Davetler paneli `GET /davet` ise `davet.son_durum` anlık kopyasını okur (routers/davet.py:273, davet.py:328 — yalnız gönderim anında yazılır). Yani bounce davet panelinde ASLA "Gönderilemedi"ye dönmez. Ayrıca web `durumBilgisi` (davetler/page.tsx:56-65) `iletildi`'yi "Gönderildi" ile aynı gösteriyor (ayrı "İletildi" etiketi yok) ve `okundu` durumunu hiç tanımıyor → "Bekliyor" (sarı) gösterir. Kullanıcı listesinde (`/users`) teslim durumu hiç yok. Yalnız `/mesajlar/gecmis` `mesaj_gonderim.durum`u gösteriyor.
- Önerilen düzeltme: webhook'ta `davet.son_durum/son_hata`'yı da güncelle (ya da panel `mesaj_gonderim`'e join etsin); `durumBilgisi`'ne `iletildi`→"İletildi", `okundu`→"Açıldı", `basarisiz`+`bounce`→"Geri döndü".

### BILDIRIM-16: Web bildirim araması hiç çalışmıyor (iki sekmede de) — BFF `q` parametresini düşürüyor
- Sınıf: Orta
- Rol / yüzey: yönetici / web `/notifications` (app.localhost:3000, hidrasyonlu — ortam düzeltmesinden SONRA yeniden ölçüldü)
- Adımlar: Okunmamış sekmesinde "gürültü", Okunmuş sekmesinde "bakım" yaz, 10 sn bekle.
- Beklenen: yalnız eşleşen satırlar (API doğrudan: okundu=true&q=bakım → 3 satır, q=gürültü → 1).
- Olan: liste süzülmüyor — "bakım" aramasında "Yanlış alarm", "Acil durum çağrısı", "Gürültü eşiği…" dahil 6 satırın tamamı (ekran: `$S/bildirim/ekran/c3-okunmus-arama.png`). api.log'da web'den gelen hiçbir `/notifications?...q=` isteği yok.
- Tekrarlanabilir: evet
- Şüpheli kök neden: admin-web/app/api/notifications/route.ts — GET yalnız `limit/offset/okundu`'yu backend'e taşıyor, `q` beyaz listede yok (mobil `q`'yu gönderiyor, notifications_controller.dart:31).
- Önerilen düzeltme: `const q = sp.get("q"); if (q) qs.set("q", q);`

### BILDIRIM-17: Bildirim ayarlarında TİP bazında kapatma yok (yalnız kanal: e-posta/SMS/mobil + ses)
- Sınıf: Öneri
- Rol / yüzey: tüm roller / API `/me/bildirim-tercihleri` + web profil + mobil ayarlar
- Ölçüm: `bildirim_mobil=false` (malik2) → sonraki `aidat_hatirlatma` için in-app satır YAZILDI, push GİTMEDİ (`push_gonderim`: `hedef_yok / tercih_kapali`) ✔. `bildirim_sesi=false` → kanal `yonetio_sessiz_v2` (kodla, notify.py:193). Ama "gürültü uyarısını kapat, aidatı açık tut" gibi tip bazında tercih yok; Android kanal ayarları (sistem) dışında yol yok.
- Karar: P167 §1.7 kanal başına tercih olarak tasarlanmış; plan "tip kapatılabiliyor mu" sorusu → HAYIR.

### BILDIRIM-18: Küçük metin/dil kusurları
- Sınıf: Küçük
- `panik_kapandi`: "Ayşe Yönetici için açılan alarm kapatıldı — -" (alarmı Ayşe AÇTI, "için" yanlış; konum yoksa "— -" kalıyor). `panik_yanlis_alarm`: "Ali Güvenlik alarmı geri aldı — -". (push_metinleri.py; `yer` "-" iken ek atlanmalı)
- Giriş kodu e-postası `Accept-Language: en` ile istendiğinde de Türkçe (eposta_sablonlari.py:10 "şimdilik yalnız Türkçe" — bilinçli karar; davet e-postası 7 dilde ✔).
- Davet "yeniden gönder" (`POST /davet/{id}/yeniden`) ilk davetin dilini (ar) korumuyor ve `Accept-Language`'i yok sayıyor → Türkçe gidiyor.
- Anket aynı metinli iki seçeneği kabul ediyor ("Evet","Evet" → 201).
- `PATCH /tenant/settings` 403 metni "Yönetici yalnız tesis adını ve hava konumunu değiştirebilir." eskimiş.
- Kargo, daireye bağlı OTURMAYAN malike de gidiyor (A-1: kiraci + malik); gürültüde "oturan kişi" kuralı uygulanırken kargoda değil (Öneri).
- Davet/aktivasyon bağlantısıyla hesabını açan kullanıcıların `eposta_dogrulandi` değeri false kalıyor (e-posta sahipliğini kanıtladıkları halde).

### BILDIRIM-19 (ortam notu, bulgu değil)
- app.localhost:3000 başlangıçta `.next` bozulduğu için JS 404 veriyordu; ana ajan yeniden başlattı. Web ölçümleri (rozet, sekme, toplu işlem, arama) düzeltme SONRASI 3000'de yeniden yapıldı. Aşırı yük (load avg 50-100) nedeniyle işlemler 4-6 sn sürüyor.
