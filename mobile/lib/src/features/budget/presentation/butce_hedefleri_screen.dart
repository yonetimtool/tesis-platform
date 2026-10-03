import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/girdi_siniri.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/para.dart';
import '../../../core/ui/bos_durum.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../data/budget_api.dart';
import '../data/butce_hedef_api.dart';
import '../domain/budget_models.dart';

/// (P253 Asama 2) BUTCE HEDEFLERI — web `/finans/butce` karsiligi.
///
/// Ust kisim KARSILASTIRMA (hedef / gerceklesen / sapma; web ile ayni
/// sapma yorumu: giderde pozitif = asildi), alt kisim YAZILAN HEDEFLER
/// (sil). "Hedef yaz" ayni tur + donem icin GUNCELLER (sunucu kurali).
///
/// DENETCI SALT OKUR: GET uclari ona acik, yazma dugmeleri cizilmez
/// (sunucu da 403 verir).
class ButceHedefleriScreen extends ConsumerStatefulWidget {
  const ButceHedefleriScreen({super.key});

  @override
  ConsumerState<ButceHedefleriScreen> createState() => _ButceHedefleriScreenState();
}

class _ButceHedefleriScreenState extends ConsumerState<ButceHedefleriScreen> {
  int _yil = DateTime.now().year;
  ButceKarsilastirma? _kars;
  List<ButceHedefi>? _hedefler;
  List<BudgetCategory> _turler = const [];
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final api = ref.read(butceHedefApiProvider);
    setState(() => _hata = null);
    try {
      final sonuc = await Future.wait<Object>([
        api.karsilastirma(_yil),
        api.hedefler(_yil),
        ref.read(budgetApiProvider).fetchCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _kars = sonuc[0] as ButceKarsilastirma;
        _hedefler = sonuc[1] as List<ButceHedefi>;
        _turler = sonuc[2] as List<BudgetCategory>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _hata = apiHataMetni(context.l10n, e));
    }
  }

  void _yilDegis(int fark) {
    setState(() {
      _yil += fark;
      _kars = null;
      _hedefler = null;
    });
    _yukle();
  }

  String _turAdi(String id) =>
      _turler.where((t) => t.id == id).map((t) => t.ad).firstOrNull ?? '—';

  Future<void> _sil(ButceHedefi h) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final onay = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.bthSilBaslik),
        content: Text(l10n.bthSilOnay(
            _turAdi(h.kategoriId), h.donem ?? l10n.bthYillik, tlTutar(h.tutarKurus))),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: Text(l10n.ortakVazgec)),
          FilledButton(
            key: const Key('bth-sil-onay'),
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(l10n.bthSil),
          ),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await ref.read(butceHedefApiProvider).sil(h.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.bthSilindi)));
      await _yukle();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    }
  }

  Future<void> _yeni() async {
    final kaydedildi = await merkezSayfaAc<bool>(
      context,
      builder: (_) => _HedefFormu(yil: _yil, turler: _turler.where((t) => t.aktif).toList()),
    );
    if (kaydedildi == true) await _yukle();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rol = ref.watch(currentUserRoleProvider).value;
    final yazabilir = rol != null && rol != UserRole.denetci;
    final k = _kars;
    final hedefler = _hedefler;
    return Scaffold(
      appBar: AppBar(title: Text(baslikBuyuk(l10n.bthBaslik, context.dilKodu))),
      floatingActionButton: yazabilir && hedefler != null
          ? FloatingActionButton.extended(
              key: const Key('bth-yeni'),
              icon: const Icon(Icons.flag_outlined),
              label: Text(l10n.bthYeni),
              onPressed: _yeni,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _yukle,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('bth-onceki-yil'),
                  tooltip: l10n.bthOncekiYil,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _yilDegis(-1),
                ),
                Expanded(
                  child: Text(l10n.bthYil(_yil),
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  key: const Key('bth-sonraki-yil'),
                  tooltip: l10n.bthSonrakiYil,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _yilDegis(1),
                ),
              ],
            ),
            if (_hata != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              )
            else if (k == null || hedefler == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Text(l10n.bthKarsilastirma, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(l10n.bthToplamGelir(tlTutar(k.hedefGelir), tlTutar(k.gercekGelir))),
              Text(l10n.bthToplamGider(tlTutar(k.hedefGider), tlTutar(k.gercekGider))),
              const SizedBox(height: 8),
              for (final s in k.satirlar) _KarsilastirmaKarti(satir: s),
              const SizedBox(height: 16),
              Text(l10n.bthYazilanlar, style: Theme.of(context).textTheme.titleSmall),
              if (hedefler.isEmpty)
                BosDurum(
                  ikon: Icons.flag_outlined,
                  baslik: l10n.bthBos,
                  aciklama: _turler.isEmpty ? l10n.bthTurYok : l10n.bthBosRehber,
                )
              else
                for (final h in hedefler)
                  Card(
                    key: Key('bth-hedef-${h.id}'),
                    child: ListTile(
                      title: Text(_turAdi(h.kategoriId)),
                      subtitle: Text([h.donem ?? l10n.bthYillik, if (h.aciklama != null) h.aciklama!]
                          .join(' · ')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tlTutar(h.tutarKurus)),
                          if (yazabilir)
                            IconButton(
                              key: Key('bth-sil-${h.id}'),
                              tooltip: l10n.bthSil,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _sil(h),
                            ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KarsilastirmaKarti extends StatelessWidget {
  const _KarsilastirmaKarti({required this.satir});

  final ButceKarsilastirmaSatiri satir;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final renk = Theme.of(context).colorScheme;
    final oran = satir.hedefKurus > 0
        ? (satir.gerceklesenKurus / satir.hedefKurus).clamp(0.0, 1.0)
        : 0.0;
    final sapmaRengi = satir.sapmaKurus == 0
        ? renk.onSurfaceVariant
        : (satir.kotu ? renk.error : Colors.green.shade700);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(satir.ad, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: oran,
              color: satir.kotu && satir.sapmaKurus != 0 ? renk.error : renk.primary,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 2,
              children: [
                Text('${l10n.bthHedef}: ${tlTutar(satir.hedefKurus)}'),
                Text('${l10n.bthGerceklesen}: ${tlTutar(satir.gerceklesenKurus)}'),
                Text(
                  '${l10n.bthSapma}: ${tlTutar(satir.sapmaKurus)}'
                  '${satir.sapmaYuzde == null ? '' : ' (%${satir.sapmaYuzde})'}',
                  style: TextStyle(color: sapmaRengi),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HedefFormu extends ConsumerStatefulWidget {
  const _HedefFormu({required this.yil, required this.turler});

  final int yil;
  final List<BudgetCategory> turler;

  @override
  ConsumerState<_HedefFormu> createState() => _HedefFormuState();
}

class _HedefFormuState extends ConsumerState<_HedefFormu> {
  final _tutar = TextEditingController();
  final _aciklama = TextEditingController();
  String? _tur;

  /// null = yillik; 1..12 = o ay.
  int? _ay;
  bool _mesgul = false;
  String? _hata;

  @override
  void dispose() {
    _tutar.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  int? get _kurus => tlMetniniKurusaCevir(_tutar.text);

  Future<void> _kaydet() async {
    final l10n = context.l10n;
    final kurus = _kurus;
    if (_tur == null || kurus == null) return;
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      await ref.read(butceHedefApiProvider).yaz(
            yil: widget.yil,
            kategoriId: _tur!,
            tutarKurus: kurus,
            donem: _ay == null ? null : '${widget.yil}-${_ay.toString().padLeft(2, '0')}',
            aciklama: _aciklama.text.trim().isEmpty ? null : _aciklama.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.bthKaydedildi)));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _mesgul = false;
          _hata = apiHataMetni(l10n, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${l10n.bthYeni} · ${widget.yil}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('bth-tur'),
            isExpanded: true,
            initialValue: _tur,
            decoration: InputDecoration(labelText: l10n.bthTur, border: const OutlineInputBorder()),
            items: [
              for (final t in widget.turler)
                DropdownMenuItem(value: t.id, child: Text(t.ad, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: _mesgul ? null : (v) => setState(() => _tur = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            key: const Key('bth-donem'),
            isExpanded: true,
            initialValue: _ay,
            decoration: InputDecoration(labelText: l10n.bthDonem, border: const OutlineInputBorder()),
            items: [
              DropdownMenuItem<int?>(value: null, child: Text(l10n.bthYillik)),
              for (var ay = 1; ay <= 12; ay++)
                DropdownMenuItem<int?>(
                    value: ay, child: Text('${widget.yil}-${ay.toString().padLeft(2, '0')}')),
            ],
            onChanged: _mesgul ? null : (v) => setState(() => _ay = v),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('bth-tutar'),
            controller: _tutar,
            enabled: !_mesgul,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: GirdiSiniri.sinir(GirdiSiniri.tutar),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l10n.bthTutar, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('bth-aciklama'),
            controller: _aciklama,
            enabled: !_mesgul,
            maxLength: 500,
            decoration: InputDecoration(labelText: l10n.bthAciklama, border: const OutlineInputBorder()),
          ),
          Text(l10n.bthGuncellemeNotu, style: Theme.of(context).textTheme.bodySmall),
          if (_hata != null) ...[
            const SizedBox(height: 8),
            Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _mesgul ? null : () => Navigator.of(context).pop(false),
                child: Text(l10n.ortakVazgec),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('bth-kaydet'),
                onPressed: _mesgul || _tur == null || _kurus == null ? null : _kaydet,
                child: Text(l10n.ortakKaydet),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
