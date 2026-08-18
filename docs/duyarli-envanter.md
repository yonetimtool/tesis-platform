# P169 Aşama 0 — Duyarlılık envanteri

## Ölçüm nasıl yapıldı (ve sınırı)

73 rotayı beş genişlikte gözle taramak 365 ekran demek. Daha önemlisi:
**gözle bakmak kusur *örneğini* bulur, *sınıfını* bulmaz** — oysa brief
açıkça "aynı kusur kaç sayfada tekrarlıyor" diye soruyor.

Bu yüzden ölçüm **kaynak taramasıyla** yapıldı: dar ekranda taşmaya ya da
kullanılamamaya yol açan **yapısal desenler** arandı (kırılma noktası
olmayan çok kolonlu ızgaralar, sabit piksel genişlikler, ham tablolar,
hover'a bağlı işleyişler, 44 px altı dokunma hedefleri, girdi font
boyutu).

**Sınır açıkça yazılıdır:** bu tarama *yapısal* kusurları bulur, *görsel*
kusurları (bir başlığın iki satıra inip kartı bozması gibi) bulmaz.
Onlar Aşama 4'te sayfa geçirilirken görülecek. Tarama kodu
`/tmp` altında tek seferlikti; kalıcı ölçüm bu turda yazılacak
`tests/duyarli-*.test.ts` kilitleri olacak.

---

## Bulgu 1 — GİRDİ FONT BOYUTU: `14px` (iOS'ta yakınlaşma)

**Etki: sitedeki HER form. Tek düzeltme.**

`--yz-fs-body: 14px` ve `components/ui/alan.tsx` içindeki `TEMEL_KUTU`
bunu kullanıyor. iOS Safari, odaklanılan girdinin font boyutu **16 px'in
altındaysa sayfayı otomatik yakınlaştırır** ve geri çıkmaz — kullanıcı
her alana dokunduğunda sayfa zıplar, yatay kaydırma açılır.

Bu tek satırlık bir kusur değil: `Alan`, `Secim`, `CokSatir`,
`AramaAlani` — hepsi aynı token'ı kullanıyor, yani **tek yerden**
düzelir.

## Bulgu 2 — DOKUNMA HEDEFİ: `boy="kucuk"` = 36 px

**Etki: 161 kullanım yeri.**

`components/ui/dugme.tsx`: `kucuk: h-9` (36 px). Brief 44×44 istiyor ve
`orta` zaten 44 px (`h-11`, yorumu da bunu söylüyor). Ama tablolardaki
satır eylemleri, araç çubukları ve modal düğmelerinin çoğu `kucuk`
kullanıyor.

Bu **masaüstünde doğru bir karar** (yoğun tablolarda 44 px satırı
şişirir) — yani çözüm `kucuk`u büyütmek değil, **dokunmatik girdide**
büyütmek.

## Bulgu 3 — DataTable: kaydırma var, KART MODU YOK

`components/ui/veri-tablosu.tsx` bugün:

| Yetenek | Durum |
|---|---|
| Yatay kaydırma | **var** (`overflow-x-auto` + `role=region` + `tabIndex`) |
| Kolon gizleme | **var** (`darEkrandaGizle` → `hidden md:table-cell`) |
| Kart modu | **yok** |
| İlk kolon sabitleme | **yok** |
| Kaydırma göstergesi | **yok** |
| Araç çubuğu sarması | **var** (`flex-wrap`) |

Yani 360 px'te tablo *çalışır* ama **okunmaz**: kullanıcı hangi satırda
olduğunu kaybeder, çünkü kimlik kolonu (daire no / ad) kayıp gider.

**Etkilenen sayfa sayısı: `VeriTablosu` kullanan tüm listeler.**

## Bulgu 4 — Modal: `sm`'de tam ekran değil

`components/ui/modal.tsx`: `fixed inset-0 flex items-center justify-center
p-4` + `max-w-lg`. 360 px'te kutu 328 px olur — **taşmaz**, ama:

- uzun formlarda dikey olarak ekranı aşar,
- klavye açılınca alt eylem çubuğu görünmez olur,
- başlık kaydırmada kaybolur.

## Bulgu 5 — Kırılma noktası olmayan ızgaralar (13 sayfa + 4 bileşen)

| Dosya | `grid-cols-N` | Sabit px |
|---|---|---|
| `assets`, `audit`, `checkpoints`, `dues`, `settings`, `shifts` | 2 | — |
| `building-editor`, `patrol-plans`, `units` | 3 | — |
| `tasks` | **7** (takvim ızgarası) | — |
| `tenants`, `tenants/[id]` | 2 (×2, ×3) | — |
| `integrations` | 2 | 280 |
| `users` | — | 220 |
| `AppShell`, `KameraSeridi`, `widget-seridi` | 2 | — |
| `UnitDetail` | 3, 2, 2 | — |
| `GirisFormu` | — | 520, 420 |
| `veri-tablosu` | — | 180 |

`tasks`'taki `grid-cols-7` bir **ay takvimidir** — yedi sütun haftanın
günleridir ve kırılamaz; çözümü sütun sayısını değiştirmek değil,
**ajanda görünümüne geçmektir** (brief §4 özel durumu da bunu diyor).

## Bulgu 6 — Hover'a bağlı işlevler (3 yer)

| Yer | Ne | Mobilde sonucu |
|---|---|---|
| `building-editor:1160` | Kat kartının altındaki eylem şeridi `group-hover:flex` | **Dokunmayla hiç açılmaz** — işlev tamamen erişilemez |
| `tasarim.tsx:361` | `hover:opacity-90` | Yalnız görsel; işlev kaybı yok |
| `GirisFormu:257` | `hover:scale-[1.02]` | Yalnız görsel; işlev kaybı yok |

**Yalnızca biri gerçek işlev kaybı.** Ayrıca `onMouseEnter/Leave` üç
bileşende altı kez geçiyor — Aşama 5'te tek tek incelenecek.

`title=` ipucu ve 44 px altı `onClick` taraması **sıfır** sonuç verdi;
bu iki sınıf zaten temiz.

## Bulgu 7 — Kabuk (AppShell)

Bugün var olan:
- `<1024 px` çekmece + karartılmış arka plan + animasyon + öğe seçilince
  kapanma **var**
- `≥1024 px` sabit kenar çubuğu, elle daraltma düğmesi **var**

Eksik olan:
- **ESC ile kapanma yok**
- **Odak tuzağı yok** (çekmece açıkken Tab arkadaki sayfaya kaçar)
- **Kaydırma kilidi yok** (çekmece açıkken arka plan kayar)
- Kırılma noktası eşiği `lg:` (1024) — brief `md` (640) sınırını istiyor,
  yani **tablet dikeyde (768) bugün çekmece görünür**; bu aslında brief'in
  istediğiyle uyumlu (`sm/md: çekmece`). Değişmesi gereken şey `lg`de
  **dar mod varsayılanı**.

## Bulgu 8 — Ağır bileşenler

| Bileşen | Durum |
|---|---|
| Grafik (`ui/grafik.tsx`) | `next/dynamic` ile **tembel** yükleniyor (220 px yer tutucu) — iyi |
| 3D sahne (`schematic`, `building-editor`) | Aşama 6'da ölçülecek |
| Zengin metin editörü | P168'de eklendi, statik import |
| Harita (şikayet haritası) | Aşama 6'da ölçülecek |

---

## Kusur sınıfı → düzeltme sayısı

Brief'in asıl sorusu buydu:

| Kusur sınıfı | Kaç yerde görünür | Kaç düzeltme |
|---|---|---|
| Girdi font boyutu (iOS yakınlaşma) | Her form | **1** (token) |
| Dokunma hedefi 36 px | 161 kullanım | **1** (bileşen) |
| DataTable dar ekranda okunmaz | Tüm listeler | **1** (bileşen) |
| Modal `sm`'de tam ekran değil | Tüm modallar | **1** (bileşen) |
| Kırılma noktasız ızgara | 13 sayfa + 4 bileşen | **17** (ama çoğu tek satır) |
| Hover'a bağlı işlev | 1 gerçek | **1** |
| Çekmece: ESC/odak/kaydırma | Kabuk | **1** |

**Yani ~23 düzeltme, 73 sayfayı kapsıyor.** Dördü (font, dokunma hedefi,
DataTable, Modal) tek başına sayfaların çoğunu düzeltiyor — brief'in
"önce altyapı, sonra ekranlar" sırası bu ölçümle doğrulanıyor.

---

## Sayfa × genişlik tablosu

Aşağıdaki tablo **yapısal** ölçümden türetilmiştir. `KART` sütunu, Aşama 3'te
o sayfanın DataTable'ının hangi modu kullanacağına dair ilk öneriyi taşır
(gerekçeler Aşama 3 raporunda).

| Sayfa | 360/390/430 | 768 | 1024 | Ana sorun |
|---|---|---|---|---|
| `/dashboard` | ⚠ | ⚠ | ✓ | 7 widget `grid-cols-2`, takvim ay ızgarası, 3D sahne |
| `/units` | ⚠ | ⚠ | ✓ | `grid-cols-3` filtre; tablo kimlik kolonu kayıyor → **kart** |
| `/users` | ⚠ | ✓ | ✓ | `w-[220px]` sabit; tablo → **kart** |
| `/tasks` | ⚠ | ⚠ | ✓ | `grid-cols-7` takvim → **ajanda** |
| `/notifications`, `/shifts`, `/checkpoints`, `/patrol-plans` | ⚠ | ⚠ | ✓ | `grid-cols-2/3` filtre satırları |
| `/kameralar` | ⚠ | ✓ | ✓ | `KameraSeridi` `grid-cols-2` |
| `/finans/*` (8 sayfa) | ⚠ | ⚠ | ✓ | Çok kolonlu para tabloları → **kaydırma** |
| `/raporlar` | ⚠ | ✓ | ✓ | Modal 10+ alan, `sm`'de tam ekran olmalı |
| `/mesajlar` | ⚠ | ✓ | ✓ | Sekmeler + zengin editör araç çubuğu taşması |
| `/karar-defteri`, `/dokumanlar`, `/kvkk-metinler` | ⚠ | ✓ | ✓ | Modal + tablo |
| `/tanimlar` | ⚠ | ⚠ | ✓ | 14 sekmeli defter; sekme şeridi taşıyor |
| `/building-editor` | ✗ | ⚠ | ✓ | **hover'a bağlı eylemler**, 3D jestler, `grid-cols-3` |
| `/schematic` | ⚠ | ⚠ | ✓ | 3D sahne, dokunmatik jest |
| `/profil` | ⚠ | ✓ | ✓ | İç sol menü `sm`'de üstte yatay olmalı |
| `/kurulum` | ⚠ | ✓ | ✓ | Adımlar `sm`'de dikey akmalı |
| `/tenants`, `/tenants/[id]` | ⚠ | ⚠ | ✓ | `grid-cols-2` ×5 |
| `/login`, `/kayit` | ⚠ | ✓ | ✓ | `w-[520px]`, `w-[420px]` sabit |
| Kalan liste sayfaları | ⚠ | ✓ | ✓ | DataTable ortak kusuru |

`✓` yapısal sorun bulunmadı · `⚠` düzeltme gerekiyor · `✗` işlev
erişilemez

**Not:** `1024` sütununun neredeyse tamamı `✓` — uygulama zaten
masaüstü-öncelikli ve `lg` üstü çalışıyor. İş, `sm` ve `md`'de.
