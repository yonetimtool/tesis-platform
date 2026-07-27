import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../call/data/call_launcher.dart';
import '../../call/domain/tel_uri.dart';
import '../data/yonetici_iletisim_api.dart';
import '../domain/yonetici_iletisim_models.dart';

/// Yonetici iletisim dizini: tenant'in tum yoneticileri (birincil ilk) +
/// yonetim maili. Numara sunucudan acikca gelir (auth.md gizlilik istisnasi);
/// arama mevcut CallLauncher ile yapilir — tel: mantigi kopyalanmaz.
class YoneticiIletisimScreen extends ConsumerWidget {
  const YoneticiIletisimScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(yoneticiIletisimProvider);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.yonIletisimBaslik, context.dilKodu)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.yonIletisimAlinamadi)),
        data: (d) {
          if (d.yoneticiler.isEmpty && (d.yonetimEmail ?? '').isEmpty) {
            return Center(child: Text(l10n.yonIletisimTanimliDegil));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final k in d.yoneticiler) YoneticiKartTile(kart: k),
              if ((d.yonetimEmail ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.mail_outline),
                    title: Text(l10n.yonIletisimMail),
                    subtitle: Text(d.yonetimEmail!),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Tek yonetici karti — testte dogrudan pump edilebilsin diye ayri widget.
class YoneticiKartTile extends ConsumerWidget {
  const YoneticiKartTile({super.key, required this.kart});

  final YoneticiKart kart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = (kart.telefon == null) ? null : telUri(kart.telefon!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kart.adSoyad, style: Theme.of(context).textTheme.titleMedium),
            if (kart.telefon != null) ...[
              const SizedBox(height: 4),
              Text(kart.telefon!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (uri != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final ok =
                      await ref.read(callLauncherProvider).dial(uri.toString());
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(context.l10n.aramaBaslatilamadi)),
                    );
                  }
                },
                icon: const Icon(Icons.phone),
                label: Text(context.l10n.yonIletisimAra),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
