/// (P253 Asama 2) TEKIL BORCLANDIRMA — web `TekilModal` karsiligi.
///
/// Govde web ile AYNI (`POST /dues/assessments`): daire, tur, tarih (donem
/// tarihten turer), son odeme, tutar, aciklama, gecikme. §C-1: kaydetmeden
/// once TUTAR ve HEDEF ("A-12 · Eylul aidati") yazili onay diyalogu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/girdi_siniri.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/para.dart';
import '../../../core/ui/finans_onay.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../data/borclandirma_api.dart';
import '../domain/borclandirma_models.dart';
import 'borc_etiketleri.dart';

/// Formu acar; kaydedildiyse `true`.
Future<bool?> tekilBorclandirmaAc(BuildContext context, {String? unitId}) =>
    merkezSayfaAc<bool>(context, builder: (_) => TekilBorclandirmaFormu(unitId: unitId));

class TekilBorclandirmaFormu extends ConsumerStatefulWidget {
  const TekilBorclandirmaFormu({super.key, this.unitId});

  /// Verilirse daire secili gelir (daire borc durumundan acilinca).
  final String? unitId;

  @override
  ConsumerState<TekilBorclandirmaFormu> createState() => _TekilState();
}

class _TekilState extends ConsumerState<TekilBorclandirmaFormu> {
  final _tutar = TextEditingController();
  final _aciklama = TextEditingController();
  String? _daireId;
  String? _turId;
  DateTime _tarih = DateTime.now();
  DateTime? _sonOdeme;
  bool _gecikme = true;
  bool _mesgul = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _daireId = widget.unitId;
  }

  @override
  void dispose() {
    _tutar.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  Future<void> _kaydet(List<DaireKisa> daireler, List<BorcTuru> turler) async {
    final l10n = context.l10n;
    final kurus = tlMetniniKurusaCevir(_tutar.text);
    if (_daireId == null) return setState(() => _hata = l10n.brcDaireSec);
    if (_turId == null) return setState(() => _hata = l10n.brcTurSec);
    if (kurus == null || kurus <= 0) return setState(() => _hata = l10n.brcTutarGecersiz);
    setState(() => _hata = null);
    final daire = daireler.where((d) => d.id == _daireId).firstOrNull;
    final tur = turler.where((t) => t.id == _turId).firstOrNull;
    final donem = donemden(_tarih);
    final onay = await finansOnayla(
      context,
      baslik: l10n.brcOnayBaslik,
      hedef: hedefMetni([daire?.no, tur?.ad, l10n.brcDonem(donem)]),
      tutar: tlTutar(kurus),
      sonuc: l10n.brcOnaySonuc,
      onayMetni: l10n.brcKaydet,
    );
    if (onay == null || !mounted) return;
    setState(() => _mesgul = true);
    try {
      await ref.read(borclandirmaApiProvider).tekil(
            unitId: _daireId!,
            donem: donem,
            tutarKurus: kurus,
            tanimId: _turId,
            tarih: _tarih,
            sonOdeme: _sonOdeme,
            aciklama: _aciklama.text.trim().isEmpty ? null : _aciklama.text.trim(),
            gecikmeUygula: _gecikme,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.brcKaydedildi)));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _mesgul = false;
        _hata = e.message.isNotEmpty ? e.message : l10n.ortakBeklenmeyenHata;
      });
    }
  }

  Future<void> _tarihSec({required bool son}) async {
    final simdi = DateTime.now();
    final secilen = await showDatePicker(
      context: context,
      initialDate: (son ? _sonOdeme : _tarih) ?? _tarih,
      firstDate: DateTime(simdi.year - 5),
      lastDate: DateTime(simdi.year + 2, 12, 31),
    );
    if (secilen == null) return;
    setState(() => son ? _sonOdeme = secilen : _tarih = secilen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final daireler = ref.watch(borcDairelerProvider).value ?? const [];
    final turler = ref.watch(borcTurleriProvider).value ?? const [];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.brcTekil, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('brc-tekil-daire'),
              isExpanded: true,
              initialValue: _daireId,
              decoration: InputDecoration(labelText: l10n.brcDaire, border: const OutlineInputBorder()),
              hint: Text(l10n.brcDaireSec),
              items: [
                for (final d in daireler) DropdownMenuItem(value: d.id, child: Text(d.no)),
              ],
              onChanged: _mesgul ? null : (v) => setState(() => _daireId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('brc-tekil-tur'),
              isExpanded: true,
              initialValue: _turId,
              decoration: InputDecoration(labelText: l10n.brcTur, border: const OutlineInputBorder()),
              hint: Text(l10n.brcTurSec),
              items: [
                for (final t in turler)
                  DropdownMenuItem(value: t.id, child: Text(t.ad, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: _mesgul ? null : (v) => setState(() => _turId = v),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('brc-tekil-tarih'),
              icon: const Icon(Icons.event_outlined),
              label: Text(l10n.brcTarihDegeri(tarihBicimi(_tarih, dil))),
              onPressed: _mesgul ? null : () => _tarihSec(son: false),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('brc-tekil-son-odeme'),
              icon: const Icon(Icons.event_busy_outlined),
              label: Text(_sonOdeme == null
                  ? l10n.brcSonOdemeYok
                  : l10n.brcSonOdemeDegeri(tarihBicimi(_sonOdeme!, dil))),
              onPressed: _mesgul ? null : () => _tarihSec(son: true),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('brc-tekil-tutar'),
              controller: _tutar,
              enabled: !_mesgul,
              maxLength: GirdiSiniri.tutar,
              inputFormatters: GirdiSiniri.sinir(GirdiSiniri.tutar),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.brcTutar, border: const OutlineInputBorder()),
            ),
            TextField(
              key: const Key('brc-tekil-aciklama'),
              controller: _aciklama,
              enabled: !_mesgul,
              maxLength: 500,
              inputFormatters: GirdiSiniri.sinir(500),
              decoration: InputDecoration(labelText: l10n.brcAciklama, border: const OutlineInputBorder()),
            ),
            SwitchListTile(
              key: const Key('brc-tekil-gecikme'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.brcGecikmeUygula),
              value: _gecikme,
              onChanged: _mesgul ? null : (v) => setState(() => _gecikme = v),
            ),
            if (_hata != null) ...[
              Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 8),
            ],
            FilledButton(
              key: const Key('brc-tekil-kaydet'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _mesgul ? null : () => _kaydet(daireler, turler),
              child: Text(l10n.brcKaydet),
            ),
          ],
        ),
      ),
    );
  }
}
