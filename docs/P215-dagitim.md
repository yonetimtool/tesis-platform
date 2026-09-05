# P215 — Canlı yayın geçidi: ağ ve port doğrulaması (DAĞITIM)

> Bu tur **iki prod yapılandırma hatasını** kapatıyor. Aşağıdaki komutlar
> "adımların uygulandığını varsayma" kuralına göre yazıldı: her biri bir
> **ölçüm**, sonucu beklenenle karşılaştırın.

---

## Ne düzeltildi

**1. `mediamtx` yanlış ağdaydı.** Prod'da 14 servisin 13'ü `tesisnet`
ağına bağlıyken `mediamtx` servisine bu satır yazılmamıştı; Docker onu
varsayılan ağa koydu:

```
mediamtx → yonetio-prod_default
api      → yonetio-prod_tesisnet
```

İki ağ arasında DNS yok → `api` konteynerinde `mediamtx` adı çözülmedi
(`socket.gaierror`) → **her** canlı yayın isteği 502 döndü.

**2. `MTX_*` ortam değişkenleri kaldırıldı.** Aynı ayar hem mount edilen
`mediamtx.yml` dosyasında hem compose `environment` bloğunda duruyordu ve
env dosyayı **eziyordu** — "hangi değer geçerli" sorusu okunarak
yanıtlanamıyordu. Sahada "logda `:999` görüyorum ama api 9997 arıyor"
şüphesi tam olarak bu belirsizlikten doğdu. Artık **tek kaynak
`infra/mediamtx.yml`**.

---

## Dağıtım

```bash
cd infra
git pull

# Compose değişti (ağ + env). Yeniden yaratmak ZORUNLU: `restart` ağ
# üyeliğini DEĞİŞTİRMEZ, konteyner eski ağda kalır.
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  up -d --force-recreate mediamtx api
```

---

## Doğrulama — sırayla, atlamadan

### 1) mediamtx ve api AYNI ağda mı?

```bash
docker inspect -f '{{.Name}} → {{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' \
  $(docker compose -f docker-compose.prod.yml --env-file .env.prod ps -q mediamtx api)
```

Beklenen: **iki satırda da aynı ağ** (`…_tesisnet`). Farklıysa dağıtım
uygulanmamış demektir — `--force-recreate` olmadan `up -d` konteyneri
yerinde bırakabilir.

### 2) İsim çözümü çalışıyor mu? (asıl kök neden)

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec -T api python -c \
  "import socket;print(socket.gethostbyname('mediamtx'))"
```

Beklenen: bir IP. `Name or service not known` → **hâlâ farklı ağlarda**.

### 3) Geçit hangi portu dinliyor? (dosyanın söylediği ile aynı mı)

```bash
# Dosyanın söylediği:
grep -E '^(api|hls)Address:' mediamtx.yml
#   apiAddress: :9997
#   hlsAddress: :8888

# Konteynerin gerçekten açtığı:
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  logs mediamtx | grep -E "listener opened"
#   INF [API] listener opened on :9997
#   INF [HLS] listener opened on :8888
```

İkisi **birebir aynı** olmalı. Ayrışıyorsa dosya mount edilmemiştir:

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec -T mediamtx sh -c "grep -E '^(api|hls)Address:' /mediamtx.yml"
```

### 4) API'nin aradığı adres ile geçidin dinlediği port aynı mı?

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec -T api sh -c 'echo "$MEDIAMTX_API_URL / $MEDIAMTX_URL"'
#   http://mediamtx:9997 / http://mediamtx:8888
```

### 5) Uçtan uca: api konteynerinden geçit API'sine

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec -T api python -c \
  "import httpx,os;r=httpx.get(os.environ['MEDIAMTX_API_URL']+'/v3/config/global/get',timeout=5);print(r.status_code)"
```

| Sonuç | Anlamı | Bakılacak yer |
|---|---|---|
| **200** | zincir sağlam | — |
| `gaierror` / `Name or service not known` | **ağ yanlış** | adım 1–2 |
| `Connection refused` | **port yanlış** ya da servis kapalı | adım 3–4 |
| **401 / 403** | API izni bu IP'ye verilmemiş | `mediamtx.yml` → `authInternalUsers` (P213 §2'nin kök nedeni) |

### 6) Gerçek kamerayla son kontrol

Web'de bir kameranın canlı yayınını açın. Hata çıkarsa **mesaja bakın** —
P215'ten sonra ayrım kullanıcıya görünür:

- *"…SUNUCU tarafında yapılandırılmamış… Kameranızda bir sorun yok"*
  → sunucu tarafı; yukarıdaki adımlara dönün, **kameraya dokunmayın**.
- *"Kameraya ulaşılamıyor"* vb. → kamera adresi/kimliği/ağ izni.

---

## Bir daha olmaması için ne eklendi

`backend/tests/test_p215_gecit_ag.py` — **dağıtımdan önce**, testte yakalar:

- prod compose'daki **her** servis `tesisnet` ağında mı (yeni bir servis
  eklenip ağı unutulursa düşer),
- `mediamtx` ile `api` özellikle aynı ağda mı,
- `mediamtx.yml`'deki port ile `MEDIAMTX_API_URL`/`MEDIAMTX_URL`
  içindeki port **aynı** mı (iki dosyada yazılı, ayrışmaları sessizdir),
- compose'da `mediamtx.yml`'i ezen `MTX_*` yinelemesi kalmamış mı,
- (çalışma zamanı) api konteynerinden geçit API'sine gerçekten
  ulaşılıyor mu — ve başarısızsa **hangisinin** kırıldığını söyler:
  ağ mı, port mu, yetki mi.
