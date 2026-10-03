# Harita karo dosyası (Türkiye PMTiles)

**Karar (P253 Aşama 2, kullanıcı):** harita karoları üçüncü bir firmadan
değil, kendi sunucumuzdaki tek bir dosyadan gelir.

Gerekçe:
* ürün Türkiye'ye yönelik;
* dışa bağımlılık ve kullanım başına ücret yok;
* kullanıcının konumu üçüncü bir firmaya gitmez (KVKK).

## Ne var, nerede

| | |
|---|---|
| **Biçim** | Protomaps PMTiles v3, vektör (MVT), gzip |
| **Kapsam** | Türkiye + sınır payı: boylam 25,0–45,5, enlem 35,3–42,6; yakınlık 0–15 (üstü istemcide büyütülür) |
| **Boyut** | 1.815.443.195 bayt (1,8 GB); 1.491.956 karo (2026-10-03 derlemesi) |
| **Yer** | MinIO `karo` kovası, herkese açık **yalnız okuma** (`mc anonymous set download`); `minio-init` dev'de ve prod'da kurar |
| **Adres** | Genel depolama adresi + `/karo/<dosya>`. Prod: `https://storage…/karo/turkiye-YYYYMMDD.pmtiles` |
| **İstemciye** | `GET /ozellikler` → `harita_karo_url` (kimliksiz). Boşsa harita kapalı; adres araması yine çalışır |
| **Web** | Leaflet + `protomaps-leaflet` 5.1.0 (`components/harita/karo-katmani.tsx`) |
| **Mobil** | `flutter_map` 7 + `vector_map_tiles` 8 + `vector_map_tiles_pmtiles` 1.5 (`core/harita/karo_haritasi.dart`); arm64 APK **+772 KB** (ölçüldü) |

### Neden daha düşük yakınlık değil

* z0–14: 958 MB; z0–13: 517 MB (ölçüldü).
* Tesis konumunda iğne bina üzerine konur. Bina ve kapı numarası
  katmanları tam ayrıntıda gelir; vektör karo z15'in üstüne kalitesiz
  büyütülmez.

## Önbellek

* Dosya adı **sürümlü** (`turkiye-<tarih>.pmtiles`). Nesne
  `Cache-Control: public, max-age=31536000, immutable` ile yüklenir.
  * Tarayıcı ve uygulama aynı aralığı bir daha indirmez.
  * Yeni sürüm yeni ad olduğu için bayat önbellek oluşmaz.
* Mobil karoları cihazda 365 gün saklar (`fileCacheTtl`).
* MinIO aralık isteğine **206** döner ve `Content-Range`'i CORS ile açar
  (ölçüldü).

## Atıf (zorunlu, ODbL)

Her haritanın köşesinde görünür, iki yüzeyde de:
"Protomaps © OpenStreetMap katkıcıları" (7 dil).
* Web: Leaflet atıf denetimi.
* Mobil: `harita-atif` metni.

## Güncelleme (yılda 1–2 kez)

```bash
# prod sunucusunda, depo kökünde:
ORTAM=prod bash docs/karo-guncelle.sh            # en yeni Protomaps derlemesi
# ya da belirli bir gün:
ORTAM=prod TARIH=20261003 bash docs/karo-guncelle.sh
```

Betik:
1. `pmtiles` aracını indirir (sabit sürüm).
2. Kesiti alır (yalnız gereken aralıklar, ~1,9 GB transfer) ve doğrular.
3. Dosyayı `karo` kovasına sürümlü adla, önbellek başlığıyla koyar.
4. Son adımı yazar: `infra/.env.prod`'da
   `HARITA_KARO_DOSYASI=<yeni ad>` ve
   `docker compose -f docker-compose.prod.yml up -d --force-recreate api`.

İstemciler yeni adresi bir sonraki açılışta alır; **uygulama güncellemesi
gerekmez**.

**Eski dosya silinmez:** açık istemciler bir süre onu okur. Bir sonraki
güncellemede `mc rm local/karo/<eski>` ile elle silinir; betik kovanın
listesini yazdırır.

## Adres arama — açık konu

`/konum/ara` sunucudan Open-Meteo'nun coğrafi kodlama ucunu çağırır
(kullanıcının IP'si değil, sunucunun IP'si gider). Hava durumu da aynı
sağlayıcıdan gelir.

Open-Meteo koşulları (2026-10'da okundu): ücretsiz API **yalnız ticari
olmayan kullanım** için ("You may only use the free API services for
non-commercial purposes"). Ticari kullanım ücretli plan ister (Standard ve
üstü; geocoding dahil). Veri CC-BY 4.0, atıf gerekir.

Prod'a çıkmadan önce **karar gerekiyor**:

| Seçenek | Not |
|---|---|
| Open-Meteo ücretli plan | Hava durumu + adres arama ikisi birden; en az değişiklik |
| Kendi yer adı dizinimiz | Karo dosyasının `places` katmanından (il, ilçe, mahalle, köy adları ve koordinatları) bir arama tablosu üretmek. Dışa bağımlılık yok. Doğruluk mahalle düzeyinde; bina düzeyi zaten iğneyle seçiliyor |
| Kendi Photon/Nominatim sunucumuz | Türkiye verisiyle mümkün, ama ayrı servis + birkaç GB + işletim yükü |

Hava durumu için de ayrı bir karar gerekir (Open-Meteo ücretli plan ya da
başka bir sağlayıcı).
