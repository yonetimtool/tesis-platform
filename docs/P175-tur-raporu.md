# P175 — Sihirbaz sahte hatası + yazı tipi yerelleştirme (rapor)

İki iş: **(A)** kurulum sihirbazının "Veriler yüklenemedi" hatası,
**(B)** Google Fonts bağımlılığı ve dış kaynak taraması.

---

# A. "Veriler yüklenemedi" — hipotezin doğruydu, sebebi değil

## 1. Gerçek hata

Tahmin etmedim; **bildirdiğin gövdeyle üretip ekranı okudum**. Sonuç:

```
EKRAN: Kurulum sihirbazı … Veriler yüklenemedi. İlerleme 3/8 adım
       1 Bloklar 4 kayıt … 2 Kat ve daireler 38 kayıt … 3 Daire tipleri 1 kayıt
CAGRILAR: ["/api/panel/kurulum","/api/me"]   KONSOL HATALARI: 0
```

Yani ekran **verileri doğru çiziyor** ve **aynı anda** hata kartını da
gösteriyor. Konsolda istisna yok, çağrı sayısı 2.

Ve gösterilen metin `kurulumHata` ("Kurulum durumu alınamadı") **değil**,
`ortakVeriYuklenemedi` ("Veriler yüklenemedi") — yani hata sihirbazdan
gelmiyordu.

## 2. Kök neden: bileşen sözleşmesi

`components/ui/durumlar.tsx` → `HataDurumu` **hiçbir zaman `null`
dönmüyordu**:

```tsx
<p role="alert">{mesaj || t("ortakVeriYuklenemedi")}</p>
```

Çağıranların çoğu şu kalıbı kullanıyor ve bileşenden **görünmemesini**
bekliyor:

```tsx
<HataDurumu mesaj={hata ?? (error ? t("kurulumHata") : null)} />
```

`mesaj` null olduğunda bile kart çiziliyor ve genel metne düşüyordu —
**"hata yok" demenin bir yolu yoktu.**

**Tarandı: 28 dosyada 39 çağrı yeri** bu kalıbı kullanıyor. Yani o
ekranların hepsi kalıcı bir sahte hata kartı taşıyordu — formlar,
modallar, finans ekranları, profil, bina editörü dahil. Kusur bileşenin
ilk gününden (P160) beri duruyordu; `git log` ile doğrulandı, bu turlarda
girmedi.

**Düzeltme:** `mesaj === null` ise bileşen hiçbir şey çizmiyor. `null` ile
`undefined` **bilinçli olarak ayrı**: alan hiç verilmezse ("hata var ama
metni yok") genel metin çizilmeye devam ediyor — üç çağrı yeri buna
dayanıyor. İkisini tek davranışa indirmek, ya "hata yok"u anlatmanın
yolunu ya da genel metni yok ederdi.

## 3. Şema uyuşmazlığı — **yoktu**

Senin hipotezin ("sözleşmede olan ama yanıtta olmayan bir alan")
ölçüldü ve **doğrulanmadı**: `Durum`/`Adim` arayüzleri yanıtla birebir
uyuşuyor, sekiz `kod` değerinin sekizi de `KURULUM_HEDEFLERI`de tanımlı,
ve bilinmeyen kod zaten `if (!h) return null` ile atlanıyor.

## 4. Yeniden deneme döngüsü

SWR 2.2.5 varsayılanı **sınırsız** (`errorRetryCount` tanımsız): üstel
geri çekilme var ama hiç durmuyor. Merkezde (`SunucuDurumu`) sınırlandı:

* `errorRetryCount: 4`,
* **kalıcı durumlar hiç denenmiyor** — 400/403/404/405/409/422 aynı
  girdiyle aynı sonucu verir; denemek yalnız sunucuya yük bindirir,
* üstel geri çekilme + **seğirme (jitter)**: sabit aralık, aynı anda hata
  alan bileşenleri sunucuya senkron dalgalar hâlinde vurdururdu.

401 listede **yok** ve bu bilinçli: `jsonFetcher` onu zaten karşılıyor
(oturum bitti → `/login`), SWR'ye hiç ulaşmıyor.

## 5. Hata mesajı artık hangi çağrı olduğunu söylüyor

Yazma yolu (`apiSend`) bunu P163'te çözmüştü; **okuma yolu çözmemişti**.
Artık `jsonFetcher` gövdesiz yanıtta durum kodu + **referans** (`GET
/api/panel/kurulum`) üretiyor. Sorgu dizesi atılıyor — hata metni bir
sızıntı yüzeyi değil. 404/405'in P173'teki özel "sürüm ayrışması" metni
korundu, referans ona da eklendi.

Hata nesnesi artık **HTTP durumunu** da taşıyor (`durum`) — yeniden
deneme kararı buna bakıyor.

**Yönü değiştirilen kilit:** `fetcher.test.ts` gövdesiz 500'de
`"Bir hata oluştu."` bekliyordu — yani §4'te değiştirmemiz istenen tam
cümleyi sabitliyordu. Korunan iddia aynı kaldı (`undefined` gösterilmez,
bozuk gövdede bile anlamlı bir cümle çıkar); eklenen şey teşhis. Ayrıca
**sorgu dizesinin referansa girmediği** ayrıca ölçülüyor — hata metni bir
sızıntı yüzeyi değil.

## 6. Kapı: şema doğrulaması eklendi

P173'teki kapı **yalnız yol ve metot** doğruluyordu; doğru tespit.
`uc-sozlesme-kapisi.test.ts`e **(5)** eklendi: arayüzün **zorunlu** ilan
ettiği her alan, sözleşmenin o ucun başarılı yanıtında **vaat ettiği** bir
alan olmalı.

Yön tek taraflı ve bilinçli: sözleşmede olup arayüzün okumadığı alan sorun
değil; tersi kusurdur (`undefined` okunur).

**Mevcut uyuşmazlıklar tarandı: yok.** İlk taramada üç "bulgu" çıktı ve
**hepsi benim ayrıştırıcımın yapaylığıydı** (sayfalama zarfını `{meta,
items}` olarak çözüp öğe şemasına inmemek). Düzeltilince 7 karşılaştırma,
0 uyuşmazlık.

**Kapsam dar ve bu açıkça yazılı:** yalnız `useSWR<Tip>(...)` + aynı
dosyada `interface Tip` biçimindeki çağrılar bağlanabiliyor (satır içi
tipler statik olarak eşlenemiyor). Karşılaştırma sayısı **alt sınırla
kilitli** — kapsam düşerse test kırılır, yani kapı sessizce boşalmaz.

Kırılabildiği kanıtlandı: sihirbazın arayüzüne sözleşmede olmayan bir
`baslik` alanı eklendi → kapı kırıldı.

---

# B. Yazı tipi ve dış bağımlılıklar

## 1. KVKK sorusu — doğrulandı: **çalışma anında Google'a istek gitmiyordu**

Derlenmiş CSS'te `@font-face` kaynakları:

```
src:url(/_next/static/media/ba9851c3c22cd980-s.woff2) format("woff2")
```

`gstatic`/`googleapis` **geçmiyor**. `next/font/google` yazı tipini
**derleme anında** indirip kendi kökenimizden servis ediyordu; kullanıcı
IP'si üçüncü tarafa aktarılmıyordu. Koddaki yorum doğruymuş.

Yani değişen şey gizlilik değil **ağ bağımsızlığı**.

## 2. Yerelleştirme

Yedi alt küme `public/fonts/` altında (toplam 213 KB), lisans
`public/fonts/OFL.txt` (SIL OFL 1.1, kaynağından indirildi).

**`next/font/local` neden seçilmedi:** Inter yedi alt kümeye bölünmüş
(latin, latin-ext, vietnamese, greek, greek-ext, cyrillic, cyrillic-ext)
ve her biri kendi `unicode-range`iyle geliyor — tarayıcı **yalnız ihtiyaç
duyduğunu** indiriyor (Türkçe kullanıcı 47 KB, 213 KB değil).
`next/font/local` `src` dizisinde **per-dosya `unicode-range` kabul
etmiyor**; hepsini aynı aile/ağırlık altında tanımlar ve alt küme bölünmesi
**kaybolurdu**. Panel yedi dilli (Rusça dahil), bu kayıp gerçek.

Kurallar `next/font`ın **ürettiği çıktıdan** alındı: aynı dosyalar, aynı
`unicode-range`ler, aynı `font-display`. **Yedek ölçüler de korundu**
(`size-adjust`, `ascent-override` — düzen kaymasını azaltıyor; atlamak
görünmeyen bir gerileme olurdu). Latin dilimi için `preload` elle eklendi.

Derleme doğrulandı: **8 `@font-face`, 7 yerel woff2, Google referansı yok.**

## 3. Diğer dış kaynaklar — tam liste

| Kaynak | İstek gidiyor mu | Karar |
|---|---|---|
| Google Fonts | **Hayır** (derleme anıydı) | **Yerelleştirildi** |
| `tile.openstreetmap.org` | **Evet** — NFC/plan haritalarında, kullanıcının tarayıcısından | IP + bakılan koordinat OSM'e ulaşıyor. `NEXT_PUBLIC_KARO_URL` ile kendi karo sunucumuza çevrilebilir — **KVKK için önerilen yol**; karar senin |
| `www.google.com` (Maps embed) | **Hayır** — `SiteHarita` hiçbir ekranda çizilmiyor | P167'de bileşen **bilerek korunmuştu**; silmedim. Çizildiği gün Google iframe'i kullanıcı tarayıcısından yüklenir — **o gün karar gözden geçirilmeli** |
| `www.openstreetmap.org` (embed) | **Hayır** — aynı bileşen | Aynı koşul |
| `youtube.com` | **Hayır** — kamera adresi **reddetme** listesi | Adres hiç çağrılmıyor |
| `play.google.com` / `apps.apple.com` | Kullanıcı tıklamadan **hayır** | Mağaza bağlantısı |
| `cloudflareinsights` | Bizim kodumuzda **yok** | Cloudflare vekilinin enjeksiyonu; senin tespitin doğru |

**Kapı:** `tests/dis-bagimlilik.test.ts` — `next/font/google` ithali
yasak, yedi woff2 depoda ve boyutlu, alt küme bölünmesi korunuyor, lisans
yerinde, derlenmiş CSS'te Google referansı yok, ve **yeni bir dış kaynak
eklenirse test kırılıyor**. Her allowlist girişi "istek gidiyor mu"
sorusunu açıkça yanıtlıyor — *kodda geçen adres* ile *kullanıcıdan çıkan
istek* aynı şey değil.

---

## Test sunucusunda ne kontrol edeceksin

1. Kurulum sihirbazını aç — **hata kartı olmamalı**, ilerleme görünmeli.
   Aynı şeyi profil, finans modalları ve bina editöründe de gör: oralarda
   da kalıcı sahte hata vardı.
2. Ağı kesip `docker compose build admin-web` — derleme **geçmeli**.
3. Tarayıcı Network → yazı tipleri `/fonts/inter-*.woff2` adresinden
   gelmeli; `fonts.gstatic.com` **hiç görünmemeli**. Türkçe arayüzde
   yalnız `inter-latin` (+ gerekiyorsa `latin-ext`) inmeli.
4. Bir uç kasten bozulursa (404) ekran artık **hangi çağrı** olduğunu
   yazmalı ve istek **dört denemeden sonra durmalı**.
