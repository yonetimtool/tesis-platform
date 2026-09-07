# DUKKAN F3 — DAĞITIM NOTU

> F3 = **SEO yüzeyi**: bölge/kategori sayfaları, arama, işletme profili,
> sıralama puanı, üretilen sitemap + mobil "Yerel İşletmeler".
>
> `dukkan.yonetiyor.com` **hâlâ yayına açılmıyor** — talep tarafı (F4)
> gelmeden ürün yarım. F3'ün çıktısı, işletmeler biriktikçe sayfaların
> kendiliğinden doğmaya hazır olması.

---

## 1. Yeni ortam değişkeni

**Yok — zorunlu olan.** Bir tanesi opsiyonel:

```
NEXT_PUBLIC_INCE_ICERIK_ESIGI=3     # varsayılan 3; dukkan-web servisi eklendiğinde
```

Bu değişken **`dukkan-web` servisi eklendiğinde** anlamlı olacak; F3'te web
hâlâ dağıtılmıyor.

---

## 2. Göç

**`0117_dukkan_yorum_ve_siralama`**

- `dukkan.yorum` tablosu (F5'te dolacak; F3'ün sıralama formülü ona dayanıyor)
- `ix_isletme_gorunur` **yeniden oluşturuluyor**: `(siralama_puani DESC)` →
  `(siralama_puani DESC, id)`. Sorgudaki `ORDER BY` ile birebir aynı olması
  için.
- `ix_isletme_yeni`, `ix_yorum_*`

**Yönetiyor tablolarına DDL yok.**

---

## 3. Uygulama

```bash
git pull
docker compose -f docker-compose.prod.yml build migrate api admin-web worker
docker compose -f docker-compose.prod.yml up migrate
docker compose -f docker-compose.prod.yml up -d --force-recreate api worker beat
```

> **`beat` YENİDEN KURULMALI** — bu fazda yeni bir zamanlanmış iş eklendi
> (`dukkan.siralama_yenile`). `beat` yenilenmezse iş **hiç çalışmaz** ve
> sıralamanın "yenilik" bileşeni sonsuza dek sönmez: bir yıl önce onaylanmış
> işletme listenin üstünde kalır. Sessiz bir kusur olurdu.

---

## 4. Doğrulama

### 4.1 Zamanlanmış iş kayıtlı mı — **atlama**

```bash
docker compose -f docker-compose.prod.yml logs beat --tail 40 | grep -i dukkan
# BEKLENEN: "dukkan-siralama" zamanlamasını içeren bir satır

docker compose -f docker-compose.prod.yml exec worker \
  celery -A app.celery_app inspect registered 2>/dev/null | grep dukkan
# BEKLENEN: dukkan.siralama_yenile
```

Görünmüyorsa **dur ve bildir**: iş kayıtlı değilse sıralama zamanla bozulur
ve bunu fark etmek aylar alır.

### 4.2 İşi elle bir kez koştur

```bash
docker compose -f docker-compose.prod.yml exec worker \
  python -c "from app.dukkan.gorevler import siralama_yenile; print(siralama_yenile())"
# BEKLENEN: {'islenen': <onaylı işletme sayısı>}
```

F3 sonrası ilk koşumda mevcut işletmelerin puanı hesaplanmış olur.

### 4.3 Uçlar

```bash
API=https://api.yonetiyor.com

curl -s "$API/dukkan/isletme-ara?il=istanbul" | head -c 200
curl -s "$API/dukkan/sitemap/sayfalar?esik=3" | head -c 200

# Konum süzgeci eksikse 422 (sessizce yok saymaz)
curl -s -o /dev/null -w '%{http_code}\n' "$API/dukkan/isletme-ara?mahalle=catalmese"
# BEKLENEN: 422
```

### 4.4 Görünürlük sınırı — **atlama**

Onaysız bir işletme aramada **çıkmamalı**:

```bash
docker compose -f docker-compose.prod.yml exec db psql -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" -tAc \
  "SELECT count(*) FROM dukkan.isletme
    WHERE durum <> 'onayli' OR dogrulama_seviyesi < 1;"
```

Bu sayı > 0 ise, aynı işletmelerin **arama sonucunda çıkmadığını** teyit et:

```bash
curl -s "$API/dukkan/isletme-ara?boyut=50" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['toplam'])"
```

Arama toplamı, `durum='onayli' AND dogrulama_seviyesi>=1` sayısına eşit
olmalı. Fazlaysa **dur ve bildir** — onaysız işletme aramaya sızmış demektir
ve bu sahte işletme riskinin (T3) kapısı.

### 4.5 Kamu profili sızdırmıyor

```bash
curl -s "$API/dukkan/isletme-profil/<bir-slug>" | grep -c "vergi_no\|red_sebebi"
# BEKLENEN: 0
```

---

## 5. `dukkan-web` — hâlâ dağıtılmıyor, ama hazırlığı yazılı

Servis eklendiğinde compose'a girecek blok:

```yaml
  dukkan-web:
    build:
      context: ../apps/dukkan-web
    environment:
      API_BASE_URL: http://api:8000
      NEXT_PUBLIC_SITE_ADRESI: https://dukkan.yonetiyor.com
      NEXT_PUBLIC_INCE_ICERIK_ESIGI: "3"
    depends_on:
      api:
        condition: service_started
    networks: [tesisnet]          # <-- P215: BU SATIR ATLANMAYACAK
    restart: unless-stopped
```

**Ağ doğrulama komutu** (servis eklendiğinde çalıştırılacak):

```bash
docker compose -f docker-compose.prod.yml exec dukkan-web \
  sh -c "wget -qO- http://api:8000/health || echo 'API ERISILEMIYOR'"
# BEKLENEN: sağlık yanıtı. "API ERISILEMIYOR" görürsen ağ eksik.

docker inspect $(docker compose -f docker-compose.prod.yml ps -q dukkan-web) \
  --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}'
# BEKLENEN: tesisnet
```

> P215'te `mediamtx`'i ağa eklemeyi unuttuk ve hata **prod'a kadar gitti**.
> O bedeli bir kez ödedik.

---

## 6. Mobil

Yeni ekranlar `/dukkan` ve `/dukkan/isletme/:slug`. **Uçlar kimliksiz**,
yani mobil tarafta yeni bir yapılandırma **gerekmiyor**.

Menüye giriş noktası F6'da (Yönetiyor entegrasyonu) eklenecek; şimdilik
rotalar tanımlı ama menüde görünmüyor — **bilinçli**: talep tarafı yokken
sekmeyi açmak, kullanıcıya yarım bir ürün göstermek olurdu.

APK/AAB üretimi bu fazda **gerekmiyor**.

---

## 7. Geri alma

```bash
docker compose -f docker-compose.prod.yml run --rm migrate \
  alembic -c /contracts/db/alembic.ini downgrade 0116_dukkan_sms_gonderim_izi
```

`yorum` tablosunu düşürür, `ix_isletme_gorunur`'u eski (tek sütunlu) hâline
döndürür. Veri kaybı: yalnız `yorum` (F3'te boş).

`beat`'i de geri kurmayı unutma — aksi hâlde kayıtlı olmayan bir görevi
çağırmaya çalışır ve günlüğe hata yazar.

---

## 8. Risk

| Risk | Değerlendirme |
|---|---|
| Yönetiyor'a etki | **Yok.** Yeni tablo `dukkan` şemasında; Yönetiyor tablolarına DDL yok |
| Mevcut uçlara etki | **Yok.** 4 yeni kamu ucu |
| `beat` yükü | Gecelik tek iş, 02:00 UTC — retention (01:00) ve finans (03:00) **arasına** kondu; üçünün aynı anda koşması gereksiz bir tepe olurdu |
| Veritabanı yükü | Yeni kısmi indeksler küçük (yalnız görünür işletmeler) |
| Bağlantı havuzu | Değişmedi. Gecelik iş **kendi** engine'ini dispose ediyor (P187) |
