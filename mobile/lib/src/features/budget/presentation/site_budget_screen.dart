import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
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

  /// Hata KANALI ikilidir (README §15): sunucu metni + yerellestirilebilir
  /// kimlik.
  String? _error;
  AkisHatasi? _hataKimligi;
  String? _donem; // null = tum zamanlar

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _hataKimligi = null;
    });
    try {
      final summary =
          await ref.read(budgetApiProvider).fetchSummary(donem: _donem);
      if (mounted) setState(() => _summary = summary);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
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
      appBar: AppBar(title: Text(baslikBuyuk(l10n.butSiteBaslik, dil))),
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
                        key: const Key('site_budget_donem_dropdown'),
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
                      const SizedBox(height: 16),
                      _TotalTile(
                        label: l10n.butGelir,
                        kurus: s.toplamGelirKurus,
                        color: Colors.green,
                        icon: Icons.trending_up,
                      ),
                      const SizedBox(height: 8),
                      _TotalTile(
                        label: l10n.butGider,
                        kurus: s.toplamGiderKurus,
                        color: Colors.red,
                        icon: Icons.trending_down,
                      ),
                      const SizedBox(height: 8),
                      _TotalTile(
                        label: l10n.butKasa,
                        kurus: s.bakiyeKurus,
                        color: s.bakiyeKurus < 0 ? Colors.red : Colors.blue,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      if (s.kategoriler.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          l10n.butKategoriToplamlari,
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
                              tlSonEkli(k.toplamKurus, dil),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        l10n.butSeffaflikNotu,
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
        // Etiket + tutar TEK satirda: `trailing:` kullanildiginda 7+ haneli
        // tutar dar ekranda (320 dp) tum tile genisligini tuketip
        // ListTile'i dusuruyordu (TR'de de olusan mevcut hata). Gorunum
        // ayni; fark yalniz tutarin esnetilebilir olmasi.
        title: Row(
          children: [
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            // Tutar KIRPILMAZ, gerekirse KUCULUR: milyonluk site butcesi
            // 18 dp kalin puntoyla dar ekrana (<= 360 dp) sigmiyor.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  tlSonEkli(kurus, context.dilKodu),
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
