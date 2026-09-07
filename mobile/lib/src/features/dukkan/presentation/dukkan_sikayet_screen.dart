import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../data/dukkan_api.dart';

/// (DUKKAN F5) SIKAYET — KIMLIKSIZ.
///
/// =========================================================================
/// GIRIS ISTEMIYORUZ VE BU BILINCLI
/// =========================================================================
/// Dolandirilan bir kullanicinin Dukkan hesabi OLMAYABILIR: numarayi
/// profilden alip TELEFONLA aramis olabilir. Kimlik zorunlu olsaydi en
/// cok duyulmasi gereken ses kesilirdi.
///
/// `iletisim` opsiyonel ve NEDEN istendigi yazili — zorunlu yapmak,
/// anonim kalmak isteyen kisiyi sikayet etmekten caydirirdi.
class DukkanSikayetScreen extends ConsumerStatefulWidget {
  const DukkanSikayetScreen({super.key, this.isletmeSlug});

  final String? isletmeSlug;

  @override
  ConsumerState<DukkanSikayetScreen> createState() =>
      _DukkanSikayetScreenState();
}

class _DukkanSikayetScreenState extends ConsumerState<DukkanSikayetScreen> {
  String _tip = 'odeme';
  final _metin = TextEditingController();
  final _iletisim = TextEditingController();
  bool _bekle = false;
  bool _gonderildi = false;
  String? _hata;

  @override
  void dispose() {
    _metin.dispose();
    _iletisim.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    if (_metin.text.trim().length < 10) return;
    setState(() {
      _bekle = true;
      _hata = null;
    });
    try {
      await ref.read(dukkanApiProvider).sikayetGonder(
            tip: _tip,
            metin: _metin.text.trim(),
            isletmeSlug: widget.isletmeSlug,
            iletisim: _iletisim.text.trim(),
          );
      if (mounted) setState(() => _gonderildi = true);
    } catch (e) {
      if (mounted) {
        setState(() => _hata = AppLocalizations.of(context).dukkanYorumHatasi);
      }
    } finally {
      if (mounted) setState(() => _bekle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tipler = <String, String>{
      'odeme': t.dukkanSikayetOdeme,
      'hizmet': t.dukkanSikayetHizmet,
      'sahte_isletme': t.dukkanSikayetSahte,
      'yorum': t.dukkanSikayetYorum,
      'kisisel_veri': t.dukkanSikayetVeri,
      'diger': t.dukkanSikayetDiger,
    };

    return Scaffold(
      appBar: AppBar(title: Text(t.dukkanSikayetBildir)),
      body: _gonderildi
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.dukkanSikayetAlindi,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _tip,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: t.dukkanSikayetKonu,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final e in tipler.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _tip = v ?? 'odeme'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _metin,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: t.dukkanSikayetMetin,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _iletisim,
                  decoration: InputDecoration(
                    labelText: t.dukkanSikayetIletisim,
                    helperText: t.dukkanSikayetIletisimIpucu,
                    helperMaxLines: 2,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _bekle ? null : _gonder,
                  child: Text(t.dukkanSikayetGonder),
                ),
                if (_hata != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_hata!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
    );
  }
}
