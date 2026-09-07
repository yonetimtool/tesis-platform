import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../data/dukkan_api.dart';
import '../data/dukkan_oturum.dart';

/// (DUKKAN F6-ek) TALEP DETAYI — GELEN TEKLIFLER.
///
/// ===========================================================================
/// OLCULEN KUSUR: OLU BAGLANTI
/// ===========================================================================
/// F4'te `dukkan_taleplerim_screen.dart` her karta
/// `context.push('/dukkan/taleplerim/{id}')` koydu ama O ROTA HIC
/// TANIMLANMADI. Yani mobilde kullanici gelen teklifleri GOREMIYORDU:
/// karta dokununca go_router'in hata ekrani cikiyordu.
///
/// Bildirim isini bagladigimiz bu fazda ortaya cikti: "teklif geldi"
/// bildirimi dogru kisiye gitse bile dokununca varilacak ekran YOKTU.
/// Bildirimi baglayip bu ekrani birakmak, bildirimi ISLEVSIZ kilardi.
///
/// Metin anahtarlari (`dukkanTeklifler`, `dukkanIsiVer`, ...) F4'te
/// yedi dile ZATEN eklenmisti — kullanilan yer yoktu. Yani sozluk
/// dogruydu, ekran eksikti.
class DukkanTalepDetayScreen extends ConsumerStatefulWidget {
  const DukkanTalepDetayScreen({required this.talepId, super.key});

  final String talepId;

  @override
  ConsumerState<DukkanTalepDetayScreen> createState() =>
      _DukkanTalepDetayState();
}

class _DukkanTalepDetayState extends ConsumerState<DukkanTalepDetayScreen> {
  bool _islemde = false;

  Future<void> _isiVer(String teklifId) async {
    setState(() => _islemde = true);
    try {
      final jeton = await ref.read(dukkanOturumProvider).jetonAl();
      await ref.read(dukkanApiProvider).teklifKabul(teklifId, jeton);
      // LISTE TAZELENIYOR: kabul sonrasi digerlerinin durumu da degisir
      // (sunucu onlari kapatiyor). Yerel olarak tek satiri guncellemek,
      // ekranda GERCEK OLMAYAN bir durum birakirdi.
      ref.invalidate(dukkanTeklifleriProvider(widget.talepId));
      ref.invalidate(dukkanTalepDetayProvider(widget.talepId));
      ref.invalidate(dukkanTaleplerimProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).dukkanListeAlinamadi)));
      }
    } finally {
      if (mounted) setState(() => _islemde = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final teklifler = ref.watch(dukkanTeklifleriProvider(widget.talepId));

    return Scaffold(
      appBar: AppBar(title: Text(t.dukkanTeklifler)),
      body: teklifler.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (h, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              h is DukkanOturumHatasi && h.kod == 'telefon_gerekli'
                  ? t.dukkanTelefonGerekli
                  : t.dukkanListeAlinamadi,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.dukkanTeklifYok, textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, n) => _TeklifKarti(
              teklif: items[n],
              islemde: _islemde,
              onIsiVer: () => _isiVer(items[n].id),
            ),
          );
        },
      ),
    );
  }
}

class _TeklifKarti extends StatelessWidget {
  const _TeklifKarti({
    required this.teklif,
    required this.islemde,
    required this.onIsiVer,
  });

  final DukkanTeklif teklif;
  final bool islemde;
  final VoidCallback onIsiVer;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final kabul = teklif.durum == 'kabul';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(teklif.isletmeAd,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            // TUTAR `null` ISE "YERINDE GORSUN" — 0 TL DEGIL. Ikisini
            // ayni gostermek, ucretsiz is teklifi gibi okunurdu.
            Text(
              teklif.tutarKurus == null
                  ? t.dukkanYerindeGorsun
                  : '${(teklif.tutarKurus! / 100).toStringAsFixed(2)} ₺',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (teklif.mesaj != null && teklif.mesaj!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(teklif.mesaj!,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 10),
            if (kabul)
              Text(t.dukkanIsVerildi,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary))
            else
              FilledButton(
                onPressed: islemde ? null : onIsiVer,
                child: Text(t.dukkanIsiVer),
              ),
          ],
        ),
      ),
    );
  }
}
