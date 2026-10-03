import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/girdi_siniri.dart';
import '../../../core/i18n/l10n.dart';
import '../data/rapor_motoru_api.dart';
import '../domain/rapor_motoru_models.dart';
import 'rapor_paylas.dart';
import 'rapor_tablo_screen.dart';

/// Secimli alanlarin listeleri (tur basina bir kez). Rol izni yoksa (403)
/// bos liste: alan yalniz "Tumu" ile cizilir — web ile ayni.
final raporSecenekleriProvider =
    FutureProvider.autoDispose.family<List<SecimOgesi>, AlanTuru>((ref, tur) async {
  try {
    return await ref.watch(raporMotoruApiProvider).secenekler(tur);
  } on ApiException {
    return const [];
  }
});

/// (P253 Asama 2) RAPOR PARAMETRE FORMU — web `RaporModali`nin karsiligi.
///
/// Alanlar KATALOGDAN gelir (`rapor.alanlar`); burada liste tutulmaz.
/// Uc eylem:
///   * GOSTER — tablo ekrani (Excel/PDF ile AYNI satirlar);
///   * EXCEL / PDF — hafif raporda dosya uretilir ve PAYLASILIR; agir
///     raporda (`agir`) is KUYRUGA alinir ve form `true` ile kapanir
///     (cagiran Islerim sekmesine gecer).
class RaporFormu extends ConsumerStatefulWidget {
  const RaporFormu({super.key, required this.rapor});
  final RaporKatalogOgesi rapor;

  @override
  ConsumerState<RaporFormu> createState() => _RaporFormuState();
}

class _RaporFormuState extends ConsumerState<RaporFormu> {
  final _durum = <String, Object?>{};
  final _metinler = <String, TextEditingController>{};
  bool _mesgul = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    for (final ad in widget.rapor.alanlar) {
      _durum[ad] = baslangicDegeri(ad);
    }
  }

  @override
  void dispose() {
    for (final c in _metinler.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _metin(String ad) => _metinler.putIfAbsent(
        ad,
        () => TextEditingController(text: (_durum[ad] as String?) ?? ''),
      );

  Map<String, dynamic> get _govde => govdeyeCevir(_durum);

  Future<void> _calistir(String bicim) async {
    final l10n = context.l10n;
    final api = ref.read(raporMotoruApiProvider);
    final r = widget.rapor;
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      if (bicim == 'tablo') {
        final tablo = await api.goster(r.kod, _govde);
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => RaporTabloScreen(tablo: tablo),
        ));
        return;
      }
      if (r.agir) {
        await api.kuyruga(r.kod, bicim, _govde);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.rprKuyrugaAlindi)));
        Navigator.of(context).pop(true);
        return;
      }
      final govde = _govde;
      await raporuPaylas(context, ref, uret: () => api.dosya(r.kod, bicim, govde), konu: r.baslik);
    } on ApiException catch (e) {
      if (mounted) setState(() => _hata = e.message.isNotEmpty ? e.message : l10n.ortakBeklenmeyenHata);
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _tarihSec(String ad) async {
    final mevcut = DateTime.tryParse('${_durum[ad] ?? ''}') ?? DateTime.now();
    final secilen = await showDatePicker(
      context: context,
      initialDate: mevcut,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (secilen == null) return;
    setState(() => _durum[ad] =
        '${secilen.year.toString().padLeft(4, '0')}-${secilen.month.toString().padLeft(2, '0')}-${secilen.day.toString().padLeft(2, '0')}');
  }

  Widget _alan(String ad) {
    final l10n = context.l10n;
    final tanim = alanTanimlari[ad];
    if (tanim == null) return const SizedBox.shrink();
    final etiket = tanim.etiket(l10n);
    final kutu = InputDecoration(labelText: etiket, border: const OutlineInputBorder(), isDense: true);
    Widget alan;
    switch (tanim.tur) {
      case AlanTuru.onay:
        return CheckboxListTile(
          key: Key('rpr-alan-$ad'),
          contentPadding: EdgeInsets.zero,
          value: _durum[ad] == true,
          title: Text(etiket),
          onChanged: _mesgul ? null : (v) => setState(() => _durum[ad] = v ?? false),
        );
      case AlanTuru.tarih:
        alan = InkWell(
          key: Key('rpr-alan-$ad'),
          onTap: _mesgul ? null : () => _tarihSec(ad),
          child: InputDecorator(
            decoration: kutu.copyWith(suffixIcon: const Icon(Icons.calendar_today_outlined)),
            child: Text('${_durum[ad] ?? ''}'),
          ),
        );
      case AlanTuru.metin || AlanTuru.kurus || AlanTuru.yil || AlanTuru.sayi:
        final sayisal = tanim.tur != AlanTuru.metin;
        alan = TextField(
          key: Key('rpr-alan-$ad'),
          controller: _metin(ad),
          enabled: !_mesgul,
          keyboardType: sayisal ? const TextInputType.numberWithOptions(decimal: true) : null,
          inputFormatters: [
            ...GirdiSiniri.sinir(tanim.tur == AlanTuru.yil
                ? 4
                : sayisal
                    ? GirdiSiniri.tutar
                    : GirdiSiniri.kod),
            if (tanim.tur == AlanTuru.yil) FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: kutu,
          onChanged: (v) => _durum[ad] = v,
        );
      case AlanTuru.ay:
        alan = DropdownButtonFormField<String>(
          key: Key('rpr-alan-$ad'),
          isExpanded: true,
          initialValue: _durum[ad] as String?,
          decoration: kutu,
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.rprHepsi)),
            for (var ay = 1; ay <= 12; ay++)
              DropdownMenuItem(value: '$ay', child: Text(ayAdi(ay, context.dilKodu))),
          ],
          onChanged: _mesgul ? null : (v) => setState(() => _durum[ad] = v),
        );
      case AlanTuru.secim:
        alan = DropdownButtonFormField<String>(
          key: Key('rpr-alan-$ad'),
          isExpanded: true,
          initialValue: _durum[ad] as String?,
          decoration: kutu,
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.rprHepsi)),
            for (final s in tanim.secenekler)
              DropdownMenuItem(value: s.id, child: Text(s.etiket(l10n))),
          ],
          onChanged: _mesgul ? null : (v) => setState(() => _durum[ad] = v),
        );
      case AlanTuru.tanimCoklu:
        final secili = (_durum[ad] as List?)?.cast<String>() ?? const <String>[];
        final liste = ref.watch(raporSecenekleriProvider(AlanTuru.tanimCoklu)).value ?? const [];
        alan = InputDecorator(
          key: Key('rpr-alan-$ad'),
          decoration: kutu,
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final o in liste)
                FilterChip(
                  label: Text(o.ad),
                  selected: secili.contains(o.id),
                  onSelected: _mesgul
                      ? null
                      : (v) => setState(() => _durum[ad] = v
                          ? [...secili, o.id]
                          : [for (final x in secili) if (x != o.id) x]),
                ),
            ],
          ),
        );
      case AlanTuru.kasa ||
            AlanTuru.firma ||
            AlanTuru.kisi ||
            AlanTuru.daire ||
            AlanTuru.tanim ||
            AlanTuru.personel:
        final liste = ref.watch(raporSecenekleriProvider(tanim.tur)).value ?? const [];
        final deger = _durum[ad] as String?;
        alan = DropdownButtonFormField<String>(
          key: Key('rpr-alan-$ad'),
          isExpanded: true,
          initialValue: liste.any((o) => o.id == deger) ? deger : null,
          decoration: kutu,
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.rprHepsi)),
            for (final o in liste)
              DropdownMenuItem(value: o.id, child: Text(o.ad, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: _mesgul ? null : (v) => setState(() => _durum[ad] = v),
        );
    }
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: alan);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final r = widget.rapor;
    final ikincil = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(r.baslik, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(r.aciklama, style: TextStyle(color: ikincil)),
            if (r.agir) ...[
              const SizedBox(height: 8),
              Text(l10n.rprAgirUyariMobil,
                  key: const Key('rpr-agir-uyari'), style: TextStyle(color: ikincil, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            for (final ad in r.alanlar) _alan(ad),
            if (_hata != null) ...[
              Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(
                  key: const Key('rpr-excel'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: _mesgul ? null : () => _calistir('excel'),
                  child: Text(l10n.rprExcel),
                ),
                OutlinedButton(
                  key: const Key('rpr-pdf'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: _mesgul ? null : () => _calistir('pdf'),
                  child: Text(l10n.rprPdf),
                ),
                FilledButton(
                  key: const Key('rpr-goster'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: _mesgul ? null : () => _calistir('tablo'),
                  child: Text(l10n.rprGoster),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
