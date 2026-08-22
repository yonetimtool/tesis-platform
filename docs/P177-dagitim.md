# P177 — Test sunucusu dağıtım adımları

**Hedef:** `test.yonetio.site` → yeni tanıtım sitesi (`tanitim-web`).
**Sunucu:** 192.168.1.25 (TEST). **Prod (192.168.1.105) DONDURULMUŞ —
bu belgedeki hiçbir adım prod'da çalıştırılmaz.**

`app-test.yonetio.site`, `panel-test.yonetio.site` ve
`api-test.yonetio.site` bu turda **değişmiyor**; adımlar onları ayakta
tutacak şekilde yazıldı.

---

## ⚠️ Başlamadan — üç tuzak

Bu üçü daha önce ortamı düşürdü. Adımların içinde tekrar hatırlatılıyor
ama önce okuyun.

### Tuzak 1 — `migrate` servisini build listesinden ÇIKARMAYIN

Göç imajı **ayrı bir imajdır**. `contracts/` canlı mount'tur (`ro`),
`backend/app` ise imaja **gömülüdür**. Kısmi build yaparsanız yeni göç
dosyası eski kodla karşılaşır ve `migrate` düşer; `api`, `admin-web`,
`worker` ve `tanitim-web` **hiç başlamaz** (`service_completed_successfully`
ile bağlılar) ve `docker ps` boş görünür.

```
# YANLIŞ  →  docker compose build api tanitim-web
# DOĞRU   →  docker compose build migrate api admin-web worker tanitim-web
```

Bu 2026-08'de bir kez ortamı düşürdü (P171).

### Tuzak 2 — Caddy'yi `--force-recreate` ile kaldırın

`api`, `admin-web` veya `tanitim-web` yenilendiğinde konteynerler **yeni
IP** alır. Caddy DNS'i önbelleğe almış olabilir ve eski IP'ye vurup
**502** döner. Belirti sinsi: "deploy başarılı" görünür, site 502 verir.

```
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  up -d --force-recreate caddy
```

### Tuzak 3 — `.env.prod`da SATIR TEKRARI YAPMAYIN

Bir değişken iki kez yazıldığında **son** değer geçerli olur. SMTP
satırları iki kez yazıldığı için ortam bir kez düştü. Aşağıdaki ekleme
adımı grep korumalıdır; kopyalayıp olduğu gibi çalıştırın.

---

## 1. Depoyu güncelle (Caddyfile korunarak)

Sunucudaki `infra/Caddyfile` **elle düzenlenmiş** durumda (bloklar
`http://`, kanonik yönlendirmeler silinmiş). Her zamanki gibi:

```bash
cd /opt/yonetio            # depo kökü (kendi yolunuz)
git stash                  # elle düzenlenmiş Caddyfile korunur
git pull
git stash pop              # geri gelir; çakışma OLMAMALI
```

> Depodaki `infra/Caddyfile` de bu turda güncellendi (kanonik hâli için),
> ama sunucuda **sizin** dosyanız geçerli. Yeni bloğu adım 3'te elle
> yapıştıracaksınız.

---

## 2. `.env.prod`a değişkenleri ekle

**Önce oku, sonra ekle.** Aşağıdaki blok zaten yazılmış olanları atlar:

```bash
cd /opt/yonetio/infra
grep -n "^TANITIM_\|^YENI_KAYIT_AKISI\|^SMS_AKTIF\|^TICARI_ILETI_AKTIF" .env.prod || echo "(henüz yok)"
```

Çıktı boşsa ekleyin:

```bash
cat >> .env.prod <<'EOF'

# --- (P177) TANITIM SITESI ---
TANITIM_DOMAIN=test.yonetio.site
TANITIM_ESKI_HEDEF=https://app-test.yonetio.site
TANITIM_APP_ADRESI=https://app-test.yonetio.site
TANITIM_SITE_ADRESI=https://test.yonetio.site
TANITIM_ILETISIM_EPOSTA=destek@yonetio.site
TANITIM_UCRETSIZ=1
TANITIM_SSO_GOOGLE=1
TANITIM_SSO_MICROSOFT=0
TANITIM_SSO_APPLE=0

# --- (P177) YENI KAYIT AKISI + GONDERIM KAPILARI ---
# KAPALI baslar. Acmadan once docs/P177-kararlar.md §7.1'i okuyun
# (Kullanim Kosullari 2. maddesi yeni akisla CELISIYOR).
YENI_KAYIT_AKISI=false
SMS_AKTIF=false
TICARI_ILETI_AKTIF=false
EOF
```

Tekrar kontrolü (**boş çıkmalı**):

```bash
grep -o "^[A-Z_]*=" .env.prod | sort | uniq -d
```

Boş çıkmazsa **durun** ve tekrarlanan satırı silin.

---

## 3. Caddy bloğunu elle yapıştır

`infra/caddy-tanitim.snippet` dosyasını açın; içindeki uyarıları okuyun.

### 3a. Önce mevcut bloğu bulun

```bash
grep -n "test.yonetio.site" infra/Caddyfile
```

`test.yonetio.site` **büyük ihtimalle zaten var** (kök/portal bloğu
olarak, `reverse_proxy admin-web:3000` ile). O bloğu **silip yerine**
snippet'i yapıştırın.

> **Aynı konak iki blokta görünürse Caddy hiç açılmaz:**
> `ambiguous site definition: test.yonetio.site`.
> Bu P149'da yaşandı ve ortamı düşürdü.

### 3b. Yapıştırdıktan sonra DOĞRULAYIN

```bash
cd /opt/yonetio/infra
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  exec caddy caddy validate --config /etc/caddy/Caddyfile
```

**"Valid configuration" görmeden devam etmeyin.**

---

## 4. Derle — DÖRT SERVİS + tanitim-web

```bash
cd /opt/yonetio/infra
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  build migrate api admin-web worker tanitim-web
```

> `migrate` listede — **çıkarmayın** (Tuzak 1).

`NEXT_PUBLIC_*` değerleri tanıtım sitesinin imajına **derleme anında
gömülür**. Yani `TANITIM_UCRETSIZ` ya da bir `TANITIM_SSO_*` değerini
sonradan değiştirirseniz `up -d` **yetmez**, `--build` gerekir.

---

## 5. Ayağa kaldır

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d
```

Göç çıktısını kontrol edin (0068 uygulanmalı):

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod logs migrate | tail -20
# beklenen: "Running upgrade 0067_eposta_dogrulama_kodu -> 0068_yeni_kayit_akisi"
```

---

## 6. Caddy'yi `--force-recreate` ile yenile

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  up -d --force-recreate caddy
```

> Bunu atlarsanız eski IP önbelleğiyle **502** alırsınız (Tuzak 2).

---

## 7. Doğrulama

### 7a. Yeni site ayakta

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://test.yonetio.site/
curl -s -o /dev/null -w "%{http_code}\n" https://test.yonetio.site/yonetici
curl -s -o /dev/null -w "%{http_code}\n" https://test.yonetio.site/yonetici/kayit
curl -s -o /dev/null -w "%{http_code}\n" https://test.yonetio.site/site-sakini
curl -s -o /dev/null -w "%{http_code}\n" https://test.yonetio.site/kullanici-sozlesmesi
curl -s -o /dev/null -w "%{http_code}\n" https://test.yonetio.site/kvkk-aydinlatma
curl -s -o /dev/null -w "%{http_code}\n" https://test.yonetio.site/cerez-politikasi
# hepsi 200
```

### 7b. Eski yollar KIRILMADI

```bash
# 301 dönmeli ve Location app-test'e gitmeli:
curl -sI https://test.yonetio.site/gizlilik      | grep -i "^HTTP\|^location"
curl -sI https://test.yonetio.site/kosullar      | grep -i "^HTTP\|^location"
curl -sI https://test.yonetio.site/hesap-silme   | grep -i "^HTTP\|^location"
curl -sI https://test.yonetio.site/davet/ORNEK   | grep -i "^HTTP\|^location"

# Derin baglanti dosyalari YONLENDIRILMEDEN, application/json ile gelmeli:
curl -sI https://test.yonetio.site/.well-known/assetlinks.json | grep -i "^HTTP\|content-type"
curl -sI https://test.yonetio.site/.well-known/apple-app-site-association | grep -i "^HTTP\|content-type"
# 200 + application/json  (301 GORURSENIZ SORUN VAR: dogrulayicilar 3xx izlemez)
```

### 7c. Diğer yüzeyler ETKİLENMEDİ

```bash
curl -s -o /dev/null -w "app-test   %{http_code}\n" https://app-test.yonetio.site/login
curl -s -o /dev/null -w "panel-test %{http_code}\n" https://panel-test.yonetio.site/login
curl -s -o /dev/null -w "api-test   %{http_code}\n" https://api-test.yonetio.site/health
```

### 7d. Yeni kayıt akışı KAPALI (varsayılan)

```bash
curl -s -X POST https://api-test.yonetio.site/auth/kayit/yonetici-dogrula \
  -H 'content-type: application/json' \
  -d '{"eposta":"kontrol@ornek.com","kod":"000000"}' -w "\n%{http_code}\n"
# beklenen: 503 + {"error":{"code":"unavailable", ...}}
```

### 7e. Hesaplayıcı

Tarayıcıda `https://test.yonetio.site/yonetici` → **Fiyat Hesapla**.
50 daire → **5.000 ₺**, altında **"Fiyatlarımıza KDV dahil değildir."**

### 7f. Kayıt e-postası GERÇEKTEN ulaşıyor mu (§9.7)

Bu adım **yalnız test sunucusunda** yapılabilir: geliştirme makinesinde
SMTP yapılandırılmamıştır, sağlayıcı `yapilandirilmadi` döner ve
**hiçbir e-posta gönderilmez** (sessizce "gönderildi" demez).

Önce akışı açın (adım 8), sonra kendi adresinizle kaydolun:

```bash
# 1) Basvuru — e-postaniza 6 haneli kod gitmeli
curl -s -X POST https://test.yonetio.site/api/kayit/basvuru \
  -H 'content-type: application/json' \
  -d '{"ad":"Test","soyad":"Yonetici","eposta":"SIZIN@ADRESINIZ",
       "telefon":"+905XXXXXXXXX","parola":"GucluParola123!",
       "onay_sozlesme":true,"onay_kvkk":true,"onay_ticari":false}'
# beklenen: {"durum":"kod_gonderildi"}
```

Gelen kutusunu kontrol edin (Resend, `noreply@yonetio.site`). Kod
gelmediyse gönderim kaydına bakın:

```bash
docker compose -f docker-compose.prod.yml --env-file .env.prod \
  logs api --tail 100 | grep -i "eposta\|smtp\|gonderim"
```

Sonra tarayıcıda `https://test.yonetio.site/yonetici/kayit` üzerinden
üç adımı tamamlayın. Son adımdan sonra **Tesis ID** hem ekranda görünür
hem ikinci bir e-postayla gelir; o e-postada **web'den giriş bağlantısı**
bulunur (yöneticiye özel — sakine giden davet e-postasında bu bağlantı
BULUNMAZ, §9.8).

### 7g. Tarayıcı konsolu ve ağ sekmesi

Konsolda hata **olmamalı**; ağ sekmesinde Google ya da izleyici alan
adına giden **hiçbir istek olmamalı** (yalnız `test.yonetio.site` ve
kullanıcı tıklarsa `play.google.com`).

---

## 8. Yeni kayıt akışını AÇMAK (isteğe bağlı, sonra)

> **Önce `docs/P177-kararlar.md` §7.1'i okuyun:** Kullanım Koşulları'nın
> 2. maddesi ("herkese açık bir kayıt formu yoktur") yeni akışla
> **çelişiyor**. Metin güncellenmeden açmak hukuki bir tutarsızlık bırakır.

```bash
cd /opt/yonetio/infra
sed -i 's/^YENI_KAYIT_AKISI=false/YENI_KAYIT_AKISI=true/' .env.prod
grep -n "^YENI_KAYIT_AKISI" .env.prod          # TEK satir olmali
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d api worker
```

`tanitim-web` yeniden derlenmesi **gerekmez**: tanıtım sitesinde ikinci
bir bayrak yok, backend'in yanıtını olduğu gibi gösteriyor.

Kapatmak için aynı komut `true` → `false` ve `up -d api worker`.

---

## 9. Testler (isteğe bağlı, geliştirme makinesinde)

Yeni kayıt akışı testleri **iki kipte** koşar; tam kapsam için ikisi de
gerekir (atlananlar `-rs` ile görünür):

```bash
cd infra
# kapali kip (varsayilan)
docker compose up -d api && sleep 8
docker compose exec -T api python -m pytest tests/test_p177_kayit_akisi.py -q -rs

# acik kip
YENI_KAYIT_AKISI=true docker compose up -d api && sleep 8
docker compose exec -T api python -m pytest tests/test_p177_kayit_akisi.py -q -rs
```

> Backend kodu imaja **gömülüdür**: `backend/` altında bir şey
> değiştirdiyseniz önce `docker compose build api`.

İkonları yeniden üretmek:

```bash
python3 scripts/ikon-uret.py          # depo kokunden
cd mobile && dart run flutter_launcher_icons
```

---

## 10. Geri alma

Tanıtım sitesini geri çekmek, kök alan adını `admin-web`e döndürmektir:

1. `infra/Caddyfile`daki `test.yonetio.site` bloğunu eski hâline getirin
   (`reverse_proxy admin-web:3000`, `handle` grubu tek).
2. `docker compose ... exec caddy caddy validate --config /etc/caddy/Caddyfile`
3. `docker compose ... up -d --force-recreate caddy`
4. İsterseniz `docker compose ... stop tanitim-web`

Göç 0068 **geri alınabilir** (test edildi) ama geri almak gerekmez:
açtığı üç tablo mevcut hiçbir akışı etkilemiyor ve `YENI_KAYIT_AKISI`
kapalıyken hiçbiri yazılmıyor.

```bash
# gerekirse (dikkat: tesis_uyelik ve onay kuyrugu satirlari silinir)
docker compose -f docker-compose.prod.yml --env-file .env.prod run --rm migrate \
  alembic -c /contracts/db/alembic.ini downgrade -1
```
