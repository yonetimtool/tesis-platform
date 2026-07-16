# Yönetio — master logo entegrasyonu (DEV-B)

Tarih: 2026-07-16 · Kapsam: YALNIZ istemci (mobile + admin-web). Backend/contracts DEGISMEZ.

## Amac

`mobile/assets/branding/logo_master.png` ile saglanan HAZIR logo (yuvarlak-kare,
mavi→teal gradyan zemin; beyaz isaret: uc bina + chevron/cati + kucuk ev + uc
insan + yay) markanin TEK kaynagi olur. Goruntu OLDUGU GIBI kullanilir —
yeniden tasarlanmaz.

Onceki commit'teki "Concept-15" geometrisi (navy zemin + iki blok + sinyal
yaylari) FARKLI bir tasarimdir; tamamen kaldirilir (karar: tek marka kimligi).

## Kararlar

1. **Basitlestirilmis isaret = elle cizilmis vektor.** Master'dan piksel
   esigiyle kesilemez (merkez bina yan bloklarla kesisir, isaret gradyan
   uzerinde yumusak golgeli). Bu yuzden merkez bina + chevron/cati siluetı
   `CustomPainter` olarak yeniden cizilir; ayni geometri admin-web'de inline
   SVG olarak aynalanir. Bu, projedeki TEK yeniden-cizilen geometridir.
2. **Concept-15 tamamen silinir** (painter geometrisi, logo.svg,
   logo_horizontal.svg, admin-web icon.svg + YonetioMark inline SVG, eski
   icon_1024/icon_foreground_1024). Git'ten geri alinabilir.
3. **Splash elle baglanir** (yeni bagimlilik yok): launch_background.xml +
   -v21 varyanti → navy zemin + ortada master bitmap.

## Varlik uretimi (tek jenerator)

`mobile/test/tools/generate_branding_assets.dart` — `flutter test` (argumansiz)
bunu ATLAR (dosya adi `_test.dart` degil). Acikca calistirilir:

    flutter test test/tools/generate_branding_assets.dart

Ortamda PIL/ImageMagick YOK; `dart:ui` PNG'yi natif cozer. Jenerator:

| Adim | Cikti |
|---|---|
| Beyaz kenar bosluguna gore oto-kirpma, kareye tamamla, **koseleri seffaflastir** | `assets/branding/icon_master.png` |
| Kirpilmis master'in kose pikselleri orneklenerek gradyan uclari cikarilir | `assets/branding/icon_background.png` |
| Beyaz isaret esikle cikarilir; sinir kutusu olculup dairesel maskeye sigacak sekilde olceklenir | `assets/branding/icon_foreground.png` |
| Basitlestirilmis isaret, beyaz-on-seffaf, 5 yogunluk | `android/.../drawable-*/ic_stat_yonetio.png` |
| Master, 5 yogunlukta splash bitmap'i | `android/.../drawable-*/splash_logo.png` |

Kaynak 637x634 → kirpma `(24,16)`'dan **608px kare**. **Buyutulmez** (brief).
Bu yuzden eski `icon_1024.png` adi birakildi; yeni ad `icon_master.png`.
xxxhdpi launcher 192px oldugundan 608px fazlasiyla yeter.

Orneklenen gradyan uclari: koyu uc **#0E3C91**, acik uc **#1DB2B6**. Bu iki
deger TEK dogruluk kaynagi: `YonetioColors`, android `values/colors.xml`,
admin-web `YonetioLogo.tsx` + `icon.svg` hepsi bunlari kullanir.

### Uretim sirasinda cikan, gozle bulunan uc sorun

1. **Kose beyazi.** Kaynakta logo beyaz zemine gomulu; yalniz kenar boslugunu
   kirpmak yetmedi — yuvarlak karenin DISINDA kalan koseler beyaz kaliyordu ve
   koyu temada beyaz ucgen olarak gorunuyordu. Cozum: master yuvarlak-kareye
   kirpilir (koseler seffaf).
2. **Hayalet cerceve.** Isaret esiklemesi, yuvarlak karenin beyaza yumusatilmis
   KENAR pikselerini de yakaliyor, isaretin etrafinda yuvarlak-kare cercevesi
   birakiyordu. Cozum: maske kenardan %4.5 iceri cekilir.
3. **Cift pay.** flutter_launcher_icons foreground'a varsayilan **%16 inset**
   ekliyor; uretimdeki payin ustune binince isaret ikonun ~1/3'une dusuyordu.
   Cozum: `adaptive_icon_foreground_inset: 0` + pay uretimde, OLCULEREK verilir
   (isaret sinir kutusu 401x450 → kosegen = tuvalin %66'si = dairesel maske
   capi; kirpilma imkansiz).

## Kullanim haritasi

| Yuzey | Surum |
|---|---|
| Launcher (adaptive) | tam master — bg: gradyan katmani, fg: paylı beyaz isaret |
| Giris ekrani | tam master ~120px + "yönetio" kelime isareti |
| Ana ekran app-bar | basitlestirilmis isaret ~28-30px |
| Bildirim kucuk ikon | basitlestirilmis isaret (monokrom zorunlu) |
| Splash | navy + ortada master |
| admin-web nav | basitlestirilmis isaret + kelime isareti |
| favicon | **basitlestirilmis** (asagida: karar) |

## Mobil

- `applicationId` (`com.tesisguvenlik.mobile`) **DEGISMEZ** — FCM /
  google-services.json ona baglidir. Yalniz `android:label` (zaten "Yönetio").
- `pubspec.yaml` → `flutter: assets:` altina `assets/branding/` EKLENIR. Su an
  kayitli degil (PNG'ler yalniz derleme-zamani girdisiydi); master calisma
  zamaninda `Image.asset` ile okunacagi icin zorunlu.
- Widget adlari korunur (`YonetioLogoMark`, `YonetioLogoVertical`,
  `YonetioWordmark`) → cagri yerleri (login_screen, home_screen) degismez;
  yalniz uygulama degisir.
- Bildirim: manifest'e `com.google.firebase.messaging.default_notification_icon`
  meta-data + `ic_stat_yonetio`.

## admin-web

- Tab basligi "Yönetio Panel" — zaten dogru.
- `YonetioMark` inline SVG → basitlestirilmis isaret geometrisi.
- favicon: `app/icon.svg` karara gore guncellenir.

## Favicon karari: BASITLESTIRILMIS isaret

Test edildi (tahmin degil): master 16px ve 32px'e indirilip 8x buyutulerek
piksel piksel bakildi (`generate_branding_assets.dart` → `favicon_*.png`).
32px'te uc bina birbirine giriyor, insanlar/yay gurultuye donuyor — okunmuyor.

Bu yuzden `admin-web/app/icon.svg` = mavi→teal gradyan yuvarlak-kare zemin +
uzerinde **beyaz basitlestirilmis isaret**. Zemin bilerek korundu: launcher
ikonuyla gorsel bag boylece kalir.

## Splash durumu: BAGLANDI (yeni bagimlilik yok)

`flutter_native_splash` EKLENMEDI. Bunun yerine mevcut
`launch_background.xml` + `drawable-v21` varyanti marka lacivertine + ortada
`splash_logo` bitmap'ine cevrildi. `drawable-v21` API21+'ta digerinin YERINE
gecer (min sdk 21) → ikisi birlikte guncellendi.

Bilinen sinir: Android 12+ kendi splash API'sini uygular (sistem, uygulama
ikonunu ortada gosterir); orada bu layer-list yalniz zemin olarak etkilidir.
Tam Android 12 splash kontrolu isteniyorsa `flutter_native_splash` ayri bir is.

## Testler

Logo geometrisini iddia eden test YOK; 443 test degisiklik gerektirmeden gecti.
`test/tools/preview_branding_screens.dart` eklendi — otomatik iddia degil,
GORSEL onizleme (giris acik/koyu + app-bar) uretir.

Ogrenilen: `Image.asset` widget testinde `testWidgets`'in sahte-zaman
bolgesinde COZULMEZ (gercek dosya-okuma/decode) — logo bos cikar. Onizlemede
`runAsync` + `precacheImage` ile alindi. Testlerde metin Ahem fontuyla kutu
olarak cizilir; onizlemede kelime isaretinin RENGI/olcegi dogrulanabilir,
glifleri dogrulanamaz.

## Kabul

`flutter analyze` temiz · `flutter test` 443/443 ✓ · `flutter build apk
--debug` ✓ · admin-web build ✓ · APK'da `package: com.tesisguvenlik.mobile`
DEGISMEDI ✓ · `application-label: Yönetio` ✓
