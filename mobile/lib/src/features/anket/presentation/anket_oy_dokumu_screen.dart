import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../data/anket_api.dart';
import '../domain/anket_models.dart';

/// (P237 §4) OY DOKUMU — KIM NEYE OY VERDI.
///
/// =========================================================================
/// ANONIM ANKETTE BU EKRAN HIC ACILMAZ
/// =========================================================================
/// Sunucu anonim ankette **409** doner ve donecek veri de YOKTUR: kimlik
/// veritabaninda durmuyor (goc 0137: `ck_anket_oy_anonim_kimliksiz`).
/// Ekran yine de savunmali: dogrudan rota ile gelinirse istek ATILMAZ,
/// aciklama cizilir. Istegi atip 409 hatasini gostermek, kullaniciya
/// "bir sey ters gitti" izlenimi verirdi — oysa ters giden bir sey yok,
/// veri bilerek tutulmuyor.
class AnketOyDokumuScreen extends ConsumerWidget {
  const AnketOyDokumuScreen({super.key, required this.anket});

  final Anket anket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dil = context.dilKodu;

    if (anket.anonim) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.anketOyDokumu)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              key: const Key('anket-dokum-anonim'),
              l10n.anketOyDokumuAnonim,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final dokum = ref.watch(anketOyDokumuProvider(anket.id));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.anketOyDokumu)),
      body: dokum.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // HATA SESSIZ GECILMEZ: bos liste gostermek "kimse oy vermedi"
        // demekti ve bu YANLIS bir bilgi olurdu.
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              key: const Key('anket-dokum-hata'),
              l10n.anketDokumYuklenemedi,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (liste) => liste.isEmpty
            ? Center(
                child: Text(
                  key: const Key('anket-dokum-bos'),
                  l10n.anketOyYok,
                ),
              )
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(anketOyDokumuProvider(anket.id)),
                child: ListView.separated(
                  itemCount: liste.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final o = liste[i];
                    return ListTile(
                      key: Key('anket-oy-${o.userId}'),
                      leading: const Icon(Icons.how_to_vote_outlined),
                      title: Text(o.ad ?? l10n.ortakBilinmiyor),
                      subtitle: Text(tarihSaatBicimi(o.createdAt, dil)),
                      trailing: Text(o.secenekMetin),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

/// `GET /anketler/{id}/oylar` — YALNIZ adli ankette cagrilir.
final anketOyDokumuProvider =
    FutureProvider.autoDispose.family<List<AnketOyKim>, String>(
  (ref, anketId) => ref.watch(anketApiProvider).oyDokumu(anketId),
);
