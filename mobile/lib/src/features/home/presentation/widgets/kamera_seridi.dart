import 'package:flutter/material.dart';

import '../../../../core/i18n/l10n.dart';
import '../../../../core/theme/home_tokens.dart';
import '../../../cameras/domain/camera_models.dart';
import '../../../cameras/presentation/kamera_karti.dart';
import 'section_header.dart';
import 'section_padding.dart';
import 'hizli_erisim.dart';

/// Ana ekranin "Canlı Kamera" seridi (gorevli.jpeg): yatay kaydirilabilir
/// kamera kartlari. Kart tipi Kameralar ekranindaki izgarayla AYNIDIR
/// ([KameraKarti]) — ad + konum + "• Canlı" / "Oynatılamıyor".
///
/// Liste SUNUCUDAN gelir ve sunucuda rol'e gore suzulmustur; bu widget
/// EK SUZGEC UYGULAMAZ (sakin/gorevli yalniz kendisine gonderilen kameralari
/// gorur — istemci "gizli" bir kamerayi eleyip guvenlik gibi davranmaz).
class KameraSeridi extends StatelessWidget {
  const KameraSeridi({
    super.key,
    required this.kameralar,
    required this.onAc,
    this.onSeeAll,
  });

  final List<Camera> kameralar;

  /// Secilen kamera — oynatilabilir mi kararini cagiran katman verir.
  final ValueChanged<Camera> onAc;

  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (kameralar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionPad(
          child: SectionHeader(
            title: context.l10n.kameraSeritBaslik,
            onSeeAll: onSeeAll,
          ),
        ),
        Builder(
          builder: (context) {
            final kartGenislik = kameraKartGenisligi(context);
            return SizedBox(
              height: kameraSeritYuksekligi(context, kartGenislik),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: kHomePagePadding),
                itemCount: kameralar.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: HomeTokens.gridGap),
                itemBuilder: (context, i) => KameraKarti(
                  kamera: kameralar[i],
                  width: kartGenislik,
                  onTap: () => onAc(kameralar[i]),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Ana ekranda AYNI ANDA gorunmesi hedeflenen kamera sayisi (P25c).
///
/// Eskiden kart sabit 168 dp idi ve tipik bir telefonda ekrana yalnizca IKI
/// kamera sigiyordu: sekiz kameralik bir sitede yonetici ana ekranda ne
/// oldugunu goremiyor, her seferinde yatay kaydiriyordu. Genislik artik
/// EKRANDAN hesaplanir.
const int kKameraGorunenKart = 4;

/// Serit karti genisligi — ekrana [kKameraGorunenKart] tanesi sigacak sekilde.
///
/// ALT SINIR 80 dp: tipik telefonlarda (>= 390 dp) dordu TAM sigar; 320 dp
/// gibi cok dar bir ekranda dortte bir 63 dp'ye duser ve ad satiri okunmaz
/// olurdu — orada dordu zorlamak yerine "sigdigi kadar" gosterilir (yatay
/// kaydirma zaten var). UST SINIR 168: genis tablette kartlar devlesmesin.
/// YAZI OLCEGI kart genisligini BUYUTMEZ — yukseklik zaten olcekle buyur ve
/// genisligi de buyutmek 2.0x olcekte ekrana tek kart birakirdi.
double kameraKartGenisligi(BuildContext context) {
  final ekran = MediaQuery.sizeOf(context).width;
  final kullanilabilir = ekran -
      2 * kHomePagePadding -
      (kKameraGorunenKart - 1) * HomeTokens.gridGap;
  return (kullanilabilir / kKameraGorunenKart).clamp(80.0, 168.0);
}

/// Serit yuksekligi — kart genisligine BAGLI (sabit 196 degil).
///
/// Kart: 8 dp ic bosluk x2 + 16:10 gorsel + ad/konum/durum satirlari.
/// Genislik kuculuyorsa gorsel de kuculur; sabit yukseklik bosluk birakirdi.
double kameraSeritYuksekligi(BuildContext context, double kartGenislik) {
  final gorsel = (kartGenislik - 16) * 10 / 16;
  // 3 metin satiri + araliklar + kart ic boslugu (olculdu: 101 dp).
  return seritYuksekligi(context, gorsel + 101);
}
