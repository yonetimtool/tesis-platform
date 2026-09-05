import 'package:flutter/material.dart';

import '../../../../core/i18n/l10n.dart';
import '../../../../core/theme/home_tokens.dart';
import '../../../cameras/domain/camera_models.dart';
import '../../../cameras/presentation/kamera_karti.dart';
import 'section_header.dart';
import 'section_padding.dart';
import 'hizli_erisim.dart';

/// Ana ekranin "Canlı Kamera" bandi: SATIR BASINA IKI kart, genislik TAM
/// DOLDURULUR; ucuncu ve dorduncu kameralar ALTA gecer.
///
/// =========================================================================
/// (P213 §5) YATAY SERIT -> IKI SUTUNLU IZGARA
/// =========================================================================
/// OLCULEN SIKAYET: "kamera izgarasi 3 sutun ve sayfayi enlemesine
/// doldurmuyor". Sebep, seridin YATAY KAYDIRMALI olmasi ve kart
/// genisliginin "ekrana DORT kart sigsin" kuralindan turemesiydi (P25c):
/// tipik telefonda kartlar ~80-90 dp'ye dusuyor, sagda bos bir serit
/// kaliyor ve kare neredeyse okunmuyordu. Ana ekranda amac BAKIP GORMEK;
/// dar kartlar bunu engelliyordu.
///
/// Kart tipi Kameralar ekranindaki izgarayla AYNIDIR ([KameraKarti]).
/// YALNIZ BU IZGARA degisti — hizli erisim ve istatistik izgaralari
/// (`hizli_erisim.dart`, `stat_tile.dart`) DOKUNULMADI.
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kHomePagePadding),
          child: LayoutBuilder(
            builder: (context, kisit) {
              // IKI SUTUN, ARADA TEK BOSLUK: kalan genislik ikiye
              // BOLUNUR, yani band sayfayi TAM doldurur.
              final kartGenislik =
                  (kisit.maxWidth - HomeTokens.gridGap) / kKameraSutun;
              return Wrap(
                spacing: HomeTokens.gridGap,
                runSpacing: HomeTokens.gridGap,
                children: [
                  for (final k in kameralar)
                    SizedBox(
                      width: kartGenislik,
                      height: kameraSeritYuksekligi(context, kartGenislik),
                      child: KameraKarti(
                        kamera: k,
                        width: kartGenislik,
                        onTap: () => onAc(k),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// (P213 §5) SATIR BASINA KART SAYISI.
///
/// P25c'de bu sayi 4'tu ve kartlar YATAY bir seritte diziliyordu; tipik
/// telefonda kart ~85 dp'ye dusuyor, kare okunmuyordu. Iki sutun, ayni
/// ekranda hem GORULEBILIR bir kare hem de dort kamerayi (iki satir)
/// veriyor.
const int kKameraSutun = 2;

/// Eski ad — `kameraKartGenisligi` hesabinda hâlâ kullaniliyor (P25c
/// testleri o fonksiyonun sinirlarini kilitliyor).
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
