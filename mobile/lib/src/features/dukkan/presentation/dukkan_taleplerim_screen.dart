import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../data/dukkan_api.dart';
import 'dukkan_hata_govdesi.dart';
import '../data/dukkan_oturum.dart';

/// (DUKKAN F4) TALEPLERIM — mobil.
///
/// Web'deki listeyle ayni bilgi, dar ekrana uyarlanmis: durum ve teklif
/// sayisi karti SAG UST kosede degil, basligin ALTINDA — telefonda sag
/// kose kaydirma sirasinda bas parmagin altinda kalir ve okunmaz.
class DukkanTaleplerimScreen extends ConsumerWidget {
  const DukkanTaleplerimScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final liste = ref.watch(dukkanTaleplerimProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.dukkanTaleplerim)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dukkan/talep-olustur'),
        icon: const Icon(Icons.add),
        label: Text(t.dukkanYeniTalep),
      ),
      body: liste.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // OTURUM HATASI ILE AG HATASI AYRI: kullanicinin yapacagi sey
        // farkli. Telefonu olmayan kullanici (olculdu: %27) tekrar
        // denemekle sonuca ulasmaz — ONA TELEFON DOGRULAMA sunulur
        // (F7 §2; once yalnizca "web'e gidin" deniyordu).
        error: (h, _) => DukkanHataGovdesi(
          hata: h,
          onYenile: () => ref.invalidate(dukkanTaleplerimProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.dukkanTalepYok, textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, n) {
              final x = items[n];
              return Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  onTap: () => context.push('/dukkan/taleplerim/${x.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(x.baslik?.isNotEmpty == true ? x.baslik! : x.kategori,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        // DURUM VE TEKLIF SAYISI BASLIGIN ALTINDA:
                        // telefonda sag kose bas parmagin altinda kalir.
                        Wrap(
                          spacing: 8,
                          children: [
                            Text('${x.mahalle} · ${x.ilce}',
                                style: Theme.of(context).textTheme.bodySmall),
                            if (x.teklifSayisi > 0)
                              Text('${x.teklifSayisi} ${t.dukkanTeklifler}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(x.aciklama,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
