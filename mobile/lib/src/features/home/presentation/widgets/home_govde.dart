import 'package:flutter/material.dart';

import '../../../../core/theme/home_tokens.dart';
import 'home_header.dart';
import 'section_padding.dart';

/// Ana ekran GOVDESI — uc rol varyantinin ortak iskeleti: en ustte karsilama
/// blogu, altinda bolumler (aralarinda tek tip bosluk).
///
/// Sayfa listesi yatay padding UYGULAMAZ; her bolum kendi boslugunu koyar
/// (yatay seritler kenardan tasabilsin diye — bkz. [kHomePagePadding]).
/// Bolum SIRASI cagiran ekrandadir: referans gorsellerin sirasi orada
/// okunur.
class HomeGovde extends StatelessWidget {
  const HomeGovde({
    super.key,
    required this.header,
    required this.bolumler,
    this.onYenile,
  });

  final HomeHeader header;

  /// Sirali bolumler. `SizedBox.shrink()` donen (veri yok) bolumler
  /// aralarinda BOSLUK BIRAKMAZ — cagiran katman gorunmeyecek bolumu
  /// listeye hic koymaz.
  final List<Widget> bolumler;

  /// Asagi cekip yenileme; null → yenileme yok.
  final Future<void> Function()? onYenile;

  @override
  Widget build(BuildContext context) {
    final liste = ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 28),
      children: [
        HomeSectionPad(child: header),
        for (final bolum in bolumler) ...[
          const SizedBox(height: HomeTokens.sectionGap),
          bolum,
        ],
      ],
    );

    if (onYenile == null) return liste;
    return RefreshIndicator(onRefresh: onYenile!, child: liste);
  }
}
