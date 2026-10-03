import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/para.dart';
import '../../../core/sayi.dart';
import '../../../core/ui/eposta_alani_widget.dart';
import '../../../core/ui/eposta_hata_metni.dart';
import '../../../core/ui/telefon_alani.dart';
import '../../../core/ui/telefon_alani_widget.dart';
import '../data/defter_api.dart';
import '../domain/defter_tanimi.dart';

/// (P253 Asama 2) GENEL DEFTER FORMU — alan listesinden cizilir.
///
/// Govde kurali web `tanimlar.tsx kaydet()` ile ayni:
///   * bos alan `null` gider (bos metin sunucu bicim denetimine takilirdi);
///   * zorunlu bos, gecersiz tutar/sayi ISTEK ATMADAN durdurulur;
///   * `sadeceOlustur` alan duzenlemede GONDERILMEZ (sunucu PATCH'te kabul
///     etmez, kullanici degistirdigini sanirdi);
///   * telefon E.164'e, IBAN bosluksuz buyuk harfe cevrilir.
/// Basariyla kaydedince `true` ile kapanir.
class DefterFormu extends ConsumerStatefulWidget {
  const DefterFormu({super.key, required this.defter, this.kayit});

  final DefterTanimi defter;
  final Map<String, dynamic>? kayit;

  @override
  ConsumerState<DefterFormu> createState() => _DefterFormuState();
}

class _DefterFormuState extends ConsumerState<DefterFormu> {
  final _metinler = <String, TextEditingController>{};
  final _degerler = <String, Object?>{};
  final _referanslar = <String, List<Map<String, dynamic>>>{};
  String? _hata;
  bool _mesgul = false;

  bool get _duzenleme => widget.kayit != null;

  @override
  void initState() {
    super.initState();
    final k = widget.kayit ?? const <String, dynamic>{};
    for (final a in widget.defter.alanlar) {
      final ham = k[a.ad];
      switch (a.tur) {
        case AlanTuru.bool_:
          _degerler[a.ad] = ham == null ? true : ham == true;
        case AlanTuru.secim:
        case AlanTuru.referans:
        case AlanTuru.tarih:
          _degerler[a.ad] = ham?.toString();
        case AlanTuru.kurus:
          _metinler[a.ad] = TextEditingController(text: ham is num ? tlTutar(ham.toInt()) : '');
        default:
          _metinler[a.ad] = TextEditingController(text: ham?.toString() ?? '');
      }
      if (a.tur == AlanTuru.referans && a.referansUcu != null) _referansYukle(a);
    }
  }

  Future<void> _referansYukle(DefterAlani a) async {
    try {
      final s = await ref.read(defterApiProvider).liste(a.referansUcu!, limit: 200, offset: 0);
      if (mounted) setState(() => _referanslar[a.ad] = s.ogeler);
    } on ApiException {
      if (mounted) setState(() => _referanslar[a.ad] = const []);
    }
  }

  @override
  void dispose() {
    for (final c in _metinler.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Gecersizse hata metni doner, govdeye yazmaz.
  String? _govdeKur(Map<String, dynamic> govde) {
    final l10n = context.l10n;
    for (final a in widget.defter.alanlar) {
      if (a.sadeceOlustur && _duzenleme) continue;
      final etiket = a.etiket(l10n);
      if (a.tur == AlanTuru.bool_) {
        govde[a.ad] = _degerler[a.ad] == true;
        continue;
      }
      final metin = (_metinler[a.ad]?.text ?? (_degerler[a.ad] as String?) ?? '').trim();
      if (metin.isEmpty) {
        if (a.zorunlu) return l10n.tnmZorunluAlan(etiket);
        govde[a.ad] = null;
        continue;
      }
      switch (a.tur) {
        case AlanTuru.kurus:
          final k = tlMetniniKurusaCevir(metin);
          if (k == null) return l10n.tnmTutarGecersiz(etiket);
          govde[a.ad] = k;
        case AlanTuru.sayi:
          final s = sayiCoz(metin);
          if (s.tur != SayiTuru.sayi) return l10n.tnmSayiGecersiz(etiket);
          final d = s.deger!;
          govde[a.ad] = d == d.roundToDouble() ? d.toInt() : d;
        case AlanTuru.telefon:
          final e164 = telefonNormalle(metin);
          govde[a.ad] = e164.isEmpty ? metin : e164;
        case AlanTuru.eposta:
          // (P253 acil) Büyük harfli e-posta GÖNDERİLMEZ (alan da söyler).
          final h = epostaHataMetni(l10n, metin, zorunlu: false);
          if (h != null) return h;
          govde[a.ad] = metin;
        case AlanTuru.iban:
          govde[a.ad] = metin.replaceAll(RegExp(r'\s'), '').toUpperCase();
        default:
          govde[a.ad] = a.buyukHarf ? metin.toUpperCase() : metin;
      }
    }
    return null;
  }

  Future<void> _kaydet() async {
    final govde = <String, dynamic>{};
    final hata = _govdeKur(govde);
    if (hata != null) {
      setState(() => _hata = hata);
      return;
    }
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    final api = ref.read(defterApiProvider);
    try {
      if (_duzenleme) {
        await api.guncelle(widget.defter.uc, widget.kayit!['id'].toString(), govde);
      } else {
        await api.olustur(widget.defter.uc, govde);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _mesgul = false;
        _hata = apiHataMetni(context.l10n, e);
      });
    }
  }

  Future<void> _tarihSec(DefterAlani a) async {
    final simdiki = DateTime.tryParse((_degerler[a.ad] as String?) ?? '') ?? DateTime.now();
    final secilen = await showDatePicker(
      context: context,
      initialDate: simdiki,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (secilen == null) return;
    final iso = '${secilen.year.toString().padLeft(4, '0')}-'
        '${secilen.month.toString().padLeft(2, '0')}-'
        '${secilen.day.toString().padLeft(2, '0')}';
    setState(() => _degerler[a.ad] = iso);
  }

  Widget _alan(DefterAlani a) {
    final l10n = context.l10n;
    final etiket = a.zorunlu ? '${a.etiket(l10n)} *' : a.etiket(l10n);
    final ipucu = a.ipucu?.call(l10n);
    final anahtar = Key('defter-alan-${a.ad}');
    switch (a.tur) {
      case AlanTuru.bool_:
        return SwitchListTile(
          key: anahtar,
          contentPadding: EdgeInsets.zero,
          title: Text(etiket),
          value: _degerler[a.ad] == true,
          onChanged: _mesgul ? null : (v) => setState(() => _degerler[a.ad] = v),
        );
      case AlanTuru.secim:
        return DropdownButtonFormField<String?>(
          key: anahtar,
          isExpanded: true,
          initialValue: _degerler[a.ad] as String?,
          decoration: InputDecoration(labelText: etiket, helperText: ipucu, helperMaxLines: 6),
          items: [
            if (!a.zorunlu) DropdownMenuItem(value: null, child: Text(l10n.tnmSecilmedi)),
            for (final s in a.secenekler)
              DropdownMenuItem(value: s.deger, child: Text(s.etiket(l10n), overflow: TextOverflow.ellipsis)),
          ],
          onChanged: _mesgul ? null : (v) => setState(() => _degerler[a.ad] = v),
        );
      case AlanTuru.referans:
        final secenekler = _referanslar[a.ad];
        final kilitli = a.sadeceOlustur && _duzenleme;
        if (secenekler == null) return const LinearProgressIndicator();
        final secili = _degerler[a.ad] as String?;
        final gecerli = secenekler.any((s) => s['id'].toString() == secili) ? secili : null;
        return DropdownButtonFormField<String?>(
          key: anahtar,
          isExpanded: true,
          initialValue: gecerli,
          decoration: InputDecoration(labelText: etiket),
          items: [
            if (!a.zorunlu) DropdownMenuItem(value: null, child: Text(l10n.tnmSecilmedi)),
            for (final s in secenekler)
              DropdownMenuItem(
                value: s['id'].toString(),
                child: Text('${s[a.referansEtiketi] ?? s['id']}', overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _mesgul || kilitli ? null : (v) => setState(() => _degerler[a.ad] = v),
        );
      case AlanTuru.tarih:
        final deger = _degerler[a.ad] as String?;
        return ListTile(
          key: anahtar,
          contentPadding: EdgeInsets.zero,
          title: Text(etiket),
          subtitle: Text(deger == null
              ? l10n.tnmTarihSec
              : tarihBicimi(DateTime.parse(deger), context.dilKodu)),
          trailing: const Icon(Icons.event_outlined),
          onTap: _mesgul ? null : () => _tarihSec(a),
        );
      // (P253 A2) TELEFON ve E-POSTA ORTAK BILESENDEN (p233/p248 kilitleri):
      // ulke kodu, bicim ve dogrulama her ekranda ayni.
      case AlanTuru.telefon:
        return TelefonAlani(
          ktrl: _metinler[a.ad]!,
          etiket: a.etiket(l10n),
          ipucu: ipucu,
          etkin: !_mesgul,
          zorunlu: a.zorunlu,
          alanAnahtari: anahtar,
        );
      case AlanTuru.eposta:
        return EpostaAlani(
          ktrl: _metinler[a.ad]!,
          etiket: a.etiket(l10n),
          ipucu: ipucu,
          etkin: !_mesgul,
          zorunlu: a.zorunlu,
          alanAnahtari: anahtar,
        );
      default:
        return TextField(
          key: anahtar,
          controller: _metinler[a.ad],
          enabled: !_mesgul,
          maxLength: a.enFazla,
          textCapitalization: a.buyukHarf ? TextCapitalization.characters : TextCapitalization.none,
          keyboardType: switch (a.tur) {
            AlanTuru.kurus || AlanTuru.sayi => const TextInputType.numberWithOptions(decimal: true),
            _ => TextInputType.text,
          },
          decoration: InputDecoration(labelText: etiket, helperText: ipucu, counterText: ''),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.defter.baslik(l10n)} · ${_duzenleme ? l10n.tnmDuzenle : l10n.tnmYeniKayit}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final a in widget.defter.alanlar)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: _alan(a)),
                ],
              ),
            ),
          ),
          if (_hata != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _hata!,
                key: const Key('defter-form-hata'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _mesgul ? null : () => Navigator.of(context).pop(false),
                child: Text(l10n.ortakVazgec),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('defter-form-kaydet'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: _mesgul ? null : _kaydet,
                child: Text(l10n.ortakKaydet),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
