/// (P253 Asama 1) OTOMASYON GUNLUGU + HATIRLATMA GECMISI — salt okuma.
///
/// Web `/finans/otomasyon` sayfasinin iki karti (`GunlukKarti`,
/// `HatirlatmaGecmisiKarti`). Mobilde Otomasyon ekraninin ust cubugundan
/// acilir. Ayni iki uc: `/otomasyon-gunlugu`, `/finans/hatirlatma-gecmisi`.
///
/// Bu liste olmadan "gorev calisti ama hicbir sey uretmedi" durumu — ki
/// asil merak edilen odur — telefonda gorunmez kalirdi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../data/finans_api.dart';
import '../domain/finans_models.dart';

final otomasyonGunluguProvider =
    FutureProvider.autoDispose<List<OtomasyonGunlukSatiri>>(
  (ref) => ref.watch(finansApiProvider).otomasyonGunlugu(),
);

final hatirlatmaGecmisiProvider = FutureProvider.autoDispose<HatirlatmaGecmisi>(
  (ref) => ref.watch(finansApiProvider).hatirlatmaGecmisi(),
);

String otomasyonTurAdi(AppLocalizations l10n, String tur) => switch (tur) {
      'aidat_tahakkuk' => l10n.finOtoTurAidatTahakkuk,
      'aidat_onizleme' => l10n.finOtoTurAidatOnizleme,
      'borc_hatirlatma' => l10n.finOtoTurBorcHatirlatma,
      'duzenli_gider' => l10n.finOtoTurDuzenliGider,
      'gecikme_faizi' => l10n.finOtoTurGecikmeFaizi,
      'aylik_ozet' => l10n.finOtoTurAylikOzet,
      'maas' => l10n.finOtoTurMaas,
      _ => tur,
    };

class OtomasyonGunluguScreen extends ConsumerWidget {
  const OtomasyonGunluguScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final gunluk = ref.watch(otomasyonGunluguProvider);
    final gecmis = ref.watch(hatirlatmaGecmisiProvider);
    String hata(Object e) =>
        e is ApiException ? apiHataMetni(l10n, e) : l10n.ortakBeklenmeyenHata;
    final baslikStili = Theme.of(context).textTheme.titleMedium;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(baslikBuyuk(l10n.finOtoGunlukBaslik, dil)),
          bottom: TabBar(tabs: [
            Tab(text: l10n.finOtoGunlukSekme),
            Tab(text: l10n.finHatirlatmaGecmisiSekme),
          ]),
        ),
        body: TabBarView(children: [
          RefreshIndicator(
            onRefresh: () async => ref.invalidate(otomasyonGunluguProvider),
            child: gunluk.when(
              data: (satirlar) => ListView(
                key: const Key('fin-oto-gunluk'),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(l10n.finOtoGunlukAciklama, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  if (satirlar.isEmpty) Text(l10n.finOtoKayitYok),
                  for (final g in satirlar)
                    Card(
                      child: ListTile(
                        title: Text(otomasyonTurAdi(l10n, g.tur)),
                        subtitle: Text([
                          tarihSaatBicimi(g.calismaZamani, dil),
                          if (g.donem != null) g.donem!,
                          l10n.finOtoAdet(g.adet),
                        ].join(' · ')),
                        trailing: Text(tlTutar(g.tutarKurus)),
                      ),
                    ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(children: [
                Padding(padding: const EdgeInsets.all(24), child: Text(hata(e))),
              ]),
            ),
          ),
          RefreshIndicator(
            onRefresh: () async => ref.invalidate(hatirlatmaGecmisiProvider),
            child: gecmis.when(
              data: (g) => ListView(
                key: const Key('fin-hatirlatma-gecmisi'),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(l10n.finHatirlatmaOzet(g.gonderilen, g.okunan), style: baslikStili),
                  const SizedBox(height: 8),
                  if (g.satirlar.isEmpty) Text(l10n.finOtoKayitYok),
                  for (final s in g.satirlar)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        s.okundu ? Icons.mark_email_read_outlined : Icons.mail_outline,
                      ),
                      title: Text(s.ad ?? '—'),
                      subtitle: Text([
                        tarihSaatBicimi(s.zaman, dil),
                        s.okundu ? l10n.finOkundu : l10n.finOkunmadi,
                      ].join(' · ')),
                      trailing: s.tutar == null ? null : Text(s.tutar!),
                    ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(children: [
                Padding(padding: const EdgeInsets.all(24), child: Text(hata(e))),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
