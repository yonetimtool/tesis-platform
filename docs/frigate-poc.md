# Frigate PoC — bulgular + ANPR ingest olay şeması taslağı (P15)

> Koşum: 2026-07-30 · Frigate **0.17.2** (`ghcr.io/blakeblackshear/frigate:stable`)
> · go2rtc 1.9.10 · dev makine: 8 çekirdek / 15,6 GB RAM · **prod compose'a
> DOKUNULMADI** (ayrı yığın: `infra/frigate-poc/`).

## 1. Yeniden koşulabilir kurulum

```bash
docker compose -f infra/frigate-poc/docker-compose.yml up -d
# Arayüz:      http://localhost:15000
# go2rtc:      http://localhost:18984
# MQTT:        localhost:11883
docker compose -f infra/frigate-poc/docker-compose.yml down     # -v KULLANILMAZ
```

Üç servis:

| Servis | Ne yapar | Neden |
|---|---|---|
| `kaynak` | mediamtx + ffmpeg → **sentetik RTSP** yayını (`rtsp://kaynak:8554/kapi`) | PoC gerçek kamera GEREKTİRMEDEN koşabilsin |
| `mqtt` | mosquitto | Frigate olayları buraya yayınlar |
| `frigate` | go2rtc restream + dedektör + HTTP API | ölçülen asıl bileşen |

Yapılandırma `infra/frigate-poc/config/config.yml`. Kritik nokta: Frigate
kameranın RTSP'sini **doğrudan** tüketmiyor, **kendi go2rtc restream'ini**
tüketiyor (`preset-rtsp-restream`) — böylece kaynağa **TEK bağlantı** açılır.
Gerçek sahada kameraların eşzamanlı bağlantı limiti (çoğu ucuz IP kamerada
2–4) bu yüzden önemlidir.

## 2. Ölçülen: akış yolu ve restream

**go2rtc restream ÇALIŞIYOR ve oynatılabilir** — `rtsp://frigate:8554/kapi`
ffprobe ile doğrulandı:

```
h264 / Constrained Baseline / 1280x720 / 10 fps / yuv420p / avc1.42c01f
```

Bu **P17'nin temel taşı**: mobil oynatıcı kameraya doğrudan bağlanmaz, bu
restream'e bağlanır. Kamera kaydı `restream_url` alanı kazanınca oynatıcı onu
kullanacak.

URL biçimleri (PoC'ta doğrulandı):

| Amaç | URL |
|---|---|
| RTSP restream | `rtsp://<host>:8554/<kamera>` |
| go2rtc API (WebRTC/HLS üretimi) | `http://<host>:1984/api/streams` |
| Anlık kare | `http://<host>:5000/api/<kamera>/latest.jpg` |
| Olay fotoğrafı | `http://<host>:5000/api/events/<id>/snapshot.jpg` |
| Olay listesi | `GET http://<host>:5000/api/events?limit=N` |

## 3. Ölçülen: olay akışı (MQTT + HTTP)

70 sn'lik `frigate/#` aboneliğinde **yakalanan konular**:

```
frigate/available                      online
frigate/stats                          {camera_fps, process_fps, detection_fps,
                                        detectors{inference_speed}, service{...}}
frigate/model_state                    (model yükleme durumu)
frigate/kapi/status/detect             online
frigate/kapi/<anahtar>/state           enabled|detect|motion|recordings|snapshots|
                                       audio|improve_contrast|ptz_autotracker|
                                       birdseye|motion_threshold|motion_contour_area|
                                       review_alerts|review_detections|
                                       review_descriptions|object_descriptions
```

Yani her kamera için **switch/durum konuları** var — bunlar bizim için de
kullanışlı: "kamera çevrimdışı" alarmı `frigate/<kamera>/status/detect` ve
`frigate/available` ile kurulabilir, ayrı bir yoklamaya gerek yok.

**Olay konusu yakalandı** (`frigate/events` yerine 0.17'de `frigate/reviews`
üzerinden "review" nesnesi de yayınlanıyor). PoC'ta olay
`POST /api/events/kapi/car/create` ile **tetiklendi** ve tam yükü kaydedildi:

```jsonc
// frigate/reviews  (type: update)
{
  "type": "update",
  "before": { ... }, "after": {
    "id": "1785450578.367615-qjitj2",
    "camera": "kapi",
    "start_time": 1785450578.367615,     // UNIX float (saniye)
    "end_time": null,                     // devam ediyor
    "severity": "alert",
    "thumb_path": "/media/frigate/clips/review/thumb-kapi-....webp",
    "data": {
      "detections": ["1785450578.367615-mhjk2h"],   // olay id'leri
      "objects": ["car"],
      "verified_objects": [], "sub_labels": [], "zones": [],
      "audio": [], "thumb_time": null, "metadata": null
    }
  }
}
```

```jsonc
// GET /api/events?limit=1
{
  "id": "1785450578.367615-mhjk2h",
  "camera": "kapi",
  "label": "car",
  "sub_label": null,            // <- PLAKA METNI BURAYA gelir (LPR)
  "zones": [],
  "start_time": 1785450573.367615,
  "end_time": 1785450583.367615,
  "has_clip": false, "has_snapshot": true,
  "top_score": null, "false_positive": false,
  "box": [],                    // [x, y, w, h] normalize kutu
  "data": { "type": "api", "score": 0, "top_score": 0 }
}
```

## 4. LPR: yapılandırma doğrulandı, TESPİT ÖLÇÜLEMEDİ

`lpr.enabled: true` geçerli kabul edildi ve çözümlenmiş varsayılanları API'den
okundu:

```jsonc
"lpr": { "enabled": true, "model_size": "small",
         "detection_threshold": 0.7,     // plaka KUTUSU eşiği
         "recognition_threshold": 0.9,   // OKUNAN METİN eşiği
         "min_plate_length": 4, "min_area": 1000,
         "known_plates": {},             // ad -> plaka listesi eşlemesi
         "match_distance": 1,            // 1 karakterlik OCR toleransı
         "replace_rules": [], "enhancement": 0 }
```

**Kritik mimari bulgu:** dedektör modelinin `attributes_map`'ine göre

```
"car":        [..., "license_plate", ...]
"motorcycle": ["license_plate"]
```

yani **`license_plate` bağımsız bir nesne değil, `car`/`motorcycle`'ın
ÖZNİTELİĞİ**. Sonuç: *plaka okumak için önce ARAÇ tespit edilmelidir.* Kamera
açısı aracın gövdesini görmüyorsa (yalnız plakaya zoom yapılmışsa) LPR
çalışmaz. Bu doğrudan **P18'in kamera-açısı kılavuzuna** girer.

> **ÖLÇÜLEMEYEN — dürüst kayıt:** PoC sentetik bir test deseni yayınlıyor;
> içinde araç YOK, dolayısıyla gerçek bir `car` tespiti ve gerçek bir plaka
> okuması **elde edilmedi** (`detection_fps: 0.0`). Olay boru hattı manuel
> olayla uçtan uca doğrulandı, ama **LPR doğruluğu ölçülmedi**. Gerçek ölçüm
> için sahadan/örnek videodan araç görüntüsü gerekir → **P18 (pilot saha)**.

## 5. Kaynak tüketimi (tek kamera, 1280×720 @ 5 fps tespit)

| Konteyner | CPU | RAM |
|---|---|---|
| `fpoc-frigate` | **%17,1** | 972 MiB |
| `fpoc-kaynak` (sentetik yayın — sahada YOK) | %28,1 | 77 MiB |
| `fpoc-mqtt` | %0,05 | 8 MiB |

Dedektör: `cpu1` (TFLite SSD 320×320), **inference_speed ≈ 10 ms/kare**.
`/dev/shm` kullanımı: 21,4 MB / 128 MB; Frigate'in kendi hesabına göre
`min_shm: 146 MB` (kare boyutu 4,8 MB × 16). **Not: `shm_size: 128mb` bu tek
kamera için bile SINIRDA** — çok kameralı kurulumda `shm_size` kamera başına
büyütülmeli.

Kaba çıkarım (ölçüme dayalı, ekstrapolasyon olduğu açık): 8 çekirdekli bir
mini PC'de CPU dedektörle **~5–6 kamera** 5 fps tespitle sığar. Coral TPU
inference'ı ~10 ms'den ~8 ms'e indirmez — **CPU'yu tamamen boşaltır**
(inference GPU/TPU'ya gider), asıl kazanç odur. Kamera sayısı 4'ü aşıyorsa
Coral **önerilir**, altında **isteğe bağlı**.

## 6. ANPR ingest olay şeması TASLAĞI (P16 girdisi)

Uç **kaynaktan bağımsız** olmalı: Frigate, Hikvision (ISAPI), Dahua ve elle
giriş aynı gövdeye çevrilir. Frigate'in yukarıdaki yükü bu şemaya şöyle
eşlenir:

```jsonc
POST /integrations/anpr/events
X-ANPR-Key: <tenant başına API anahtarı>
{
  "kaynak": "frigate",             // frigate | hikvision | dahua | manuel
  "kaynak_olay_id": "1785450578.367615-mhjk2h",  // ISTEMCIDEN — idempotency
  "plaka": "34 ABC 123",           // sunucu NORMALIZE eder (mevcut norm_plaka)
  "zaman": "2026-07-30T21:09:33Z", // Frigate UNIX float -> ISO8601 UTC
  "kamera": "kapi",                // tenant içinde kamera kimliği/adı
  "yon": "giris",                  // giris | cikis | bilinmiyor
  "guven": 0.93,                   // 0..1 — LPR recognition score
  "foto_ref": "/api/events/<id>/snapshot.jpg",  // ya da presign'lı obje anahtarı
  "ham": { }                       // kaynağın ham yükü (denetim/hata ayıklama)
}
```

Eşleme notları (Frigate → şema):

| Şema alanı | Frigate karşılığı | Not |
|---|---|---|
| `kaynak_olay_id` | `event.id` | **idempotency anahtarı** — aynı olay iki kez gelirse ikincisi yok sayılır. Frigate `update` + `end` olarak İKİ KEZ yayınlar. |
| `plaka` | `event.sub_label` | LPR sonucu buraya yazılır; `null` ise plaka okunamamış → olay **atılır** ya da "bilinmeyen araç" olarak işlenir |
| `zaman` | `event.start_time` | UNIX float saniye → ISO8601 |
| `kamera` | `event.camera` | tenant'ta kamera eşlemesi tablo/ayar ile |
| `guven` | `event.top_score` / LPR skoru | eşik **tenant başına** yapılandırılabilir olmalı |
| `yon` | **Frigate VERMEZ** | zone geçiş sırasından (`zones`) türetilir → kamerada `giris_zone`/`cikis_zone` tanımlanmalı |
| `foto_ref` | `/api/events/<id>/snapshot.jpg` | ingest sırasında çekilip MinIO'ya kopyalanmalı (Frigate saklama süresi kısa) |

**`yon` alanı en kritik tasarım noktası:** Frigate yön bilgisi üretmez.
İki seçenek var — (a) kamera başına sabit yön ("bu kamera giriştir"),
(b) Frigate zone'ları ile geçiş sırası. (a) basit ve tek yönlü kapılarda
doğrudur; (b) tek kameralı çift yönlü geçitler için gerekir. **P16'da (a) ile
başlanması, şemanın (b)'yi taşıyacak şekilde bırakılması öneriliyor.**

## 7. P16 için doğrudan çıkarımlar

1. **İdempotency zorunlu**: Frigate aynı olayı `update` ve `end` ile birden
   çok kez yayınlar → `(tenant, kaynak, kaynak_olay_id)` üzerinde tekillik.
2. **Düşük güven kuyruğu**: `recognition_threshold` varsayılanı 0.9 ve
   `match_distance: 1` (1 karakter OCR toleransı) — yani yanlış okuma
   BEKLENEN bir durumdur. Eşiğin altındaki okumalar doğrudan araç geçişi
   AÇMAMALI, **onay kuyruğuna** düşmeli (P16 kapsamında).
3. **Fotoğraf kopyalanmalı**: Frigate'in `retain` süresi kısa (PoC'ta 1 gün);
   ihlal/geçiş kaydı fotoğrafı bizim MinIO'muza alınmalı.
4. **Kamera çevrimdışı sinyali bedava**: `frigate/available` +
   `frigate/<kamera>/status/detect` — ayrı sağlık yoklaması yazmaya gerek yok.
5. **Zaman biçimi**: Frigate UNIX float saniye kullanır; ingest ISO8601 UTC
   ister — dönüşüm adaptörde, uçta değil.

## 8. Yapılmayanlar (bilinçli)

* Prod compose'a **hiçbir şey eklenmedi** (P15 kapsamı: PoC).
* Ingest ucu **yazılmadı** — o P16.
* Coral TPU denenmedi (donanım yok) — kazancı yukarıda ölçüme dayalı olarak
  değil, mimari olarak açıklandı; sahada doğrulanacak (P18).
* Gerçek plaka doğruluğu ölçülmedi (§4'teki dürüst kayıt).
