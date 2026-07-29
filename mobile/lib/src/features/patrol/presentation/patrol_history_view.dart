import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../domain/patrol_models.dart';
import 'devriye_hata_metni.dart';
import 'patrol_history_controller.dart';

/// Pencere gecmisi gorunumu (`GET /patrol-windows` — ozet + son pencereler).
/// Iki ekranda paylasilir: Turlarim "Gecmis" sekmesi (saha) ve yonetici
/// "Devriye takibi" ekrani. Veri: [patrolHistoryControllerProvider].
class PatrolHistoryView extends ConsumerWidget {
  const PatrolHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(patrolHistoryControllerProvider);
    final controller = ref.read(patrolHistoryControllerProvider.notifier);

    if (state.loading && state.items.isEmpty && state.errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (state.errorMessage != null || state.hataKimligi != null)
            PatrolErrorBanner(
              message: state.forbidden
                  ? l10n.devriyeGecmisYetkiYok
                  : devriyeHatasiCoz(
                          l10n, state.hataKimligi, state.errorMessage) ??
                      '',
              onRetry: state.forbidden ? null : controller.refresh,
            ),
          if (state.items.isNotEmpty) ...[
            PatrolHistorySummary(ozet: state.ozet),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < state.items.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    PatrolHistoryTile(item: state.items[i]),
                  ],
                ],
              ),
            ),
          ] else if (state.errorMessage == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.devriyeGecmisBos,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PatrolHistorySummary extends StatelessWidget {
  const PatrolHistorySummary({super.key, required this.ozet});

  final PatrolWindowOzet ozet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget chip(String label, int value, Color color) => Chip(
          avatar: CircleAvatar(backgroundColor: color, radius: 6),
          label: Text('$label $value'),
          visualDensity: VisualDensity.compact,
        );
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        chip(l10n.devriyeOzetToplam, ozet.toplam, Colors.blueGrey),
        chip(l10n.devriyeDurumTamamlandi, ozet.tamamlandi, Colors.green),
        chip(l10n.devriyeDurumKacirildi, ozet.kacirildi, Colors.red),
        chip(l10n.devriyeDurumBekliyor, ozet.bekliyor, Colors.orange),
      ],
    );
  }
}

class PatrolHistoryTile extends StatelessWidget {
  const PatrolHistoryTile({super.key, required this.item});

  final PatrolWindowHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final (icon, color, label) = switch (item.durum) {
      PatrolWindowDurum.tamamlandi => (
          Icons.check_circle,
          Colors.green,
          l10n.devriyeDurumTamamlandi,
        ),
      PatrolWindowDurum.kacirildi =>
        (Icons.cancel, Colors.red, l10n.devriyeDurumKacirildi),
      PatrolWindowDurum.bekliyor => (
          Icons.hourglass_top,
          Colors.orange,
          l10n.devriyeDurumBekliyor,
        ),
      PatrolWindowDurum.bilinmiyor => (
          Icons.help_outline,
          Colors.grey,
          l10n.devriyeDurumBilinmiyor,
        ),
    };
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(item.planAdi ?? l10n.devriyeTuru),
      subtitle: Text(
        '${tarihBicimi(item.pencereBaslangic, dil)} · '
        '${saatBicimi(item.pencereBaslangic, dil)} – '
        '${saatBicimi(item.pencereBitis, dil)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: TextStyle(color: color)),
          Text(
            '${item.okutulanCheckpointSayisi}/${item.beklenenCheckpointSayisi}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Hata banner'i — retry butonlu (patrol ekranlarinin ortak parcasi).
class PatrolErrorBanner extends StatelessWidget {
  const PatrolErrorBanner({super.key, required this.message, this.onRetry});

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    // CANLI BOLGE (tur 56): bant ekrana SONRADAN gelir; `liveRegion` olmadan
    // ekran okuyucu yeni metni DUYURMAZ — gormeyen kullanici hata olustugunu
    // ancak elle gezinirse anlar. (Flutter'in `SnackBar`i bunu zaten yapiyor;
    // eksik olan STATIK bantlardi.)
    return Semantics(
      liveRegion: true,
      child: _govde(context),
    );
  }

  Widget _govde(BuildContext context) {
    return Card(
      color: Colors.red.withValues(alpha: 0.08),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.red)),
            ),
            if (onRetry != null)
              // 320 dp'de Almanca "Erneut versuchen" satiri 18 px tasiriyordu
              // (tur 42 — hata bandi ilk kez surulunce gorundu).
              Flexible(
                child: TextButton(
                  onPressed: () => onRetry!(),
                  child: Text(
                    context.l10n.ortakYenidenDene,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _two(int v) => v.toString().padLeft(2, '0');

/// Kalan sure metni — birim KISALTMALARI dile gore (ARB: sure*).
/// Sayilar LTR izole edilmez: cevre metin zaten sayi+birim ciftidir.
String sureMetni(AppLocalizations l10n, Duration d) {
  if (d.inHours >= 1) {
    return l10n.sureSaatDakika('${d.inHours}', _two(d.inMinutes % 60));
  }
  if (d.inMinutes >= 1) {
    return l10n.sureDakikaSaniye('${d.inMinutes}', _two(d.inSeconds % 60));
  }
  return l10n.sureSaniye('${d.inSeconds}');
}
