import 'package:flutter/material.dart';

import '../../../../core/theme/home_tokens.dart';
import '../../domain/home_view_models.dart';

/// Selamlamanin alt satir bicimi — referans gorsellerde uc varyant:
/// tesis secici (gorevli: "Mavi Residence ⌄"), duz gri (sakin: daire/blok)
/// ve MAVI (yonetici: "Yönetici Paneli").
enum HomeAltBaslikStili { tesisSecici, gri, mavi }

/// Referans ana ekranin karsilama blogu: solda "Merhaba, {ad}" (26 bold) +
/// role gore alt satir; sagda hava blogu (gunes ikonu + "24°C" bold + sehir).
/// Bildirim zili ve avatar app-bar satirindadir (HomeShell) — burada DEGIL.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.greetingName,
    required this.subtitle,
    this.altBaslikStili = HomeAltBaslikStili.gri,
    this.hava,
    this.onAltBaslik,
  });

  final String greetingName;
  final String subtitle;
  final HomeAltBaslikStili altBaslikStili;
  final HomeHava? hava;

  /// Tesis secici dokunmasi (gorevli). null → dokunmasiz gorunum.
  final VoidCallback? onAltBaslik;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Merhaba, $greetingName',
                  maxLines: 1,
                  style: HomeText.greeting.copyWith(color: s.heading),
                ),
              ),
              const SizedBox(height: 4),
              _AltBaslik(
                metin: subtitle,
                stil: altBaslikStili,
                onTap: onAltBaslik,
              ),
            ],
          ),
        ),
        if (hava != null) ...[
          const SizedBox(width: 12),
          _HavaBlogu(hava: hava!),
        ],
      ],
    );
  }
}

class _AltBaslik extends StatelessWidget {
  const _AltBaslik({required this.metin, required this.stil, this.onTap});

  final String metin;
  final HomeAltBaslikStili stil;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    final renk = switch (stil) {
      HomeAltBaslikStili.mavi => HomeTokens.primary,
      HomeAltBaslikStili.gri || HomeAltBaslikStili.tesisSecici => s.muted,
    };
    final metinWidget = Text(
      metin,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: HomeText.greetingSub.copyWith(
        color: renk,
        fontWeight: stil == HomeAltBaslikStili.mavi
            ? FontWeight.w600
            : FontWeight.w400,
      ),
    );

    if (stil != HomeAltBaslikStili.tesisSecici) return metinWidget;

    // Tesis secici gorunumu: metin + asagi ok. Secim akisi HENUZ YOK
    // (tek tenant oturumu) — dokunma opsiyoneldir, ok yalniz gorunumdur.
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: metinWidget),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 20, color: s.muted),
        ],
      ),
    );
  }
}

class _HavaBlogu extends StatelessWidget {
  const _HavaBlogu({required this.hava});

  final HomeHava hava;

  @override
  Widget build(BuildContext context) {
    final s = HomeSurface.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          hava.ikon,
          size: 26,
          // Amber yalniz gunes ikonunda; diger hava durumlari notr.
          color: hava.ikon == Icons.wb_sunny_outlined
              ? HomeTokens.orange
              : s.muted,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hava.sicaklik,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)
                  .copyWith(color: s.heading),
            ),
            Text(
              hava.sehir,
              style: HomeText.rowSub.copyWith(color: s.muted),
            ),
          ],
        ),
      ],
    );
  }
}
