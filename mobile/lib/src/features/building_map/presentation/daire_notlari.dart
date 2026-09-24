import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../data/daire_notu_api.dart';

/// (P247-bekleyen 1.2) Daire detayindaki NOTLAR bolumu.
///
/// * Saha personeli: yalniz sunucunun dondurdugu (isaretli) notlari OKUR.
/// * Yonetim: not yazar; "Guvenlik ve tesis gorevlileri bu notu gorebilir"
///   kutusu VARSAYILAN KAPALI ve altinda ne anlama geldigi yazili. Her
///   notun durumu gorunur ve tek dokunusla tersine cevrilir.
class DaireNotlari extends ConsumerStatefulWidget {
  const DaireNotlari({super.key, required this.unitId, required this.yonetim});

  final String unitId;
  final bool yonetim;

  @override
  ConsumerState<DaireNotlari> createState() => _DaireNotlariState();
}

class _DaireNotlariState extends ConsumerState<DaireNotlari> {
  late Future<List<DaireNotu>> _notlar = _yukle();
  final _metin = TextEditingController();
  bool _sahaGorebilir = false;
  bool _mesgul = false;

  Future<List<DaireNotu>> _yukle() =>
      ref.read(daireNotuApiProvider).listele(widget.unitId);

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  Future<void> _calistir(Future<void> Function() is_) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _mesgul = true);
    try {
      await is_();
      if (!mounted) return;
      setState(() {
        _notlar = _yukle();
      });
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _ekle() async {
    final metin = _metin.text.trim();
    if (metin.isEmpty) return;
    await _calistir(() async {
      await ref
          .read(daireNotuApiProvider)
          .ekle(widget.unitId, metin, sahaGorebilir: _sahaGorebilir);
      _metin.clear();
      // Bir sonraki not yine VARSAYILANDAN (kapali) baslar.
      _sahaGorebilir = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ikincil = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.daireNotlariBaslik, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        FutureBuilder<List<DaireNotu>>(
          future: _notlar,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              );
            }
            final notlar = s.data ?? const <DaireNotu>[];
            if (notlar.isEmpty) {
              return Text(l10n.daireNotuYok, style: TextStyle(color: ikincil));
            }
            return Column(
              children: [
                for (final n in notlar)
                  ListTile(
                    key: Key('daire-notu-${n.id}'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(n.metin ?? n.dosyaAdi ?? ''),
                    subtitle: widget.yonetim
                        ? Text(n.sahaGorebilir ? l10n.ekSahaAcik : l10n.ekSahaKapali)
                        : null,
                    trailing: widget.yonetim
                        ? TextButton(
                            key: Key('daire-notu-saha-${n.id}'),
                            onPressed: _mesgul
                                ? null
                                : () => _calistir(() => ref
                                    .read(daireNotuApiProvider)
                                    .sahaGorunurlugu(n.id, sahaGorebilir: !n.sahaGorebilir)),
                            child: Text(n.sahaGorebilir ? l10n.ekSahaKapat : l10n.ekSahaAc),
                          )
                        : null,
                  ),
              ],
            );
          },
        ),
        if (widget.yonetim) ...[
          const SizedBox(height: 8),
          TextField(
            key: const Key('daire-notu-metin'),
            controller: _metin,
            maxLength: 4000,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: l10n.daireNotuYer,
              counterText: '',
            ),
          ),
          CheckboxListTile(
            key: const Key('daire-notu-saha-kutusu'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _sahaGorebilir,
            onChanged: _mesgul ? null : (v) => setState(() => _sahaGorebilir = v ?? false),
            title: Text(l10n.ekSahaGorebilir),
            subtitle: Text(l10n.ekSahaAciklama),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              key: const Key('daire-notu-ekle'),
              onPressed: _mesgul ? null : _ekle,
              child: Text(l10n.daireNotuEkle),
            ),
          ),
        ],
      ],
    );
  }
}
