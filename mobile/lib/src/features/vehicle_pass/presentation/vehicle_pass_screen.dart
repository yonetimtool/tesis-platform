import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/theme/home_tokens.dart';
import '../domain/vehicle_pass_models.dart';
import 'vehicle_pass_controller.dart';

/// "Araç Geçişleri" (G1) — admin + security.
///
/// Ana ekrandaki "Araç Plaka" karti buraya gelir (once "Bu bölüm yakında"
/// diyordu). Ekranin üç isi var:
///   * ACIK/KAPALI suzgeci + plaka aramasi (arama SUNUCUDA — normalize
///     eslesme "34 abc" == "34ABC" yalniz orada dogru calisir),
///   * ICERIDEKI araca CIKIS damgalama (yetkili roller),
///   * yeni GIRIS kaydi (409 = plaka zaten iceride).
///
/// Yetkisiz rol 403 alir; hata bandi yerine ACIKLAYICI bos durum cizilir —
/// "yetkin yok" bir ag hatasi degildir.
class VehiclePassScreen extends ConsumerWidget {
  const VehiclePassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vehiclePassControllerProvider);
    final controller = ref.read(vehiclePassControllerProvider.notifier);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.modulAracGecis, context.dilKodu)),
        actions: [
          IconButton(
            tooltip: l10n.ortakYenile,
            icon: const Icon(Icons.refresh),
            onPressed: state.loading ? null : controller.refresh,
          ),
        ],
      ),
      floatingActionButton: state.canManage && !state.erisimYok
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.directions_car_outlined),
              label: Text(l10n.aracYeniGiris),
              onPressed: () => _formAc(context, ref),
            )
          : null,
      body: Column(
        children: [
          if (!state.erisimYok) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                onSubmitted: controller.ara,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.aracPlakaAra,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
              ),
            ),
            _SuzgecSatiri(state: state, controller: controller),
            if (state.doluluk != null) _DolulukBandi(state: state),
          ],
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: _Govde(state: state),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _formAc(BuildContext context, WidgetRef ref) async {
    final kaydedildi = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _GirisFormu(),
    );
    if (kaydedildi == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.aracGirisKaydedildi)));
    }
  }
}

/// ACIK/KAPALI suzgeci — `SegmentedButton` yerine kaydirilabilir cip seridi:
/// uc secenek uzun cevirilerde (de/ru) 320 dp'ye sigmiyor.
class _SuzgecSatiri extends StatelessWidget {
  const _SuzgecSatiri({required this.state, required this.controller});

  final VehiclePassState state;
  final VehiclePassController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final etiket = {
      GecisSuzgeci.tumu: l10n.aracSuzgecTumu,
      GecisSuzgeci.iceride: l10n.aracSuzgecIceride,
      GecisSuzgeci.cikmis: l10n.aracSuzgecCikmis,
    };
    // SABIT YUKSEKLIK KULLANILMAZ (ilk surumde `SizedBox(height:)` vardi):
    // yukseklik cipi sikistirinca dokunma hedefi 48 dp'nin ALTINA duser ve
    // `androidTapTargetGuideline` haklı olarak düşer. tasks_screen'deki
    // kalip: kaydirilabilir Row, yukseklik icerikten gelir.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          for (final s in GecisSuzgeci.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(etiket[s]!),
                selected: state.suzgec == s,
                onSelected: (_) => controller.suzgecDegistir(s),
              ),
            ),
        ],
      ),
    );
  }
}

/// Agregat doluluk bandi — ayni ucu Otopark ekrani da kullanir.
class _DolulukBandi extends StatelessWidget {
  const _DolulukBandi({required this.state});

  final VehiclePassState state;

  @override
  Widget build(BuildContext context) {
    final d = state.doluluk!;
    final l10n = context.l10n;
    // Kapasite tanimsizsa UYDURMA yuzde uretilmez (sunucu da `oran: null`
    // doner): yalniz gercek arac sayisi gosterilir.
    final metin = d.kapasite == null || d.kapasite == 0
        ? l10n.sayacArac(d.dolu)
        : l10n.otoparkDoluKapasite('${d.dolu}', '${d.kapasite}');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Icon(
            Icons.local_parking_outlined,
            size: 18,
            color: okunurVurgu(context, Colors.blue),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${l10n.ozetOtoparkDoluluk}: $metin',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Govde extends ConsumerWidget {
  const _Govde({required this.state});

  final VehiclePassState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.erisimYok) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.lock_outline, size: 40),
          const SizedBox(height: 12),
          Text(l10n.aracErisimYok, textAlign: TextAlign.center),
        ],
      );
    }
    final hata = akisHatasiCoz(l10n, state.hataKimligi, state.errorMessage);
    if (hata != null && state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            hata,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      );
    }
    if (state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Text(
              state.sorgu.trim().isEmpty
                  ? l10n.aracListeBos
                  : l10n.aracAramaBos,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      itemCount: state.items.length,
      itemBuilder: (context, i) =>
          _GecisKarti(gecis: state.items[i], canManage: state.canManage),
    );
  }
}

class _GecisKarti extends ConsumerWidget {
  const _GecisKarti({required this.gecis, required this.canManage});

  final VehiclePass gecis;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = gecis;
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final vurgu = okunurVurgu(context, g.acik ? Colors.green : Colors.grey);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_car_outlined, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    g.plaka,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  g.acik ? l10n.aracRozetIceride : l10n.aracRozetCikti,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: vurgu),
                ),
              ],
            ),
            if (g.aracTanim != null || g.unitNo != null || g.ziyaretciMi) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 2,
                children: [
                  if (g.aracTanim != null) Text(g.aracTanim!),
                  if (g.unitNo != null) Text(l10n.aracDaire(g.unitNo!)),
                  if (g.ziyaretciMi) Text(l10n.aracRozetZiyaretci),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Text(
              l10n.aracGirisZamani(tarihSaatBicimi(g.girisZamani, dil)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (g.cikisZamani != null)
              Text(
                l10n.aracCikisZamani(tarihSaatBicimi(g.cikisZamani!, dil)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (g.kaydedenAd != null)
              Text(
                l10n.aracKaydeden(g.kaydedenAd!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (canManage && g.acik) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout, size: 18),
                  label: Text(l10n.aracCikisVer),
                  onPressed: () => _cikisVer(context, ref, g),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _cikisVer(
    BuildContext context,
    WidgetRef ref,
    VehiclePass g,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.aracCikisOnayBaslik),
        content: Text(g.plaka),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.ortakIptal),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.aracCikisVer),
          ),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await ref.read(vehiclePassControllerProvider.notifier).cikisVer(g.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.aracCikisVerildi)));
    } on ApiException catch (e) {
      // 409: gecis baska bir cihazdan zaten kapatilmis. Kullaniciya
      // "beklenmeyen hata" degil, OLAN sey soylenir.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.statusCode == 409 ? l10n.aracZatenKapali : apiHataMetni(l10n, e),
          ),
        ),
      );
    }
  }
}

/// Yeni arac GIRISI formu.
class _GirisFormu extends ConsumerStatefulWidget {
  const _GirisFormu();

  @override
  ConsumerState<_GirisFormu> createState() => _GirisFormuState();
}

class _GirisFormuState extends ConsumerState<_GirisFormu> {
  final _formKey = GlobalKey<FormState>();
  final _plaka = TextEditingController();
  final _tanim = TextEditingController();
  final _daire = TextEditingController();
  bool _ziyaretci = false;
  bool _gonderiliyor = false;
  String? _hata;

  @override
  void dispose() {
    _plaka.dispose();
    _tanim.dispose();
    _daire.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = context.l10n;
    setState(() {
      _gonderiliyor = true;
      _hata = null;
    });
    try {
      await ref
          .read(vehiclePassControllerProvider.notifier)
          .girisKaydet(
            VehiclePassDraft(
              plaka: _plaka.text.trim(),
              aracTanim: _tanim.text.trim(),
              unitNo: _daire.text.trim(),
              ziyaretciMi: _ziyaretci,
            ),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _gonderiliyor = false;
        // 409 = ayni plakanin ACIK gecisi var (yapisal garanti: kismi unique
        // indeks). Kullaniciya sebebi soylenir.
        _hata = e.statusCode == 409
            ? l10n.aracZatenIceride
            : apiHataMetni(l10n, e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gonderiliyor = false;
        _hata = l10n.ortakBeklenmeyenHata;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.aracYeniGiris,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _plaka,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: l10n.aracPlaka,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.aracPlakaZorunlu
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tanim,
                  decoration: InputDecoration(
                    labelText: l10n.aracTanimAlani,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _daire,
                  decoration: InputDecoration(
                    labelText: l10n.aracDaireAlani,
                    border: const OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.aracZiyaretciMi),
                  value: _ziyaretci,
                  onChanged: (v) => setState(() => _ziyaretci = v),
                ),
                if (_hata != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _hata!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _gonderiliyor ? null : _gonder,
                    child: Text(
                      _gonderiliyor ? l10n.ortakKaydediliyor : l10n.ortakKaydet,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
