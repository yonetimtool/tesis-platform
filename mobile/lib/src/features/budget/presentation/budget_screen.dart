import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../data/budget_api.dart';
import '../domain/budget_models.dart';
import 'butce_tip_adi.dart';

/// Butce ekrani (Wave 2A — yonetici):
///   * Ozet: gelir / gider / kasa (donem filtresiyle),
///   * Hareketler: defter listesi + manuel gelir-gider girisi,
///   * Kategoriler: dinamik kategori yonetimi (olustur + aktif/pasif).
/// Tutarlar API'de KURUS, ekranda TL (bkz. budget_models donusumleri).
/// Sakin gorunumu Wave 2B'de eklenecek (bu ekran yalniz yonetim menusunde).
class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  BudgetSummary? _summary;
  List<BudgetEntry>? _entries;
  List<BudgetCategory>? _categories;

  /// Hata KANALI ikilidir (README §15): [_error] SUNUCU metnini, [_hataKimligi]
  /// yerellestirilebilir kimligi tasir.
  String? _error;
  AkisHatasi? _hataKimligi;

  /// 'YYYY-MM' veya null (tum zamanlar) — Ozet + Hareketler'i filtreler.
  String? _donem;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final api = ref.read(budgetApiProvider);
    setState(() {
      _error = null;
      _hataKimligi = null;
    });
    try {
      final results = await Future.wait([
        api.fetchSummary(donem: _donem),
        api.fetchEntries(donem: _donem),
        api.fetchCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as BudgetSummary;
        _entries = results[1] as List<BudgetEntry>;
        _categories = results[2] as List<BudgetCategory>;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = apiHataMetni(context.l10n, e));
      }
    } catch (_) {
      if (mounted) setState(() => _hataKimligi = AkisHatasi.beklenmeyen);
    }
  }

  /// Son 12 ay + "Tumu" secenekleri (donem filtresi).
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
    final l10n = context.l10n;
    final hata = akisHatasiCoz(l10n, _hataKimligi, _error);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(baslikBuyuk(l10n.butBaslik, context.dilKodu)),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.butSekmeOzet),
              Tab(text: l10n.butSekmeHareketler),
              Tab(text: l10n.butSekmeKategoriler),
            ],
          ),
        ),
        body: hata != null
            ? _ErrorRetry(message: hata, onRetry: _reload)
            : (_summary == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      _SummaryTab(
                        summary: _summary!,
                        donem: _donem,
                        donemItems: _donemItems(l10n),
                        onDonemChanged: (v) {
                          setState(() => _donem = v);
                          _reload();
                        },
                      ),
                      _EntriesTab(
                        entries: _entries ?? const [],
                        categories: _categories ?? const [],
                        onCreated: _reload,
                      ),
                      _CategoriesTab(
                        categories: _categories ?? const [],
                        onChanged: _reload,
                      ),
                    ],
                  )),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.l10n.ortakTekrarDene),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------- OZET -------------------------------------- //
class _SummaryTab extends StatelessWidget {
  const _SummaryTab({
    required this.summary,
    required this.donem,
    required this.donemItems,
    required this.onDonemChanged,
  });

  final BudgetSummary summary;
  final String? donem;
  final List<DropdownMenuItem<String?>> donemItems;
  final ValueChanged<String?> onDonemChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final kasaNegatif = summary.bakiyeKurus < 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String?>(
          key: const Key('summary_donem_dropdown'),
          // `isExpanded` OLMAZSA dropdown ic Row'u icerigi kadar genisler:
          // uzun etiket (de) + prefixIcon 320 dp'de +30 px tasiriyordu
          // (tur 26 surusu). README §15'in "dropdown + uzun deger" kalibi.
          isExpanded: true,
          initialValue: donem,
          items: donemItems,
          onChanged: onDonemChanged,
          decoration: InputDecoration(
            labelText: l10n.butDonem,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.calendar_month_outlined),
          ),
        ),
        const SizedBox(height: 16),
        _AmountCard(
          label: l10n.butGelir,
          kurus: summary.toplamGelirKurus,
          color: Colors.green,
          icon: Icons.trending_up,
        ),
        const SizedBox(height: 8),
        _AmountCard(
          label: l10n.butGider,
          kurus: summary.toplamGiderKurus,
          color: Colors.red,
          icon: Icons.trending_down,
        ),
        const SizedBox(height: 8),
        _AmountCard(
          label: l10n.butKasa,
          kurus: summary.bakiyeKurus,
          color: kasaNegatif ? Colors.red : Colors.blue,
          icon: Icons.account_balance_wallet_outlined,
        ),
        if (summary.kategoriler.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.butKategoriKirilimi,
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final k in summary.kategoriler)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                k.tip == BudgetTip.gelir
                    ? Icons.add_circle_outline
                    : Icons.remove_circle_outline,
                color: k.tip == BudgetTip.gelir ? Colors.green : Colors.red,
              ),
              // `trailing:` ile tutar SIKISTIRILAMAZ; dar ekranda (320 dp)
              // uzun kategori adi + 7 haneli tutar tile'i tasiriyordu
              // (tur 26 surusu `de`de +30 px olctu). Ayni cozum `_AmountCard`
              // icinde de var: etiket ELLIPSIS, tutar KUCULUR.
              title: Row(
                children: [
                  Expanded(child: Text(k.ad, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(
                        tlSonEkli(k.toplamKurus, dil),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({
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

// ----------------------------- HAREKETLER ---------------------------------- //
class _EntriesTab extends ConsumerWidget {
  const _EntriesTab({
    required this.entries,
    required this.categories,
    required this.onCreated,
  });

  final List<BudgetEntry> entries;
  final List<BudgetCategory> categories;
  final Future<void> Function() onCreated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'budget_new_entry',
        onPressed: () async {
          final saved = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _EntryForm(
              categories: categories.where((c) => c.aktif).toList(),
            ),
          );
          if (saved == true) await onCreated();
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.butYeniHareket),
      ),
      body: entries.isEmpty
          ? Center(child: Text(l10n.butHareketYok))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                final gelir = e.tip == BudgetTip.gelir;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      gelir ? Icons.add_circle : Icons.remove_circle,
                      color: gelir ? Colors.green : Colors.red,
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(e.kategoriAd ?? l10n.butKategori)),
                        // Rozet de KUCULEBILIR: dar ekranda 7 haneli tutar
                        // basligi 30 dp'ye sikistirdiginda sabit genislikli
                        // rozet satiri tasiriyordu (TR'de de olusuyordu).
                        if (e.otomatik)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                l10n.butOtomatik,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.blue),
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${tarihBicimi(e.tarih, dil)}'
                      '${e.aciklama == null ? '' : ' · ${e.aciklama}'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      tlSonEkli(e.tutarKurus, dil, onEk: gelir ? '+' : '-'),
                      style: TextStyle(
                        color: gelir ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Manuel gelir/gider girisi. Tutar TL girilir, KURUS gonderilir.
class _EntryForm extends ConsumerStatefulWidget {
  const _EntryForm({required this.categories});

  final List<BudgetCategory> categories;

  @override
  ConsumerState<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends ConsumerState<_EntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _tutarCtrl = TextEditingController();
  final _aciklamaCtrl = TextEditingController();
  BudgetCategory? _kategori;
  DateTime _tarih = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _tutarCtrl.dispose();
    _aciklamaCtrl.dispose();
    super.dispose();
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(budgetApiProvider).createEntry(
            kategoriId: _kategori!.id,
            tutarKurus: parseTlToKurus(_tutarCtrl.text)!,
            tarih: _tarih,
            aciklama: _aciklamaCtrl.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = apiHataMetni(_l10n, e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _l10n.ortakBeklenmeyenHata;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.butYeniHareket,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<BudgetCategory>(
                isExpanded: true,
                key: const Key('entry_category_dropdown'),
                initialValue: _kategori,
                items: [
                  for (final c in widget.categories)
                    DropdownMenuItem(
                      value: c,
                      child: Text(
                        l10n.butKategoriTip(c.ad, butceTipAdi(l10n, c.tip)),
                      ),
                    ),
                ],
                onChanged:
                    _saving ? null : (v) => setState(() => _kategori = v),
                decoration: InputDecoration(
                  labelText: l10n.butKategori,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v == null ? l10n.butKategoriSecin : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tutarCtrl,
                enabled: !_saving,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.butTutar,
                  hintText: l10n.butTutarIpucu,
                  border: const OutlineInputBorder(),
                  suffixText: 'TL',
                ),
                validator: (v) => parseTlToKurus(v ?? '') == null
                    ? l10n.butTutarGecersiz
                    : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _tarih,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(
                            const Duration(days: 366),
                          ),
                        );
                        if (picked != null) setState(() => _tarih = picked);
                      },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  l10n.butTarih(tarihBicimi(_tarih, context.dilKodu)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _aciklamaCtrl,
                enabled: !_saving,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: l10n.gorevAciklamaOpsiyonel,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(
                    _saving ? l10n.ortakKaydediliyor : l10n.ortakKaydet),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------- KATEGORILER --------------------------------- //
class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab({required this.categories, required this.onChanged});

  final List<BudgetCategory> categories;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'budget_new_category',
        onPressed: () async {
          final saved = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _CategoryForm(),
          );
          if (saved == true) await onChanged();
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.butYeniKategori),
      ),
      body: categories.isEmpty
          ? Center(child: Text(l10n.butKategoriYok))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: categories.length,
              itemBuilder: (context, i) {
                final c = categories[i];
                final gelir = c.tip == BudgetTip.gelir;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: SwitchListTile(
                    secondary: Icon(
                      gelir ? Icons.add_circle_outline : Icons.remove_circle_outline,
                      color: gelir ? Colors.green : Colors.red,
                    ),
                    title: Text(c.ad),
                    subtitle: Text(
                      '${butceTipAdi(l10n, c.tip)}'
                      '${c.aktif ? '' : l10n.butPasifEki}',
                    ),
                    value: c.aktif,
                    // Kapatmak = soft-delete: eski kayitlar korunur.
                    onChanged: (v) async {
                      try {
                        await ref
                            .read(budgetApiProvider)
                            .updateCategory(c.id, aktif: v);
                        await onChanged();
                      } on ApiException catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(apiHataMetni(context.l10n, e))),
                          );
                        }
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm();

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  final _formKey = GlobalKey<FormState>();
  final _adCtrl = TextEditingController();
  BudgetTip _tip = BudgetTip.gider;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _adCtrl.dispose();
    super.dispose();
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(budgetApiProvider)
          .createCategory(ad: _adCtrl.text.trim(), tip: _tip);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = apiHataMetni(_l10n, e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _l10n.ortakBeklenmeyenHata;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.butYeniKategori,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _adCtrl,
              enabled: !_saving,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: l10n.butKategoriAdi,
                hintText: l10n.butKategoriAdiIpucu,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.butAdZorunlu : null,
            ),
            const SizedBox(height: 8),
            SegmentedButton<BudgetTip>(
              segments: [
                ButtonSegment(
                  value: BudgetTip.gelir,
                  label: Text(l10n.butGelir),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                ButtonSegment(
                  value: BudgetTip.gider,
                  label: Text(l10n.butGider),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
              selected: {_tip},
              onSelectionChanged:
                  _saving ? null : (s) => setState(() => _tip = s.single),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child:
                  Text(_saving ? l10n.ortakKaydediliyor : l10n.ortakKaydet),
            ),
          ],
        ),
      ),
    );
  }
}
