import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import 'auth_controller.dart';
import 'giris_hata_metni.dart';
import 'kayit_screen.dart' show KayitRolu;
import 'sosyal_giris.dart';

/// (P184) SSO TAMAMLAMA FORMU — girişte "Tesis ID ile tamamlama".
///
/// Saglayici "bu Google hesabinin sahibisin" der; hangi tesiste kim oldugunu
/// SOYLEMEZ. Onu ROL + Tesis ID soyler; e-posta sahipligini saglayicinin
/// `email_verified` bayragi (OTP atlanir) ya da e-posta OTP kanitlar. SMS YOK.
///
/// AYRI BIR ROTA DEGIL, GIRIS EKRANININ BIR MODU: akis giristen ayrilmaz.
/// `oauthIptal()` durumu temizler.
class SosyalBaglamaFormu extends ConsumerStatefulWidget {
  const SosyalBaglamaFormu({super.key});

  @override
  ConsumerState<SosyalBaglamaFormu> createState() => _SosyalBaglamaFormuState();
}

/// Formun ic asamasi: bilgi girisi → (gerekirse) e-posta OTP → onay bekliyor.
enum _Asama { form, otp, onayBekliyor }

class _SosyalBaglamaFormuState extends ConsumerState<SosyalBaglamaFormu> {
  final _formKey = GlobalKey<FormState>();
  final _tesisCtrl = TextEditingController();
  final _kodCtrl = TextEditingController();
  KayitRolu _rol = KayitRolu.sakin;
  _Asama _asama = _Asama.form;

  @override
  void dispose() {
    _tesisCtrl.dispose();
    _kodCtrl.dispose();
    super.dispose();
  }

  String _rolEtiketi(AppLocalizations l10n, KayitRolu rol) => switch (rol) {
        KayitRolu.sakin => l10n.kayitRolSakin,
        KayitRolu.guvenlik => l10n.kayitRolGuvenlik,
        KayitRolu.tesisGorevlisi => l10n.kayitRolTesisGorevlisi,
      };

  Future<void> _tamamla() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final sonuc = await ref.read(authControllerProvider.notifier).oauthRolTamamla(
          tesisKodu: _tesisCtrl.text.trim(),
          rol: _rol.kimlik,
        );
    if (sonuc == null || !mounted) return;
    // `giris` -> state authenticated; router devralir.
    if (sonuc.durum == 'otp_gerekli') {
      setState(() => _asama = _Asama.otp);
    } else if (sonuc.durum == 'onay_bekliyor') {
      setState(() => _asama = _Asama.onayBekliyor);
    }
  }

  Future<void> _dogrula() async {
    final durum = await ref
        .read(authControllerProvider.notifier)
        .oauthRolTamamlaDogrula(
          tesisKodu: _tesisCtrl.text.trim(),
          rol: _rol.kimlik,
          kod: _kodCtrl.text.trim(),
        );
    if (!mounted) return;
    if (durum == 'onay_bekliyor') {
      setState(() => _asama = _Asama.onayBekliyor);
    }
    // 'giris' -> router devralir; hata -> state.errorMessage gosterilir.
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ref.watch(authControllerProvider);
    final submitting = auth.submitting;
    final hata = girisHatasiCoz(l10n, auth.hataKimligi, auth.errorMessage);
    final saglayici =
        kSaglayiciEtiketi[auth.oauthSaglayici] ?? (auth.oauthSaglayici ?? '');

    if (_asama == _Asama.onayBekliyor) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.hourglass_top_outlined,
              size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(l10n.kayitOnayBekliyorBaslik,
              key: const Key('sosyal-onay-bekliyor'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Text(l10n.kayitOnayBekliyorAciklama,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('sosyal-onay-girise-don'),
            onPressed: ref.read(authControllerProvider.notifier).oauthIptal,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: Text(l10n.kayitGiriseDon),
          ),
        ],
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.sosyalTamamlaBaslik,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l10n.sosyalTamamlaAciklama(saglayici),
              style: Theme.of(context).textTheme.bodySmall),
          // APPLE PRIVATE RELAY: kullaniciya SOYLENIR.
          if (auth.oauthRelay) ...[
            const SizedBox(height: 8),
            Text(l10n.sosyalRelayUyari,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          if (_asama == _Asama.form) ...[
            DropdownButtonFormField<KayitRolu>(
              key: const Key('sosyal-rol'),
              initialValue: _rol,
              decoration: InputDecoration(
                labelText: l10n.sosyalRol,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final r in KayitRolu.values)
                  DropdownMenuItem(value: r, child: Text(_rolEtiketi(l10n, r))),
              ],
              onChanged:
                  submitting ? null : (r) => setState(() => _rol = r ?? _rol),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('sosyal-tesis-kodu'),
              controller: _tesisCtrl,
              enabled: !submitting,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l10n.sosyalTesisKodu,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().length < 4)
                  ? l10n.ortakZorunluAlan(l10n.sosyalTesisKodu)
                  : null,
            ),
          ] else ...[
            Text(l10n.sosyalOtpAciklama,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('sosyal-kod'),
              controller: _kodCtrl,
              enabled: !submitting,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.girisKodAlani,
                prefixIcon: const Icon(Icons.mail_outline),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          if (hata != null) ...[
            const SizedBox(height: 12),
            Text(hata,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('sosyal-ilerle'),
            onPressed: submitting
                ? null
                : () => _asama == _Asama.otp ? _dogrula() : _tamamla(),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: Text(
              _asama == _Asama.otp ? l10n.sosyalDogrula : l10n.sosyalTamamla,
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
