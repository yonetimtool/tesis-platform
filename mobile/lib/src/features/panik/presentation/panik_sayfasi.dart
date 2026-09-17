import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../data/panik_api.dart';
import '../domain/panik_models.dart';

/// (P240 §1) PANIK TETIKLEME SAYFASI.
///
/// =========================================================================
/// ROL BASINA FARKLI DUGMELER
/// =========================================================================
/// Tek bir "panik" dugmesi, uc farkli olayi tek alici kumesine
/// gonderirdi. Sunucudaki `TETIKLEYEBILIR` tablosunun aynasi burada;
/// gorunmeyen bir dugme, basinca 403 alacagi bir yol sunmamak icin.
///
/// =========================================================================
/// GERI SAYIM ISTEMCIDE, YAYIN SUNUCUDA
/// =========================================================================
/// Dugmeye basilinca alarm SUNUCUDA hemen yazilir (`beklemede`) ve
/// istemci geri sayar. Sayim bitince ISTEMCI HICBIR SEY YAPMAZ — yayini
/// sunucudaki gecikmeli gorev yapar. Boylece uygulama kapansa, ekran
/// sonse ya da ag kopsa bile alarm GIDER.
List<PanikTip> tetiklenebilirTipler(UserRole rol) => switch (rol) {
      UserRole.resident => const [PanikTip.sakin],
      UserRole.security ||
      UserRole.tesisGorevlisi =>
        const [PanikTip.guvenlik],
      UserRole.guvenlikAmiri => const [PanikTip.guvenlik],
      // Yoneticinin dairesi yoktur: `sakin` tipi gidilecek ADRES tasimaz.
      UserRole.yonetici ||
      UserRole.admin =>
        const [PanikTip.guvenlik, PanikTip.yoneticiAnons],
      UserRole.denetci || UserRole.unknown => const [],
    };

String panikTipAdi(AppLocalizations l10n, PanikTip tip) => switch (tip) {
      PanikTip.sakin => l10n.panikTipSakin,
      PanikTip.guvenlik => l10n.panikTipGuvenlik,
      PanikTip.yoneticiAnons => l10n.panikTipAnons,
    };

class PanikSayfasi extends ConsumerStatefulWidget {
  const PanikSayfasi({super.key});

  @override
  ConsumerState<PanikSayfasi> createState() => _PanikSayfasiState();
}

class _PanikSayfasiState extends ConsumerState<PanikSayfasi> {
  PanikAlarm? _alarm;
  int _kalan = 0;
  Timer? _sayac;
  bool _mesgul = false;
  String? _hata;

  @override
  void dispose() {
    _sayac?.cancel();
    super.dispose();
  }

  Future<void> _tetikle(PanikTip tip) async {
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      final alarm = await ref.read(panikApiProvider).tetikle(tip);
      if (!mounted) return;
      setState(() {
        _alarm = alarm;
        _kalan = alarm.iptalPenceresiSn;
      });
      _sayac?.cancel();
      _sayac = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _kalan = _kalan > 0 ? _kalan - 1 : 0);
        if (_kalan == 0) t.cancel();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _hata = apiHataMetni(context.l10n, e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _iptal() async {
    final alarm = _alarm;
    if (alarm == null) return;
    setState(() => _mesgul = true);
    final l10n = context.l10n;
    final mesajci = ScaffoldMessenger.of(context);
    try {
      final y = await ref.read(panikApiProvider).iptal(alarm.id);
      if (!mounted) return;
      _sayac?.cancel();
      setState(() {
        _alarm = null;
        _kalan = 0;
      });
      mesajci.showSnackBar(SnackBar(
        content: Text(y.durum == 'iptal'
            ? l10n.panikIptalEdildi
            : l10n.panikYanlisAlarmGonderildi),
      ));
    } on ApiException catch (e) {
      if (mounted) setState(() => _hata = apiHataMetni(l10n, e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rol = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    final tipler = tetiklenebilirTipler(rol);
    final alarm = _alarm;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.panikBaslik)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_hata != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_hata!,
                    key: const Key('panik-hata'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (alarm == null) ...[
              // YASAL SINIR — DUGMELERDEN ONCE.
              //
              // "Bu sistem 112/155 yerine gecmez" cumlesi alarmi
              // BASTIKTAN SONRA gosterilseydi, en kritik anda okunmazdi.
              Text(
                l10n.panikYasalUyari,
                key: const Key('panik-yasal'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              for (final tip in tipler)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton(
                    key: Key('panik-tip-${tip.kimlik}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      // DOKUNMA HEDEFI BUYUK: acil durumda titreyen bir
                      // parmak kucuk bir dugmeyi isabet ettiremez.
                      minimumSize: const Size.fromHeight(64),
                    ),
                    onPressed: _mesgul ? null : () => _tetikle(tip),
                    child: Text(panikTipAdi(l10n, tip)),
                  ),
                ),
              if (tipler.isEmpty)
                Text(l10n.panikYetkiYok, key: const Key('panik-yetki-yok')),
            ] else ...[
              Text(
                _kalan > 0
                    ? l10n.panikGonderiliyor(_kalan)
                    : l10n.panikGonderildi,
                key: const Key('panik-geri-sayim'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(l10n.panikIptalAciklama),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const Key('panik-iptal'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: _mesgul ? null : _iptal,
                child: Text(l10n.panikIptalEt),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
