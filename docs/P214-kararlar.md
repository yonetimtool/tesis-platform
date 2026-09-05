# P214 — Modal haritanın altında kalıyordu (katman düzeni)

## Şikâyet

`app.yonetiyor.com/checkpoints` → "Yeni nokta" → modal açılıyor ama Leaflet
haritası üstünü kapatıyor; yalnız haritadan taşan alt şerit (İptal/Kaydet)
görünüyor.

## Kök neden — tahmin değil, iki dosyadan okunan sayılar

| | değer |
|---|---|
| Uygulama ölçeği (`app/tasarim-sistemi.css`) | 0–80 · `--yz-z-modal: 60` |
| Leaflet (`leaflet/dist/leaflet.css`) | 200–**1000** · `.leaflet-pane` 400, kontroller **1000** |

`components/ui/modal.tsx` **portal kullanmıyor** (`fixed inset-0`, sayfa
ağacında). Yani modal ile harita **aynı kök yığınlama bağlamında** yarışıyor
ve 400 > 60 olduğu için harita kazanıyor. Modalın haritadan **taşan** kısmı
görünüyordu — kullanıcının "yalnız alttaki düğmeler görünüyor" tarifi bunun
birebir yansıması.

## Karar: ezmek değil, izole etmek

Leaflet'in on kadar kuralını (`.leaflet-pane`, `.leaflet-popup`,
`.leaflet-control`…) tek tek ezmek yerine harita **kendi yığınlama
bağlamına hapsedildi**:

```
isolation: "isolate"; position: relative; z-index: var(--yz-z-base)
```

**Neden ezmedik:** o değerler kendi aralarında anlamlı (pane < popup <
control). Ezmek hem bu iç sırayı bozma riski taşır hem de Leaflet sürümü
değişince **sessizce** kırılır. İzolasyon tek satır, sürümden bağımsız ve
kütüphanenin iç sırasını **korur** — dışarıya harita tek bir katman olarak
görünür.

## Ölçek gözden geçirildi

Ölçek zaten vardı ve tutarlıydı (base 0 → tooltip 80), ama **üçüncü parti
kuralı yazılı değildi**. Kural artık ölçeğin tanımlandığı yerde, örnek kod
ve gerekçesiyle duruyor: *üçüncü parti bir bileşenin katman değerlerini tek
tek ezme, onu kendi bağlamına hapset.*

Tarama sırasında ölçekten kopmuş **üç ham değer** bulundu, üçü de ölçeğe
bağlandı:

- **`Toast.tsx: z-[60]`** — modalla **aynı** değerdi. Eşit z-index'te sırayı
  DOM konumu belirler, yani modal açıkken çıkan bir bildirimin görünüp
  görünmemesi tesadüfe kalıyordu. Ölçek zaten toast'ı modalın üstüne koyuyor
  (70 > 60). *Bu, şikâyetten bağımsız ikinci bir kusurdu.*
- **`dokunma-kapisi.tsx: z-[400]`** — Leaflet'in pane değerini (400) aşmak
  için konmuştu ama kontrollerini (1000) **zaten aşamıyordu**: sorunu
  çözmüyor, çözüyor gibi duruyordu. Harita artık izole olduğu için düğme
  onun dışında kalıyor; ölçekteki en düşük "üstte dursun" değeri yeterli.
- **`AppShell.tsx: focus:z-[60]`** (atlama bağlantısı) → `--yz-z-tooltip`.

Kodda ölçek dışı ham z-index **kalmadı** (testle kilitli).

## Tarama — aynı çakışma başka nerede?

Leaflet yalnız iki bileşende (`konum-haritasi`, `plan-haritasi`), iki sayfada
(`/checkpoints`, `/schematic`). İkisi de izole edildi.

Gerçek tarayıcıda beş sayfa tarandı; her öğenin hesaplanmış `z-index`'i
okundu ve ≥100 olanların izole bir atası olup olmadığı ölçüldü:

```
/checkpoints  leaflet=1  ölçek dışı 8 öğe, İZOLE OLMAYAN 0   (z=1000 leaflet-top ×2 … hepsi izole)
/schematic    leaflet=0 canvas=1   ölçek dışı 0
/dashboard    ölçek dışı 0
/units        ölçek dışı 0
/complaints   ölçek dışı 0
```

**İlk tarama boşa düşmüştü:** `/checkpoints`'te `leaflet=0` çıktı — harita
ancak **GPS'li nokta varsa** çizildiği için "0 sorun" hiçbir şey ölçmüyordu.
Tarama, veriyi kendisi kuracak şekilde düzeltildi ve yukarıdaki sonuç o
geçerli koşumdan.

- **Tarih seçiciler:** yerel `<input type="date">` kullanılıyor; açılır
  takvimi tarayıcı kendi katmanında çizer, sayfa z-index'inden etkilenmez.
- **Açılır menüler / ipuçları:** ölçek içinde (dropdown 40 < modal 60 <
  toast 70 < tooltip 80) ve harita artık yarışmıyor.
- **`/schematic` plan haritası** bu veri durumunda çizilmedi, yani orada
  **davranışsal olarak ölçülemedi** — aynı bileşen izolasyonu taşıyor ve
  kaynak kilidi bunu ölçüyor.

## Doğrulama — ne ölçtüm

**1. Gerçek tarayıcı (asıl kanıt).** `tools/katman-surusu.mjs`: modal
açılır, her form alanının merkezinde `document.elementFromPoint` sorulur —
o noktada en üstte hangi öğe var? Alanın kendisi değilse **örtülmüş**
demektir.

- **Dedektör sınaması** (`DENEY=1`, kök neden geri getirilir — izolasyon
  kaldırılıp kutu Leaflet bandına çekilir):
  `ORTULEN 6 öğe: input ← div.leaflet-container …` — **ölçüm kör değil**,
  ve bulduğu tablo kullanıcının tarifiyle birebir aynı (8 öğeden 6'sı
  örtülü, görünen 2'si alttaki düğmeler).
- **Düzeltmeyle:** `Modaldaki etkileşimli öğe: 8 · ORTULEN OGE YOK`.

**2. Birim kilitleri** (`tests/z-katman-duzeni.test.ts`, 9 test): ölçek
sırası ve **eşitlik olmaması**, ölçeğin 0–99 bandında kalması, Leaflet'in
ölçeğimizin üstünde olduğu (izolasyonu zorunlu kılan koşul), Leaflet kullanan
**her** bileşenin izole olduğu, Leaflet'in iç sırasının ezilmediği, kodda ham
z-index kalmadığı, ve `/checkpoints` modalı açıkken **form alanlarının
çizildiği**. Kilit, izolasyonu kaldırıp testin düştüğü görülerek doğrulandı.

**Ölçemediğim:** jsdom boyama yapmaz ve yığınlama sırasını hesaplamaz —
"modal piksel olarak üstte" iddiasını bir birim testi kuramaz. O iddia
yalnız tarayıcı sürüşünde ölçüldü; sürüş CI'da değil, elle koşulur
(`npx next build && npx next start -p 3196` → `KOK=http://app.localhost:3196
node tools/katman-surusu.mjs`). **Konak önemli:** `localhost` panel
yüzeyidir ve admin oradan `/tenants`'a düşer.
