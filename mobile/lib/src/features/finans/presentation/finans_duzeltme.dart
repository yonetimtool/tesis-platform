/// (P253 Asama 2) FINANS DUZELTMELERI — mobil.
///
/// Web ile AYNI uclar ve govdeler: iptal (ters kayit), iade, virman,
/// acilis fisi, toplu tahsilat, faiz affi, odeme plani.
///
/// §C KURALI (docs/P253-kararlar.md):
///  1. Her eylem `finansOnayla` diyalogundan gecer — TUTAR ve HEDEF yazili.
///  2. Iptalde (ve geri almada) SEBEP ZORUNLU; sunucu da reddeder.
///  3. GERI AL mumkunse islemden sonra snackbar'da: virman/iade/acilis/
///     toplu tahsilat ters kayitla geri alinir — geri alma da SEBEP ister
///     (baglamdan otomatik metin gonderilmez). Geri alinamayan (iptalin
///     kendisi, faiz affi, odeme plani) diyalogda ONCEDEN yazilir.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/girdi_siniri.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/para.dart';
import '../../../core/ui/finans_onay.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../data/finans_api.dart';
import '../domain/finans_models.dart';
import 'tahsilat_screen.dart' show kasalarProvider;

const _aciklamaAzami = 500;

String _hata(AppLocalizations l10n, Object e) =>
    e is ApiException ? apiHataMetni(l10n, e) : l10n.ortakBeklenmeyenHata;

/// Islem hedefi: hedef bilgisi yoksa kasa adi (virman bacagi gibi).
String islemHedefi(FinansHareketi h) =>
    [h.hedef, h.kasaAd ?? ''].where((s) => s.isNotEmpty).join(' · ');

// ================================ GERI AL ================================== #

/// Verilen hareketleri ters kayitla GERI ALIR — sebep kullanicidan istenir.
/// Virmanda tek bacak yeter (sunucu iki bacagi birlikte ters kayitlar).
Future<bool> geriAl(
  BuildContext context,
  WidgetRef ref, {
  required List<String> hareketIdleri,
  required String hedef,
  required int tutarKurus,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final sebep = await finansOnayla(
    context,
    baslik: l10n.fdzGeriAlBaslik,
    hedef: hedef,
    tutar: tlTutar(tutarKurus),
    sonuc: l10n.fdzGeriAlSonuc,
    onayMetni: l10n.fdzGeriAl,
    sebepZorunlu: true,
    tehlikeli: true,
  );
  if (sebep == null) return false;
  final api = ref.read(finansApiProvider);
  try {
    for (final id in hareketIdleri) {
      await api.iptal(id, sebep);
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.fdzGeriAlindi)));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(_hata(l10n, e))));
    return false;
  }
}

/// Basari snackbar'i + "Geri al" eylemi. [onDegisti] geri almadan sonra.
void _geriAlinabilirBildir(
  BuildContext context,
  WidgetRef ref, {
  required String mesaj,
  required List<String> hareketIdleri,
  required String hedef,
  required int tutarKurus,
  VoidCallback? onDegisti,
}) {
  final l10n = context.l10n;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mesaj),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        key: const Key('fdz-geri-al'),
        label: l10n.fdzGeriAl,
        onPressed: () async {
          if (!context.mounted) return;
          final ok = await geriAl(context, ref,
              hareketIdleri: hareketIdleri, hedef: hedef, tutarKurus: tutarKurus);
          if (ok) onDegisti?.call();
        },
      ),
    ),
  );
}

// ================================= IPTAL =================================== #

/// Ters kayitla IPTAL — sebep zorunlu; ters kayit geri alinamaz (onceden yazili).
Future<bool> hareketIptalEt(BuildContext context, WidgetRef ref, FinansHareketi h) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final sebep = await finansOnayla(
    context,
    baslik: l10n.fdzIptalBaslik,
    hedef: islemHedefi(h),
    tutar: tlTutar(h.tutarKurus),
    sonuc: h.virmanGrupId != null
        ? '${l10n.fdzIptalVirmanNotu} ${l10n.fdzIptalSonuc}'
        : l10n.fdzIptalSonuc,
    onayMetni: l10n.fdzIptalEt,
    sebepZorunlu: true,
    tehlikeli: true,
  );
  if (sebep == null) return false;
  try {
    await ref.read(finansApiProvider).iptal(h.id, sebep);
    messenger.showSnackBar(SnackBar(content: Text(l10n.fdzIptalEdildi)));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(_hata(l10n, e))));
    return false;
  }
}

// ================================== IADE =================================== #

/// IADE — tutar varsayilan hareketin tutari (kismi olabilir; sunucu
/// kalan tutari asani reddeder). Sonra "Geri al".
Future<bool> hareketIadeEt(
  BuildContext context,
  WidgetRef ref,
  FinansHareketi h, {
  VoidCallback? onDegisti,
}) async {
  final l10n = context.l10n;
  final girdi = await merkezSayfaAc<({int tutar, String aciklama})>(
    context,
    builder: (_) => _TutarAciklamaFormu(
      baslik: l10n.fdzIade,
      varsayilanKurus: h.tutarKurus,
      tutarIpucu: l10n.fdzIadeTutarIpucu,
    ),
  );
  if (girdi == null || !context.mounted) return false;
  final hedef = islemHedefi(h);
  final onay = await finansOnayla(
    context,
    baslik: l10n.fdzIade,
    hedef: hedef,
    tutar: tlTutar(girdi.tutar),
    sonuc: l10n.fdzIadeSonuc,
    onayMetni: l10n.fdzIade,
  );
  if (onay == null || !context.mounted) return false;
  try {
    final iade = await ref
        .read(finansApiProvider)
        .iade(h.id, tutarKurus: girdi.tutar, aciklama: girdi.aciklama);
    if (context.mounted) {
      _geriAlinabilirBildir(context, ref,
          mesaj: l10n.fdzIadeYapildi,
          hareketIdleri: [iade.id],
          hedef: hedef,
          tutarKurus: girdi.tutar,
          onDegisti: onDegisti);
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_hata(l10n, e))));
    }
    return false;
  }
}

// ============================ DEFTER ISLEMLERI ============================== #

/// Defterden baslatilan islemler: virman ve acilis fisi.
Future<bool> defterIslemi(BuildContext context, WidgetRef ref, {VoidCallback? onDegisti}) async {
  final l10n = context.l10n;
  final secim = await merkezSayfaAc<String>(
    context,
    builder: (dctx) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.fdzIslemSec, style: Theme.of(dctx).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            key: const Key('fdz-sec-virman'),
            leading: const Icon(Icons.swap_horiz),
            title: Text(l10n.fdzVirman),
            onTap: () => Navigator.of(dctx).pop('virman'),
          ),
          ListTile(
            key: const Key('fdz-sec-acilis'),
            leading: const Icon(Icons.playlist_add_outlined),
            title: Text(l10n.fdzAcilis),
            onTap: () => Navigator.of(dctx).pop('acilis'),
          ),
        ],
      ),
    ),
  );
  if (secim == null || !context.mounted) return false;
  return secim == 'virman'
      ? virmanYap(context, ref, onDegisti: onDegisti)
      : acilisYap(context, ref, onDegisti: onDegisti);
}

Future<bool> virmanYap(BuildContext context, WidgetRef ref, {VoidCallback? onDegisti}) async {
  final l10n = context.l10n;
  final girdi = await merkezSayfaAc<_VirmanGirdisi>(context, builder: (_) => const _VirmanFormu());
  if (girdi == null || !context.mounted) return false;
  final hedef = '${girdi.kaynak.ad} → ${girdi.hedef.ad}';
  final onay = await finansOnayla(
    context,
    baslik: l10n.fdzVirman,
    hedef: hedef,
    tutar: tlTutar(girdi.tutar),
    sonuc: l10n.fdzVirmanSonuc,
    onayMetni: l10n.fdzVirman,
  );
  if (onay == null || !context.mounted) return false;
  try {
    final satirlar = await ref.read(finansApiProvider).virman(
          kaynakKasaId: girdi.kaynak.id,
          hedefKasaId: girdi.hedef.id,
          tutarKurus: girdi.tutar,
          aciklama: girdi.aciklama,
        );
    if (context.mounted && satirlar.isNotEmpty) {
      _geriAlinabilirBildir(context, ref,
          mesaj: l10n.fdzVirmanYapildi,
          // Tek bacak yeter: sunucu virmanin IKI bacagini birlikte ters kayitlar.
          hareketIdleri: [satirlar.first.id],
          hedef: hedef,
          tutarKurus: girdi.tutar,
          onDegisti: onDegisti);
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_hata(l10n, e))));
    }
    return false;
  }
}

Future<bool> acilisYap(BuildContext context, WidgetRef ref, {VoidCallback? onDegisti}) async {
  final l10n = context.l10n;
  final girdi = await merkezSayfaAc<_AcilisGirdisi>(context, builder: (_) => const _AcilisFormu());
  if (girdi == null || !context.mounted) return false;
  final hedef = '${girdi.kasa.ad} · ${girdi.giris ? l10n.fdzYonGiris : l10n.fdzYonCikis}';
  final onay = await finansOnayla(
    context,
    baslik: l10n.fdzAcilis,
    hedef: hedef,
    tutar: tlTutar(girdi.tutar),
    sonuc: l10n.fdzAcilisSonuc,
    onayMetni: l10n.ortakKaydet,
  );
  if (onay == null || !context.mounted) return false;
  try {
    final fis = await ref.read(finansApiProvider).acilis(
          kasaId: girdi.kasa.id,
          yon: girdi.giris ? 'giris' : 'cikis',
          tutarKurus: girdi.tutar,
          aciklama: girdi.aciklama,
        );
    if (context.mounted) {
      _geriAlinabilirBildir(context, ref,
          mesaj: l10n.fdzAcilisYapildi,
          hareketIdleri: [fis.id],
          hedef: hedef,
          tutarKurus: girdi.tutar,
          onDegisti: onDegisti);
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_hata(l10n, e))));
    }
    return false;
  }
}

// ============================ BORCLU ISLEMLERI ============================== #

String _daireHedefi(AppLocalizations l10n, List<Borclu> b) =>
    l10n.fdzDaireler(b.length, b.map((x) => x.unitNo).join(', '));

int _toplam(List<Borclu> b) => b.fold<int>(0, (t, x) => t + x.kalanKurus);

/// FAIZ AFFI — geri alinamaz (onceden yazili).
Future<bool> faizAffet(BuildContext context, WidgetRef ref, List<Borclu> secili) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final onay = await finansOnayla(
    context,
    baslik: l10n.fdzFaizAffi,
    hedef: _daireHedefi(l10n, secili),
    tutar: tlTutar(_toplam(secili)),
    sonuc: '${l10n.fdzSecimToplami}. ${l10n.fdzFaizAffiSonuc}',
    onayMetni: l10n.fdzFaizAffi,
    tehlikeli: true,
  );
  if (onay == null) return false;
  try {
    final s = await ref.read(finansApiProvider).faizAffi([for (final b in secili) b.unitId]);
    messenger.showSnackBar(
        SnackBar(content: Text(l10n.fdzFaizAffedildi(s.kalem, tlTutar(s.toplamKurus)))));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(_hata(l10n, e))));
    return false;
  }
}

/// ODEME PLANI — vadeler yayilir; geri alinamaz (yeni planla degistirilir).
Future<bool> odemePlaniUygula(BuildContext context, WidgetRef ref, List<Borclu> secili) async {
  final l10n = context.l10n;
  final girdi = await merkezSayfaAc<({int taksit, DateTime ilkVade})>(
    context,
    builder: (_) => const _OdemePlaniFormu(),
  );
  if (girdi == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  final onay = await finansOnayla(
    context,
    baslik: l10n.fdzOdemePlani,
    hedef: _daireHedefi(l10n, secili),
    tutar: tlTutar(_toplam(secili)),
    sonuc: '${l10n.fdzSecimToplami}. ${l10n.fdzPlanSonuc(girdi.taksit)}',
    onayMetni: l10n.fdzOdemePlani,
  );
  if (onay == null) return false;
  try {
    final daire = await ref.read(finansApiProvider).odemePlani(
          [for (final b in secili) b.unitId],
          taksitSayisi: girdi.taksit,
          ilkVade: girdi.ilkVade,
        );
    messenger.showSnackBar(SnackBar(content: Text(l10n.fdzPlanUygulandi(daire))));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(_hata(l10n, e))));
    return false;
  }
}

/// TOPLU TAHSILAT — secili borclulara, tutarlar kalan borcla dolu gelir
/// (duzenlenebilir). Sonra "Geri al" (tum satirlar ters kayit).
Future<bool> topluTahsilatYap(
  BuildContext context,
  WidgetRef ref,
  List<Borclu> secili, {
  VoidCallback? onDegisti,
}) async {
  final l10n = context.l10n;
  final girdi = await merkezSayfaAc<_TopluGirdisi>(
    context,
    builder: (_) => _TopluTahsilatFormu(borclular: secili),
  );
  if (girdi == null || !context.mounted) return false;
  final toplam = girdi.satirlar.fold<int>(0, (t, s) => t + s.tutarKurus);
  final hedef = '${girdi.kasa.ad} · ${_daireHedefi(l10n, secili)}';
  final onay = await finansOnayla(
    context,
    baslik: l10n.fdzTopluTahsilat,
    hedef: hedef,
    tutar: tlTutar(toplam),
    sonuc: l10n.fdzTopluSonuc,
    onayMetni: l10n.fdzTopluTahsilat,
  );
  if (onay == null || !context.mounted) return false;
  try {
    final yazilan = await ref
        .read(finansApiProvider)
        .topluTahsilat(kasaId: girdi.kasa.id, satirlar: girdi.satirlar);
    if (context.mounted) {
      _geriAlinabilirBildir(context, ref,
          mesaj: l10n.fdzTopluYapildi(yazilan.length),
          hareketIdleri: [for (final h in yazilan) h.id],
          hedef: hedef,
          tutarKurus: toplam,
          onDegisti: onDegisti);
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_hata(l10n, e))));
    }
    return false;
  }
}

// ================================ FORMLAR =================================== #

TextField _tutarAlani(TextEditingController c, String etiket, {Key? key, String? ipucu}) =>
    TextField(
      key: key,
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: GirdiSiniri.sinir(GirdiSiniri.tutar),
      decoration: InputDecoration(labelText: etiket, helperText: ipucu),
    );

TextField _aciklamaAlani(TextEditingController c, String etiket) => TextField(
      key: const Key('fdz-aciklama'),
      controller: c,
      maxLength: _aciklamaAzami,
      inputFormatters: [LengthLimitingTextInputFormatter(_aciklamaAzami)],
      decoration: InputDecoration(labelText: etiket),
    );

/// Kaydet / Vazgec satiri — gecersizse hata metni dugmenin USTUNDE.
Widget _eylemler(BuildContext context, {required String? hata, required VoidCallback onKaydet}) {
  final l10n = context.l10n;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (hata != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(hata, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.ortakVazgec)),
          const SizedBox(width: 8),
          FilledButton(key: const Key('fdz-form-kaydet'), onPressed: onKaydet, child: Text(l10n.ortakKaydet)),
        ],
      ),
    ],
  );
}

class _TutarAciklamaFormu extends StatefulWidget {
  const _TutarAciklamaFormu({required this.baslik, required this.varsayilanKurus, this.tutarIpucu});

  final String baslik;
  final int varsayilanKurus;
  final String? tutarIpucu;

  @override
  State<_TutarAciklamaFormu> createState() => _TutarAciklamaFormuState();
}

class _TutarAciklamaFormuState extends State<_TutarAciklamaFormu> {
  late final _tutar = TextEditingController(text: tlTutar(widget.varsayilanKurus));
  final _aciklama = TextEditingController();
  String? _hata;

  @override
  void dispose() {
    _tutar.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.baslik, style: Theme.of(context).textTheme.titleMedium),
          _tutarAlani(_tutar, l10n.finansAlanTutar, key: const Key('fdz-tutar'), ipucu: widget.tutarIpucu),
          _aciklamaAlani(_aciklama, l10n.finansAlanAciklama),
          _eylemler(context, hata: _hata, onKaydet: () {
            final k = tlMetniniKurusaCevir(_tutar.text);
            if (k == null || k <= 0) {
              setState(() => _hata = l10n.butTutarGecersiz);
              return;
            }
            Navigator.of(context).pop((tutar: k, aciklama: _aciklama.text.trim()));
          }),
        ],
      ),
    );
  }
}

typedef _VirmanGirdisi = ({Kasa kaynak, Kasa hedef, int tutar, String aciklama});

class _VirmanFormu extends ConsumerStatefulWidget {
  const _VirmanFormu();

  @override
  ConsumerState<_VirmanFormu> createState() => _VirmanFormuState();
}

class _VirmanFormuState extends ConsumerState<_VirmanFormu> {
  final _tutar = TextEditingController();
  final _aciklama = TextEditingController();
  Kasa? _kaynak;
  Kasa? _hedef;
  String? _hata;

  @override
  void dispose() {
    _tutar.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kasalar = ref.watch(kasalarProvider).value ?? const <Kasa>[];
    DropdownButtonFormField<Kasa> kasaSec(Key key, String etiket, Kasa? deger, ValueChanged<Kasa?> f) =>
        DropdownButtonFormField<Kasa>(
          key: key,
          isExpanded: true,
          initialValue: deger,
          decoration: InputDecoration(labelText: etiket),
          items: [for (final k in kasalar) DropdownMenuItem(value: k, child: Text(k.ad))],
          onChanged: f,
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.fdzVirman, style: Theme.of(context).textTheme.titleMedium),
          kasaSec(const Key('fdz-kaynak'), l10n.fdzKaynakKasa, _kaynak, (k) => setState(() => _kaynak = k)),
          kasaSec(const Key('fdz-hedef'), l10n.fdzHedefKasa, _hedef, (k) => setState(() => _hedef = k)),
          _tutarAlani(_tutar, l10n.finansAlanTutar, key: const Key('fdz-tutar')),
          _aciklamaAlani(_aciklama, l10n.finansAlanAciklama),
          _eylemler(context, hata: _hata, onKaydet: () {
            final k = tlMetniniKurusaCevir(_tutar.text);
            if (_kaynak == null || _hedef == null) {
              setState(() => _hata = l10n.finansSutunKasa);
              return;
            }
            if (_kaynak!.id == _hedef!.id) {
              setState(() => _hata = l10n.fdzAyniKasa);
              return;
            }
            if (k == null || k <= 0) {
              setState(() => _hata = l10n.butTutarGecersiz);
              return;
            }
            Navigator.of(context).pop<_VirmanGirdisi>(
                (kaynak: _kaynak!, hedef: _hedef!, tutar: k, aciklama: _aciklama.text.trim()));
          }),
        ],
      ),
    );
  }
}

typedef _AcilisGirdisi = ({Kasa kasa, bool giris, int tutar, String aciklama});

class _AcilisFormu extends ConsumerStatefulWidget {
  const _AcilisFormu();

  @override
  ConsumerState<_AcilisFormu> createState() => _AcilisFormuState();
}

class _AcilisFormuState extends ConsumerState<_AcilisFormu> {
  final _tutar = TextEditingController();
  final _aciklama = TextEditingController();
  Kasa? _kasa;
  bool _giris = true;
  String? _hata;

  @override
  void dispose() {
    _tutar.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kasalar = ref.watch(kasalarProvider).value ?? const <Kasa>[];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.fdzAcilis, style: Theme.of(context).textTheme.titleMedium),
          DropdownButtonFormField<Kasa>(
            key: const Key('fdz-kasa'),
            isExpanded: true,
            initialValue: _kasa,
            decoration: InputDecoration(labelText: l10n.finansSutunKasa),
            items: [for (final k in kasalar) DropdownMenuItem(value: k, child: Text(k.ad))],
            onChanged: (k) => setState(() => _kasa = k),
          ),
          const SizedBox(height: 8),
          Text(l10n.fdzYon),
          RadioGroup<bool>(
            groupValue: _giris,
            onChanged: (v) => setState(() => _giris = v ?? true),
            child: Column(
              children: [
                RadioListTile<bool>(
                    key: const Key('fdz-yon-giris'), value: true, title: Text(l10n.fdzYonGiris)),
                RadioListTile<bool>(
                    key: const Key('fdz-yon-cikis'), value: false, title: Text(l10n.fdzYonCikis)),
              ],
            ),
          ),
          _tutarAlani(_tutar, l10n.finansAlanTutar, key: const Key('fdz-tutar')),
          _aciklamaAlani(_aciklama, l10n.finansAlanAciklama),
          _eylemler(context, hata: _hata, onKaydet: () {
            final k = tlMetniniKurusaCevir(_tutar.text);
            if (_kasa == null) {
              setState(() => _hata = l10n.finansSutunKasa);
              return;
            }
            if (k == null || k <= 0) {
              setState(() => _hata = l10n.butTutarGecersiz);
              return;
            }
            Navigator.of(context).pop<_AcilisGirdisi>(
                (kasa: _kasa!, giris: _giris, tutar: k, aciklama: _aciklama.text.trim()));
          }),
        ],
      ),
    );
  }
}

class _OdemePlaniFormu extends StatefulWidget {
  const _OdemePlaniFormu();

  @override
  State<_OdemePlaniFormu> createState() => _OdemePlaniFormuState();
}

class _OdemePlaniFormuState extends State<_OdemePlaniFormu> {
  final _taksit = TextEditingController(text: '3');
  DateTime _vade = DateTime.now();
  String? _hata;

  @override
  void dispose() {
    _taksit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.fdzOdemePlani, style: Theme.of(context).textTheme.titleMedium),
          TextField(
            key: const Key('fdz-taksit'),
            controller: _taksit,
            keyboardType: TextInputType.number,
            maxLength: 2,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
            decoration: InputDecoration(labelText: l10n.fdzTaksitSayisi),
          ),
          OutlinedButton.icon(
            key: const Key('fdz-ilk-vade'),
            icon: const Icon(Icons.event_outlined),
            label: Text('${l10n.fdzIlkVade}: ${tarihBicimi(_vade, context.dilKodu)}'),
            onPressed: () async {
              final s = await showDatePicker(
                context: context,
                initialDate: _vade,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              );
              if (s != null) setState(() => _vade = s);
            },
          ),
          const SizedBox(height: 8),
          _eylemler(context, hata: _hata, onKaydet: () {
            final n = int.tryParse(_taksit.text);
            if (n == null || n < 2 || n > 36) {
              setState(() => _hata = l10n.fdzTaksitSayisi);
              return;
            }
            Navigator.of(context).pop((taksit: n, ilkVade: _vade));
          }),
        ],
      ),
    );
  }
}

typedef _TopluGirdisi = ({Kasa kasa, List<({String unitId, String? userId, int tutarKurus})> satirlar});

class _TopluTahsilatFormu extends ConsumerStatefulWidget {
  const _TopluTahsilatFormu({required this.borclular});

  final List<Borclu> borclular;

  @override
  ConsumerState<_TopluTahsilatFormu> createState() => _TopluTahsilatFormuState();
}

class _TopluTahsilatFormuState extends ConsumerState<_TopluTahsilatFormu> {
  /// Daire basina tutar denetleyicisi — kalan borcla dolu baslar.
  final _tutarlar = <String, TextEditingController>{};
  Kasa? _kasa;
  String? _hata;

  TextEditingController _tutar(Borclu b) =>
      _tutarlar.putIfAbsent(b.unitId, () => TextEditingController(text: tlTutar(b.kalanKurus)));

  @override
  void dispose() {
    for (final c in _tutarlar.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kasalar = ref.watch(kasalarProvider).value ?? const <Kasa>[];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.fdzTopluTahsilat, style: Theme.of(context).textTheme.titleMedium),
          DropdownButtonFormField<Kasa>(
            key: const Key('fdz-kasa'),
            isExpanded: true,
            initialValue: _kasa,
            decoration: InputDecoration(labelText: l10n.finansSutunKasa),
            items: [for (final k in kasalar) DropdownMenuItem(value: k, child: Text(k.ad))],
            onChanged: (k) => setState(() => _kasa = k),
          ),
          for (final b in widget.borclular)
            _tutarAlani(_tutar(b), '${b.unitNo}${b.ad == null ? '' : ' · ${b.ad}'}',
                key: Key('fdz-toplu-${b.unitId}')),
          const SizedBox(height: 8),
          _eylemler(context, hata: _hata, onKaydet: () {
            if (_kasa == null) {
              setState(() => _hata = l10n.finansSutunKasa);
              return;
            }
            final satirlar = <({String unitId, String? userId, int tutarKurus})>[];
            for (final b in widget.borclular) {
              final k = tlMetniniKurusaCevir(_tutar(b).text);
              if (k == null || k <= 0) {
                setState(() => _hata = l10n.butTutarGecersiz);
                return;
              }
              satirlar.add((unitId: b.unitId, userId: b.userId, tutarKurus: k));
            }
            Navigator.of(context).pop<_TopluGirdisi>((kasa: _kasa!, satirlar: satirlar));
          }),
        ],
      ),
    );
  }
}
