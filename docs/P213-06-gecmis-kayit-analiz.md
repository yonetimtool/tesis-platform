# P213 §6 — Geçmiş kayıt izleme (NVR/DVR): ANALİZ

> **Bu belge yalnız analizdir. Kod yazılmadı.** Talep gereği öneri sunulup
> onay bekleniyor. Kapsam: **YALNIZ WEB** (mobil bu tur kapsam dışı).

---

## 0. Şu an elimizde ne var (ölçülmüş durum)

| Parça | Durum |
|---|---|
| `camera.stream_url` | Kameranın/NVR'ın **canlı** RTSP ya da HLS adresi. Parola adresin içinde, **düz metin** saklanıyor. |
| `camera.restream_url`, `snapshot_url` | Geçit yayını ve tek kare adresleri (P17/P121). |
| Canlı zincir (P213 §2) | `api` → MediaMTX (`sourceOnDemand`) → HLS → backend vekili → tarayıcı. Rol kapısı **vekilde**. |
| Kare zinciri (P213 §3) | `api` → ffmpeg → tek JPEG. Kameraya **doğrudan** gider, MediaMTX'e uğramaz. |
| `app/crypto.py` | KEK/AES-GCM ile at-rest şifreleme **zaten var** (entegrasyon sırları bununla saklanıyor). |
| `app/anpr.py` | Hikvision ISAPI ve Dahua olay yükleri için **hâlihazırda satıcıya dokunan kod** var. |

Yani "geçit üzerinden HLS yayınla + rol kapısını vekilde tut" deseni kurulu.
Geçmiş kayıt bu desenin **kaynağı değiştirilmiş** hâli olabilir.

---

## 1. Dört yol ve gerçek maliyetleri

### A) ONVIF Profile G (standart: Recording Search + Replay)
Cihazda `RecordingSearch` servisi `FindRecordings`/`FindEvents` ile hangi
aralıklarda kayıt olduğunu döndürür; `Replay` servisi `GetReplayUri` ile
zaman aralıklı bir **RTSP** adresi verir (`Range: clock=...`, hızlandırma için
`Scale`).

- **Artı:** markadan bağımsız tek kod yolu; zaman çizelgesi (hangi aralıkta
  kayıt var) **standart** biçimde gelir.
- **Eksi:** Profile **S** (canlı) neredeyse her cihazda var; Profile **G**
  yok. Ucuz/çin menşeli NVR'ların bir kısmı G'yi ya hiç desteklemiyor ya da
  eksik uyguluyor (FindRecordings boş döner, GetReplayUri çalışır — ya da
  tersi). **Cihaz cihaz doğrulanması gereken bir şey; katalogdan garanti
  edilemez.**

### B) Satıcı API'leri (Hikvision ISAPI / Dahua CGI)
- **Hikvision:** `POST /ISAPI/ContentMgmt/search` (XML `CMSearchDescription`)
  → sonuçta `playbackURI` (`rtsp://.../Streaming/tracks/101?starttime=...&endtime=...`).
  İndirme için `/ISAPI/ContentMgmt/download`.
- **Dahua:** `/cgi-bin/mediaFileFind.cgi` (`factory.create` → `findFile` →
  `findNextFile`) ve oynatma `rtsp://.../cam/playback?channel=1&starttime=...`;
  indirme `loadfile.cgi`. Kimlik doğrulama **Digest**.
- **Artı:** bu iki marka Türkiye'deki sitelerin ezici çoğunluğu; API'leri
  ONVIF G'den daha güvenilir çalışıyor.
- **Eksi:** iki ayrı ağız, sürüm sürüm değişen ayrıntılar, belgelenmemiş
  davranışlar. Üçüncü bir marka gelince üçüncü adaptör.

### C) Adres şablonu (arama yok, doğrudan oynatma)
Kullanıcının seçtiği zaman aralığını satıcı şablonuna yazıp doğrudan RTSP
açmak. **Artı:** en az kod. **Eksi:** "hangi saatlerde kayıt var" bilinmez;
kayıt olmayan aralıkta kullanıcı boş ekran görür ve bunun hata mı, kayıt
yokluğu mu olduğunu ayırt edemez. Tek başına yetersiz, ama **B'nin arama
ayağı çalışmadığında geri düşüş** olarak değerli.

### D) Kaydı BİZ tutalım (MediaMTX `record` + `playback` sunucusu)
MediaMTX canlı yayını zaten çekiyor; `record: yes` ile parçalara ayırıp
diske yazabilir, gömülü `playback` sunucusu hangi parçaların olduğunu
listeler ve zaman aralığıyla servis eder.

- **Artı:** **markadan tamamen bağımsız**, tek kod yolu, zaman çizelgesi
  bizde, NVR'a hiç bağlanmıyoruz.
- **Eksi — ve bu belirleyici:** 24/7 kayıt **bizim** diskimizi ve **bizim**
  bant genişliğimizi yer. Kaba hesap: 2 Mbit/s'lik tek kamera ≈ **21 GB/gün**,
  **650 GB/ay**. 8 kameralı bir site 30 gün saklama isterse ≈ **5 TB**. Site
  zaten yerinde 30 gün kayıt tutan bir NVR'a **para vermiş** durumda; aynı
  veriyi ikinci kez buluta taşımak, hem faturayı hem KVKK yüzeyini ikiye
  katlamak demek.

---

## 2. Belirleyici kısıt: NVR bizim sunucumuza açık mı?

Bu, kod kararından **önce** gelen soru.

- Kayıtlar sitedeki NVR'da, **özel ağda**. Bizim `api` konteynerimiz başka
  bir yerde. Aradaki yol açılmadan hiçbir yaklaşım (A/B/C) çalışmaz.
- **Aynı kısıt canlı yayında da var** ve bugün zaten karşılanıyor: canlı
  çalışan bir sitede `stream_url` sunucudan erişilebilir demektir (port
  yönlendirme ya da VPN kurulmuş). Yani geçmiş kayıt **yeni bir ağ şartı
  getirmiyor** — aynı yolu, çoğu zaman **aynı portu** kullanır.
- **Getirdiği yeni şey:** arama/HTTP API'si genelde **80/443** (ISAPI, CGI,
  ONVIF), RTSP ise **554**. Yani bugün yalnız 554'ü yönlendirmiş bir sitede
  **ikinci bir port** gerekecek. Bunu kullanıcıya "ikinci port aç" diye
  söylemek kötü bir deneyim; alternatifi (C) ile yalnız 554 üzerinden
  aramasız oynatma.
- **Güvenlik:** NVR'ı internete açmak ciddi bir risktir (bu cihazların
  güvenlik geçmişi kötü). Önerimiz kullanıcıya **VPN/site-to-site** ya da
  **yerinde küçük bir geçit** olacak; ama bu tur bunu **zorunlu kılmıyor**,
  yalnız belgeliyor.

---

## 3. Kimlik bilgisi: bugünkü durum bir açık

`stream_url` içinde `rtsp://kullanici:parola@...` **düz metin** duruyor.
Geçmiş kayıt için NVR'ın **yönetim** hesabı gerekecek (arama API'si), yani
daha değerli bir sır. Öneri:

1. Kameraya/NVR'a ait `kayit_kullanici` + `kayit_parola` **ayrı alanlar**,
   parola `app/crypto.py` ile **şifreli** (desen mevcut, yeni altyapı yok).
2. GET yanıtlarında **asla dönmez** (entegrasyon sırlarındaki `write-only`
   kuralı).
3. Kullanıcıya **salt-okunur NVR hesabı** açması söylenir (Hikvision/Dahua
   ikisinde de operatör rolü var).
4. Fırsat maddesi: `stream_url` içindeki parolayı da aynı alana taşımak —
   **bu turun kapsamı dışı**, ama not düşülüyor.

---

## 4. KVKK / denetim — atlanmaması gereken

Canlı izleme anlıktır; **geçmiş kayıt izleme geriye dönük gözetimdir** ve
KVKK açısından ağırdır. Öneri: her oynatma isteği **denetim kaydına** yazılsın
(kim, hangi kamera, hangi zaman aralığı, ne zaman). Bu, kodun en ucuz ama
en değerli parçası; sonradan eklemek zor.

Erişim: **yalnız yönetici**. `sakin_gorebilir` bayrağı **canlı** içindir;
geçmiş kayda sakin/görevli erişimi **açılmamalı** (ayrı bir bayrak bile
önermiyorum — istenirse ayrıca konuşulur).

---

## 5. ÖNERİ

**Adaptör arkasında B + C, ONVIF (A) sonraya, D reddedilsin.**

Tek bir arayüz:

```
KayitSaglayici:
    araliklari_listele(kamera, bas, bit) -> [(bas, bit), ...]   # zaman çizelgesi
    oynatma_adresi(kamera, bas, bit)     -> rtsp://...          # geçide verilecek
```

- **`hikvision`** ve **`dahua`** adaptörleri (sahadaki kameraların pratikte
  tamamı) — arama + oynatma.
- **`sablon`** adaptörü: arama yok, yalnız oynatma (C). Arama API'si
  kapalı/erişilemez sitelerde geri düşüş.
- **`onvif`** adaptörü **sonraki tur**: standart olması cazip ama sahada
  güvenilmez; iki satıcı adaptörü çalışırken eklemek düşük risk, önce
  eklemek yüksek risk.
- **D (kendi kaydımız) reddediliyor:** maliyet gerekçesi §1.D'de. İleride
  "NVR'ı olmayan küçük site" senaryosu gelirse ayrı bir ürün kararı olarak
  yeniden açılır.

**Oynatma zinciri canlıyla AYNI olur** (yeni altyapı yok):
`adaptör → zaman aralıklı RTSP → MediaMTX yolu → HLS → backend vekili → tarayıcı`.
Rol kapısı zaten vekilde; bant genişliği sunucumuzdan geçer (tarayıcı NVR'a
doğrudan bağlanamaz — RTSP'yi oynatamaz ve parolayı istemciye vermek
kabul edilemez).

**Web arayüzü:** kamera seç → gün seç → **kayıt olan aralıkları gösteren
şerit** → şeride tıkla → oynat. Şerit, "kayıt yok" ile "bağlanamadım"
arasındaki farkı görünür kılar (bu ayrımın yokluğu C'nin tek başına
yetersiz olma sebebi).

**Bölünme (onay verilirse):**
1. Model + göç (`kayit_saglayici`, `kayit_adres`, `kayit_kullanici`,
   şifreli `kayit_parola`) + kameralar formu.
2. Adaptör arayüzü + `sablon` + **testler** (taklit HTTP adaptöründe —
   P200 dersi).
3. `hikvision` adaptörü + testler.
4. `dahua` adaptörü + testler.
5. Uçlar (`GET /cameras/{id}/kayit/araliklar`, `POST .../kayit/oynat`) +
   denetim kaydı + rol kapısı.
6. Web ekranı (şerit + oynatıcı) + testler.

**Ölçemeyeceğim şey — açıkça söylüyorum:** elimde gerçek bir Hikvision/Dahua
NVR **yok**. Adaptörleri satıcı protokolüne göre yazıp taklit HTTP
adaptörüyle **birebir istek/yanıt** düzeyinde ölçebilirim; ama "gerçek
cihazda çalışıyor" iddiasını **sizin sahada denemeniz** olmadan kuramam.
Bunu baştan planlayalım: adaptörler ayrıntılı hata günlüğü yazsın ki ilk
gerçek cihaz denemesi teşhis edilebilir olsun (P213 §2'de 401'i bulan şey
tam olarak buydu).

---

## 6. Onayınızı beklediğim noktalar

1. Öneri (B+C şimdi, A sonra, D red) kabul mü?
2. Kimlik bilgisi için ayrı şifreli alanlar + salt-okunur NVR hesabı tavsiyesi
   uygun mu?
3. Geçmiş kayıt **yalnız yöneticiye** açık kalsın mı?
4. Sahada deneyebileceğiniz bir NVR var mı, varsa **marka/model**?
