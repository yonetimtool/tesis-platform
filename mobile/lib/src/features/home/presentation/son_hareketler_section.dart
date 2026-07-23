import 'package:flutter/material.dart';

import '../domain/son_hareketler.dart';
import 'widgets/activity_row.dart';
import 'widgets/section_header.dart';

const _green = Color(0xFF16A34A);
const _teal = Color(0xFF1DB2B6);
const _purple = Color(0xFF7C3AED);
const _navy = Color(0xFF0E3C91);
const _red = Color(0xFFDC2626);
const _amber = Color(0xFFD97706);

/// Ana ekranin "Son Hareketler" bolumu (referans) — istemcide birlesik akis
/// ([residentHareketleri]). [now] disaridan → zaman etiketleri deterministik.
/// Bos akista bolum HIC cizilmez.
class SonHareketlerSection extends StatelessWidget {
  const SonHareketlerSection({
    super.key,
    required this.hareketler,
    required this.now,
    this.onSeeAll,
  });

  final List<Hareket> hareketler;
  final DateTime now;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (hareketler.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Son Hareketler', onSeeAll: onSeeAll),
        for (final h in hareketler)
          ActivityRow(
            icon: _icon(h.tip),
            title: h.baslik,
            subtitle: h.altBaslik,
            time: hareketZamanEtiketi(h.zaman, now),
            accent: _accent(h.tip),
          ),
      ],
    );
  }

  IconData _icon(HareketTip tip) => switch (tip) {
        HareketTip.kargoKayit ||
        HareketTip.kargoTeslim =>
          Icons.local_shipping_outlined,
        HareketTip.ziyaretci => Icons.emoji_people_outlined,
        HareketTip.aidatOdeme => Icons.receipt_long_outlined,
        HareketTip.alarm => Icons.error_outline,
        HareketTip.uyari => Icons.schedule_outlined,
        HareketTip.bilgi => Icons.notifications_outlined,
      };

  Color _accent(HareketTip tip) => switch (tip) {
        HareketTip.kargoKayit => _navy,
        HareketTip.kargoTeslim => _green,
        HareketTip.ziyaretci => _purple,
        HareketTip.aidatOdeme => _teal,
        HareketTip.alarm => _red,
        HareketTip.uyari => _amber,
        HareketTip.bilgi => _navy,
      };
}
