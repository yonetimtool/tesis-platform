/// (P250 §6) Hızlı İşlemler — SEÇ ve SIRALA (en fazla 8), varsayılana dön.
///
/// Seçenekler ROLE göre sunucudan gelir: yetkisi olmayan işlem burada
/// görünmez. Kayıt hesaba gider; web aynı seçimi görür.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../data/hizli_islemler_api.dart';

class HizliIslemlerOzellestirScreen extends ConsumerStatefulWidget {
  const HizliIslemlerOzellestirScreen({super.key});

  @override
  ConsumerState<HizliIslemlerOzellestirScreen> createState() =>
      _HizliIslemlerOzellestirScreenState();
}

class _HizliIslemlerOzellestirScreenState
    extends ConsumerState<HizliIslemlerOzellestirScreen> {
  List<String>? _secim;
  bool _kaydediyor = false;

  Future<void> _yaz(List<String>? secili) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _kaydediyor = true);
    try {
      await ref.read(hizliIslemlerApiProvider).yaz(secili);
      ref.invalidate(hizliIslemlerProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.panoHizliKaydedildi)));
      navigator.pop();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
      if (mounted) setState(() => _kaydediyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final veri = ref.watch(hizliIslemlerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.panoHizliIslemler)),
      body: veri.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.ortakBeklenmeyenHata)),
        data: (v) {
          final secim = _secim ??= [...v.secili];
          final secenekler = [
            for (final k in v.secenekler)
              if (hizliIslemKatalogu[k] != null) k,
          ];
          final secilmeyen = secenekler
              .where((k) => !secim.contains(k))
              .toList();
          final dolu = secim.length >= hizliUstSinir;
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.panoHizliOzellestirAciklama),
              ),
              if (dolu)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(l10n.panoHizliUstSinir),
                ),
              // Seçilenler SEÇİM SIRASIYLA; tutamaktan sürüklenerek sıralanır.
              ReorderableListView(
                key: const Key('hizli-secili-liste'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: (eski, yeni) => setState(() {
                  secim.insert(yeni, secim.removeAt(eski));
                }),
                children: [
                  for (final (i, k) in secim.indexed)
                    CheckboxListTile(
                      key: Key('hizli-secenek-$k'),
                      value: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(hizliIslemKatalogu[k]!.etiket(l10n)),
                      onChanged: (_) => setState(() => secim.remove(k)),
                      secondary: ReorderableDragStartListener(
                        index: i,
                        child: Icon(
                          Icons.drag_handle,
                          semanticLabel: l10n.panoHizliYukari(
                            hizliIslemKatalogu[k]!.etiket(l10n),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(height: 1),
              for (final k in secilmeyen)
                CheckboxListTile(
                  key: Key('hizli-secenek-$k'),
                  value: false,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(hizliIslemKatalogu[k]!.etiket(l10n)),
                  onChanged: dolu ? null : (_) => setState(() => secim.add(k)),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('hizli-varsayilan'),
                  onPressed: _kaydediyor ? null : () => _yaz(null),
                  child: Text(
                    l10n.panoHizliVarsayilan,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('hizli-kaydet'),
                  onPressed: _kaydediyor || _secim == null
                      ? null
                      : () => _yaz(List.of(_secim!)),
                  child: Text(l10n.ortakKaydet),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
