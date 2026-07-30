import 'package:flutter/widgets.dart';

/// TUR 61 — AG GORSELLERINDE COZME SINIRI.
///
/// BULUNAN SORUN: `lib/src` icindeki 17 ag gorseli cagrisinin HICBIRI cozme
/// siniri vermiyordu. Yani 40x40 dp'lik bir avatar ya da 96 dp'lik bir liste
/// minyaturu icin bile sunucudan gelen fotograf TAM COZUNURLUKTE bellege
/// aciliyordu. 4000x3000'lik bir JPEG, ekranda 40 px gorunse de yaklasik
/// **48 MB** RGBA tutar; duyuru/kargo listesinde on fotograf yarim GB'a cikar.
///
/// Hicbir surus bunu goremezdi: gorsel taklidi (tur 34) minik bir PNG servis
/// ediyor, yani COZME BOYUTU hic zorlanmiyor. Kusur ancak gercek fotografla
/// ortaya cikardi — envanterin (tur 49, E maddesi) "buyuk fotografin bellek
/// etkisi" satiri tam buydu.
///
/// [mantiksal] ekranda gorunecek dp olcusudur; sinir cihazin piksel
/// yogunluguyla carpilarak FIZIKSEL piksele cevrilir (`cacheWidth`/
/// `cacheHeight` fiziksel piksel bekler). `null` gecilirse sinir konmaz.
int? cozmeSiniri(BuildContext context, double? mantiksal) {
  if (mantiksal == null || mantiksal <= 0) return null;
  return (mantiksal * MediaQuery.devicePixelRatioOf(context)).round();
}

/// [ImageProvider]'i cozme siniriyla sarar (avatar gibi `backgroundImage`
/// alanlari `cacheWidth` almadigi icin gerekir).
ImageProvider sinirliGorsel(
  BuildContext context,
  ImageProvider kaynak,
  double mantiksal,
) {
  final px = cozmeSiniri(context, mantiksal);
  return px == null ? kaynak : ResizeImage(kaynak, width: px, height: px);
}
