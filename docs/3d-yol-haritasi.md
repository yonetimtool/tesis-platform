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

## 5. ŞİKAYET HARİTASI — 3D DEĞİL, 2D

Brief Aşama 6 zaten *"Leaflet/MapLibre + OpenStreetMap"* diyor ve bu
doğru: şikayetin konumu **coğrafi**, mimari değil. 3D bir şehir sahnesi
hem karo veri hem model ister, hem de kullanıcıya adres bulmayı
**zorlaştırır**.

`leaflet` bu turda **kurulmadı** — Şikayet Haritası taşınırken kurulacak.
Karar gerekçesi: bugün kullanılmayan bir paketi `package.json`'a eklemek,
ölçülen paket temelini kirletir.

**Karo sunucusu kararı gerekiyor:** public OSM karoları kullanım
şartlarına tabi ve kurumsal ağda erişilemeyebilir. Seçenekler: (a) public
OSM (hızlı, şartlara tabi), (b) kendi karo sunucumuz (bağımsız, işletme
yükü), (c) karosuz — yalnız işaretçi + adres metni. Karar Kerem'de.

---

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
