# 3D Yol Haritası (P160 / Aşama 5)

> Brief: *"DİĞER MODÜLLERİN 3D SAHNELERİ BU TURDA YAPILMAYACAK. Belgede 12
> ayrı sahne isteniyor; her biri ayrı model, ayrı optimizasyon ve ciddi
> performans bütçesi demek. Bunun yerine: hangi modüle hangi sahne, hangi
> sırayla — PLANLA."*

---

## 1. BU TURDA YAPILAN

| Sahne | Durum | Nerede |
|---|---|---|
| **BuildingScene** (site/bina maketi) | ✅ **yapıldı** | Canlı Panel |
| **RouteScene** (devriye rotası) | ✅ **yapıldı** — §4 | NFC Noktaları · Devriye Planları |

`components/3d/` altında üç dosya: `bina-sahnesi.tsx`, `rota-sahnesi.tsx`
ve **ikisinin paylaştığı** `sahne-yukleyici.tsx` (tembel yükleme + WebGL
ölçümü + tema/hareket/mobil kararı + geri düşüş). Ayrım kasıtlı —
`next/dynamic` kararı sahnenin *dışında* verilmeli, yoksa modül zaten
yüklenmiş olur. §4'ün "ikinci bir tembel yükleme mekanizması yazılmayacak"
kuralı bu yüzden `useSahneOrtami` ile karşılandı.

**Ölçüldü:** paylaşılan paket **87.5 → 87.9 kB** (+0.4; artışın kaynağı
`Grafik` kabuğu, 3D değil). Üç.js hâlâ ana pakete girmiyor: `/checkpoints`
3,94 kB · `/patrol-plans` 5,61 kB.

---

## 2. NEDEN 12 SAHNE BU TURDA YAPILMADI

Karar gerekçeleriyle:

1. **Her sahne bir MODEL demek.** Depoda tek bir glTF yok. Bina sahnesi
   yer tutucu geometriyle (kutu) çözülebildi çünkü bir site *kütlelerden*
   oluşuyor. Ama "asansör bakım sahnesi" ya da "jeneratör sahnesi" kutuyla
   anlatılamaz — modelsiz yapılırsa **dekor** olur ve brief'in en sert
   kuralını (*"veriye bağlı olacak, dekor değil"*) çiğner.
2. **Her sahne ayrı performans bütçesi.** Tek sahne bile gölge haritası,
   ışık ve malzeme ayarı istiyor. On iki sahnenin FPS'i ayrı ayrı
   ölçülmeli; ölçülmeyen sahne, yavaş cihazda ürünü kötü gösterir.
3. **Fayda eğrisi çok hızlı düşüyor.** Site maketi *yönetim panosunda*
   gerçekten bilgi taşıyor (hangi blok, hangi kamera çevrimdışı). Bir
   "aidat 3D sahnesi" hiçbir karar değiştirmez — süs olur.

**Ölçüt:** bir sahne ancak *"bu görselleştirme olmadan kullanıcının
göremeyeceği bir ilişki var mı?"* sorusuna evet denirse yapılmalı.

---

## 3. SAHNE ÖNCELİK SIRASI

Ölçüte göre sıralandı. **Kademe 1** yapılmalı, **2** değerli, **3** ise
gerekçesi olmadan yapılmamalı.

### Kademe 1 — bilgi taşıyor (sonraki tur)

| # | Sahne | Modül | Ne gösterir | Model ihtiyacı |
|---|---|---|---|---|
| 1 | **RouteScene** | NFC Noktaları · Devriye Planları | Rota çizgisi, kontrol noktası durumu (okutuldu/gecikti/atlandı), ilerleme | **YOK** — çizgi + küre yeterli |
| 2 | **FloorScene** | Daireler | Kat planı: daire doluluk, borçlu daire, açık talep | Kat planı geometrisi (bloklardan türetilebilir) |
| 3 | **CameraCoverageScene** | Kameralar | Kamera konumu + görüş konisi; kör nokta | **YOK** — koni ilkel geometri |

### Kademe 2 — değerli ama modelsiz zayıf

| # | Sahne | Modül | Not |
|---|---|---|---|
| 4 | AssetScene | Demirbaş | Demirbaşın binadaki yeri; model olmadan işaretçiye düşer |
| 5 | IncidentScene | Şikayet Haritası | 3D yerine **2D harita (Leaflet)** daha doğru — §5 |

### Kademe 3 — yapılmamalı (gerekçe olmadan)

Aidat · Finans · Raporlar · Tanımlar · İcra · Vardiyalar · Yönetim.
Hiçbiri mekânsal bir ilişki taşımıyor; 3D burada **süs**tür ve paket
maliyeti gerçek.

---

## 4. RouteScene — sonraki turun tasarımı

Hazır olsun diye şimdiden yazıldı:

```
components/3d/rota-sahnesi.tsx
  props: { noktalar: {id, ad, durum, sira}[], ilerleme: number }
  durum: "okutuldu" | "gecikti" | "atlandi" | "bekliyor"
```

- Noktalar **sıraya göre** bir eğri üzerine dizilir (`CatmullRomCurve3`);
  gerçek koordinat yok ve uydurulmayacak — sıra bilgisi var, o kullanılır.
- Çizgi **ilerlemeye göre** iki renge bölünür (tamamlanan / kalan).
- Gecikmiş nokta **amber**, atlanmış **kırmızı**; bina sahnesiyle aynı
  `--yz-*-edge` ailesi.
- `BinaSahnesi` ile **aynı yükleyiciyi** kullanır — ikinci bir tembel
  yükleme mekanizması yazılmayacak.

### Uygulanınca ne değişti (dürüst not)

Tasarım büyük ölçüde aynen uygulandı; **iki sapma** var:

1. **`ilerleme` dışarıdan alınmıyor, okutulan noktalardan TÜRETİLİYOR.**
   İki kaynak olsaydı çizgi ile noktalar birbirini yalanlayabilirdi.
2. **`rotaCizgisi` diye bir anahtar eklendi.** `/checkpoints` sayfasındaki
   noktalar bir plana bağlı **değil** — aralarında sıra yok. Orada çizgi
   çizmek, olmayan bir devriye yolu göstermek olurdu; sahne o sayfada
   yalnız durum işaretçilerini çiziyor ve ekranda bunu **yazıyor**.

**Durum nereden geliyor** (`lib/rota-durumu.ts`, tek tanım):
`GET /scans` bugünkü okutmaları, `GET /dashboard/live` alarmları verir.
Öncelik: `eksik_checkpoint` → atlandı · `gecikmis_okutma` → gecikti ·
taramada var → okutuldu · aksi halde bekliyor. **Alarm okutmayı ezer**,
çünkü alarm sonradan üretilir: dün okutulmuş ama bugünkü turda atlanmış
bir noktayı yeşil göstermek yanlış olurdu.

**Eklenen tek şey bir BFF köprüsü:** `/api/scans`. Uç
(`backend/app/routers/scans.py`) baştan beri vardı, panelde karşılığı
yoktu — backend'e dokunulmadı.

---

## 5. ŞİKAYET HARİTASI — 2D, ama COĞRAFİ DEĞİL

> **Bu bölüm bir turda düzeltildi.** Önceki hâli *"şikayetin konumu
> coğrafi, mimari değil"* diyordu ve **yanlıştı** — iddia ölçülmeden
> yazılmıştı.

### Ölçüm

Depoda `lat/lng` taşıyan tablolar: `tenant` (hava durumu konumu),
`checkpoint`, `scan_event`, `task_completion`, `asset_checkout`.
**`unit_complaint`, `unit` ve `block` hiç koordinat taşımıyor.** Bir
şikayet bir *daireye* bağlıdır; daire de bloğa, kata ve sıraya. Yani
coğrafi bir OSM haritası ancak **şikayet başına konum uydurularak**
çizilebilirdi.

### Karar: Leaflet, `CRS.Simple` kipinde

Leaflet kuruldu (`leaflet` 1.9 + `react-leaflet` **4.2.1** — v5 React 19
istiyor, projede React 18 var) ama **coğrafi kipte değil**. `CRS.Simple`
kat planı/şema haritaları için tasarlanmış düzlemsel bir koordinat
sistemidir; girdi gerçek veridir: `blok` (yatay şerit), `sıra` (sütun),
`kat` (dikey eksen).

**Bunun iki sonucu var:**

1. **Karo sunucusu kararı DÜŞTÜ.** Bu bölümün eski hâli Kerem'e (a) public
   OSM / (b) kendi sunucumuz / (c) karosuz seçimini bırakıyordu. `CRS.Simple`
   haritasında **karo yok**, dolayısıyla dış istek de yok. Karar gereksiz.
2. Harita *"burası dünyada şu nokta"* demiyor, *"bu daire bu bloğun bu
   katında"* diyor — kayıtla **birebir aynı** iddia.

### Şema kaldı, harita yanına geldi

`/schematic` artık iki sekmeli: **Şema** (varsayılan) ve **Plan haritası**.
Şema kaldı çünkü **erişilebilir yüzey odur**: her hücre gerçek bir
`<button>`, klavyeyle gezilir, `aria-pressed` taşır. Bir tuval üzerindeki
dikdörtgen bunu veremez. Harita büyük sitelerde pan/zoom kazandıran
**alternatif** görünümdür, tek görünüm değil.

**Sessiz eksik yok:** kat/sıra girilmemiş daireler haritada yer alamaz
(uydurma sütun, daireyi olmadığı yere koymaktı) — sayıları ekranda
yazılır ve şema görünümünde erişilebilir kalırlar.

**Ölçüldü:** `leaflet` kendi tembel parçasında (**148 kB**), paylaşılan
pakete **girmedi**. Paylaşılan paket 87,9 → **88,3 kB** (+0,4); artışın
kaynağı Leaflet değil (shared parçalarda `leaflet`/`MapContainer` izi yok)
— kesin kaynağı ayrıştırılmadı, dürüstçe not düşülüyor.

### Coğrafi harita — NFC noktaları için YAPILDI

Koordinat taşıyan veri **var**: NFC noktaları (`gps_lat/gps_lng`).
*"Bu nokta binanın arkasında mı, bahçede mi"* sorusu gerçekten coğrafidir
ve bir plan şeması onu yanıtlayamaz.

**Karo sunucusu: public OSM — Kerem'in kararı.** Bu seçimin iki
yükümlülüğü kodda karşılanıyor:

1. **Attribution zorunlu.** `© OpenStreetMap katkıda bulunanlar` ibaresi
   haritada görünür (ODbL + karo kullanım politikası); metin sözlükten
   gelir, yedi dilde.
2. **Karo sunucusu değiştirilebilir.** OSM'nin public karoları bir
   *nezaket* hizmetidir; yoğun/toplu kullanım politikaya aykırı. Panel
   kullanımı düşük hacimli (yalnız yönetici) ama kendi sunucumuza geçiş
   tek satırlık bir ayar olsun diye `NEXT_PUBLIC_KARO_URL` baştan bağlandı.

`/checkpoints` iki sekmeli oldu:

| Sekme | Ne çizer | Ne iddia eder |
|---|---|---|
| **Harita** (varsayılan) | koordinatı **olan** aktif noktalar | gerçek coğrafi konum |
| **Akış** | **tüm** aktif noktalar | sıra yok, çizgi yok — yalnız durum |

**Sessiz eksik yok:** koordinatı girilmemiş noktalar haritada yer alamaz;
sayıları ekranda yazılır ve Akış görünümünde + tabloda dururlar. Hiçbir
noktada koordinat yoksa **boş dünya haritası çizilmez** — ne yapılacağını
söyleyen bir boş durum çıkar.

**İşaretçi `CircleMarker`:** Leaflet'in varsayılan işaretçisi PNG'ye
bağlıdır ve paketleyici altında yolu bozulur (klasik `marker-icon.png`
404'ü). Vektör işaretçi dosya istemez; **beyaz hale + renkli dolgu**
kullanılıyor çünkü karo görüntüsü keyfîdir ve bir rengin karo üzerindeki
kontrastı önceden ölçülemez — durum ayrıca ipucunda **metin** olarak yazar.

### Okutma katmanı — YAPILDI

Aynı harita ikinci bir katman taşıyor: o günün okutmaları. Nokta
işaretçileri dolu daire, okutmalar **daha küçük ve içi açık**; ikisi
arasına **kesikli bir çizgi** çekiliyor — sapma bir bakışta görünüyor.
Katman düğmeyle kapatılabilir (`aria-pressed`), varsayılan açık.

**Yalnız `konum_durumu === "var"` olan okutmalar haritaya girer.** Enum
beş değerli ve dördü "konum yok" demek (`izin_yok`, `servis_kapali`,
`zaman_asimi`, `bilinmiyor`) — sunucunun P34 gerekçesi bu üçünü tek bir
NULL'a indirmemeyi açıkça savunuyor. Haritaya konamayan okutmaların
sayısı ekranda yazılır.

#### Eşik: ürün kararı olarak alındı — ve bir AYAR

Önceki turda burada *"sistemde eşik yok, uydurmak ürün kararı olurdu"*
yazıyordu. **Karar alındı (Kerem): varsayılan 50 m, tesis bazında
değiştirilebilir.**

Eşik `tenant.okutma_mesafe_esigi_m` kolonunda (göç `0052`), Ayarlar →
Operasyon altında yönetici tarafından değiştirilir. **Sabit kodlamak
yanlış olurdu:** bir sitede noktalar bahçe içinde 10 m aralıklarla
dizilidir, diğerinde bloklar arası 200 m vardır — aynı sayı ikisinde de
anlamlı olamaz. `localStorage` da yanlış olurdu: eşik bir **tesis
politikası**, kişisel tercih değil; iki yönetici farklı "eşik dışı"
listesi görürdü.

Sınırlar **iki yerde de aynı**: şema `CHECK BETWEEN 1 AND 5000`, API
`Field(ge=1, le=5000)`. Farklı olsalardı API'den geçen bir değer
veritabanında reddedilir ve istek 500 ile düşerdi — bir test bunu
doğrudan veritabanına sorarak kilitliyor.

#### "Belirsiz" üçüncü bir sonuçtur — ve zorunludur

GPS doğruluğu eşikten **büyükse** karşılaştırma karar veremez: ±100 m
hatayla ölçülmüş bir mesafenin 50 m eşiğini geçip geçmediği bilinemez.
Bunu "eşik dışı" saymak, **ölçüm hatasını ihlal diye raporlamaktı** —
yani birini yanlış suçlamak.

Bu bir ürün kararı değil, **aritmetik**: hata payı eşiğin tamamından
büyükse kıyas anlamsızdır. Panel üçüncü bir sonuç döner (`belirsiz`),
mesafeyi yine yazar ve yargıyı kullanıcıya bırakır. Doğruluk alanı hiç
gelmiyorsa (eski istemci) karşılaştırma yapılır — elde başka bir şey yok
ve her okutmayı belirsiz saymak eşiği işe yaramaz kılardı.

**Dil hâlâ ölçüm dili:** "eşik dışı" bir **gözlem** bildirir, "şüpheli"
ya da "ihlal" bir **suç atfeder**. 60 m uzakta okutma yapmış bir
görevliyi panelin suçlaması, ölçümün taşıyabileceğinden fazlasını iddia
etmekti. Bir test sözlükte bu kelimelerin geçmemesini kilitliyor.

#### Eşik BİLDİRİM ÜRETMEZ — bilinmesi gereken sınır

Ölçüldü: sunucu **hiçbir yerde mesafe hesaplamıyor**. Alarm üretimi
(`kacirilan_tur`, `eksik_checkpoint`, `gecikmis_okutma`) yalnız *eksik* ve
*geciken* okutmayla ilgili; mesafeyle değil.

Yani eşiği değiştirmek **haritanın neyi işaretlediğini** değiştirir ama
bildirim/alarm üretmez. Yönetici "eşiği koydum, artık uyarı alırım"
beklerse yanılır. Eşiğin alarma dönüşmesi ayrı bir iş: alarm üretimi,
bildirim ve worker tarafı — bu turda **istenmedi ve yapılmadı**.

## 6. PERFORMANS BÜTÇESİ (her yeni sahne bunu tutmalı)

| Ölçüt | Hedef | Bu turda |
|---|---|---|
| Paylaşılan pakete etki | **0 kB** (tembel) | ✅ +0.1 kB |
| Masaüstü FPS | ≥ 60 | `frameloop="demand"` — hareketsizken 0 kare |
| Orta dizüstü FPS | ≥ 30 | ölçülmedi (§7) |
| Mobil | sadeleştirilmiş/durağan | ✅ `hareketVar=false` |
| `prefers-reduced-motion` | sahne statik | ✅ |
| WebGL yok | zarif geri düşüş | ✅ metin özeti |

---

## 7. ÖLÇÜLMEYEN — dürüst not

**FPS gerçek cihazda ölçülmedi.** Brief 60/30 fps istiyor; bu tur
`frameloop="demand"` ile *yapısal* bir güvence koydu (hareketsiz sahne
kare çizmez) ama sayı ölçülmedi. Ölçüm için gerçek tarayıcı gerekiyor
(jsdom WebGL çalıştırmaz) ve test sunucusunda yapılmalı:

```
DevTools → Performance → 10 sn kayıt → panoyu döndür → FPS grafiği
```

Blok sayısı arttıkça (20+ blok) kutle sayısı doğrusal artar; o noktada
`InstancedMesh`e geçmek gerekebilir — şimdiden yapmak, olmayan bir sorunu
çözmek olurdu.
