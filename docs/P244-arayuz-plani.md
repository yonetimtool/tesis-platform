# P244 — Arayüz yeniden tasarımı · AŞAMA 1: ÖLÇÜM ve PLAN

**Bu belgede kod yok.** Ölçüm, karar önerisi ve aşama planı var. Onay bekliyor.

---

## 0. REFERANS GÖRSELLER — NE OKUDUM

Dosya adları belirttiğinizden farklı; klasörde `ui1.png` … `ui5.png` duruyor
(hepsi bugün 07:57). Beşini de açtım. Eşleştirme benim okumam:

| dosya | sizin adlandırmanız | içerik |
|---|---|---|
| `ui1.png` | 01-guvenlik-modulu | Güvenlik modülü 7 ekran + **Design System bandı** |
| `ui2.png` | 02-tesis-finans | Tesis + Finans, 23 ekran küçük ölçekte |
| `ui3.png` | 03-guvenlik-detay | Güvenlik 9 ekran, **okunaklı ölçekte** |
| `ui4.png` | 04-ana-sayfa | *aslında* İletişim + Tanımlar, 24 ekran |
| `ui5.png` | 05-iletisim-tanimlar | *aslında* **Ana Sayfa**, tam ölçekli |

`ui4` ve `ui5`'in içeriği adlandırmanızla ters. Yanlış okuduysam düzeltin.

Klasörde ayrıca Ağustos'tan kalma 3 WhatsApp JPEG var (mobil ana ekran
referansları) — bu turla ilgisiz, dokunmadım.

### 0.1 Tasarım sistemi bandı (`ui1`)

| rol | etiket | pikselden ölçtüğüm |
|---|---|---|
| Primary | `#2563EB` | `#176bf8` |
| Primary Hover | `#1d4ed8` | `#1b63ec` |
| Success | `#16a34a` | `#0aa259` |
| Warning | `#f59e0b` | `#fa9903` |
| Danger | `#ef4444` | `#f0413f` |
| Background | `#f7f9fc` | `#f2f6fa` (gutter'dan) |
| Surface | `#ffffff` | `#ffffff` |
| Border | `#e4e7ec` | — |
| Text | `#172033` | `#162b43` |
| Secondary | `#667085` | `#556e8f` |

Piksel değerleri etiketlerden biraz sapıyor (görsel bir *render*, gradyanlı
swatch'lar). **Etiketleri doğru kabul ediyorum** — hepsi Tailwind'in standart
tonları (blue-600/700, green-600, amber-500, red-500). Uydurma bir palet değil.

Tipografi: **Inter / Geist**. Başlık 24/600 · Alt başlık 18/600 · Section 16/600 ·
Body 14/400 · Secondary 13/400 · Caption 12/400.

### 0.2 Kabuk (`ui5` — tam ölçekli ana sayfa)

* **Kenar çubuğu**: koyu lacivert (ölçtüm: `#14263a`), ~200 px. Üstte marka +
  slogan. Öğeler **düz liste**, üstlerinde küçük-kapital bölüm etiketleri
  (`YÖNETİM`, `TESİS YÖNETİMİ`, `RAPORLAR`, `SİSTEM`; etiket rengi `#6d8cb1`).
  Aktif öğe = **dolu mavi hap**. En altta **site değiştirici kartı**: bina
  küçük görseli + "Beyoğlu Konakları / Site Yönetimi" + `›`.
* **Üst çubuk**: beyaz, geniş arama alanı + sağında **`Ctrl K`** rozeti; zil
  (kırmızı `3` rozeti); TR bayrağı + dil; avatar + ad + rol.
* **Kahraman bandı**: site fotoğrafı, soldan sağa koyu gradyan, "Günaydın,
  Furkan" + "Beyoğlu Konakları'nda her şey yolunda." + tarih ve hava durumu
  satırı; sağda italik marka cümlesi.
* **KPI şeridi**: 4 kart. Yumuşak tonlu ikon kutusu · etiket · büyük sayı · alt
  satır. 2.–4. kartlarda sağ üstte trend rozeti (`↑%5`).
* **Ana ızgara**: solda 2/3 **Site Maketi** (3B render, blok pinleri,
  `3D Görünüm | Harita Görünümü` segmenti, sağ kenarda yüzen kontrol yığını,
  altta durum efsanesi + arama); sağda 1/3 **Hızlı İşlemler** (2×2 döşeme) ve
  **Duyurular** (ikon + 2 satır + tarih).
* **Alt sıra**: Tahsilat Durumu (halka grafik + tutarlı efsane) · Talepler
  (öncelik hapları) · Son İşlemler.
* **Altbilgi**: telif + Gizlilik/Koşullar/Destek.

### 0.3 Modül başına farklılaşma — referansta GERÇEKTEN var

| düzen tipi | referanstaki ekranlar |
|---|---|
| Küçük resim ızgarası | Kameralar (canlı, `CANLI` rozeti, yoğunluk seçici) |
| Tablo + önizleme paneli | Kamera Kayıtları (sağda video oynatıcı) |
| Liste + harita | NFC Noktaları · Şikayet Haritası |
| Hafta ızgarası | Vardiya Planı (satır=personel, sütun=gün, hücre=çip) |
| Zaman çizelgesi listesi | Acil Durum Çağrıları |
| Anahtar/toggle listesi | Otomasyon · Site Kuralları · KVKK Tercihleri |
| Marka kartı listesi | Banka Entegrasyonu |
| Form + geçmiş | Hesaplar Arası Virman |
| Usta-detay (sol liste/sağ içerik) | Tanımlar · Tesis Ayarları · Site Ayarları · Profil |
| Kapak görselli içerik kartı | Duyurular · Etkinlik Yönetimi |
| Grafik + tablo | Aidat (çubuk) · Finans (çizgi) · Giderler (halka) · Bütçe (yatay bar) |
| Kart ızgarası + alt tablo | Bina Düzenleme (blok kartları + daire tablosu) |
| Adım çubuğu | Kurulum Sihirbazı |
| Yoğun operasyon tablosu | Araç Geçişleri · Devriye · Talepler |

### 0.4 Referansta gördüğüm TUTARSIZLIKLAR

Körü körüne kopyalamak hata olur:

1. **İki farklı kenar çubuğu.** `ui5`/`ui1` düz liste + bölüm etiketleri; `ui3`
   ise üst düzey öğeler + aktif olanın açıldığı katlanır gruplar. (→ soru 1)
2. **Trend rozeti rengi anlama göre değil yöne göre.** `ui5`'te "Açık Talepler
   ↓%20" **kırmızı**; oysa açık talebin azalması iyi haber. Düzelteceğim.
3. **Renk tek başına anlam taşıyor** (kamera durum noktaları, aktif menü hapı,
   geçiş yönü okları). Kuralımız bunu yasaklıyor → ikinci ipucu ekleyeceğim.
4. **Palet erişilebilirlik eşiğini tutmuyor** (§1.6).

---

## 1. MEVCUT DURUM — ÖLÇÜM

### 1.1 Büyüklük

| | sayı |
|---|---|
| `app/(protected)` altındaki sayfa | **79** |
| Korumalı dışı sayfa (giriş, kayıt, hukuki, ölçüm) | 10 |
| Menü öğesi | **84**, 8 grupta |
| Paylaşılan bileşen (`components/*.tsx`) | 45 |
| `components/ui/` bileşeni | 19 |
| Alt klasör bileşen kümesi | 13 klasör (3d, finans, pano, vardiya, harita…) |
| Sözlük anahtarı | **3.149** × 7 dil |
| Web test dosyası | **228** (146 DOM, 82 tarama/birim) |

Menü grubu dağılımı: finans 19 · tanımlar 14 · güvenlik 12 · tesis 12 ·
iletişim 11 · yönetim 10 · platform 5 · özet 1.

İstediğiniz yedi grup mevcut `GrupId` ile neredeyse birebir örtüşüyor —
**yeni bir bilgi mimarisi kurmaya gerek yok.**

### 1.2 Bugünkü tasarım sistemi

`app/tasarim-sistemi.css` — 633 satır, **82 adet `--yz-*` token**: fs 18 · z 9 ·
space 9 · radius 8 · dur 8 · durum renkleri · yüzey · kenarlık · metal · gölge.

**Sistem VAR ve tek katman. İkinci sistem kurmayacağım, bunu genişleteceğim.**

Ama bir şey daha var ve planı belirliyor:

> **İKİ TASARIM DİLİ YAN YANA YAŞIYOR.** P160'ta bilinçli bir geçiş kararı
> verilmiş: eski dil (`globals.css` + `tailwind.config.ts`, mobil Dart
> token'larıyla eşitlenmiş) korunmuş, yeni `--yz-*` dili *yanına* konmuş.
> Dosya başlığı bunu yazıyor ve "geçiş bitince eski tokenlar kaldırılabilir"
> diyor.

Geçişin bugünkü durumu (ölçtüm):

| sayfa grubu | sayı |
|---|---|
| **Yalnız yeni dil** (`components/ui`) | **59 / 79** |
| **Karma** (hem eski hem yeni) | **18 / 79** |
| Yalnız eski dil | **0** |
| Hiçbiri (yönlendirme vb.) | 2 |

Karma 18: `aidatim, akilli-ev, anketler, announcements, assets, bakim,
complaints, dashboard, finans, integrations, panik, patrol-plans, raporlar,
reports/dues, reports/patrols, reports/tasks, tanimlar, tasks`.

Geçiş **%75 bitmiş**. P244 bunu tamamlama fırsatı.

İkilik bileşen düzeyinde de var:

| iş | eski | yeni |
|---|---|---|
| düğme | `btnPrimary` / `btnGhost` (sınıf dizgesi) | `<Dugme>` |
| tablo | `Tablo/Th/Tr/Td`, `TabloKart` | `<VeriTablosu>` |
| kart | `cardCls`, `panelCls`, `Kart` (tasarim.tsx) | `<Kart>` (ui/yuzey) |
| boş durum | `tasarim.tsx BosDurum` | `ui/durumlar BosDurum` |
| sayfa başlığı | `PageHeader` | `SayfaBasligi` |

### 1.3 "Hepsi aynı iskelet" iddiası — ölçüm ne diyor

79 sayfada bileşen kullanımı:

| bileşen | sayfa | oran |
|---|---|---|
| HataDurumu | 63 | 79% |
| Kart | 52 | 65% |
| Modal | 40 | 50% |
| BosDurum | 39 | 49% |
| İskelet (yükleniyor) | 35 | 44% |
| VeriTablosu | 28 | 35% |
| Sekmeler | 10 | 12% |
| eski Tablo | 8 | 10% |
| **KPI** | **3** | **3%** |
| **Grafik** | **3** | **3%** |
| Harita | 1 | 1% |
| Detay paneli / drawer | 1 | 1% |

**Ölçüm, teşhisi kısmen çürütüyor.** Sorun "her sayfada aynı bayat KPI şeridi"
değil — **KPI 79 sayfanın yalnız 3'ünde var.** Grafik 3, harita 1, detay paneli 1.

Ekranlar birbirine benziyor çünkü **çoğu sayfada kart + tablo'dan başka hiçbir
şey yok.** "Boş görünüyor" şikâyetinin ölçülen kaynağı bu: özet yok, bağlam yok,
ikincil panel yok.

Sayfa uzunluğu ortancası 339 satır; en uzunlar `vardiya-plani` 1353, `tasks`
1333, `building-editor` 1238.

**Kısa sayfalar mutlaka zayıf değil** — kontrol ettim: `finans/giderler` 45
satır çünkü gövdesi paylaşılan `HareketSayfasi` kabuğunda (7 finans sayfası
aynı kabuğu kullanıyor); `shifts` 27 satır çünkü bir `redirect`. Bunları "boş
sayfa" diye raporlamak yanlış olurdu.

### 1.4 Kabuk bugün ne yapıyor

* Kenar çubuğu **açık mavi** (`--yz-bg-sidebar: #d8e4f5`) — referans
  **lacivert**. En görünür değişiklik bu.
* Bölümler **varsayılan KAPALI** (P167 §1.2 kararı: 84 öğe açık çizilince menü
  taşıyordu). Referansta hepsi **açık ve düz**. (→ soru 2)
* Küçültme modu (`kelimeGoster`), 35 benzersiz ikon, sayfa eylem yuvası,
  **Ctrl+K komut paleti**, bildirim merkezi, dil seçici, görünüm seçici, ekran
  yardımı — hepsi **zaten var**. Referanstaki üst çubuğun istediği her şey
  mevcut; eksik olan tek şey **site değiştiricinin kenar çubuğu dibinde olması**
  (bugün hesap menüsünde).

### 1.5 Görsel kilitler — asıl risk burada

| kilit | ne ölçüyor | yeniden tasarımda ne olur |
|---|---|---|
| `tasarim-token.test.ts` (21 test) | web token'ları ↔ **mobil `home_tokens.dart`** birebir | **TOPLU KIRILIR** (→ soru 3) |
| ” | "hiçbir sayfa kendi `<table>` iskeletini yazmıyor" | **korunur, işimize yarar** |
| ” | "birincil düğme MAVİ" | korunur (#2563EB mavi) |
| ” | "tanımsız `--yz-*` kullanılamaz" | korunur, yeni token'ları beyan etmeye zorlar |
| `yz-token-kontrast.test.ts` (15 test) | her rengin AA/3.0 eşiği | **her yeni renk yeniden ölçülmeli** |
| `sabit-metin.test.ts` (19) | JSX'te düz dizge yok | sürtünme kaynağı, kural doğru |
| `erisilebilir-etiket.test.ts` (19) | aria-label zorunluluğu | korunur |
| `p243-bos-durum-rehberi.test.ts` | her `BosDurum` bir `aciklama` taşır | korunur, işimize yarar |
| `p239-*.dom.test.ts` (5 dosya) | sözcük bölünmesi, seçenek görünürlüğü | korunur |
| 146 DOM testi | metin/rol ile sorgular | **çoğu hayatta kalır**, düzen değişse de metin durur |

### 1.6 ÖLÇÜLEN ÇATIŞMA: referans palet AA'yı tutmuyor

| renk | beyaz kartta | sayfa zemininde | metin (≥4.5) | grafik (≥3.0) |
|---|---|---|---|---|
| Primary `#2563EB` | 5.17 | 4.76 | **geçer** | geçer |
| Secondary `#667085` | 4.97 | 4.58 | geçer (dar) | geçer |
| Text `#172033` | 16.27 | 14.98 | geçer | geçer |
| Success `#16a34a` | 3.30 | 3.03 | **KALIR** | geçer |
| Danger `#ef4444` | 3.76 | 3.47 | **KALIR** | geçer |
| **Warning `#f59e0b`** | **2.15** | **1.98** | **KALIR** | **KALIR** |
| Border `#e4e7ec` / beyaz | 1.24 | — | — | **kilit ≥1.5 İSTİYOR** |

Ayrıca:
* **Beyaz kart / zemin `#f2f6fa` = 1.086.** P166 kilidi kartın zeminden
  ayrışmasını istiyor; bugünkü değer 1.13. Referans zemin **fazla açık** —
  kademe görünmez olur (P166'da ölçülen kusurun ta kendisi).
* **Aktif menü hapı `#2563EB` / lacivert `#14263a` = 2.97** — arayüz bileşeni
  eşiği 3.0'ın *altında*.

**Sonuç:** referans paletini olduğu gibi almak, bugün geçen dört erişilebilirlik
kilidini kırar. Mevcut çözümümüz (`-ink` metin varyantı + `-edge` grafik
varyantı) **korunmalı**. Palet ham tonda kalır (görsel kimlik bozulmaz), metin
ve anlamlı çizgi koyulaştırılmış varyantı kullanır. Bu, P160'ta zaten kurulmuş
bir mekanizma.

Önerdiğim düzeltmeler:

| token | referans | önerim | neden |
|---|---|---|---|
| zemin | `#f7f9fc` | **`#eef2f7`** | kart/zemin kademesi ≥1.10 kalsın |
| kenarlık | `#e4e7ec` | **`#d7dee7`** | kilit ≥1.5'i tutsun |
| aktif hap | `#2563EB` | `#3b82f6` **+ sol işaret çubuğu** | 3.0 + renk tek başına anlam taşımasın |
| warning metni | — | `-ink` varyantı (bugünkü `#885b1d`) | AA |

---

## 2. TASARIM SİSTEMİ — TEK KAYNAK

**Karar: `app/tasarim-sistemi.css` tek kaynak olarak kalır, genişler. İkinci
sistem kurulmaz. Eski dil (`globals.css` + tailwind renkleri) P244 boyunca
emekliye ayrılır.**

| aile | bugün | P244 |
|---|---|---|
| kenar çubuğu | `#d8e4f5` açık mavi | **lacivert ~`#14263a`** + metin/etiket/aktif token'ları |
| zemin | `#eef1f6` | `#eef2f7` (ince ayar) |
| vurgu | `#5b8def` soluk | **`#2563EB`** canlı |
| success/warning/danger | soluk tonlar | `#16a34a` / `#f59e0b` / `#ef4444` (+ mevcut ink/edge) |
| yüzey dili | **fırçalanmış metal + neumorphism** (`--yz-metal-*`, `--yz-raised`, `--yz-sunken`) | **düz**: ince kenarlık + çok hafif gölge |
| tipografi | mevcut 18 kademeli `--yz-fs-*` | ölçek korunur, değerler referansa çekilir (24/18/16/14/13/12) |
| yazı tipi | mevcut (`yazi-tipi.css`) | **emin değilim** — referans "Inter / Geist" diyor (→ soru 4) |

**Metal/neumorphism yaygınlığı (ölçtüm):** `--yz-metal-*` 29 dosya,
`--yz-raised` 21, `--yz-sunken` 7, `.yz-lift` 10. Bunları token düzeyinde
düzleştirmek (değeri değiştirmek, adı bırakmak) 67 dosyaya tek tek dokunmaktan
çok daha ucuz. **Önerim: token değerlerini düzleştir, adları bir tur daha yaşat,
sonra ayrı bir temizlik turunda sil.**

**Görünüm modu (Standart/Büyük) korunur.** `:root.yz-buyuk` bloğu yalnız
`--yz-fs-*` ve kontrol yüksekliklerini eziyor, renk token'ına dokunmuyor — yeni
palet onunla sorunsuz çalışır. Yeni eklenen her ölçü token'ı büyük modda da
tanımlanmalı; bunu bir kilitle bağlayacağım.

---

## 3. GRUP GRUP PLAN

### A. Özet / Ana sayfa

| | |
|---|---|
| **Ekranlar** | `/dashboard` (1016 satır, karma dil), `/` yönlendirme |
| **Ölçülen sorunlar** | Özelleştirilebilir widget sistemi var ama **kahraman bandı yok**, KPI şeridi referanstaki gibi değil, karma dil |
| **Yeni yön** | `ui5`'in birebir karşılığı: kahraman bandı → 4'lü KPI şeridi → 2/3 Site Maketi + 1/3 (Hızlı İşlemler, Duyurular) → 3'lü alt sıra (Tahsilat halkası, Talepler, Son İşlemler) |
| **Yeniden kullanılacak** | `pano/widget-seridi`, `pano/finans-ozeti`, `pano/takvim`, `3d/*`, `ui/grafik-pasta`, `ui/kpi`, özelleştirme/sürükle mantığı (P184) |
| **Modüle özgü yeni** | `KahramanBandi`, `HizliIslemler`, `TrendRozeti` |
| **Büyüklük** | **Büyük** |
| **Risk** | Widget özelleştirme + gizli bölüm mantığı (P184 §11) bozulabilir; `pano-tint-blok.dom.test.ts` "1 kahraman + 4 ikincil" sert sınırını ölçüyor — **bilinçli güncellenecek** |

### B. Tesis (bloklar, daireler, maket, ortak alanlar)

| | |
|---|---|
| **Ekranlar** | `/building-editor` (1238), `/units`, `/residents`, `/schematic`, `/rezervasyon-yonetimi`, `/tesis-ayarlari` |
| **Ölçülen sorunlar** | `building-editor` en uzun 3. sayfa ve tek parça; blok kartı kavramı yok; `UnitDetail` var ama **detay paneli 79 sayfanın yalnız 1'inde** |
| **Yeni yön** | `ui4`'teki Bina Düzenleme deseni: üstte **blok kartları şeridi** + altta seçili bloğun daire tablosu + sağdan **daire detay çekmecesi**. `/schematic` ve maket `ui5`'teki gibi segment + yüzen kontrol + efsane |
| **Yeniden kullanılacak** | `UnitDetail`, `3d/bina-sahnesi`, `3d/sahne-yukleyici`, `DaireSakinleri`, `dokunma-kapisi` |
| **Modüle özgü yeni** | `BlokKarti`, `DetayCekmecesi` (ürün geneline yayılacak) |
| **Büyüklük** | **Büyük** |
| **Risk** | 3B sahne etkileşimi (→ soru 5); `daire-viz-editor` testleri; `bina-hucre-tip.dom.test.ts` |

### C. Güvenlik

| | |
|---|---|
| **Ekranlar** | `/kameralar` (863), `/kamera-kayitlari`, `/panik`, `/akilli-ev` (790), `/notifications`, `/patrol-plans` (779), `/checkpoints`, `/arac-gecisleri` (69), `/olaylar`, `/ziyaretciler` |
| **Ölçülen sorunlar** | `arac-gecisleri` **69 satır** — referansta 5 KPI + yoğun tablo olan ekran bizde çıplak liste. `/checkpoints` harita yok (harita 79 sayfada 1 kez geçiyor). Kameralar ızgara var (`KameraSeridi`) ama canlı rozeti/yoğunluk seçici yok |
| **Yeni yön** | Referansın en güçlü bölümü, birebir izlenecek: Kameralar=ızgara+CANLI, Kayıtlar=tablo+sağ önizleme, NFC=liste+harita, Devriye=KPI+tablo, Araç=5 KPI+yoğun tablo, Acil Durum=zaman çizelgesi, Akıllı Ev=cihaz ikon sütunlu tablo |
| **Yeniden kullanılacak** | `KameraSeridi`, `KameraOynatici`, `DevriyeGorunumu`, `harita/*`, `panik/*`, `Foto` |
| **Modüle özgü yeni** | `CanliRozet`, `KameraIzgarasi` (yoğunluk seçici), `OlayZamanCizelgesi`, `NoktaHaritasi` |
| **Büyüklük** | **Büyük** |
| **Risk** | Canlı yayın/MediaMTX yolu (P190 §6) — **görsele dokunulur, akışa dokunulmaz**; P129 rol görünürlüğü |

### D. Tesis operasyonu

| | |
|---|---|
| **Ekranlar** | `/bakim`, `/tasks` (1333), `/assets`, `/complaints`, `/rezervasyon-yonetimi`, `/gorevlerim`, `/kargolar` |
| **Ölçülen sorunlar** | `/tasks` en uzun 2. sayfa; şikayet haritası **yok** (referansta harita+panel); `/bakim` P241'de yeni yazıldı, dile en yakın olan bu |
| **Yeni yön** | Görevler: liste/pano/takvim görünüm seçici + filtre çubuğu + detay çekmecesi. Şikayet: harita + sağda öncelik listesi. Rezervasyon: alan kartları + rezervasyon tablosu. Demirbaş: envanter tablosu + detay çekmecesi |
| **Yeniden kullanılacak** | `GorevAdimlari`, `ui/ay-takvimi`, `harita/*`, `Ekler` |
| **Modüle özgü yeni** | `GorevPanosu` (kanban), `SikayetHaritasi`, `AlanKarti` |
| **Büyüklük** | **Orta-büyük** |
| **Risk** | `/tasks` çok sayıda DOM testi taşıyor |

### E. Finans

| | |
|---|---|
| **Ekranlar** | 19 menü öğesi: `/dues`, `/finans` + 11 alt sayfa, `/icra`, `/sayac-okuma`, `/raporlar`, `/reports/*` |
| **Ölçülen sorunlar** | **7 sayfa tek bir `HareketSayfasi` kabuğunu paylaşıyor** → finans modülü tamamen tekdüze. Grafik yalnız 3 sayfada; referansta finansın yarısı grafikli |
| **Yeni yön** | Kabuk KALIR (tekrar yazmak hata olur) ama **yapılandırılabilir** hâle gelir: özet şeridi + isteğe bağlı grafik yuvası + tablo. Aidat=çubuk, Finans=çizgi, Giderler=halka, Bütçe=yatay bar, Borçlular=yaşlandırma, Banka=marka kartları, Otomasyon=kural satırları + anahtar, Virman=form+geçmiş, Raporlar=kategorili rapor kartları |
| **Yeniden kullanılacak** | `finans/hareket-sayfasi`, `finans/hareket-modali`, `finans/satir-tablosu`, `rapor/rapor-grafik`, `ui/grafik*` |
| **Modüle özgü yeni** | `OzetSeridi`, `YaslandirmaTablosu`, `KuralSatiri`, `BankaKarti`, `RaporKarti` |
| **Büyüklük** | **Büyük** (en çok sayfa) |
| **Risk** | Para biçimlendirme, kuruş sınırı (P211), tek defter (P192) — **hiçbirine dokunulmaz**; `p193-finans-eylemleri.dom.test.ts` |

### F. İletişim

| | |
|---|---|
| **Ekranlar** | `/announcements`, `/duyurular`, `/site-kurallari`, `/kurallar`, `/etkinlik-yonetimi`, `/etkinlikler`, `/mesajlar`, `/complaints`, `/taleplerim`, `/anketler`, `/davetler`, `/yonetim-iletisim` |
| **Ölçülen sorunlar** | `/duyurular` 62, `/kurallar` 57, `/etkinlikler` 64, `/yonetim-iletisim` 81 satır — **sakin tarafı ekranların hepsi ince**. Referansta duyuru kapak görselli zengin kart |
| **Yeni yön** | Duyuru/etkinlik = kapak görselli içerik kartı + hedef kitle rozeti + yayın durumu. Kurallar = kategori listesi + kural satırları. Mesajlar = sol oluşturma formu + sağ şablon paneli + gönderim geçmişi sekmesi. Talepler = KPI + öncelik listesi + detay çekmecesi (konuşma geçmişi) |
| **Yeniden kullanılacak** | `ZenginMetin`, `Foto`, `Ekler`, `mesaj/*`, `HukukiBelge` |
| **Modüle özgü yeni** | `IcerikKarti` (kapak görselli), `KonusmaGecmisi` |
| **Büyüklük** | **Orta** |
| **Risk** | Düşük; duyuru kuralları/hedef kitle mantığı (P190 §3) korunur |

### G. Tanımlar / Yönetim

| | |
|---|---|
| **Ekranlar** | `/tanimlar` (1021), `/users` (1007), `/yetki`, `/settings`, `/tesis-ayarlari`, `/profil` (1048), `/kurulum`, `/ice-aktarim`, `/dokumanlar`, `/karar-defteri`, `/transparency`, `/kvkk*`, `/audit`, `/tenants` |
| **Ölçülen sorunlar** | `/tanimlar` ve `/profil` zaten usta-detay'a yakın ama karma dil; `/yetki` matris okunabilirliği **emin değilim, açıp bakmadım** |
| **Yeni yön** | Hepsi **usta-detay**: sol kategori listesi + sağ içerik. `/kurulum` P243 §6'da yeni yazıldı, referansın adım çubuğuna yakın — üstüne adım çubuğu eklenir. `/users` sekmeli tablo + avatar + rol rozeti |
| **Yeniden kullanılacak** | `ReportsTabs`, `ice-aktarim/*`, `profil/*`, `Avatar`, `kurulum-adimlari` |
| **Modüle özgü yeni** | `UstaDetayDuzeni` (tek bileşen, 5 ekran tüketir), `AdimCubugu`, `YetkiMatrisi` |
| **Büyüklük** | **Orta-büyük** |
| **Risk** | Yetki matrisi rol kurallarını yansıtıyor — **görsel değişir, kural değişmez**; `kurulum-*.dom.test.ts` |

---

## 4. AŞAMALANDIRMA ÖNERİM

Sizin sıranız doğru. Bir ekleme ve bir ayrım öneriyorum.

| # | aşama | kapsam | dağıtılabilir mi | kilitler |
|---|---|---|---|---|
| **0** | **Karar turu** | Soruların yanıtı + token çatışmalarının çözümü. Kod yok | — | — |
| **1** | **Tasarım sistemi** | Token değerleri (lacivert, canlı vurgu, düz yüzey), tipografi ölçeği, büyük mod pariteleri | **Evet** — token değişimi tüm sayfalara aynı anda iner, hiçbir sayfa yarım kalmaz | `tasarim-token`, `yz-token-kontrast` güncellenir |
| **2** | **Kabuk** | Kenar çubuğu (lacivert, site değiştirici), üst çubuk, sayfa başlığı deseni, altbilgi | **Evet** | `kabuk-*.dom.test.ts` |
| **3** | **Paylaşılan bileşenler** | Tablo yoğunluğu, filtre çubuğu, kart, modal, **detay çekmecesi (yeni)**, KPI/özet şeridi, boş durum | **Evet** — eski bileşenler çalışmaya devam eder | bileşen testleri |
| **4** | **Karma 18 sayfayı tek dile indir** | Eski dil kalıntılarını temizle | **Evet** | — |
| **5** | **Özet sayfası** | Kahraman + KPI + maket + alt sıra | **Evet** | `pano-*` |
| **6** | **Güvenlik + Tesis** | En görsel modüller | **Evet** | kamera/devriye testleri |
| **7** | **Finans** | Kabuğu yapılandırılabilir yap, grafikleri ekle | **Evet** | finans testleri |
| **8** | **Operasyon + İletişim** | | **Evet** | |
| **9** | **Tanımlar/Yönetim** | Usta-detay | **Evet** | kurulum testleri |
| **10** | **Cila + eski dil emekliliği** | `globals.css` ezmeleri, metal token'ları, artık bileşenler | **Evet** | parite testi emekliye ayrılır |

**Neden 4. aşama ayrı:** karma 18 sayfayı modül turlarına dağıtırsam, her turda
"bu sayfa niye hâlâ iki dil kullanıyor" sorusunu yeniden çözmem gerekir. Tek
seferde temizlemek ucuz.

**Neden 3. aşama 5'ten önce:** özet sayfası detay çekmecesini ve yeni KPI
şeridini tüketecek. Ters sırada aynı bileşeni iki kez yazardım.

**Tur tahmini: 8–11 tur.** Aşama 1–4 birer tur; 5 bir tur; 6 iki tur; 7 iki tur;
8 bir-iki tur; 9 bir tur; 10 bir tur. **Tahmin, taahhüt değil** — 79 sayfanın
içine girince şişebilir.

---

## 5. KİLİTLER: BİLİNÇLİ GÜNCELLEME mi, GERÇEK KUSUR mu

Ayrımı şimdiden koyuyorum, yoksa her kırmızıda aynı tartışma olur.

| kilit | karar | gerekçe |
|---|---|---|
| `tasarim-token` — mobil parite | **BİLİNÇLİ** (→ soru 3) | mobil bu turda kapsam dışı |
| `tasarim-token` — "kendi `<table>`ını yazma" | **DOKUNULMAZ** | kırılırsa gerçek kusur |
| `tasarim-token` — "tanımsız token yok" | **DOKUNULMAZ** | yeni token'ı beyan etmeye zorlar |
| `yz-token-kontrast` — eşikler | **DOKUNULMAZ** | eşik düşürmek erişilebilirliği satmaktır; renk değeri değişir, eşik değişmez |
| `yz-token-kontrast` — kenarlık ≥1.5 | **DOKUNULMAZ** | referans kenarlığı 1.24; kenarlığı koyulaştırırım |
| `yz-token-kontrast` — kart/zemin kademesi | **DOKUNULMAZ** | P166'da ölçülmüş gerçek kusur |
| `pano-tint-blok` — 1 kahraman + 4 ikincil | **BİLİNÇLİ** | yeni özet düzeni farklı |
| `sabit-metin`, `erisilebilir-etiket`, `telefon-kapsam` | **DOKUNULMAZ** | |
| `p243-bos-durum-rehberi` | **DOKUNULMAZ** | yeni boş durumlar da açıklama taşır |
| `p239-*` sözcük bölünmesi | **DOKUNULMAZ** | |
| DOM testlerindeki metin sorguları | **duruma göre** | metin duruyorsa test de durmalı; düşüyorsa önce "metni mi kaldırdım" diye bakarım |

**Kural:** bir kilidi güncellemeden önce **neden güncellediğimi dosyaya
yazacağım** ve güncellenen kilidi **kırarak** hâlâ ayırt ettiğini
doğrulayacağım. Eşik düşürerek geçen hiçbir kilit kabul etmiyorum.

---

## 6. KORUNACAKLAR — dokunulmayacak

İş mantığı · rotalar · veri yapıları · yetki ve izolasyon (P228/P231) · BFF
sözleşme kapısı · 7 dil pariteliği · sabit metin yasağı · erişilebilirlik
eşikleri · görünüm modu (Standart/Büyük) · sözcük bölünmesi yasağı (P239) ·
tek defter (P192) · mobil (bu turda kapsam dışı).

**Dokunma hedefi notu:** siz 48×48 dediniz; kodda bugün **44 px**
(`min-height: 44px`, büyük modda 52). Bunu 48'e çıkarmak ayrı ve gerçek bir
değişiklik — tüm kontrol yükseklikleri kayar. İsterseniz aşama 1'e alırım, ama
**kendiliğinden yapmadım** (→ soru 6).

---

## 7. SORULARIM

1. **Kenar çubuğu hangisi?** `ui5`/`ui1` düz liste + bölüm etiketleri mi,
   `ui3`'teki katlanır gruplar mı? Bugün bizde **katlanır ve varsayılan kapalı**
   (84 öğe açık çizilince menü taşıyor diye — P167'de ölçülmüş). Referanstaki
   düz liste 84 öğeyle çalışmaz; ya öğe sayısını azaltırız ya katlanır kalır.
2. **Bölümler varsayılan açık mı olsun?** (1'in devamı.) Açık olursa menü ~84
   satır olur.
3. **Mobil token pariteliği ne olacak?** Web renkleri değişince
   `tasarim-token.test.ts` kırılır. Üç seçenek:
   **(a)** mobil token'ları da güncelle (kapsam dışı dediniz ama kilit bunu
   istiyor); **(b)** pariteliği *anlamsal* token'larla sınırla (başarı/uyarı/
   tehlike aynı kalsın), *kabuk* token'larını (kenar çubuğu, zemin) parite
   dışına al; **(c)** pariteyi tamamen dondur, mobil geçtiğinde yeniden kur.
   **Önerim (b)** — anlam ortak kalır, kabuk yüzeye özgüdür.
4. **Yazı tipi değişecek mi?** Referans "Inter / Geist" diyor. Bizdekini
   değiştirmeden önce sormak istiyorum; yazı tipi değişimi 7 dilde (Arapça
   dahil) yeniden ölçüm demek.
5. **Site maketi 3B korunacak mı?** Önerim: **evet, etkileşim aynen korunur**,
   çevresi (segment seçici, yüzen kontroller, efsane, arama) referanstaki gibi
   yenilenir. Sahnenin kendisi (`bina-sahnesi`, `site-palet`) yerinde kalır.
6. **Dokunma hedefi 44 → 48 px olsun mu?**
7. **Referansta olup bizde OLMAYAN ekranlar.** Saydıklarım: Şikayet Haritası,
   Gürültü Uyarıları (var ama zayıf), Şeffaflık Panosu (var), Karar Defteri
   (var), Doküman Yönetimi (var), Ziyaretçiler (var).
   **Gerçekten yalnız "Şikayet Haritası" yeni bir ekran gibi duruyor** — gerisi
   bizde var, referansta daha zengin çizilmiş. Şikayet Haritası'nı **yeni ekran
   olarak yapayım mı**, yoksa tasarım yalnız mevcut ekranlara mı uygulansın?
8. **Mobil bu dile ne zaman geçecek?** 3. sorunun cevabı buna bağlı.

---

## 8. EMİN OLMADIKLARIM

* `ui4`/`ui5` adlandırmasının içerikle ters olması — benim okumam.
* `/yetki` matrisinin bugünkü okunabilirliğini **açıp incelemedim**; G
  grubundaki değerlendirmem dosya boyutuna dayanıyor.
* Tur sayısı tahmini (8–11) 79 sayfanın içine girmeden yapıldı.
* Referanstaki bazı ekranların bizdeki tam karşılığını eşleştiremedim (ör.
  "Selfak Panosu" = Şeffaflık Panosu olmalı ama emin değilim).
* Yazı tipi kararı (soru 4) — bugünkü yığını ölçmedim.
