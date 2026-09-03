# P210 — Ses dosyaları geldi: üçüncü kanal, `_v2` geçişi, küçültücü tuzağı

## Dosya doğrulaması (ölçüldü, `ffprobe`)

| Dosya | Süre | Biçim | Boyut |
|---|---|---|---|
| `yonetio_bildirim.ogg` / `.caf` | **0,32 sn** | Vorbis mono 22 kHz / IMA4 CAF 44,1 kHz | 4,5 K / 19 K |
| `yonetio_vardiya.ogg` / `.caf` | **4,62 sn** | Vorbis mono / IMA4 CAF | 28 K / 110 K |
| `yonetio_gurultu.ogg` / `.caf` | **7,42 sn** | Vorbis mono / IMA4 CAF | 45 K / 174 K |

**CAF boyutları sorun değil.** iOS'un kısıtı **30 saniye**; en uzun dosya
7,4 sn. Söylediğim "< 100 KB" bir öneriydi (indirme/paket boyutu için),
platform sınırı değil — burada aşılması bir şeyi bozmuyor.

Not: 7,4 sn bir bildirim sesi için uzun. Gürültü uyarısı **daireye en
fazla 7 günde bir** gittiği için kabul edilebilir; her gün çalan bir
seste aynı süre rahatsız edici olurdu.

## K1 — Kaçan vardiya hangi sesi kullanacak? → `yonetio_bildirim`

**`yonetio_vardiya` DEĞİL.** Gerekçe:

1. **Farklı dinleyici, farklı eylem.** `yonetio_vardiya` görevliye
   "vardiyan başlıyor, hazırlan" der. Kaçan vardiya uyarısı **yöneticiye**
   "görevli gelmedi, yerine birini bul" der. Sesin tek işi *bakmadan* ne
   olduğunu anlatmak; aynı sesi iki farklı eyleme vermek bu işi bozar.
2. **Somut karışıklık:** kendisi de bir vardiya listesinde olan bir
   yönetici (küçük sitede sık), "vardiyan başlıyor" sesini duyup kendi
   vardiyası sanır — oysa gidip birini yerine göndermesi gerekiyor.
3. **Üçüncü bir kanal açmadım:** nadir bir olay için kullanıcının sistem
   ayarlarına bir satır daha eklemek, ayar ekranını okunmaz yapmaya doğru
   giden yoldur. Kaçan vardiya kritik kanaldan, genel kritik sesle gider —
   "önemli, şimdi bak"ın ortak sesi.

## K2 — Üçüncü kanal + `_v2` geçişi

Yeni kanal `yonetio_vardiya_v2` (IMPORTANCE_HIGH, kendi sesi).
Beş kanalın **hepsi** `_v2`: `kritik`, `genel`, `sessiz`, `gurultu`,
`vardiya`. Manifest varsayılanı da `yonetio_genel_v2`.

Android'de var olan bir kanalın sesi program tarafından değiştirilemez;
kimlik aynı kalsaydı güncelleyen kullanıcıda **eski (sessiz) kanal**
kalırdı. Eski `_v1` kuşağı `deleteNotificationChannel` ile siliniyor —
yoksa ayar ekranında aynı ada sahip iki satır görünürdü.

`SES_HAZIR = True`.

## K3 — SESLER APK'YA GİRMEMİŞTİ (ölçülen kusur)

Dosyalar `res/raw/`e konuldu, `flutter build apk --release` **sorunsuz
geçti**, ama sesler **APK'da yoktu**:

```
aapt2 dump resources app-release.apk   →  `raw` TİPİ HİÇ YOK
build/app/intermediates/packaged_res/… →  üç .ogg DURUYOR
build/app/intermediates/shrunk_resources_binary_format/…  ← küçültücü
```

**Kök neden:** release yapımında kaynak küçültücü (resource shrinker)
çalışıyor ve sesler yalnızca `resources.getIdentifier("yonetio_gurultu",
"raw", …)` ile aranıyordu. Bu bir **çalışma zamanı dizgi aramasıdır**;
küçültücü onu göremez, dosyaları "kullanılmıyor" sayıp atar.

Bu **sessiz** bir kusur: kod çalışır, kanal oluşur, bildirim gelir —
yalnızca ses sistem sesidir. Ancak cihazda, kulakla fark edilir.

**Düzeltme:** statik `R.raw.yonetio_*` referansı. Küçültücü görür; dosya
silinirse **kod derlenmez** — sessiz kusur, derleme hatasına döner.
`getIdentifier`ın "dosya yoksa sistem sesine düş" esnekliği artık
istenmiyor zaten: dosyalar var ve olmak zorunda.

**Doğrulama (yeni APK):**
```
type raw id=0b entryCount=3
  raw/yonetio_bildirim · raw/yonetio_gurultu · raw/yonetio_vardiya
APK içinde: OggS imzalı üç dosya — 4577 / 28035 / 45487 bayt (kaynakla aynı)
classes.dex: beş `_v2` kimliği + silinecek dört `_v1`
```

## K4 — 5 dakika kademesi (madde 4 doğrulaması)

P207'de kural: virgüllü liste, 1–240 arası, **en fazla 3 kademe**,
varsayılan 15. **5 bu sınırların içinde** ve tek başına da yazılabiliyor.
Ölçüldü (test): `"5"` → `[5]`; ayar `5` iken vardiya 06:00Z ise 05:55Z'de
hatırlatma gitti (`dakika=5`), 05:53Z'de **gitmedi** (pencere
`(kademe-1, kademe]`). Zincirin son halkası da ölçüldü: bu bildirim
`yonetio_vardiya_v2` kanalından `yonetio_vardiya.caf` sesiyle gidiyor.

Varsayılan **15 olarak kaldı** — 5'e çekmedim: bu tenant ayarıdır ve
tesis kendi seçmeli. Sitenizde 5 dk isteniyorsa Tesis ayarları →
"Vardiya hatırlatma (dakika)" alanına `5` yazılır (ya da `15,5` ile iki
kademe).

## Ölçüm

Backend `test_p207_push_kanal.py` → **17 test** (4 yeni: vardiya kanalı,
kaçan vardiyanın hatırlatma sesini kullanmaması, üç sesin ayrışması,
kimliklerin `_v2` olması; 4 eski test yeni gerçeğe güncellendi).
`test_p207_vardiya_hatirlatma.py` → **17 test** (2 yeni: 5 dk kademesi,
kanal/ses eşlemesi).
Mobil `p207_kanal_kimlik_test.dart` → **8 test** (3 yeni: dosyaların
pakette olması, `_v2` + eski kuşak silme, `R.raw` kuralı).

**Kilit kanıtı:** `getIdentifier`a geri dönüldü → `SESLER STATIK R.raw
ILE` testi düştü; geri alındı. (Bu kilit olmasaydı kusur yalnızca
cihazda, kulakla fark edilirdi.)

Mobil tam takım **2040** yeşil.

**Ölçemediğim:** seslerin cihazda gerçekten çalması ve birbirinden ayırt
edilebilir olması — APK'ya girdiklerini ve doğru kanallara bağlandıklarını
ölçtüm, kulakla doğrulama sizde. iOS tarafında `.caf` dosyalarının pakete
girmesi de sizde (Xcode → Runner target).
