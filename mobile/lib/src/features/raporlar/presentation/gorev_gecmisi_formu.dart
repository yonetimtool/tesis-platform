import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../domain/rapor_dosya_turu.dart';
import '../data/rapor_motoru_api.dart';
import '../domain/rapor_motoru_models.dart';
import 'rapor_paylas.dart';

/// (P253 Asama 2) GOREV GECMISI CSV — web `/reports/tasks` "CSV indir"in
/// mobil karsiligi (eylem tablosu `ISTEMCI /reports/tasks`).
///
/// Sunucuda bu icin bir rapor YOK; web de CSV'yi istemcide kuruyor. Mobil
/// ayni ucu (`/task-completions`) ayni tarih araligiyla TUM sayfalariyla
/// ceker, ayni sutunlarla CSV kurar ve PAYLASIR. Tamamlayan adi `/users`
/// listesinden (web `userName` ile ayni).
class GorevGecmisiFormu extends ConsumerStatefulWidget {
  const GorevGecmisiFormu({super.key, this.simdi});

  /// Testte sabit "bugun".
  final DateTime? simdi;

  @override
  ConsumerState<GorevGecmisiFormu> createState() => _GorevGecmisiFormuState();
}

class _GorevGecmisiFormuState extends ConsumerState<GorevGecmisiFormu> {
  late DateTime _bas;
  late DateTime _bit;
  bool _mesgul = false;
  String? _hata;

  /// (P253 A2) Son cekim ust sinira takildi mi (rapor eksik).
  bool _kesildi = false;

  @override
  void initState() {
    super.initState();
    final s = widget.simdi ?? DateTime.now();
    // Varsayilan: bu ayin basi -> bugun (rapor tarihleriyle ayni dusunce).
    _bas = DateTime(s.year, s.month, 1);
    _bit = DateTime(s.year, s.month, s.day);
  }

  Future<void> _sec(bool baslangic) async {
    final secilen = await showDatePicker(
      context: context,
      initialDate: baslangic ? _bas : _bit,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (secilen != null) setState(() => baslangic ? _bas = secilen : _bit = secilen);
  }

  Future<void> _paylas(BuildContext bctx) async {
    final l10n = context.l10n;
    final api = ref.read(raporMotoruApiProvider);
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    setState(() => _kesildi = false);
    try {
      final bas = _bas;
      // Bitis gunu DAHIL: ertesi gunun basina kadar (yari acik aralik).
      final bit = DateTime(_bit.year, _bit.month, _bit.day + 1);
      await raporuPaylas(
        bctx,
        ref,
        konu: l10n.rprGorevGecmisi,
        uret: () async {
          final cekim = await api.gorevGecmisi(baslangic: bas, bitis: bit);
          final satirlar = cekim.satirlar;
          // (P253 A2) Sinira takildiysa rapor EKSIK: kullaniciya soylenir.
          if (cekim.kesildi && mounted) setState(() => _kesildi = true);
          List<SecimOgesi> kisiler;
          try {
            kisiler = await api.kisiler();
          } on ApiException {
            kisiler = const [];
          }
          final csv = gorevGecmisiCsv(l10n, satirlar, {for (final k in kisiler) k.id: k.ad});
          // BOM: Excel Turkce karakterleri UTF-8 okusun (web csv.ts ile ayni).
          return (
            baytlar: Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]),
            dosyaAdi: gorevGecmisiDosyaAdi,
          );
        },
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _hata = e.message);
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Widget _tarih(String etiket, DateTime d, bool baslangic, Key key) => InkWell(
        key: key,
        onTap: _mesgul ? null : () => _sec(baslangic),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: etiket,
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          child: Text(tarihBicimi(d, context.dilKodu)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.rprGorevGecmisi, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(l10n.rprGorevGecmisiAlt,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          _tarih(l10n.rprBaslangic, _bas, true, const Key('gg-baslangic')),
          const SizedBox(height: 10),
          _tarih(l10n.rprBitis, _bit, false, const Key('gg-bitis')),
          if (_hata != null) ...[
            const SizedBox(height: 8),
            Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_kesildi) ...[
            const SizedBox(height: 8),
            Text(l10n.rprKesildi, key: const Key('gg-kesildi'),
                style: TextStyle(color: Theme.of(context).colorScheme.tertiary)),
          ],
          const SizedBox(height: 12),
          Builder(
            builder: (bctx) => FilledButton.icon(
              key: const Key('gg-paylas'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.ios_share),
              label: Text(l10n.rprCsvPaylas),
              onPressed: _mesgul ? null : () => _paylas(bctx),
            ),
          ),
        ],
      ),
    );
  }
}
