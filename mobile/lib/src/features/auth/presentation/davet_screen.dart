import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/validators/password_rule.dart';
import '../data/auth_api.dart';
import 'auth_controller.dart';
import 'sosyal_giris.dart';

/// (P155 §7/§8) DAVET EKRANI — derin baglantiyla gelen kayit.
///
/// Davet bagi (`https://<portal>/davet/‹jeton›`) uygulamada bu ekrani acar.
/// Jeton cozulunce TESIS/ROL/DAIRE/TELEFON bellidir; kullanici YALNIZ yontem
/// secer (parola / Google / Microsoft / Apple) ve gerekirse adini duzeltir.
/// Tesis kodu + daire no ekrani ATLANIR — sartname §7.
///
/// SMS YOK: davet jetonu, yoneticinin bu kisiyi ekledigi kanittir (§2). Ne
/// parola ne sosyal yolda kod istenir.
class DavetScreen extends ConsumerStatefulWidget {
  const DavetScreen({required this.jeton, super.key});

  final String jeton;

  @override
  ConsumerState<DavetScreen> createState() => _DavetScreenState();
}

enum _Durum { yukleniyor, gecerli, gecersiz, parola }

class _DavetScreenState extends ConsumerState<DavetScreen> {
  final _parolaFormKey = GlobalKey<FormState>();
  final _adCtrl = TextEditingController();
  final _parolaCtrl = TextEditingController();

  _Durum _durum = _Durum.yukleniyor;
  DavetCozum? _cozum;
  String? _hata;
  String? _hataKodu;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _coz();
  }

  @override
  void dispose() {
    _adCtrl.dispose();
    _parolaCtrl.dispose();
    super.dispose();
  }

  Future<void> _coz() async {
    try {
      final c = await ref.read(authApiProvider).davetCoz(widget.jeton);
      if (!mounted) return;
      setState(() {
        _cozum = c;
        _adCtrl.text = c.ad;
        _durum = _Durum.gecerli;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _hataKodu = e.code;
        _durum = _Durum.gecersiz;
      });
    }
  }

  Future<void> _parolaGonder() async {
    if (!_parolaFormKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).davetParolaTamamla(
          jeton: widget.jeton,
          ad: _adCtrl.text.trim(),
          newPassword: _parolaCtrl.text,
        );
    if (!mounted) return;
    final durum = ref.read(authControllerProvider);
    // Basarida router status=authenticated ile ana ekrana goturur; yalniz
    // HATAYI burada goster.
    if (durum.status != AuthStatus.authenticated) {
      setState(() => _hata = durum.errorMessage);
    }
  }

  Future<void> _sosyalGonder(String saglayici) async {
    final denetleyici = ref.read(authControllerProvider.notifier);
    // Onceki denemeden kalmis bir baglama jetonunu temizle (kayit ekraniyla
    // ayni ilke).
    denetleyici.oauthIptal();
    await denetleyici.oauthAkisi(saglayici);
    if (!mounted) return;
    final durum = ref.read(authControllerProvider);
    if (durum.status == AuthStatus.authenticated) return; // kimlik zaten bagli
    if (durum.oauthBaglamaJetonu == null) {
      // Kullanici tarayiciyi kapatti (jeton yok) — sessizce kal.
      if (durum.errorMessage != null) {
        setState(() => _hata = durum.errorMessage);
      }
      return;
    }
    await denetleyici.davetSosyalTamamla(
      jeton: widget.jeton,
      ad: _adCtrl.text.trim().isEmpty ? null : _adCtrl.text.trim(),
    );
    if (!mounted) return;
    final son = ref.read(authControllerProvider);
    if (son.status != AuthStatus.authenticated) {
      setState(() => _hata = son.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bekliyor = ref.watch(authControllerProvider).submitting;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.davetBaslik)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: switch (_durum) {
                _Durum.yukleniyor =>
                  const Center(child: CircularProgressIndicator()),
                _Durum.gecersiz => _gecersiz(l10n),
                _Durum.gecerli => _yontemSecimi(l10n, bekliyor),
                _Durum.parola => _parolaFormu(l10n, bekliyor),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _gecersiz(AppLocalizations l10n) {
    final metin = switch (_hataKodu) {
      'davet_suresi_doldu' => l10n.davetSuresiDoldu,
      'davet_kullanilmis' => l10n.davetKullanilmis,
      _ => l10n.davetBulunamadi,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.link_off, size: 48, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 16),
        Text(l10n.davetGecersizBaslik,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(metin, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(l10n.davetYoneticinizeBasvurun,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _yontemSecimi(AppLocalizations l10n, bool bekliyor) {
    final cozum = _cozum!;
    final saglayicilar =
        ref.watch(oauthSaglayicilarProvider).value ?? const <String>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.davetOzet(cozum.tesisAd, _rolEtiketi(l10n, cozum.rol))),
        const SizedBox(height: 8),
        _bilgiSatiri(l10n.ortakCepTelefonu, cozum.telefonMaskeli),
        if (cozum.daireNo != null) _bilgiSatiri(l10n.kayitDaireNo, cozum.daireNo!),
        const SizedBox(height: 20),
        if (_hata != null) ...[
          Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
        ],
        Text(l10n.kayitYontemBaslik,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('davet-yontem-parola'),
          onPressed: bekliyor ? null : () => setState(() => _durum = _Durum.parola),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(l10n.kayitYontemParola),
        ),
        for (final s in saglayicilar) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            key: Key('davet-yontem-$s'),
            onPressed: bekliyor ? null : () => _sosyalGonder(s),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: Text(l10n.sosyalIleDevam(kSaglayiciEtiketi[s] ?? s)),
          ),
        ],
      ],
    );
  }

  Widget _parolaFormu(AppLocalizations l10n, bool bekliyor) {
    return Form(
      key: _parolaFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.parolaBelirleBaslik,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          TextFormField(
            controller: _adCtrl,
            enabled: !bekliyor,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.ortakAdSoyad,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('davet-parola'),
            controller: _parolaCtrl,
            enabled: !bekliyor,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: l10n.ortakYeniParola,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscure ? l10n.ortakParolayiGoster : l10n.ortakParolayiGizle,
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => (v ?? '').isEmpty
                ? l10n.ortakParolaZorunlu
                : parolaHataMetni(l10n, v),
          ),
          const SizedBox(height: 24),
          if (_hata != null) ...[
            Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
          ],
          FilledButton(
            key: const Key('davet-parola-gonder'),
            onPressed: bekliyor ? null : _parolaGonder,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: bekliyor
                ? const SizedBox(
                    height: 22, width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text(l10n.parolaBelirleButon),
          ),
          TextButton(
            onPressed: bekliyor ? null : () => setState(() {
              _hata = null;
              _durum = _Durum.gecerli;
            }),
            child: Text(l10n.ortakVazgec),
          ),
        ],
      ),
    );
  }

  Widget _bilgiSatiri(String etiket, String deger) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(etiket, style: TextStyle(color: Theme.of(context).hintColor)),
            Text(deger),
          ],
        ),
      );

  String _rolEtiketi(AppLocalizations l10n, String rol) => switch (rol) {
        'yonetici' => l10n.kayitRolYonetici,
        'resident' => l10n.kayitRolSakin,
        'security' => l10n.kayitRolGuvenlik,
        'tesis_gorevlisi' => l10n.kayitRolTesisGorevlisi,
        'denetci' => l10n.rolDenetci,
        _ => rol,
      };
}
