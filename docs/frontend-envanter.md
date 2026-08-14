# P160 / Aşama 0 — admin-web frontend envanteri

> Bu belge **Aşama 0 çıktısıdır** ve brief'in kuralı gereği sonraki her
> aşamanın girdisidir. Ölçümler koddan üretildi (elle sayılmadı).
> Tarih: 2026-08-14 · Kapsam: `admin-web/` (KİLİTLİ KURAL 1).

---

## 0. YÖNETİCİ ÖZETİ — üç şey baştan bilinmeli

1. **Uygulama sanıldığından büyük:** 57 sayfa (52'si korumalı), 108 BFF
   rotası, korumalı sayfalarda **14.680 satır**. Aşama 6 "modüllerin
   taşınması" pratikte ~50 ekranın yeniden yazımıdır.
2. **Brief'in varsaydığı kütüphanelerin hiçbiri kurulu değil:** grafik
   (Recharts) yok, harita (Leaflet/MapLibre) yok, 3D (Three/R3F/Drei)
   yok, bileşen kütüphanesi yok. Bunlar eklenecekse **yeni bağımlılık**
   kararıdır — brief "mevcutta ne varsa onu koru" diyor ama koruyacak bir
   şey yok.
3. **Aşama 1 ile KİLİTLİ KURAL 6 çelişiyor** (ayrıntı §6). Token
   katmanını değiştirmek, web'i mobil tasarım sistemine kilitleyen
   `tasarim-token.test.ts`'i kırar; o testi yeşil tutmak ise yeni paleti
   imkânsız kılar. **Karar gerekiyor.**

---

## 1. STACK

| Konu | Durum |
|---|---|
| Next.js | **14.2.35**, **App Router** (`app/`), `runtime: nodejs` + `force-dynamic` BFF rotaları |
| React | 18.3.1 |
| CSS | **Tailwind 3.4.6** + `app/globals.css`. `darkMode: "class"` |
| Bileşen kütüphanesi | **YOK** — hepsi el yazımı (`components/`, 28 dosya) |
| Durum yönetimi | **SWR 2.2.5** (52/52 korumalı sayfa `useSWR` kullanıyor). Redux/Zustand yok |
| Animasyon | **framer-motion 12.42** (kurulu, sınırlı kullanım) |
| Video | **hls.js 1.5** (kamera oynatıcı) |
| Grafik | **YOK** |
| Harita | **YOK** (`SiteHarita.tsx` el yazımı SVG şematik) |
| 3D | **YOK** |
| Test | vitest 4.1 + Testing Library + jsdom + axe-core + playwright. **95 test dosyası** |

**Sonuç:** çatı sağlam ve modern; eksik olan *görsel dil* ve *ortak
bileşen derinliği*, çatı değil.

---

## 2. ROTALAR, ROLLER, UÇLAR

### 2a. Rol gerçeği — brief'in listesiyle uyuşmuyor

`lib/yuzey.ts::ROTA_ROLLERI` ölçümü (45 girdi):

| Rol | Erişebildiği web rotası |
|---|---|
| `admin` | **35** |
| `yonetici` | **33** |
| `denetci` | **5** |
| `security` · `tesis_gorevlisi` · `resident` · `guvenlik_amiri` | **0** |

KİLİTLİ KURAL 4 altı rol sayıyor; gerçekte **web paneli üç role hizmet
ediyor**, kalan dördü **mobil yüzeye ait**. Bu bir kusur değil, kayıtlı
bir tasarım kararı (`docs/platform-tesis-ayrimi.md`; iki yüzey: `app.*`
yönetici/denetçi, `panel.*` yalnız admin).

**Aşama 6'ya etkisi:** "her rol için ayrı QA turu" pratikte **üç** tur.
Kalan üç rol için korunacak bir ekran yok — kural boş yere sağlanmış olur.

### 2b. Kapısı `ROTA_ROLLERI`nde olmayan 7 sayfa

`/audit` · `/integrations` · `/settings` · `/support` · `/tenants` ·
`/tenants/[id]` · `/yetki` — bunlar **panel (platform admin) yüzeyi** ve
kapıları `yuzey.ts`teki `Yuzey` ayrımıyla çözülüyor. Taşımada bu ayrım
korunmalı; `ROTA_ROLLERI`ye eklemek onları tesis yüzeyine sızdırırdı.

### 2c. Rota × rol × uç tablosu

| Rota | Roller | Menü grubu | API uçları |
|---|---|---|---|
| `/aidatim` | _(panel yüzeyi / kapı ayrı)_ | finans | `/api/me/dues` |
| `/anketler` | admin·yonetici | iletisim | `/api/panel/anketler`, `/api/panel/anketler/${id}` |
| `/announcements` | admin·yonetici | iletisim | `/api/announcements`, `/api/announcements/${a.id}`, `/api/announcements/${editing`, `/api/uploads/presign` |
| `/arac-gecisleri` | admin | guvenlik | `/api/vehicle-passes` |
| `/assets` | admin·yonetici | tesis | `/api/assets`, `/api/assets/${a.id}`, `/api/assets/${detail.id}/history`, `/api/assets/${editing` _(+1)_ |
| `/audit` | _(panel yüzeyi / kapı ayrı)_ | yonetim | `/api/audit` |
| `/building-editor` | admin·yonetici | tanimlar | `/api/blocks`, `/api/blocks/${b.id}${cascade`, `/api/blocks/${block`, `/api/units` _(+3)_ |
| `/checkpoints` | admin·yonetici | guvenlik | `/api/checkpoints`, `/api/checkpoints/${c.id}`, `/api/checkpoints/${editing` |
| `/complaints` | admin·yonetici | iletisim | `/api/complaints`, `/api/complaints/${c.id}/decline`, `/api/complaints/${c.id}/resolve` |
| `/dashboard` | admin·yonetici | guvenlik | `/api/cameras`, `/api/dashboard/live`, `/api/tenant/settings` |
| `/davetler` | admin·yonetici | iletisim | `/api/davet`, `/api/davet/${satir.user_id}/yeniden` |
| `/dis-hizmetler` | admin·yonetici | tesis | `/api/external-services` |
| `/dues` | admin·yonetici | finans | `/api/dues/assessments`, `/api/dues/payments` |
| `/duyurular` | _(panel yüzeyi / kapı ayrı)_ | iletisim | `/api/announcements` |
| `/etkinlikler` | _(panel yüzeyi / kapı ayrı)_ | tesis | `/api/events` |
| `/finans` | admin·yonetici | finans | `/api/panel/finans-hareketler`, `/api/panel/finans-ozet`, `/api/panel/kasa-bakiyeleri` |
| `/gorevlerim` | _(panel yüzeyi / kapı ayrı)_ | tesis | `/api/tasks`, `/api/tasks/${g.id}/completions` |
| `/ice-aktarim` | admin·yonetici | tanimlar | `/api/panel/ice-aktarim`, `/api/panel/ice-aktarim-${tur`, `/api/panel/ice-aktarim-turler`, `/api/panel/ice-aktarim/${id}/geri-al` |
| `/icra` | admin·yonetici·denetci | icra | `/api/me`, `/api/panel/icra-dosyalari`, `/api/panel/icra-dosyalari/${d.id}` |
| `/integrations` | _(panel yüzeyi / kapı ayrı)_ | platform | `/api/integrations`, `/api/integrations/${editing`, `/api/integrations/${it.id}`, `/api/integrations/${it.id}/trigger` _(+1)_ |
| `/kameralar` | admin·yonetici | guvenlik | `/api/cameras`, `/api/cameras/${duzenlenen}`, `/api/cameras/${k.id}` |
| `/kargolar` | _(panel yüzeyi / kapı ayrı)_ | guvenlik | `/api/kargo` |
| `/kurallar` | _(panel yüzeyi / kapı ayrı)_ | tesis | `/api/site-rules` |
| `/kurulum` | admin·yonetici | tanimlar | `/api/panel/kurulum` |
| `/kvkk` | admin·yonetici·denetci | yonetim | `/api/me/pazarlama` |
| `/mesajlar` | admin·yonetici | iletisim | `/api/panel/mesaj-gecmis`, `/api/panel/mesaj-onizleme`, `/api/panel/mesaj-sablonlari`, `/api/panel/mesaj-sablonlari/${id}` |
| `/notifications` | admin·yonetici | guvenlik | `/api/notifications`, `/api/notifications/${id}` |
| `/olaylar` | admin | guvenlik | `/api/violations` |
| `/patrol-plans` | admin·yonetici | guvenlik | `/api/checkpoints`, `/api/patrol-plans`, `/api/patrol-plans/${assign`, `/api/patrol-plans/${editing` _(+3)_ |
| `/profil` | admin·yonetici·denetci | yonetim | `/api/me`, `/api/me/contact` |
| `/raporlar` | admin·yonetici·denetci | finans | `/api/panel/rapor-katalog`, `/api/panel/rapor/${kod}` |
| `/reports/dues` | admin·yonetici | finans | `/api/dues/assessments`, `/api/dues/payments`, `/api/units` |
| `/reports/patrols` | admin·yonetici | — | `/api/patrol-plans`, `/api/patrol-windows` |
| `/reports/tasks` | admin·yonetici | — | `/api/task-categories`, `/api/task-completions`, `/api/users` |
| `/rezervasyonlarim` | _(panel yüzeyi / kapı ayrı)_ | tesis | `/api/common-areas`, `/api/reservations`, `/api/reservations/${id}/cancel` |
| `/sayac-okuma` | admin·yonetici | finans | `/api/borclandirma/sayac`, `/api/tanimlar/gelir-gider-tanimlari`, `/api/tanimlar/sayaclar-ana`, `/api/tanimlar/sayaclar-bolum` |
| `/schematic` | admin·yonetici | tesis | `/api/building-map`, `/api/unit-complaints` |
| `/settings` | _(panel yüzeyi / kapı ayrı)_ | platform | `/api/tenant/settings` |
| `/shifts` | admin·yonetici | guvenlik | `/api/shifts`, `/api/shifts/${editing`, `/api/shifts/${s.id}` |
| `/support` | _(panel yüzeyi / kapı ayrı)_ | iletisim | `/api/support`, `/api/support/${secili.id}`, `/api/uploads` |
| `/taleplerim` | _(panel yüzeyi / kapı ayrı)_ | iletisim | `/api/complaints` |
| `/tanimlar` | admin·yonetici | tanimlar | `/api/muhasebe-ayarlari`, `/api/tanimlar/${defter.kaynak}`, `/api/tanimlar/${defter.kaynak}/${`, `/api/tanimlar/sayaclar-ana` _(+2)_ |
| `/tasks` | admin·yonetici | tesis | `/api/task-categories`, `/api/tasks`, `/api/tasks/${detail.id}/completions`, `/api/tasks/${editing` _(+2)_ |
| `/tenants` | _(panel yüzeyi / kapı ayrı)_ | platform | `/api/tenants`, `/api/tenants/${tesis.id}` |
| `/tenants/[id]` | _(panel yüzeyi / kapı ayrı)_ | — | `/api/tenants/${id}`, `/api/tenants/${id}/yonetici`, `/api/tenants/${id}/yonetici/reset-credential`, `/api/tenants/${id}/yoneticiler` _(+1)_ |
| `/transparency` | admin·yonetici·denetci | yonetim | `/api/transparency`, `/api/transparency/${ay}` |
| `/units` | admin·yonetici | tesis | `/api/blocks`, `/api/tanimlar/unit-tipleri`, `/api/units`, `/api/units/${editing` _(+4)_ |
| `/users` | admin·yonetici | yonetim | `/api/users`, `/api/users/${editing`, `/api/users/${u.id}`, `/api/users/acilabilir-roller` |
| `/yetki` | _(panel yüzeyi / kapı ayrı)_ | yonetim | `/api/panel/yetki-matrisi` |
| `/yonetim-iletisim` | _(panel yüzeyi / kapı ayrı)_ | iletisim | `/api/yonetici-iletisim` |
| `/yonetisim` | admin·yonetici | yonetim | `/api/panel/dokumanlar`, `/api/panel/dokumanlar/${id}`, `/api/panel/karar-defteri`, `/api/panel/karar-pdf/${k.id}` _(+4)_ |
| `/ziyaretciler` | _(panel yüzeyi / kapı ayrı)_ | guvenlik | `/api/visitors`, `/api/visitors/${id}/checkout` |

---

## 3. MENÜ YAPISI (korunacak)

`lib/menu.ts` — gruplar tek kaynakta ve **rol kapısı burada değil**
(`yuzey.ts`ten geliyor). Brief'in istediği gruplama **zaten mevcut**:

`guvenlik` · `tesis` · `finans` · `finansHareket` · `icra` · `iletisim` ·
`tanimlar` · `yonetim` · `platform`

Kilitli bir ölçü var: **menü ≤ 12 satır** (900px'te kaydırmasız ~10
satır hedefi, `menu` testinde kilitli). Yeni sidebar bu ölçüyü bozmamalı
— brief'in "katlanabilir grup" isteği bununla uyumlu.

**Aşama 2 için sonuç:** menü verisi yeniden yazılmayacak, yalnız *çizimi*
değişecek. `menu.ts` + `yuzey.ts` dokunulmadan kalırsa KİLİTLİ KURAL 2
ve 4 yapısal olarak garanti altına alınır.

---

## 4. TASARIM TOKENLARI — bugünkü hâli

**Mimari:** tokenlar **CSS değişkeni değil**. İki katman:

1. `tailwind.config.ts` → `theme.extend.colors` (**açık tema** değerleri):
   `primary`, `accent.{blue,green,orange,purple,red}`,
   `vurguInk.*` (metin için koyulaştırılmış varyant),
   `yuzey.{bg,card,divider,placeholder}`, `metin.{heading,body,muted}`,
   `ink`, marka `navy/teal`.
2. `app/globals.css` → **koyu tema, Tailwind yardımcı sınıflarını yeniden
   eşleyerek** (`.dark .bg-white { background-color: #0f172a; }` …).
   `:root` altında yalnızca **3 CSS değişkeni** var (`--grad-brand` vb.).

### Ne VAR
renk paleti (açık+koyu), vurgu semantiği (yeşil=olumlu/kırmızı=ihlal),
odak halkası (`:focus-visible`, WCAG 2.4.11), `prefers-reduced-motion`
kancası, kart radius/gölge ölçüleri.

### Ne YOK (brief'in Aşama 1'de istediği)
- **Tek token katmanı yok** — renk Tailwind'de, koyu tema CSS'te sınıf
  ezmesiyle; boşluk/z-index/kırılma noktası/animasyon süresi **token
  değil**, sayfa sayfa serpiştirilmiş.
- **Kabartma (`--raised`/`--sunken`) yok** — metalik dil tamamen yeni.
- `--border-shine` karşılığı yok.
- Gradient token yok (marka gradyanı dışında).

### Mimari değerlendirme
Sınıf-ezmesiyle koyu tema **yeni dil için elverişsiz**: metalik yüzey
gölge + kenarlık gradyanı ister, bunlar `bg-white`'ı ezerek elde edilemez.
Brief'in istediği **CSS değişkeni tabanı doğru karar** — ama bu, koyu
tema mekanizmasının komple değişmesi demek (~160 satır `globals.css`
ezmesi + 110+ kullanım).

---

## 5. ORTAK BİLEŞEN KATMANI — bugünkü kapsama

| Bileşen | Dosya | Kaç sayfada |
|---|---|---|
| EmptyState | `EmptyState.tsx` | **42** |
| Tablo | `tablo.tsx` (199 s.) | **22** |
| Liste | `Liste.tsx` (308 s.) | **16** |
| Modal | `Modal.tsx` (217 s.) | **3** |
| tasarim.tsx (kart/blok) | 455 s. | **2** |
| Toast · Foto · Ekler · KameraOynatici · SiteHarita · UnitDetail | — | nokta atışı |

**İyi haber:** tekrar sanılandan az — tablo/boş durum zaten paylaşılıyor.
Sayfa başına ayrı `<table>` yazan **1** sayfa var, elle overlay yazan
**1** sayfa.

**Gerçek boşluklar:**
- **Modal yalnız 3 sayfada.** Kalan oluşturma/düzenleme akışları *sayfa
  üstünde alan açma* deseniyle çalışıyor — brief bunu kaldırmak istiyor,
  yani **~20 ekranda form deseni değişecek**.
- **Skeleton hiçbir sayfada yok (0/52).** Yükleme durumu ya boş ekran ya
  metin. Brief her sayfada skeleton istiyor.
- **Hiç yok:** Drawer · Tooltip · Tabs (yalnız `ReportsTabs` nokta
  çözümü) · sayfa-başına-kayıt seçimli Pagination · DatePicker ·
  ChartCard · KPI · ConfirmDialog · 3DViewer · MapViewer · Skeleton.
- `tablo.tsx` bir *görsel* tablo; sıralama/kolon görünürlüğü/satır
  seçimi/toplu işlem **yok**. Brief'in DataTable'ı bunun üstüne yazılacak
  yeni bir bileşen.

---

## 6. ⛔ ÇÖZÜLMESİ GEREKEN ÇELİŞKİ (Aşama 1 buna bağlı)

`admin-web/tests/tasarim-token.test.ts` şunu **kilitliyor**:

> web'in `tailwind.config.ts` + `globals.css` renk/ölçü değerleri,
> **`mobile/lib/src/core/theme/home_tokens.dart`** ile birebir aynı olmalı.

Testin gerekçesi dosyada yazılı: "tasarım sisteminin kaynağı mobildir,
web onu KOPYALAR; kopya, kopyalandığı gün doğru olup ertesi gün sessizce
ayrışan şeydir."

Brief'in dört maddesi aynı anda sağlanamıyor:

| # | Madde | Sonuç |
|---|---|---|
| Aşama 1 | "Eski token'ları kaldır, iki dil bir arada bırakma" | tokenlar değişmeli |
| KİLİTLİ 1 | "mobil uygulamaya DOKUNULMAYACAK" | mobil sabit |
| KİLİTLİ 6 | "Mevcut testler yeşil kalacak" | parite testi yeşil kalmalı |
| — | parite testi web==mobil diyor | **çelişki** |

### Seçenekler

- **A — Parite testini emekliye ayır (önerim).** Test bir *ürün kararını*
  (web mobili yansıtır) koruyor; bu brief o kararı **açıkça geri
  alıyor**. Terk edilmiş bir kararı bekçilik eden kilit, kaldırılması
  gereken kilittir. Bedeli dürüstçe: **web ve mobil kalıcı olarak görsel
  ayrışır.** Testi silmek yerine *kapsamını daraltmayı* öneririm —
  yalnız **anlam** paritesi kalsın (yeşil=olumlu, kırmızı=ihlal), *ton*
  paritesi kalksın.
- **B — Mobili de yeni dile taşı.** Tutarlılık en iyi olur ama KİLİTLİ
  KURAL 1'i ihlal eder ve bu turun kapsamını ikiye katlar.
- **C — İki dili yan yana tut.** Aşama 1 bunu açıkça yasaklıyor
  ("iki dil bir arada bırakma"); ayrıca ölçülen kusur zaten buydu.

**Kod yazmadan önce A/B/C kararınızı istiyorum** — brief'in (c) durdurma
koşulu ("brief kendi içinde çelişiyorsa") tam olarak bu durum. Yanlış
seçim, ya kırmızı bir test takımı ya da geri alınması pahalı bir mobil
turu demek.

---

## 7. BAĞIMLILIK KARARI (Aşama 5/6 buna bağlı)

Brief 3D (R3F+Three+Drei), harita (Leaflet/MapLibre) ve grafik (Recharts)
istiyor; **üçü de kurulu değil**. Kaba maliyet (gzip, ana pakete
girmezse):

| Paket | Yaklaşık | Not |
|---|---|---|
| three + @react-three/fiber + drei | ~600–900 kB | **tembel yüklenmeli**, ana pakete asla girmemeli |
| leaflet + react-leaflet | ~50 kB | OSM karo; çevrimdışı/kurumsal ağda karo sunucusu kararı gerekir |
| recharts | ~110 kB | |

**Kararım (Aşama 5 gerekçesiyle uyumlu):** 3D bu turda **yalnız iki
sahne** ve `next/dynamic` ile `ssr:false` tembel yükleme; harita ve
grafik gerçek ihtiyaç anında (Şikayet Haritası / Raporlar) eklenir.
Ölçüm brief'in istediği gibi 3D öncesi/sonrası raporlanacak.

---

## 8. AŞAMA 6 İÇİN GERÇEKÇİ İŞ BÜYÜKLÜĞÜ

52 korumalı sayfa · 14.680 satır · ortalama **282 satır/sayfa**. Her
sayfada yapılacaklar: yeni bileşenlere geçiş + modal deseni + skeleton +
boş/hata durumu. Bu, tek turda bitecek bir iş **değil**; brief'in
öncelik sırası (1→6) doğru ve turlara bölünmeli.

**Önerilen bölünme:** Aşama 1–3 (token + kabuk + bileşen katmanı) tek
tur; Aşama 4–5 (dashboard + 3D) ikinci tur; Aşama 6 öncelik gruplarına
göre üç tur; Aşama 7–10 kapanış turu.

---

## 9. PAKET BOYUTU TEMELİ (Aşama 9 ölçümünün "önce"si)

`npm run build` · 2026-08-14 · **3D/harita/grafik eklenmeden önce**:

```
First Load JS shared by all        87.5 kB
  chunks/2117-…                    31.7 kB
  chunks/fd9d1056-…                53.6 kB
  diğer paylaşılan                  2.15 kB
Middleware                         28 kB
```

En ağır sayfalar: `/units` 158 kB · `/tasks` 155 kB · `/tenants` 152 kB ·
`/users` 152 kB. Aşama 9'da 3D **sonrası** aynı tablo alınıp
karşılaştırılacak; kural: **paylaşılan paket 87.5 kB'ı aşmayacak**
(3D `next/dynamic` + `ssr:false` ile yalnız kendi rotasına inecek).

---

## 10. AŞAMA 1 — TESLİM EDİLEN (2026-08-14)

- `app/tasarim-sistemi.css` — tek token katmanı (`--yz-*`): renk (iki
  tema), tipografi, boşluk, radius, gölge/kabartma, kenarlık, gradyan,
  animasyon süresi, z-index; kırılma noktaları belgelenmiş.
- `app/layout.tsx` — katman + **Inter** (`next/font`, self-host) bağlandı.
- `tests/yz-token-kontrast.test.ts` — 15 test, **iki tema için ayrı**
  WCAG doğrulaması + eski dille çakışmama kilidi.

**Ölçülen ve düzeltilen:** brief'in verdiği hex'lerin **beşi** WCAG AA'yı
tutmuyordu (ayrıntı ve yeni değerler CSS'te satır satır yazılı). Ton ve
doygunluk korunarak yalnız açıklık kaydırıldı.

**Durum renkleri için üç varyant** (depodaki `vurguInk` deseninin
devamı): ham ton = dolgu/dekor · `-ink` = metin (4.5) · `-edge` = anlam
taşıyan grafik (3.0). Ham tonu 3.0'a zorlamak brief'in paletini görünür
biçimde bozardı (`warning` kahverengileşiyordu).
