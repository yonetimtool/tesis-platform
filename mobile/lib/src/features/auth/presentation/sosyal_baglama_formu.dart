import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/ui/telefon_alani.dart';
import '../../../core/ui/telefon_hata_metni.dart';
import 'auth_controller.dart';
import 'giris_hata_metni.dart';
import 'sosyal_giris.dart';

/// (P154 / Asama 4) SOSYAL HESAP ESLESTIRME FORMU.
///
/// BRIEF'IN MERKEZ KURALI BURADA GORUNUR HALE GELIR: "sosyal hesap kimlik
/// dogrulama YONTEMIDIR, eslesme anahtari degil". Saglayici "bu Google
/// hesabinin sahibisin" der; hangi tesiste kim oldugunu SOYLEMEZ. Onu
/// tesis ID + telefon soyler, SMS kanitlar.
///
/// AYRI BIR ROTA DEGIL, GIRIS EKRANININ BIR MODU: akis giristen ayrilmaz
/// ve geri tusuyla yarim kalmis bir "kimligi dogrulanmis ama eslesmemis"
/// duruma dusulmez. `oauthIptal()` durumu temizler.
class SosyalBaglamaFormu extends ConsumerStatefulWidget {
  const SosyalBaglamaFormu({super.key});

  @override
  ConsumerState<SosyalBaglamaFormu> createState() => _SosyalBaglamaFormuState();
}

class _SosyalBaglamaFormuState extends ConsumerState<SosyalBaglamaFormu> {
  final _formKey = GlobalKey<FormState>();
  final _tesisCtrl = TextEditingController();
  final _telefonCtrl = TextEditingController();
  final _kodCtrl = TextEditingController();
  String _tesisAd = '';
  String _telefonMaskeli = '';

  @override
  void dispose() {
    _tesisCtrl.dispose();
    _telefonCtrl.dispose();
    _kodCtrl.dispose();
    super.dispose();
  }

  Future<void> _kodIste() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final r = await ref.read(authControllerProvider.notifier).oauthBaglanBasla(
          tesisKodu: _tesisCtrl.text.trim(),
          telefon: telefonNormalle(_telefonCtrl.text),
        );
    if (r == null || !mounted) return;
    setState(() {
      _tesisAd = r.tesisAd;
      _telefonMaskeli = r.telefonMaskeli;
    });
  }

  Future<void> _dogrula() {
    return ref.read(authControllerProvider.notifier).oauthBaglanDogrula(
          telefon: telefonNormalle(_telefonCtrl.text),
          kod: _kodCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ref.watch(authControllerProvider);
    final submitting = auth.submitting;
    final hata = girisHatasiCoz(l10n, auth.hataKimligi, auth.errorMessage);
    final saglayici =
        kSaglayiciEtiketi[auth.oauthSaglayici] ?? (auth.oauthSaglayici ?? '');

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.sosyalBaslik,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.sosyalEslesmeAciklama(saglayici),
              style: Theme.of(context).textTheme.bodySmall),
          // APPLE PRIVATE RELAY: kullaniciya SOYLENIR — o adrese posta
          // gonderilemeyecegini bilmeli.
          if (auth.oauthRelay) ...[
            const SizedBox(height: 8),
            Text(l10n.sosyalRelayUyari,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          if (!auth.kodBekleniyor) ...[
            TextFormField(
              key: const Key('sosyal-tesis-kodu'),
              controller: _tesisCtrl,
              enabled: !submitting,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.sosyalTesisKodu,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.ortakZorunluAlan(l10n.sosyalTesisKodu)
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('sosyal-telefon'),
              controller: _telefonCtrl,
              enabled: !submitting,
              keyboardType: TextInputType.phone,
              // (P123) TEK bicimlendirici — giris ekraninin aynisi.
              inputFormatters: const [TelefonBicimlendirici()],
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.ortakCepTelefonu,
                hintText: l10n.ortakTelefonIpucu,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => telefonHataMetni(l10n, v ?? ''),
            ),
          ] else ...[
            Text(l10n.sosyalKodAciklama(_tesisAd, _telefonMaskeli),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('sosyal-kod'),
              controller: _kodCtrl,
              enabled: !submitting,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.girisKodAlani,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          if (hata != null) ...[
            const SizedBox(height: 12),
            Text(hata, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('sosyal-ilerle'),
            onPressed: submitting
                ? null
                : () => auth.kodBekleniyor ? _dogrula() : _kodIste(),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: Text(
              auth.kodBekleniyor ? l10n.sosyalDogrula : l10n.sosyalKodGonder,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('sosyal-vazgec'),
            onPressed: submitting
                ? null
                : ref.read(authControllerProvider.notifier).oauthIptal,
            child: Text(l10n.sosyalVazgec),
          ),
        ],
      ),
    );
  }
}
