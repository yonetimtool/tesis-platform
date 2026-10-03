/// (P253 §B, plan §2.1) LISTE EKRANI — genis web tablolarinin mobil karsiligi.
///
/// Web'deki her tablo (`VeriTablosu`) sutun siralama, sutun gizleme, sayfa
/// boyu ve sayfalama veriyor. Telefonda bunlarin karsiligi:
///   * satir bir KARTTIR (ana bilgi + 2-3 ikincil); dokununca detay;
///   * siralama ve suzgec TEK bir "Sirala / Suz" penceresinde; secili
///     suzgecler liste basinda CIP olarak durur, tek dokunusla kalkar;
///   * sayfalama yerine SONSUZ KAYDIRMA (sunucu `limit/offset`i korunur);
///   * sutun gizleme GEREKMEZ — kart neyi gosterecegini zaten secmistir
///     (P253 karari §A-5, tabloda `yapisal`);
///   * uzun bas -> coklu secim + alt cubukta toplu eylemler (`coklu_secim`).
///
/// BIR KEZ YAZILIR: finans hareketleri, borclandirmalar, envanter, icra,
/// vardiya listeleri bunu kullanir; her yeni liste ucuzlar.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../girdi_siniri.dart';
import '../i18n/l10n.dart';
import 'coklu_secim.dart';
import 'merkez_diyalog.dart';

/// Sunucuya giden sorgu: sayfa + arama + suzgec + siralama.
class ListeSorgusu {
  const ListeSorgusu({
    required this.offset,
    required this.limit,
    this.arama = '',
    this.suzgec = const {},
    this.siralama,
  });

  final int offset;
  final int limit;
  final String arama;

  /// suzgec adi -> secili deger (yalniz secili olanlar).
  final Map<String, String> suzgec;
  final String? siralama;
}

class ListeSayfasi<T> {
  const ListeSayfasi(this.ogeler, {this.toplam});
  final List<T> ogeler;

  /// Sunucu toplam verdiyse "hepsi geldi" kesin bilinir; vermediyse
  /// sayfa boyundan kisa donen sayfa sonu belirler.
  final int? toplam;
}

class SuzgecSecenegi {
  const SuzgecSecenegi(this.deger, this.etiket);
  final String deger;
  final String Function(AppLocalizations l10n) etiket;
}

class SuzgecTanimi {
  const SuzgecTanimi({required this.ad, required this.etiket, required this.secenekler});
  final String ad;
  final String Function(AppLocalizations l10n) etiket;
  final List<SuzgecSecenegi> secenekler;
}

class SiralamaTanimi {
  const SiralamaTanimi(this.deger, this.etiket);
  final String deger;
  final String Function(AppLocalizations l10n) etiket;
}

class ListeEkrani<T> extends StatefulWidget {
  const ListeEkrani({
    super.key,
    required this.yukle,
    required this.kart,
    required this.kimlik,
    this.baslik,
    this.onDokun,
    this.aramaVar = false,
    this.suzgecler = const [],
    this.siralamalar = const [],
    this.varsayilanSiralama,
    this.topluEylemler = const [],
    this.sayfaBoyu = 30,
    this.fab,
    this.bosMetin,
  });

  /// Verilirse kendi `Scaffold`+`AppBar`i ile cizilir; verilmezse yalniz
  /// govde (sekme icinde kullanim).
  final String? baslik;
  final Future<ListeSayfasi<T>> Function(ListeSorgusu sorgu) yukle;
  final Widget Function(BuildContext context, T oge, bool secili) kart;
  final Object Function(T oge) kimlik;
  final void Function(T oge)? onDokun;
  final bool aramaVar;
  final List<SuzgecTanimi> suzgecler;
  final List<SiralamaTanimi> siralamalar;
  final String? varsayilanSiralama;

  /// Bos degilse uzun bas coklu secimi acar.
  final List<TopluEylem<T>> topluEylemler;
  final int sayfaBoyu;
  final Widget? fab;
  final String Function(AppLocalizations l10n)? bosMetin;

  @override
  State<ListeEkrani<T>> createState() => ListeEkraniState<T>();
}

class ListeEkraniState<T> extends State<ListeEkrani<T>> {
  final _kaydirma = ScrollController();
  final _secim = CokluSecim<Object>();
  final List<T> _ogeler = [];
  String _arama = '';
  Map<String, String> _suzgec = const {};
  String? _siralama;
  bool _yukleniyor = false;
  bool _bitti = false;
  Object? _hata;
  Timer? _aramaBekleme;
  int _nesil = 0; // eski istegin yaniti yeni listeyi bozmasin

  @override
  void initState() {
    super.initState();
    _siralama = widget.varsayilanSiralama;
    _kaydirma.addListener(_sonaYaklasti);
    _secim.addListener(() => setState(() {}));
    yenile();
  }

  @override
  void dispose() {
    _aramaBekleme?.cancel();
    _kaydirma.dispose();
    _secim.dispose();
    super.dispose();
  }

  /// Disaridan da cagrilir (kayit eklendikten sonra).
  Future<void> yenile() async {
    _nesil++;
    setState(() {
      _ogeler.clear();
      _bitti = false;
      _hata = null;
    });
    await _dahaFazla();
  }

  void _sonaYaklasti() {
    if (_kaydirma.position.pixels > _kaydirma.position.maxScrollExtent - 300) {
      _dahaFazla();
    }
  }

  Future<void> _dahaFazla() async {
    if (_yukleniyor || _bitti) return;
    final nesil = _nesil;
    setState(() => _yukleniyor = true);
    try {
      final sayfa = await widget.yukle(ListeSorgusu(
        offset: _ogeler.length,
        limit: widget.sayfaBoyu,
        arama: _arama,
        suzgec: _suzgec,
        siralama: _siralama,
      ));
      if (!mounted || nesil != _nesil) return;
      setState(() {
        _ogeler.addAll(sayfa.ogeler);
        _bitti = sayfa.ogeler.length < widget.sayfaBoyu ||
            (sayfa.toplam != null && _ogeler.length >= sayfa.toplam!);
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted || nesil != _nesil) return;
      setState(() {
        _hata = e;
        _yukleniyor = false;
      });
    }
  }

  void _aramaDegisti(String metin) {
    _aramaBekleme?.cancel();
    _aramaBekleme = Timer(const Duration(milliseconds: 350), () {
      _arama = metin.trim();
      yenile();
    });
  }

  Future<void> _siralaSuzAc() async {
    final sonuc = await merkezSayfaAc<(Map<String, String>, String?)>(
      context,
      builder: (_) => _SiralaSuzPenceresi(
        suzgecler: widget.suzgecler,
        siralamalar: widget.siralamalar,
        suzgec: _suzgec,
        siralama: _siralama,
      ),
    );
    if (sonuc == null) return;
    _suzgec = sonuc.$1;
    _siralama = sonuc.$2;
    yenile();
  }

  void _suzgecKaldir(String ad) {
    _suzgec = Map.of(_suzgec)..remove(ad);
    yenile();
  }

  Widget _govde(BuildContext context) {
    final l10n = context.l10n;
    final aktif = _suzgec.entries.toList();
    final ust = <Widget>[
      if (widget.aramaVar || widget.suzgecler.isNotEmpty || widget.siralamalar.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              if (widget.aramaVar)
                Expanded(
                  child: TextField(
                    key: const Key('liste-ara'),
                    maxLength: GirdiSiniri.arama,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    decoration: InputDecoration(
                      hintText: l10n.listeAra,
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: _aramaDegisti,
                  ),
                )
              else
                const Spacer(),
              if (widget.suzgecler.isNotEmpty || widget.siralamalar.isNotEmpty)
                TextButton.icon(
                  key: const Key('liste-sirala-suz'),
                  onPressed: _siralaSuzAc,
                  icon: const Icon(Icons.tune),
                  label: Text(l10n.listeSiralaSuz),
                ),
            ],
          ),
        ),
      if (aktif.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Wrap(
            spacing: 6,
            children: [
              for (final e in aktif)
                InputChip(
                  key: Key('liste-cip-${e.key}'),
                  label: Text(_secenekEtiketi(l10n, e.key, e.value)),
                  deleteButtonTooltipMessage: l10n.listeSuzgecKaldir(_suzgecEtiketi(l10n, e.key)),
                  onDeleted: () => _suzgecKaldir(e.key),
                ),
            ],
          ),
        ),
    ];

    Widget liste;
    if (_hata != null && _ogeler.isEmpty) {
      liste = ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(l10n.ortakYuklenemedi, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                FilledButton.tonal(onPressed: yenile, child: Text(l10n.ortakTekrarDene)),
              ],
            ),
          ),
        ],
      );
    } else if (_ogeler.isEmpty && !_yukleniyor) {
      liste = ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              (widget.bosMetin ?? (l) => l.listeBos)(l10n),
              key: const Key('liste-bos'),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    } else {
      liste = ListView.separated(
        key: const Key('liste-ogeler'),
        controller: _kaydirma,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        itemCount: _ogeler.length + (_bitti ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i >= _ogeler.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final oge = _ogeler[i];
          final k = widget.kimlik(oge);
          final secili = _secim.seciliMi(k);
          return InkWell(
            key: Key('liste-oge-$k'),
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (_secim.acik) {
                _secim.degistir(k);
              } else {
                widget.onDokun?.call(oge);
              }
            },
            onLongPress: widget.topluEylemler.isEmpty ? null : () => _secim.baslat(k),
            child: widget.kart(context, oge, secili),
          );
        },
      );
    }

    return Column(
      children: [
        ...ust,
        Expanded(child: RefreshIndicator(onRefresh: yenile, child: liste)),
      ],
    );
  }

  String _suzgecEtiketi(AppLocalizations l10n, String ad) {
    for (final s in widget.suzgecler) {
      if (s.ad == ad) return s.etiket(l10n);
    }
    return ad;
  }

  String _secenekEtiketi(AppLocalizations l10n, String ad, String deger) {
    for (final s in widget.suzgecler) {
      if (s.ad != ad) continue;
      for (final o in s.secenekler) {
        if (o.deger == deger) return '${s.etiket(l10n)}: ${o.etiket(l10n)}';
      }
    }
    return deger;
  }

  List<T> get _seciliOgeler => [
        for (final o in _ogeler)
          if (_secim.seciliMi(widget.kimlik(o))) o,
      ];

  @override
  Widget build(BuildContext context) {
    final secimde = _secim.acik;
    final govde = _govde(context);
    final alt = secimde && widget.topluEylemler.isNotEmpty
        ? CokluSecimAltCubugu<T>(
            eylemler: widget.topluEylemler,
            secili: _seciliOgeler,
            onBitti: () {
              _secim.bitir();
              yenile();
            },
          )
        : null;
    final ustCubuk = secimde
        ? CokluSecimUstCubugu(
            sayi: _secim.sayi,
            onTumunu: () => _secim.tumunu(_ogeler.map(widget.kimlik)),
            onBitir: _secim.bitir,
          )
        : null;

    final icerik = PopScope(
      // Secim kipindeyken geri tusu once secimi kapatir.
      canPop: !secimde,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && secimde) _secim.bitir();
      },
      child: govde,
    );

    if (widget.baslik == null) {
      return Column(
        children: [
          ?ustCubuk,
          Expanded(child: icerik),
          ?alt,
        ],
      );
    }
    return Scaffold(
      appBar: ustCubuk ?? AppBar(title: Text(widget.baslik!)),
      body: icerik,
      bottomNavigationBar: alt,
      floatingActionButton: secimde ? null : widget.fab,
    );
  }
}

class _SiralaSuzPenceresi extends StatefulWidget {
  const _SiralaSuzPenceresi({
    required this.suzgecler,
    required this.siralamalar,
    required this.suzgec,
    required this.siralama,
  });

  final List<SuzgecTanimi> suzgecler;
  final List<SiralamaTanimi> siralamalar;
  final Map<String, String> suzgec;
  final String? siralama;

  @override
  State<_SiralaSuzPenceresi> createState() => _SiralaSuzPenceresiState();
}

class _SiralaSuzPenceresiState extends State<_SiralaSuzPenceresi> {
  late Map<String, String> _suzgec = Map.of(widget.suzgec);
  late String? _siralama = widget.siralama;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tema = Theme.of(context).textTheme;
    return SingleChildScrollView(
      key: const Key('liste-sirala-suz-penceresi'),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.siralamalar.isNotEmpty) ...[
            Text(l10n.listeSiralama, style: tema.titleSmall),
            for (final s in widget.siralamalar)
              ListTile(
                key: Key('liste-siralama-${s.deger}'),
                contentPadding: EdgeInsets.zero,
                title: Text(s.etiket(l10n)),
                trailing: _siralama == s.deger ? const Icon(Icons.check) : null,
                onTap: () => setState(() => _siralama = s.deger),
              ),
            const SizedBox(height: 8),
          ],
          if (widget.suzgecler.isNotEmpty) Text(l10n.listeSuzgecler, style: tema.titleSmall),
          for (final s in widget.suzgecler) ...[
            const SizedBox(height: 8),
            Text(s.etiket(l10n)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  key: Key('liste-suzgec-${s.ad}-hepsi'),
                  label: Text(l10n.listeHepsi),
                  selected: !_suzgec.containsKey(s.ad),
                  onSelected: (_) => setState(() => _suzgec.remove(s.ad)),
                ),
                for (final o in s.secenekler)
                  ChoiceChip(
                    key: Key('liste-suzgec-${s.ad}-${o.deger}'),
                    label: Text(o.etiket(l10n)),
                    selected: _suzgec[s.ad] == o.deger,
                    onSelected: (_) => setState(() => _suzgec[s.ad] = o.deger),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                key: const Key('liste-temizle'),
                onPressed: () => setState(() {
                  _suzgec = {};
                }),
                child: Text(l10n.listeTemizle),
              ),
              const Spacer(),
              FilledButton(
                key: const Key('liste-uygula'),
                onPressed: () => Navigator.of(context).pop((_suzgec, _siralama)),
                child: Text(l10n.listeUygula),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
