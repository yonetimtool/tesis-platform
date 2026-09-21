# P244 — Arayüz yeniden tasarımı · KARARLAR

Plan: `docs/P244-arayuz-plani.md`. Bu dosya **aşama 0**: sekiz sorunun
yanıtı, yanıtlar üzerine yapılan ölçümler ve bağlayıcı kararlar.

---

## 0. AŞAMA 0'DA YAPILAN ÜÇ ÖLÇÜM

Üç yanıt, doğrulanmadan uygulanamayacak bir varsayım içeriyordu. Üçünü de
ölçtüm; **ikisi varsayımı düzeltti.**

### 0.1 Şikayet Haritası — BENİM HATAM, ekran VAR

Planda "şikayet haritası yok" yazmıştım. **Yanlış.**

`lib/menu.ts:252` → `{ href: "/schematic", anahtar: "kabukSikayetHaritasi",
icon: "pin", grup: "tesis" }`

Ekran `/schematic` adresinde, 420 satır, `PlanHaritasiYukleyici` + yoğunluk
renkleri (`yesil/sari/kirmizi`, eşik **sunucuda**) + daire başına şikâyet
listesi + şema/harita görünüm anahtarı ile çalışıyor.

Hatanın kaynağı: rota adı İngilizce (`/schematic`), menü etiketi Türkçe
("Şikayet Haritası"). Rota listesini okurken eşleştiremedim ve **menü
anahtarına bakmadım**. Planı düzelttim.

> **Ders:** rota adından ekranın ne olduğuna karar verme; menü anahtarına
> bak. Bu depoda 79 rotanın bir kısmı İngilizce adla, Türkçe etiketle yaşıyor.

**Karar:** yeni ekran yapılmayacak. Şikayet Haritası mevcut ekran olarak
D grubunda (tesis operasyonu) yeniden tasarlanacak.

### 0.2 Inter — ZATEN KURULU, ama İKİ YAZI TİPİ AYNI ANDA YAŞIYOR

"Inter'e geç" dediniz. **Inter P175'ten beri kurulu:** `app/yazi-tipi.css`,
yerel barındırma, 7 alt küme, değişken ağırlık 100–900, `font-display: swap`,
SIL OFL lisansı `public/fonts/OFL.txt`.

| soru | yanıt |
|---|---|
| düzen bozulur mu? | **Hayır** — bugün zaten Inter'le çiziliyor |
| dosya boyutu ne kadar artar? | **0 KB** — dosyalar zaten `public/fonts` içinde |

Türkçe kullanıcının indirdiği: `inter-latin.woff2` 47 KB +
`inter-latin-ext.woff2` 83 KB = **130 KB** (ğ/ş `latin-ext`te, ı/ü/ö/ç
`latin`te). Rusça kullanıcı ayrıca `cyrillic` 18 KB alır. Tarayıcı
`unicode-range` sayesinde yalnız gerekeni indirir.

**Ama ölçüm bir kusur buldu:**

| kaynak | yazı tipi |
|---|---|
| `--yz-font` (yeni dil) | `Inter, "Inter Yedek", ui-sans-serif, …` |
| `tailwind.config.ts` → `fontFamily.sans` (eski dil) | **sistem yığını** (`-apple-system, BlinkMacSystemFont, Segoe UI, Roboto…`) |

Yani **ürün bugün iki yazı tipiyle birden çiziliyor**: `--yz-font` kullanan
yüzeyler Inter, Tailwind `font-sans` kullanan eski yüzeyler işletim sistemi
yazı tipi. Windows'ta Segoe UI, macOS'ta SF Pro.

Bu, "arayüz tutarsız / şablon gibi" şikâyetinin ölçülebilir bir parçası ve
**tasarım tercihi değil, kusur**.

**Karar:** aşama 1'de `fontFamily.sans` Inter'e bağlanır. Tek yazı tipi.

### 0.3 Dokunma hedefi — 44, "sızıntı" DEĞİL; başka bir standart

"Kodda 44 ise o bir kusur, P220'de 48 kararı verilmişti, muhtemelen başka bir
yerden sızmış" dediniz. Ölçtüm:

| | kaynak | standart |
|---|---|---|
| **Web 44 px** | `tasarim-sistemi.css:454`, **P169 §5** | WCAG 2.1 **SC 2.5.5 (AAA)** = 44×44 CSS px · Apple HIG 44 pt |
| **Mobil 48×48** | `docs/P220-kararlar.md:416` | **Flutter'ın kendi erişilebilirlik kilidi**: *"Tappable objects should be at least 48×48"* = Android Material tap target |

P220'nin 48 kararı **mobil tarafta ve Flutter'ın `androidTapTargetGuideline`
kilidi yakaladığı için** alınmış — `visualDensity: compact` verilen bir düğme
40×40'a düşmüştü. Web'e dair bir karar değil.

Yani 44 bir yerden sızmadı; **iki yüzey iki farklı platform standardını
uyguluyor** ve ikisi de savunulabilir (WCAG AA tabanı zaten 24 px — SC 2.5.8;
44 AAA, 48 Material).

**Yine de 48'i uyguluyorum** — talimat net ve 48 üçünün en sıkısı. Kaydı
düzeltmemin sebebi "birleştir" sözünün ne anlama geldiğini değiştirmesi:
birleştirilecek bir sızıntı yok, **bilinçli olarak daha sıkı eşiğe geçiyoruz.**

**Uygulanabilirlik ölçüldü — genel `min-width: 48px` VERİLEMEZ:**

| ekran | takvim gün hücresi | 44 sığar mı | 48 sığar mı |
|---|---|---|---|
| 320 px | 33.1 px | hayır | hayır |
| 360 px | 38.9 px | hayır | hayır |
| 390 px | 43.1 px | hayır | hayır |

Ay takvimi ızgarası (7 sütun) dar ekranda **bugün de 44'ü tutmuyor**;
P170 §4.3 bunu ölçüp bilinçli istisna yapmış (genel `min-width` ızgarayı
taşırıyordu).

**Karar:**
* `min-height: 44px → 48px` — **genel**, dikey alan bedava.
* `min-width` **opt-in kalır**: `.yz-dokunma-44` → `.yz-dokunma-48`.
* Takvim hücresi istisnası **sürer ve belgelenir**; hücre artık `39×48`
  olur (bugün `39×39`) — tam çözüm değil ama ölçülebilir iyileşme.
* **Açık kalan:** dar ekranda ay takvimi 48×48'i tutamıyor. Çözümü ayrı bir
  iş (yatay kaydırma ya da hafta görünümü); bu turda kapsam dışı.

---

## 1. SEKİZ SORUNUN KARARA DÖNMÜŞ HÂLİ

| # | konu | karar |
|---|---|---|
| 1 | Kenar çubuğu | **`ui3` katlanır gruplar.** 84 öğe düz listede çalışmaz. `ui5`'in görsel dili korunur: grup başlıkları, ikon tutarlılığı, güçlü aktif durum. **Aktif grup açık kalır** ve kullanıcı hangi grupta olduğunu kaybetmez |
| 2 | Bölüm varsayılanı | Katlanır; aktif grup otomatik açık |
| 3 | Mobil parite | **Anlamsal token'lar** (durum renkleri, metin, vurgu) parite İÇİNDE; **kabuk token'ları** (kenar çubuğu, zemin) parite DIŞINDA. Mobilin kabuğu zaten farklı |
| 4 | Yazı tipi | Inter — **zaten kurulu**; yapılacak iş Tailwind'i ona bağlamak (§0.2) |
| 5 | Dokunma hedefi | 48 px; `min-height` genel, `min-width` opt-in; takvim istisnası belgeli (§0.3) |
| 6 | 3B maket | **Etkileşim aynen korunur.** Sahne (`bina-sahnesi`, `site-palet`, `site-yerlesim`) yerinde kalır; çerçeve, segment seçici, yüzen kontroller ve efsane yeni dile uyar |
| 7 | Aşamalandırma | Aşama 0 (karar) ve aşama 4 (karma sayfa temizliği) ayrı kalır |
| 8 | İki tasarım dili | Geçiş **bitirilecek**; 18 karma sayfa temizlenip tek dil kalır |

**Ek genel kural:** *bu turda yeni ekran yapılmayacak.* Referansta olup bizde
olmayan bir şey çıkarsa listelenir, ayrı turda değerlendirilir.

### 1.1 Referansta olup bizde olmayan — güncel liste

§0.1'den sonra liste **boşaldı**:

| referans ekranı | bizdeki karşılığı |
|---|---|
| Şikayet Haritası | `/schematic` ✔ |
| Gürültü Uyarıları | `/gurultu-uyarilari` ✔ |
| Şeffaflık Panosu ("Selfak Panosu") | `/transparency` ✔ |
| Karar Defteri | `/karar-defteri` ✔ |
| Doküman Yönetimi | `/dokumanlar` ✔ |
| Ziyaretçiler | `/ziyaretciler` ✔ |
| Banka Entegrasyonu | `/finans/banka` ✔ |
| Otomasyon | `/finans/otomasyon` ✔ |
| Kurulum Sihirbazı | `/kurulum` ✔ |

**Eksik ekran yok.** Referans bizim ekranlarımızı daha zengin çiziyor, yeni
ekran getirmiyor.

---

## 2. AŞAMA 1 SÖZLEŞMESİ — TOKEN KATMANI

Aşama 1'in kapsamı ve **dağıtılabilirlik sözü**: token değerleri değişir,
bileşen API'si değişmez. Değişiklik 79 sayfaya **aynı anda** iner, hiçbir
sayfa yarım kalmaz.

### 2.1 Değişecek değerler

| token | bugün | P244 | gerekçe |
|---|---|---|---|
| `--yz-bg-sidebar` | `#d8e4f5` açık mavi | **lacivert** | referansın en görünür kararı |
| `--yz-bg-app` | `#eef1f6` | `#eef2f7` | kart/zemin kademesi korunur |
| `--yz-accent` | `#5b8def` soluk | `#2563EB` | referans |
| `--yz-success` | `#3fa97a` | `#16a34a` | referans |
| `--yz-warning` | `#d6963c` | `#f59e0b` | referans |
| `--yz-danger` | `#d45b5e` | `#ef4444` | referans |
| `--yz-border` | `#dbe2ea` | referanstan **koyu** | kilit ≥1.5 (plan §1.6) |
| `--yz-raised` / `--yz-sunken` / `--yz-metal-*` | neumorphism | **düz** | referans düz |
| `--yz-fs-*` | mevcut ölçek | 24/18/16/14/13/12 | referans |
| dokunma hedefi | 44 | 48 | §0.3 |
| `fontFamily.sans` | sistem yığını | Inter | §0.2 |

### 2.2 Değişmeyecekler

* **Eşikler.** AA 4.5 / grafik 3.0 / kenarlık 1.5 / kart-zemin kademesi.
  Renk değeri eşiğe uyar; eşik renge uymaz.
* **`-ink` ve `-edge` mekanizması.** Referans paleti ham hâliyle AA'yı
  tutmuyor (warning metin 2.15, grafik 2.15). Ham ton görsel kimlikte kalır;
  metin `-ink`, anlamlı çizgi `-edge` kullanır.
* **Koyu tema.** Referans yalnız açık temayı çiziyor ama koyu tema yayında bir
  özellik (P190 §5, hesapta kalıcı). İki tema da yeni palete taşınır.
* **Görünüm modu (Standart/Büyük).** `:root.yz-buyuk` korunur; yeni her ölçü
  token'ı orada da tanımlanır — **bunu yeni bir kilitle bağlıyorum.**
* Bileşen adları ve API'leri. Aşama 1 yalnız değer katmanıdır.

### 2.3 Aşama 1'de güncellenecek kilitler

| kilit | ne yapılacak | neden |
|---|---|---|
| `tasarim-token` — mobil parite | **İKİYE BÖLÜNÜR**: anlamsal token'lar parite içinde kalır, kabuk token'ları parite dışına çıkar; gerekçe teste yazılır | karar 3 |
| `yz-token-kontrast` | yeniden ölçülür, **eşikler aynı** | renk değişti, kural değişmedi |
| **YENİ** `p244-olcek-paritesi` | her `--yz-fs-*` ve kontrol yüksekliğinin `.yz-buyuk`ta da tanımlı olduğunu ölçer | büyük mod sessizce eksik kalmasın |

Her güncellenen kilit **kırılarak** hâlâ ayırt ettiği doğrulanacak. Eşik
düşürerek geçen kilit kabul edilmiyor.

---

## 3. PLANDA DÜZELTİLENLER

| plan yeri | eski | yeni |
|---|---|---|
| §3 D grubu | "şikayet haritası **yok**" | `/schematic` olarak **var**, yeniden tasarlanacak |
| §3 B grubu | `/schematic` yalnız "şematik görünüm" sanılmıştı | Şikayet Haritası olduğu için **D grubuna** taşındı |
| §2 yazı tipi | "emin değilim, sorayım" | Inter zaten kurulu; iş Tailwind'i bağlamak |
| §6 dokunma hedefi | "44 var, 48 isteniyor, sormadan yapmadım" | 48'e geçiliyor; 44'ün kaynağı sızıntı değil (§0.3) |
| §7 soru 7 | "yalnız Şikayet Haritası eksik gibi" | **eksik ekran yok** |

---

# AŞAMA 1 — TASARIM SİSTEMİ · UYGULANDI

Kapsam sözü tutuldu: **yalnız değer katmanı değişti, bileşen API'si
değişmedi.** 79 sayfaya aynı anda indi, hiçbir sayfa yarım kalmadı.

## A1.1 Değişen token'lar

| token | eski | yeni | ölçüm |
|---|---|---|---|
| `--yz-bg-sidebar` | `#d8e4f5` | **`#14263a`** | içerikten 13.15 ayrışır |
| `--yz-bg-app` | `#eef1f6` | `#eef2f7` | kart/zemin 1.124 |
| `--yz-surface-2` | `#eff3f8` | `#eaeff5` | karttan 1.156 (eşik 1.1) |
| `--yz-surface-sunken` | `#e7ecf2` | `#e2e8f0` | |
| `--yz-border` | `#dbe2ea` | `#dde4ec` | 1.28 (eşik 1.15) |
| `--yz-accent` | `#5b8def` | **`#2563eb`** | |
| `--yz-success` | `#3fa97a` | `#16a34a` | |
| `--yz-warning` | `#d6963c` | `#f59e0b` | |
| `--yz-danger` | `#d45b5e` | `#ef4444` | |
| `--yz-fs-h3` | 15 px | **16 px** | referansın "Section" kademesi |
| `--yz-fw-kpi` | 300 | **700** | ince rakam zayıf okunuyordu |
| dokunma hedefi | 44 px | **48 px** | |
| `fontFamily.sans` | sistem yığını | **Inter** | §0.2'deki kusur |

Yeni aile: `--yz-sidebar-{text,text-2,label,border,hover,active,active-ink,marker}`
— iki temada da tanımlı.

Düzleşenler: `--yz-raised`, `--yz-raised-hover`, `--yz-sunken`,
`--yz-metal-1/2/accent`, `--yz-bg-app-grad`, `--yz-border-shine`.
**Adlar korundu** (50+ dosya okuyor); artıkların temizliği aşama 10'da.

## A1.2 Ölçüm üç kez beni düzeltti

1. **En zor yüzeyi yanlış varsaydım.** `ink`/`edge` tonlarını sayfa
   zeminine (`#eef2f7`) göre türetmiştim; oysa en zor yüzey
   `--yz-surface-sunken` (`#e2e8f0`). Kilit dördünü birden düşürdü
   (`accent-ink` 4.43, `success-edge` 2.92). Yeniden türetim **tüm yüzey
   kümesini** tarayarak yapıldı.
   > **Ders:** en zor yüzeyi varsayma, kümeyi tara.
2. **`--yz-surface-2`'yi fazla açık seçtim** (`#f5f8fb`, karttan 1.066 —
   eşik 1.1). Kart kademesi görünmez olurdu; P166'da ölçülen kusurun
   aynısı.
3. **Kenarlık kilidinin eşiğini planda yanlış aktarmıştım.** Testin
   *başlığı* ">=1.5" diyor ama *iddiası* `>=1.15`. Planda "referans
   kenarlığı kilidi kırıyor" yazmıştım — **kırmıyordu**. Başlık
   düzeltildi.

## A1.3 Öngörülen en büyük risk GERÇEKLEŞMEDİ

Planda "`tasarim-token.test.ts` **toplu kırılır**" demiştim. **Kırılmadı
— 28/28 geçti.** Sebep: o test `tailwind.config.ts` + `globals.css`
(eski dil) ile mobil Dart token'larını eşitliyor; yeni `--yz-*` katmanını
hiç okumuyor.

Yani mobil parite bölünmesi (karar 3) **şimdi gerekmedi**; gerekeceği yer
aşama 10 (eski dilin emekliliği). Karar geçerli, uygulaması ertelendi.

## A1.4 Aktif menü öğesi — renk tek başına anlam taşımıyor

Ölçüldü: `#2563eb` lacivert üzerinde **2.97** (arayüz bileşeni eşiği 3.0
altında) ama üzerindeki beyaz metin **5.17**. `#3b82f6` tersini yapıyor:
laciverde karşı 4.17, beyaz metin **3.68** (okunmuyor). **Tek bir mavi
ikisini birden tutmuyor.**

Çözüm referansın yapmadığı şey: dolgu referans tonunda kalır, aktiflik
ayrıca **sol işaret çubuğu** (`--yz-sidebar-marker`, laciverde karşı 6.04)
ve `aria-current` ile anlatılır. Üç ayrı ipucu.

## A1.5 Kilitler

| kilit | ne oldu |
|---|---|
| `yz-token-kontrast` | `bg-sidebar` içerik yüzeyi kümesinden **çıkarıldı**, yerine kenar çubuğu ailesini **aynı eşiklerle** ölçen iki yeni test geldi. Test sayısı 24 → **28**: kapsam düşmedi, büyüdü. Eşik düşürülmedi |
| `tasarim-token` | **dokunulmadı**, 28/28 geçiyor |
| `p226-select-gradyan` | Gradyanlar düzleşince tarama listesi boşaldı ve kilit **boşa geçmeyi reddetti** — doğru davranış. Test silinmedi: iddia "liste dolu olmalı"dan "tarayıcı gerçekten çalışıyor + bugün gradyan yok"a taşındı. Biri yarın gradyan eklerse kilit yine yakalar |
| **YENİ** `p244-olcek-paritesi` | Her `--yz-fs-*`'ın büyük modda tanımlı **ve gerçekten daha büyük** olduğunu ölçer |

**Dört kilit de kırılarak doğrulandı:** yeni ölçü token'ını büyük modda
tanımsız bırakmak, büyük modda aynı değeri kopyalamak, `warning-ink`'i ham
tona düşürmek, bölüm etiketini referans tonuna (4.41) düşürmek, gradyan
token'ını geri getirmek — hepsi ilgili testi düşürdü.

## A1.6 Bu aşamada YAPILMAYAN

* **Kenar çubuğu çizimi.** Token'lar hazır; `AppShell`'in laciverde
  taşınması **aşama 2**. Bugün kenar çubuğu yeni lacivert token'ı
  kullanıyor ama içindeki metin renkleri hâlâ genel token'larda —
  aşama 2'ye kadar kontrast düşük kalabilir. **Bilinçli ve geçici.**
* Bileşen yoğunluğu, filtre çubuğu, detay çekmecesi → aşama 3.
* Ay takvimi dar ekranda 48×48'i tutamıyor (§0.3 açık madde).

## A1.7 Doğrulama

* `npx tsc --noEmit` temiz.
* `npx eslint` 0 hata (4 uyarı, hepsi P244 öncesinden).
* **Tam web takımı: 229 dosya / 1970 test yeşil.**

---

# AŞAMA 2 — KABUK · UYGULANDI

## A2.1 Kenar çubuğu laciverde taşındı

Aşama 1'de token'ı lacivert olmuştu ama çizim kodu hâlâ **içerik**
yüzeylerinin metin token'larını kullanıyordu. Ölçüldü: `--yz-text`
(`#172033`) lacivert üzerinde **1.06** — menü okunmuyordu. Aşama 1'in
sonunda "bilinçli ve geçici" diye kaydettiğim borç buydu; kapandı.

| yer | eski | yeni |
|---|---|---|
| menü satırı (pasif) | `--yz-text-2` | `--yz-sidebar-text-2` |
| menü satırı (aktif) | kabartılmış metal kapsül + `accent-edge` çubuk | **dolu mavi hap** + `--yz-sidebar-marker` çubuk |
| bölüm başlığı | `--yz-text` / `--yz-text-3` | `--yz-sidebar-text` / `--yz-sidebar-label` |
| iç kenarlıklar | `--yz-border` | `--yz-sidebar-border` |
| çıkış düğmesi | beyaz `--yz-metal-1` kart | saydam + ince kenarlık |
| tema anahtarı | beyaz yüzey | kabuk yüzeyi |

**Mobil üst çubuk laciverde çevrilmedi, beyaz oldu.** Gerekçe: içindeki
bileşenler (bildirim merkezi, dil seçici, hesap menüsü) **masaüstü üst
çubuğuyla aynı** bileşenler ve o çubuk beyaz. Laciverde çevirmek ya üç
bileşeni birden koyu zemin için yeniden renklendirmeyi ya da onları
okunmaz bırakmayı gerektirirdi. Referansta da üst çubuk beyaz.

## A2.2 Aktif öğe — üç ipucu

Ölçüm (aşama 1) tek bir mavinin iki eşiği birden tutamadığını göstermişti.
Uygulanan: dolgu `#2563eb` (beyaz metin 5.17) **+** sol işaret çubuğu
`--yz-sidebar-marker` (laciverde karşı 6.04) **+** `aria-current="page"`.
Renk tek taşıyıcı değil.

## A2.3 Site kartı — kenar çubuğunun dibinde

Referanstaki kart eklendi: bina ikonu + site adı + rol + `›`.

* **Tek tesislide de çizilir** ama düğme değil: "hangi sitedeyim" sorusu
  onun için de geçerli; olmayan bir kararı sunan düğme, basıldığında
  hiçbir şey yapmayan düğmedir.
* **Seçici hesap menüsünden KALDIRILDI.** İki yerde birden durması
  "hangisi geçerli?" sorusunu üretir — dil seçicinin P140.4'teki
  gerekçesiyle aynı. Geçiş **mantığı** `lib/tesis-gecis.ts` kancasına
  çıkarıldı: çizim taşındı, karar tek yerde kaldı.
* Menü **yukarı açılır**: kart zaten çubuğun dibinde.

## A2.4 Üst çubuk: `Ctrl K` rozeti

Kısayol P166'dan beri **çalışıyordu ama hiçbir yerde yazmıyordu** — yani
yalnız deneyerek bulunabiliyordu. Referanstaki rozet eklendi
(`aria-hidden`: alanın erişilebilir adı `aria-label`dan geliyor).

Arama alanının kendisi de **eski dilden yeni dile taşındı**
(`border-slate-300 bg-yuzey-card text-metin-body` → token'lar). Kabuk her
sayfada çiziliyor; ürünün en çok görünen tek kontrolü eski dilde
kalıyordu.

## A2.5 Altbilgi — bizde hiç yoktu

Referansta var, bizde **yoktu**. İçeriğin bittiğini söyler: altbilgisiz
bir sayfada uzun bir tablonun sonu ile ekranın sonu aynı şeye benziyor.
Telif + ürün adı + `/gizlilik` ve `/kosullar`.

## A2.6 Kanonik sayfa başlığı — ölçüm

**79 sayfanın 71'i kendi `<h1>`ini yazıyor.** Ortak desen yok: eski dilde
`SayfaBasligi` (tasarim.tsx) ve `PageHeader` (form.tsx) var ama ikisi
**toplam 4 sayfada** kullanılıyor.

"Her sayfa aynı şablon" şikâyetinin yanındaki ikinci gerçek bu: sayfalar
aynı şablonda **değil**, ama tutarlı da değil.

`components/ui/sayfa-basligi.tsx` eklendi (başlık · açıklama · eylem ·
üst bilgi · alt çubuk yuvaları). **Adoption modül turlarında** — bu
aşamada yalnız bileşen hazır, hiçbir sayfa bozulmadı.

## A2.7 Kilitler

| kilit | ne oldu |
|---|---|
| **YENİ** `p244-kabuk-token` | Kenar çubuğu ağacında içerik token'ı (`--yz-text*`, `--yz-metal-*`) kullanımını yasaklar; aktif öğenin renk dışında ipucu taşıdığını ölçer. **Metin taraması, DOM testi değil** — jsdom renk çözmez ve P226'da tam bu tuzağa düşülmüştü |
| `kabuk-rol-menusu` · `duzen-rol` | "Menü boş çizilir" testleri altbilgi bağlantılarını sayıyordu. **Eşik gevşetilmedi**: ölçülen şey hâlâ "bu role sayfa satırı çizilmiyor mu"; kabuğun sabit parçaları (logo, atla bağlantısı, hukuki altbilgi) sayım dışında |
| `p203-coklu-tesis` | Seçici taşındığı için **ölçülen yer** değişti, ölçülen şey değil: tek tesisliye seçim sunulmaması ve bulunduğu tesisin tıklanamaz olması hâlâ ölçülüyor. Tek tesislide kartın **düğme olmadığı** da eklendi |
| `i18n` TR-kopyası | `"Ctrl K"` istisna listesine girdi: tuş adı, cümle değil. Almanca'da tuş gerçekten `Strg` olduğu için yalnız o dil farklı |

**İki kilit kırılarak doğrulandı:** menü satırını içerik token'ına geri
döndürmek ve aktif işaretçiyi kaldırmak — ikisi de `p244-kabuk-token`'ı
düşürdü.

## A2.8 Bu aşamada YAPILMAYAN

* Sayfa başlığının 71 sayfaya uygulanması — modül turları (5–9).
* Bölüm başlıklarının referanstaki gibi küçük-kapital **etiket** olarak
  düz listede durması: bizde **katlanır** kalıyor (karar 1, 84 öğe).
* Üst çubukta site adı: referansta üst çubukta yok, kenar çubuğunda —
  bizde de öyle yapıldı.

## A2.9 Doğrulama

`tsc` temiz · `eslint` 0 hata (4 uyarı, hepsi P244 öncesinden) ·
**tam takım 230 dosya / 1974 test yeşil.**

---

# AŞAMA 3 — PAYLAŞILAN BİLEŞENLER · UYGULANDI

## A3.0 Aşama 1'in bedavaya getirdiği şey

Bileşenlerde **50+ `--yz-metal-*` / `--yz-raised` kullanımı** duruyor
(yuzey 7, dugme 6, sekmeler 5, kpi 2, tablo 2…). Aşama 1'de **token
değerleri** düzleştiği için hepsi **zaten düz çiziliyor** — tek bir
bileşene dokunmadan. Aşama 1'de "adları koru, değerleri düzleştir"
kararının karşılığı bu.

Yani aşama 3'ün işi "düzleştirmek" değil, **eksik olanı yapmak** oldu.

## A3.1 Yeni: detay çekmecesi (`DetayCekmecesi`)

Ölçülen boşluk: **79 sayfanın 1'inde** detay paneli vardı.

Bunun "boş görünüyor" şikâyetiyle doğrudan ilgisi var: detayı olmayan
bir tablo, satıra tıklayınca **yeni bir sayfaya** gitmeye zorlar;
kullanıcı listedeki yerini kaybeder, geri dönünce süzgeçleri yeniden
kurar. Panel listeyi **yerinde** tutar.

**Neden modal değil:** modal "bir işi bitir, sonra devam et" der
(oluşturma/düzenleme); çekmece "şunun ayrıntısına bak, listede kal" der.
İkisini tek bileşene sıkıştırmak iki farklı niyeti tek davranışa
indirger.

**Odak tuzağı yeniden yazılmadı.** `components/ui/modal.tsx` içindeki
mantık `lib/odak-tuzagi.ts`'e çıkarıldı; ikisi de onu kullanıyor. Böylece
P161'de ölçülen ders tek yerde kaldı:

> Görünürlük süzgeci `offsetParent !== null` **olamaz** — jsdom'da her
> zaman `null` döner, yani tuzak **testte sessizce devre dışı** kalır ve
> hiç ölçülemez.

## A3.2 Yeni: filtre çubuğu (`FiltreCubugu`)

Ölçülen: paylaşılan bir filtre bileşeni **hiç yoktu**; 12 sayfa aynı
`flex flex-wrap items-end gap-3` sarmalını elle yazıyor, diğerleri
varyasyonlarını.

**"N filtre açık — temizle" rozeti** eklendi. Boş bir liste karşısında
kullanıcının ilk sorusu "kayıt mı yok, yoksa ben mi süzdüm" olur — P243
§6c'de boş durum metinlerine yazılan dersin aynısı, ama orada yalnız
metin vardı. **Sayı metnin içinde**: renk tek taşıyıcı değil.

## A3.3 Yeni: özet şeridi (`OzetKarti` + `OzetSeridi`)

Ölçülen: **KPI 79 sayfanın 3'ünde.** Referansta neredeyse her operasyon
ekranının üstünde 3–5 kart var.

**Mevcut `Kpi` kullanılmadı ve bu bilinçli:** o bir **halka** (116 px
çember, glow'lu), referansınki **dikdörtgen kart**. Halkayı dikdörtgene
zorlamak, panoda çalışan bir bileşeni bozmak olurdu. `Kpi` duruyor;
panonun ele alınması aşama 5.

**Referansın bir hatası düzeltildi.** `ui5`'te "Açık Talepler ↓%20"
**kırmızı** çizilmiş — oysa açık talebin azalması iyi haberdir. Ok yönü
ile iyi/kötü aynı şey değil: borç düşerse iyi, tahsilat düşerse kötü.
Bizde çağıran taraf `trendYonu`nu **anlam** olarak verir
(`iyi`/`kotu`), yön olarak değil. Kilit bunu ölçüyor.

**Sütun sayısı sabit değil** (`auto-fit`): sabit bir `lg:grid-cols-4`,
üç kartlı bir ekranda sağda ölü bir kolon bırakırdı — P244'ün kaçınmak
istediği şeyin ta kendisi.

## A3.4 Tablo: yoğunluk, hover, yapışkan başlık, satır→detay

| ekleme | karar |
|---|---|
| `yogunluk` (`rahat`/`normal`/`sik`) | Tek ölçü vardı (`p-3`). Yoğun operasyon tablosu ile altı satırlık tanım defteri aynı nefesi kullanıyordu. **Varsayılan değişmedi** — 28 sayfa bugünkü ölçüyle çizildi, hepsini bir anda değiştirmek ölçülmemiş bir gerileme riskiydi. `py` değişir, `px` sabit kalır: yatay dolguyu daraltmak okunurluğu dikey sıkışmadan çok bozar |
| satır hover | Referansta her satırın hover zemini var. **CSS'te**, satır içi `style` ile `:hover` yazılamaz. `@media (hover: hover)` ile: dokunmatikte `:hover` yapışır ve yanlış bir "seçili" izlenimi bırakır |
| `yapiskanBaslik` | **Varsayılan kapalı**: kendi kaydırma kabı olan düzenlerde (modal içindeki tablo) yanlış yere yapışır |
| `onSatirTikla` + `satirAdi` | Verilirse imleç, `role="button"`, `tabIndex`, `Enter`/`Space` ve erişilebilir ad **birlikte** gelir; verilmezse **hiçbiri**. Yarım uygulanmış tıklanabilir satır (fareyle çalışıp klavyeyle çalışmayan), hiç olmamasından kötüdür |

## A3.5 Kendi tutarsızlığımı düzelttim

Ölçüldü: depoda **358 `data-test`** kullanımına karşı **5 `data-testid`**
— ve beşinin üçü **benim** önceki aşamalarda eklediklerimdi
(`kurulum-asgari`, `kurulum-sonra`, `ekran-yardimi`). Testing Library'nin
`getByTestId` varsayılanı `data-testid` olduğu için oraya kaymışım.

Üçü de konvansiyona döndürüldü, testleri `data-test` seçicisine geçti.

## A3.6 Kilitler

**YENİ** `p244-paylasilan-bilesenler.dom.test.ts` (13 test): çekmecenin
diyalog rolü/adı, ESC, örtü, odak girişi, boş eylem çubuğu çizilmemesi;
filtre sayısının **metinle** söylenmesi; trend renginin **anlama** bağlı
olması; `href` yoksa bağlantı çizilmemesi; yoğunluk; satır tıklamanın
fare **ve** klavyeyle birlikte çalışması; yapışkan başlığın varsayılan
kapalılığı.

`i18n` `sabit-metin` taraması şablon dizgemi yakaladı
(`` `${hucreSinifi} text-start font-medium` ``) — **haklı**: tarama CSS
sınıfını cümleden ayırt edemez. Değer adlandırıldı.

**Üç kilit kırılarak doğrulandı:** satır tıklamasından `tabIndex`'i
kaldırmak, çekmeceden ESC'i kaldırmak, trend rengini yöne bağlamak
(referansın hatası) — üçü de ilgili testi düşürdü.

## A3.7 Bu aşamada YAPILMAYAN

* Yeni bileşenlerin **sayfalara uygulanması** — modül turları (5–9).
  Bu aşama yalnız bileşen katmanı; hiçbir sayfa değişmedi.
* `components/Modal.tsx` (eski) hâlâ 1 sayfa + 3 kabuk bileşeni
  tarafından kullanılıyor; emekliliği aşama 10.
* `Kpi` (halka) ile `OzetKarti` (dikdörtgen) yan yana yaşıyor; panonun
  hangisini kullanacağı aşama 5'te karara bağlanacak.

## A3.8 Doğrulama

`tsc` temiz · `eslint` 0 hata (4 uyarı, hepsi P244 öncesinden) ·
**tam takım 231 dosya / 1987 test yeşil.**

---

# AŞAMA 4 — KARMA SAYFALARI TEMİZLE · UYGULANDI

**18 → 0.** Korumalı sayfaların hiçbiri artık eski görsel modülden ithal
etmiyor.

## A4.1 Ölçüm: iş 18 sayfa değil, 5 sembol kümesiydi

| eski sembol | kaç sayfa | ne yapıldı |
|---|---|---|
| `tablo::Tablo/Th/Td/Tr/TabloBasligi/TabloKart/BosSatir` | 8 | dosya **taşındı** → `components/ui/tablo-ilkelleri.tsx`, token diline çevrildi |
| `form::EksikVeriUyarisi` | 6 | `ui/durumlar`a taşındı |
| `form::Pager` | 2 | `ui/tablo-ilkelleri`ne taşındı |
| `tasarim::*` (8 sembol) | 1 (dashboard) | `ui` karşılıklarına çevrildi |
| `tasarim::IkonKutu` | 1 (raporlar) | `ui/yuzey`e taşındı |
| `Liste` + eski `Modal` | 1 (tanimlar) | `Liste` taşındı; `Modal` → `ui/modal` |

Yani 18 sayfayı tek tek elden geçirmek gerekmedi; **6 modül hareketi** 18
sayfayı birden temizledi.

## A4.2 `Liste` `VeriTablosu`ya ÇEVRİLMEDİ — gerekçe

İkisi aynı işi yapıyor görünüyor ama `Liste` bir şey daha yapıyor:
**sütun başına süzgeç** (`kolon.suzgec`). `VeriTablosu`da bu **yok**. Tek
kullanıcısını (`/tanimlar`) çevirmek, **çalışan bir özelliği sessizce
silmek** olurdu.

**Açık madde (aşama 10):** ya `VeriTablosu`ya sütun süzgeci eklenip
`Liste` emekliye ayrılır, ya da ikisinin hangi durumda kullanılacağı
yazılı bir kurala bağlanır. Bugün iki bileşen yan yana duruyor ve bu bir
**borç**.

Aynı gerekçeyle `tablo-ilkelleri` de `VeriTablosu`ya çevrilmedi: o bir
**veri tablosu** (sıralama, sayfalama, seçim, kolon gizleme), bunlar
**düz tablo ilkelleri**. Altı satırlık bir tanım defterine sayfalama
eklemek özellik değil gürültü olurdu.

## A4.3 Ölçüm üç şey daha buldu

1. **`EksikVeriUyarisi` sabit renk yazıyordu** (`border-amber-200
   bg-amber-50 text-amber-800`) — token katmanını bypass ediyordu ve koyu
   temada kendi başınaydı. Token diline çevrildi; metin `--yz-warning-ink`
   kullanıyor (ham `--yz-warning` metin olarak **2.15**, AA'nın çok
   altında — aşama 1'de ölçülmüştü).
2. **`KahramanBlok` ölü ithaldi** — dashboard onu içe aktarıyor ama hiç
   kullanmıyordu.
3. **`KATEGORI_VURGUSU` anlamı rengin adında saklıyordu**
   (`"blue"`/`"green"`/`"purple"`). Yeni katmanda ad **anlam** taşır;
   `Rozet`, `IkonKutu` ve `OzetKarti` aynı sözlüğü kullanıyor. Mor
   karşılıksız kaldı ve `notr`e düştü — rapor dökümleri bir **durum**
   bildirmiyor, yalnız bir kategori.

## A4.4 `tsc` iki hatamı yakaladı

* **Ad çakışması:** `Liste` `ui`'ya taşınınca iki farklı `Kolon` tipi aynı
  ambarda buluştu (`Liste`ninki `ciz`/`suzgec`, `VeriTablosu`nunki
  `hucre`/`siralanabilir`). `ListeKolonu` olarak yeniden adlandırıldı.
* **Yanlış eşleme:** `BolumBasligi`yi `ui`'nun `Bolum`una bağlamıştım —
  ama `Bolum` bir **sarmalayıcı** (children zorunlu), `BolumBasligi` ise
  yalnız **başlık satırı**. `tsc` yakaladı; `BolumBasligi` token diliyle
  `ui/yuzey`e eklendi.

Ayrıca bir regex'im yanlış ithal bloğunu yakalayıp dosyayı bozdu;
`git checkout` ile geri alınıp elle yapıldı.

## A4.5 Kilitler

| kilit | ne oldu |
|---|---|
| **YENİ** `p244-tek-tasarim-dili` | Hiçbir korumalı sayfa eski görsel modülden ithal etmiyor + eski `tasarim.tsx`'in **hiç kullanıcısı kalmadığı** ölçülüyor |
| `tasarim-token` — "TABLO KABI token kullanıyor" | **İddia güncellendi, niyet aynı.** Eskiden `rounded-kart`/`bg-yuzey-card` **sınıfları** aranıyordu — onlar eski dilin adlarıydı. Ölçülen şey değişmedi ("kap tasarım sisteminden mi geliyor, yoksa elle slate/gölge mi"); yalnız sistemin adı değişti. Eski adların **geri gelmemesi** de ayrıca kilitlendi |
| `tasarim-token` — "elle tablo iskeleti yok" | Yol sabitleri taşınan dosyalara güncellendi |
| `yz-bilesen` — "eski dil sınıfı yok" | **Gerçek kusur yakaladı:** `liste.tsx` çevirimim eksikti, iki düğmede `border-slate-300` kalmıştı |

Kilit **kırılarak doğrulandı**: bir sayfaya eski modülden ithal eklemek
`p244-tek-tasarim-dili`'ni düşürdü.

## A4.6 Bu aşamada YAPILMAYAN

* `components/tasarim.tsx`, `components/form.tsx` ve eski
  `components/Modal.tsx` **silinmedi** — aşama 10. `tasarim.tsx`'in artık
  hiç kullanıcısı yok (kilit bunu ölçüyor), yani silinebilir hâle geldi;
  `form.tsx` hâlâ form kontrollerini veriyor, `Modal.tsx` 3 kabuk
  bileşenini.
* Sayfaların **görünümü** değişmedi: bu aşama modül sınırını tasarım dili
  sınırıyla hizaladı, düzeni değil.

## A4.7 Doğrulama

`tsc` temiz · `eslint` 0 hata (4 uyarı, hepsi P244 öncesinden) ·
**tam takım 232 dosya / 1990 test yeşil.**

---

# AŞAMA 5 — ÖZET SAYFASI · UYGULANDI

## A5.0 Çatışma: referansın sabit düzeni vs bizim özelleştirilebilir panomuz

Referans (`ui5`) **sabit** bir düzen çiziyor. Bizde özet sayfası
**kullanıcı başına özelleştirilebilir** (P167 §2.5): 8 bölüm,
sürükle-bırak sıralama, gizleme, sunucuda kalıcı.

**Karar: özelleştirme sistemi korundu.** Çalışan işlevsellik
pazarlıksız. Referansın düzeni bölümlerin **varsayılan sırası** olarak
zaten büyük ölçüde mevcut; eklenen şey bölümlerin **içi** ve sayfanın
**başı**.

## A5.1 Kahraman bandı — bölüm değil, sayfa başlığının yerine

Sayfa `SayfaBasligi baslik="Özet"` ile başlıyordu: sayfanın **adını
tekrarlamak** dışında bir şey söylemiyordu. Bant aynı yerde üç soruyu
birden yanıtlıyor: **kimim, hangi sitedeyim, bugün ne gün** (+ hava).

**Bir bölüm değil** ve bu bilinçli: gizlenebilir bir karşılama satırı,
"bu sayfa neresi" sorusunu gizlenebilir yapardı.

**Fotoğraf yok — bilinçli.** Referansta bandın zemini site fotoğrafı.
Bizde tesis fotoğrafı diye bir alan **yok** (ne şemada ne yüklemede).
Uydurma bir stok görsel koymak, ürünü gerçek olmayan bir şeyle
süslemekti — P244'ün kaçındığı "mockup" tam olarak bu. Marka gradyanı
kullanıldı; alan bir gün eklenirse bant onu taşır.

## A5.2 Ölçüm: `/weather` için BFF rotası hiç yokmuş

Sunucuda `GET /weather` **P233'ten beri var** ve **mobil kullanıyor**
(`weatherProvider`). Web'de karşılık gelen BFF rotası **hiç yoktu** —
panel hava durumunu isteyemiyordu bile.

Bu, depoda kayıtlı bir kusur **sınıfı** (P173/P189: "BFF eksik-rota"):
sunucu ucu çalışır, web'in kapısı yoktur ve eksiklik ancak o ekran
yazılınca fark edilir.

`app/api/weather/route.ts` eklendi. **Yeni sunucu ucu değil** — var olan
uca kapı.

**503 bir hata değil, bir durum:** konum ayarlanmamışsa uç 503 döner ve
bant hava bloğunu **çizmez**. Bir karşılama satırını, kullanıcının
yapabileceği hiçbir şey olmayan bir hatayla bölmek yanlış olurdu.

## A5.3 KPI halkası → özet kartı

| | halka (eski) | kart (yeni) |
|---|---|---|
| şekil | 116 px çember + glow | dikdörtgen kart |
| taşıdığı | tek sayı | etiket + büyük sayı + **alt satır bağlam** |
| sayı | 0'dan hedefe **sayarak** gelir | ilk kareden itibaren **gerçek** |
| sınır | **en çok 4** | yok (aşağıda) |

**"En çok dört" sınırı kalktı.** Gerekçesi P133.2'de **renkti**: renkli
çemberler beşincide birbirini boğup sinyali gürültüye çeviriyordu. Kart
dili renkle değil **tipografiyle** çalışır — etiket küçük ve sönük, sayı
büyük ve koyu; ikon kutusu tonlu ama **metin taşımaz**. Sınırın
dayandığı ölçüm artık geçerli değil; sayıyı korumak **sebebi kalkmış bir
kuralı** korumak olurdu.

**Kuralın öteki yarısı aynen duruyor** ve ölçülüyor: yetkisi olmayana
mali kart çizilmez, sayı dekoratif değil, kart bir bağlantıdır.

**Yeni uç açılmadı.** Kartlar sayfada **zaten çekilen** kayıtlardan
türüyor (`dashboard/live`, `building-map`, `gorunur-sayi`). Kilit bunu
ölçüyor.

## A5.4 Maket: etkileşim aynen, çerçeve yeni

Karar 6 uygulandı. `BinaSahnesiYukleyici`, `sahneBloklari`, `secim` ve
seçim paneli **tek satır değişmedi**. Eklenen: kart başlığı, açıklama ve
**durum efsanesi**.

**Efsane iki kez düzeltildi — ikisi de ölçümle:**

1. İlk yazımda efsaneyi `dolu/boş/borçlu/alarm` diye kurmuştum. Ölçüm:
   `DaireDurumu` **`normal`/`borclu`/`alarm`/`pasif`** ve **bu sayfa
   yalnız ikisini üretiyor** (`complaint_count > 0 ? alarm : normal`).
   Dört durumlu bir efsane, hiç çizilmeyecek iki renk ilan ederdi.
2. Renkleri `--yz-*-edge` token'larından almıştım. Ölçüm: sahne kendi
   paletini kullanıyor (`site-palet.ts`, WebGL sayısal renk ister) ve o
   palet **tema başına ayrı**. Efsane artık `durumRenkleri()`den okuyor —
   tek kaynak.

## A5.5 Yan bulgu: 3B paleti eski renkleri taşıyor

`site-palet.ts` başlığı "durum renkleri `--yz-*-edge` ailesinin sayısal
karşılığıdır" diyor. **Bugün değil:** açık temada `alarm: #d45b5e` —
P244 öncesi `--yz-danger-edge` (`#d25a5d`) ile neredeyse aynı, yenisiyle
(`#ef4444`) değil. Yani aşama 1 token'ları değiştirdi, **sahne paleti
geride kaldı**.

**Değiştirmedim.** Karar 6 "maketin kendisine dokunma" diyor ve daire
durum renkleri maketin kendisi. Ayrı bir karar hak ediyor — **açık
madde**.

## A5.6 Kilitler

| kilit | ne oldu |
|---|---|
| **YENİ** `p244-ozet-sayfasi` (6 test) | Selam/tesis/tarih bir arada; saate göre selam; **hava alınamazsa bant çizilmeye devam eder**; şerit var; **efsane renklerini sahneden alır**; **yeni uç açılmadı** |
| `pano-tint-blok` | **Bilinçli güncelleme** (aşama 0'da işaretlenmişti). "En çok 4" düştü — gerekçesi renkti, dil değişti. Kuralın öteki yarısı (yetki sızıntısı, dekoratif olmayan sayı, bağlantı) **aynen duruyor** |
| `pano.dom` | Halkanın birleşik `sr-only` metni yerine kartın iki ayrı görünür ögesi. **Ölçülen şey değişmedi** |
| `pano-duzenleme` | **Gerçek kusur yakaladı:** maket başlığını iki kez çiziyordum (çerçeve + kart). `maket` artık `kendiBasligi: true` |
| `i18n` | `"{derece}°C {durum}"` TR-kopyası istisnası; iki yorumumda Türkçe sabit yakalandı |

**Üç kırma denendi, biri kilitsizdi ve kilit eklendi:**
havayı yutmayı kaldırmak ✔, mali kartı yetkisize çizmek ✔, **efsaneye
sabit hex yazmak → hiçbir kilit yakalamadı** → `p244-ozet-sayfasi`'na
eklendi ve kırılarak doğrulandı. Kilidin kendi ölçüm hatası da (jsdom
hex'i `rgb()`ye çevirir) ilk koşuda ortaya çıktı.

## A5.7 Bu aşamada YAPILMAYAN

* Referanstaki **"Hızlı İşlemler" / "Duyurular" / "Talepler" / "Son
  İşlemler"** kartları eklenmedi. `widgetlar` bölümü zaten hızlı
  kısayolları veriyor; kalan üçü **yeni veri kaynakları** ister ve bu
  turun kuralı "yeni uç açma". Ayrı turda değerlendirilmeli.
* **3D/Harita görünüm seçici** (referansta maket kartının sağ üstünde)
  eklenmedi: harita görünümü bu sayfada yok, olmayan bir görünüme
  geçiren bir düğme çizmek kullanıcıyı aldatırdı.
* Finans bölümü (`PanoFinansOzeti`) referansın halka grafiğine
  çevrilmedi — finans turu (aşama 7).

## A5.8 Doğrulama

`tsc` temiz · `eslint` 0 hata (4 uyarı, hepsi P244 öncesinden) ·
**tam takım 233 dosya / 1996 test yeşil.**

---

# AŞAMA 6a — GÜVENLİK · UYGULANDI (ilk tur)

Plan aşama 6'yı **iki tur** diye tahmin etmişti. Bu tur **güvenlik**;
tesis (B grubu) bir sonraki tura kaldı — sonunda açıkça yazılı.

## A6.1 Ölçüm: aşama 3'ün bileşenleri hiç kullanılmıyordu

10 güvenlik ekranı tarandı: **`OzetSeridi`, `FiltreCubugu` ve
`DetayCekmecesi` sıfır sayfada.** Aşama 3'te yazılan bileşenler
raftaydı. En büyük kaldıraç buydu.

## A6.2 `arac-gecisleri` — ölçülen en zayıf ekran

69 satırdı ve her kaydı **ayrı bir kart** olarak alt alta diziyordu:
50 geçiş = 50 kart.

Kart dizisi burada yanlış bir seçimdi: geçiş kaydı **üç alanlı ve
tekrarlı**; kart dili her kayda bir başlık seviyesi verip ekrana dört
kayıt sığdırıyordu. Tablo aynı alanda yirmi beş kayıt gösterir.

Yeni: `SayfaBasligi` + `OzetSeridi` (3 kart) + `FiltreCubugu`
(plaka araması + durum) + `VeriTablosu` (`yogunluk="sik"`, yapışkan
başlık, numaralı).

## A6.3 Ölçüm: BFF sunucunun süzgeçlerini düşürüyormuş

Sunucu `acik`, `plaka`, `baslangic`, `bitis` süzgeçlerini **P16'dan beri**
destekliyor ve sözleşme bunları **açıkça sayaç tarifi** olarak
belgeliyor:

> "Ana ekran sayacı: `?acik=true&limit=1` → `meta.total`"
> "Bugün N giriş: `?baslangic=<gün başı>&limit=1` → `meta.total`"

BFF rotası yalnız `limit`/`offset` taşıyordu. Yani web ne plakaya göre
arayabiliyor ne de "içeride kaç araç var" sorabiliyordu. Depoda kayıtlı
sınıf (**P213**: "BFF sorgu süzgecini beyaz listeyle taşır").

Rota düzeltildi — **beyaz listeyle**, çünkü sorgu dizesini olduğu gibi
iletmek istemcinin backend uçlarına serbestçe parametre geçirmesine izin
vermek olurdu.

Sayaçlar artık **`meta.total`dan** geliyor, görünen sayfadan değil:
görünen 50 kaydı saymak "bugün 50 giriş oldu" gibi **yanlış** bir sayı
üretirdi.

## A6.4 `kameralar` — canlı rozeti ve ızgara yoğunluğu

* **CANLI rozeti küçük resmin üstünde.** Eskiden canlı olduğu kartın
  **altında sönük bir satırdı**; referansta kırmızı rozet görüntünün
  üstünde ve göz onu önce görür. Renk tek taşıyıcı değil — rozetin
  içinde kelime de var.
* **Izgara yoğunluğu** (Büyük / Orta / Sık). Sabit `lg:grid-cols-3`
  üç kameralık bir sitede doğru, yirmi kameralık bir sitede sayfayı
  yedi ekran boyu uzatıyordu. Seçim **cihaza değil veriye** bağlı ve
  bunu ancak kullanıcı bilir. Tercih `localStorage`ta: bir **görünüm
  alışkanlığı**, hesaba yazılacak bir ayar değil (kabuk menüsünün
  dar/geniş tercihiyle aynı sınıf).
* Özet şeridi: toplam / görüntü veren / görüntü alınamayan.
  **"Arızalı" demiyoruz** — bir kamera çalışıyor ama karesi geç gelmiş
  olabilir; etiket "görüntü alınamayan" ve alt satırı bunun **ilerleyen**
  bir sayı olduğunu söylüyor.

## A6.5 Kırma denemeleri iki boşluk buldu

| kırma | sonuç |
|---|---|
| Sayaçları görünen listeden say | **Yakalanmadı** → testim ayırt etmiyordu (üç kart da aynı sayıyı gösteriyordu). İddia **kart başına** daraltıldı; yeniden kırıldı, düştü |
| Aramayı istemciye al | yakalandı ✔ |
| BFF'ten süzgeci kaldır | **Yakalanmadı** → DOM testi `fetch`i taklit ediyor, **rota işlevi hiç çalışmıyor**. P200/P213 dersi birebir tekrar: taklit, ölçülmek istenen katmanın **altına** konmalı. Ayrı bir rota testi yazıldı (`p244-bff-arac-suzgec`, 5 test); yeniden kırıldı, dördü birden düştü |

## A6.6 Kilitler iki gerçek kusurumu yakaladı

1. **`canliSayisi`yi `kareHatalari` tanımlanmadan önce koymuşum** —
   `kamera-oynatici.dom` testi TDZ hatasıyla düştü. `tsc` bunu
   görmemişti.
2. **`arac-gecisleri` istek düştüğünde "kayıt yok" yazıyordu** —
   `guvenlik-ekranlari.dom` yakaladı. **P61 ihlali**: bilinen tek şey
   listenin okunamadığı. Hata artık tabloya veriliyor; tablo boş durum
   yerine tekrar düğmesi çiziyor.

## A6.7 Bir kilidin ölçütü değişti, kuralı değişmedi

`guvenlik-ekranlari` — "YAZMA düğmesi/formu YOK". Eski iddia *"hiç
düğme ve hiç metin kutusu yok"*tu ve bu, "yazma yolu yok"un **vekiliydi**.
Sayfaya arama ve filtre gelince vekil düştü — **ama kural düşmedi**:
arama kutusu bir **okuma** kontrolüdür, kayıt üretmez.

Ölçülen şey artık doğrudan kuralın kendisi: `<form>` yok ve
"yeni/ekle/oluştur/kaydet" diye bir eylem yok. Gerçek güvence zaten
BFF'te (rota yalnız `GET` dışa aktarır).

## A6.8 Bu turda YAPILMAYAN — açıkça

* **Tesis grubu (B) hiç ele alınmadı**: `/building-editor`, `/units`,
  `/residents`, `/rezervasyon-yonetimi`, `/tesis-ayarlari`. Sonraki tur.
* Güvenliğin kalan yedi ekranı (`kamera-kayitlari`, `panik`, `akilli-ev`,
  `notifications`, `patrol-plans`, `checkpoints`, `olaylar`,
  `ziyaretciler`) **dokunulmadı**. Bu turda iki ekran ölçülerek seçildi:
  en zayıf olan (`arac-gecisleri`, 69 satır) ve referansın en güçlü
  gösterdiği (`kameralar`).
* **`DetayCekmecesi` hâlâ hiçbir sayfada kullanılmıyor.** Aşama 3'te
  yazıldı, aşama 6a'da yeri gelmedi — satır tıklaması `arac-gecisleri`
  için anlamsız (geçiş kaydının detayı yok). Tesis turunda daire detayı
  için kullanılacak.

## A6.9 Doğrulama

`tsc` temiz · `eslint` 0 hata (4 uyarı, hepsi P244 öncesinden) ·
**tam takım 235 dosya / 2007 test yeşil.**

---

# AŞAMA 6b — TESİS · UYGULANDI (ikinci tur)

## A6b.1 `DetayCekmecesi` nihayet kullanılıyor

Aşama 3'te yazıldı, **altı tur boyunca hiçbir sayfada kullanılmadı**.
İlk tüketicisi `/units`.

**Ölçülen kusur:** daire detayı **tablonun altında** açılıyor ve sayfa
oraya **kaydırılıyordu** (`useAcilinca`). Kullanıcı listedeki yerini
kaybediyor, geri dönünce süzgeçleri ve kaydırmayı yeniden kuruyordu; bir
daireden ötekine bakmak her seferinde aşağı-yukarı gitmek demekti.

Çekmece listeyi **yerinde** tutar. `useAcilinca` kancası artık gereksiz —
kaldırıldı.

## A6b.2 Satır tıklaması EKLENMEDİ — ölçülmüş karar

Aşama 3'te tabloya `onSatirTikla` eklemiştim ve burası ilk adayıydı.
**Eklemedim:** `/units` tablosu **seçilebilir** (`secilebilir`), yani
satıra tıklamak kullanıcıların çoğunda **"seç"** anlamına gelir. İki
anlamı aynı harekete yüklemek, toplu işlem yapmak isteyene her seferinde
çekmece açardı.

Detay, satır sonundaki **düğmeyle** açılıyor. Kilit bunu ölçüyor: satırda
`role="button"` **yok** ve seçim kutusu **duruyor**.

## A6b.3 `UnitDetail` eski dilden çıktı

41 eski-dil kullanımı vardı (`cardCls`, `inputCls`, `btnPrimary/Ghost/
Danger`, `Field`, `ErrorBox`). Aşama 4 **sayfaları** temizlemişti;
paylaşılan bu bileşen `components/form.tsx`e bağlı kalmıştı.

**Kart sarmalayıcısı kaldırıldı:** bileşen artık çekmecenin içinde
çiziliyor ve çekmece zaten bir yüzey — üstüne ikinci bir kart koymak iki
kenarlık ve iki dolgu demekti.

Dönüşümde `tsc` bir API farkını yakaladı: `AlanSarmal` **render-prop**
alıyor (`{(b) => <Alan {...b} …/>}`), eski `Field` düz children alıyordu.
Sekiz alan buna göre çevrildi.

## A6b.4 Özet şeritleri — "bu sayı neyi sayıyor?"

| ekran | kaynak | gerekçe |
|---|---|---|
| `/units` | `/api/units/arsa-payi-ozeti` (**ayrı uç**) | Liste **sayfalı**; görünen satırların toplamı "toplam arsa payı" değildir |
| `/residents` | **görünen liste** | Liste sayfalı **değil** — sunucu tüm sakinleri döndürüyor, gruplama istemcide |
| `/arac-gecisleri` (6a) | `meta.total` | Liste sayfalı |

Üçü aynı kuralı değil, aynı **soruyu** uyguluyor: *bu sayı neyi sayıyor?*

`/residents`'ta özet **süzgeçsiz** listeden sayılıyor: `gruplar` süzgeçten
geçmiş listeyi taşıyor ve oradan saymak "arama yapınca sakin sayısı
düştü" gibi yanlış bir şey söylerdi.

## A6b.5 `/residents` gruplaması KORUNDU

Blok-gruplu kart yapısı **tabloya çevrilmedi**: gruplama bu sayfanın
**var olma sebebi** (P220 §4 — "kim nerede oturuyor" sorusu). Eklenen
şey sayfa başlığı, özet şeridi ve filtre çubuğu.

## A6b.6 Kilitler

**YENİ** `p244-tesis-ekranlari` (4 test): özet şeridi arsa payı eksiğini
sayıyla söyler; detay **çekmecede** açılır ve arkadaki tablo durur; ESC
kapatır; satır tıklaması **eklenmedi** ve seçim kutusu duruyor.

**İki kırma denendi, ikisi de yakalandı:** detayı tablo altına geri
koymak, satır tıklaması eklemek.

`p193-arsa-payi` — bilgi tablonun altından özet şeridine taşındığı için
iddia güncellendi. **Ölçülen şey değişmedi** ve asıl gerekçe kaydedildi:
toplam ayrı uçtan gelir, görünen satırlardan türetilmez.

Test yazarken kendi kurgum bir kez düştü: `/api/units/{id}/residents`
de `/api/units` içeriyor; genel dalı öne almak, dizi bekleyen bir uca
nesne döndürüp bileşeni `filter is not a function` ile düşürüyordu.

## A6b.7 Bu turda YAPILMAYAN — açıkça

* **`/building-editor` (1238 satır) hiç ele alınmadı.** Referanstaki
  "blok kartları şeridi + seçili bloğun daire tablosu" deseni oraya ait
  ve tek başına bir tur işi. En uzun üçüncü sayfa.
* `/rezervasyon-yonetimi` ve `/tesis-ayarlari` dokunulmadı.
* Güvenliğin kalan yedi ekranı (6a'da da not edilmişti) dokunulmadı.
* **3B sahne paleti hâlâ P244 öncesi renklerde** (§A5.5 açık maddesi).

## A6b.8 Doğrulama

`tsc` temiz · `eslint` 0 hata (4 uyarı, hepsi P244 öncesinden) ·
**tam takım 236 dosya / 2011 test yeşil.**

---

# AŞAMA 6c — BUILDING-EDITOR + GÜVENLİĞİN KALANI · UYGULANDI

## A6c.1 `/building-editor` — sabit renkler token katmanını atlıyordu

Blok kartları **sabit Tailwind renkleri** yazıyordu:
`border-indigo-200 bg-indigo-50 text-indigo-900`, `text-amber-600`,
`text-red-700`, `border-slate-300 bg-white` — yani token katmanını
tamamen atlıyor ve **koyu temada kendi başınaydı**.

Aşama 4'ün kilidi bunu görmemişti: o kilit **modül ithallerini** ölçüyor
(eski dosyalardan içe aktarma), sabit sınıf adlarını değil. `yz-bilesen`
kilidi de yalnız `components/ui/` altını tarıyor.

Referansın blok kartları **nötr bir yüzey**; renk burada bir **anlam**
taşımıyordu, yalnızca süstü. Kartlar token diline çevrildi, ızgaraya
dizildi, "kayıtsız blok" rozeti **metin** taşıyor, ekleme kartı kesik
çizgili.

Sayfadaki diğer üç sabit renk kullanımı da (uyarı şeridi, boş metin, kat
ekleme kutusu) token'a çevrildi.

## A6c.2 Güvenliğin kalanı — ölçerek seçildi

| ekran | ölçüm | karar |
|---|---|---|
| `/olaylar` | **kart yığını** + `bg-slate-100` | **çevrildi**: özet şeridi + tablo |
| `/ziyaretciler` | **kart yığını** | **çevrildi**: özet şeridi + tablo |
| `/panik` | zaten tablo | dokunulmadı |
| `/patrol-plans`, `/checkpoints` | zaten `VeriTablosu` | dokunulmadı |
| `/kamera-kayitlari`, `/notifications`, `/akilli-ev` | sabit renk yok, yapı makul | dokunulmadı |

## A6c.3 Tarama beklediğimden fazlasını buldu

Kart-yığını desenini kilitlemek için yazdığım tarama, düzelttiğim
üçün **dışında on ekran daha** buldu. Hepsini "istisna" diye
etiketlemek kuralı sessizce boşaltmak olurdu; tek tek bakıp ikiye
ayırdım:

**Doğru kullanım (7) — kart yanlış bileşen değil, yanlış YERDE
kullanılmıştı:**

| ekran | kart neyi temsil ediyor |
|---|---|
| `duyurular`, `etkinlikler` | **uzun içerik** (`whitespace-pre-line`) — tablo hücresine sıkıştırmak okunmaz yapardı |
| `rezervasyon-yonetimi` | **ortak alan tanımı**, rezervasyon kaydı değil |
| `schematic`, `residents` | **blok grubu** (içinde liste/ızgara) |
| `tasks` | **kanban görev kartı** — tabloya çevirmek sürükle-bırakı öldürürdü |
| `tesis-ayarlari` | **ayar grubu** |
| `yonetim-iletisim` | **kişi kartviziti** |
| `kameralar`, `building-editor`, `dashboard` | görsel karo / blok kartı / pano bölümü |

**Borç (3) — kart yanlış yerde, ama düzeltmesi bu turun kapsamı
dışında (aşama 8: operasyon + iletişim):**
`dis-hizmetler`, `kargolar`, `rezervasyonlarim`.

Borç listesi **tam eşleşir**: biri düzeltilince listeden silinmeli
(yoksa liste bayatlar), yeni biri eklenince test düşer. Yani borç ne
sessizce büyüyebilir ne de sessizce unutulabilir.

## A6c.4 Kilit: kart yığını yasağı

**YENİ** `p244-kart-yigini-yasak` (3 test). Metin taraması, çünkü
"ekran boş görünüyor" görsel bir yargı ve jsdom onu ölçemez — ama
**desen yapısal**: bir listeyi `map` edip `<Kart` döndürmek.

Kilit ayrıca **istisna listesinin bayatlamasını** da ölçüyor: listede
adı geçen dosya silinmişse test düşer.

Kırarak doğrulandı: `/olaylar`'ı kart yığınına geri döndürmek testi
düşürdü.

## A6c.5 Kendi hatam — üçüncü kez

Import bloklarını `[\s\S]*?` ile eşleyen regex'i **üçüncü kez**
kullandım ve üçüncü kez dosyanın ilk `import {`ini (React'ınkini)
yakalayıp bloğu bozdu. Her seferinde `tsc` yakaladı ve elle onardım.

**Bundan sonra bu deseni kullanmayacağım**; ithal bloğunu değiştirirken
hedef modülün tam metnini arayıp değiştireceğim.

## A6c.6 Bu turda YAPILMAYAN

* Borç listesindeki üç ekran (aşama 8).
* `/kamera-kayitlari`'na referanstaki **sağ önizleme paneli** eklenmedi
  — video oynatıcı zaten var ama yan yana düzen kurulmadı.
* `/checkpoints`'e referanstaki **harita + liste** ayrımı uygulanmadı;
  sayfada harita zaten var, düzeni değiştirilmedi.
* `/panik`'e özet şeridi eklenmedi (tablo yapısı yeterliydi, öncelik
  kart yığınlarındaydı).
* 3B sahne paleti hâlâ P244 öncesi renklerde (§A5.5).

## A6c.7 Doğrulama

`tsc` temiz · `eslint` 0 hata (4 uyarı, hepsi P244 öncesinden) ·
**tam takım 237 dosya / 2014 test yeşil.**

---

# AŞAMA 7a — FİNANS · UYGULANDI (ilk tur)

Plan finansı **iki tur** diye tahmin etmişti. Bu tur **paylaşılan kabuk +
ölçümde çıkan iki sessiz kusur**; grafikler ve kalan ekranlar sonraki
tura.

## A7.1 Ölçülen kök neden: yedi sayfa tek iskelet

`HareketSayfasi` kabuğunu **yedi sayfa** paylaşıyor (gider, gelir,
tahsilat, borçlandırma, virman, iade, açılış) ve kabuk yalnızca
**başlık + tablo** çiziyordu. Finans modülünün baştan sona aynı
görünmesinin sebebi tek bir dosyaydı.

Kabuk **yeniden yazılmadı** — yapılandırılabilir yapıldı:
`aciklamaAnahtari`, `ozet`, `grafik`, `suzgec` yuvaları. **Verilmezse
hiç çizilmez**: boş bir özet şeridi ya da boş bir grafik kutusu, sayfayı
doldurmuş gibi görünüp hiçbir şey söylemez.

**Neden yuva, neden kabuğun kendi hesabı değil:** özetlenecek şey her
sayfada farklı (giderde "onay bekleyen", tahsilatta "bu ay tahsil
edilen", borçlandırmada "bu ay borçlandırılan"). Kabuk bunları bilemez;
bildiği tek şey **nereye** çizileceği.

Özet sayıları **sunucudan** geliyor (`/finans/ozet`,
`/finans/kasa-bakiyeleri`) — görünen hareketlerden toplam almak "iki
yerde iki farklı rakam" demekti; bu kural `/finans` sayfasının dosya
başında zaten yazılıydı. **Yeni uç açılmadı**; ikisi de beyaz listede ve
SWR önbelleği paylaşılıyor.

## A7.2 Ölçüm iki SESSİZ kusur buldu — aynı satırda, ters yönlerde

BFF beyaz listesi: `["tip", "kasa_id", "baslangic", "bitis"]`
Backend imzası: `tip, kasa_id, user_id`

**1. `user_id` eksikti — gerçek ve pahalı.**
`/finans/iade` ekranı "bu **kişinin** tahsilatları" diye soruyor
(`?tip=tahsilat&user_id=…`) ve süzgeç **BFF'te düşüyordu**: ekran
**herkesin** tahsilatını listeliyordu. Kullanıcı yanlış bir tahsilatı
seçip iade açabilirdi.

**2. `baslangic`/`bitis` fazlaydı.**
Backend bunları **hiç tanımıyor**. Beyaz listede durmaları **olmayan bir
yeteneği varmış gibi** gösteriyordu: biri tarih süzgeci yazsa parametre
sunucuya gider, FastAPI onu sessizce atar, ekran "süzdüm" der ama
süzmez. (Tarandı: kullanan yoktu.)

İkisi de **sessiz**: ne hata verir ne log bırakır. Tek belirti "listede
olmaması gereken kayıtlar var".

## A7.3 Sözleşme sapması — web kilidi yakaladı

`uc-sozlesme-kapisi` kilidi, yazdığım `KasaOzet` arayüzünde
`bekleyen_cikis_toplam_kurus`u **sözleşmenin vaat etmediği** bir alan
olarak işaretledi.

Ölçüldü: alan **backend'de P192'den beri var** ve `/finans` ekranı onu
zaten okuyordu — ama OpenAPI şemasında **hiç beyan edilmemişti**. Yani
sapma benden önce vardı; benim adlandırılmış arayüzüm onu **görünür**
yaptı (eski okuma satır içi generic olduğu için tarama görmüyordu).

**Kusur sözleşmedeydi, kodda değil.** `KasaBakiyeResponse` şemasına
eklendi; backend sözleşme testleri (6/6) yeşil.

## A7.4 Kilit

**YENİ** `p244-finans-suzgec` (4 test): beyaz liste **backend imzasıyla
birebir** eşleşir — eksik de olamaz, fazla da. Tarama
`routers/finans.py::hareket_listesi` imzasını **doğrudan okuyor**, elle
yazılmış bir liste ile karşılaştırmıyor.

`user_id` için **ayrı bir iddia** var ve bu bilinçli: düştüğünde ne
olduğunu anlatması gerekiyor ("iade ekranı herkesin tahsilatını
listeler").

**İki kırma denendi, ikisi de yakalandı:** `user_id`yi geri çıkarmak,
backend'de olmayan bir süzgeci geri eklemek.

## A7.5 Bu turda YAPILMAYAN — açıkça

* **Grafikler eklenmedi.** Referansta aidat çubuk, finans çizgi, gider
  halka, bütçe yatay bar var. Yuva (`grafik`) hazır ama **hiçbir sayfa
  doldurmuyor** — grafik verisi ayrı uçlar ister ve hangi uçların
  hazır olduğunu ölçmedim.
* **Özet şeridi yalnız dört sayfada**: giderler, gelirler, tahsilatlar,
  (borçlandırma kabuğu kullanmıyor — kendi ekranı). Virman, iade ve
  açılış şeritsiz kaldı: virman kasadan kasaya taşıma (özetlenecek
  toplam bir şey yok), iade zaten seçilen kişiye bağlı, açılış tek
  seferlik.
* `/dues`, `/finans/banka`, `/finans/otomasyon`, `/finans/butce`,
  `/finans/borclular`, `/icra`, `/sayac-okuma`, `/raporlar`
  **dokunulmadı** — referansın en ayırt edici düzenleri (banka marka
  kartları, otomasyon kural satırları, bütçe yatay bar, rapor
  kategorileri) burada ve hepsi sonraki tura.

## A7.6 Doğrulama

`tsc` temiz · `eslint` 0 hata (4 uyarı, hepsi P244 öncesinden) ·
**tam takım 238 dosya / 2018 test yeşil** · backend sözleşme testleri
6/6 yeşil.

---

# AŞAMA 7b — FİNANSIN KALANI · UYGULANDI

## A7b.1 Önce grafik verisini ölçtüm

7a'da "hangi uçların hazır olduğunu ölçmedim" diye kaydetmiştim. Ölçtüm —
**üçü de hazır ve beyaz listede**:

| uç | ne veriyor | kullanan |
|---|---|---|
| `/budget/karsilastirma` | hedef · gerçekleşen · sapma (kategori başına) | `/finans/butce` (tablo olarak) |
| `/finans/tahsilat-gostergesi` | tahakkuk · tahsilat · oran · önceki döneme göre değişim | **yalnız** `/finans/borclular` |
| `/finans/yaslandirma` | yaşlandırma kovaları | `/finans/borclular` (grafikli) |

Yani grafik için **yeni uç gerekmedi**; gereken şey var olan veriyi
görselleştirmekti.

## A7b.2 Bütçe: iki sayı kolonu → yatay oran barı

Ekran hedefi ve gerçekleşeni **yan yana iki sayı kolonu** olarak
gösteriyordu. İki sayıyı karşılaştırmak okurun işiydi: *"420.000 ile
483.500 arasındaki fark ne?"* sorusunu göz yapamaz, ancak hesaplayarak
bulur. Referansta aynı veri **yatay bar**.

Üç karar, üçü de kilitli:

* **Hedefsiz kategoride bar çizilmez.** Sıfır hedefe karşı dolu bir bar
  "sonsuz aşım" demekti — bilgi değil, hata.
* **Dolgu %100'de durur ama yüzde gerçeği söyler.** %180'lik bir bar
  satırdan taşar ve tablo hizasını bozar; ama sayıyı da kırpmak yanlış
  bilgi olurdu.
* **Aşımın işareti tipe bağlı** (giderde kötü, gelirde iyi) ve bu yorum
  `sapmaKotuMu` ile **tek yerde**; bar onu prop olarak alıyor. İkinci bir
  kopya, iki ekranda iki anlam demekti.

Ayrıca sapma sütunu ham `--yz-danger`/`--yz-success` kullanıyordu; bunlar
**metin olarak AA'yı tutmuyor** (aşama 1'de ölçülmüştü) — `-ink`
varyantına geçti.

## A7b.3 Aidat: gösterge vardı, ekranda yoktu

`/finans/tahsilat-gostergesi` **P192'den beri var** ve
`/finans/borclular` onu kullanıyor. **Aidat ekranında yoktu** — oysa "bu
dönem ne kadar tahakkuk etti, ne kadarı tahsil edildi" sorusunun
sorulacağı ilk yer orası; kullanıcı sayıyı görmek için başka bir ekrana
gitmek zorundaydı.

Üç kart eklendi. **Oran yoksa (tahakkuk sıfır) durum nötr**: "%0" demek
tahsilat yapılmadığını **söylemektir**, oysa borçlandırma da yapılmamış
olabilir.

## A7b.4 `/raporlar` — zaten referansın deseni

Planda "ölü liste görünümünden kaçın, kategorilere ayır" yazmıştım.
Ölçtüm: ekran **zaten** kategorili başlıklar + ikonlu, açıklamalı kart
ızgarası kullanıyor. **Dokunmadım.**

## A7b.5 Otomasyon: "Evet/Hayır" → durum rozeti

`aktif` sütunu düz metin "Evet/Hayır" yazıyordu. Kural listesinde aranan
şey *"hangileri çalışıyor"* ve göz bunu bir rozetten metin okumadan
tarar.

**Rozet tıklanabilir değil ve bu ölçülmüş bir karar:** referansta burada
bir anahtar (toggle) var, ama kuralı **yerinde** açıp kapatacak bir yazma
ucu **yok** — düzenleme kuralın tamamını alan bir akıştan geçiyor.
Tıklanınca hiçbir şey yapmayan bir anahtar çizmek kullanıcıyı bir kez
aldatırdı.

## A7b.6 Kilit

**YENİ** `p244-finans-gorsel` (5 test). **Üç kırma denendi, üçü de
yakalandı:** hedefsizde barı yine çizmek, yüzdeyi de %100'e kırpmak,
aşım rengini tipten bağımsız yapmak.

`sabit-metin` taraması `trendYonu` üçlüsündeki dizgeleri yakaladı —
**haklı**: tarama CSS/kimlik değeri ile cümleyi ayırt edemez. Değerler
adlandırıldı.

## A7b.7 Bu turda YAPILMAYAN — açıkça

* **`/finans/banka`** (629 satır) — referanstaki **banka marka kartları**
  yapılmadı. Ekran bugün bir yükleme akışı + eşleştirme tablosu; marka
  kartı listesi **hesap listesi** ekranı ister ve o ayrı bir düzen
  kararı.
* **`/icra`** (635), **`/sayac-okuma`** (424), **`/finans/borclular`**
  (339) dokunulmadı. Borçlular zaten grafikli; icra ve sayaç okuma
  yapısal olarak makul (tablo + sihirbaz).
* Otomasyonda **yerinde aç/kapat** yapılmadı (yazma ucu yok — yukarıda).
* Finans özet şeridi hâlâ dört sayfada; virman/iade/açılış şeritsiz
  (7a'daki gerekçe geçerli).

## A7b.8 Doğrulama

`tsc` temiz · `eslint` 0 hata (4 uyarı, hepsi P244 öncesinden) ·
**tam takım 239 dosya / 2023 test yeşil.**

---

# AŞAMA 8a — OPERASYON: KART YIĞINI BORCU · UYGULANDI

Aşama 6c'de `p244-kart-yigini-yasak` kilidini yazarken üç sayfayı
**BORÇ** listesine koymuştum. Borç kapandı.

## A8a.1 Neden bu üçü borçtu, `yonetim-iletisim` değil

Kilit "kart" kullanan her sayfayı suçlamıyor; **kartın doğru olduğu**
yerleri istisna tutuyor. Ayrımı yeniden ölçtüm:

| ekran | kart neyi temsil ediyor | karar |
|---|---|---|
| `yonetim-iletisim` | üç-beş kişilik **sabit** yönetim kadrosu, kartvizit | istisna — **kaldı** |
| `dis-hizmetler` | tesisin **tüm** güvenilir esnafı, büyüyen liste | borç — tablo |
| `kargolar` | tekrarlı, beş alanlı operasyon kaydı | borç — tablo |
| `rezervasyonlarim` | tekrarlı, dar kayıt (alan/tarih/saat/kişi) | borç — tablo |

Kart **kimlik** gösterir, tablo **tarama** sağlar. Kapıdaki görevlinin
sorusu "hangi dairenin kargosu bekliyor", sakininki "hangi gün
neredeyim" — ikisi de sütun ister. Kart dili bu ekranlarda ekrana üç-dört
kayıt sığdırıyordu.

## A8a.2 Ölçtüğüm ve düzelttiğim BFF kusuru

`/api/kargo` vekili **yalnız `limit`/`offset`** taşıyordu. Backend ise
`durum`, `unit_id`, `baslangic`, `bitis` süzgeçlerini P126.4'ten beri
destekliyor. Yani durum süzgeci eklesem sunucuya **hiç ulaşmayacaktı**;
liste süzülmemiş dönecek, üç özet kartı aynı sayıyı gösterecekti.

Bu **tekrar eden bir kusur sınıfı** (P173/P189/P213 ve bu turda §6). Beyaz
listeyle iletildi; `?` ile gelen her şey değil, yalnızca sözleşmede tarif
edilen alanlar.

## A8a.3 Ölçülen sınır: kargo listesi yönetime KAPALI

Backend'i okurken beklemediğim bir şey buldum:
`GET /kargo`, **admin ve yönetici** için `unit_id` + tek seferlik
görüntüleme izni olmadan **403** veriyor (`kargo_yonetime_kapali`) —
ziyaretçi ekranıyla aynı gizlilik deseni. Yani bu ekranın gerçek
izleyicisi **güvenlik ve sakin**.

**Değiştirmedim.** Bu bir gizlilik kararı, arayüz kararı değil; ama özet
şeridinin ve süzgecin kimin için tasarlandığını bu belirledi.

## A8a.4 Rehberde ÖZET ŞERİDİ YOK — bilerek

Referansın refleksi her ekrana serit koymak. Rehberde sayılacak anlamlı
bir şey yok: *"12 esnaf"* kimsenin sorduğu soru değil. Şerit yerine
**arama + tür süzgeci** kondu; rehberde sorulan gerçek soru "tesisatçı
kimdi". Türler **veriden türetilir** — tür serbest metin alanı, sabit bir
liste bir gün veriyle ayrışırdı.

Arama **istemcide** ve bu ölçüldü: uç sayfalamıyor, `limit` parametresi
**yok**, tüm listeyi tek seferde dönüyor. Elimizdeki dizi listenin
tamamı, yani istemcide süzmek burada eksik sonuç üretmez. (Kargo ve araç
ekranlarında üretirdi — orada sunucuda süzülüyor.)

## A8a.5 Kendi kusurum: aynı sözlük anahtarı iki kontrolde

Süzgeç `<select>`ine form alanıyla **aynı** anahtarı verdim
(`disHizmetTur`). Sonuç: ekranda iki kontrolün erişilebilir adı aynı oldu
ve `yonetici-ekranlari` testi "birden çok eleman" diyerek düştü —
**haklı olarak**. Bu, P239'da kaydedilen dersin aynısı: aynı anahtar iki
düğmede = yanlış hedef. Ayrı anahtarlar açıldı
(`disHizmetTurSuzgec`, `kargoDurumSuzgec`).

## A8a.6 Bilinçli güncellenen iki iddia

* `rezervasyon-kvkk`: alan adı artık kart başlığı değil **hücre**;
  `findByRole("heading")` → `findByRole("cell")`. İddia değişmedi.
* `guvenlik-ekranlari`: "Bekliyor" kelimesi artık durum **süzgecinin**
  seçeneğinde de geçiyor; kapsamsız sorgu iddiayı seçenekle de
  karşılardı. Satır hücresinden okunuyor.

## A8a.7 Kilitler

* **YENİ** `p244-kargo-bff-suzgec` (4 test) — rota işlevini **doğrudan**
  çağırır. DOM testi bunu ölçemez: `fetch` taklit edilir, rota hiç
  çalışmaz (P200/P213 dersi). **İki kırma yakalandı:** süzgeç döngüsünü
  kaldırmak, beyaz liste yerine her şeyi geçirmek.
* **YENİ** `p244-operasyon-listeleri` (7 test) — kaynak taraması kartın
  *gittiğini* ölçer, bu dosya *yerine konanın doğru olduğunu*: gerçek
  `<table>`, korunan `tel:` bağlantısı, korunan rol/durum kapıları.
  **Üç kırma yakalandı:** rol kapısını kaldırmak, telefonu düz metne
  çevirmek, sayaçları görünen listeden türetmek.
* `p244-kart-yigini-yasak`'ta `BORC` listesi **boşaltıldı, silinmedi** —
  iddia "bugün borç yok" olarak kalır ve yeni bir kart yığını eklenirse
  test düşer.

## A8a.8 Bu turda YAPILMAYAN — açıkça

Aşama 8'in operasyon yarısının **yalnızca kart yığını borcu** kapandı.
`/tasks` (1313 satır, kanban görünüm seçici), `/bakim` (672),
`/assets` (414), `/complaints` (367), `/schematic` (420) ve iletişim
modülünün tamamı (`/mesajlar` 564, `/anketler` 594, `/announcements` 408,
`/site-kurallari` 390) **dokunulmadı**. Bunlar 8b ve 8c.

Borcu öne aldım çünkü kilide yazılmış bir sözdü ve listenin bayatlaması
en kolay unutulan şeydi.

## A8a.9 Doğrulama

`tsc` temiz · `eslint` 0 hata (4 uyarı, hepsi P244 öncesinden; kendi
ürettiğim iki uyarı `useMemo` ile kapatıldı) ·
**tam takım 241 dosya / 2034 test yeşil.**

---

# AŞAMA 8b — TALEP ZİNCİRİ + DEMİRBAŞ · UYGULANDI

## A8b.1 Talepler: liste bir duvardı

`/complaints` her talebi **tam açık** gösteriyordu: tam mesaj + bütün
fotoğraflar + bütün durum geçmişi. Yirmi talep = yirmi duvar; *"hangisi
açık"* sorusu ancak kaydırarak yanıtlanıyordu.

Kararın **iki yarısı** var ve ikisi de kilitli:

1. **Ağır olan çekmeceye.** Mesaj, fotoğraflar, durum geçmişi ve bağlı
   iş emri artık detay çekmecesinde.
2. **Eylem satırda kaldı.** Bu ekranın işi **triyaj**: yönetici listeyi
   tarar ve karar verir. "Çöz"ü çekmecenin içine koymak her karara bir
   açma-kapama adımı eklerdi.

İkisi birlikte ölçülmezse tasarım yanlış tarafa kayar: yalnız (1)
ölçülse eylemler de çekmeceye taşınabilirdi; yalnız (2) ölçülse liste
yine duvar kalırdı. Çekmecede Çöz/Reddet **bilerek yok** — aynı eylemi
iki yerde sunmak "hangisi geçerli" sorusunu üreten ikinci bir karar
noktası olurdu.

## A8b.2 ÖLÇÜLEN: aşama 4 renk katmanını kapatmamış

`p244-tek-tasarim-dili` kilidi **modül ithalatını** ölçüyor, sınıf
adlarını değil — bu bilinçli bir seçimdi (jsdom renk çözmez, P226). Ama
bir boşluk bıraktığını şimdi ölçtüm:

`/complaints` yalnız `@/components/ui`den ithal ettiği için kilidi
**haklı olarak geçiyordu**, oysa rozet renkleri hâlâ ham palet
sınıflarıydı (`bg-amber-100 text-amber-700`).

**Taradım: 22 sayfa** hâlâ ham tailwind palet sınıfı ya da eski dilin
renk yardımcılarını (`text-metin-*`, `kart-kenar`, `yuzey-divider`)
taşıyor. Bu turda **dokunduğum sayfalarda** kapattım; kalan liste
**aşama 10'un hedefi** ve sayısı burada yazılı, böylece "bitti sanmak"
mümkün değil.

`/assets`te bulduğum şey daha basitti: ham paleti taşıyan tek sabit
(`DURUM_STYLE`) **ölü koddu** — rozet rengi zaten `durumRengi` üzerinden
token'dan geliyordu. Silindi.

## A8b.3 Kart HER YERDE yanlış değil — iki yeni istisna

Aşama 8a'da üç sayfayı karttan tabloya taşıdım. Bu turda **tersini**
savundum ve kilide iki istisna ekledim:

* **`/gorevlerim`** — kart okunacak değil **yapılacak** bir iş: içinde
  bir not alanı ve bir tamamlama düğmesi var. Girdi taşıyan kaydı tablo
  hücresine sıkıştırmak dokunma hedefini de küçültürdü.
* **`/taleplerim`** — kart **okunacak bir metin**: konu + çok satırlı
  serbest açıklama. Tabloya çevirmek mesajı tek hücreye sıkıştırırdı.
  Paneldeki `/complaints` bunun **taranan** karşılığı ve orada tablo
  doğru seçim. Aynı veri, iki farklı soru, iki farklı düzen.

İkisinde de değişen şey **kartın kendisi değil, kartın yüzey
kazanması**: kayıtlar çıplak `<article>` idi ve birbirine akıyordu.

`/taleplerim`de ayrıca durum **renk de taşımaya başladı**: dört durum da
aynı nötr gri balondaydı, oysa sakinin bu ekranda sorduğu tek soru
"talebim ne oldu". Eşleme panelinkiyle **aynı** — aksi hâlde sakin ve
yönetici aynı durumu farklı renkte görürdü.

## A8b.4 Kilidin yakaladığı GERÇEK kusur

`ham-enum` taraması `{g.durum}` satırını yakaladı: durum geçmişinde
bilinmeyen bir durum için **ham veritabani sabiti** ekrana yazılıyordu.
Bu kod **eskiden de vardı** (`{meta ? t(...) : g.durum}`) ama tek
satırda olduğu için taramadan geçmişti; ayrı satıra düşerken yakalandı.
Depoda bunun için zaten bir anahtar var (`talepDurumBilinmiyor`).

Ayrıca `erisilebilir-etiket` taraması **kendi yorumumu** yakaladı
(yorumda geçen `<Secim>`); yorum yeniden yazıldı. Tarama haklı: kaynak
metni yorumla kodu ayırt etmez.

## A8b.5 Kilitler

**YENİ** `p244-talep-ekrani` (6 test) — kararın iki yarısını birlikte
ölçer. **İki kırma yakalandı:** mesajı tabloya geri koymak (liste yine
duvar), eylemleri satırdan kaldırıp çekmeceye taşımak.

Bilinçli güncellenen iddia: `talep.dom`da Çöz/Reddet sorguları
**diyaloğa kapsamlandı**. Eskiden satırdaki düğme form açılınca
kayboluyordu (`canAct && !action`); artık eylemler satırda **kalıyor**.
Diyalog `aria-modal` taşıdığı için ekran okuyucu arkadakini zaten
görmez. İddia değişmedi.

## A8b.6 Bu turda YAPILMAYAN — açıkça

* **`/tasks`** (1313 satır) — dokunulmadı. Zaten `VeriTablosu` +
  sekmeli görünüm kullanıyor; kalanı sayfa başlığı ve özet şeridi.
* **`/bakim`** (672), **`/schematic`** (420) — dokunulmadı.
* İletişim modülünün **tamamı** — dokunulmadı (8c).
* `/assets`te zimmet geçmişi hâlâ tablonun **altında bir kart**;
  çekmeceye taşınmadı (kaydırma çıpası `detayRef` ile birlikte ayrı bir
  karar).
* Renk katmanı borcu: **22 sayfadan** yalnız bu turda dokunulanlar
  temizlendi.

## A8b.7 Doğrulama

`tsc` temiz · `eslint` 0 hata (4 uyarı, hepsi P244 öncesinden) ·
**tam takım 242 dosya / 2040 test yeşil.**

---

# AŞAMA 8c — GÖREVLER, BAKIM, ŞİKAYET HARİTASI · UYGULANDI

## A8c.1 Görevlerde ÇALIŞMAYAN bir özellik buldum

Bu bir tasarım eksiği değil, **bozuk bir özellikti**:

* Sayfa `kategori_id`yi sorguya **ekliyordu**,
* Arka uç `kategori_id`yi **destekliyor** (UUID veya `"diger"`),
* Ama BFF rotası yalnız `limit`/`offset`/`aktif`/`atanan_user_id`
  taşıyordu — `kategori_id` ve `durum` **sessizce düşüyordu**.

Yani kullanıcı bir kategori seçiyor ve **liste aynen kalıyordu**.
Sayfadaki yorum *"SÜZGEÇ ARTIK GERÇEK"* diyor; arka uç için doğruydu,
**yol için değildi**.

Aynı kusur sınıfının depoda **dördüncü** örneği: P173, P189, P213 ve bu
turda §6 (araç geçişleri) ile §8a (kargo). Bu kadar tekrar edince artık
bir kaza değil: **BFF, vekil olduğu için görünmez, ve görünmeyen katman
sessizce yanlış olur.**

## A8c.2 İkinci ölü özellik: durum süzgeci

`durumFiltre` **durumu vardı**, sorguya **ekleniyordu** — ama onu
kuracak **hiçbir kontrol yoktu**. P230 §4'te eklenen görev durumu
süzgeci (atandı / başlandı / tamamlandı / gecikti) webden **hiç
kullanılamıyordu**. Ekrana getirildi.

İki kusur birlikte anlamlı: kontrol olsa bile BFF onu düşürecekti.

## A8c.3 Şerit sayıları — bu turun en çok tekrar eden kusuru

Dört ekranda aynı karar: **sayaçlar görünen listeden türetilmez.**

`/bakim`da bu özellikle keskin. Liste `?durum=` ile süzülüyor; sayaçlar
kendi sorgularını atmasa, *"planlı"* seçili bir ekranda geciken bakım
sayısı **0** görünürdü — yani ekran, **geciken bakım yok derdi**.

`/schematic` **bilinçli istisna**: orada veri sayfalı değil,
`building-map` binanın tamamını tek yanıtta veriyor (harita zaten ancak
öyle çizilebilir). Elimizdeki ağaç listenin tamamı olduğu için istemci
sayımı **doğrudur** ve uca üçüncü bir istek atmak gereksizdi.

## A8c.4 Kilidin yakaladığı kendi hatam

Haritada "Haritadaki daire" kartına, haritanın altında **zaten yazan**
"N dairenin kat/sıra bilgisi eksik" cümlesini alt bilgi olarak
koymuştum. `yz-plan-haritasi` kilidi "birden çok eleman" diyerek düştü
— **haklı**: ekranda iki kez okunan tek bir bilgi.

Düzeltirken ikinci bir hata daha çıktı: sayacı **tüm kayıtlı daireler**
üzerinden hesaplıyordum, oysa kat/sıra girilmemiş daire **haritada
yoktur**. Etiketi yalan yapıyordu; sayım çizilebilen hücrelere
(`hucreler`) bağlandı.

## A8c.5 Renk katmanı

`/tasks` tamamlama tablosundaki ham palet kalıntıları (`kart-kenar`,
`text-metin-body`, `text-metin-muted`, `bg-emerald-100`) token'a
çevrildi. 8b'de sayılan **22 sayfalık** borçtan bu turda dokunulanlar
düştü.

## A8c.6 Kilitler

* **YENİ** `p244-gorev-bff-suzgec` (5 test) — rota işlevini doğrudan
  çağırır. **İki kırma yakalandı:** süzgeç döngüsünü kaldırmak, beyaz
  liste yerine her şeyi geçirmek. Ayrıca "önceden çalışan süzgeçler
  bozulmadı" iddiası da kilitli.
* **YENİ** `p244-operasyon-ekranlari` (4 test) — durum süzgecinin
  ekranda olduğunu, seçilen durumun **listeye** uygulandığını (sayaç
  isteğiyle karışmasın diye `limit=1` olmaması aranıyor) ve şerit
  sayaçlarının ayrı sorgulardan geldiğini ölçer. **İki kırma
  yakalandı:** durum seçimini kaldırmak, bakım sayaçlarını görünen
  listeye bağlamak.

## A8c.7 Bu turda YAPILMAYAN — açıkça

* **İletişim modülünün tamamı** dokunulmadı: `/mesajlar` (564),
  `/anketler` (594), `/announcements` (408), `/site-kurallari` (390),
  `/etkinlik-yonetimi` (299), `/duyurular`, `/kurallar`, `/etkinlikler`,
  `/davetler`. Bu artık **aşama 8d**.
* `/tasks`ta kanban ve takvim görünümlerinin **iç düzeni** değişmedi;
  yalnız sayfanın başlığı, şeridi ve süzgeç çubuğu yenilendi.
* `/tasks`ta tamamlama kayıtları hâlâ tablonun **altında bir kart**
  (çekmeceye taşınmadı — `/assets` ile aynı açık madde).

## A8c.8 Doğrulama

`tsc` temiz · `eslint` 0 hata (4 uyarı, hepsi P244 öncesinden) ·
**tam takım 244 dosya / 2049 test yeşil.**

---

# AŞAMA 8d — İLETİŞİM: SAKİN TARAFI · UYGULANDI

## A8d.1 Bu turda bulduğum şey bir tasarım eksiği değildi

Sözleşme `Announcement`, `Etkinlik` ve `SiteKurali` şemalarının
**üçünde de** `foto_url` (kısa ömürlü presigned GET) söz veriyor.
Yönetim ekranları görsel **yüklüyor** — kural görseli P190 §3'te
**özellikle** eklenmişti.

Sakin taraftaki üç ekran bu alanı **yerel tiplerine hiç koymamıştı**:

| ekran | uçtan gelen ama çizilmeyen |
|---|---|
| `/duyurular` | `foto_url`, `olusturan_ad` |
| `/etkinlikler` | `foto_url`, `olusturan_ad`, `katiliyorum_sayisi`, `katilmiyorum_sayisi` |
| `/kurallar` | `foto_url` |
| `/yonetim-iletisim` | `avatar_url` (tipte **vardı**, hiç kullanılmıyordu) |

Yani yönetici bir duyuruya kapak görseli ekliyor, **sakin onu hiç
görmüyordu**. Kural görseli eklendiği günden beri görünmüyordu.

**Bu kusurun türü önemli:** ekran hatasız çalışıyor, testler yeşil,
yalnızca veri eksik. Hiçbir kilit bunu yakalayamazdı çünkü hiçbir kilit
*"uç ne veriyorsa ekran onu gösteriyor mu"* diye **sormuyordu**.
`uc-sozlesme-kapisi` ters yönü ölçüyor (sözleşmenin **vermediği** alan
okunmasın). Eksik yön artık kilitli.

## A8d.2 Katılım sayıları: okunur, basılmaz

`Etkinlik` şeması katılım sayıları için açıkça *"ŞEFFAF katılım
sayıları; sayılar herkese açık"* diyor — yani **okunması ürün gereği**.
Sayılar geldi.

**RSVP beyanı hâlâ yok** ve dosyanın başındaki karar geçerli: beyan bir
**yazma** akışıdır, kendi doğrulama/geri alma davranışını ister.
Değişen şey salt okunur sayıların görünür olması — yarım bir düğme
eklemek değil. Bu yüzden sayılar **rozette**: rozet okunur, düğme
basılır; basılamayan bir düğme çizmek kullanıcıyı bir kez aldatırdı.

## A8d.3 `IcerikKarti` — üç ekran tek bileşen

Üç ekran aynı şeyi gösteriyor: başlık + üst veri satırı + serbest metin
+ opsiyonel kapak. Üç kez yazmak, görselin oran/kırpma davranışının üç
yerde ayrışması demekti.

**Kapak oranı sabit** (`aspect-[16/9] object-cover`) ve bu bilinçli:
görseller kullanıcı yüklemesidir; dikey bir telefon fotoğrafı kartı
ekran boyu uzatırdı. Kırpar ama **düzeni korur**.

`/kurallar`da `<ol>` **korundu**: kurallar numaralandırılmış bir
metindir ve ekran okuyucu sıra bilgisini ancak listeden alır. Kart
yüzeyi listenin **içine** girdi, dışına değil — bu, kart eklerken en
kolay kaybedilecek şeydi ve kilitli.

## A8d.4 Sözlük anahtarı AÇMAMA kararı

Duyurunun üst veri satırı için `"{zaman} · {kisi}"` anahtarı açtım ve
sözlük bütünlüğü kilidi **haklı olarak** düştü: yedi dilde aynı dize,
yani "TR kopyası". Anahtar **silindi**; ayraç bir cümle değil bir
**noktalama** ve şablonda kalıyor (etkinlik ekranı da aynı deseni
kullanıyor).

## A8d.5 Renk katmanı borcu 22 → 18

`mesajlar` (SMS önizleme kutusu, unicode uyarısı, sayaç satırları),
`anketler` (sonuç tablosu kenarı) ve paylaşılan `Foto` bileşeninin
**hata yer tutucusu** token diline geçti. Üçü de ayrı bir `dark:`
eşlemesi taşıyordu; token zaten iki modda da doğru değeri veriyor.

Ölçülen bir **boşluk**: tasarım sisteminde **yumuşak ton yok** —
`Rozet` de dolgu kullanmıyor, yalnız kenar + metin. Unicode uyarısı bu
yüzden `surface-sunken` zemin + `warning-edge` kenar + `warning-ink`
metinle kuruldu. Uydurma bir pastel ton eklemek koyu modda ikinci bir
eşleme borcu açardı. **Yumuşak ton ailesi gerekiyorsa aşama 10'un
kararıdır**, bir sayfanın yan etkisi değil.

## A8d.6 Kilit

**YENİ** `p244-sakin-icerik` (8 test). **Üç kırma yakalandı:** duyuruda
`foto_url`u yeniden düşürmek, kuralları `<ol>` dışına çıkarmak,
etkinlikten katılım sayılarını kaldırmak. Ayrıca iki **negatif** iddia
da kilitli: görsel yokken boş kutu çizilmemesi, etkinlikte katılım
düğmesi **olmaması**.

## A8d.7 Bu turda YAPILMAYAN — açıkça

* **Yönetim tarafı iletişim ekranları** yalnız renk katmanında
  temizlendi; düzenleri değişmedi: `/announcements` (408),
  `/site-kurallari` (390), `/etkinlik-yonetimi` (299), `/mesajlar`
  (564), `/anketler` (594), `/davetler` (199).
* Duyuruda **hedef kitle rozeti** yapılmadı: hedefleme kuralları
  P190 §3'te yönetim tarafında; sakin listesinde zaten yalnız kendisine
  ulaşanlar var, rozet orada bilgi taşımazdı.
* Etkinlikte **RSVP beyanı** yapılmadı (yukarıdaki gerekçe).
* Renk katmanı borcu: **18 sayfa** kaldı (aşama 10).

## A8d.8 Doğrulama

`tsc` temiz · `eslint` 0 hata (4 uyarı, hepsi P244 öncesinden) ·
**tam takım 245 dosya / 2057 test yeşil.**

---

# AŞAMA 9a — TANIMLAR / AYARLAR: USTA-DETAY · UYGULANDI

## A9a.1 On bir defter, saran bir düğme sırası

`/tanimlar` on bir kayıt defterini sayfanın üstünde **saran** bir düğme
sırası olarak diziyordu: iki-üç satıra yayılan düğmeler, yalnızca renkle
(ve `aria-pressed` ile) belli olan seçim, her tıklamada aşağı kayan
içerik.

Dikey liste on bir öğeyi **tek sütunda** gösterir, seçili olan
**konumunu korur** ve göz listeyi yukarıdan aşağı tarar. Referansta bu
ekranların hepsi usta-detay.

## A9a.2 Neden `Sekmeler`in bir varyantı değil

`Sekmeler` içeriği **kendi tutar** (`sekme.icerik`) — yani on bir
defterin hepsini birden kurmak demektir. Her defterin **kendi `useSWR`i**
var; fark, bir istek ile **on bir istek** arasındaki farktır.

`UstaDetayDuzeni`de içerik `children` olarak dışarıdan gelir: çağıran
yalnız seçili olanı çizer. Bu, bileşeni ayırmanın **tek gerekçesi** ve
kilitli (`YALNIZ SECILI DEFTERIN UCU CAGRILIR`).

## A9a.3 Erişilebilirlik: `aria-pressed` yetmiyordu

Eski düğme sırası `aria-pressed` taşıyordu — P160'ta eklenmişti ve o
gün doğruydu. Ama `aria-pressed` ekran okuyucuya *"bu N öğeden K'sı"*
demez; sekme deseni der. Yeni düzen gerçek `role=tablist` +
`aria-orientation=vertical` + `role=tab` + `aria-selected`.

**Seritte tek klavye durağı** (`tabIndex`): on bir sekmenin her biri
odaklanabilir olsaydı klavye kullanıcısı içeriğe ulaşmak için **on bir
kez** Tab'a basardı. Gezinme ok tuşlarıyla — ve dört ok tuşu da kabul
ediliyor, çünkü **dar ekranda aynı şerit yatay çiziliyor** ve orada
kullanıcının refleksi sağ/sol olur.

## A9a.4 Bilinçli güncellenen iddia

`sayac.dom` ve `pano-daire-tanim.dom` defter seçicilerini
`getByRole("button")` ile buluyordu. Öğeler hâlâ `<button>` etiketi ama
artık **açık bir role** taşıyorlar ve erişilebilirlik ağacında sekme
olarak duruyorlar. Sorgular `tab`a güncellendi; **iddia değişmedi**:
defter seçiciyi bul, tıkla, o defterin ucu çağrılsın.

## A9a.5 Yetki matrisi: üç sayı, başka yerden okunamaz

`/yetki`ye özet şeridi eklendi ve sayılar **istemcide** hesaplanıyor —
`/schematic` ile aynı bilinçli istisna: matris sayfalı değil, sunucu tüm
uçları tek yanıtta veriyor ("kim neye erişiyor" sorusu ancak böyle
yanıtlanır).

Üçüncü kart özellikle eklendi: **"rol kapısı yok"** sayısı. Sayfanın en
başındaki not zaten *"rol kapısı yok ≠ herkese açık"* diyor; kartın alt
bilgisi bunu tekrar söylüyor, çünkü bir sayıyı rakam olarak görmek
yorumu davet eder.

Tablo `yogunluk="sik"` + yapışkan başlık: yüzlerce uç ve **rol başına
bir sütun** var; ekrana çok satır sığması satır yüksekliğinden değerli.

## A9a.6 Kilit

**YENİ** `p244-usta-detay` (5 test). **Üç kırma yakalandı:** her sekmeyi
odaklanabilir yapmak, `aria-selected` yerine `aria-pressed` kullanmak,
bütün defterleri birden çizmek.

## A9a.7 Bu turda YAPILMAYAN — açıkça

Aşama 9'un yalnız ilk parçası bitti. **Dokunulmayanlar:**
`/users` (1007), `/profil` (1048), `/kurulum` (386), `/ice-aktarim`
(742), `/dokumanlar` (512), `/karar-defteri` (315), `/transparency`
(240), `/audit` (225), `/tenants` (565). Bunlar 9b ve 9c.

`/settings` ve `/tesis-ayarlari` yalnız **sayfa başlığını** aldı; form
düzenleri (kart grupları) zaten makul ve usta-detaya çevrilmedi — iki
ekranın toplamı beş kart, sol liste bir sütun israfı olurdu.

## A9a.8 Doğrulama

`tsc` temiz · `eslint` 0 hata (4 uyarı, hepsi P244 öncesinden) ·
**tam takım 246 dosya / 2062 test yeşil.**

---

# AŞAMA 9b — KULLANICILAR + PROFİL · UYGULANDI

## A9b.1 Süzgeçler hata hâlinde kayboluyordu

`/users`ın rol/durum/arama süzgeçleri tablonun **`araclar` yuvasının
içindeydi**. Tablo hata alınca "tekrar dene" çizer ve süzgeçler
**onunla birlikte kaybolurdu** — oysa kullanıcının ilk refleksi süzgeci
değiştirip tekrar denemektir.

Bu, dosyanın kendi yorumunun **zaten söylediği** bir kural: hata
durumu tablonun içine alınırken "dışarıda bir dal olsaydı hata çıkınca
SÜZGEÇLER de kaybolurdu" diye yazılmış. Kural doğruydu, uygulama ters
düşmüştü: süzgeçler de aynı kutunun içindeydi.

`FiltreCubugu` tablonun **dışına** çıktı ve iddia kilitli.

## A9b.2 Sayaçlar: rol süzgeci açıkken "Sakin: 0"

Üç kart (aktif / sakin / pasif) ayrı sorgulardan (`?...&limit=1` →
`meta.total`). Görünen sayfadan saymak iki kez yanlış olurdu: liste hem
**sayfalı** (25'lik) hem **süzgeçli** — rol süzgeci açıkken sayaç da
süzülür ve *"Sakin: 0"* yazardı, oysa sakin var, yalnızca listede yok.

## A9b.3 ÖLÇÜLDÜ: `/users`ta avatar YAPILAMAZ

Plan *"`/users` sekmeli tablo + **avatar** + rol rozeti"* diyordu.
Sözleşmeyi okudum: `UserListItem` şeması `avatar_url` **vermiyor**
(`id, ad, email, aranabilir, role, is_active, gorev_*, created_at`).
Tek-kayıt `User` şemasında da yok.

Uydurulmadı. `uc-sozlesme-kapisi` kilidi zaten buna izin vermezdi ve
kilit haklı: sözleşmenin vermediği bir alanı okuyan arayüz, bir gün
sessizce boş çizer. **Avatar istenirse önce sözleşme + backend işidir**
— arayüz turunun kapsamı değil.

Rol zaten `Rozet` ile noktalı çiziliyor; o kısım **vardı**.

## A9b.4 `/profil` ÇEVRİLMEDİ — ve bu ölçülmüş bir karar

`/profil` **zaten** usta-detay: solda bölüm listesi, sağda içerik.
`UstaDetayDuzeni`ye çevirmedim, çünkü çevirmek **üç şeyi bozardı**:

* Sol liste bir **`<nav>`** ve bu P169 §4'te bilinçli seçilmiş — ekran
  okuyucu kullanıcısı gezinme bölgesini **atlayabilir**.
* **"Hesabımı sil"** öğesi `tehlikeli` işaretiyle kırmızı çiziliyor;
  `UstaDetayDuzeni` böyle bir kavram taşımıyor. Sırf tutarlılık için
  onu kaybetmek, yıkıcı bir seçimi diğerleriyle aynı göstermek olurdu.
* **Altı öğe var, on bir değil**: `/tanimlar`daki "on bir kez Tab"
  sorunu burada yok.

**AÇIK MADDE (aşama 10):** iki kardeş ekran aynı şekil için **iki
desen** kullanıyor — `/tanimlar` `role=tablist`, `/profil` `<nav>` +
`aria-current`. İkisi de geçerli ARIA desenleri ve her birinin bu
ekrandaki gerekçesi yukarıda yazılı, ama **tutarsızlık gerçek**. Aşama
10'da ya `UstaDetayDuzeni`ye "tehlikeli öğe" + gezinme semantiği
eklenip ikisi birleştirilmeli, ya da ayrılık kalıcı bir kural olarak
yazılmalı. Bu turda sessizce birini ötekine benzetmek, iki gerçek
davranışı gizlemek olurdu.

## A9b.5 Kilit

**YENİ** `p244-kullanici-ekrani` (3 test). **İki kırma yakalandı:**
sayaçları görünen listeden türetmek, süzgeçleri tablonun `araclar`
yuvasına geri koymak.

İkincisi özellikle önemliydi: bu turda **kendi elimle** üretebileceğim
bir gerilemeydi — süzgeçleri çubuğa taşırken tablonun içinde bırakmak
da mümkündü.

## A9b.6 Bu turda YAPILMAYAN — açıkça

`/kurulum` (386), `/ice-aktarim` (742), `/dokumanlar` (512),
`/karar-defteri` (315), `/transparency` (240), `/audit` (225),
`/tenants` (565) dokunulmadı — aşama 9c.

`/profil`in **iç bölümleri** (hesap, güvenlik, bildirim, yasal, şifre,
hesap silme) düzen olarak değişmedi; yalnız sayfa başlığı geldi.

## A9b.7 Doğrulama

`tsc` temiz · `eslint` 0 hata (4 uyarı, hepsi P244 öncesinden) ·
**tam takım 247 dosya / 2065 test yeşil.**
