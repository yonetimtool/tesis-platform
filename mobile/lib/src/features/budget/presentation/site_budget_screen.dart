import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/budget_api.dart';
import '../domain/budget_models.dart';

/// "Site Butcesi" — SAKIN seffaflik gorunumu (Wave 2B). SALT OKUMA:
/// yalniz AGREGAT ozet (toplam gelir/gider/kasa + kategori toplamlari)
/// gosterilir; defter satirlari, kisi/daire verisi ve yonetim eylemleri
/// bu ekranda YOKTUR (backend de 403 ile korur — auth.md §4).
class SiteBudgetScreen extends ConsumerStatefulWidget {
  const SiteBudgetScreen({super.key});

  @override
  ConsumerState<SiteBudgetScreen> createState() => _SiteBudgetScreenState();
}

class _SiteBudgetScreenState extends ConsumerState<SiteBudgetScreen> {
  BudgetSummary? _summary;
  String? _error;
  String? _donem; // null = tum zamanlar

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final summary =
          await ref.read(budgetApiProvider).fetchSummary(donem: _donem);
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
      appBar: AppBar(title: const Text('Site Bütçesi')),
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
                        key: const Key('site_budget_donem_dropdown'),
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
                      const SizedBox(height: 16),
                      _TotalTile(
                        label: 'Gelir',
                        kurus: s.toplamGelirKurus,
                        color: Colors.green,
                        icon: Icons.trending_up,
                      ),
                      const SizedBox(height: 8),
                      _TotalTile(
                        label: 'Gider',
                        kurus: s.toplamGiderKurus,
                        color: Colors.red,
                        icon: Icons.trending_down,
                      ),
                      const SizedBox(height: 8),
                      _TotalTile(
                        label: 'Kasa',
                        kurus: s.bakiyeKurus,
                        color: s.bakiyeKurus < 0 ? Colors.red : Colors.blue,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      if (s.kategoriler.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Kategori toplamları',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        for (final k in s.kategoriler)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              k.tip == BudgetTip.gelir
                                  ? Icons.add_circle_outline
                                  : Icons.remove_circle_outline,
                              color: k.tip == BudgetTip.gelir
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            title: Text(k.ad),
                            trailing: Text(
                              '${formatKurusAsTl(k.toplamKurus)} TL',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Bu ekran site yönetiminin gelir ve giderlerini '
                        'şeffaflık amacıyla özet olarak gösterir. Kişi ve '
                        'daire bazlı detaylar görüntülenmez; sorularınız '
                        'için yönetiminize başvurun.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.label,
    required this.kurus,
    required this.color,
    required this.icon,
  });

  final String label;
  final int kurus;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(label),
        trailing: Text(
          '${formatKurusAsTl(kurus)} TL',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
