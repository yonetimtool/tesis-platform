# P213 — gürültü eşiği ayarı, kamera görüntüleme ve kayıt

## §1 — Gürültü eşikleri yönetici ayarında

### ÖLÇÜM — biri eksikti, üçü SESSİZCE bozuktu
| Ayar | Şema | `_to_settings` (GET) | Yönetici yazabilir mi |
|---|---|---|---|
| `gurultu_esigi` | ✅ | ✅ | ✅ |
| `gurultu_pencere_gun` | ✅ (P208) | ❌ **yok** | ❌ **403** |
| `gurultu_susma_gun` | ✅ (P208) | ❌ **yok** | ❌ **403** |
| `gurultu_sakin_uyarisi` | ✅ (P208) | ❌ **yok** | ❌ **403** |
| eskalasyon eşiği | ❌ **yok** (kod sabiti `asama >= 2`) | — | — |

İkinci sütun sessiz bir kusurdu: `TenantSettings` şeması alanları
tanımlıyor ama `_to_settings` doldurmuyordu → **GET her tesiste şema
varsayılanını dönüyordu** (30/7/true), yani ekran gerçek değeri hiç
göstermemişti. P165'te birebir aynı sınıf ölçülmüş ve o zaman
`rezervasyon_gecmis_ay` için not düşülmüştü — aynı tuzağa üç alan daha
düşmüş.

Web tarafında alanlar **zaten çizilmişti** (`lib/tesis-ayar-alanlari.ts`);
yani arayüz vardı, sunucu tarafı eksikti. Kullanıcının gördüğü şey
"değiştiriyorum ama değişmiyor"du.

### KARAR K1.1 — Dört ayar da yöneticide, dördü de yanıtta
`_YONETICI_YAZABILIR` kümesine ve `_to_settings`e eklendi. Gerekçe P37/P34
ile aynı: eşiği ve pencereyi **komşuluk ilişkisini bilen kişi** ayarlar;
platform operatörüne bırakmak her değişikliği destek talebine çevirirdi.

### KARAR K1.2 — Eskalasyon eşiği ayar oldu (göç 0105)
`gurultu_eskalasyon_esigi` (1..10, varsayılan **1**): N. eşik aşımından
**sonraki** her aşımda güvenliğe gider. Varsayılan 1 ⇒ ikinci 5'te —
P212'nin bugünkü davranışı **aynen** korunur.

**Neden 0 yok:** "her uyarıda güvenliği çağır" demek olurdu ve birinci
eşiğin anlamını silerdi. **Neden üst sınır 10:** daha büyüğü pratikte
"hiç çağırma"dır ve bunu ifade etmenin doğru yolu ayrı bir açma/kapama
anahtarıdır, kocaman bir sayı değil.

### KARAR K1.3 — Eşik 1: **uç reddetmez, arayüz uyarır**
İstek "1 yaparsa kullanılamaz hale gelir; uyar" diyordu. Eşiği 1'de
yasaklamadım: küçük bir sitede bu **bilinçli** bir tercih olabilir ve 422
dönmek meşru bir kullanımı imkânsız kılardı. Bunun yerine alan 1 olunca
ipucu satırı **uyarıya** dönüşüyor: *"Eşik 1: her gürültü şikâyetinde
daireye uyarı gider… 3 ve üzeri önerilir."* (7 dil)

### KARAR K1.4 — Değişiklikler denetime
Bu ayarlar paraya değil **bildirime** dönüşüyor: eşiği 1 yapan her
şikâyette daireye anons gönderir, eskalasyon eşiğini düşüren güvenliği
daha sık çağırır. "Kim ne zaman değiştirdi" bir anlaşmazlıkta sorulacak
ilk sorulardan. Denetim kaydı **eski + yeni** değerleri taşır ve yalnız
**gerçekten değişen** alanlar için yazılır.

Sınırlar üç yerde **aynı**: Pydantic `Field`, DDL `CHECK`, web alan
tablosu. Tesis bazında — testle kilitli (A'nın eşiği B'yi etkilemiyor).

### Kilit
Backend 7 test (dördü de yanıtta; yönetici değiştirebiliyor ve yanıt
**gerçek** değeri dönüyor; 7 geçersiz değer 422; eşik 1 kabul; denetim
kaydı; tesis izolasyonu; denetçi 403) + eskalasyon eşiğinin **gerçekten
kullanıldığı** (eşik 2 → üçüncü aşımda eskalasyon) P212 dosyasına eklendi.
Web 2 DOM testi (alan çizilir ve gönderilir; eşik 1'de uyarı görünür).
Göç geri alınabilir — downgrade→upgrade koşuldu.

---

## §2 — RTSP canlı yayın açılmıyordu: kök neden **MediaMTX API yetkisi**

### ÖLÇÜM — zinciri sırayla sürdüm
```
1) GET  http://mediamtx:9997/v3/paths/list      -> 401     ← KIRILMA NOKTASI
2) POST /v3/config/paths/add/cam<id>            -> 401
3) backend bunu "yol zaten var" sanıp PATCH     -> 401 (sonucu OKUNMUYOR)
4) GET  /cam<id>/index.m3u8                     -> 404 (yol hiç oluşmadı)
5) kullanıcı: "Canlı yayın henüz hazır değil"
```

MediaMTX 1.9'un **gömülü varsayılan** `authInternalUsers` ayarında iki iç
kullanıcı var:
* `any` → publish/read/playback (her IP)
* `any` → **api**/metrics/pprof ama **yalnız `ips: [127.0.0.1, ::1]`**

`api` servisi geçide docker ağının IP'siyle (172.x) bağlandığı için **her
API çağrısı 401** alıyordu.

**Kare neden çalışıyordu:** ızgaradaki kareyi ffmpeg **kameradan
doğrudan** çekiyor; MediaMTX'e hiç uğramıyor. Kullanıcının gözlemi
("kare var, canlı yok") bu ayrımın birebir yansıması.

### KARAR K2.1 — `infra/mediamtx.yml` (dosya, ortam değişkeni değil)
`api` izni özel ağ aralıklarına (`10/8`, `172.16/12`, `192.168/16`) +
yerel döngüye açıldı. **API portu dışarı açılmıyor** (compose'da `ports`
yok): özel ağ aralığını yetkilendirmek, API'yi internete açmak değildir.

Önce `MTX_AUTHINTERNALUSERS_1_IPS=…` ortam değişkeni denendi ve **etki
etmedi** (401 sürdü) — liste öğelerini env ile ezmek bu sürümde güvenilir
değil. Dosya hem çalışıyor hem kararı **okunur** kılıyor.

### KARAR K2.2 — Yetki hatası artık **yutulmuyor**
Eski kod POST'un 4xx'ini idempotent kabul edip PATCH deniyor, **onun
sonucunu hiç okumuyordu**. Artık:
* **401/403** → `kamera_gecit_yetkisiz` ("sunucudaki mediamtx
  yapılandırması düzeltilmeli") — çünkü düzeltilecek yer kamera değil;
* `"already exists"` içeren 4xx → **normal**, idempotent kayıt;
* başka 4xx/5xx → `kamera_gecit_yapilandirma` + gövde loglanır.

Böylece dört durum dört ayrı cümle: geçide **ulaşılamıyor** /
geçit **reddetti** / geçit **yolu kaydedemedi** / **yayın hazır değil**.
Dördünü tek mesaja indirmek, yöneticiyi yanlış yere gönderiyordu.

### ÖLÇÜM — zincirin tamamı sentetik bir yayınla sürüldü
Gerçek kamera yok; bu yüzden ikinci bir MediaMTX konteynerini "kamera"
yapıp ffmpeg ile test deseni yayınladım:

```
paths/add            -> 200
index.m3u8 (geçit)   -> 200  (varyant playlist)
main_stream.m3u8     -> 200
BACKEND VEKİLİ:
  /cameras/{id}/canli/index.m3u8       -> 200
  /cameras/{id}/canli/main_stream.m3u8 -> 200
  /cameras/{id}/canli/<seg>.ts         -> 200, 59 784 bayt gerçek video
```

Segment adı `e251157e82b2_main_seg0.ts` — vekildeki dosya deseni
(`^[A-Za-z0-9._-]+\.(m3u8|ts|mp4)$`) bunu kabul ediyor; iki kademeli
playlist (index → main_stream → segment) vekilden ayrı istekler olarak
geçiyor.

**Dev'de canlı izleme artık açık:** `infra/.env`e `MEDIAMTX_URL` ve
`MEDIAMTX_API_URL` eklendi — kök neden ancak zincir çalışırken ölçülebilir.

### Kilit
10 test: dört geçit hatasının **ayrı ayrı** metinleri (7 dil, dördü de
birbirinden farklı ve yetki hatası "sunucu" diyor), 401/403 → ayrı kimlik,
"already exists" → hata değil, başka 4xx → hata, 5 gezinti denemesi 404.
Kırma denemesi: 401 dalı devre dışı bırakıldığında tam olarak o iki test
düştü.

### Ölçemediğim
**Gerçek kamerayla prod**. Prod'da `mediamtx.yml` mount edilene kadar API
401 dönmeye devam eder — dağıtımda `infra/mediamtx.yml` sunucuya
gitmeli ve `docker compose up -d mediamtx` ile yeniden oluşturulmalı.
