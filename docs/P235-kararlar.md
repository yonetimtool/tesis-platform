# P235 — vardiya modalı birleştirme + mobil paket + Cloudflare adımları

---

## §1 — Vardiya ekleme: web'de iki ekran vardı

### Ölçüm

**Web'de iki ayrı giriş, iki ayrı bileşen:**

| Düğme | `data-test` | Açtığı | Ne yapıyor |
|---|---|---|---|
| Üstte "Vardiya ekle" | `vardiya-yeni` | `page.tsx` içindeki `<Modal>` (1025–1183) | kişi → **başlangıç/bitiş tarihi** → saatler → not. Takvim YOK, çok grup YOK |
| Altta "Kalıp uygula" | `vardiya-kalip-ac` | `components/vardiya/kalip-modali.tsx` (586 satır) | takvimden gün seçilmiş olmalı; kalıp (dilimler) + dilim başına personel + rotasyon |

**Mobilde tek akış** (`_HizliEkleDialogu`, `vardiya_plani_screen.dart`):

1. personel (açılır liste)
2. **`GunTakvimi`** — günler takvimden seçilir
3. seçili gün sayısı + "seçimi temizle"
4. başlangıç/bitiş **tarihi** — takvim boşken çalışan aralık kipi
5. başlangıç/bitiş **saati**
6. not
7. **"Gruba ekle"** (P232 çok gruplu yapı: "pazartesi gündüz, salı-çarşamba gece")
8. önizleme (kaç vardiya oluşacak) → gönder

Yani mobilde **takvim + çok grup** var, web'in üst modalında **ikisi de
yok**. Kullanıcının gördüğü fark tam olarak buydu.

### Yapılan: web mobile eşitlendi, TEK modal

`components/vardiya/vardiya-ekle-modali.tsx` yazıldı; **iki düğme de onu
açıyor**. Akış mobildekiyle aynı sırada:

1. **takvim** (modalın içinde, ay ızgarası) → günler
2. seçili gün sayısı + "seçimi temizle"
3. **kalıp**: "Serbest saat" (varsayılan) ya da kayıtlı kalıp
4. serbest saatte kişi + başlangıç/bitiş **saati**; kalıpta **dilim başına** kişi
5. tarih aralığı (takvim boşken — mobildeki fallback'in aynısı)
6. **"Bu grubu ekle"** → biriken gruplar (P232)
7. rotasyon · not
8. önizleme → gönder (çakışma akışı)

**İki gönderim yolu, mobildekinin aynısı:** grup yoksa ve kalıp
seçilmemişse `/toplu` (tekil kip), aksi hâlde `/kalip-uygula` (çok
gruplu). İkisi de yaşıyor — birini kapatmak **yayındaki mobil sürümleri
kırardı**.

### Silinen ölü kod

| Ne | Satır |
|---|---|
| `components/vardiya/kalip-modali.tsx` | **586 → silindi** |
| `page.tsx` içindeki `HizliEkle` fonksiyonu | **~240 → silindi** |
| `page.tsx` toplam | 1185 → **946** |

### Kalıp ve rotasyon KAYBOLMADI

`kalip-modali.tsx`in iki yeteneği yeni modala **taşındı**: kayıtlı kalıp
(gün içinde birden çok dilim) ve rotasyon (haftalık kaydırma). Bunları
atmak "birleştirme" değil **özellik silme** olurdu; istek ekranların
birleşmesiydi.

### Ölçüm sırasında çıkan iki gerçek kusur

1. **Şerit seçimi modala hiç aktarılmıyordu.** Başlangıç değerini
   `useState(() => new Set(prop))` ile vermiştim; modal sayfada **hep
   monteli** duruyor (`acik` bir prop), yani o başlatıcı yalnız bir kez —
   modal kapalıyken ve prop boşken — çalışıyordu. Kullanıcı çizelgede
   günleri işaretleyip "Kalıp uygula"ya basınca modal **boş** açılırdı.
   `acik` kenarında çalışan bir efekte taşındı.
2. **"Geri al" düğmesi hiç çıkmıyordu.** Birleştirmede `onUygulandi →
   setSonParti` geri çağrısını düşürmüşüm. Otuz günlük yanlış planı tek
   tek silmemek isteğin kritik şartıydı; `onParti` olarak geri kondu.

İkisini de testler yakaladı.

### Parite durumu — açıkça

| Yetenek | Web | Mobil |
|---|---|---|
| Takvimden gün seçimi | ✅ | ✅ |
| Aralık kipi (bas/son tarih) | ✅ | ✅ |
| Çok gruplu plan (P232) | ✅ | ✅ |
| Önizleme + çakışma akışı | ✅ | ✅ |
| Kayıtlı kalıp (çok dilim) | ✅ | ❌ |
| Rotasyon (haftalık) | ✅ | ❌ |

**Son iki satır ÖNCEDEN VAR OLAN bir boşluk** — bu tur üretmedi, çünkü o
iki yetenek zaten yalnız web'deki `kalip-modali.tsx`teydi. Bu turda
istenen şey web'deki **iki ekranın birleşmesiydi** ve o yapıldı; mobile
kalıp/rotasyon eklemek ayrı bir iştir ve **yapılmadı** olarak
bildiriyorum.

---

## §Cloudflare — onaylanan kararın uygulama adımları

Karar (P234 §3'te önerildi, bu turda **onaylandı**):

| Alan adı | Bulut | |
|---|---|---|
| `yonetiyor.com`, `www` | 🟠 turuncu | proxy |
| `panel.yonetiyor.com` | 🟠 turuncu | proxy |
| `app.yonetiyor.com` | 🟠 turuncu | proxy |
| `api.yonetiyor.com` | ⚪ gri | **canlı kamera akışı** — CF ŞS 2.8 |
| `api.yonetio.site` | ⚪ gri | yayındaki mobil sürümler |
| `storage.yonetio.site` | ⚪ gri | presign imzası + 100 MB gövde sınırı |
| **tüm posta kayıtları** | ⚪ gri | aşağıda — **en kritik madde** |

SSL/TLS modu: **Full (strict)**.

### ⚠️ POSTA KAYITLARI — biri turuncu olursa posta TAMAMEN durur

Resend geçişi sürüyor. **Gri kalması gereken kayıtların tamamı:**

| Tip | Ad | Not |
|---|---|---|
| `MX` | `@` (kök) | Google Workspace |
| `MX` | `send.…` | Resend bounce toplama |
| `TXT` | `@` | SPF (Google + Resend) |
| `TXT` | `send.…` | Resend SPF |
| `TXT` | `dkim._domainkey` | DKIM |
| `TXT` | `resend._domainkey` | Resend DKIM |
| `TXT` | `_dmarc` | DMARC |
| `CNAME` | `rsend` | Resend |
| `CNAME` | `send` | Resend |

**Teknik gerçek:** `MX` ve `TXT` kayıtları Cloudflare'de **zaten
proxy'lenemez** — turuncu bulut seçeneği çıkmaz. Gerçek tehlike
**`CNAME`lerde** (`rsend`, `send`): Cloudflare CNAME'leri **varsayılan
olarak turuncuya alır** ve turuncu bir `send` kaydı, `MX`in işaret ettiği
adı Cloudflare IP'sine çözer → **gelen/giden posta zinciri kopar.**

İçe aktarmadan **hemen sonra** bu ikisini gri yap.

#### Kontrol komutu — posta kayıtları gerçekten gri mi

```bash
# Turuncu = Cloudflare IP'sine cozulur (104.x / 172.67.x / 188.114.x ...)
# Gri     = gercek hedefine cozulur
for ad in send rsend; do
  printf '%-8s -> ' "$ad"
  dig +short "$ad.yonetiyor.com" | tr '\n' ' '
  echo
done

# MX ve TXT hic proxy'lenemez ama DEGERLERI dogru mu:
dig +short MX  yonetiyor.com
dig +short MX  send.yonetiyor.com
dig +short TXT yonetiyor.com                    # SPF
dig +short TXT send.yonetiyor.com               # Resend SPF
dig +short TXT resend._domainkey.yonetiyor.com  # Resend DKIM
dig +short TXT dkim._domainkey.yonetiyor.com    # DKIM
dig +short TXT _dmarc.yonetiyor.com             # DMARC
```

`send` / `rsend` satırlarında **104.21.x / 172.67.x / 188.114.x** gibi bir
adres görürsen o kayıt **turuncudur ve postayı kırar** — Cloudflare
panelinde bulutu griye çevir.

### Ad sunucusu taşıma — öncesi/sonrası karşılaştırma

Hostinger → Cloudflare geçişinde Cloudflare kayıtları **otomatik tarar**
ama bu tarama **eksiksiz değildir**: `TXT` kayıtlarının uzun olanları,
`SRV`, ve bazı `CNAME`ler atlanabiliyor.

**1) TAŞIMADAN ÖNCE — mevcut kayıtları dosyala** (Hostinger hâlâ
yetkiliyken):

```bash
cd ~ && mkdir -p dns-yedek && cd dns-yedek
AD=yonetiyor.com
NS=$(dig +short NS $AD | head -1)      # su anki yetkili sunucu
echo "yetkili: $NS"

for t in A AAAA CNAME MX TXT NS SRV CAA; do
  echo "--- $t"
  dig +noall +answer "@$NS" "$AD" $t
done > oncesi-kok.txt

# ALT ALANLAR — bildiklerimizi tek tek sor (zone transfer genelde kapali)
for alt in www api panel app storage mail send rsend \
           dkim._domainkey resend._domainkey _dmarc; do
  for t in A AAAA CNAME MX TXT; do
    dig +noall +answer "@$NS" "$alt.$AD" $t
  done
done > oncesi-alt.txt

wc -l oncesi-kok.txt oncesi-alt.txt
```

**2) TAŞIMADAN SONRA — aynı komutları Cloudflare'e sor:**

```bash
cd ~/dns-yedek
AD=yonetiyor.com
CF=$(dig +short NS $AD | head -1)      # artik *.ns.cloudflare.com olmali
echo "yetkili: $CF"

for t in A AAAA CNAME MX TXT NS SRV CAA; do
  echo "--- $t"
  dig +noall +answer "@$CF" "$AD" $t
done > sonrasi-kok.txt

for alt in www api panel app storage mail send rsend \
           dkim._domainkey resend._domainkey _dmarc; do
  for t in A AAAA CNAME MX TXT; do
    dig +noall +answer "@$CF" "$alt.$AD" $t
  done
done > sonrasi-alt.txt
```

**3) KARŞILAŞTIR:**

```bash
cd ~/dns-yedek
# TTL ve A kayitlari DEGISECEK (turuncu olanlar CF IP'sine doner) —
# karsilastirmada TTL'i ve A/AAAA'yi disarida tutup GERI KALANI esitle.
norm() { awk '{$2=""; print}' "$1" | grep -viE '[[:space:]](A|AAAA)[[:space:]]' | sort -u; }
diff <(norm oncesi-kok.txt) <(norm sonrasi-kok.txt)
diff <(norm oncesi-alt.txt) <(norm sonrasi-alt.txt)
```

**Boş çıktı = MX/TXT/CNAME/CAA kayıtları birebir taşındı.** Fark çıkan her
satırı Cloudflare panelinde elle ekle.

`A`/`AAAA` kayıtları bilinçli olarak karşılaştırma dışında: turuncu olanlar
**zaten** Cloudflare IP'sine dönecek — orada fark görmek beklenen sonuçtur.
Gri kalması gerekenleri ayrıca doğrula:

```bash
for alt in api storage; do
  printf '%-8s -> ' "$alt"; dig +short "$alt.yonetiyor.com" | tr '\n' ' '; echo
done
dig +short api.yonetio.site
dig +short storage.yonetio.site
# Hepsi SUNUCUNUN GERCEK IP'sini gostermeli (188.114.x / 104.21.x DEGIL).
```

### Sıra

1. **Taşımadan önce** yukarıdaki `oncesi-*.txt` dosyalarını üret. Bu adım
   atlanırsa karşılaştıracak bir şey kalmaz.
2. Cloudflare'e alan adını ekle, taramanın bulduklarını **`oncesi-*` ile
   karşılaştır**, eksikleri elle gir.
3. **Her şey griyken** ad sunucularını Hostinger'da Cloudflare'inkilerle
   değiştir. (Önce gri: turuncuya almadan önce zincirin çalıştığını gör.)
4. Yayılmayı bekle (`dig +short NS yonetiyor.com` → `*.ns.cloudflare.com`).
5. `sonrasi-*.txt` üret, **diff'i temizle**.
6. Posta kontrol komutunu çalıştır — `send`/`rsend` **gri** olmalı.
7. Kendine test e-postası gönder (davet/parola sıfırlama) — **geldi mi?**
8. **Şimdi** turuncuya al: `yonetiyor.com`, `www`, `panel.`, `app.`.
9. SSL/TLS modunu **Full (strict)** yap. `Flexible` sonsuz yönlendirme
   döngüsü üretir ve son bacağı şifresiz bırakır.
10. Panel + tanıtım sitesini aç, sertifika zincirini ve girişi doğrula.
11. Bir hafta boyunca posta akışını izle.

### Caddy tarafı — `trusted_proxies`

`infra/Caddyfile`e `(cf_gercek_ip)` snippet'i eklendi: turuncu konaklarda
`CF-Connecting-IP`yi gerçek istemci adresi olarak kabul eder, güvenilen
vekil listesini Cloudflare'den **12 saatte bir tazeler** (elle yazılmış
liste sessizce eskir ve o an gerçek IP kaybolur).

**Bugün bunu kullanan bir yer YOK** (ölçüldü: hız sınırlama telefon/e-posta
ekseninde, `audit_log`da IP sütunu yok). Şimdi konmasının sebebi: ileride
IP'ye bakan bir şey yazan kişi, bunun Cloudflare IP'si olduğunu fark
etmeden yazar ve **sessizce yanlış çalışırdı**.

**Snippet henüz hiçbir konakta `import` EDİLMEDİ ve bu bilinçli:**
`trusted_proxies cloudflare` bir **Caddy modülü** gerektiriyor
(`caddy-cloudflare-ip`) ve standart imajda yok — `import` etsem Caddy
**hiç başlamazdı**. Turuncuya geçtiğinde iki şey gerekiyor:

```bash
# 1) Modullu Caddy imaji (infra/Dockerfile.caddy olarak eklenebilir)
FROM caddy:2-builder AS builder
RUN xcaddy build --with github.com/WeidiDeng/caddy-cloudflare-ip
FROM caddy:2
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

# 2) Turuncu konak bloklarina tek satir:
#    import cf_gercek_ip
```

Bunu **turuncuya geçtikten sonra** yapmak doğru: gri kalan bir kurulumda
modülü eklemek, çözdüğü sorun ortada yokken imajı değiştirmek olurdu.
