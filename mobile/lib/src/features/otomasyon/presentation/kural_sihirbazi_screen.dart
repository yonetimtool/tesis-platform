/// (P250 §9) YENİ KURAL SİHİRBAZI — ne zaman → kime → ne yapılsın → önizleme.
///
/// Web `KuralSihirbazi` ikizi: aynı adımlar, aynı gövde, aynı sunucu
/// önizlemesi (`POST /aidat-planlari/onizleme`, KAYDETMEZ). Dairelere borç
/// yazma yalnız "Her ay"da: plan ayın bir gününde çalışır.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/para.dart';
import '../../finans/data/finans_api.dart';
import '../../finans/domain/finans_models.dart';
import '../data/otomasyon_api.dart';
import 'kural_cumlesi.dart';

const _sikliklar = ['aylik', 'uc_aylik', 'alti_aylik', 'yillik'];
const _paylasimlar = ['daire_basina', 'esit', 'arsa_payi', 'metrekare'];
const _sonAdim = 3;

final _kalemlerProvider = FutureProvider.autoDispose<List<GiderTuru>>(
  (ref) => ref.watch(finansApiProvider).giderTurleri(),
);
final _kasalarProvider = FutureProvider.autoDispose<List<Kasa>>(
  (ref) => ref.watch(finansApiProvider).kasalar(),
);

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class KuralSihirbaziScreen extends ConsumerStatefulWidget {
  const KuralSihirbaziScreen({super.key, this.bugun});

  /// Testte sabit gün (ilk tarih hesabı).
  final DateTime? bugun;

  @override
  ConsumerState<KuralSihirbaziScreen> createState() => _SihirbazState();
}

class _SihirbazState extends ConsumerState<KuralSihirbaziScreen> {
  int _adim = 0;
  String? _hata;
  bool _mesgul = false;
  // 1) ne zaman
  String _siklik = 'aylik';
  final _gun = TextEditingController(text: '1');
  DateTime? _ilkTarih;
  // 2) kime
  String? _tur; // 'borc' | 'gider'
  String _paylasim = 'daire_basina';
  // 3) ne yapılsın
  final _ad = TextEditingController();
  final _tutar = TextEditingController();
  final _vade = TextEditingController(text: '10');
  String? _kalemId;
  String? _kasaId;
  bool _otomatik = false;
  // 4) önizleme
  KuralOnizleme? _onizleme;

  DateTime get _bugun => widget.bugun ?? DateTime.now();
  int get _gunSayi => int.tryParse(_gun.text) ?? 0;
  int get _kurus => tlMetniniKurusaCevir(_tutar.text) ?? 0;

  @override
  void dispose() {
    _gun.dispose();
    _ad.dispose();
    _tutar.dispose();
    _vade.dispose();
    super.dispose();
  }

  Map<String, dynamic> _planGovdesi() => {
    'ad': _ad.text.trim(),
    'gelir_gider_tanim_id': _kalemId,
    'dagitim': _paylasim,
    'tutar_kurus': _paylasim == 'daire_basina' ? _kurus : null,
    'toplam_tutar_kurus': _paylasim == 'daire_basina' ? null : _kurus,
    'tahakkuk_gunu': _gunSayi,
    'vade_gun': int.tryParse(_vade.text) ?? 0,
    'onizleme_gun': 3,
  };

  DateTime get _giderTarihi => _siklik == 'aylik'
      ? ilkAylikTarih(_gunSayi, _bugun)
      : (_ilkTarih ?? _bugun);

  Map<String, dynamic> _giderGovdesi() => {
    'ad': _ad.text.trim(),
    'tutar_kurus': _kurus,
    'periyot': _siklik,
    'sonraki_tarih': _iso(_giderTarihi),
    'kasa_id': _kasaId,
    'otomatik_onay': _otomatik,
  };

  bool _gecerli() => switch (_adim) {
    0 => _siklik == 'aylik' ? _gunSayi >= 1 && _gunSayi <= 28 : _ilkTarih != null,
    1 => _tur != null,
    2 =>
      _ad.text.trim().isNotEmpty &&
          _kurus > 0 &&
          (_tur == 'gider' || _kalemId != null),
    _ => true,
  };

  Future<void> _ileri() async {
    final l10n = context.l10n;
    if (!_gecerli()) {
      setState(() => _hata = l10n.otoSihirbazEksik);
      return;
    }
    setState(() => _hata = null);
    if (_adim == 2) {
      _onizleme = null;
      if (_tur == 'borc') {
        setState(() => _mesgul = true);
        try {
          _onizleme = await ref
              .read(otomasyonApiProvider)
              .planOnizleme(_planGovdesi());
        } on ApiException catch (e) {
          if (mounted) {
            setState(() {
              _hata = apiHataMetni(l10n, e);
              _mesgul = false;
            });
          }
          return;
        }
        if (!mounted) return;
        setState(() => _mesgul = false);
      }
    }
    setState(() => _adim = (_adim + 1).clamp(0, _sonAdim));
  }

  Future<void> _kaydet() async {
    final l10n = context.l10n;
    final nav = Navigator.of(context);
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      final api = ref.read(otomasyonApiProvider);
      if (_tur == 'borc') {
        await api.planEkle(_planGovdesi());
      } else {
        await api.giderEkle(_giderGovdesi());
      }
      nav.pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _hata = apiHataMetni(l10n, e);
          _mesgul = false;
        });
      }
    }
  }

  Widget _secenek({
    required String anahtar,
    required bool secili,
    required String baslik,
    String? alt,
    bool etkin = true,
    required VoidCallback onSec,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      key: Key(anahtar),
      enabled: etkin,
      leading: Icon(
        secili ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      title: Text(baslik),
      subtitle: alt == null ? null : Text(alt),
      onTap: etkin ? onSec : null,
    ),
  );

  List<Widget> _neZaman() {
    final l10n = context.l10n;
    return [
      for (final s in _sikliklar)
        _secenek(
          anahtar: 'sihirbaz-siklik-$s',
          secili: _siklik == s,
          baslik: siklikMetni(l10n, s),
          onSec: () => setState(() {
            _siklik = s;
            if (s != 'aylik' && _tur == 'borc') _tur = null;
          }),
        ),
      const SizedBox(height: 8),
      if (_siklik == 'aylik')
        TextField(
          key: const Key('sihirbaz-gun'),
          controller: _gun,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          decoration: InputDecoration(
            labelText: l10n.otoSihirbazAyinGunu,
            helperText: l10n.otoSihirbazGunIpucu,
            border: const OutlineInputBorder(),
          ),
        )
      else
        OutlinedButton.icon(
          key: const Key('sihirbaz-ilk-tarih'),
          icon: const Icon(Icons.event_outlined),
          label: Text(
            _ilkTarih == null
                ? l10n.otoSihirbazIlkTarih
                : '${l10n.otoSihirbazIlkTarih}: ${tarihBicimi(_ilkTarih!, context.dilKodu)}',
          ),
          onPressed: () async {
            final secilen = await showDatePicker(
              context: context,
              initialDate: _ilkTarih ?? _bugun,
              firstDate: DateTime(_bugun.year - 1),
              lastDate: DateTime(_bugun.year + 5),
            );
            if (secilen != null) setState(() => _ilkTarih = secilen);
          },
        ),
    ];
  }

  List<Widget> _kime() {
    final l10n = context.l10n;
    final aylik = _siklik == 'aylik';
    return [
      _secenek(
        anahtar: 'sihirbaz-tur-borc',
        secili: _tur == 'borc',
        etkin: aylik,
        baslik: l10n.otoSihirbazKimeDaireler,
        alt: aylik ? l10n.otoSihirbazKimeDairelerAlt : l10n.otoSihirbazYalnizAylik,
        onSec: () => setState(() => _tur = 'borc'),
      ),
      _secenek(
        anahtar: 'sihirbaz-tur-gider',
        secili: _tur == 'gider',
        baslik: l10n.otoSihirbazKimeGider,
        alt: l10n.otoSihirbazKimeGiderAlt,
        onSec: () => setState(() => _tur = 'gider'),
      ),
      if (_tur == 'borc') ...[
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const Key('sihirbaz-paylasim'),
          initialValue: _paylasim,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.otoSihirbazPaylasim,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final p in _paylasimlar)
              DropdownMenuItem(
                value: p,
                child: Text(
                  paylasimSecenegi(l10n, p),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) => setState(() => _paylasim = v ?? 'daire_basina'),
        ),
      ],
    ];
  }

  List<Widget> _ne() {
    final l10n = context.l10n;
    final borc = _tur == 'borc';
    final tutarEtiketi = !borc
        ? l10n.otoSihirbazTutar
        : _paylasim == 'daire_basina'
        ? l10n.otoSihirbazTutarDaire
        : l10n.otoSihirbazTutarToplam;
    return [
      TextField(
        key: const Key('sihirbaz-ad'),
        controller: _ad,
        maxLength: 100,
        decoration: InputDecoration(
          labelText: l10n.otoSihirbazAd,
          helperText: l10n.otoSihirbazAdOrnek,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      if (borc)
        ref
            .watch(_kalemlerProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(l10n.ortakBeklenmeyenHata),
              data: (l) => DropdownButtonFormField<String>(
                key: const Key('sihirbaz-kalem'),
                initialValue: _kalemId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.otoSihirbazKalem,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final k in l)
                    DropdownMenuItem(value: k.id, child: Text(k.ad)),
                ],
                onChanged: (v) => setState(() => _kalemId = v),
              ),
            ),
      if (borc) const SizedBox(height: 12),
      TextField(
        key: const Key('sihirbaz-tutar'),
        controller: _tutar,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [LengthLimitingTextInputFormatter(15)],
        decoration: InputDecoration(
          labelText: tutarEtiketi,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      if (borc)
        TextField(
          key: const Key('sihirbaz-vade'),
          controller: _vade,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          decoration: InputDecoration(
            labelText: l10n.otoSihirbazVade,
            border: const OutlineInputBorder(),
          ),
        )
      else ...[
        ref
            .watch(_kasalarProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
              data: (l) => DropdownButtonFormField<String?>(
                key: const Key('sihirbaz-kasa'),
                initialValue: _kasaId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.otoSihirbazKasa,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('—')),
                  for (final k in l)
                    DropdownMenuItem<String?>(value: k.id, child: Text(k.ad)),
                ],
                onChanged: (v) => setState(() => _kasaId = v),
              ),
            ),
        SwitchListTile(
          key: const Key('sihirbaz-otomatik'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.otoSihirbazOtomatikOnay),
          value: _otomatik,
          onChanged: (v) => setState(() => _otomatik = v),
        ),
      ],
    ];
  }

  List<Widget> _onizlemeAdimi() {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final tema = Theme.of(context).textTheme;
    final borc = _tur == 'borc';
    final cumle = borc
        ? planCumlesi(
            l10n,
            dil,
            ad: _ad.text.trim(),
            dagitim: _paylasim,
            tutarKurus: _paylasim == 'daire_basina' ? _kurus : null,
            toplamTutarKurus: _paylasim == 'daire_basina' ? null : _kurus,
            gun: _gunSayi,
            vadeGun: int.tryParse(_vade.text) ?? 0,
          )
        : giderCumlesi(
            l10n,
            dil,
            ad: _ad.text.trim(),
            tutarKurus: _kurus,
            periyot: _siklik,
            sonrakiTarih: _giderTarihi,
            otomatikOnay: _otomatik,
          );
    final o = _onizleme;
    return [
      Text(cumle, key: const Key('sihirbaz-cumle'), style: tema.titleSmall),
      const SizedBox(height: 8),
      if (borc && o != null) ...[
        Text(
          l10n.otoKuralBugunPlan('${o.adet}', tlIsaretli(o.toplamKurus, dil)),
          key: const Key('sihirbaz-bugun'),
        ),
        if (o.atlanan > 0) Text(l10n.otoKuralBugunAtlanan('${o.atlanan}')),
        if (o.ilkTarih != null)
          Text(
            l10n.otoKuralIlkCalisma(tarihBicimi(o.ilkTarih!, dil)),
            style: tema.bodySmall,
          ),
      ],
      if (!borc)
        Text(
          l10n.otoKuralBugunGider(
            tlIsaretli(_kurus, dil),
            tarihBicimi(_giderTarihi, dil),
          ),
          key: const Key('sihirbaz-bugun'),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final basliklar = [
      l10n.otoSihirbazNeZaman,
      l10n.otoSihirbazKime,
      l10n.otoSihirbazNe,
      l10n.otoSihirbazOnizleme,
    ];
    final icerik = switch (_adim) {
      0 => _neZaman(),
      1 => _kime(),
      2 => _ne(),
      _ => _onizlemeAdimi(),
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.otoKuralYeni)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.otoSihirbazAdim('${_adim + 1}', '${basliklar.length}'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            basliklar[_adim],
            key: const Key('sihirbaz-baslik'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...icerik,
          if (_hata != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _hata!,
                key: const Key('sihirbaz-hata'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('sihirbaz-geri'),
                  onPressed: _mesgul
                      ? null
                      : () => _adim == 0
                            ? Navigator.of(context).pop(false)
                            : setState(() {
                                _hata = null;
                                _adim -= 1;
                              }),
                  child: Text(
                    _adim == 0 ? l10n.ortakIptal : l10n.otoSihirbazGeri,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: Key(
                    _adim < _sonAdim ? 'sihirbaz-ileri' : 'sihirbaz-kaydet',
                  ),
                  onPressed: _mesgul
                      ? null
                      : (_adim < _sonAdim ? _ileri : _kaydet),
                  child: Text(
                    _adim < _sonAdim
                        ? l10n.otoSihirbazIleri
                        : l10n.otoSihirbazKaydet,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
