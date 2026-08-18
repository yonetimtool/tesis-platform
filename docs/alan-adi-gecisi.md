# ALAN ADI GEÇİŞİ — yönetiyor.com (P120)

`yönetiyor.com` **birincil müşteriye dönük** alan adı olur. `yonetio.site`
**kapanmaz**: ikisi de aynı sunucuyu, aynı uygulamayı sunar.

---

## 0) ÖNCE DÜZELTME — punycode

Görevde ACE etiketi `xn--ynetiyor-vpb` olarak verilmişti. **Bu yanlış.**
Doğrusu:

```
yönetiyor.com  ->  xn--ynetiyor-n4a.com
```

Üretimi (tahmin etmeyin, üretin):

```bash
python3 -c "print('yönetiyor.com'.encode('idna').decode())"
# xn--ynetiyor-n4a.com
```

Doğrulama (DNS gerçeği): `xn--ynetiyor-n4a.com` **kayıtlı**, NS'i
Hostinger (`atlas/hyperion.dns-parking.com`), A kaydı prod sunucuya
bakıyor. `-vpb` etiketli ad ise **hiç yok** — SOA bile dönmüyor. Yanlış
biçimle devam edilseydi Caddy o ad için sertifika almaya çalışır, Let's
Encrypt doğrulaması sürekli düşer ve site **hiç açılmazdı**.

İki etiket göz kararıyla **ayırt edilemez**; bu yüzden depodaki her
`xn--` dizesi `infra/alan-adi-denetimi.py` ile unicode kaynağından
yeniden üretilip karşılaştırılır.

---

## 1) DNS KAYITLARI — Kerem'in gireceği tablo

**Prod sunucu IP: `185.248.57.150`** (ölçüldü: `api.yonetio.site` bu IP'de
ve `/health` bizim yanıtımızı veriyor).

Kayıt sağlayıcıdan bağımsızdır; Hostinger, Cloudflare, hepsinde aynı.

### yönetiyor.com (yeni birincil)

| Tip | Ad / Host | Değer | TTL | Durum |
|---|---|---|---|---|
| A | `@` (kök) | `185.248.57.150` | 300 | ✅ **girilmiş** |
| A | `www` | `185.248.57.150` | 300 | ✅ **girilmiş** |
| A | `app` | `185.248.57.150` | 300 | ✅ **girilmiş** |
| A | `panel` | `185.248.57.150` | 300 | ✅ **girilmiş** |
| A | `api` | — | — | ⛔ **AÇILMIYOR** (aşağıya bakın) |
| A | `storage` | — | — | ⛔ **AÇILMIYOR** |

Kayıt panelinde alan adı **unicode** (`yönetiyor.com`) görünür; kayıt
sağlayıcı punycode'a kendisi çevirir. `@`/`www`/`panel` yazmak yeterlidir.

**`api.` ve `storage.` bilerek açılmadı.** Mobil yapımın **içine gömülü**
adres `api.yonetio.site` ve bu tur o adres **değişmiyor** (App Store'da
inceleme bekleyen yapım ona bakıyor). İki API adresi açmak hangisinin
kanonik olduğunu belirsizleştirir, CORS/çerez yüzeyini bedelsiz büyütür ve
`storage.` için imzalı URL'ler zaten tek bir konakla imzalanır — ikinci
konak **imza doğrulamasını bozar**.

### yonetio.site (eski — TEK BİR DEĞİŞİKLİK GEREKİYOR)

| Tip | Ad / Host | Şu an | Olması gereken | Neden |
|---|---|---|---|---|
| A | `@` (kök) | `185.248.57.150` | ✅ **yapıldı** | aşağıdaki bulgu |
| A | `www` | `185.248.57.150` (CNAME→kök) | ✅ **yapıldı** | aynı |
| A | `panel` | `185.248.57.150` | değişmez | ✅ |
| A | `api` | `185.248.57.150` | değişmez | ✅ |
| A | `storage` | `185.248.57.150` | değişmez | ✅ |

#### ⚠️ CANLI BULGU — App Store'u düşürecek durum

`yonetio.site` **kökü bugüne kadar hiç sunulmuyordu**: Caddy'de yalnız
`api.`/`panel.`/`storage.` blokları vardı ve kök A kaydı Hostinger'in park
sayfasına (`2.57.91.91`) bakıyor.

Ama mobil uygulamada `AppConfig.webBaseUrl` = `https://yonetio.site` ve
**gizlilik politikası / kullanım koşulları bağlantıları oraya gidiyor.**
Ölçüldü:

```
https://yonetio.site/gizlilik      -> 200
https://yonetio.site/olmayan-yol   -> 200      # her yol 200 = catch-all
içerik: "Parked Domain name on Hostinger DNS system"
```

Yani **App Store Connect'e verilen gizlilik politikası adresi bir park
sayfası gösteriyor.** Apple bu bağlantıyı elle açar; tek başına ret
sebebidir ve "sayfa açıldı" diye bakan bir cihaz testinden de **geçer
görünür** (sayfa gerçekten açılıyor, sadece bizim sayfamız değil).

Bu turda Caddy'ye kök blokları eklendi; **A kaydı prod IP'ye çevrilir
çevrilmez** `https://yonetio.site/gizlilik` gerçek politikayı sunar —
uygulamanın yeniden derlenmesi **gerekmez**, gömülü adres doğruydu, altında
sunucu yoktu.

---

## 2) SUNUCU TARAFI — bu turda yapıldı

`infra/Caddyfile`:

* **kök + www**, her iki alan için → `admin-web:3000`. Ayrı bir tanıtım
  uygulaması yoktur; `/gizlilik` ve `/kosullar` zaten panelin **public**
  rotalarıdır.
* **panel.** her iki alan için → `admin-web:3000`. Eski adres aynen çalışır
  (yer imi, tarayıcı parola kasası ona bağlı).
* Yönlendirme **yok**: `yonetio.site` → `yönetiyor.com` 301'i, incelemedeki
  uygulamanın bağlantılarını kırardı. İkisi de kanonik.
* Caddyfile'da **punycode** yazılır: TLS SNI ve `Host` başlığı daima
  punycode gelir; unicode yazmak eşleşmeyen bir site bloğu bırakırdı.

> **⚠️ HSTS artık KÖKTEN yayılıyor.** Ortak güvenlik başlıkları
> `Strict-Transport-Security: max-age=31536000; includeSubDomains` içerir.
> Bu başlık bugüne kadar yalnız alt alanlardan gidiyordu; kök sunulmaya
> başlayınca **her iki kök alan adı için bir yıllık, tüm alt alanları
> kapsayan** bir HTTPS taahhüdü olur. Sonuç: bundan sonra açılacak
> **hiçbir alt alan düz HTTP ile çalışamaz** (tarayıcı bağlanmadan
> reddeder). Posta sağlayıcısının isteyebileceği `autodiscover.` /
> `autoconfig.` gibi adlar tarayıcı trafiği taşımaz, etkilenmez; ama bir
> gün HTTP-only bir alt alan gerekirse **önce bu başlık daraltılmalı ve
> bir yıl beklenmelidir**. Bilinçli bir tercihtir.

`infra/docker-compose.prod.yml` + `infra/.env.prod.example`:
`PORTAL_DOMAIN`, `PANEL_DOMAIN_YENI`, `PORTAL_DOMAIN_ESKI` eklendi
(varsayılanları dolu — DNS hazır olmadan da yığın ayağa kalkar; Caddy
sertifikayı arka planda tekrar tekrar dener ve DNS yayılınca kendiliğinden
alır, **diğer siteleri etkilemez**).

#### ⚠️ İKİNCİ CANLI BULGU — bize ait olmayan alan adı, giden mesajlarda

Alan adı denetimi sırasında çıktı: `backend/app/routers/mesajlar.py` içinde

```python
"odeme_linki": "https://yonetio.app/ode",
```

sabit kodluydu. **`yonetio.app` bize ait değil** — NS'i Cloudflare
(`stella/uriah.ns.cloudflare.com`), oysa sahip olduğumuz alanların hepsi
Hostinger'da (`dns-parking.com`). Bir harf farkı (`.app` / `.site`).

Bu değer bir örnek değil: aidat hatırlatma **SMS ve e-postalarındaki**
`{odeme_linki}` etiketine giriyor (`mesajlasma.py` şablonları:
*"…{bakiye} TL'dir. Ödeme: {odeme_linki}"*). Yani **bizim gönderdiğimiz
mesajda sakinlere üçüncü bir tarafın alan adına bağlantı veriyorduk.** O
alanı elinde tutan biri için hazır bir kimlik avı yüzeyi: kurban, linki
tanıdığı site yönetiminden gelen bir mesajda görür.

**Düzeltildi:** değer artık `Settings.portal_base_url` ayarından üretiliyor
(varsayılan `https://yönetiyor.com`, `PORTAL_BASE_URL` ile değiştirilebilir).
Unicode bilerek: bağlantı insanın okuduğu mesaj metnine girer, `xn--…`
biçimi SMS'te kimlik avı gibi görünür.

> **Açık kalan:** `/ode` rotası **henüz yok** (panelin public rotaları:
> `/gizlilik`, `/kosullar`, `/login`). Bağlantı bugün 404 verir — ama
> **bizim** alanımızda 404 verir; yabancının alanında çalışan bir sayfadan
> iyidir. Ödeme akışı yazılınca bu rota açılmalı.

`backend/app/config.py`: `CORS_ORIGINS` artık **punycode'a
normalleştiriliyor**. Unicode yazılırsa punycode biçimi de listeye girer;
ikisi de geçerli kalır. (Tarayıcı `Origin` başlığını daima punycode
gönderir — bu normalleştirme olmasaydı belirti "CORS bozuk" diye görünür,
kimse alan adının yazım biçiminden şüphelenmezdi.)

### Dağıtım

`.env.prod`'a **iki satır** eklenmeli (örnek dosyadan kopyalayın):

```
CORS_ORIGINS=https://panel.yonetio.site,https://panel.xn--ynetiyor-n4a.com
PORTAL_BASE_URL=https://yönetiyor.com
```

Alan adı değişkenlerinin (`PORTAL_DOMAIN`, `PANEL_DOMAIN_YENI`,
`PORTAL_DOMAIN_ESKI`) compose'da varsayılanı vardır; `.env.prod`'a
yazmasanız da çalışır.

```bash
cd /opt/yonetio            # prod sunucu
git pull
C="docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.prod"

# 1) GOC ONCE — ZORUNLU. Aciklama asagida.
$C run --rm migrate

# 2) Caddy — YENI KONAKLAR + TLS.  --force-recreate ZORUNLU, aciklamasi asagida.
$C up -d --force-recreate caddy

# 3) Kod tasiyan servisler — imaj kodu BAKE eder.
#    KISMI BUILD YAPMAYIN: yalniz `api` kurmak imajla depoyu AYRISTIRIR
#    (`contracts/` canli mount, `backend/app` imajda) ve bir sonraki goc
#    olmayan bir modulu arar. 2026-08'de ortami dusurdu (P171).
#    Kanonik komut RUNBOOK-PROD.md §6.1'de.
$C up -d --build migrate api admin-web worker

# 4) SEMA ILE KOD UYUSUYOR MU (P124) — `uyumlu: true` bekleniyor
curl -s https://api.yonetio.site/health | python3 -m json.tool

# 3) sertifikalar gerçekten alındı mı
$C logs --since 5m caddy | grep -iE "certificate obtained|obtain|error|failed"
```

> **⛔ GÖÇ ÖNCE ÇALIŞMALI — bu sıra atlanınca kamera modülü ÖLDÜ.**
> Bu belgenin ilk hâli `migrate` adımını **içermiyordu** ve bu gerçek bir
> arızaya yol açtı: aynı turda `camera.snapshot_url` kolonu koda eklendi,
> `api` imajı yeniden derlendi, göç **koşulmadı**. SQLAlchemy artık her
> `SELECT camera` sorgusuna o kolonu koyuyor; Postgres "column does not
> exist" diyor ve **`GET /cameras` 500** dönüyor. Kullanıcının gördüğü şey
> "kamera oynatmıyor"du — oysa liste hiç gelmiyordu. Kural: **kod yeni
> şema istiyorsa göç önce koşar.** Yeni bir dağıtımda emin değilseniz
> `run --rm migrate` zaten idempotenttir; boşuna koşmak zararsızdır.
>
> Dağıtımdan sonra `/health` çıktısındaki `schema.uyumlu` alanı **true**
> olmalıdır; `false` ise göç eksiktir (bkz. P124).

> **⚠️ `up -d caddy` TEK BAŞINA YETMEYEBİLİR — bu tuzağa dikkat.**
> `Caddyfile` bir **bind mount**'tur; içeriğini değiştirmek servis
> tanımını değiştirmez. Compose yalnız *tanım* değiştiğinde kabı yeniden
> yaratır, dolayısıyla salt-Caddyfile değişikliğinde `up -d caddy`
> **"Container caddy Running" yazıp hiçbir şey yapmaz** — ve komut
> başarıyla döndüğü için dağıtım yapıldı sanılır. Bu turda servis
> `environment`'ı da değiştiği için normalde yeniden yaratılır, ama
> **gelecekteki salt-Caddyfile düzenlemelerinde bu geçerli olmaz.**
> Bu yüzden `--force-recreate` yazıyoruz. Kesintisiz alternatif:
> `$C exec caddy caddy reload --config /etc/caddy/Caddyfile` — önce
> doğrular, hatalıysa çalışan sunucuyu düşürmeden yüksek sesle patlar.

**`api` yeniden derlenmeli:** imajlar kodu içine alır (mount yok); yalnız
`up -d api` demek eski kodu çalıştırmaya devam etmek olur.

---

## 2b) SUNULAN KONAK LİSTESİ — tek kaynak

Aşağıdaki liste **belge süsü değildir**: `infra/alan-adi-denetimi.py`
(kontrol 5) bunu `infra/Caddyfile`'ın çözülmüş site adresleriyle
**karşılaştırır** ve ayrışırlarsa `depo` kapısı kırmızı verir.

Bu kapının varlık sebebi somut: önceki tur DNS belgesini ve Caddy
yapılandırmasını birlikte gönderdi, ama sunucuya **yalnız belge ulaştı** —
kimse "belgede yazan konaklar gerçekten sunuluyor mu?" diye ölçmediği için
`yönetiyor.com` haftalarca `ERR_SSL_PROTOCOL_ERROR` verebilirdi. Aynı
hata sınıfı `.gitignore` olayında da yaşandı: **yapılandırmanın vaat
ettiği şey ile gerçekte olan şey ayrıştı ve hiçbir ölçüm bakmıyordu.**

<!-- KONAK-LISTESI-BASLANGIC (infra/alan-adi-denetimi.py kontrol 5 okur;
     elle düzenlerken Caddyfile ile birlikte değiştirin) -->
```
api.yonetio.site
panel.yonetio.site
storage.yonetio.site
yonetio.site
www.yonetio.site
xn--ynetiyor-n4a.com
www.xn--ynetiyor-n4a.com
app.xn--ynetiyor-n4a.com
panel.xn--ynetiyor-n4a.com
```
<!-- KONAK-LISTESI-BITIS -->

| Konak | Ne sunar |
|---|---|
| `yonetio.site`, `www.` | Tanıtım sayfası (statik) + `/gizlilik`, `/kosullar` → admin-web |
| `xn--ynetiyor-n4a.com`, `www.` | Aynısı (yeni birincil alan) |
| `app.xn--ynetiyor-n4a.com` | **Tesis çalışma alanı** (P126.1) — aynı `admin-web`, konaktan tesis yüzeyi |
| `panel.yonetio.site`, `panel.xn--…` | admin-web (yönetim paneli) |
| `api.yonetio.site` | FastAPI |
| `storage.yonetio.site` | MinIO (imzalı URL konağı) |

**Kök neden panelin kendisi değil:** admin-web'in `/` rotası `/dashboard`a,
oradan da `/login`e gider. Kök panele bağlansaydı markanın ana adresi bir
**yönetici giriş ekranı** olurdu. Kök artık statik bir tanıtım sayfası
sunar; hukuki sayfalar ve `/_next/*` varlıkları admin-web'e proxy'lenir
(metinler **kopyalanmaz** — tek kaynak `admin-web/lib/hukuki/`).

## 3) DOĞRULAMA — üç aşamalı

### 3a) SUNUCUDAN, TLS'e hiç girmeden (asıl teşhis burada)

Uzaktan `000` görmek iki çok farklı şeyi aynı gösterir: "Caddy o konağı
tanımıyor" ve "arkadaki uygulama düştü". Host başlığıyla **yerel** curl
ikisini ayırır — sertifika, DNS ve ağ denklemden çıkar:

```bash
C="docker compose -f infra/docker-compose.prod.yml --env-file infra/.env.prod"

# admin-web AYAKTA MI (Caddy'yi hiç kullanmadan)
$C exec caddy wget -qO- --header='Host: panel.yonetio.site' \
    http://admin-web:3000/gizlilik | head -c 120; echo

# Caddy 80'de HANGI konakları tanıyor (ACME yönlendirmesi 308 döner;
# TANIMSIZ konak 404 verir — ayırt edici olan budur)
for h in yonetio.site www.yonetio.site panel.yonetio.site \
         xn--ynetiyor-n4a.com www.xn--ynetiyor-n4a.com \
         app.xn--ynetiyor-n4a.com panel.xn--ynetiyor-n4a.com; do
  printf '%-32s %s\n' "$h" \
    "$(curl -sS -m 10 -o /dev/null -w '%{http_code}' -H "Host: $h" http://127.0.0.1/gizlilik)"
done
```

`308` (HTTPS'e yönlendirme) = konak **tanımlı**. `404` = Caddyfile'da
**yok**, yani dağıtım yapılmamış ya da ad yanlış yazılmış.

### 3b) Sertifikalar gerçekten alındı mı

```bash
$C logs --since 10m caddy | grep -iE "certificate obtained|trying to solve|error|failed|rate limit"
# Caddy'nin deposunda duran sertifikalar:
$C exec caddy ls /data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/
```

Beklenen: yedi konak da listede. Bir konak **eksikse** ACME o ad için
düşmüştür; günlükte gerekçe yazar (en sık: DNS henüz yayılmamış, ya da
80/443 o ada ulaşmıyor).

### 3c) Dışarıdan, gerçek DNS ile

```bash
for h in yonetio.site www.yonetio.site panel.yonetio.site \
         xn--ynetiyor-n4a.com www.xn--ynetiyor-n4a.com \
         app.xn--ynetiyor-n4a.com panel.xn--ynetiyor-n4a.com; do
  printf '%-32s TLS=%-28s /gizlilik=%s\n' "$h" \
    "$(echo | openssl s_client -servername $h -connect $h:443 2>/dev/null \
        | openssl x509 -noout -subject 2>/dev/null | sed 's/subject=//' || echo YOK)" \
    "$(curl -sS -m 20 -o /dev/null -w '%{http_code}' https://$h/gizlilik)"
done

# Unicode giriş de çalışmalı (curl/tarayıcı punycode'a kendisi çevirir)
curl -sS -m 20 -o /dev/null -w 'unicode -> %{http_code}\n' https://yönetiyor.com/gizlilik

# Ve park sayfası KALMAMIŞ olmalı
curl -sS -m 20 https://yonetio.site/gizlilik | grep -qi "Parked Domain" \
  && echo "HALA PARK SAYFASI" || echo "gercek sayfa"
```

Beklenen: yedisinde de sertifika var, `/gizlilik` **200**, "Parked Domain"
yok.

### `000` NE DEMEK — ayırt etme tablosu

`000` "sayfa yok" demek **değildir**; bağlantının HTTP'ye hiç gelemediğini
söyler. En sık sebebi, o konak için Caddy'de **site bloğu olmamasıdır**:
SNI eşleşmeyince TLS el sıkışması `tlsv1 alert internal error` ile düşer.

| Belirti | Anlamı | Yapılacak |
|---|---|---|
| `000`, TLS `internal error` | Konak Caddyfile'da yok **ya da** yeni yapılandırma dağıtılmadı | §2 dağıtım, sonra 3a |
| `000`, bağlantı reddedildi | 80/443 o adrese ulaşmıyor | pfSense yönlendirmesi |
| Sertifika var ama `502` | TLS iyi, `admin-web` düşük | `$C logs admin-web` |
| `404`, sertifika var | Konak tanımlı, rota yok | Next.js rotası |
| `200` ama "Parked Domain" | DNS hâlâ park IP'sinde | A kaydı |

## 4) E-POSTA — destek@yönetiyor.com

**Kendi kutumuzda mail sunucusu YOK ve olmayacak.** Gerekçe: giden posta
itibarı (IP ısıtma, geri bildirim döngüleri, kara liste takibi) tam zamanlı
bir iştir ve tek bir VPS'ten gönderilen posta pratikte spam'e düşer.
Kerem bir posta sağlayıcısı seçecek (Google Workspace, Zoho Mail, Yandex
360, Migadu…). Aşağıdaki kayıtlar **sağlayıcıdan bağımsız iskelettir**;
kesin değerleri sağlayıcı verir.

> **⚠️ MX kaydı kökten gider.** `yönetiyor.com` kökü aynı zamanda web
> sitesini de sunuyor; **A ve MX aynı adda birlikte yaşar**, çakışmazlar.
> Ama kökte **CNAME kullanmayın** — CNAME diğer tüm kayıtları geçersiz
> kılar ve hem siteyi hem postayı düşürür.

| Tip | Ad | Değer (sağlayıcı verir) | Not |
|---|---|---|---|
| MX | `@` | `10 mx1.saglayici.com` | öncelik sayısı değerin başında |
| MX | `@` | `20 mx2.saglayici.com` | yedek |
| TXT | `@` | `v=spf1 include:saglayici.com -all` | **tek bir SPF kaydı** olmalı |
| TXT | `<seçici>._domainkey` | sağlayıcının verdiği public anahtar | DKIM |
| TXT | `_dmarc` | `v=DMARC1; p=none; rua=mailto:dmarc@yönetiyor.com; fo=1` | başlangıç |

### Sıra ve gerekçeler

1. **MX + SPF + DKIM** birlikte girilir; DKIM'siz SPF, alan adı taklidine
   karşı zayıf kalır.
2. **SPF `-all` (hard fail)** seçilir, `~all` değil: yumuşak başarısızlık
   taklit postayı **teslim ettirir**, yalnız işaretler.
3. **DMARC `p=none` ile BAŞLANIR.** Doğrudan `p=reject` yazmak, sağlayıcı
   yapılandırması eksikken **kendi meşru postamızı** çöpe attırır. İki-dört
   hafta `rua` raporları izlenir, hizalama doğrulanınca `p=quarantine` →
   `p=reject` diye ilerlenir.
4. **Tek SPF kaydı.** İkinci bir `v=spf1` TXT'i eklemek SPF'i **tamamen
   geçersiz** kılar (RFC 7208); yeni gönderici eklenecekse mevcut kaydın
   içine `include:` olarak yazılır.

### Uygulamanın gönderdiği posta

Şu an uygulama **kendi başına e-posta göndermiyor**; hukuki belgelerdeki
adresler yalnızca **iletişim** içindir:

* `kvkk@yonetio.site` — `admin-web/lib/hukuki/gizlilik.ts` (7 dil)
* `destek@yonetio.site` — `admin-web/lib/hukuki/kosullar.ts` (7 dil)

**Bu turda değiştirilmediler.** Yayınlanmış bir hukuki belgedeki iletişim
adresini, o kutu **açılmadan** değiştirmek, KVKK başvurusu yapan birinin
postasını boşluğa göndermek olur. Sıra: (1) Kerem kutuları açar,
(2) `kvkk@yönetiyor.com` ve `destek@yönetiyor.com` teslim alıyor mu diye
test edilir, (3) belgeler tek commit'te güncellenir ve eski adresler en az
bir yıl **yönlendirme** olarak açık tutulur.

---

## 5) BİLİNÇLİ OLARAK YAPILMAYANLAR

| Yapılmadı | Neden |
|---|---|
| `yonetio.site` → `yönetiyor.com` 301 yönlendirmesi | İncelemedeki mobil yapımın hukuki belge bağlantılarını ve `api.` alışkanlığını kırardı. İkisi de kanonik kalır. |
| Mobildeki `apiBaseUrl` / `webBaseUrl` değişikliği | Görevde açıkça "bu tur değiştirme" denildi; ayrıca `webBaseUrl` zaten **doğruydu** — eksik olan sunucu tarafıydı, o da düzeltildi. |
| `api.yönetiyor.com` / `storage.yönetiyor.com` | Yukarıda (§1). `storage.` için ikinci konak, imzalı URL doğrulamasını **bozar**. |
| Hukuki belgelerdeki e-posta adresleri | Kutular yok (§4). |
| HSTS preload başvurusu | `includeSubDomains` zaten var; preload listesine girmek **geri dönüşü aylar süren** bir taahhüttür, posta/alt alan yapısı oturmadan yapılmaz. |
