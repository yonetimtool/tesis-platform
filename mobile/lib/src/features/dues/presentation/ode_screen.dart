import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../data/odeme_api.dart';
import 'my_dues_controller.dart';

/// "Öde" (P30) — sakinin odeme ekrani.
///
/// TASARIM: "çok kolay" olmasi istendi. Ekran TEK SAYFADIR ve iki yolu
/// yan yana degil ALT ALTA gosterir: sekmeler kullanici bir yolu secmeden
/// once "hangisi bana lazim" diye dusundururdu; alt alta liste, havale
/// bilgisi hep gorunur birakir.
///
/// HAVALE YOLU sitenin banka kasasi tanimli DEGILSE hic cizilmez — yanlis
/// ya da bos IBAN gostermektense secenegi hic sunmamak dogru.
class OdeScreen extends ConsumerWidget {
  const OdeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(odemeBilgileriProvider);
    return Scaffold(
      appBar: AppBar(title: Text(baslikBuyuk(l10n.odeBaslik, context.dilKodu))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: Text(
              akisHatasiCoz(
                    l10n,
                    e is ApiException ? e.agHatasi : AkisHatasi.beklenmeyen,
                    e is ApiException ? e.message : null,
                  ) ??
                  l10n.ortakBeklenmeyenHata,
              textAlign: TextAlign.center,
            )),
          ],
        ),
        data: (bilgi) => _Govde(bilgi: bilgi),
      ),
    );
  }
}

class _Govde extends ConsumerWidget {
  const _Govde({required this.bilgi});

  final OdemeBilgileri bilgi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          child: ListTile(
            title: Text(l10n.odeBorcunuz),
            subtitle: Text(
              bilgi.borcKurus > 0
                  ? tlIsaretli(bilgi.borcKurus, dil)
                  : l10n.odeBorcYok,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ---------------------------- HAVALE ----------------------------- #
        Text(l10n.odeHavaleBaslik,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (bilgi.iban == null)
          Text(l10n.odeHavaleKapali)
        else ...[
          Text(l10n.odeHavaleAdim),
          const SizedBox(height: 10),
          _KopyalanabilirSatir(
            baslik: bilgi.bankaAdi ?? 'IBAN',
            deger: bilgi.iban!,
          ),
          const SizedBox(height: 8),
          _KopyalanabilirSatir(
            baslik: l10n.odeKodBaslik,
            deger: bilgi.odemeKodu,
            vurgulu: true,
          ),
        ],

        const SizedBox(height: 24),
        // ----------------------------- KART ------------------------------ #
        Text(l10n.odeKartBaslik,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        if (!bilgi.kartAktif)
          Text(l10n.odeKartKapali)
        else
          FilledButton(
            onPressed: bilgi.borcKurus <= 0
                ? null
                : () => _kartOde(context, ref, bilgi.borcKurus),
            child: Text(
              '${l10n.odeKartBaslik} — ${tlIsaretli(bilgi.borcKurus, dil)}',
            ),
          ),
      ],
    );
  }

  Future<void> _kartOde(BuildContext context, WidgetRef ref, int tutar) async {
    final l10n = context.l10n;
    final mesajci = ScaffoldMessenger.of(context);
    try {
      final sonuc = await ref.read(odemeApiProvider).kartOde(tutar);
      if (sonuc.basarili) {
        mesajci.showSnackBar(SnackBar(content: Text(l10n.odeBasarili)));
        // Borc ve aidat ekrani ANINDA tazelenir: kullanici odedikten sonra
        // eski tutari gormemeli.
        ref.invalidate(odemeBilgileriProvider);
        ref.invalidate(myDuesControllerProvider);
      }
    } on ApiException catch (e) {
      mesajci.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Deger + "Kopyala" — IBAN ve kod ELLE yazilmayacak kadar uzundur.
class _KopyalanabilirSatir extends StatelessWidget {
  const _KopyalanabilirSatir({
    required this.baslik,
    required this.deger,
    this.vurgulu = false,
  });

  final String baslik;
  final String deger;
  final bool vurgulu;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: ListTile(
        title: Text(baslik),
        subtitle: SelectableText(
          deger,
          style: TextStyle(
            fontSize: vurgulu ? 20 : 16,
            fontWeight: vurgulu ? FontWeight.w700 : FontWeight.w500,
            // Tek aralikli yazi tipi: IBAN ve kod okunurken hane hane
            // takip edilir.
            fontFamily: 'monospace',
          ),
        ),
        trailing: TextButton.icon(
          // 48 dp dokunma hedefi (bes eksenli surus kurali).
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: const Icon(Icons.copy),
          label: Text(l10n.odeKopyala),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: deger));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.odeKopyalandi)),
            );
          },
        ),
      ),
    );
  }
}
