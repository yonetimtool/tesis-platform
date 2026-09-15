# P236 — telefon alanı kırıktı + bayraklı, aranabilir ülke listesi

---

## §1 — KUSUR: numara alanına yazılamıyor

### Ölçüm — nerede kırık, nerede değil

| Yüzey | Durum |
|---|---|
| **Web** | **KIRIK** |
| Mobil | sağlam (ölçüldü, aşağıda) |

### Kök neden: iki `width` sınıfı çakışıyordu

P233'te ülke seçiciyi şöyle yazmıştım:

```tsx
<Secim className="w-32 shrink-0"> …
```

`Secim` **kendi içinde `w-full` taşıyor** (`components/ui/alan.tsx`).
İkisi de `width` kuruyor ve hangisinin kazandığı **class attribute
sırasına değil, Tailwind'in ürettiği CSS sırasına** bağlı.

Tailwind 3.4.6 çıktısı **ölçüldü** (varsayılmadı):

```
.w-32  { width: 8rem }   ← önce
.w-full{ width: 100% }   ← SONRA, yani kazanan
```

Sonuç: select `width:100%` aldı, `shrink-0` yüzünden **küçülmedi** ve
numara alanı sıfır genişliğe indi. Kullanıcı ülkeyi seçebiliyor, numarayı
yazamıyor. Bildirilen belirti tam olarak bu.

Rendered DOM'da da görünüyordu:

```html
<select class="odak-ic h-11 w-full px-3 outline-none w-32 shrink-0">
```

### Düzeltme

Genişlik **sarmalayıcı div'e** taşındı; bileşenin kendi `w-full`'ü
dokunulmadan kaldı — Tailwind sırasına bağımlılık tamamen ortadan kalktı:

```tsx
<div className="w-32 shrink-0"><Secim …/></div>
<div className="min-w-0 flex-1"><Alan …/></div>
```

`min-w-0`: flex öğesinin varsayılan `min-width:auto` değeri, içerik
genişliğinin altına inmesini engeller ve uzun bir yer tutucu kutuyu
taşırırdı.

### Testler bunu neden yakalamadı

**jsdom düzen hesaplamaz.** `offsetWidth` her zaman `0` döner,
`getComputedStyle` class'ları çözmez, `w-32`/`w-full` çakışması diye bir
kavram orada yok. Ölçüldü: kusurlu kodda **DOM testlerinin hepsi
geçiyordu** — P233'ün 6 telefon testi, P205/P207/P232 dahil. Testler
"input var mı, `onChange` çalışıyor mu, gövde doğru mu" diye soruyordu ve
üçünün de cevabı **evet**ti. Kullanıcının göremediği şey **genişlikti**.

Aynı sınıfın daha önceki üyesi: `<select>` arka planına gradyan token
koymak — seçenekler görünmez olur, jsdom göremez.

### Yeni kilit — kaynak taraması

`tests/genislik-cakismasi.test.ts`: `Alan`/`Secim`/`CokSatir` üstüne
`w-*` sınıfı geçilemez (`w-full` hariç — o zaten bileşenin kendi değeri).
Altı dedektör vakasıyla sınandı.

**Kilit iki kusur daha buldu**, ikisi de sessizce duruyordu:

| Yer | Sınıf |
|---|---|
| `finans/borclandirmalar` | `<Alan className="w-20">` — gecikme oranı kutusu |
| `tenants/[id]` | `<Alan className="max-w-xs">` — tesis silme onayı |

İkisi de sarmalayıcıya taşındı.

### Mobil neden sağlam — ve nasıl kilitlendi

Mobil `SizedBox(width: 132)` + `Expanded` kullanıyor; CSS sınıfı yok,
çakışma **mümkün değil**.

Ama **Flutter düzen hesaplar** — jsdom'un yapamadığını yapabiliyor. Bu
yüzden mobilde kusur *davranışla* kilitlendi
(`test/p236_telefon_yazilabilir_test.dart`):

- numara alanı genişliği > 100 dp, ve seçiciden **geniş**
- ülke seçildikten sonra hâlâ yazılabiliyor (odak/etkinlik kaybı yok)
- ülke seçilmeden de yazılabiliyor — alan **kilitli değil** (geçersiz
  olması ayrı şey; kullanıcıyı sıraya zorlamak yanlış olurdu)
- 320 dp dar ekranda da kullanılabilir genişlik kalıyor

**Kırarak doğrulandı:** web'deki kusuru mobile taşıdım
(`SizedBox(132)` → `Expanded(flex:100)`) → **2 test düştü**. Geri alındı.

---

## §2 — Bayrak, arama, Türkiye

### Emoji mi görsel mi — **emoji**, ve nedeni ölçüldü

Soru "emoji bazı Android sürümlerinde düz gösteriliyor" diye soruldu.
Ölçüm şunu gösterdi: **asıl sorun Android değil, Windows.**

- Uygulama **özel yazı tipi taşımıyor** (`pubspec.yaml`'da `fonts:` bloğu
  yorumda) → sistem emoji yazı tipi kullanılıyor.
- **Windows'ta Segoe UI Emoji'de bayrak YOKTUR.** Panel çoğunlukla
  masaüstünde kullanılıyor, yani bu nadir bir durum değil **en yaygın
  durum**.
- Bazı Android yapımları (özellikle Çin pazarına çıkan OEM'ler)
  bayrakları çıkarıyor.

**Yine de emoji seçildi, çünkü çizilmediğinde bilgi kaybolmuyor.**
Bayrak bir **regional indicator çiftidir** (🇹🇷 = U+1F1F9 U+1F1F7); bayrak
biçimi yoksa **harflere düşer** ve ekranda `TR +90` yazar.

Bu, etiket tasarımını da değiştirdi: P233'te etiket `TR +90` idi ve bayrak
**ayrıca** çiziliyordu → `🇹🇷 TR +90`. Bayrak çizilmeyen platformda bu
**`TR TR +90`** demekti. Artık etiket **bayrak + arama kodu**:

| Platform | Görünen |
|---|---|
| bayrak destekli | `🇹🇷 +90` |
| desteksiz (Windows, bazı Android) | `TR +90` |

`+1`i paylaşan US/CA ve `+7`yi paylaşan RU/KZ **her iki durumda da** ayrışır.

**Görsel (SVG/PNG) seçilmedi:** 50 bayrak = 50 varlık (paket boyutu,
istek sayısı), CSP/çevrimdışı yüzeyi, bayat kalma riski (P184'te bayat
mipmap eski ikonu taşımıştı) — ve kazancı **yalnızca görsel**;
okunabilirlik zaten ISO harfleriyle garanti altında.

### Liste aranabilir

**Mobilde P233'ten beri vardı** (arama kutulu alt sayfa). **Web geride
kalmıştı** — yerleşik `<select>` kullanıyordu.

Web'de `<select>` **bırakıldı ve yerine aranabilir bir açılır liste
yazıldı** (`components/UlkeSecici.tsx`). Sebep ölçülebilir: yerleşik
listenin yazarak-atlaması **görünen metne** göre çalışır ve o metin artık
`🇹🇷 +90` — kullanıcı "TR" yazıp bulamazdı, emoji yazması gerekirdi.

Arama **ISO kodu ve arama kodu** ile eşleşiyor: "TR", "90", "+90" hepsi
çalışır. Bayrağın kendisi aranmıyor — kimse emoji yazarak aramaz.

### Türkiye

**Listenin başında** (P233'ten beri, `ULKELER` sırası). **Varsayılan
olarak seçili değil** ve bu P233'ün ölçülmüş kararı: önceden seçili bir
`+90`, kutuya hiç bakmadan yabancı numara yazan kullanıcının numarasını
**sessizce** Türk numarasına çevirirdi. Telefon global benzersiz anahtar
olduğu için bu, ya başkasının numarasıyla çakışma ya da erişilemez hesap
demekti. İstek "üstte **veya** varsayılan" olduğu için **üstte** olması
şartı karşılıyor.

---

## Telefon girilen TÜM yerler — tarandı

| Yüzey | Yer | Durum |
|---|---|---|
| Web | `/users` · `/tenants` · `/tenants/[id]` · `/tanimlar` · `/dis-hizmetler` · `/profil` · `/kayit` | ✅ hepsi paylaşılan `TelefonAlani` |
| Mobil | sakin ekle/düzenle · personel · dış hizmet · kayıt · profil · Dükkân | ✅ hepsi paylaşılan `TelefonAlani` widget |
| Giriş ekranı | web + mobil | muaf (tek kimlik alanı — P233 §3) |

Kusur **paylaşılan bileşendeydi**, yani yedi web yüzeyinin **hepsi**
kırıktı ve düzeltme hepsini birden kapattı. Kapsam kilitleri
(`telefon-kapsam.test.ts`, `telefon_alani_kapsam_test.dart`) bir yüzeyin
kendi alanını kurmasını zaten yasaklıyor — "biri çalışıp diğeri
çalışmasın" durumu yapısal olarak imkânsız.

---

## Tam paketin bulduğu kırmızı

Web tam paketi bir kusur daha yakaladı ve gerçekti: yeni `UlkeSecici`'de
`--yz-surface` ve `--yz-raised` diye **tanımsız** tasarım değişkenleri
kullanmışım. `tasarim-token.test.ts` (P160) yakaladı.

Düzeltme: **komut paletiyle aynı tokenlar** (`--yz-metal-1`,
`--yz-raised-hover`). O da bir açılır listedir ve ikisinin farklı yüzey
rengi taşıması tutarsızlık olurdu.

Bu, turun ikinci "jsdom görmez" dersi değil — bu kilit **kaynağa** bakıyor
ve tam olarak bu yüzden yakaladı. CSS değişkeni tanımsızsa tarayıcı
**sessizce** varsayılana düşer: liste renksiz görünür ama hiçbir hata
vermez.

---

## Ne ölçüldü — özet

| Ölçüm | Nerede | Sonuç |
|---|---|---|
| Tailwind sınıf sırası | `tailwindcss` CLI ile gerçekten derlendi | `.w-full` sonra → kazanıyor |
| Rendered DOM | jsdom, users sayfası | `class="… w-full … w-32 shrink-0"` |
| Web akışı uçtan uca | form aç → ülke seç → numara yaz → kaydet | `+905419222388` |
| Mobil alan genişliği | Flutter `getSize`, 390 dp ve 320 dp | yazılabilir genişlik var |
| Mobil akış | ülke seç → yaz → E.164 | `+905419222388` |
| Kilit kırma (web) | `<Alan className="w-32">` geri kondu | kilit yakaladı ✔ |
| Kilit kırma (mobil) | `SizedBox(132)` → `Expanded(flex:100)` | 2 test düştü ✔ |
| Emoji bayrak desteği | özel font yok → sistem emoji fontu | Windows'ta bayrak YOK, harfe düşüyor |
