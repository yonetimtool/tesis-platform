# P216 — H265 kameralar (DAĞITIM)

## Ne değişti

`infra/mediamtx.yml`: `hlsVariant: mpegts` → **`fmp4`**. MPEG-TS yalnız
H264 destekliyor; H265 kameralarda muxer anında yok ediliyor ve yayın
hiç üretilmiyordu.

## Dağıtım

```bash
cd infra
git pull

# ÖNEMLİ: `restart` YETMEZ. Konteyner P215 öncesinden kalma
# MTX_HLSVARIANT ortam değişkenini taşıyorsa dosyayı EZER ve
# `restart` ortam değişkenlerini güncellemez.
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  up -d --force-recreate mediamtx api
```

## Doğrulama

```bash
# 1) Konteynerde ARTIK MTX_* env kalmamalı (dosya tek kaynak)
docker inspect $(docker compose -f docker-compose.prod.yml --env-file .env.prod ps -q mediamtx) \
  --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -c MTX
#    beklenen: 0

# 2) ÇALIŞAN varyant (dosyanın söylediği değil, geçidin uyguladığı)
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec -T api python -c \
  "import httpx,os;print(httpx.get(os.environ['MEDIAMTX_API_URL']+'/v3/config/global/get',timeout=5).json()['hlsVariant'])"
#    beklenen: fmp4

# 3) H265 kameranın kodeği (kaydetmeden de bakılabilir)
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec -T api ffprobe -v error -rtsp_transport tcp -select_streams v:0 \
  -show_entries stream=codec_name -of default=nw=1:nk=1 "rtsp://KULLANICI:PAROLA@KAMERA_IP:554/YOL"
#    hevc  -> H265 (tarayıcıda oynamayabilir, mobilde oynar)
#    h264  -> her yerde oynar

# 4) Geçit loglarında artık şu satır OLMAMALI:
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  logs mediamtx --tail 200 | grep -i "MPEG-TS variant"
#    beklenen: çıktı YOK

# 5) "path already exists" da azalmalı (artık önce sorulup sonra yazılıyor)
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  logs mediamtx --tail 200 | grep -c "already exists"
```

## Web'de ne göreceksiniz

- **H264 kamera:** eskisi gibi açılır.
- **H265 kamera, destekleyen tarayıcı (Safari):** açılır — sunucu artık
  H265'i sunuyor.
- **H265 kamera, desteklemeyen tarayıcı:** oynatıcı hls.js'i hiç
  başlatmadan şunu yazar: *"Bu kamera HVC1 ile yayın yapıyor;
  tarayıcınız bu biçimi oynatamıyor. Mobil uygulamada izleyebilir ya da
  kameranın H264 (alt) akışını açıp adresi onunla değiştirebilirsiniz."*
- **Kamera eklerken "Bağlantıyı test et":** kodeki de söyler
  (*"Kodek: HEVC — tarayıcıda izlenemez…"*). Kaydetmeyi engellemez.

## Önerilen kalıcı çözüm (siteye söylenecek)

Kameranın **ikinci (alt) akışını H264** yapın ve adresi ona çevirin.
Maliyeti sıfır, her tarayıcıda çalışır, site izlemesi için çözünürlük
fazlasıyla yeterli. Sunucuda H264'e dönüştürme **ölçüldü ve reddedildi**:
1080p25 için `speed=0.693x` — tek akış bile gerçek zamana yetişmiyor.
