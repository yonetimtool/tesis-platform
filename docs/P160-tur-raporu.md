# P160 — admin-web Premium Enterprise yeniden tasarımı

> Dal: `main` · Kapsam **yalnız `admin-web`** (KİLİTLİ KURAL 1) ·
> Canlıya deploy yok · Backend / sözleşme / veri modeli / mobil
> **dokunulmadı**.

---

## 0. DURUM ÖZETİ

| Aşama | Durum |
|---|---|
| 0 — Envanter | ✅ `docs/frontend-envanter.md` |
| 1 — Tasarım sistemi | ✅ `--yz-*` token katmanı, WCAG kilidi |
| 2 — Kabuk (sidebar + header) | ✅ katlanma · Ctrl+K paleti · bildirim merkezi |
| 3 — Ortak bileşen katmanı | 🟡 **çoğu** — kalan liste §6 |
| 4 — Canlı Panel | ✅ KPI halkaları + 3D sahne |
| 5 — 3D | ✅ BuildingScene · 🟡 RouteScene planlandı (`docs/3d-yol-haritasi.md`) |
| 6 — Modüllerin taşınması | ❌ **başlanmadı** — 49 sayfa, §6 |
| 7 — Hareket | ✅ sayfa geçişi + mikro etkileşimler |
| 8 — Duyarlılık / erişilebilirlik | 🟡 yeni yüzeylerde ✅, taşınmamış sayfalarda eskisi gibi |
| 9 — Performans | ✅ ölçüldü — §4 |
| 10 — QA | ❌ **yapılmadı** — §7 |

**Tek cümle:** *altyapı ve vitrin ekranı bitti, 49 sayfanın taşınması
başlamadı.*

---

## 1. VERİLEN BÜYÜK KARARLAR

### 1a. Token çelişkisi → seçenek C (Kerem seçti)
`tests/tasarim-token.test.ts` web renklerini **mobile** kilitliyor;
Aşama 1 ise yeni palet istiyor. Dördü aynı anda sağlanamıyordu. Karar:
yeni dil eskinin **üstüne değil yanına** kondu. `globals.css` ve
`tailwind.config.ts` hiç değişmedi → parite testi yeşil, mobile
dokunulmadı, taşınmamış 49 sayfa eski tokenlarıyla çalışmaya devam
ediyor. **Bedeli:** geçiş boyunca iki dil bir arada yaşıyor.

### 1b. Brief'in paleti WCAG AA'yı tutmuyordu
Yazdığım kontrast testi **beş** gerçek düşüklük yakaladı (ör. açık temada
`--yz-text-3` sayfa zemininde 2.16, eşik 3.0). Ton ve doygunluk
korunarak yalnız açıklık kaydırıldı. Ayrıca durum renkleri **üç
varyanta** ayrıldı: ham (dolgu) · `-ink` (metin, 4.5) · `-edge` (anlamlı
grafik, 3.0). Ham tonu 3.0'a zorlamak paleti bozardı (`warning`
kahverengileşiyordu).

### 1c. Kabuk yeniden yazılmadı, giydirildi
`AppShell` kalıcılık, rol/yüzey süzme, hidrasyon güvenliği gibi
belgelenmiş kararlar taşıyor. Yeniden yazmak KİLİTLİ KURAL 2'yi riske
atardı. `menu.ts` + `yuzey.ts`'e **hiç dokunulmadı** — bu, kural 2 ve
4'ü yapısal olarak garanti ediyor.

### 1d. R3F sürümü — `--force` değil uyumlu majör
`@react-three/fiber@9` React ≥19 istiyor, proje React 18'de. Peer
uyarısını bastırmak çalışma zamanında patlardı; **v8 + drei v9** kuruldu.

### 1e. KPI kartları bağlantı, düğme değil
`useRouter` eklemem 23 pano testini düşürdü. Doğru cevap testleri
düzeltmek değil **bağlantı kullanmaktı**: orta tıkla yeni sekme, ekran
okuyucu "bağlantı" der, router taklidi gerekmez.

### 1f. Birim yeri dile bırakıldı
Türkçe `%78`, İngilizce `78%`. `Kpi` artık `birim` değil `bicimle`
alıyor; pano `Intl.NumberFormat`i aktif dille kuruyor. Bileşeni bir
tarafa sabitlemek yedi dilden altısında yanlış olurdu.

---

## 2. DEPO KİLİTLERİ — 11 kez yakaladı, hiçbiri gevşetilmedi

Üçlüde dize · şablon dizgesinde CSS · yorumda Türkçe karakter · yorumda
eski sınıf adı · adsız form denetimi · elle tablo yazma · menü boşluğu ·
dil seçici konumu · tint blok ölçüsü · sabit hex renk · i18n anahtar
çakışması.

**Üç tanesi öğreticiydi:**

- **`erisilebilir-etiket`** `ui/alan.tsx` ilkellerini yakaladı.
  `ParolaAlani` emsaliyle muaf tutuldu **ve muafiyet ödendi**: "yeni form
  ilkelleri etiketli kullanılıyor" testi her çağrı yerini denetliyor.
  Kilit **taşımadan önce** kondu.
- **`(P138) TABLO İLKELİ`** yeni `VeriTablosu`yu "elle tablo yazan sayfa"
  sandı. Muafiyet listesine eklendi — kilit *"her sayfa kendi tablosunu
  yazmasın"* diyor, bu ise sayfaların kullanacağı ilkel.
- **Kendi token disiplin testim** rozetteki `#ffffff`'i yakaladı ve
  **gerçek bir kusurumu** ortaya çıkardı: `dugme.tsx`'te *"kontrast
  ölçüldü (≥4.5)"* yazıyordu, ölçülmemişti — gerçek değer 3.88. Dolgular
  koyulaştırıldı, değer `--yz-on-fill` token'ına taşındı, **muafiyet
  listesi tamamen kaldırıldı**.

**İki kilit dile göre taşındı, silinmedi:** `pano-tint-blok` (koruduğu
şey dil değil *ölçü*ydü: "en çok dört ikincil gösterge") ve `pano.dom`
(görsel rakam yerine erişilebilir metin — KPI sayarak geldiği için
görsel metne bakan test yarışa girer).

---

## 3. YAN BULGULAR (P160 kapsamı dışında, düzeltildi)

- **`ThemeToggle` korumasız `localStorage` okuyordu.** Gizli sekmede /
  depolama engelliyken bu, tema anahtarını değil **tüm kabuğu**
  çizilemez hale getiriyordu. Katlanma testi yakaladı.
- **Kök dizine yanlışlıkla `package.json` oluşturdum** (hatalı `npm
  install`); fark edilip kaldırıldı, depoya girmedi.

---

## 4. PERFORMANS ÖLÇÜMÜ (Aşama 9)

| | 3D öncesi | 3D sonrası |
|---|---|---|
| Paylaşılan First Load JS | **87.5 kB** | **87.6 kB** (+0.1) |
| `/dashboard` ilk yük | — | 116 kB |

**3D ana pakete girmedi** — `next/dynamic` + `ssr:false` çalışıyor.
Eklenen bağımlılıklar: `three@0.169` · `@react-three/fiber@8` ·
`@react-three/drei@9` · `recharts@2`.

**FPS ölçülmedi** — jsdom WebGL çalıştırmaz; gerçek tarayıcı gerekiyor.
`frameloop="demand"` ile *yapısal* güvence var (hareketsiz sahne kare
çizmez) ama sayı test sunucusunda ölçülmeli (`docs/3d-yol-haritasi.md` §7).

---

## 5. TESTLER

| | |
|---|---|
| Web takımı | **816 yeşil** (başlangıç 736 → +80) |
| Yeni test dosyası | 5: token kontrastı · bileşen sözleşmesi · veri tablosu · kabuk katlanma · palet+bildirim |
| `lint` · `tsc` · `build` | temiz |

---

## 6. YAPILMAYANLAR — açık liste

### Aşama 3'ten kalan bileşenler
`DatePicker` · `ChartCard` (Recharts kurulu ama sarmalayıcı yazılmadı) ·
`Toast`'ın yeni dile geçişi · `MapViewer` (Leaflet kurulmadı — gerekçe
`docs/3d-yol-haritasi.md` §5).

### Aşama 6 — modüllerin taşınması: **hiç başlanmadı**
52 korumalı sayfanın **51'i** hâlâ eski dilde (yalnız `/dashboard`
taşındı). Envanterin ölçümü: 14.680 satır, ortalama 282 satır/sayfa.
Her sayfada yapılacak: yeni bileşenlere geçiş + modal deseni + skeleton
+ boş/hata durumu.

**Bilinçli olarak başlamadım.** Brief *"yarım bırakılan ekranı eski
haliyle çalışır bırak — kırık ekran teslim etme"* diyor; kalan bağlamda
bir sayfayı bitiremeyeceğim için hiç dokunmamayı seçtim. **Bugün hiçbir
ekran bozuk değil.**

### Aşama 10 — QA: yapılmadı
Rol bazlı el turu (üç rol × ~35 rota) yapılmadı. Otomatik takım yeşil
ama brief'in istediği "her menü öğesine tek tek gir" turu **elle**
yapılmalı — test sunucusunda.

---

## 7. TEST SUNUCUSUNDA NE GÖRECEKSİNİZ

```bash
git pull && cd admin-web && npm ci && npm run build
```

**Değişen:** kabuk (metalik zemin, kabartmalı aktif menü, **katlanabilir**
sidebar), üst barda **Ctrl+K paleti** ve **bildirim merkezi**, ve
**Canlı Panel** (KPI halkaları + 3D site maketi).

**Değişmeyen:** diğer 51 sayfa — eski görünümde ve **tam çalışır**.

Kontrol listesi:
- Ctrl+K → palet açılır, iki harften sonra arama; oklarla gezinme
- Sidebar'daki `‹` → daralır, sayfa yenilenince **dar kalır**
- Canlı Panel → halkalar 0'dan sayar; 3D maket döner/yakınlaşır
- Tema anahtarı → her iki temada da metalik yüzeyler
- İşletim sisteminde "hareketi azalt" → sayaçlar saymaz, sahne durur
