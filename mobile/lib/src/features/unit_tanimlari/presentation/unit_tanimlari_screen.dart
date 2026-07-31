import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../data/unit_tanim_api.dart';
import '../domain/unit_tanim_models.dart';

/// "Bağımsız Bölüm Tanımları" (P26) — TIPLER + GRUPLAR, iki sekme.
///
/// IKI AYRI KAVRAM: GRUP bolumun NE OLDUGU (Daire / Villa / Dukkan), TIP
/// buyukluk/duzen (1+0, 2+1, dubleks) + VARSAYILAN AIDAT. Ad SERBEST metindir:
/// hazir bir liste sunulmaz, kullanici ne yazarsa o.
///
/// TEK EKRAN IKI SEKME (iki ayri ekran DEGIL): ikisi de ayni kucuk tanim
/// listesidir ve kullanici site kurarken art arda ikisini de doldurur;
/// menude iki ayri giris, ayrimi anlatmak yerine kalabalik yapardi.
class UnitTanimlariScreen extends ConsumerWidget {
  const UnitTanimlariScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(baslikBuyuk(l10n.modulDaireTanimlari, context.dilKodu)),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.daireTanimSekmeTipler),
              Tab(text: l10n.daireTanimSekmeGruplar),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TanimListesi(tipMi: true),
            _TanimListesi(tipMi: false),
          ],
        ),
      ),
    );
  }
}

class _TanimListesi extends ConsumerWidget {
  const _TanimListesi({required this.tipMi});

  final bool tipMi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = tipMi
        ? ref.watch(unitTipleriProvider)
        : ref.watch(unitGruplariProvider);

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Text(
                akisHatasiCoz(
                      l10n,
                      e is ApiException ? e.agHatasi : AkisHatasi.beklenmeyen,
                      e is ApiException ? e.message : null,
                    ) ??
                    l10n.ortakBeklenmeyenHata,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        data: (liste) => RefreshIndicator(
          onRefresh: () async => _tazele(ref),
          child: liste.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: Text(l10n.daireTanimYok, textAlign: TextAlign.center),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: liste.length,
                  itemBuilder: (context, i) => _TanimKarti(
                    tanim: liste[i],
                    tipMi: tipMi,
                    onDuzenle: () => _formAc(context, ref, mevcut: liste[i]),
                    onSil: () => _sil(context, ref, liste[i]),
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _formAc(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.daireTanimYeni),
      ),
    );
  }

  void _tazele(WidgetRef ref) => ref.invalidate(
        tipMi ? unitTipleriProvider : unitGruplariProvider,
      );

  Future<void> _formAc(
    BuildContext context,
    WidgetRef ref, {
    UnitTanim? mevcut,
  }) async {
    final kaydedildi = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TanimFormu(tipMi: tipMi, mevcut: mevcut),
    );
    if (kaydedildi == true) _tazele(ref);
  }

  Future<void> _sil(
    BuildContext context,
    WidgetRef ref,
    UnitTanim tanim,
  ) async {
    final l10n = context.l10n;
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tanim.ad),
        // Onay metni KAC daireyi etkiledigini SOYLER: "sil" demeden once
        // sonucun buyuklugu bilinmeli.
        content: Text(l10n.daireTanimSilOnay(tanim.daireSayisi)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.ortakVazgec),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.ortakSil),
          ),
        ],
      ),
    );
    if (onay != true || !context.mounted) return;
    final api = ref.read(unitTanimApiProvider);
    final mesajci = ScaffoldMessenger.of(context);
    try {
      final etkilenen =
          tipMi ? await api.deleteTip(tanim.id) : await api.deleteGrup(tanim.id);
      mesajci.showSnackBar(
        SnackBar(content: Text(l10n.daireTanimSilindiEtki(etkilenen))),
      );
      _tazele(ref);
    } on ApiException catch (e) {
      mesajci.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _TanimKarti extends StatelessWidget {
  const _TanimKarti({
    required this.tanim,
    required this.tipMi,
    required this.onDuzenle,
    required this.onSil,
  });

  final UnitTanim tanim;
  final bool tipMi;
  final VoidCallback onDuzenle;
  final VoidCallback onSil;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tip = tanim is UnitTip ? tanim as UnitTip : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onDuzenle,
        title: Text(tanim.ad),
        subtitle: Text(
          [
            l10n.daireTanimDaireSayisi(tanim.daireSayisi),
            if (tip != null)
              '${l10n.daireTanimVarsayilanAidat}: '
                  '${tip.varsayilanAidatKurus == null ? l10n.daireTanimAidatBos : tlIsaretli(tip.varsayilanAidatKurus!, context.dilKodu)}',
          ].join(' · '),
        ),
        trailing: IconButton(
          tooltip: l10n.ortakSil,
          icon: const Icon(Icons.delete_outline),
          onPressed: onSil,
        ),
      ),
    );
  }
}

class _TanimFormu extends ConsumerStatefulWidget {
  const _TanimFormu({required this.tipMi, this.mevcut});

  final bool tipMi;
  final UnitTanim? mevcut;

  @override
  ConsumerState<_TanimFormu> createState() => _TanimFormuState();
}

class _TanimFormuState extends ConsumerState<_TanimFormu> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _adCtrl;
  late final TextEditingController _aidatCtrl;
  late bool _aktif;
  bool _kaydediyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    final m = widget.mevcut;
    _adCtrl = TextEditingController(text: m?.ad ?? '');
    final tip = m is UnitTip ? m : null;
    _aidatCtrl = TextEditingController(
      // KURUS -> TL: kullanici lira girer, sunucu kurus bekler.
      text: tip?.varsayilanAidatKurus == null
          ? ''
          : (tip!.varsayilanAidatKurus! / 100).toStringAsFixed(2),
    );
    _aktif = m?.aktif ?? true;
  }

  @override
  void dispose() {
    _adCtrl.dispose();
    _aidatCtrl.dispose();
    super.dispose();
  }

  /// TL metnini KURUS'a cevirir. Bos metin `null` doner — "tanimsiz" ile
  /// "0 (muaf)" AYRI seylerdir.
  int? _kurus(String metin) {
    final temiz = metin.trim().replaceAll(',', '.');
    if (temiz.isEmpty) return null;
    final lira = double.tryParse(temiz);
    if (lira == null) return null;
    return (lira * 100).round();
  }

  Future<void> _kaydet() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _kaydediyor = true;
      _hata = null;
    });
    final api = ref.read(unitTanimApiProvider);
    final metin = _aidatCtrl.text.trim();
    final taslak = UnitTanimDraft(
      ad: _adCtrl.text.trim(),
      aktif: _aktif,
      varsayilanAidatKurus: _kurus(metin),
      // Tip formunda alan HER ZAMAN gonderilir: bos birakmak "tutari kaldir"
      // demektir ve gondermemek onu sessizce eski degerinde birakirdi.
      aidatGirildi: widget.tipMi,
    );
    try {
      final id = widget.mevcut?.id;
      if (widget.tipMi) {
        id == null
            ? await api.createTip(taslak)
            : await api.updateTip(id, taslak);
      } else {
        id == null
            ? await api.createGrup(taslak)
            : await api.updateGrup(id, taslak);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _kaydediyor = false;
        _hata = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.tipMi
                    ? l10n.daireTanimSekmeTipler
                    : l10n.daireTanimSekmeGruplar,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adCtrl,
                enabled: !_kaydediyor,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: '${l10n.daireTanimAd} *',
                  // Ipucu ORNEKTIR, hazir liste degil: ad serbest metindir.
                  hintText: l10n.daireTanimAdIpucu,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? l10n.ortakZorunluAlan(l10n.daireTanimAd)
                    : null,
              ),
              if (widget.tipMi) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _aidatCtrl,
                  enabled: !_kaydediyor,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.daireTanimVarsayilanAidat,
                    helperText: l10n.daireTanimAidatAlt,
                    helperMaxLines: 3,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final metin = (v ?? '').trim();
                    if (metin.isEmpty) return null; // tanimsiz — gecerli
                    final k = _kurus(metin);
                    if (k == null || k < 0) {
                      // Butcedeki tutar dogrulamasiyla AYNI metin
                      // (kullanici iki yerde farkli cumle gormesin).
                      return l10n.butTutarGecersiz;
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.kameraAktif),
                value: _aktif,
                onChanged:
                    _kaydediyor ? null : (v) => setState(() => _aktif = v),
              ),
              if (_hata != null) ...[
                const SizedBox(height: 8),
                Text(
                  _hata!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _kaydediyor ? null : _kaydet,
                child: Text(l10n.ortakKaydet),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
