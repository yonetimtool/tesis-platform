# P191 — dağıtım notları

Sıra önemlidir: **göç → imajlar → doğrulama**. Komutlar `infra/` içinde
`--env-file .env.prod` ile çalıştırılır (RUNBOOK-PROD.md §6).

```bash
cd /opt/yonetio/infra   # sunucudaki yol
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
```

> **Kısmi build YAPMAYIN.** `migrate api admin-web worker beat` beşi birden
> gerekiyor; argümansız `up -d --build` hepsini kapsar (P171 olayı).

Bu turda **iki yeni göç** var: `0077_push_gonderim`, `0078_gorev_aidat_bildirim`.

---

## §1 — Kayıt yönlendirmesi

### Yeni değişkenler (`.env.prod`)

```ini
# Oturum çerezi panel.* ve app.* arasında paylaşılsın (BAŞTAKİ NOKTA ÖNEMLİ).
COOKIE_DOMAIN=.yonetiyor.com

# Konak-ötesi yönlendirmenin hedefi. DERLEME ARGÜMANI: değişirse
# `docker compose build admin-web` gerekir. Boş bırakılabilir (o zaman
# adres iletilmiş başlıklardan türetilir — yine portsuz/https).
ADMIN_WEB_APP_ADRESI=https://app.yonetiyor.com
```

`COOKIE_DOMAIN` **çalışma zamanı** değişkenidir; `up -d` yeter.
`ADMIN_WEB_APP_ADRESI` **derleme** argümanıdır; `--build` şart.

### Doğrulama

```bash
# 1) Yönlendirmede PORT OLMAMALI ve https olmalı:
curl -sI https://panel.yonetiyor.com/kayit | grep -i '^location'
#    beklenen: location: https://app.yonetiyor.com/kayit
#    HATALIYSA (…:3000 görülürse) admin-web imajı eski demektir.

# 2) Oturumsuz korumalı sayfa kendi konağında /login'e gitmeli:
curl -sI https://panel.yonetiyor.com/dashboard | grep -i '^location'

# 3) Çerez alan adı (giriş sonrası, tarayıcı geliştirici araçlarında):
#    tesis_rt çerezinin Domain alanı `.yonetiyor.com` olmalı.
```

### Davetli SSO girişi

Panelden kullanıcı oluşturulmuş bir e-postayla Google girişi:
"bu hesap bir tesise bağlı değil" ekranı artık **Tesis ID** sorar. Test:
`app.yonetiyor.com/login` → Google → Tesis ID (davet e-postasındaki kod) →
oturum açılmalı. Sağlayıcı e-postayı doğrulamamışsa 6 haneli e-posta kodu
adımı gelir.

---

## §2 — Bildirimler

### İlk bakılacak yer

```bash
# Sağlayıcı gerçekten fcm mi? (varsayılan `noop`tur ve HİÇBİR ŞEY göndermez)
grep -E '^PUSH_PROVIDER=' .env.prod
# beklenen: PUSH_PROVIDER=fcm

# Servis hesabı dosyası var mı ve konteynerde görünüyor mu?
ls -l secrets/fcm-service-account.json
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec -T api ls -l /secrets/fcm-service-account.json
```

`PUSH_PROVIDER=noop` iken **hiçbir bildirim gitmez** ve hiçbir yerde hata
görünmez — bu, bildirim gelmemesinin en sık nedenidir.

### Panelden doğrulama (kod okumadan)

**Bildirimler** sayfası → **Push teşhisi** kartı (admin/yönetici):

* Sağlayıcı `noop` ya da yapılandırma eksikse **kırmızı uyarı** çıkar.
* **Kayıtlı cihaz** 0 ise henüz kimse mobil uygulamaya girmemiş/izin
  vermemiştir.
* **Kendime test bildirimi gönder** → telefonda bildirim çıkmalı; çıkmazsa
  aynı kartın listesinde deneme satırı ve **sonucu** görünür
  (`gonderildi` / `gecersiz_token` / `basarisiz` / `noop` /
  `yapilandirilmadi` / `hedef_yok`).

### Sunucudan doğrulama

```bash
# Push kararlarının izi (değerler değil alan adları loglanır):
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  logs api worker | grep -E 'PUSH|EXTERNAL_NOTIFY' | tail -40

# Kayıtlı cihazlar ve son denemeler:
docker compose -f docker-compose.prod.yml --env-file .env.prod exec -T db \
  psql -U tesis_owner -d tesis -c \
  "SELECT durum, count(*) FROM push_gonderim
   WHERE created_at > now() - interval '1 day' GROUP BY 1;"
```

### Uçtan uca senaryo

1. Mobil uygulamada giriş yap, bildirim iznini ver.
2. Panelde **Bildirimler → Push teşhisi**: *Kayıtlı cihaz* ≥ 1 olmalı.
3. Panelden o kişiye bir **görev ata** → telefona "Yeni görev" düşmeli.
4. Düşmediyse aynı karttaki son deneme satırının **sonucu** nedeni söyler.

---

## §3 — Kamera

### Doğrulama komutları (adımların uygulandığını VARSAYMAYIN)

```bash
# 1) mediamtx ayakta mı?
docker compose -f docker-compose.prod.yml --env-file .env.prod ps mediamtx
#    "Up" değilse:  ... up -d mediamtx

# 2) MediaMTX API'si cevap veriyor mu (api konteynerinden, iç ağ)?
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec -T api python -c \
  "import httpx,os;print(httpx.get(os.environ.get('MEDIAMTX_API_URL','http://mediamtx:9997')+'/v3/paths/list',timeout=5).status_code)"
#    beklenen: 200

# 3) ffmpeg api imajında mı? (yoksa kare çekilemez — 503 kamera_ffmpeg_yok)
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec -T api ffmpeg -version | head -1

# 4) Sunucudan kameraya erişim (kimlik bilgisi olmadan, yalnız port):
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec -T api python -c \
  "import socket;s=socket.create_connection(('192.168.1.50',554),3);print('rtsp portu ACIK');s.close()"
```

### Panelden

**Kameralar → kamera ekle/düzenle → Bağlantıyı test et.** Sonuç artık
arızayı adlandırır: parola mı, adres mi, yol mu, ağ mı, sunucu mu.
Adres biçimi örneği formda yazılı.

Canlı izleme MediaMTX gerektirir: `MEDIAMTX_URL` boşsa canlı **kapalıdır**
(kare çekimi çalışmaya devam eder) ve arayüz bunu ayrı bir mesajla söyler.

---

## §4 — Banka entegrasyonu

Göçler ve doğrulama adımları §4 tamamlandığında bu bölüme eklenecektir.
