/// (P253 Asama 2) GECIKME FAIZINI ISLE — web `GecikmeFaiziKarti` karsiligi.
///
/// Once ONIZLEME (ne yazilacak), sonra §C onay diyalogu (adet + toplam),
/// sonra `POST /borclandirma/gecikme-faizi/isle`. Onizleme ile isleme
/// sunucuda AYNI hesabi cagirir. Ayar (uygula / oran) Otomasyon ekraninda.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/finans_onay.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../data/borclandirma_api.dart';
import '../domain/borclandirma_models.dart';

final faizOnizlemeProvider = FutureProvider.autoDispose<FaizOnizleme>(
  (ref) => ref.watch(borclandirmaApiProvider).faizOnizleme(),
);

/// Pencereyi acar; faiz yazildiysa `true`.
Future<bool?> gecikmeFaiziAc(BuildContext context) =>
    merkezSayfaAc<bool>(context, builder: (_) => const GecikmeFaiziPenceresi());

class GecikmeFaiziPenceresi extends ConsumerStatefulWidget {
  const GecikmeFaiziPenceresi({super.key});

  @override
  ConsumerState<GecikmeFaiziPenceresi> createState() => _FaizState();
}

class _FaizState extends ConsumerState<GecikmeFaiziPenceresi> {
  bool _mesgul = false;
  String? _hata;

  Future<void> _isle(FaizOnizleme o) async {
    final l10n = context.l10n;
    final onay = await finansOnayla(
      context,
      baslik: l10n.brcFaiz,
      hedef: l10n.brcFaizOnayHedef(o.adet, o.donem),
      tutar: tlTutar(o.toplamFarkKurus),
      sonuc: l10n.brcFaizOnaySonuc,
      onayMetni: l10n.brcFaizIsle,
    );
    if (onay == null || !mounted) return;
    setState(() => _mesgul = true);
    try {
      final n = await ref.read(borclandirmaApiProvider).faizIsle();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.brcFaizIslendi(n))));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _mesgul = false;
        _hata = e.message.isNotEmpty ? e.message : l10n.ortakBeklenmeyenHata;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onizleme = ref.watch(faizOnizlemeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.brcFaiz, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          onizleme.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              e is ApiException && e.message.isNotEmpty ? e.message : l10n.ortakBeklenmeyenHata,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            data: (o) {
              final metin = !o.uygulaniyor
                  ? l10n.brcFaizKapali
                  : o.adet == 0
                      ? l10n.brcFaizYok
                      : l10n.brcFaizIslenecek(o.adet, tlTutar(o.toplamFarkKurus));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(metin, key: const Key('brc-faiz-ozet')),
                  const SizedBox(height: 16),
                  if (_hata != null) ...[
                    Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: 8),
                  ],
                  FilledButton(
                    key: const Key('brc-faiz-isle'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: _mesgul || !o.uygulaniyor || o.adet == 0 ? null : () => _isle(o),
                    child: Text(l10n.brcFaizIsle),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
