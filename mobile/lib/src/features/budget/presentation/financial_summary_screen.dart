import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../data/budget_api.dart';
import '../domain/budget_models.dart';

/// "Gunluk/Donemsel Ozet" — YONETICI icin cepten hizli finansal rapor
/// (Wave 2B): aidat tahsilat orani, geciken daire sayisi, gelir/gider/kasa
/// ve en yuksek gider kategorileri. Salt okuma; kaynak:
/// GET /reports/financial-summary.
class FinancialSummaryScreen extends ConsumerStatefulWidget {
  const FinancialSummaryScreen({super.key});

  @override
  ConsumerState<FinancialSummaryScreen> createState() =>
      _FinancialSummaryScreenState();
}

class _FinancialSummaryScreenState
    extends ConsumerState<FinancialSummaryScreen> {
  FinancialSummary? _summary;

  /// Hata KANALI ikilidir (README §15): sunucu metni + yerellestirilebilir
  /// kimlik.
  String? _error;
  AkisHatasi? _hataKimligi;
  late String? _donem; // acilista icinde bulunulan ay

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _donem = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _hataKimligi = null;
    });
    try {
      final summary = await ref
          .read(budgetApiProvider)
          .fetchFinancialSummary(donem: _donem);
      if (mounted) setState(() => _summary = summary);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = apiHataMetni(context.l10n, e));
    } catch (_) {
      if (mounted) setState(() => _hataKimligi = AkisHatasi.beklenmeyen);
    }
  }

  List<DropdownMenuItem<String?>> _donemItems(AppLocalizations l10n) {
    final now = DateTime.now();
    return [
      DropdownMenuItem<String?>(value: null, child: Text(l10n.butTumZamanlar)),
      for (var i = 0; i < 12; i++)
        () {
          final d = DateTime(now.year, now.month - i);
          final v = '${d.year}-${d.month.toString().padLeft(2, '0')}';
          return DropdownMenuItem<String?>(value: v, child: Text(v));
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final hata = akisHatasiCoz(l10n, _hataKimligi, _error);
    return Scaffold(
      appBar: AppBar(title: Text(baslikBuyuk(l10n.butFinansalOzet, dil))),
      body: hata != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(hata, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: _load,
                        child: Text(l10n.ortakTekrarDene)),
                  ],
                ),
              ),
            )
          : s == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      DropdownButtonFormField<String?>(
                        key: const Key('fs_donem_dropdown'),
                        initialValue: _donem,
                        items: _donemItems(l10n),
                        onChanged: (v) {
                          setState(() => _donem = v);
                          _load();
                        },
                        decoration: InputDecoration(
                          labelText: l10n.butDonem,
                          border: const OutlineInputBorder(),
                          prefixIcon:
                              const Icon(Icons.calendar_month_outlined),
                        ),
                      ),
                      if (s.tahsilat != null) ...[
                        const SizedBox(height: 16),
                        _sectionTitle(context, Icons.payments_outlined,
                            l10n.butAidatTahsilati),
                        _TahsilatCard(tahsilat: s.tahsilat!),
                      ],
                      const SizedBox(height: 16),
                      _sectionTitle(
                          context, Icons.savings_outlined, l10n.butBaslik),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _statRow(l10n.butGelir,
                                  tlSonEkli(s.toplamGelirKurus, dil),
                                  valueColor: Colors.green),
                              _statRow(l10n.butGider,
                                  tlSonEkli(s.toplamGiderKurus, dil),
                                  valueColor: Colors.red),
                              _statRow(
                                l10n.butKasa,
                                tlSonEkli(s.bakiyeKurus, dil),
                                valueColor: s.bakiyeKurus < 0
                                    ? Colors.red
                                    : Colors.blue,
                                bold: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (s.enYuksekGiderler.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _sectionTitle(context, Icons.leaderboard_outlined,
                            l10n.butEnYuksekGiderler),
                        Card(
                          margin: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (var i = 0;
                                  i < s.enYuksekGiderler.length;
                                  i++) ...[
                                if (i > 0) const Divider(height: 1),
                                ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 12,
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  title: Text(s.enYuksekGiderler[i].ad),
                                  trailing: Text(
                                    tlSonEkli(
                                        s.enYuksekGiderler[i].toplamKurus, dil),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

Widget _sectionTitle(BuildContext context, IconData icon, String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

Widget _statRow(String label, String value,
    {Color? valueColor, bool bold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Etiket kucultulebilir: dar ekranda (320 dp) uzun ceviriler
        // ("المصروفات", "Sollstellung") satiri tasiriyordu. TUTAR asla
        // kirpilmaz — para okunabilir kalmali.
        Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    ),
  );
}

class _TahsilatCard extends StatelessWidget {
  const _TahsilatCard({required this.tahsilat});

  final TahsilatOzet tahsilat;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final yuzde = tahsilat.tahsilatOraniYuzde;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statRow(l10n.butTahakkuk, tlSonEkli(tahsilat.tahakkukKurus, dil)),
            _statRow(
              l10n.butTahsilat,
              tlSonEkli(tahsilat.tahsilatKurus, dil),
              valueColor: Colors.green,
            ),
            _statRow(
              l10n.butGeciken,
              l10n.binaDaireSayisi(tahsilat.gecikenDaireSayisi),
              valueColor:
                  tahsilat.gecikenDaireSayisi > 0 ? Colors.red : Colors.green,
            ),
            if (yuzde != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: yuzde / 100,
                  minHeight: 6,
                  color: yuzde >= 80 ? Colors.green : Colors.orange,
                  backgroundColor: Colors.blueGrey.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                // YON-DUYARLI: Arapca'da sola hizalanir (centerRight sabit
                // sagda kalirdi).
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  l10n.butTahsilatYuzde(yuzde),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.butTahakkukYok),
              ),
          ],
        ),
      ),
    );
  }
}
