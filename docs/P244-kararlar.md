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
