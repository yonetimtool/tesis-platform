/// (P253 Asama 1) IZIN TALEPLERI — liste, onayla / reddet, sil.
///
/// Web'deki izin listesinin mobil karsiligi; AYNI uclar ve AYNI kurallar:
///   * liste her role acik — amir yalniz kendi ekibini gorur, personel
///     kendi taleplerini (suzme SUNUCUDA);
///   * onay/ret yonetim + amir (`_ONAYLAYAN`); dugme yalniz bekleyen
///     satirda ve yalniz o rollerde cizilir;
///   * silme: yonetim/amir her kaydi, personel YALNIZ kendi BEKLEYEN
///     talebini (onaylanmis izni kendi silmesi, karari geri almak olurdu).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../data/vardiya_plani_api.dart';
import '../domain/vardiya_plani_models.dart';
import 'izin_formu.dart';

/// Suzgec: null = tumu.
final izinSuzgeciProvider =
    NotifierProvider.autoDispose<_IzinSuzgeci, String?>(_IzinSuzgeci.new);

class _IzinSuzgeci extends Notifier<String?> {
  @override
  String? build() => 'onay_bekliyor';

  void sec(String? durum) => state = durum;
}

final izinListesiProvider =
    FutureProvider.autoDispose<List<VardiyaIzin>>((ref) {
  return ref
      .read(vardiyaPlaniApiProvider)
      .izinler(durum: ref.watch(izinSuzgeciProvider));
});

/// "2026-10-05 – 2026-10-07" — noktalama, ceviri degil.
String izinAraligi(VardiyaIzin i) =>
    i.baslangic == i.bitis ? i.baslangic : '${i.baslangic} – ${i.bitis}';

String _durumAdi(AppLocalizations l10n, String durum) => switch (durum) {
      'onay_bekliyor' => l10n.vrdIzinBekleyen,
      'onaylandi' => l10n.vrdIzinOnaylanan,
      'reddedildi' => l10n.vrdIzinReddedilen,
      final d => d,
    };

class IzinTalepleriSayfasi extends ConsumerWidget {
  const IzinTalepleriSayfasi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rol = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    final karar = rol == UserRole.admin ||
        rol == UserRole.yonetici ||
        rol == UserRole.guvenlikAmiri;
    final benim = ref.watch(currentUserIdProvider).value;
    final suzgec = ref.watch(izinSuzgeciProvider);
    final liste = ref.watch(izinListesiProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.vrdIzinTalepleri,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final (kod, ad) in [
                ('onay_bekliyor', l10n.vrdIzinBekleyen),
                ('onaylandi', l10n.vrdIzinOnaylanan),
                ('reddedildi', l10n.vrdIzinReddedilen),
                (null, l10n.vrdIzinTumu),
              ])
                ChoiceChip(
                  key: Key('izin-suzgec-${kod ?? 'tumu'}'),
                  label: Text(ad),
                  selected: suzgec == kod,
                  onSelected: (_) =>
                      ref.read(izinSuzgeciProvider.notifier).sec(kod),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: liste.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(e is ApiException
                  ? apiHataMetni(l10n, e)
                  : l10n.ortakBeklenmeyenHata),
              data: (izinler) => izinler.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.vrdIzinYok),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final i in izinler)
                          _IzinSatiri(
                            izin: i,
                            karar: karar,
                            silebilir: karar ||
                                (i.userId == benim && i.bekliyor),
                          ),
                      ],
                    ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.ortakKapat),
            ),
          ),
        ],
      ),
    );
  }
}

class _IzinSatiri extends ConsumerWidget {
  const _IzinSatiri({
    required this.izin,
    required this.karar,
    required this.silebilir,
  });

  final VardiyaIzin izin;
  final bool karar;
  final bool silebilir;

  Future<void> _calistir(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(VardiyaPlaniApi api) is_,
    String basari,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await is_(ref.read(vardiyaPlaniApiProvider));
      ref.invalidate(izinListesiProvider);
      messenger.showSnackBar(SnackBar(content: Text(basari)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final i = izin;
    return Card(
      key: Key('izin-${i.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(i.kisiAd ?? '-',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text([
              izinTuruAdi(l10n, i.tur),
              izinAraligi(i),
              _durumAdi(l10n, i.durum),
            ].join('  ·  ')),
            if ((i.notMetni ?? '').isNotEmpty)
              Text(i.notMetni!,
                  style: Theme.of(context).textTheme.bodySmall),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                if (karar && i.bekliyor) ...[
                  TextButton(
                    key: Key('izin-reddet-${i.id}'),
                    onPressed: () => _calistir(context, ref,
                        (a) => a.izinReddet(i.id), l10n.vrdIzinReddedildi),
                    child: Text(l10n.vrdIzinReddet),
                  ),
                  FilledButton(
                    key: Key('izin-onayla-${i.id}'),
                    onPressed: () => _calistir(context, ref,
                        (a) => a.izinOnayla(i.id), l10n.vrdIzinOnaylandi),
                    child: Text(l10n.vrdIzinOnayla),
                  ),
                ],
                if (silebilir)
                  IconButton(
                    key: Key('izin-sil-${i.id}'),
                    tooltip: l10n.ortakSil,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (d) => AlertDialog(
                          content: Text(l10n.vrdIzinSilOnay),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(d).pop(false),
                              child: Text(l10n.ortakVazgec),
                            ),
                            FilledButton(
                              key: const Key('izin-sil-onayla'),
                              onPressed: () => Navigator.of(d).pop(true),
                              child: Text(l10n.ortakSil),
                            ),
                          ],
                        ),
                      );
                      if (ok != true || !context.mounted) return;
                      await _calistir(context, ref, (a) => a.izinSil(i.id),
                          l10n.vrdIzinSilindi);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
