/// (P164) BINA DUZENLEME — YAPISAL ARAC DIYALOGLARI.
///
/// =========================================================================
/// NEDEN VAR
/// =========================================================================
/// `docs/web-mobil-esitlik.md` P163'te olcmustu: kat silme, daire tipi
/// toplu degistirme ve suruklemeli siralama WEBDE VARDI, MOBILDE YOKTU.
/// Uclarin hepsi (`POST /units/kat-sil`, `PATCH /units/toplu`,
/// `PATCH /units/siralama`) zaten mevcuttu; eksik olan istemci tarafiydi.
///
/// =========================================================================
/// UCU DE AYNI KURALLARA UYAR
/// =========================================================================
///  * YIKICI ISLEM ONAY ISTER ve onay metni NE SILINECEGINI yazar.
///  * BOS ISTEK ATILMAZ: kaydet dugmesi, gonderilecek bir sey yoksa
///    kapalidir — "yaptim" deyip hicbir sey yapmamak en kotu sonuctur.
///  * HATA SESSIZ KALMAZ: sunucu mesaji diyalogda gorunur, kapanip
///    kaybolmaz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../data/bina_duzenleme_api.dart';
import '../domain/bina_duzenleme_models.dart';
import '../domain/daire_araligi.dart';
import 'bina_duzenleme_controller.dart';

/// Acik bloktaki daireleri verir; blok yoksa bloksuz kovayi.
List<EditorUnit> _daireler(BinaDuzenlemeState state, String? blok) {
  if (blok == null || blok.isEmpty) return state.blocklessUnits;
  return state.unitsForBlock(blok);
}

// ===========================================================================
// KAT SIL
// ===========================================================================

class KatSilDialog extends ConsumerStatefulWidget {
  const KatSilDialog({super.key, required this.blok});

  final String? blok;

  @override
  ConsumerState<KatSilDialog> createState() => _KatSilDialogState();
}

class _KatSilDialogState extends ConsumerState<KatSilDialog> {
  int? _kat;
  String? _hata;
  bool _mesgul = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(binaDuzenlemeControllerProvider);
    final daireler = _daireler(state, widget.blok);
    // KATLAR VERIDEN: elle sayi yazdirmak, olmayan bir kati silmeye
    // calismak demekti. Yalnizca GERCEKTEN VAR OLAN katlar listelenir.
    final katlar = <int>{
      for (final u in daireler)
        if (u.kat != null) u.kat!,
    }.toList()..sort();

    final silinecek = _kat == null
        ? 0
        : daireler.where((u) => u.kat == _kat).length;

    return AlertDialog(
      title: Text(l10n.binaKatSil),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (katlar.isEmpty)
            Text(l10n.binaKatYok)
          else
            DropdownButtonFormField<int>(
              initialValue: _kat,
              decoration: InputDecoration(labelText: l10n.binaKat),
              items: [
                for (final k in katlar)
                  DropdownMenuItem(
                    value: k,
                    child: Text(l10n.binaKatEtiket(k)),
                  ),
              ],
              onChanged: (v) => setState(() {
                _kat = v;
                _hata = null;
              }),
            ),
          if (_kat != null) ...[
            const SizedBox(height: 12),
            // NE SILINECEGI ACIKCA YAZAR: "kati sil" tek basina kac
            // dairenin gidecegini soylemiyordu.
            Text(l10n.binaKatSilOzet(silinecek)),
          ],
          if (_hata != null) ...[
            const SizedBox(height: 12),
            Text(
              _hata!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _mesgul ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.ortakIptal),
        ),
        FilledButton(
          onPressed: (_kat == null || _mesgul) ? null : _sil,
          child: Text(l10n.ortakSil),
        ),
      ],
    );
  }

  Future<void> _sil() async {
    final l10n = context.l10n;
    // IKINCI ONAY: kat silme geri alinamaz ve altindaki TUM daireleri
    // goturur. Tek dokunusla olmasi dogru degil.
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.ortakEminMisiniz),
        content: Text(l10n.binaKatSilOnay(_kat!)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(l10n.ortakIptal),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(l10n.ortakSil),
          ),
        ],
      ),
    );
    if (onay != true) return;

    setState(() => _mesgul = true);
    try {
      await ref
          .read(binaDuzenlemeControllerProvider.notifier)
          .deleteFloor(blok: widget.blok ?? '', kat: _kat!);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      // Sunucu mesaji EKRANDA kalir; diyalog kapanmaz.
      if (mounted) setState(() => _hata = e.message);
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }
}

// ===========================================================================
// DAIRE TIPI TOPLU DEGISTIR (numara ile secim)
// ===========================================================================

class TopluTipDialog extends ConsumerStatefulWidget {
  const TopluTipDialog({super.key, required this.blok});

  final String? blok;

  @override
  ConsumerState<TopluTipDialog> createState() => _TopluTipDialogState();
}

class _TopluTipDialogState extends ConsumerState<TopluTipDialog> {
  final _ifadeCtrl = TextEditingController();
  List<String> _secili = const [];
  List<String> _bulunamayan = const [];
  bool? _aktif;
  String? _hata;
  bool _mesgul = false;

  @override
  void dispose() {
    _ifadeCtrl.dispose();
    super.dispose();
  }

  void _uygula() {
    final state = ref.read(binaDuzenlemeControllerProvider);
    final daireler = _daireler(state, widget.blok);
    final sonuc = aralikCoz(_ifadeCtrl.text, [
      for (final u in daireler) AralikSatiri(id: u.id, no: u.no),
    ]);
    setState(() {
      _secili = sonuc.idler;
      // ESLESMEYEN PARCA SESSIZCE DUSMEZ: "12 daire sectim" deyip
      // 9'unu islemek en kotu sonuctur.
      _bulunamayan = sonuc.bulunamayan;
      _hata = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.binaTopluTip),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ifadeCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.binaAralikSec,
                      hintText: '3,5,7-12',
                    ),
                    onSubmitted: (_) => _uygula(),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _uygula,
                  child: Text(l10n.binaAralikUygula),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.binaSeciliSayisi(_secili.length)),
            if (_bulunamayan.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                l10n.binaAralikBulunamayan(_bulunamayan.join(', ')),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            // TIP SECIMI BU TURDA YOK: mobilde daire tipi listesi ucu
            // (`/tanimlar/unit-tipleri`) bu ekranda cekilmiyor. Yarim bir
            // secici koymaktansa DURUM degisimi sunuluyor; tip degisimi
            // tanim listesi baglandiginda eklenir.
            DropdownButtonFormField<bool>(
              initialValue: _aktif,
              decoration: InputDecoration(labelText: l10n.ortakDurum),
              items: [
                DropdownMenuItem(value: true, child: Text(l10n.ortakAktif)),
                DropdownMenuItem(value: false, child: Text(l10n.ortakPasif)),
              ],
              onChanged: (v) => setState(() => _aktif = v),
            ),
            if (_hata != null) ...[
              const SizedBox(height: 12),
              Text(
                _hata!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _mesgul ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.ortakIptal),
        ),
        FilledButton(
          // BOS ISTEK ATILMAZ: secim yoksa ya da degistirilecek alan
          // yoksa dugme kapalidir.
          onPressed: (_secili.isEmpty || _aktif == null || _mesgul)
              ? null
              : _kaydet,
          child: Text(l10n.ortakKaydet),
        ),
      ],
    );
  }

  Future<void> _kaydet() async {
    setState(() => _mesgul = true);
    try {
      await ref
          .read(binaDuzenlemeControllerProvider.notifier)
          .bulkUpdateUnits(unitIds: _secili, aktif: _aktif);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _hata = e.message);
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }
}

// ===========================================================================
// SIRALAMA (suruklemeli)
// ===========================================================================

class SiralamaDialog extends ConsumerStatefulWidget {
  const SiralamaDialog({super.key, required this.blok});

  final String? blok;

  @override
  ConsumerState<SiralamaDialog> createState() => _SiralamaDialogState();
}

class _SiralamaDialogState extends ConsumerState<SiralamaDialog> {
  int? _kat;
  List<EditorUnit> _sira = [];
  String? _hata;
  bool _mesgul = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(binaDuzenlemeControllerProvider);
    final daireler = _daireler(state, widget.blok);
    final katlar = <int>{
      for (final u in daireler)
        if (u.kat != null) u.kat!,
    }.toList()..sort();

    return AlertDialog(
      title: Text(l10n.binaSiralama),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (katlar.isEmpty)
              Text(l10n.binaKatYok)
            else
              DropdownButtonFormField<int>(
                initialValue: _kat,
                decoration: InputDecoration(labelText: l10n.binaKat),
                items: [
                  for (final k in katlar)
                    DropdownMenuItem(
                      value: k,
                      child: Text(l10n.binaKatEtiket(k)),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _kat = v;
                  // SIRA VERIDEN KURULUR: kullanicinin gordugu duzen ile
                  // kaydedilecek duzen ayni olmali.
                  _sira = daireler.where((u) => u.kat == v).toList()
                    ..sort((a, b) => (a.sira ?? 0).compareTo(b.sira ?? 0));
                  _hata = null;
                }),
              ),
            if (_sira.isNotEmpty) ...[
              const SizedBox(height: 8),
              Flexible(
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  itemCount: _sira.length,
                  // `onReorderItem` KULLANILIYOR, `onReorder` DEGIL:
                  // eskisi asagi tasimada hedef indeksi bir fazla verir ve
                  // her cagrida elle duzeltilmesi gerekirdi (unutulmasi
                  // kolay bir tuzak). Yenisi duzeltmeyi kendisi yapar.
                  onReorderItem: (eski, yeni) => setState(() {
                    final oge = _sira.removeAt(eski);
                    _sira.insert(yeni, oge);
                  }),
                  itemBuilder: (context, i) => ListTile(
                    key: ValueKey(_sira[i].id),
                    dense: true,
                    leading: const Icon(Icons.drag_handle),
                    title: Text(_sira[i].no),
                  ),
                ),
              ),
            ],
            if (_hata != null) ...[
              const SizedBox(height: 12),
              Text(
                _hata!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _mesgul ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.ortakIptal),
        ),
        FilledButton(
          onPressed: (_sira.isEmpty || _mesgul) ? null : _kaydet,
          child: Text(l10n.ortakKaydet),
        ),
      ],
    );
  }

  Future<void> _kaydet() async {
    setState(() => _mesgul = true);
    try {
      // TEK ISTEK: daire basina ayri `PATCH` atmak, yirmi dairelik bir
      // katta yirmi istek ve arada kesilme riski demekti — yarim
      // uygulanmis bir siralama, gorulen duzen ile kaydi ayirirdi.
      await ref.read(binaDuzenlemeControllerProvider.notifier).reorderUnits([
        for (var i = 0; i < _sira.length; i++)
          UnitSiraSatiri(id: _sira[i].id, kat: _kat!, sira: i + 1),
      ]);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _hata = e.message);
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }
}
