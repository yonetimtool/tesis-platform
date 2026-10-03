import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/ek_api.dart';
import 'ek_sil.dart';

/// (P253 Asama 1) NOTLAR VE EKLER karti — web `Ekler` bileseninin mobil
/// ikizi. Okuma ust kaydi gorene acik (sunucu suzer); not ekleme ve silme
/// yalniz [ekSilebilir] rollerde cizilir (sunucu yine karar verir).
class EkListesi extends ConsumerStatefulWidget {
  const EkListesi({super.key, required this.varlikTipi, required this.varlikId});

  final String varlikTipi;
  final String varlikId;

  @override
  ConsumerState<EkListesi> createState() => _EkListesiState();
}

class _EkListesiState extends ConsumerState<EkListesi> {
  final _not = TextEditingController();
  bool _mesgul = false;

  (String, String) get _anahtar => (widget.varlikTipi, widget.varlikId);

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  Future<void> _ekle() async {
    final metin = _not.text.trim();
    if (metin.isEmpty) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _mesgul = true);
    try {
      await ref.read(ekApiProvider).notEkle(widget.varlikTipi, widget.varlikId, metin);
      _not.clear();
      ref.invalidate(ekListesiProvider(_anahtar));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final yazar = ekSilebilir(ref.watch(currentUserRoleProvider).value);
    final ekler = ref.watch(ekListesiProvider(_anahtar));
    final ikincil = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      key: const Key('ek-listesi'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.kisEkBaslik, style: const TextStyle(fontWeight: FontWeight.w600)),
            ekler.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text(
                e is ApiException ? apiHataMetni(l10n, e) : l10n.ortakYuklenemedi,
                style: TextStyle(color: ikincil),
              ),
              data: (liste) => liste.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(l10n.kisEkYok, style: TextStyle(color: ikincil)),
                    )
                  : Column(
                      children: [
                        for (final ek in liste)
                          ListTile(
                            key: Key('ek-${ek.id}'),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: Icon(
                              ek.tur == 'not' ? Icons.notes_outlined : Icons.attach_file,
                            ),
                            title: Text(ek.tur == 'not' ? (ek.metin ?? '') : (ek.dosyaAdi ?? '')),
                            subtitle: ek.olusturanAd == null ? null : Text(ek.olusturanAd!),
                            onTap: ek.dosyaUrl == null
                                ? null
                                : () => launchUrl(
                                    Uri.parse(ek.dosyaUrl!),
                                    mode: LaunchMode.externalApplication,
                                  ),
                            trailing: yazar
                                ? IconButton(
                                    key: Key('ek-sil-${ek.id}'),
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: l10n.ortakSil,
                                    onPressed: () async {
                                      final silindi = await ekSilOnayli(
                                        context,
                                        ref,
                                        ekId: ek.id,
                                        ad: ek.gorunenAd,
                                      );
                                      if (silindi) ref.invalidate(ekListesiProvider(_anahtar));
                                    },
                                  )
                                : null,
                          ),
                      ],
                    ),
            ),
            if (yazar) ...[
              TextField(
                key: const Key('ek-not-metin'),
                controller: _not,
                maxLength: 4000,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(labelText: l10n.kisEkNotYer, counterText: ''),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const Key('ek-not-ekle'),
                  onPressed: _mesgul ? null : _ekle,
                  child: Text(l10n.ortakEkle),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
