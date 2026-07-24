import 'package:flutter/material.dart';

/// Ana ekranin yatay sayfa boslugu. Sayfa listesinin KENDISI padding'siz
/// cizilir; her bolum boslugu kendisi uygular. Boylece yatay kaydirilan
/// seritler (vardiya, canli kamera, hizli erisim) kenardan TASABILIR —
/// referans gorsellerdeki gibi son kart ekran kenarinda kesilir.
const double kHomePagePadding = 16.0;

/// Kenardan tasmayan (durgun) bolumler icin yatay bosluk sarmalayicisi.
class HomeSectionPad extends StatelessWidget {
  const HomeSectionPad({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: kHomePagePadding),
        child: child,
      );
}
