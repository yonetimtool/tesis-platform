# P169 — admin-web duyarlılık turu (rapor)

> Kapsam: **tarayıcıdan girilen panel**. Flutter uygulamasına dokunulmadı.
> Kırmızı çizgi: **`xl` (≥1440) görünümü bu turdan önceki hâliyle aynı.**

---

## 0. Ölçüm ve yöntem

Envanter `docs/duyarli-envanter.md`de. Yöntem statik kaynak taramasıydı ve
sınırı orada da yazılı: **yapısal** kusuru bulur, **görsel** kusuru bulmaz.
Turun getirisi buradan geldi — kusurları tek tek değil **sınıf sınıf**
düzeltmek: dört düzeltme 73 sayfanın çoğunu kapsadı.

Kırılma noktaları tek kaynakta: `lib/kirilma-noktasi.ts`
(`sm <640 · md 640–1023 · lg 1024–1439 · xl ≥1440`).
Tailwind'de yalnız `xl` değişti (1280 → 1440); `sm` ve `lg` zaten
brief'in istediği sayılardı. **İkinci bir kırılma sözlüğü açılmadı** —
kod tabanında 84 `sm:`, 36 `lg:`, 10 `md:` kullanımı vardı ve paralel bir
dil, aynı ekranda iki sistemin yan yana yaşaması demekti.

---

## 1. `VeriTablosu` — sayfa başına kip ve gerekçesi

Dar ekranda iki kip var. Kip kararı **sayfanın**; `kartRolu` işlenmemiş
her sayfa otomatik olarak kaydırma kipinde **kalır**, yani hiçbir sayfa
bu değişiklikten bozulmadı.

**KART** — kimlik taşıyan varlık listeleri. 360 px'te tablo çalışıyordu
ama okunmuyordu: kimlik kolonu (daire no / ad) kayıp gidiyor, kullanıcı
hangi satırda olduğunu kaybediyordu.

| Sayfa | Rol sayısı | Başlık kolonu |
|---|---|---|
| `/mesajlar` (iki tablo) | 8 | hedef · şablon adı |
| `/users` | 5 | ad |
| `/units` | 5 | daire no |
| `/tasks` | 5 | görev adı |
| `/support` | 5 | konu |
| `/raporlar` | 5 | rapor adı |
| `/patrol-plans` | 5 | plan adı |
| `/icra` | 5 | dosya no |
| `/gurultu-uyarilari` | 5 | daire |
| `/dokumanlar` | 5 | doküman adı |
| `/tenants` | 4 | tesis adı |
| `/shifts` | 4 | vardiya |
| `/kvkk-metinler` | 4 | başlık |
| `/karar-defteri` | 4 | karar no |
| `/davetler` | 4 | davetli |
| `/checkpoints` | 4 | nokta adı |
| `/assets` | 4 | varlık adı |

**KAYDIRMA** — yan yana okunması gereken **seriler**. Bir para defterini
karta bölmek, ayın hareketlerini karşılaştırma imkânını yok ederdi.

`/audit` · `/dues` · `/finans` · `/finans/borclandirmalar` ·
`components/finans/hareket-sayfasi` · `/reports/dues` · `/reports/patrols` ·
`/reports/tasks` · `/yetki` (rol matrisi — satır/kolon ilişkisi *verinin
kendisi*).

`/notifications` hiçbirine girmiyor ve bu bilinçli: bildirim bir
**cümledir**, sütuna bölünmez; sayfa zaten kart listesi.

**Kart kipi bir özettir, bir kırpma değil.** Rolsüz kolonlar silinmez,
"Detay"da katlanır; seçim / sıralama / sayfalama / toplu işlem çalışmaya
devam eder. Tablo semantiği bırakılıyor (`<table>` içinde hücreleri
`display:block` yapmak satır/kolon ilişkisini ekran okuyucudan **gizler** —
göze düzelen şey kulağa bozulur); liste anlamı `<ul>/<li>` ile kuruluyor.

Kaydırma kipinde sağ kenara **gradyan göstergesi** eklendi: göstergesiz bir
tabloda kullanıcı sağa kaydırılabildiğini bilmez ve "veri eksik" sanır.
Aynı gösterge + `role="region"` + `tabIndex` ortak `TabloKart` kabına da
eklendi — orada **klavyeyle kaydırma hiç yoktu** (WCAG 2.1.1).

---

## 2. Hover'a bağlı işlevler — tam liste ve akıbeti

Tarama sonucu **6 kullanım, 3 dosya**:

| Yer | Ne yapıyordu | Karar |
|---|---|---|
| `building-editor` daire şeridi | `group-hover:flex` — **düzenle ve sil telefondan hiç ulaşılamıyordu** | `coarse:flex` eklendi. Ekran çalışır görünüyor, iki işlev sessizce erişilemez duruyordu. Farede davranış değişmedi. |
| `ui/sekmeler.tsx` → `Ipucu` | yalnız hover + odak; odaklanamayan bir simgeye asılıysa **dokunmatikte hiç görünmüyordu** | `onClick` ile açılır hâle geldi. Farede zaten açık olduğu için davranış aynı. |
| `ui/dugme.tsx` (2 kullanım) | `boxShadow` yükseltme | **Salt görsel** — işlev kaybı yok. |
| `ui/komut-paleti.tsx` (2 kullanım) | fareyle üzerine gelinen satırı seçili yapar | Satırın kendi `onClick`'i var; **işlev kaybı yok.** |

Ayrıca `title=` ipucuna bağlı işlev taraması **sıfır** sonuç verdi.

**Sürükle-bırak yüzeyleri ölçüldü, üçü de yedekli çıktı:**

* **Görev panosu (kanban):** HTML5 sürükleme dokunmatikte hiç çalışmaz —
  ama her kartta kategoriyi değiştiren bir **seçim** zaten vardı.
* **Bina editörü daire taşıma:** sürükleme + `Alt+Ok`. İkisi de telefonda
  yok; ancak **Düzenle** modalında `Kat` ve `Sıra` alanları var ve o modal
  artık dokunmatikte erişilebilir (yukarıdaki `coarse:flex` düzeltmesi).
  Yani kaybolan **kısayoldu**, işlev değil.
* **Pano bölüm sıralaması:** zaten "Yukarı taşı / Aşağı taşı" düğmeleriyle.

---

## 3. Dokunma tuzağı — sayfanın alt yarısı erişilemiyordu

`OrbitControls` (3D) ve Leaflet (harita) tek parmak sürtmesini **kendi
jesti** sayar ve dokunuşu yutar. Tam genişlikte, sayfanın ortasında duran
böyle bir alanın üzerinden aşağı kaydırmak isteyen kullanıcının parmağı
oraya düştüğünde **sayfa kaymıyordu**. Fare tekerleği olan bir cihazda bu
tuzak yoktur; masaüstünde görülmesi mümkün değildi.

`components/ui/dokunma-kapisi.tsx` — **tek mekanizma, iki tüketici**
(3D yükleyicisi + harita yükleyicisi). Kaba işaretçide üstte şeffaf bir
katman durur; dokunuşa müdahale etmediği için tarayıcı sayfayı normal
kaydırır. Kullanıcı bilerek dokununca içerik tam etkileşime açılır ve
**çıkış düğmesi** kalır — çıkış yolu bırakmadan açmak, tuzağı kapıyla
birlikte yeniden kurmak olurdu.

Jestler ölçüldü: bina sahnesinde tek parmak döndürür, iki parmak
yakınlaştırır (`enablePan={false}` ile `TWO` yalnız zoom'a düşüyor) —
brief'in istediği davranış zaten buydu.

**Not:** brief'te geçen "şikâyet haritası" **üründe yok**. Panelin haritaları
`/checkpoints` (NFC nokta konumları) ve `/schematic` (plan haritası); kapı
ikisine de uygulandı. `components/SiteHarita.tsx` P167'de Özet'ten
çıkarıldığından beri **hiçbir yerden çağrılmıyor**.

---

## 4. Kaydırma kilidi — aynı iş, üç uygulama, ikisi yanlış

| Yer | Önce | Sonra |
|---|---|---|
| `Modal` | yalnız `overflow: hidden` → **iOS Safari yok sayar** | ortak kanca |
| `Cekmece` | **kilit hiç yoktu** | ortak kanca |
| Kabuk çekmecesi | doğru sürüm | ortak kanca |

`lib/kaydirma-kilidi.ts`. `position: fixed` + negatif `top`, kapanınca
konumu geri koyar (sayfanın **başa atlamasını** da engeller). İç içe
açılanlar **sayılır**: sayaç olmasaydı çekmeceden açılan modal kapanınca
kilit çözülür, çekmece hâlâ açıkken sayfa arkada kaymaya başlardı.

---

## 5. Ekran ekranı durum

**Telefon (`sm`, 360–414 px)**

| Ekran | Durum |
|---|---|
| Özet | 7 widget 2 sütun; finansal kartlar tek sütun; takvim **ajanda**; 3D sade + dokunma kapısı |
| Daireler · Kullanıcılar · Görevler | kart kipi; görev takvimi ajanda; kanban yatay kaydırma + kategori seçimi |
| Bildirimler | zaten kart listesi |
| Vardiyalar · NFC · Devriye | kart kipi; harita dokunma kapısıyla |
| Kameralar | ızgara tek sütuna düşüyor; anlık görüntüler artık **tembel** |
| Finansal İşlemler (8 sayfa) | özet kartlar tek sütun; defterler yatay kaydırma + gösterge |
| Raporlar · modallar | modal **tam ekran** + güvenli alan payı |
| SMS/E-posta · Karar Defteri · Doküman · KVKK | kart kipi; formlar 16 px girdi |
| Tanımlar | ortak `TabloKart` — kaydırma artık klavyeyle de yapılabiliyor |
| Profil | iç menü **yatay şerit** |
| Sistem · Kurulum sihirbazı | kurulum zaten dikey adım listesi (ölçüldü, değişiklik gerekmedi) |

**Tablet (`md` 640–1023 / `lg` 1024–1439):** ızgaralar 2–3 sütuna oturuyor;
`md`de 3D sahne artık **sade** — eşik 768'den 1024'e alındı. 768 bu projede
başka hiçbir yerde geçmeyen bir sayıydı; değişen aralık (768–1023) tanım
gereği tablet dikeydir, masaüstü değil. Ayrıca eski ölçüm `useEffect` içinde
**bir kez** yapılıyordu: telefonu yatay çevirmek ya da pencereyi büyütmek
sahneyi eski kararda bırakıyordu. Artık sorgu **dinleniyor**.

---

## 6. Başarım

`next build` (üretim) ölçümü:

* **Tüm rotalarda ortak ilk yük: 88,3 kB**
* **En ağır rota `/dashboard`: 180 kB** (`/tasks` 175, `/tanimlar` 174)

Ağır paketlerin hiçbiri ilk yükte değil — `three` + R3F + drei, Leaflet ve
Recharts `next/dynamic` + `ssr:false` ile ayrı parçalarda. Zengin metin
editörü **dış kütüphane kullanmıyor** (tarayıcının kendi düzenleme motoru),
yani orada ertelenecek bir yük yok.

Görsel yükü: `Foto`, `/kameralar` ızgarası ve görev fotoğrafı `loading="lazy"
decoding="async"` aldı. 20 kameralı bir sitede telefon açılışta 20 anlık
görüntüyü birden çekiyordu.

**Ölçülmeyen:** yavaş-4G'de gerçek ilk çizim süresi. Buradaki sayı **paket
boyutu**, cihazda geçen süre değil; gerçek ölçüm için gerçek cihaz ve ağ
kısıtlaması gerekir, bu turda yapılmadı. Rakam **verilmiyor** çünkü
uydurulmuş bir saniye değeri, ölçülmüş bir değerle aynı biçimde okunurdu.

---

## 7. Kapsam dışı bulunan ve düzeltilen kusur

`yz-asama10-tarama` testinin sahte ucu `/kvkk-metinler` için yanlış şekil
(dizi yerine nesne) veriyordu ve `VeriTablosu` bunu **yakalanmamış
istisnayla** çöküyordu. Vitest bunu "testleri yanlış geçiriyor olabilir"
diye bildiriyordu — yani tarama sessizce eksik ölçüyordu. Uç, dizi listesine
eklendi. Ayrıca `/reports/dues` iki tabloya `undefined` geçebiliyordu;
`?? []` ile kapatıldı.
