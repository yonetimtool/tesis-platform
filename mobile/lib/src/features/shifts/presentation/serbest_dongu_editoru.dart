// yetenek:vardiya-serbest-dongu — eylem tablosundaki YETENEK satiri (P253 A2).
/// (P253 Asama 2) SERBEST DONGU TANIMI — web `dongu-modali.tsx` karsiligi.
///
/// Ayni model: dilimler (ad + saat) ve BLOKLAR ("Gece, 14 gun, gun asiri").
/// Bloklar sunucunun `adimlar` dizisine `bloklariAc` ile ACILIR — web
/// fonksiyonunun BIREBIR aynisi (gun asiri = blok icinde cift gunler
/// calisir, tek gunler tatil). Kayit `POST /vardiya-plani/kaliplar`;
/// atama, kuru onizleme ve bosluk satiri cagiran diyalogda (ayni uc).
///
/// Sinirlar web ile ayni: en fazla 6 dilim, en fazla 84 gun, en az bir
/// calisma gunu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/girdi_siniri.dart';
import '../../../core/i18n/l10n.dart';
import '../data/vardiya_plani_api.dart';
import '../domain/vardiya_plani_models.dart';

const int tatil = -1;
const int azamiGun = 84;
const int azamiDilim = 6;

enum BlokDuzeni { herGun, gunAsiri }

class DonguBlogu {
  const DonguBlogu({required this.dilim, required this.gun, this.duzen = BlokDuzeni.herGun});

  /// Dilim sirasi; [tatil] = calisilmaz.
  final int dilim;
  final int gun;
  final BlokDuzeni duzen;

  DonguBlogu kopya({int? dilim, int? gun, BlokDuzeni? duzen}) =>
      DonguBlogu(dilim: dilim ?? this.dilim, gun: gun ?? this.gun, duzen: duzen ?? this.duzen);
}

/// Blok listesi -> sunucunun `adimlar` dizisi. Web `bloklariAc` ile AYNI.
List<List<int>> bloklariAc(List<DonguBlogu> bloklar) => [
      for (final b in bloklar)
        for (var i = 0; i < b.gun; i++)
          (b.dilim != tatil && (b.duzen != BlokDuzeni.gunAsiri || i.isEven)) ? [b.dilim] : <int>[],
    ];

/// Varsayilan: 2 gece -> 2 gunduz -> 2 tatil (web `HAZIR_BLOK.ikiIkiIki`).
const List<DonguBlogu> varsayilanBloklar = [
  DonguBlogu(dilim: 1, gun: 2),
  DonguBlogu(dilim: 0, gun: 2),
  DonguBlogu(dilim: tatil, gun: 2),
];

/// Kaydedilen kalibi doner (vazgecilirse null).
class SerbestDonguEditoru extends ConsumerStatefulWidget {
  const SerbestDonguEditoru({super.key});

  @override
  ConsumerState<SerbestDonguEditoru> createState() => _SerbestDonguEditoruState();
}

class _Dilim {
  _Dilim(String ad, this.baslangic, this.bitis) : ad = TextEditingController(text: ad);
  final TextEditingController ad;
  String baslangic;
  String bitis;
}

class _SerbestDonguEditoruState extends ConsumerState<SerbestDonguEditoru> {
  final _ad = TextEditingController();
  late final List<_Dilim> _dilimler = [
    _Dilim(context.l10n.donguGunduz, '08:00', '20:00'),
    _Dilim(context.l10n.donguGece, '20:00', '08:00'),
  ];
  List<DonguBlogu> _bloklar = List.of(varsayilanBloklar);
  bool _mesgul = false;
  String? _hata;

  @override
  void dispose() {
    _ad.dispose();
    for (final d in _dilimler) {
      d.ad.dispose();
    }
    super.dispose();
  }

  List<List<int>> get _adimlar => bloklariAc(_bloklar);

  bool get _gecerli {
    final a = _adimlar;
    return _ad.text.trim().isNotEmpty &&
        a.length <= azamiGun &&
        a.any((x) => x.isNotEmpty) &&
        _dilimler.every((d) => d.ad.text.trim().isNotEmpty);
  }

  Future<void> _saatSec(_Dilim d, bool baslangicMi) async {
    final mevcut = (baslangicMi ? d.baslangic : d.bitis).split(':');
    final secilen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(mevcut[0]), minute: int.parse(mevcut[1])),
    );
    if (secilen == null) return;
    final metin = '${secilen.hour.toString().padLeft(2, '0')}:${secilen.minute.toString().padLeft(2, '0')}';
    setState(() => baslangicMi ? d.baslangic = metin : d.bitis = metin);
  }

  void _dilimSil(int i) {
    setState(() {
      _dilimler.removeAt(i).ad.dispose();
      // Silinen dilime bagli bloklar tatile, sonrakiler bir sira geri kayar.
      _bloklar = [
        for (final b in _bloklar)
          b.dilim == i ? b.kopya(dilim: tatil) : (b.dilim > i ? b.kopya(dilim: b.dilim - 1) : b),
      ];
    });
  }

  Future<void> _kaydet() async {
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      final k = await ref.read(vardiyaPlaniApiProvider).donguKalibiOlustur(
            ad: _ad.text.trim(),
            dilimler: [
              for (final d in _dilimler)
                VardiyaDilim(ad: d.ad.text.trim(), baslangic: d.baslangic, bitis: d.bitis),
            ],
            adimlar: _adimlar,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.sdgDonguKaydedildi)));
      Navigator.of(context).pop(k);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _mesgul = false;
          _hata = apiHataMetni(context.l10n, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tema = Theme.of(context);
    final adimlar = _adimlar;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.sdgAc, style: tema.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              key: const Key('sdg-ad'),
              controller: _ad,
              enabled: !_mesgul,
              inputFormatters: GirdiSiniri.sinir(GirdiSiniri.ad),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l10n.sdgDonguAd, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Text(l10n.sdgDonguDilimler, style: tema.textTheme.titleSmall),
            for (var i = 0; i < _dilimler.length; i++)
              Padding(
                key: Key('sdg-dilim-$i'),
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: Key('sdg-dilim-ad-$i'),
                        controller: _dilimler[i].ad,
                        enabled: !_mesgul,
                        inputFormatters: GirdiSiniri.sinir(60),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                            labelText: l10n.sdgDonguDilimAd, isDense: true, border: const OutlineInputBorder()),
                      ),
                    ),
                    TextButton(
                      key: Key('sdg-dilim-bas-$i'),
                      onPressed: _mesgul ? null : () => _saatSec(_dilimler[i], true),
                      child: Text(_dilimler[i].baslangic, semanticsLabel: l10n.sdgVardiyaBaslangicSaati),
                    ),
                    const Text('–'),
                    TextButton(
                      key: Key('sdg-dilim-bit-$i'),
                      onPressed: _mesgul ? null : () => _saatSec(_dilimler[i], false),
                      child: Text(_dilimler[i].bitis, semanticsLabel: l10n.sdgVardiyaBitisSaati),
                    ),
                    if (_dilimler.length > 1)
                      IconButton(
                        tooltip: l10n.sdgDilimSil,
                        icon: const Icon(Icons.close),
                        onPressed: _mesgul ? null : () => _dilimSil(i),
                      ),
                  ],
                ),
              ),
            if (_dilimler.length < azamiDilim)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const Key('sdg-dilim-ekle'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.sdgDonguDilimEkle),
                  onPressed: _mesgul
                      ? null
                      : () => setState(() => _dilimler.add(_Dilim('${_dilimler.length + 1}', '08:00', '16:00'))),
                ),
              ),
            const SizedBox(height: 12),
            Text(l10n.sdgDonguAdimlar, style: tema.textTheme.titleSmall),
            for (var i = 0; i < _bloklar.length; i++) _blokSatiri(i),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('sdg-blok-ekle'),
                icon: const Icon(Icons.add),
                label: Text(l10n.sdgDonguAdimEkle),
                onPressed: _mesgul
                    ? null
                    : () => setState(() => _bloklar = [..._bloklar, const DonguBlogu(dilim: 0, gun: 1)]),
              ),
            ),
            const SizedBox(height: 8),
            // ADIM SERIDI: kaydetmeden once dongunun kendisi gorunsun (web ile ayni).
            Wrap(
              key: const Key('sdg-serit'),
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final a in adimlar)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: a.isEmpty ? null : tema.colorScheme.primaryContainer,
                      border: Border.all(color: tema.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      a.isEmpty ? l10n.sdgDonguTatil : _dilimler[a.first].ad.text,
                      style: tema.textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(l10n.sdgDonguUzunluk(adimlar.length), key: const Key('sdg-uzunluk')),
            if (adimlar.length > azamiGun)
              Text(l10n.sdgSinirAsildi, style: TextStyle(color: tema.colorScheme.error)),
            if (_hata != null) Text(_hata!, style: TextStyle(color: tema.colorScheme.error)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _mesgul ? null : () => Navigator.of(context).pop(),
                  child: Text(l10n.ortakVazgec),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('sdg-kaydet'),
                  onPressed: _mesgul || !_gecerli ? null : _kaydet,
                  child: Text(l10n.sdgDonguKaydet),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _blokSatiri(int i) {
    final l10n = context.l10n;
    final b = _bloklar[i];
    void degistir(DonguBlogu yeni) => setState(() => _bloklar = [
          for (var j = 0; j < _bloklar.length; j++) j == i ? yeni : _bloklar[j],
        ]);
    return Padding(
      key: Key('sdg-blok-$i'),
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: DropdownButtonFormField<int>(
              key: Key('sdg-blok-dilim-$i'),
              isExpanded: true,
              initialValue: b.dilim,
              decoration: InputDecoration(
                  labelText: l10n.sdgDonguAdimDilim, isDense: true, border: const OutlineInputBorder()),
              items: [
                for (var j = 0; j < _dilimler.length; j++)
                  DropdownMenuItem(value: j, child: Text(_dilimler[j].ad.text, overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: tatil, child: Text(l10n.sdgDonguTatil)),
              ],
              onChanged: _mesgul ? null : (v) => degistir(b.kopya(dilim: v)),
            ),
          ),
          SizedBox(
            width: 90,
            child: TextFormField(
              key: Key('sdg-blok-gun-$i'),
              initialValue: '${b.gun}',
              enabled: !_mesgul,
              keyboardType: TextInputType.number,
              inputFormatters: GirdiSiniri.sinir(2),
              decoration: InputDecoration(
                  labelText: l10n.sdgDonguGunSayisi, isDense: true, border: const OutlineInputBorder()),
              onChanged: (v) => degistir(b.kopya(gun: (int.tryParse(v) ?? 1).clamp(1, azamiGun))),
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<BlokDuzeni>(
              key: Key('sdg-blok-duzen-$i'),
              isExpanded: true,
              initialValue: b.duzen,
              decoration: InputDecoration(
                  labelText: l10n.sdgDonguDuzen, isDense: true, border: const OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: BlokDuzeni.herGun, child: Text(l10n.sdgDonguHerGun)),
                DropdownMenuItem(value: BlokDuzeni.gunAsiri, child: Text(l10n.sdgDonguGunAsiri)),
              ],
              onChanged: _mesgul ? null : (v) => degistir(b.kopya(duzen: v)),
            ),
          ),
          if (_bloklar.length > 1)
            IconButton(
              key: Key('sdg-blok-sil-$i'),
              tooltip: l10n.sdgBlokSil,
              icon: const Icon(Icons.close),
              onPressed: _mesgul ? null : () => setState(() => _bloklar = [..._bloklar]..removeAt(i)),
            ),
        ],
      ),
    );
  }
}
