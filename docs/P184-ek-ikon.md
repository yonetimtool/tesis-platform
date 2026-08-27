# P184 ek — Mobil ikon düzeltmesi (zoom/kırpma + zemin varyantı)

## Sorun

Android launcher ikonu ZOOM'lu / logo kırpılmış görünüyordu. Asıl sebep,
%66 sığdırma kararının yanlış olması değil, **gömülü Android mipmap'lerin
bayat kalması** idi: kaynak varlıklar değiştikten sonra
`flutter_launcher_icons` yeniden koşulmamıştı. Bu turda:

1. Üretim betiği (`scripts/ikon-uret.py`) iki zemin varyantı üretecek
   şekilde genişletildi (karşılaştırma için).
2. Varsayılan varyant seçilip `assets/marka/ikon/`'a yazıldı.
3. `flutter_launcher_icons` yeniden koşuldu; `mobile/android/.../mipmap-*`
   ve `drawable-*/ic_launcher_foreground.png` ile tüm iOS `AppIcon`
   dosyaları GERÇEKTEN yeniden yazıldı (git 38 dosya değişik gösteriyor).

## Seçilen varyant ve gerekçe

**VARSAYILAN: `lacivert`** — lacivert zemin + beyaz siluet işaret.

| Varyant   | Zemin      | İşaret                       |
|-----------|------------|------------------------------|
| `acik`    | `#EAF1FA`  | Lacivert logo (olduğu gibi)  |
| `lacivert`| `#102060`  | BEYAZ SİLUET (`beyaza_boya`) |

Gerekçe: lacivert zemin modern, ayırt edici ve işaret üzerinde net öne
çıkıyor. Lacivert logo koyu zeminde görünmediği için işaret beyaz silüete
çevrildi (`png-arac.beyaza_boya`). Açık varyant tamamen üretilmiş ve
`assets/marka/ikon-onizleme/acik/` altında hazır durur; bir bayrakla
kolayca değiştirilebilir.

Mağaza ikonları (iOS App Store 1024, Play 512, apple-touch-icon) seçilen
uyarlanabilir (adaptive) zeminle **AYNI** üretilir — mağazalar arası
görsel tutarlılık için aynı lacivert zemin + beyaz işaret.

## Kırpma ve güvenli bölge sığdırması

- Kaynak: `assets/marka/yonetiyor-logo.png` (1072×992 RGBA).
- Kırpma kutusu (P177, karar): `(303, 182, 769, 641)` → **466×459** işaret.
- Android ön katman oranı `ORAN_ADAPTIF = 0.66` (Android'in belgelediği
  güvenli bölge).
- **İşaretin tuvaldeki son boyutu: 675×664 (1024 tuvalde) → %65.9** —
  %66 sınırının ALTINDA, işaretin tamamı görünür, kırpılma yok.
- Mağaza ikonu oranı `ORAN_MAGAZA = 0.72` (nefes payı).

## Alfa doğrulama (gerçek çıktı)

`ios-appstore-1024.png`, `play-store-512.png`, `apple-touch-icon.png` ve
üretilen `mobile/ios/.../Icon-App-1024x1024@1x.png` — hepsi **alfasız**
(ITMS-90717 reddini önler):

```
=== ALFA DOGRULAMA (hepsi False olmali) ===
  alpha=False  OK  assets/marka/ikon/ios-appstore-1024.png
  alpha=False  OK  assets/marka/ikon/play-store-512.png
  alpha=False  OK  assets/marka/ikon/apple-touch-icon.png
  alpha=False  OK  mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
SONUC: TUM ALFASIZ (gecti)
```

Betiğin kendi doğrulaması (`dogrula`) her üç çıktı dizini için de
"TUM DENETIMLER GECTI" verir; ön katman ve monochrome saydam kalır,
mağaza ikonları alfasızdır.

## Yeniden üretim (logo güncellendiğinde)

Depo kökünden, SIRAYLA:

```bash
python3 scripts/ikon-uret.py
cd mobile && export PATH="$PATH:/home/kerem/flutter/bin"
dart run flutter_launcher_icons
```

- İlk komut: her iki varyantın tam önizleme setini
  `assets/marka/ikon-onizleme/{acik,lacivert}/` altına yazar VE varsayılan
  varyantı `assets/marka/ikon/`'a (flutter'ın okuduğu yer) yazar.
- İkinci komut: gömülü Android/iOS launcher kaynaklarını yeniden üretir.

Kaynak logonun boyutu/sınır kutusu değişmişse betik **açıkça durur** —
kırpma kutusu (`KUTU`) bilinçli olarak yeniden seçilmelidir.

## Varyant değiştirme

Varsayılanı açık maviye çevirmek için:

```bash
python3 scripts/ikon-uret.py --varsayilan acik
cd mobile && dart run flutter_launcher_icons
```

Betikte `VARSAYILAN_VARYANT` sabiti de kalıcı olarak değiştirilebilir.
Yeni bir zemin denemek için `VARYANTLAR` sözlüğüne bir giriş eklemek
yeterli (zemin RGB + beyaz siluet bayrağı).

## Önizleme dosyaları (kullanıcıya gösterilecek)

- Açık:     `assets/marka/ikon-onizleme/acik/play-store-512.png`
- Lacivert: `assets/marka/ikon-onizleme/lacivert/play-store-512.png`
