import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/ui/bos_durum.dart';
import '../../../routing/app_router.dart';
import '../data/panik_api.dart';
import '../domain/panik_models.dart';
import 'panik_sayfasi.dart' show panikTipAdi;

/// (P240 §1) ACIL DURUM CAGRILARI — TAKIP.
///
/// Bu ekran olmadan sistem "bir sey oldu" demekten ibaret kalir:
/// kim bastı, kac kisi gordu, kac saniyede mudahale edildi, kim kapatti.
class PanikTakipScreen extends ConsumerWidget {
  const PanikTakipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final durum = ref.watch(panikListeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.panikTakipBaslik),
        actions: [
          // (P249 §2) TATBIKATLAR — takip ekraninin rolleri (yonetim +
          // guvenlik) raporu okur; yonetim planlar.
          TextButton.icon(
            key: const Key('panik-takip-tatbikat'),
            icon: const Icon(Icons.campaign_outlined),
            label: Text(l10n.tatbikatBaslik),
            onPressed: () => context.push(AppRoutes.tatbikat),
          ),
        ],
      ),
      body: durum.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (liste) {
          if (liste.isEmpty) {
            return BosDurum(
              ikon: Icons.emergency_outlined,
              baslik: l10n.panikAlarmYok,
              aciklama: l10n.panikAlarmYokAlt,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(panikListeProvider),
            child: ListView.separated(
              itemCount: liste.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final a = liste[i];
                final goren = a.alicilar.where((x) => x.goruldu != null).length;
                return ListTile(
                  key: Key('panik-satir-${a.id}'),
                  leading: Icon(
                    Icons.emergency_outlined,
                    color: a.acik ? Theme.of(context).colorScheme.error : null,
                  ),
                  title: Text(panikTipAdi(
                    l10n,
                    PanikTip.values.firstWhere(
                      (t) => t.kimlik == a.tip,
                      orElse: () => PanikTip.guvenlik,
                    ),
                  )),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text([a.olusturanAd ?? '', a.yer]
                          .where((x) => x.isNotEmpty)
                          .join(' · ')),
                      Text(l10n.panikGorenSayisi(goren, a.alicilar.length)),
                      // SURE YOKSA SATIR HIC CIZILMEZ: "0 sn" yazmak,
                      // mudahale edilmemis bir alarmi aninda mudahale
                      // edilmis gibi gosterirdi.
                      if (a.mudahaleSuresiSn != null)
                        Text(l10n.panikMudahaleSuresi(a.mudahaleSuresiSn!)),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: a.acik
                      ? TextButton(
                          key: Key('panik-kapat-${a.id}'),
                          onPressed: () async {
                            await ref.read(panikApiProvider).kapat(a.id);
                            ref.invalidate(panikListeProvider);
                          },
                          child: Text(l10n.panikKapat),
                        )
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
