# P182 — Özet sayfası düzeni + 3D maket etiketleri (kararlar)

Kesintisiz mod: kararlar burada gerekçesiyle. Dört bölüm de **web** (admin-web).
Backend/göç YOK. Kabul kriterleri dosyanın sonunda işaretli.

---

## §1 — 3D maket: kamera/bildirim ÜSTÜNDEKİ metin etiketleri kaldırıldı

**Sorun:** 3D makette her kamera/bildirim işaretinin yanında adı bir kapsülde
yazıyordu; işaret sayısı artınca sahne "yazı bulutu"na dönüyordu.

**Karar:** İşaret artık **yalnız renkli, tıklanabilir bir nokta**. Ad sahnede
kalıcı yazı olarak GÖRÜNMEZ ama erişilebilirlikten düşmez:
- `aria-label` + `title` → ad, üzerine gelince tarayıcı ipucu + ekran okuyucu.
- Tıklama davranışı **değişmedi**: `onSec(id)` yine çağrılır, seçilen bilginin
  paneli/gösterimi eskisi gibi açılır.
- Renk kodu (tür + sönük durum) ve hover büyümesi korundu → işaret ayırt edilir.

**Dosya:** `admin-web/components/3d/bina-sahnesi.tsx` (`Etiket`). Blok ADI etiketi
(sahne tabanındaki blok ismi, hover'da) BU DEĞİL — o korundu; kaldırılan yalnız
işaret üstündeki ad kapsülleri.

**Tarayıcı tuzağı:** `Etiket` başındaki açıklama `/** */` blok yorumuydu; tur-22
tarayıcısı blok yorumu soymaz → "çevrilmemiş JSX metni" sanıyordu. `//` satır
yorumuna çevrildi. Ayrıca `transform: uzerinde ? "scale(1.25)" : "none"` üçlüsü
tur-47'ye "görünen metin" gibi geldi → değerler modül sabitine
(`ISARET_BUYUME_*`) alındı, üçlüde yalnız tanımlayıcı kaldı.

---

## §2 — Izgara sınırı tutarsızlığı (7 vs 6) — HER YERDE 6

**Kök neden (sessiz kayıt hatası):** Sunucu şeması `PanoTercihi.widgetlar`
**hep `max_length=6`** idi. İstemci sabiti `WIDGET_SINIRI = 7` idi ve metinde
"en fazla 7" yazıyordu. 7. widget eklenince `PUT /me/pano-tercihi` **422**
(`pano_tercihi_gecersiz`) dönüyordu; ama bir yerde başarı sanılıp "kaydedildi"
görünümü veriliyordu → kullanıcı 7 seçip kaydettiğini sanıyor, ertesi gün 6
buluyordu.

**Karar:** Sınır **6** — istemci + metin + ızgara + (zaten) sunucu.
- `admin-web/lib/pano-tercihi.ts`: `WIDGET_SINIRI = 7 → 6`. Metin bu sabitten
  üretilir (`panoKisayolSiniri {n}`), istemci doğrulaması (`widget-seridi.tsx`)
  da bu sabite bakar → tek kaynak.
- `admin-web/components/pano/widget-seridi.tsx`: masaüstü ızgara `lg:grid-cols-7
  → lg:grid-cols-6` (bkz. §3).
- Sunucu (`backend/app/schemas.py` `max_length=6`, `routers/takvim.py` 422)
  DEĞİŞMEDİ — zaten 6'ydı; tutarsızlık istemci tarafındaydı.

**Sessiz kayıt taraması (aynı desen başka yerde var mı?):** `void kaydet()` +
koşulsuz `toast.success` ya da `.catch(() => {})` deseni tarandı. **Tek** örnek
`varsayilanaDon` idi (`void duzeniKaydet(); toast.success()` — kayıt patlasa da
"kaydedildi" diyordu). Düzeltme:
- `duzeniKaydet` artık `Promise<boolean>` döner (`catch` → `toast.error`, `false`).
- `varsayilanaDon` `await` eder; başarı mesajını **yalnız `true` gelirse** gösterir.
- Diğer kayıt çağrıları (`satirlariUygula`, `widgetDegisti`) zaten `duzeniKaydet`
  üzerinden gidiyor → başarısızlıkta `toast.error` görünür (bkz. §4 otomatik kayıt).
- Başka sessiz-kayıt örneği BULUNMADI.

---

## §3 — Izgara hizası: masaüstünde tam genişlik, sağ kenar 3D maketle hizalı

**Sorun:** 6 kısayol mobil/tabletta iyiydi; masaüstünde sağda boşluk kalıyordu.

**Kök neden:** Kısayol şeridi `lg:grid-cols-7` kullanıyordu. Sınır 6'ya inince
7 sütunlu ızgarada **6 widget → sağda 1 boş sütun** kalıyordu ("eksik kart" gibi
okunan boşluk, hizasız görünüm).

**Karar:** `lg:grid-cols-7 → lg:grid-cols-6`. Altı sütun altı widget'ı tam
doldurur; sağ kenar sayfa içeriğinin sağ keniyla (= 3D maketin sağ keniyla)
hizalanır. Maket ve şerit **aynı** içerik kabı içindeki satırlar olduğundan,
şeridi 6 fr-sütunla genişletmek sağ kenarları eşitler.
- Esnek ızgara (`grid-cols-N`, fr birimleri) — **sabit piksel YOK**.
- Dokunma katmanları değişmedi: `grid-cols-2 sm:grid-cols-3 md:grid-cols-4`
  (mobil/tablet mevcut görünüm korunur), yalnız `lg` 7→6.
- Satır bölümleri (`SUTUN_SINIF`) zaten `grid grid-cols-N` (fr, tam genişlik) —
  banner/gruplar düzgün HTML ızgarasıyla kurulu, kayan yerleşim yok.

**Dosya:** `admin-web/components/pano/widget-seridi.tsx`.

---

## §4 — Düzenleme arayüzü sadeleştirildi (sürükle-bırak + klavye)

### Otomatik kayıt mı, tek "Kaydet" düğmesi mi? → **OTOMATİK KAYIT** (gerekçe)

**Seçim: otomatik kayıt.** Her düzenleme (sütun sayısı, banner, gizle/göster,
sürükle-bırak taşıma, klavye taşıma) anında `PUT /me/pano-tercihi` yazar.
Gerekçe:
1. **Belirsiz "kaydedilmemiş değişiklik" durumu yok.** Tek "Kaydet" düğmesi,
   kullanıcının kaydetmeden ayrılıp düzenini kaybetmesi riskini getirir; pano
   düşük-riskli, sık dokunulan bir tercih ekranı — "her dokunuş kalıcı" sezgisi
   daha doğru.
2. **Yazma ucuz ve atomik:** tek küçük JSONB gövdesi; her değişiklik bağımsız.
3. **Başarısızlık GÖRÜNÜR (§2):** `duzeniKaydet` `catch`'inde `toast.error`
   (`panoKaydedilemedi`); sessizce yutulmaz. Başarıda `varsayilanaDon` dışında
   sessiz kalır (her küçük taşımada "kaydedildi" bildirimi gürültü olurdu).
4. **Karışım yok:** İki model (hem otomatik hem düğme) yok — brief'in "ikisi
   karışmasın" şartı. Üst bardaki tek eylem düğmesi düzeni **Düzenle/Bitti**
   (kip anahtarı), bir de yıkıcı **Varsayılana dön** (yalnız kipte).

### Sürükle-bırak = asıl etkileşim

Önceki düzenleme kipi her bölümde **4 taşıma düğmesi** (← → yukarı aşağı) +
her satırda taşıma düğmeleri barındırıyordu — kalabalık. Yerine:

- **Tek sürükle tutamacı** (`⠿`) her bölüm başlığında. Bölüm bu tutamaçtan
  sürüklenip başka bölümün önüne ya da boş satıra bırakılır.
- **Bırakma hedefi görsel:** üzerine gelinen bölüm kesik çerçeveyle (`VURGU_STIL`)
  işaretlenir; boş satır kesik-çerçeveli bir "Bölümü buraya bırakın" bölgesidir.
- **Tutulan bölüm** soluklaşır (geri bildirim).

### Erişilebilirlik: klavyeyle de taşınır

Tutamaç bir `<button>` (odaklanabilir). Odaktayken **ok tuşları**:
`←/→` bölümü satır içinde, `↑/↓` önceki/sonraki satıra taşır. Aynı mantık
sürükle-bırak ile ortak: ikisi de `lib/pano-tercihi.ts`teki **saf** fonksiyonlara
bağlanır — `bolumSurukleBirak` (bırakma) ve `bolumOkTasi` (ok tuşu). Mantık
bileşenin dışında olduğu için jsdom'da sürükle olayı üretmeden **birim testle**
kilitlenir (`tests/pano-yerlesim-tasima.test.ts`, 16 test).

### Sadeleşen kontroller

- **Bölüm başlığı (kip):** ad + sürükle tutamacı + **gizle/göster**. (4 taşıma
  düğmesi kalktı.)
- **Satır kontrolü (kip):** **1/2/3/4** sütun seçici + banner girişi + satır
  yukarı/aşağı (2 küçük düğme — satır bir bütün olarak taşınabilsin diye kaldı;
  sürükle bölüm-düzeyinde çalışır). Sütun seçici **satır başına** — widget başına
  ayrı ayar YOK (brief).
- **Normal görünümde HİÇBİR düzenleme kontrolü yok** — hepsi `duzenlemede`
  koşuluna bağlı.
- **Varsayılana dön** korundu (yalnız kip; kayıt tutmazsa başarı demez).

### Dosyalar
- `admin-web/lib/pano-tercihi.ts`: `bolumSurukleBirak`, `bolumOkTasi`, `BolumYon`
  (saf, index-kaymasına ve boş satır temizliğine karşı güvenli — kimlikle çalışır).
- `admin-web/app/(protected)/dashboard/page.tsx`: sürükle durumu + tutamaç +
  bırakma bölgeleri + `bolumKlavye`; `bolumIcTasi`/`bolumSatirTasi` (buton mantığı)
  kaldırıldı.
- i18n (7 dil): `panoTasiTut` (tutamaç etiketi), `panoBosSatir` (boş satır bölgesi).

---

## Kabul kriterleri

1. ✅ 3D makette kamera/bildirim üstünde metin etiketi yok; ikon/işaret + tıklama
   davranışı korundu.
2. ✅ Izgara sınırı her yerde 6 (istemci sabiti + metin + ızgara sütunu + sunucu).
3. ✅ 7. widget artık sessizce düşmüyor; sınır 6'da net (istemcide eklenemez,
   metin "6" der).
4. ✅ Aynı sessiz-kayıt deseni tarandı; tek örnek (`varsayilanaDon`) düzeltildi;
   başkası yok — burada belgelendi.
5. ✅ Masaüstünde kısayollar tam genişlik; sağ kenar 3D maketle hizalı; esnek
   ızgara (sabit px yok); mobil/tablet görünümü korundu.
6. ✅ Bölümler sürükle-bırak ile yeniden sıralanıyor; sıralama otomatik kaydedilir
   ve yenilemede korunur (kayıt sunucuda).
7. ✅ Sürükle-bırak klavyeyle de yapılır (tutamaç + ok tuşları); görsel bırakma
   hedefi var.
8. ✅ Düzenleme kontrolleri yalnız düzenleme kipinde; normal görünüm temiz.
9. ✅ Kayıt başarısızlığı görünür (`toast.error`); "Varsayılana dön" var.
