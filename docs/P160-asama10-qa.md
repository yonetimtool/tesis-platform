# P160 / Aşama 10 — Rol bazlı gezinti ve QA raporu

> Brief: *"her rol için tüm menüyü tek tek gez ve raporla: hangi sayfa yeni
> dilde, hangisi eski kaldı, konsolda hata var mı."*

Ölçüm tarihi: bu turun sonu. Ölçüm yöntemi ve **neyin ölçülmediği** §4'te.

---

## 1. ÖNCE BİR DÜZELTME: altı rolün dördünün web yüzeyi YOK

Brief altı rol sayıyor: yönetici, denetçi, güvenlik, güvenlik amiri, tesis
görevlisi, sakin. Panelde bunların **ikisi** oturum açabiliyor:

| Rol | `app.*` (panel) | Neden |
|---|---|---|
| **yönetici** | ✅ açılır | `TESIS_ROLLERI` |
| **denetçi** | ✅ açılır (dar küme) | `TESIS_ROLLERI` — salt okuma (P128) |
| **admin** | ✅ açılır + `panel.*` | platform yüzeyi |
| güvenlik | ❌ | `MOBIL_ROLLERI` — mobil uygulamaya yönlendirilir (P129) |
| tesis görevlisi | ❌ | `MOBIL_ROLLERI` |
| sakin | ❌ | `MOBIL_ROLLERI` |
| **güvenlik amiri** | ❌ | `tesisYuzeyiBekleyenRol` — ne web ne mobil ekran seti var (P129) |

Bu bir eksik değil, **kayıtlı bir karar**: `lib/yuzey.ts` P129'da menüyü
role göre süzmeye başladı çünkü `app.*`a giren bir sakin, hiçbirini
açamadığı 39 bağlantı görüyordu. O yüzden bu rapor **yönetici · denetçi ·
admin** üzerinden yürüyor; diğer üç rol için doğru cevap "panelde ekranı
yok"tur.

---

## 2. ROL × SAYFA — tam matris

`✓` menüde görünür · `-` görünmez · **DİL** = sayfanın tasarım dili.

| Rota | Dil | yönetici | denetçi | admin |
|---|---|---|---|---|
| /dashboard | yeni | ✓ | – | ✓ |
| /olaylar | yeni | – | – | ✓ |
| /notifications | yeni | ✓ | – | ✓ |
| /kameralar | yeni | ✓ | – | ✓ |
| /shifts | yeni | ✓ | – | ✓ |
| /checkpoints | yeni | ✓ | – | ✓ |
| /patrol-plans | yeni | ✓ | – | ✓ |
| /arac-gecisleri | yeni | – | – | ✓ |
| /units | yeni | ✓ | – | ✓ |
| /tasks | yeni | ✓ | – | ✓ |
| /assets | yeni | ✓ | – | ✓ |
| /schematic | yeni | ✓ | – | ✓ |
| /dis-hizmetler | yeni | ✓ | – | ✓ |
| /dues | yeni | ✓ | – | ✓ |
| /finans | yeni | ✓ | – | ✓ |
| /sayac-okuma | yeni | ✓ | – | ✓ |
| /reports/dues | yeni | ✓ | – | ✓ |
| /reports/patrols | yeni | ✓ | – | ✓ |
| /reports/tasks | yeni | ✓ | – | ✓ |
| /raporlar | yeni | ✓ | **✓** | ✓ |
| /icra | yeni | ✓ | **✓** | ✓ |
| /announcements | yeni | ✓ | – | ✓ |
| /mesajlar | yeni | ✓ | – | ✓ |
| /complaints | yeni | ✓ | – | ✓ |
| /anketler | yeni | ✓ | – | ✓ |
| /davetler | yeni | ✓ | – | ✓ |
| /kurulum | yeni | ✓ | – | ✓ |
| /ice-aktarim | yeni | ✓ | – | ✓ |
| /building-editor | yeni | ✓ | – | ✓ |
| /tanimlar | yeni | ✓ | – | ✓ |
| /users | yeni | ✓ | – | ✓ |
| /transparency | yeni | ✓ | **✓** | ✓ |
| /yonetisim | yeni | ✓ | – | ✓ |
| /kvkk | yeni | ✓ | ✓ | ✓ |
| /profil | yeni | ✓ | ✓ | ✓ |

**Yalnız `panel.*` (admin):** /tenants · /integrations · /settings ·
/audit · /yetki · /support — hepsi **yeni** dilde.

**Park edilmiş sayfalar** (dosya duruyor, hiçbir role açık değil — P129
kararı): /aidatim · /taleplerim · /kurallar · /etkinlikler ·
/rezervasyonlarim · /ziyaretciler · /kargolar · /gorevlerim · /duyurular ·
/yonetim-iletisim. **Hepsi yine de yeni dile taşındı**, çünkü bu sayfalar
mobil/sakin yüzeyi açıldığında geri gelecek ve o gün eski dilde kalmış
olsalardı tur yeniden açılırdı.

### Denetçinin kümesi neden bu kadar dar

Kayıtlı gerekçe (P128/P129): `/finans` ve `/dues` **form** taşır; sunucu
denetçiyi 403 ile keser ama basılacak bir düğme göstermek "yetkim var
sandım" demektir. Denetçi aynı veriye `/raporlar`dan yazmasız ulaşır.
`/icra` istisnadır: uç okumayı denetçiye açar ve sayfa ona **yazma
düğmesi çizmez** (`yazabilir = role === "admin"`).

---

## 3. ESKİ DİLDE KALAN SAYFA: **YOK**

Tarama ölçütü: sayfa kaynağında `cardCls`/`panelCls`/`panelMotion`/
`inputCls`/`btnPrimary`/`btnGhost`/`btnDanger`/`<ErrorBox`/`<PageHeader`/
`<EmptyState` geçmiyor. 51 korumalı sayfanın **51'i** geçiyor.

**Bilinçli olarak kalan iki bağımlılık** — bunlar "eski dil" değil:

1. **`EksikVeriUyarisi`** (`components/form`): bir bağımlılık uyarısı
   bileşeni, tasarım ilkeli değil. Altı sayfada kullanılıyor.
2. **`components/tablo`** ilkelleri: altı tabloda duruyor ve her biri
   `VeriTablosu`'na taşınmadı çünkü genel tablonun ifade etmediği bir
   şeyleri var — finans kasa tablosu (toplam satırı), aidatım özeti,
   yönetişim karar listesi, entegrasyon uç listesi, görev tamamlama
   kayıtları, tesis yönetici listesi. Bunları taşımak, genel bileşene
   kullanılmayan kavramlar eklemek olurdu.

---

## 4. KONSOL — ölçüldü

`tests/yz-asama10-tarama.dom.test.ts`: **51 sayfanın hepsi** jsdom'da
çiziliyor ve çizim sırasında `console.error`/`console.warn` **boş**.
Yakalanan sınıflar: eksik `key`, geçersiz DOM iç içe geçmesi, denetimli↔
denetimsiz girdi geçişi, geçersiz öznitelik.

Tarama **iki gerçek şey buldu**:

* **`/profil` — denetimli onay kutusu `undefined` görebiliyordu.**
  `setAranabilir(data.aranabilir)` alan gelmezse kutuyu denetimsize
  çeviriyordu (kullanıcının işaretini sessizce kaybettiren sınıf).
  `?? false` kondu. Sözleşme bugün alanı hep gönderiyor — bu bir
  sağlamlaştırma, aktif bir kusur değil; dürüstçe böyle kaydedildi.
* **`/ice-aktarim`** düz dizi dönen bir uç okuyor; taramanın ilk sahtesi
  nesne döndürünce sayfa çöktü. **Kusur taramada değil sayfada değildi** —
  sahte düzeltildi. Yine de not: bu uç sözleşmesi (`list[...]`) depodaki
  diğer uçlardan farklı ve gelecekte kolayca yanlış okunabilir.

### ÖLÇÜLMEYEN — dürüst not

| Ne | Neden ölçülmedi | Nasıl ölçülür |
|---|---|---|
| Gerçek tarayıcı konsolu | jsdom Next.js çalışma zamanını, CSS'i ve ağ katmanını çalıştırmaz | test sunucusunda DevTools |
| Görsel düzen / taşma | jsdom düzen hesaplamaz (`getBoundingClientRect` hep 0) | gerçek tarayıcı + 360dp/768/1440 |
| 3D sahne FPS | WebGL yok | `docs/3d-yol-haritasi.md` §7 |
| Kontrast (canlı) | tokenler ölçüldü, **sayfa birleşimleri** ölçülmedi | axe DevTools |
| Yedi dilde taşma | tarama yalnız `tr` ile çizdi | dil değiştirip aynı taramayı koşmak |

---

## 5. KALAN İŞ

### Yapılmadı, gerekçesi var
* ~~**Aşama 5 · RouteScene**~~ — **YAPILDI**, NFC noktaları ve devriye
  planlarına bağlandı (`docs/3d-yol-haritasi.md` §4).
* ~~**Leaflet / Şikayet haritası 2D**~~ — **YAPILDI.** `/schematic` iki
  sekmeli oldu: Şema (erişilebilir, varsayılan) + Plan haritası (Leaflet
  `CRS.Simple`). **Karo sunucusu kararı düştü**: bu haritada karo yok.
  Gerekçe ve ölçüm `docs/3d-yol-haritasi.md` §5'te.
* **`components/form` ve `components/tablo`nun tümden emekliye
  ayrılması** — §3'teki iki bağımlılık sürüyor.

### Ölçülmesi gereken
* Gerçek tarayıcıda konsol + görsel geçiş (yukarıdaki tablo).
* Yedi dilde tarama (özellikle `ru` ve `ar`: en uzun etiketler ve RTL).
* Paket: paylaşılan First Load JS **87.6 → 87.9 kB** (+0.3). Artış
  `Grafik` bileşeninin kabuğundan; recharts'ın kendisi tembel ve ana
  pakete girmiyor. Bir sonraki turda ölçülmeye devam etmeli.

### Bilinen davranış farkı
* `/olaylar` yöneticiye **kapalı** (P154 kararı, sebebi `yuzey.ts`te
  yazılı: yönetici listeyi okuyabiliyor ama yazamıyordu ve "Olay bildir"
  düğmesi 403 alıyordu). Sayfa yeni dilde ama yalnız admin görüyor.
