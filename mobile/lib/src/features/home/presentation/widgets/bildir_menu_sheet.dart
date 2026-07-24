import 'package:flutter/material.dart';

import '../../../../core/branding/yonetio_logo.dart';

/// FAB olusturma menusunun tek girisi (WP2.4). [route] null + [comingSoon]
/// true ise pasif "yakında" satiri cizilir.
class BildirGiris {
  const BildirGiris({
    required this.icon,
    required this.label,
    this.route,
    this.comingSoon = false,
  });

  final IconData icon;
  final String label;
  final String? route;
  final bool comingSoon;
}

/// Merkez + FAB'in acdigi rol-bazli olusturma menusu (referans bottom sheet).
/// Rota cozumu cagirana birakilir: secim [onSec] ile doner.
Future<void> showBildirMenu(
  BuildContext context, {
  required List<BildirGiris> girisler,
  required ValueChanged<String> onSec,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final g in girisler)
            ListTile(
              enabled: !g.comingSoon,
              leading: CircleAvatar(
                backgroundColor: (g.comingSoon
                        ? Theme.of(ctx).disabledColor
                        : YonetioColors.navy)
                    .withValues(alpha: 0.12),
                child: Icon(g.icon,
                    size: 20,
                    color: g.comingSoon
                        ? Theme.of(ctx).disabledColor
                        : YonetioColors.navy),
              ),
              title: Text(g.label),
              trailing: g.comingSoon
                  ? Text('Yakında',
                      style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                          color: Theme.of(ctx).disabledColor))
                  : const Icon(Icons.chevron_right, size: 18),
              onTap: g.comingSoon || g.route == null
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      onSec(g.route!);
                    },
            ),
        ],
      ),
    ),
  );
}
