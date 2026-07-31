import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../data/anket_api.dart';
import '../domain/anket_models.dart';

/// Anket ekrani (P38) — SAKININ oy verdigi yer.
///
/// MINIMAL BILEREK: anket olusturma/kapatma YONETIM isidir ve panele
/// aittir; mobilde yalnizca "gor ve oy ver" vardir. Oy DEGISTIRILEMEZ, bu
/// yuzden oy verilmis bir ankette oy butonlari HIC CIZILMEZ — sunucu 409
/// dondurup kullaniciya hata gostermek yerine, yapilamayacak seyi hic
/// teklif etmiyoruz.
class AnketScreen extends ConsumerWidget {
  const AnketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final anketler = ref.watch(anketlerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.anketBaslik)),
      body: anketler.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', textAlign: TextAlign.center),
          ),
        ),
        data: (liste) => liste.isEmpty
            ? Center(child: Text(l10n.anketYok))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(anketlerProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: liste.length,
                  itemBuilder: (_, i) => _AnketKarti(anket: liste[i]),
                ),
              ),
      ),
    );
  }
}

class _AnketKarti extends ConsumerStatefulWidget {
  const _AnketKarti({required this.anket});

  final Anket anket;

  @override
  ConsumerState<_AnketKarti> createState() => _AnketKartiState();
}

class _AnketKartiState extends ConsumerState<_AnketKarti> {
  bool _gonderiliyor = false;

  Future<void> _oyVer(String secenekId) async {
    if (_gonderiliyor) return;
    setState(() => _gonderiliyor = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(anketApiProvider).oyVer(widget.anket.id, secenekId);
      ref.invalidate(anketlerProvider);
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.anketOyHatasi('$e'))));
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = widget.anket;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(a.baslik,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (!a.acik)
                  Chip(
                    label: Text(l10n.anketKapali),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (a.aciklama != null) ...[
              const SizedBox(height: 4),
              Text(a.aciklama!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            for (final s in a.secenekler)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(s.metin)),
                    // Sonuc YALNIZ sunucu verdiyse cizilir: acik ankette
                    // sayi hic gelmez (surusel etki).
                    if (s.oy != null)
                      Text('${s.oy}',
                          style: const TextStyle(
                              fontFeatures: [FontFeature.tabularFigures()])),
                    if (a.oyVerilebilir) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _gonderiliyor ? null : () => _oyVer(s.id),
                        child: Text(l10n.anketOyVer),
                      ),
                    ],
                  ],
                ),
              ),
            if (a.oyVerdim == true)
              Text(l10n.anketOyVerdiniz,
                  style: Theme.of(context).textTheme.bodySmall),
            if (a.acik && !a.sonucVar)
              Text(l10n.anketSonucKapali,
                  style: Theme.of(context).textTheme.bodySmall),
            if (a.sonucVar)
              Text(l10n.anketToplamOy(a.toplamOy!),
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
