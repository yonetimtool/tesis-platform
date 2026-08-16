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

  /// Ust seviyeden acildiginda kullanicinin sectigi blok; bir blogun
  /// icindeyken kullanilmaz ([_etkinBlok]).
  String? _blok;

  /// Uzerinde calisilan blok — acik blok varsa O, yoksa secilen.
  String? get _etkinBlok {
    final acik = widget.blok;
    if (acik != null && acik.isNotEmpty) return acik;
    final secilen = _blok;
    return (secilen != null && secilen.isNotEmpty) ? secilen : null;
  }

  /// (P165) SUNUCUNUN ETKI OZETI — `null` = henuz sorulmadi/gelmedi.
  ///
  /// Yerel sayim (`daireler.where(kat)`) YALNIZ DAIREYI bilir; sakini,
  /// tahakkugu, talebi BILMEZ — oysa kaybedilen esas sey onlar.
  KatOnizleme? _onizleme;
  bool _onizlemeYukleniyor = false;

  /// Kacinci istegin cevabi bekleniyor — kullanici kati hizli degistirirse
  /// ONCEKI istek sonradan donup YANLIS ozeti yazabilirdi.
  int _istekSayaci = 0;

  /// Mali kayit varken IKINCI KAPI: kat numarasi ELLE yazilir.
  final _onayCtrl = TextEditingController();

  /// Ikinci kapi acildi mi — buton bunun uzerinden kilitlenir.
  bool get _kapiAcik {
    if (_onizleme?.maliKayit != true) return true;
    return _onayCtrl.text.trim() == '${_kat ?? ''}';
  }

  @override
  void dispose() {
    _onayCtrl.dispose();
    super.dispose();
  }

  /// Kat secilince ozeti ceker. BLOK YOKSA ISTEK ATILMAZ: uc `blok`u
  /// zorunlu tutar (min_length=1) ve bos gondermek 422 demekti.
  Future<void> _onizlemeCek(int kat) async {
    final blok = _etkinBlok;
    if (blok == null) return;
    final sira = ++_istekSayaci;
    setState(() => _onizlemeYukleniyor = true);
    try {
      final ozet = await ref
          .read(binaDuzenlemeApiProvider)
          .fetchKatOnizleme(blok: blok, kat: kat);
      if (!mounted || sira != _istekSayaci) return;
      setState(() {
        _onizleme = ozet;
        _onizlemeYukleniyor = false;
      });
    } on ApiException catch (e) {
      if (!mounted || sira != _istekSayaci) return;
      // OZET GELMEZSE SILME ENGELLENMEZ ama SESSIZ de kalmaz: kullanici
      // ozetsiz karar verdigini bilmeli.
      setState(() {
        _onizleme = null;
        _onizlemeYukleniyor = false;
        _hata = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(binaDuzenlemeControllerProvider);
    final blok = _etkinBlok;
    final daireler = blok == null ? const <EditorUnit>[] : _daireler(state, blok);
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
          // BLOK SECIMI — ust seviyeden acildiginda (bir bloga girilmeden).
          //
          // ONCE YOKTU ve islem SESSIZCE 422 aliyordu: uc `blok`u zorunlu
          // tutuyor (`min_length=1`), diyalog ise bos gonderiyordu. Web'de
          // modalin ilk alani zaten blok secimi — mobil ona hizalandi.
          if (widget.blok == null || widget.blok!.isEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _blok,
              decoration: InputDecoration(labelText: l10n.binaBlokEtiketi),
              items: [
                for (final b in state.blocks)
                  DropdownMenuItem(value: b.ad, child: Text(b.ad)),
              ],
              onChanged: (v) => setState(() {
                _blok = v;
                _kat = null;
                _onizleme = null;
                _hata = null;
                _onayCtrl.clear();
              }),
            ),
            const SizedBox(height: 12),
          ],
          // Blok secilene kadar kat listesi CIZILMEZ: baska bir blogun
          // katlarini gostermek, yanlis kati secmeye davet olurdu.
          if (blok == null)
            const SizedBox.shrink()
          else if (katlar.isEmpty)
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
              onChanged: (v) {
                setState(() {
                  _kat = v;
                  _hata = null;
                  _onizleme = null;
                  _onayCtrl.clear();
                });
                if (v != null) _onizlemeCek(v);
              },
            ),
          // YEREL SAYIM YALNIZ OZET YOKKEN: sunucunun ozeti geldiginde ayni
          // sayiyi iki kez yazmak (ve ikisi ayrisirsa hangisinin dogru
          // oldugunu tartistirmak) gereksiz.
          if (_kat != null && _onizleme == null) ...[
            const SizedBox(height: 12),
            // NE SILINECEGI ACIKCA YAZAR: "kati sil" tek basina kac
            // dairenin gidecegini soylemiyordu.
            Text(l10n.binaKatSilOzet(silinecek)),
          ],
          // (P165) ETKI OZETI — brief'in kurali: "kullanici ne
          // kaybedecegini SILMEDEN ONCE gorsun". Web'deki ile AYNI
          // kademeler: bos kat · daireli ama mali kayitsiz · mali kayitli.
          if (_kat != null && _onizlemeYukleniyor && _onizleme == null) ...[
            const SizedBox(height: 12),
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ] else if (_onizleme != null) ...[
            const SizedBox(height: 8),
            if (_onizleme!.bos)
              // BOS KAT: kaybedilecek bir sey yok, tek onayla gider.
              Text(
                l10n.binaKatBos,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else ...[
              Text(l10n.binaKatOzet(
                _onizleme!.daire,
                _onizleme!.sakin,
                _onizleme!.talep,
              )),
              const SizedBox(height: 2),
              Text(
                l10n.binaKatOzetMali(
                  _onizleme!.tahakkuk,
                  _onizleme!.odeme,
                  _onizleme!.rezervasyon,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_onizleme!.maliKayit) ...[
                const SizedBox(height: 8),
                // MALI KAYIT AYRI UYARI: sakin ya da talep yeniden
                // olusturulabilir, bir TAHSILAT KAYDI olusturulamaz.
                Text(
                  l10n.binaKatMaliUyari,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 8),
                // IKINCI KAPI: islev KALDIRILMADI (silme hala mumkun);
                // yalnizca KAZAYLA olmasi engellendi.
                TextField(
                  controller: _onayCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.binaKatOnayYaz(_kat!),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
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
          // MALI KAYIT VARSA kat numarasi yazilmadan dugme ACILMAZ.
          onPressed: (_kat == null || _etkinBlok == null || _mesgul || !_kapiAcik)
              ? null
              : _sil,
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
        // ONAY METNI SOMUT: "kati sil" tek basina kac dairenin, kac
        // sakinin gidecegini soylemiyordu. Ozet gelmediyse (blok-suz mod
        // ya da ag hatasi) eski GENEL metin kullanilir — onaysiz birakmak
        // degil, az bilgiyle onaylatmak.
        content: Text(
          _onizleme == null
              ? l10n.binaKatSilOnay(_kat!)
              : l10n.binaKatSilOzetOnay(
                  _etkinBlok ?? '',
                  _kat!,
                  _onizleme!.daire,
                  _onizleme!.sakin,
                  _onizleme!.tahakkuk +
                      _onizleme!.odeme +
                      _onizleme!.talep +
                      _onizleme!.rezervasyon,
                ),
        ),
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
          .deleteFloor(blok: _etkinBlok!, kat: _kat!);
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
