import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
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
  String? _error;
  late String? _donem; // acilista icinde bulunulan ay

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _donem = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final summary = await ref
          .read(budgetApiProvider)
          .fetchFinancialSummary(donem: _donem);
      if (mounted) setState(() => _summary = summary);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Beklenmeyen bir hata oluştu. Tekrar deneyin.');
      }
    }
  }

  List<DropdownMenuItem<String?>> _donemItems() {
    final now = DateTime.now();
    return [
      const DropdownMenuItem<String?>(value: null, child: Text('Tüm zamanlar')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Finansal özet')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: _load, child: const Text('Tekrar dene')),
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
                        items: _donemItems(),
                        onChanged: (v) {
                          setState(() => _donem = v);
                          _load();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Dönem',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_month_outlined),
                        ),
                      ),
                      if (s.tahsilat != null) ...[
                        const SizedBox(height: 16),
                        _sectionTitle(context, Icons.payments_outlined,
                            'Aidat tahsilatı'),
                        _TahsilatCard(tahsilat: s.tahsilat!),
                      ],
                      const SizedBox(height: 16),
                      _sectionTitle(
                          context, Icons.savings_outlined, 'Bütçe'),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _statRow('Gelir',
                                  '${formatKurusAsTl(s.toplamGelirKurus)} TL',
                                  valueColor: Colors.green),
                              _statRow('Gider',
                                  '${formatKurusAsTl(s.toplamGiderKurus)} TL',
                                  valueColor: Colors.red),
                              _statRow(
                                'Kasa',
                                '${formatKurusAsTl(s.bakiyeKurus)} TL',
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
                            'En yüksek giderler'),
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
                                    '${formatKurusAsTl(s.enYuksekGiderler[i].toplamKurus)} TL',
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
        Text(label),
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
    final yuzde = tahsilat.tahsilatOraniYuzde;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statRow(
                'Tahakkuk', '${formatKurusAsTl(tahsilat.tahakkukKurus)} TL'),
            _statRow(
              'Tahsilat',
              '${formatKurusAsTl(tahsilat.tahsilatKurus)} TL',
              valueColor: Colors.green,
            ),
            _statRow(
              'Geciken',
              '${tahsilat.gecikenDaireSayisi} daire',
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
                alignment: Alignment.centerRight,
                child: Text(
                  'Tahsilat %$yuzde',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Bu dönem için tahakkuk kaydı yok.'),
              ),
          ],
        ),
      ),
    );
  }
}
