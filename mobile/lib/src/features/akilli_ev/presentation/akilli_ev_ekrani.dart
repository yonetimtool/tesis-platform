import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/ui/bos_durum.dart';
import '../data/akilli_ev_api.dart';
import '../domain/akilli_ev_models.dart';

/// (P240 §3) AKILLI EV — mobil.
///
/// =========================================================================
/// SAKININ YUZEYI BURASI
/// =========================================================================
/// Web paneli YONETIM yuzeyidir (merkez tanimlama, cihaz esleme,
/// senaryo). Sakin kendi dairesinin cihazlarini MOBILDEN yonetir; P129
/// kurali geregi `app.*`ta hicbir sayfa gormez. Ayrilan sey YETKI degil
/// YUZEY — sunucu ikisine de izin verir.
///
/// LISTE SUNUCUDAN SUZULMUS GELIR: bu ekran hicbir daire filtresi
/// uygulamaz (bkz. `AkilliEvApi`).
///
/// KAPALI BOLUM = GORUNMEZ: yonetim kapattigi bir bolumun cihazlarini
/// sakin de gormez; yoklukta hepsi kapalidir.
class AkilliEvEkrani extends ConsumerWidget {
  const AkilliEvEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cihazlar = ref.watch(akilliEvCihazlarProvider);
    final bolumler = ref.watch(akilliEvBolumlerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.akilliEvBaslik)),
      body: cihazlar.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (liste) {
          final acikBolumler = (bolumler.asData?.value ?? const <AkilliEvBolum>[])
              .where((b) => b.acik)
              .map((b) => b.bolum)
              .toSet();
          final gorunen = liste
              .where((c) => acikBolumler.contains(akilliEvBolumu(c.tip)))
              .toList();
          if (gorunen.isEmpty) {
            return BosDurum(
              ikon: Icons.home_outlined,
              baslik: l10n.akilliEvCihazYok,
              aciklama: l10n.akilliEvKapaliAciklama,
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(akilliEvCihazlarProvider);
              ref.invalidate(akilliEvBolumlerProvider);
            },
            child: ListView.separated(
              itemCount: gorunen.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _CihazKarti(c: gorunen[i]),
            ),
          );
        },
      ),
    );
  }
}

/// Cihaz TIPI -> hangi BOLUMUN altinda sayilir.
///
/// Eslesme KODDA: bolum anahtarlari yoneticinin actigi/kapattigi
/// seylerdir, cihaz tipleri ise protokolun verisi. Ikisini veride
/// birlestirmek, her yeni tipte veri gocu gerektirirdi.
String akilliEvBolumu(String tip) => switch (tip) {
      'isik' || 'priz' => 'aydinlatma',
      'termostat' => 'iklim',
      'kilit' => 'kilit',
      'perde' => 'perde',
      'sensor_su' || 'vana' => 'kacak',
      'sensor_duman' || 'sensor_gaz' => 'yangin',
      'sayac' => 'sayac',
      _ => 'enerji',
    };

String akilliEvTipAdi(AppLocalizations l10n, String tip) => switch (tip) {
      'isik' => l10n.akilliEvTipIsik,
      'priz' => l10n.akilliEvTipPriz,
      'kilit' => l10n.akilliEvTipKilit,
      'termostat' => l10n.akilliEvTipTermostat,
      'perde' => l10n.akilliEvTipPerde,
      'vana' => l10n.akilliEvTipVana,
      'sensor_su' => l10n.akilliEvTipSensorSu,
      'sensor_duman' => l10n.akilliEvTipSensorDuman,
      'sensor_gaz' => l10n.akilliEvTipSensorGaz,
      'sensor_hareket' => l10n.akilliEvTipSensorHareket,
      'sayac' => l10n.akilliEvTipSayac,
      _ => l10n.akilliEvTipDiger,
    };

String akilliEvEylemAdi(AppLocalizations l10n, String eylem) => switch (eylem) {
      'ac' => l10n.akilliEvEylemAc,
      'kapat' => l10n.akilliEvEylemKapat,
      'kilit_ac' => l10n.akilliEvEylemKilitAc,
      _ => l10n.akilliEvEylemVanaKapat,
    };

class _CihazKarti extends ConsumerStatefulWidget {
  const _CihazKarti({required this.c});

  final AkilliEvCihaz c;

  @override
  ConsumerState<_CihazKarti> createState() => _CihazKartiState();
}

class _CihazKartiState extends ConsumerState<_CihazKarti> {
  bool _bekliyor = false;

  Future<void> _gonder(String eylem) async {
    final l10n = context.l10n;
    setState(() => _bekliyor = true);
    try {
      await ref.read(akilliEvApiProvider).komut(widget.c.id, eylem);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.akilliEvKomutGonderildi)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _bekliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = widget.c;
    return ListTile(
      key: ValueKey('akilli-ev-cihaz-${c.id}'),
      leading: const Icon(Icons.home_outlined),
      title: Text(c.ad),
      subtitle: Text(
        '${akilliEvTipAdi(l10n, c.tip)} · ${c.daireNo ?? c.alan ?? l10n.akilliEvOrtakAlan}',
      ),
      // SENSORDE HIC DUGME YOK: `eylemler` bos gelir, satir salt okuma
      // kalir. Basinca 422 alacak bir dugme cizmek yaniltici olurdu.
      trailing: c.eylemler.isEmpty
          ? null
          : Wrap(
              spacing: 4,
              children: [
                for (final e in c.eylemler)
                  TextButton(
                    key: ValueKey('akilli-ev-komut-${c.id}-$e'),
                    onPressed: _bekliyor ? null : () => _gonder(e),
                    child: Text(akilliEvEylemAdi(l10n, e)),
                  ),
              ],
            ),
    );
  }
}
