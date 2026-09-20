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
