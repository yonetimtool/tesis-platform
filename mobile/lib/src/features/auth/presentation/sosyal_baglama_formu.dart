import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import 'auth_controller.dart';
import 'giris_hata_metni.dart';
import 'sosyal_giris.dart';

/// (P184) SSO TAMAMLAMA FORMU — girişte "Tesis ID ile tamamlama".
///
/// Saglayici "bu Google hesabinin sahibisin" der; hangi TESISTE oldugunu
/// SOYLEMEZ. Onu Tesis ID soyler; e-posta sahipligini saglayicinin
/// `email_verified` bayragi (OTP atlanir) ya da e-posta OTP kanitlar. SMS YOK.
///
/// ===========================================================================
/// (P194) ROL SORULMAZ — BURASI BIR GIRIS EKRANI
/// ===========================================================================
/// Bu form ROL ACILIR LISTESI iceriyordu ve liste `KayitRolu`ydan
/// besleniyordu — yani KAYIT ekraninin listesinden. Yonetici mobilden
/// KAYDOLAMADIGI icin o listede yonetici YOK; sonucta web'de kaydolmus bir
/// yonetici Google ile giris denedigi anda kendi rolunu SECEMIYOR, "Sakin"
/// secmek zorunda kaliyor ve sunucu hakli olarak reddediyordu.
///
/// OLCULDU (dev API, gercek yonetici hesabi + dogrulanmis Google kimligi,
/// ayni Tesis ID):
///     rol="resident" gonderildi -> durum="onay_bekliyor", jeton YOK
///     rol GONDERILMEDI          -> durum="giris",         jeton VAR
///
/// Sunucu P191 §1'den beri hazirdi: rol beyani yoksa rol HESAPTAN okunur ve
/// `_TAMAMLA_ROLLERI` yoneticiyi de kapsar. Eksik olan tek sey, istemcinin
/// beyani birakmasiydi.
///
/// KURAL: GIRIS kimlik sorar, rol SORMAZ. Kim oldugunu sistem bilir.
/// Rol secimi YALNIZ kayit ekraninda anlamlidir ve orada DURUYOR.
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
  _Asama _asama = _Asama.form;

  @override
  void dispose() {
    _tesisCtrl.dispose();
    _kodCtrl.dispose();
    super.dispose();
  }

  Future<void> _tamamla() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // ROL GONDERILMEZ: sunucu rolu hesaptan okur (bkz. sinif basligi).
    final sonuc = await ref.read(authControllerProvider.notifier).oauthRolTamamla(
          tesisKodu: _tesisCtrl.text.trim(),
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
          // ROL YOK — 1. adimla AYNI kural (bkz. sinif basligi). Ikinci
          // adimda rol beyan etmek, OTP yolundaki yoneticiyi yine
          // "onay_bekliyor" cikmazina atardi.
          tesisKodu: _tesisCtrl.text.trim(),
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
            // (P194) ROL SECIMI KALDIRILDI — bkz. sinif basligi.
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
