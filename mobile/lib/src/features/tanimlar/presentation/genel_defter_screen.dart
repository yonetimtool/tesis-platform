import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/liste_ekrani.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../data/defter_api.dart';
import '../domain/defter_tanimi.dart';
import 'defter_formu.dart';

/// (P253 Asama 2) TEK GENEL DEFTER EKRANI — hangi defter oldugunu yalniz
/// [DefterTanimi]dan bilir (web `DefterGorunumu` ile ayni fikir).
///
/// Liste kartina dokununca duzenleme; menude Duzenle / Sil. Silme onayi
/// KAYDIN ADINI yazar; sunucu 409 (kayit baska kayitlarda kullaniliyor)
/// donerse "pasiflestirebilirsiniz" yolunu soyleyen anlasilir metin.
class GenelDefterScreen extends ConsumerStatefulWidget {
  const GenelDefterScreen({super.key, required this.defter});

  final DefterTanimi defter;

  @override
  ConsumerState<GenelDefterScreen> createState() => _GenelDefterScreenState();
}

class _GenelDefterScreenState extends ConsumerState<GenelDefterScreen> {
  final _liste = GlobalKey<ListeEkraniState<Map<String, dynamic>>>();

  DefterTanimi get _d => widget.defter;

  /// Onceki bildirimi KAPATIR: art arda iki eylemde (kaydet, sonra sil)
  /// ikinci sonuc kuyrukta beklemesin — 409 "kullanimda" mesaji eski
  /// "Kaydedildi"nin arkasinda gorunmuyordu.
  void _bildir(String metin) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(metin)));

  String _ad(Map<String, dynamic> k) => '${k[_d.adAlani] ?? k['ad'] ?? k['id']}';

  Future<void> _form([Map<String, dynamic>? kayit]) async {
    final l10n = context.l10n;
    final tamam = await merkezSayfaAc<bool>(
      context,
      builder: (_) => DefterFormu(defter: _d, kayit: kayit),
    );
    if (tamam == true && mounted) {
      _bildir(l10n.tnmKaydedildi);
      await _liste.currentState?.yenile();
    }
  }

  Future<void> _sil(Map<String, dynamic> k) async {
    final l10n = context.l10n;
    final onay = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l10n.tnmSilBaslik),
        content: Text(l10n.tnmSilOnay(_ad(k)), key: const Key('defter-sil-onay')),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: Text(l10n.ortakVazgec)),
          FilledButton(
            key: const Key('defter-sil-evet'),
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(l10n.ortakSil),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    try {
      await ref.read(defterApiProvider).sil(_d.uc, k['id'].toString());
      if (!mounted) return;
      _bildir(l10n.tnmSilindi);
      await _liste.currentState?.yenile();
    } on ApiException catch (e) {
      if (!mounted) return;
      _bildir(e.statusCode == 409 ? l10n.tnmSilKullanimda : apiHataMetni(l10n, e));
    }
  }

  Future<void> _sayaclariUret() async {
    final l10n = context.l10n;
    final api = ref.read(defterApiProvider);
    final anaSayaclar = (await api.liste('/sayaclar/ana', limit: 200, offset: 0)).ogeler;
    if (!mounted) return;
    final secilen = await merkezSayfaAc<String>(
      context,
      builder: (dctx) => _AnaSayacSecimi(anaSayaclar: anaSayaclar),
    );
    if (secilen == null || !mounted) return;
    try {
      final s = await api.sayaclariUret(secilen);
      if (!mounted) return;
      _bildir(l10n.tnmSayacUretimSonuc('${s.olusturulan}', '${s.atlanan}'));
      await _liste.currentState?.yenile();
    } on ApiException catch (e) {
      if (mounted) _bildir(apiHataMetni(l10n, e));
    }
  }

  String _ozetDegeri(DefterAlani a, Map<String, dynamic> k) {
    final l10n = context.l10n;
    final ham = k[a.ozetAlani ?? a.ad];
    if (ham == null || '$ham'.isEmpty) return '';
    switch (a.tur) {
      case AlanTuru.kurus:
        return ham is num ? tlTutar(ham.toInt()) : '$ham';
      case AlanTuru.secim:
        for (final s in a.secenekler) {
          if (s.deger == '$ham') return s.etiket(l10n);
        }
        return '$ham';
      case AlanTuru.bool_:
        return '';
      default:
        return '$ham';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(_d.baslik(l10n), context.dilKodu)),
        actions: [
          if (_d.otomatikSayac)
            TextButton.icon(
              key: const Key('defter-sayac-uret'),
              icon: const Icon(Icons.auto_awesome_motion_outlined),
              label: Text(l10n.tnmSayacUret),
              onPressed: _sayaclariUret,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('defter-yeni'),
        onPressed: () => _form(),
        icon: const Icon(Icons.add),
        label: Text(l10n.tnmYeniKayit),
      ),
      body: ListeEkrani<Map<String, dynamic>>(
        key: _liste,
        kimlik: (k) => k['id'].toString(),
        bosMetin: (l) => l.tnmKayitYokAlt,
        yukle: (s) async {
          final r = await ref.read(defterApiProvider).liste(_d.uc, limit: s.limit, offset: s.offset);
          return ListeSayfasi(r.ogeler, toplam: r.toplam);
        },
        onDokun: _form,
        kart: (context, k, _) {
          final ozet = [
            for (final a in _d.alanlar)
              if (a.ozet) _ozetDegeri(a, k),
          ].where((x) => x.isNotEmpty).join(' · ');
          final pasif = k['aktif'] == false;
          return ListTile(
            key: Key('defter-kayit-${k['id']}'),
            title: Text(_ad(k)),
            subtitle: ozet.isEmpty && !pasif
                ? null
                : Text([if (ozet.isNotEmpty) ozet, if (pasif) l10n.tnmPasif].join(' · ')),
            trailing: PopupMenuButton<String>(
              key: Key('defter-menu-${k['id']}'),
              onSelected: (s) => s == 'sil' ? _sil(k) : _form(k),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'duzenle', child: Text(l10n.tnmDuzenle)),
                PopupMenuItem(value: 'sil', child: Text(l10n.ortakSil)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AnaSayacSecimi extends StatefulWidget {
  const _AnaSayacSecimi({required this.anaSayaclar});
  final List<Map<String, dynamic>> anaSayaclar;

  @override
  State<_AnaSayacSecimi> createState() => _AnaSayacSecimiState();
}

class _AnaSayacSecimiState extends State<_AnaSayacSecimi> {
  String? _secili;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.tnmSayacUretimBaslik, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const Key('defter-ana-sayac'),
            isExpanded: true,
            initialValue: _secili,
            decoration: InputDecoration(labelText: l10n.tnmAlanAnaSayac),
            items: [
              for (final s in widget.anaSayaclar)
                DropdownMenuItem(
                  value: s['id'].toString(),
                  child: Text('${s['ad'] ?? s['id']}', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _secili = v),
          ),
          const SizedBox(height: 8),
          Text(l10n.tnmSayacUretimNotu, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('defter-sayac-uret-onay'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: _secili == null ? null : () => Navigator.of(context).pop(_secili),
            child: Text(l10n.tnmSayacUret),
          ),
        ],
      ),
    );
  }
}

/// (P253 Asama 2) Muhasebe ayarlari — tek kayitlik form (web `Ayarlar`).
class MuhasebeAyarlariScreen extends ConsumerStatefulWidget {
  const MuhasebeAyarlariScreen({super.key});

  @override
  ConsumerState<MuhasebeAyarlariScreen> createState() => _MuhasebeAyarlariScreenState();
}

class _MuhasebeAyarlariScreenState extends ConsumerState<MuhasebeAyarlariScreen> {
  final _seri = TextEditingController();
  final _sira = TextEditingController();
  final _para = TextEditingController();
  bool _yuklendi = false;
  bool _mesgul = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _seri.dispose();
    _sira.dispose();
    _para.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      final a = await ref.read(defterApiProvider).muhasebeAyarlari();
      if (!mounted) return;
      setState(() {
        _seri.text = '${a['evrak_seri'] ?? ''}';
        _sira.text = '${a['evrak_sira'] ?? ''}';
        _para.text = '${a['para_birimi'] ?? ''}';
        _yuklendi = true;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _hata = apiHataMetni(context.l10n, e));
    }
  }

  Future<void> _kaydet() async {
    final l10n = context.l10n;
    final sira = int.tryParse(_sira.text.trim());
    if (sira == null) {
      setState(() => _hata = l10n.tnmSayiGecersiz(l10n.tnmAlanEvrakSira));
      return;
    }
    setState(() {
      _mesgul = true;
      _hata = null;
    });
    try {
      await ref.read(defterApiProvider).muhasebeAyarlariniKaydet({
        'evrak_seri': _seri.text.trim().toUpperCase(),
        'evrak_sira': sira,
        'para_birimi': _para.text.trim().toUpperCase(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.tnmKaydedildi)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _hata = apiHataMetni(l10n, e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(baslikBuyuk(l10n.tnmAyarlar, context.dilKodu))),
      body: !_yuklendi && _hata == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  key: const Key('muhasebe-seri'),
                  controller: _seri,
                  enabled: !_mesgul,
                  maxLength: 5,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: l10n.tnmAlanEvrakSeri,
                    helperText: l10n.tnmEvrakSeriIpucu,
                  ),
                ),
                TextField(
                  key: const Key('muhasebe-sira'),
                  controller: _sira,
                  enabled: !_mesgul,
                  maxLength: 12,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.tnmAlanEvrakSira),
                ),
                TextField(
                  key: const Key('muhasebe-para'),
                  controller: _para,
                  enabled: !_mesgul,
                  maxLength: 3,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(labelText: l10n.tnmAlanParaBirimi),
                ),
                Text(l10n.tnmParaBirimiNotu, style: Theme.of(context).textTheme.bodySmall),
                if (_hata != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_hata!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('muhasebe-kaydet'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: _mesgul ? null : _kaydet,
                  child: Text(l10n.ortakKaydet),
                ),
              ],
            ),
    );
  }
}
