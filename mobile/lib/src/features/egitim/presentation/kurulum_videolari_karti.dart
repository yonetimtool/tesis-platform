/// (P250 §4) Ana sayfadaki "Kurulum videoları" kartı — web kartının ikizi.
///
/// İlerleme göstergesiyle ("3/8 izlendi"). Kurulum tamamlanınca KÜÇÜLÜR
/// ama KAYBOLMAZ: devralan yeni yönetici de videolara buradan ulaşır.
/// Hiç video yoksa, liste yüklenemediyse ya da yükleniyorsa ÇİZİLMEZ —
/// ana ekran bu karta rehin değil.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/l10n.dart';
import '../../../routing/app_router.dart';
import '../data/egitim_api.dart';

class KurulumVideolariKarti extends ConsumerWidget {
  const KurulumVideolariKarti({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(egitimListesiProvider).value;
    if (l == null || l.toplam == 0) return const SizedBox.shrink();
    final l10n = context.l10n;
    final kucuk = l.kurulumTamam;
    return Card(
      key: const Key('kurulum-videolari-karti'),
      margin: EdgeInsets.zero,
      child: ListTile(
        dense: kucuk,
        leading: const Icon(Icons.play_circle_outline),
        title: Text(l10n.egitimVideolariBaslik),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.egitimIlerleme('${l.izlenen}', '${l.toplam}')),
            if (!kucuk) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: l.toplam == 0 ? 0 : l.izlenen / l.toplam,
                semanticsLabel: l10n.egitimVideolariBaslik,
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(AppRoutes.kurulumVideolari),
      ),
    );
  }
}
