/// (P253 Asama 2, plan §2.2) TOPLU TAHAKKUK SIHIRBAZI.
///
/// Bes adim, her adim tek ekran:
///   1. Ne?      tur + tarih (donem tarihten) + son odeme + kalem tipi
///   2. Ne kadar? dagitim yontemi + tutar (daire basina ya da toplam)
///   3. Kime?    tum daireler / bir blok / tek tek (coklu secim)
///   4. Onizleme ozet: islenecek, atlanacak, hedefsiz, toplam; en yuksek
///      ve en dusuk bes tutar. Daire bazinda tablo YOK.
///   5. Onay     §C diyalogu (adet · tur · donem + toplam), sonra isle.
///
/// Govde web `TopluModal` ile AYNI (`TopluBorcIstek`); onizleme ile isleme
/// AYNI govdeyi gonderir — gorulen ile yazilan ayrismasin.
///
/// GERI AL (§C-4): toplu tahakkuk bir PARTI kimligi doner; sonuc ekraninda
/// "Geri al" partiyi tek istekte ters kayitla kapatir (sebep zorunlu,
/// `POST /borclandirma/parti/{id}/geri-al`). Odeme almis satirlar geri
/// alinmaz ve listelenir — onay diyalogu bunu ONCEDEN yazar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/girdi_siniri.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/para.dart';
import '../../../core/ui/coklu_secim.dart';
import '../../../core/ui/finans_onay.dart';
import '../data/borclandirma_api.dart';
import '../domain/borclandirma_models.dart';
import 'borc_etiketleri.dart';

class TopluTahakkukScreen extends ConsumerStatefulWidget {
  const TopluTahakkukScreen({super.key});

  @override
  ConsumerState<TopluTahakkukScreen> createState() => _TopluState();
}

class _TopluState extends ConsumerState<TopluTahakkukScreen> {
  static const _adimSayisi = 5;

  final _tutar = TextEditingController();
  final _aciklama = TextEditingController();
  final _secim = CokluSecim<String>();
  int _adim = 0;
  String? _turId;
  DateTime _tarih = DateTime.now();
  DateTime? _sonOdeme;
  String _kalemTipi = 'aidat';
  String _dagitim = 'daire_basina';
  TopluKapsam _kapsam = TopluKapsam.tumu;
  String? _blok;
  TopluOnizleme? _onizleme;
  TahakkukSonucu? _sonuc;
  bool _mesgul = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _secim.addListener(() => setState(() => _onizleme = null));
  }

  @override
  void dispose() {
    _tutar.dispose();
    _aciklama.dispose();
    _secim.dispose();
    super.dispose();
  }

  TopluBorcGovdesi _govde() {
    final kurus = tlMetniniKurusaCevir(_tutar.text);
    return TopluBorcGovdesi(
      donem: donemden(_tarih),
      tanimId: _turId ?? '',
      dagitim: _dagitim,
      kalemTipi: _kalemTipi,
      kapsam: _kapsam,
      tutarKurus: kurus != null && kurus > 0 ? kurus : null,
      sonOdeme: _sonOdeme,
      tarih: _tarih,
      aciklama: _aciklama.text.trim().isEmpty ? null : _aciklama.text.trim(),
      blok: _blok,
      unitIds: _secim.secili.toList(),
    );
  }

  /// Bu adimdan ileri gidilebilir mi; gidilemiyorsa NEDEN.
  String? _engel(AppLocalizations l10n) {
    switch (_adim) {
      case 0:
        return _turId == null ? l10n.brcTurSec : null;
      case 1:
        final kurus = tlMetniniKurusaCevir(_tutar.text);
        // Daire basinda tutar BOS olabilir (tip varsayilani); dagitimda
        // toplam zorunlu (sunucu da 422 verir).
        if (_dagitim != 'daire_basina' && (kurus == null || kurus <= 0)) {
          return l10n.brcTutarGecersiz;
        }
        if (_tutar.text.trim().isNotEmpty && (kurus == null || kurus <= 0)) {
          return l10n.brcTutarGecersiz;
        }
        return null;
      case 2:
        if (_kapsam == TopluKapsam.blok && _blok == null) return l10n.brcBlokSec;
        if (_kapsam == TopluKapsam.secili && _secim.sayi == 0) return l10n.brcDaireSec;
        return null;
      default:
        return null;
    }
  }

  void _degisti(VoidCallback f) => setState(() {
        f();
        _onizleme = null;
      });

  Future<void> _ileri() async {
    final l10n = context.l10n;
    final engel = _engel(l10n);
    if (engel != null) return setState(() => _hata = engel);
    setState(() => _hata = null);
    if (_adim == 2) {
      // Onizleme adimina gecmeden ONCE sunucu planini al.
      setState(() => _mesgul = true);
      try {
        final o = await ref.read(borclandirmaApiProvider).topluOnizleme(_govde());
        if (!mounted) return;
        setState(() {
          _onizleme = o;
          _adim = 3;
          _mesgul = false;
        });
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          _mesgul = false;
          _hata = e.message.isNotEmpty ? e.message : l10n.ortakBeklenmeyenHata;
        });
      }
      return;
    }
    setState(() => _adim++);
  }

  Future<void> _isle(String turAd) async {
    final l10n = context.l10n;
    final o = _onizleme;
    if (o == null) return;
    final donem = donemden(_tarih);
    final onay = await finansOnayla(
      context,
      baslik: l10n.brcToplu,
      hedef: l10n.brcTopluOnayHedef(o.islenecek, turAd, donem),
      tutar: tlTutar(o.toplamKurus),
      sonuc: l10n.brcTopluOnaySonuc,
      onayMetni: l10n.brcTopluIsle,
      tehlikeli: true,
    );
    if (onay == null || !mounted) return;
    setState(() => _mesgul = true);
    try {
      final s = await ref.read(borclandirmaApiProvider).topluIsle(_govde());
      if (!mounted) return;
      setState(() {
        _sonuc = s;
        _mesgul = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _mesgul = false;
        _hata = e.message.isNotEmpty ? e.message : l10n.ortakBeklenmeyenHata;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final turler = ref.watch(borcTurleriProvider).value ?? const [];
    final daireler = ref.watch(borcDairelerProvider).value ?? const [];
    final turAd = turler.where((t) => t.id == _turId).firstOrNull?.ad ?? '';
    final sonuc = _sonuc;
    return Scaffold(
      appBar: AppBar(title: Text(baslikBuyuk(l10n.brcToplu, context.dilKodu))),
      body: sonuc != null
          ? _SonucGorunumu(sonuc: sonuc, toplamKurus: _onizleme?.toplamKurus ?? 0)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(l10n.brcAdim(_adim + 1, _adimSayisi),
                    key: const Key('brc-toplu-adim'),
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(_adimBasligi(l10n), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ...switch (_adim) {
                  0 => _ne(l10n, turler),
                  1 => _neKadar(l10n),
                  2 => _kime(l10n, daireler),
                  3 => _onizlemeGorunumu(l10n),
                  _ => _onayGorunumu(l10n, turAd),
                },
                if (_hata != null) ...[
                  const SizedBox(height: 8),
                  Text(_hata!,
                      key: const Key('brc-toplu-hata'),
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_adim > 0)
                      OutlinedButton(
                        key: const Key('brc-toplu-geri'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                        onPressed: _mesgul ? null : () => setState(() {
                              _adim--;
                              _hata = null;
                            }),
                        child: Text(l10n.brcGeri),
                      ),
                    const Spacer(),
                    if (_adim < _adimSayisi - 1)
                      FilledButton(
                        key: const Key('brc-toplu-ileri'),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                        onPressed: _mesgul ? null : _ileri,
                        child: Text(l10n.brcIleri),
                      )
                    else
                      FilledButton(
                        key: const Key('brc-toplu-isle'),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                        onPressed: _mesgul || _onizleme == null || _onizleme!.islenecek == 0
                            ? null
                            : () => _isle(turAd),
                        child: Text(l10n.brcTopluIsle),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  String _adimBasligi(AppLocalizations l10n) => switch (_adim) {
        0 => l10n.brcAdimNe,
        1 => l10n.brcAdimNeKadar,
        2 => l10n.brcAdimKime,
        3 => l10n.brcAdimOnizleme,
        _ => l10n.brcAdimOnay,
      };

  Future<void> _tarihSec({required bool son}) async {
    final simdi = DateTime.now();
    final secilen = await showDatePicker(
      context: context,
      initialDate: (son ? _sonOdeme : _tarih) ?? _tarih,
      firstDate: DateTime(simdi.year - 5),
      lastDate: DateTime(simdi.year + 2, 12, 31),
    );
    if (secilen == null) return;
    _degisti(() => son ? _sonOdeme = secilen : _tarih = secilen);
  }

  List<Widget> _ne(AppLocalizations l10n, List<BorcTuru> turler) {
    final dil = context.dilKodu;
    return [
      DropdownButtonFormField<String>(
        key: const Key('brc-toplu-tur'),
        isExpanded: true,
        initialValue: _turId,
        decoration: InputDecoration(labelText: l10n.brcTur, border: const OutlineInputBorder()),
        hint: Text(l10n.brcTurSec),
        items: [
          for (final t in turler)
            DropdownMenuItem(value: t.id, child: Text(t.ad, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => _degisti(() => _turId = v),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: const Key('brc-toplu-tarih'),
        icon: const Icon(Icons.event_outlined),
        label: Text(l10n.brcTarihDegeri(tarihBicimi(_tarih, dil))),
        onPressed: () => _tarihSec(son: false),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(l10n.brcDonem(donemden(_tarih)),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
      OutlinedButton.icon(
        key: const Key('brc-toplu-son-odeme'),
        icon: const Icon(Icons.event_busy_outlined),
        label: Text(_sonOdeme == null
            ? l10n.brcSonOdemeYok
            : l10n.brcSonOdemeDegeri(tarihBicimi(_sonOdeme!, dil))),
        onPressed: () => _tarihSec(son: true),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: const Key('brc-toplu-kalem'),
        isExpanded: true,
        initialValue: _kalemTipi,
        decoration: InputDecoration(labelText: l10n.brcKalemTipi, border: const OutlineInputBorder()),
        items: [
          for (final k in kalemTipleri) DropdownMenuItem(value: k, child: Text(kalemTipiAdi(l10n, k))),
        ],
        onChanged: (v) => _degisti(() => _kalemTipi = v ?? 'aidat'),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('brc-toplu-aciklama'),
        controller: _aciklama,
        maxLength: 500,
        inputFormatters: GirdiSiniri.sinir(500),
        decoration: InputDecoration(labelText: l10n.brcAciklama, border: const OutlineInputBorder()),
        onChanged: (_) => setState(() => _onizleme = null),
      ),
    ];
  }

  List<Widget> _neKadar(AppLocalizations l10n) => [
        RadioGroup<String>(
          groupValue: _dagitim,
          onChanged: (v) => _degisti(() => _dagitim = v ?? 'daire_basina'),
          child: Column(
            children: [
              for (final d in dagitimlar)
                RadioListTile<String>(
                  key: Key('brc-toplu-dagitim-$d'),
                  contentPadding: EdgeInsets.zero,
                  value: d,
                  title: Text(dagitimAdi(l10n, d)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('brc-toplu-tutar'),
          controller: _tutar,
          maxLength: GirdiSiniri.tutar,
          inputFormatters: GirdiSiniri.sinir(GirdiSiniri.tutar),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _dagitim == 'daire_basina' ? l10n.brcTutarDaireBasina : l10n.brcTutarToplam,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => _onizleme = null),
        ),
      ];

  List<Widget> _kime(AppLocalizations l10n, List<DaireKisa> daireler) {
    final bloklar = {for (final d in daireler) if (d.blok != null && d.blok!.isNotEmpty) d.blok!}
        .toList()
      ..sort();
    return [
      RadioGroup<TopluKapsam>(
        groupValue: _kapsam,
        onChanged: (v) => _degisti(() => _kapsam = v ?? TopluKapsam.tumu),
        child: Column(
          children: [
            RadioListTile<TopluKapsam>(
              key: const Key('brc-toplu-kapsam-tumu'),
              contentPadding: EdgeInsets.zero,
              value: TopluKapsam.tumu,
              title: Text(l10n.brcKapsamTumu),
            ),
            RadioListTile<TopluKapsam>(
              key: const Key('brc-toplu-kapsam-blok'),
              contentPadding: EdgeInsets.zero,
              value: TopluKapsam.blok,
              title: Text(l10n.brcKapsamBlok),
            ),
            RadioListTile<TopluKapsam>(
              key: const Key('brc-toplu-kapsam-secili'),
              contentPadding: EdgeInsets.zero,
              value: TopluKapsam.secili,
              title: Text(l10n.brcKapsamSecili),
            ),
          ],
        ),
      ),
      if (_kapsam == TopluKapsam.blok)
        DropdownButtonFormField<String>(
          key: const Key('brc-toplu-blok'),
          isExpanded: true,
          initialValue: _blok,
          decoration: InputDecoration(labelText: l10n.brcBlokSec, border: const OutlineInputBorder()),
          items: [for (final b in bloklar) DropdownMenuItem(value: b, child: Text(b))],
          onChanged: (v) => _degisti(() => _blok = v),
        ),
      if (_kapsam == TopluKapsam.secili) ...[
        Row(
          children: [
            Expanded(child: Text(l10n.brcSeciliSayi(_secim.sayi), key: const Key('brc-toplu-secili-sayi'))),
            TextButton(
              key: const Key('brc-toplu-tumunu'),
              onPressed: () => _secim.tumunu([for (final d in daireler) d.id]),
              child: Text(l10n.brcTumunuSec),
            ),
          ],
        ),
        for (final d in daireler)
          CheckboxListTile(
            key: Key('brc-toplu-daire-${d.id}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _secim.seciliMi(d.id),
            title: Text(hedefMetni([d.blok, d.no])),
            onChanged: (_) => _secim.degistir(d.id),
          ),
      ],
    ];
  }

  List<Widget> _onizlemeGorunumu(AppLocalizations l10n) {
    final o = _onizleme;
    if (o == null) return const [];
    Widget satirlar(String baslik, List<TopluSatir> s) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(baslik, style: const TextStyle(fontWeight: FontWeight.w600)),
            for (final r in s)
              Row(
                children: [
                  Expanded(child: Text(r.unitNo)),
                  Text(tlTutar(r.tutarKurus ?? 0)),
                ],
              ),
          ],
        );
    return [
      Text(l10n.brcOnizlemeIslenecek(o.islenecek), key: const Key('brc-toplu-islenecek')),
      Text(l10n.brcOnizlemeToplam(tlTutar(o.toplamKurus)),
          key: const Key('brc-toplu-toplam'), style: const TextStyle(fontWeight: FontWeight.w700)),
      if (o.atlanacak > 0) ...[
        const SizedBox(height: 8),
        Text(l10n.brcOnizlemeAtlanacak(o.atlanacak),
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
        for (final r in o.atlananlar)
          Text('${r.unitNo} — ${atlamaNedeniAdi(l10n, r.atlamaNedeni!)}'),
      ],
      if (o.hedefsiz > 0) ...[
        const SizedBox(height: 8),
        Text(l10n.brcOnizlemeHedefsiz(o.hedefsiz), key: const Key('brc-toplu-hedefsiz')),
        Text(o.hedefsizler.map((r) => r.unitNo).join(', ')),
      ],
      if (o.enYuksek.isNotEmpty) satirlar(l10n.brcEnYuksek, o.enYuksek),
      if (o.enDusuk.length > 1) satirlar(l10n.brcEnDusuk, o.enDusuk),
    ];
  }

  List<Widget> _onayGorunumu(AppLocalizations l10n, String turAd) {
    final o = _onizleme;
    if (o == null) return const [];
    return [
      Text(l10n.brcTopluOnayHedef(o.islenecek, turAd, donemden(_tarih))),
      Text(tlTutar(o.toplamKurus), style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(l10n.brcTopluOnaySonuc,
          key: const Key('brc-toplu-geri-alinamaz'),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ];
  }
}

class _SonucGorunumu extends ConsumerStatefulWidget {
  const _SonucGorunumu({required this.sonuc, required this.toplamKurus});

  final TahakkukSonucu sonuc;
  final int toplamKurus;

  @override
  ConsumerState<_SonucGorunumu> createState() => _SonucGorunumuState();
}

class _SonucGorunumuState extends ConsumerState<_SonucGorunumu> {
  bool _mesgul = false;
  TahakkukSonucu? _geriAlma;

  Future<void> _geriAl() async {
    final l10n = context.l10n;
    final parti = widget.sonuc.partiId;
    if (parti == null) return;
    final sebep = await finansOnayla(
      context,
      baslik: l10n.brcPartiGeriAl,
      hedef: l10n.brcTopluOlustu(widget.sonuc.olusan),
      tutar: tlTutar(widget.toplamKurus),
      sonuc: l10n.brcPartiGeriAlSonuc,
      onayMetni: l10n.brcPartiGeriAl,
      sebepZorunlu: true,
      tehlikeli: true,
    );
    if (sebep == null || !mounted) return;
    setState(() => _mesgul = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final s = await ref.read(borclandirmaApiProvider).partiGeriAl(parti, sebep);
      if (!mounted) return;
      setState(() => _geriAlma = s);
      messenger.showSnackBar(SnackBar(content: Text(l10n.brcPartiGeriAlindi(s.olusan))));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sonuc = widget.sonuc;
    final ok = sonuc.olusan > 0;
    final geri = _geriAlma;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Icon(ok ? Icons.check_circle_outline : Icons.error_outline,
            size: 48, color: ok ? Colors.green : Theme.of(context).colorScheme.error),
        const SizedBox(height: 12),
        Text(ok ? l10n.brcTopluOlustu(sonuc.olusan) : l10n.brcTopluOlusmadi,
            key: const Key('brc-toplu-sonuc'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
        if (sonuc.atlananlar.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.brcAtlananlar, style: const TextStyle(fontWeight: FontWeight.w600)),
          for (final a in sonuc.atlananlar)
            Text('${a.unitNo ?? ''} — ${atlamaNedeniAdi(l10n, a.neden)}'),
        ],
        if (ok && sonuc.partiId != null && geri == null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('brc-parti-geri-al'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            icon: const Icon(Icons.undo),
            label: Text(l10n.brcPartiGeriAl),
            onPressed: _mesgul ? null : _geriAl,
          ),
        ],
        if (geri != null) ...[
          const SizedBox(height: 16),
          Text(l10n.brcPartiGeriAlindi(geri.olusan), key: const Key('brc-parti-geri-alindi')),
          for (final a in geri.atlananlar)
            Text('${a.unitNo ?? ''} — ${atlamaNedeniAdi(l10n, a.neden)}'),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('brc-toplu-kapat'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: () => Navigator.of(context).pop(ok),
          child: Text(l10n.ortakTamam),
        ),
      ],
    );
  }
}
