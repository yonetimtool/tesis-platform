import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/bos_durum.dart';
import '../data/gurultu_api.dart';

/// (E2E 2026-09, MOBIL-10) GURULTU UYARILARI — web sayfasinin ikizi:
/// tarih, daire, sayac/esik, durum ve bekleyende "Anons yapildi".
class GurultuUyarilariScreen extends ConsumerStatefulWidget {
  const GurultuUyarilariScreen({super.key});

  @override
  ConsumerState<GurultuUyarilariScreen> createState() =>
      _GurultuUyarilariScreenState();
}

class _GurultuUyarilariScreenState
    extends ConsumerState<GurultuUyarilariScreen> {
  final Set<String> _isleniyor = {};

  Future<void> _yapildi(GurultuUyarisi u) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isleniyor.add(u.id));
    try {
      await ref.read(gurultuApiProvider).yapildi(u.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.gurultuIsaretlendi)));
      ref.invalidate(gurultuUyarilariProvider);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    } finally {
      if (mounted) setState(() => _isleniyor.remove(u.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(gurultuUyarilariProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.modulGurultuUyarilari, context.dilKodu)),
        actions: [
          IconButton(
            tooltip: l10n.ortakYenile,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(gurultuUyarilariProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(gurultuUyarilariProvider.future),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              BosDurum(
                ikon: Icons.error_outline,
                baslik: l10n.gurultuAlinamadi,
                aciklama: e is ApiException ? apiHataMetni(l10n, e) : null,
              ),
            ],
          ),
          data: (liste) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                l10n.gurultuAciklama,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (liste.isEmpty)
                BosDurum(
                  ikon: Icons.volume_off_outlined,
                  baslik: l10n.gurultuYok,
                  aciklama: l10n.gurultuYokAlt,
                )
              else
                for (final u in liste)
                  Card(
                    key: Key('gurultu-${u.id}'),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(u.unitNo ?? l10n.gurultuDaireYok),
                      subtitle: Text(
                        '${tarihSaatBicimi(u.createdAt.toLocal(), context.dilKodu)}'
                        '\n${l10n.gurultuSayac(u.sayac, u.esik)}'
                        ' · ${gurultuDurumMetni(l10n, u.durum)}',
                      ),
                      isThreeLine: true,
                      trailing: u.isaretlenebilir
                          ? TextButton(
                              key: Key('gurultu-yapildi-${u.id}'),
                              onPressed: _isleniyor.contains(u.id)
                                  ? null
                                  : () => _yapildi(u),
                              child: Text(l10n.gurultuDurumYapildi),
                            )
                          : null,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sunucu durum kodu -> aktif dildeki etiket (web `yonUyariDurum_*`).
/// Bilinmeyen kod HAM gosterilir: yeni bir durum eklendiginde satir bos
/// kalmasin.
String gurultuDurumMetni(AppLocalizations l10n, String durum) =>
    switch (durum) {
      'gonderildi' => l10n.gurultuDurumGonderildi,
      'basarisiz' => l10n.gurultuDurumBasarisiz,
      'manuel_bekliyor' => l10n.gurultuDurumBekliyor,
      'manuel_yapildi' => l10n.gurultuDurumYapildi,
      _ => durum,
    };
