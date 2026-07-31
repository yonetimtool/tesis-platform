# ANPR kamera kurulumu — Hikvision / Dahua / Frigate (P19)

> Sahadaki kameranın plaka okumalarını Yönetio'ya nasıl gönderteceğinizi
> anlatır. Uç sözleşmesi: `contracts/openapi.yaml` →
> `POST /integrations/anpr/events`. Olay şeması ve Frigate ölçümleri:
> `docs/frigate-poc.md`.

## 0. Önce anahtar

Her site (tenant) için **ayrı** bir anahtar üretilir. Anahtar bir kullanıcı
hesabı değildir; kamera kutusunun kimliğidir.

```bash
curl -X POST https://<sunucu>/integrations/anpr/keys \
  -H "Authorization: Bearer <admin access token>" \
  -H "Content-Type: application/json" \
  -d '{"ad":"Ana kapı Hikvision"}'
```

Yanıttaki `anahtar` alanı **yalnız bir kez** döner (`<kimlik>.<sır>`).
Sunucuda yalnız sırrın sha256 özeti saklanır — kaybederseniz yenisi üretilir,
eskisi `DELETE /integrations/anpr/keys/{id}` ile pasifleştirilir.

Her istekte şu başlık gider:

```
X-ANPR-Key: <kimlik>.<sır>
```

> **Kamera başına ayrı anahtar üretin.** Bir kamera arızalanıp yerine yenisi
> gelirse yalnız onun anahtarını pasifleştirirsiniz; diğerleri çalışmaya devam
> eder. `son_kullanim` alanı hangi kutunun ne zaman yazdığını gösterir.

## 1. Hikvision (ISAPI olay bildirimi)

Hikvision kameralar plaka okumalarını **HTTP Host Notification** ile iter.

**Kamera web arayüzü → Configuration → Network → Advanced Settings →
HTTP Listening** (model/firmware'e göre "Alarm Server" / "HTTP Host"):

| Alan | Değer |
|---|---|
| Destination IP / URL | `https://<sunucu>/integrations/anpr/events` |
| Protocol | HTTPS (mümkünse; HTTP yalnız kapalı ağda) |
| Format | **JSON** (XML gönderen firmware'ler için aşağıya bakın) |
| Custom header | `X-ANPR-Key: <kimlik>.<sır>` |

**Configuration → Road Traffic → Vehicle Detection**'da plaka tanıma açık
olmalı ve "Upload to HTTP Listening" işaretli olmalıdır.

Gövde şu şekilde gelir (adaptörün okuduğu alanlar **kalın**):

```jsonc
{
  "EventNotificationAlert": {
    "channelName": "Ana Kapı",         // → kamera
    "dateTime": "2026-07-31T10:05:00+03:00",
    "ANPR": {
      "licensePlate": "34 ABC 123",    // → plaka (sunucu normalize eder)
      "dateTime": "2026-07-31T10:05:00+03:00",   // → zaman
      "confidenceLevel": 95            // → güven (0-100 → 0..1)
    }
  }
}
```

**Kaynak alanını eklemek gerekir.** Hikvision gövdeye ek alan koyamıyorsa
sorgu dizesi kullanılamaz — bu uç gövdeden okur. İki seçenek:

* Firmware "custom body" destekliyorsa gövdeye `"kaynak": "hikvision"` ekleyin;
* desteklemiyorsa kameranın önüne ince bir aktarıcı koyun (nginx/Node-RED)
  ve gövdeyi `{"kaynak":"hikvision", ...orijinal gövde}` olarak sarın.

> **Olay kimliği yoksa sorun değil.** Hikvision her bildirimde benzersiz bir
> kimlik vermeyebilir; adaptör o durumda `(plaka + zaman)`dan **türevsel** bir
> kimlik üretir. Aynı olay tekrar gelirse aynı kimliği verir, yani idempotency
> korunur — kamera "retry" yaptığında ikinci bir geçiş açılmaz.

### XML gönderen firmware

Eski firmware'ler `multipart/form-data` içinde XML iter. Bu uç **JSON**
bekler; araya bir dönüştürücü (Node-RED "XML → JSON" düğümü ya da küçük bir
FastAPI/Express aktarıcı) koyun ve yukarıdaki JSON şekline çevirin. Alan
adları XML'de de aynıdır (`licensePlate`, `dateTime`, `confidenceLevel`).

## 2. Dahua (HTTP push — TrafficCar)

**Kamera web arayüzü → Setting → Network → Access Platform → HTTP Push**
(bazı modellerde Event → ANPR → Push):

| Alan | Değer |
|---|---|
| URL | `https://<sunucu>/integrations/anpr/events` |
| Method | POST |
| Header | `X-ANPR-Key: <kimlik>.<sır>` |
| Event | TrafficCar / TrafficJunction (plaka olayı) |

Gövde:

```jsonc
{
  "kaynak": "dahua",
  "Events": [{
    "Data": {
      "PlateNumber": "07 AB 100",   // → plaka
      "UTC": 1785450900,             // → zaman (UNIX saniye; "Time" de olur)
      "ChannelName": "Çıkış",        // → kamera
      "Confidence": 92,              // → güven
      "EventID": "abc-123"           // varsa → idempotency; yoksa türetilir
    }
  }]
}
```

## 3. Frigate

Frigate'in kendi webhook'u yoktur; olayları **MQTT**'ye ve HTTP API'sine
yazar. İki bağlama seçeneği:

* **MQTT köprüsü (önerilen):** `frigate/events` konusunu dinleyen küçük bir
  betik, `after` nesnesini `{"kaynak":"frigate", "after": {...}}` olarak bu
  uca POST eder. Adaptör `after.id`yi idempotency anahtarı, `after.sub_label`ı
  plaka, `after.start_time`ı zaman olarak okur (P15'te ölçüldü).
* **Yoklama:** `GET /api/events?after=<son_zaman>` ile periyodik çekip aynı
  gövdeyi POST etmek. Basit ama gecikmeli.

> Frigate aynı olayı `update` ve `end` olarak **birden çok kez** yayınlar.
> Köprüde ayıklama YAPMAYIN — uç zaten idempotenttir ve tekrarı sessizce
> yutar. Ayıklama yapmak, `end` yükündeki nihai plaka değerini kaçırmanıza yol
> açar.

## 4. Yön (`yon`) — en sık atlanan ayar

Hiçbir kamera markası "bu araç girdi mi çıktı mı" bilgisini güvenilir şekilde
üretmez. Sistem şöyle davranır:

| `yon` | Davranış |
|---|---|
| verilmedi / `bilinmiyor` | Plakanın **açık geçişi varsa ÇIKIŞ**, yoksa **GİRİŞ** |
| `giris` | Giriş; araç zaten içerideyse olay sessizce yok sayılır |
| `cikis` | Çıkış; açık geçiş yoksa yok sayılır |

**Tek yönlü kapıda** (yalnız giriş kamerası var, çıkışta kamera yok) sitenin
`anpr_otomatik_cikis` ayarını **kapatması** gerekir — aksi hâlde aracın ikinci
girişi "çıkış" sanılır. Ayar: `PATCH /tenant/settings`
`{"anpr_otomatik_cikis": false}` (yönetici de yazabilir).

**Çift kameralı geçitte** her kameraya sabit yön verin: aktarıcı gövdeye
`"yon":"giris"` ya da `"yon":"cikis"` eklesin. Bu, en sağlam kurulumdur.

## 5. Güven eşiği

Varsayılan `anpr_guven_esigi = 0.850`. Bu değerin **altındaki** okuma geçiş
açmaz, **onay kuyruğuna** düşer (mobil: *Plaka Okumaları* ekranı).

* Kamera açısı kötüyse veya gece okumaları zayıfsa eşiği yükseltmeyin —
  **düşürmeyin de**. Önce açıyı düzeltin (§6).
* Sahada çok fazla onay birikiyorsa eşiği kademeli düşürün ve kuyruğu izleyin.
* `1.0` = hiçbir okumaya güvenme (hepsi onaya düşer) — geçici olarak yeni bir
  kamerayı "gözlem altında" çalıştırmak için kullanışlıdır.
* `0.0` = hepsini işle. Yalnız güveni yüksek, tek yönlü, kontrollü geçitlerde.

Ayar: `PATCH /tenant/settings` `{"anpr_guven_esigi": 0.9}`.

## 6. Kamera açısı (plaka okuma için kritik)

`docs/frigate-poc.md` §4'te ölçülen mimari gerçek: **plaka bağımsız bir nesne
değil, aracın ÖZNİTELİĞİDİR** — model önce *araç* görmeli, sonra plakayı
okuyabilir.

* Kamera **aracın gövdesini** görmeli. Yalnız plakaya zoom yapılmış bir kadraj
  LPR'yi çalışmaz hâle getirir.
* Plaka görüntüde yaklaşık **100–150 piksel genişlikte** olmalı.
* Yatay sapma ±30°, dikey sapma ±30° içinde kalmalı.
* Gece: IR aydınlatma plakayı **parlatmamalı** (retro-reflektif plaka doyar ve
  okunmaz olur). Kısa pozlama + IR filtresi ayarı gerekir.
* Araç **yavaşladığı** noktaya bakın (bariyer/kasis önü), tam hız geçilen yere
  değil.

## 7. Doğrulama

Kurulumdan sonra elle bir olay göndererek zinciri sınayın:

```bash
curl -X POST https://<sunucu>/integrations/anpr/events \
  -H "X-ANPR-Key: <kimlik>.<sır>" -H "Content-Type: application/json" \
  -d '{"kaynak":"manuel","kaynak_olay_id":"kurulum-testi-1",
       "plaka":"34 TEST 34","zaman":"2026-07-31T10:00:00Z","kamera":"Ana Kapı"}'
```

Beklenen: `201` + `"durum":"islendi"` + dolu bir `vehicle_pass_id`.
Mobilde *Araç Geçişleri* listesinde `34TEST34 · İçeride` görünmelidir.

Sorun giderme:

| Belirti | Neden |
|---|---|
| `401` | Anahtar yanlış, biçimsiz (`.` yok) ya da pasifleştirilmiş |
| `422 anpr_kaynak_bilinmiyor` | `kaynak` alanı yok/yanlış |
| `201` ama `durum: "hata"` | Plaka okunamadı — gövdedeki `plaka`/`licensePlate`/`PlateNumber` alanına bakın |
| `201` ama `durum: "yok_sayildi"` | `durum_nedeni`ye bakın: `zaten_iceride`, `acik_gecis_yok`, `otomatik_cikis_kapali` |
| `201` ama `durum: "onay_bekliyor"` | Güven eşiğin altında — §5 |

Olay defteri: `GET /integrations/anpr/events?limit=20` (admin/güvenlik) ya da
mobilde *Plaka Okumaları*.

## 8. Ağ ve güvenlik notları

* Sunucu kamera yayınını **hiç çekmez**; bağlantı her zaman kameradan
  sunucuya doğrudur. Kameraya internetten erişim açmanız GEREKMEZ.
* Anahtar bir **yazma** yetkisidir: o siteye plaka olayı yazabilir. Okuma ya da
  başka bir uç yetkisi vermez.
* Kamera kutusu ile sunucu arasında HTTPS kullanın; kapalı ağda HTTP kabul
  edilebilir ama anahtar düz metin gider.
* Fotoğraf: `foto_key` alanı MinIO obje anahtarı bekler. Kamera doğrudan
  fotoğraf gönderemez; aktarıcı önce `POST /uploads/presign` ile yükleyip
  anahtarı olaya eklemelidir. **Frigate'in kendi saklama süresi kısadır** —
  ihlal/geçiş kanıtı olarak saklanacak fotoğraf bize kopyalanmalıdır.
