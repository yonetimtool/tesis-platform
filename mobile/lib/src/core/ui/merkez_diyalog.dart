import 'package:flutter/material.dart';

/// MERKEZ SAYFA (P22a) — uygulamadaki tum acilir pencerelerin TEK bicimi.
///
/// Eskiden her form/detay `showModalBottomSheet` ile ekranin ALTINDAN
/// aciliyordu. Kerem'in istegi: hepsi ORTADAN acilsin ve tek bir diyalog
/// bicimi olsun. Bu yardimci `showDialog`i sarar; cagiran taraf yalniz
/// GOVDEYI verir, duzeni (genislik, kenar bosluk, kaydirma sinirlari)
/// burasi kurar.
///
/// OLCULMUS UC KARAR (tur 31'de acik acik olculdu, ikisi regresyon oldugu
/// icin yaziliyor):
///
/// 1. ZEMIN `surfaceContainerLow` — M3'te `Dialog` varsayilani
///    `surfaceContainerHigh`tir. Zemin koyulasinca alt sayfada 4.5'i tutan
///    ikincil metin **3.90** kontrasta duser (koyu tema surusu boyle
///    kirmizi verdi). Zemini alt sayfanin yuzeyine sabitlemek, ekran ekran
///    metin rengi kovalamaktan iyidir.
///
/// 2. `Column(mainAxisSize.min)` + `Flexible` — yalniz `ConstrainedBox`
///    kullanilirsa cocuk SINIRSIZ yukseklik alir; govdelerin icindeki
///    mevcut `SingleChildScrollView`in viewport'u **0.0** olur ve pencere
///    HIC kaydirmaz (olcum: `viewport: 0.0, range: 0..378`).
///
/// 3. DIS KAYDIRMA YOK — govdeler zaten kendi `SingleChildScrollView`ini
///    tasir; disariya ikinci bir kaydirma alani koymak ic ice kaydirma
///    uretiyordu.
///
/// [kapatilabilir] perdeye dokununca kapanmayi kontrol eder (alt sayfanin
/// `isDismissible` karsiligi).
Future<T?> merkezSayfaAc<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool kapatilabilir = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: kapatilabilir,
    useSafeArea: true,
    builder: (dctx) => merkezSayfaGovdesi(dctx, builder(dctx)),
  );
}

/// Diyalog kabugunu tek yerde kurar — `merkezSayfaAc` ve dogrudan
/// `showDialog` cagiran (donus degeri icin kendi rotasini kuran) yerler
/// ayni kabugu paylassin diye ayri fonksiyon.
Widget merkezSayfaGovdesi(BuildContext context, Widget cocuk) {
  return Dialog(
    // (1) numarali karar: alt sayfayla AYNI yuzey.
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    // Dar ekranda (320 dp) 40 dp'lik varsayilan yatay bosluk govdeyi
    // ezip tasma uretiyordu; 16 dp yeterli ve dokunma alanini korur.
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      // Tabletde/genis ekranda pencere ekrani boydan boya kaplamasin.
      constraints: const BoxConstraints(maxWidth: 560),
      // (2) numarali karar: min + Flexible → govdenin kendi kaydirma
      // alani SINIRLI yukseklik alir ve gercekten kaydirir.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Flexible(child: cocuk)],
      ),
    ),
  );
}
