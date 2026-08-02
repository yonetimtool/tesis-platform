import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/theme/home_tokens.dart';
import '../domain/violation_models.dart';
import '../../../core/ui/merkez_diyalog.dart';
import 'violations_controller.dart';

/// Durum/kaynak ADLARI — enum GORUNEN METIN TASIMAZ (README §15), etiket
/// cizim aninda burada cozulur. `switch`in `default` dali YOKTUR: yeni bir
/// durum eklenirse derleyici ceviriyi zorlar.
String ihlalDurumAdi(AppLocalizations l10n, IhlalDurum d) => switch (d) {
  IhlalDurum.yeni => l10n.ihlalDurumYeni,
  IhlalDurum.inceleniyor => l10n.ihlalDurumInceleniyor,
  IhlalDurum.kapatildi => l10n.ihlalDurumKapatildi,
};

String ihlalKaynakAdi(AppLocalizations l10n, IhlalKaynak k) => switch (k) {
  IhlalKaynak.kamera => l10n.ihlalKaynakKamera,
  IhlalKaynak.manuel => l10n.ihlalKaynakManuel,
  IhlalKaynak.devriye => l10n.ihlalKaynakDevriye,
};

Color _durumRengi(IhlalDurum d) => switch (d) {
  IhlalDurum.yeni => Colors.red,
  IhlalDurum.inceleniyor => Colors.orange,
  IhlalDurum.kapatildi => Colors.green,
};

/// "İhlaller" (G2) — admin + yonetici + security okur.
///
/// Ana ekrandaki "İhlaller" karti buraya gelir. Akis: yeni → inceleniyor →
/// kapatildi. KAPATMA yalniz admin (dort-goz kurali); `kapatildi` TERMINAL.
/// yonetici OKUR ama eylem dugmesi GORMEZ.
class ViolationsScreen extends ConsumerWidget {
  const ViolationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(violationsControllerProvider);
    final controller = ref.read(violationsControllerProvider.notifier);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.modulIhlaller, context.dilKodu)),
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
              icon: const Icon(Icons.report_outlined),
              label: Text(l10n.ihlalYeni),
              onPressed: () => _formAc(context),
            )
          : null,
      body: Column(
        children: [
          if (!state.erisimYok)
            _SuzgecSatiri(state: state, controller: controller),
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

  static Future<void> _formAc(BuildContext context) async {
    final acildi = await merkezSayfaAc<bool>(
      context,
      builder: (_) => const _IhlalFormu(),
    );
    if (acildi == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.ihlalAcildi)));
    }
  }
}

class _SuzgecSatiri extends StatelessWidget {
  const _SuzgecSatiri({required this.state, required this.controller});

  final ViolationsState state;
  final ViolationsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Dort cip uzun cevirilerde (de/ru) 320 dp'ye sigmaz — yatay kaydirilir.
    // SABIT YUKSEKLIK YOK: yukseklik cipi sikistirinca dokunma hedefi 48 dp
    // esiginin altina duser (bkz. arac ekranindaki ayni not).
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(l10n.aracSuzgecTumu),
              selected: state.suzgec == null,
              onSelected: (_) => controller.suzgecDegistir(null),
            ),
          ),
          for (final d in IhlalDurum.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(ihlalDurumAdi(l10n, d)),
                selected: state.suzgec == d,
                onSelected: (_) => controller.suzgecDegistir(d),
              ),
            ),
        ],
      ),
    );
  }
}

class _Govde extends StatelessWidget {
  const _Govde({required this.state});

  final ViolationsState state;

  @override
  Widget build(BuildContext context) {
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
          Text(l10n.ihlalErisimYok, textAlign: TextAlign.center),
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
          Center(child: Text(l10n.ihlalListeBos, textAlign: TextAlign.center)),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      itemCount: state.items.length,
      itemBuilder: (context, i) => _IhlalKarti(
        ihlal: state.items[i],
        canManage: state.canManage,
        canClose: state.canClose,
      ),
    );
  }
}

class _IhlalKarti extends ConsumerWidget {
  const _IhlalKarti({
    required this.ihlal,
    required this.canManage,
    required this.canClose,
  });

  final Ihlal ihlal;
  final bool canManage;
  final bool canClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = ihlal;
    final l10n = context.l10n;
    final vurgu = okunurVurgu(context, _durumRengi(i.durum));
    final gecisler = canManage
        ? ihlalSonrakiDurumlar(i.durum, adminMi: canClose)
        : const <IhlalDurum>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    i.baslik,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  ihlalDurumAdi(l10n, i.durum),
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: vurgu),
                ),
              ],
            ),
            if (i.aciklama != null) ...[
              const SizedBox(height: 4),
              Text(i.aciklama!),
            ],
            const SizedBox(height: 4),
            Wrap(
              spacing: 10,
              runSpacing: 2,
              children: [
                Text(
                  ihlalKaynakAdi(l10n, i.kaynak),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (i.konum != null)
                  Text(i.konum!, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  tarihSaatBicimi(i.createdAt, context.dilKodu),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (i.olusturanAd != null)
              Text(
                l10n.ihlalKaydeden(i.olusturanAd!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (gecisler.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final hedef in gecisler)
                    OutlinedButton(
                      onPressed: () => _degistir(context, ref, i, hedef),
                      child: Text(
                        hedef == IhlalDurum.kapatildi
                            ? l10n.ihlalKapat
                            : l10n.ihlalIncelemeyeAl,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _degistir(
    BuildContext context,
    WidgetRef ref,
    Ihlal i,
    IhlalDurum hedef,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    // KAPATMA geri alinamaz — onay istenir (terminal durum).
    if (hedef == IhlalDurum.kapatildi) {
      final onay = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.ihlalKapat),
          content: Text(l10n.ihlalKapatmaOnay),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.ortakIptal),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.ihlalKapat),
            ),
          ],
        ),
      );
      if (onay != true) return;
    }
    try {
      await ref
          .read(violationsControllerProvider.notifier)
          .durumDegistir(i.id, hedef);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.ihlalDurumGuncellendi)),
      );
    } on ApiException catch (e) {
      // 409 = kayit baska bir yerden kapatilmis (terminal). Kullaniciya
      // "beklenmeyen hata" degil OLAN sey soylenir.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.statusCode == 409
                ? l10n.ihlalKapaliDegistirilemez
                : apiHataMetni(l10n, e),
          ),
        ),
      );
    }
  }
}

class _IhlalFormu extends ConsumerStatefulWidget {
  const _IhlalFormu();

  @override
  ConsumerState<_IhlalFormu> createState() => _IhlalFormuState();
}

class _IhlalFormuState extends ConsumerState<_IhlalFormu> {
  final _formKey = GlobalKey<FormState>();
  final _baslik = TextEditingController();
  final _aciklama = TextEditingController();
  final _konum = TextEditingController();
  IhlalKaynak _kaynak = IhlalKaynak.manuel;
  bool _gonderiliyor = false;
  String? _hata;

  @override
  void dispose() {
    _baslik.dispose();
    _aciklama.dispose();
    _konum.dispose();
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
          .read(violationsControllerProvider.notifier)
          .ac(
            IhlalDraft(
              baslik: _baslik.text.trim(),
              aciklama: _aciklama.text.trim(),
              kaynak: _kaynak,
              konum: _konum.text.trim(),
            ),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _gonderiliyor = false;
        _hata = apiHataMetni(l10n, e);
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
                  l10n.ihlalYeni,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _baslik,
                  decoration: InputDecoration(
                    labelText: l10n.ihlalBaslikAlani,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.ihlalBaslikZorunlu
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _aciklama,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.ihlalAciklamaAlani,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _konum,
                  decoration: InputDecoration(
                    labelText: l10n.ihlalKonumAlani,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                // `isExpanded` ZORUNLU (§15 kalibi): uzun Almanca etiket +
                // prefixIcon 320 dp'de tasirir.
                DropdownButtonFormField<IhlalKaynak>(
                  isExpanded: true,
                  initialValue: _kaynak,
                  decoration: InputDecoration(
                    labelText: l10n.ihlalKaynakAlani,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final k in IhlalKaynak.values)
                      DropdownMenuItem(
                        value: k,
                        child: Text(ihlalKaynakAdi(l10n, k)),
                      ),
                  ],
                  onChanged: (v) =>
                      setState(() => _kaynak = v ?? IhlalKaynak.manuel),
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
