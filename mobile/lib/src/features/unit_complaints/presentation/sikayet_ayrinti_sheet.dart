import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../data/unit_complaint_api.dart';
import '../domain/unit_complaint_models.dart';
import 'kategori_adi.dart';

/// (P253 §D) Daireye gelen sikayetlerin ORUNTUSU — yonetim, kimliksiz.
final sikayetKaynakOzetiProvider =
    FutureProvider.autoDispose.family<SikayetKaynakOzeti, String>(
  (ref, unitId) => ref.read(unitComplaintApiProvider).kaynakOzeti(unitId),
);

/// (P253 §D) YONETIM sikayet ayrintisi — web'deki harita daire ayrintisiyla
/// AYNI eylemler: oruntu satiri ("son 30 gunde 12 sikayet, 2 farkli
/// daireden") + tek kaynak uyarisi + "asilsiz" isareti (gerekce zorunlu)
/// ve geri alma.
///
/// Sikayet edenin kimligi HICBIR role donmez; burada gosterilecek bir alan
/// yok. Isaret sikayet edene bildirim olarak gider.
///
/// Donus: bir degisiklik yapildiysa `true` (cagiran listeyi tazeler).
Future<bool?> sikayetAyrintisiAc(BuildContext context, UnitComplaint c) {
  return merkezSayfaAc<bool>(
    context,
    builder: (_) => SikayetAyrintiSheet(complaint: c),
  );
}

class SikayetAyrintiSheet extends ConsumerStatefulWidget {
  const SikayetAyrintiSheet({super.key, required this.complaint});

  final UnitComplaint complaint;

  @override
  ConsumerState<SikayetAyrintiSheet> createState() => _SikayetAyrintiSheetState();
}

class _SikayetAyrintiSheetState extends ConsumerState<SikayetAyrintiSheet> {
  final _gerekce = TextEditingController();
  bool _form = false;
  bool _mesgul = false;
  String? _hata;

  @override
  void dispose() {
    _gerekce.dispose();
    super.dispose();
  }

  Future<void> _gonder({required bool isaretle}) async {
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    final api = ref.read(unitComplaintApiProvider);
    try {
      if (isaretle) {
        await api.asilsizIsaretle(widget.complaint.id, _gerekce.text.trim());
      } else {
        await api.asilsizGeriAl(widget.complaint.id);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _mesgul = false;
        _hata = e.message.isNotEmpty ? e.message : context.l10n.ortakBeklenmeyenHata;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = widget.complaint;
    final ikincil = Theme.of(context).colorScheme.onSurfaceVariant;
    final oruntu = ref.watch(sikayetKaynakOzetiProvider(c.targetUnitId));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sikayetSatirBaslik(
                c.unitNo ?? '-',
                unitComplaintKategoriAdi(l10n, c.kategori),
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(tarihSaatBicimi(c.createdAt, context.dilKodu),
                style: TextStyle(color: ikincil)),
            if (c.notlar != null && c.notlar!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(c.notlar!),
            ],
            const SizedBox(height: 12),
            oruntu.when(
              data: (o) => o.bos
                  ? const SizedBox.shrink()
                  : Wrap(
                      key: const Key('sikayet-oruntu'),
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(l10n.sikayetOruntu(o.gun, o.sikayetSayisi, o.farkliKaynak)),
                        if (o.tekKaynakYogun)
                          Tooltip(
                            message: l10n.sikayetTekKaynakIpucu,
                            child: Chip(
                              key: const Key('sikayet-tek-kaynak'),
                              avatar: const Icon(Icons.info_outline, size: 16),
                              label: Text(l10n.sikayetTekKaynak),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        if (o.asilsizSayisi > 0)
                          Text(l10n.sikayetAsilsizSayisi(o.asilsizSayisi),
                              style: TextStyle(color: ikincil, fontSize: 12)),
                      ],
                    ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            if (c.asilsiz) ...[
              const SizedBox(height: 8),
              Chip(
                key: const Key('sikayet-asilsiz-rozet'),
                label: Text(l10n.sikayetAsilsiz),
                visualDensity: VisualDensity.compact,
              ),
              if ((c.asilsizGerekce ?? '').isNotEmpty)
                Text(l10n.sikayetAsilsizGerekceGoster(c.asilsizGerekce!),
                    style: TextStyle(color: ikincil, fontSize: 12)),
            ],
            const SizedBox(height: 8),
            SelectableText(l10n.sikayetKayitNo(c.id),
                style: TextStyle(color: ikincil, fontSize: 12)),
            const SizedBox(height: 12),
            if (c.asilsiz)
              OutlinedButton(
                key: const Key('sikayet-asilsiz-geri-al'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _mesgul ? null : () => _gonder(isaretle: false),
                child: Text(l10n.sikayetAsilsizGeriAl),
              )
            else if (!_form)
              OutlinedButton(
                key: const Key('sikayet-asilsiz-ac'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => setState(() => _form = true),
                child: Text(l10n.sikayetAsilsizIsaretle),
              )
            else ...[
              Text(l10n.sikayetAsilsizAciklama,
                  style: TextStyle(color: ikincil, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                key: const Key('sikayet-asilsiz-gerekce'),
                controller: _gerekce,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.sikayetAsilsizGerekce,
                  border: const OutlineInputBorder(),
                ),
              ),
              Row(
                children: [
                  FilledButton(
                    key: const Key('sikayet-asilsiz-onayla'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: _mesgul || _gerekce.text.trim().length < 3
                        ? null
                        : () => _gonder(isaretle: true),
                    child: Text(l10n.sikayetAsilsizOnayla),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: _mesgul
                        ? null
                        : () => setState(() {
                              _form = false;
                              _gerekce.clear();
                              _hata = null;
                            }),
                    child: Text(l10n.ortakVazgec),
                  ),
                ],
              ),
            ],
            if (_hata != null) ...[
              const SizedBox(height: 8),
              Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
