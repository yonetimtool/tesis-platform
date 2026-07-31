import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/theme/home_tokens.dart';
import '../domain/anpr_models.dart';
import 'anpr_controller.dart';

/// Durum/yon ADLARI — enum GORUNEN METIN TASIMAZ (README §15). `switch`in
/// `default` dali YOKTUR: yeni bir durum eklenirse derleyici ceviriyi zorlar.
String anprDurumAdi(AppLocalizations l10n, AnprDurum d) => switch (d) {
  AnprDurum.islendi => l10n.anprDurumIslendi,
  AnprDurum.onayBekliyor => l10n.anprDurumOnayBekliyor,
  AnprDurum.yokSayildi => l10n.anprDurumYokSayildi,
  AnprDurum.hata => l10n.anprDurumHata,
};

String anprYonAdi(AppLocalizations l10n, AnprYon y) => switch (y) {
  AnprYon.giris => l10n.anprYonGiris,
  AnprYon.cikis => l10n.anprYonCikis,
  AnprYon.bilinmiyor => l10n.anprYonBilinmiyor,
};

/// Sunucunun KISA KODUNU aktif dile cevirir. Kod bilinmiyorsa `null` doner ve
/// ekran hicbir sey gostermez — ham kodu kullaniciya basmak (orn.
/// "otomatik_cikis_kapali") ceviri BOSLUGUNU gizlemek olurdu.
String? anprNedenAdi(AppLocalizations l10n, String? kod) => switch (kod) {
  'dusuk_guven' => l10n.anprNedenDusukGuven,
  'zaten_iceride' => l10n.anprNedenZatenIceride,
  'acik_gecis_yok' => l10n.anprNedenAcikGecisYok,
  'otomatik_cikis_kapali' => l10n.anprNedenOtomatikCikisKapali,
  'elle_reddedildi' => l10n.anprNedenElleReddedildi,
  'anpr_plaka_bicimi' => l10n.anprNedenPlakaBicimi,
  _ => null,
};

Color _durumRengi(AnprDurum d) => switch (d) {
  AnprDurum.islendi => Colors.green,
  AnprDurum.onayBekliyor => Colors.orange,
  AnprDurum.yokSayildi => Colors.grey,
  AnprDurum.hata => Colors.red,
};

/// "Plaka Okumaları" (P17) — ANPR olay defteri + ONAY KUYRUGU.
///
/// Kamera kutusu olaylari `X-ANPR-Key` ile YAZAR; bu ekran yalniz OKUR ve
/// dusuk guvenli okumalara insan karari verir. RBAC arac gecisi listesiyle
/// ayni kume (admin + security): plaka kisisel veriye baglanabilir (KVKK).
class AnprScreen extends ConsumerWidget {
  const AnprScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(anprControllerProvider);
    final controller = ref.read(anprControllerProvider.notifier);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.modulPlakaOlaylari, context.dilKodu)),
        actions: [
          IconButton(
            tooltip: l10n.ortakYenile,
            icon: const Icon(Icons.refresh),
            onPressed: state.loading ? null : controller.refresh,
          ),
        ],
      ),
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
}

class _SuzgecSatiri extends StatelessWidget {
  const _SuzgecSatiri({required this.state, required this.controller});

  final AnprState state;
  final AnprController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // SABIT YUKSEKLIK YOK: yukseklik cipi sikistirinca dokunma hedefi 48 dp
    // esiginin altina duser (P8'de olculdu).
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
          for (final d in AnprDurum.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(anprDurumAdi(l10n, d)),
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

  final AnprState state;

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
          Text(l10n.anprErisimYok, textAlign: TextAlign.center),
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
          Center(child: Text(l10n.anprListeBos, textAlign: TextAlign.center)),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: state.items.length,
      itemBuilder: (context, i) =>
          _OlayKarti(olay: state.items[i], canDecide: state.canDecide),
    );
  }
}

class _OlayKarti extends ConsumerWidget {
  const _OlayKarti({required this.olay, required this.canDecide});

  final AnprOlay olay;
  final bool canDecide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = olay;
    final l10n = context.l10n;
    final vurgu = okunurVurgu(context, _durumRengi(o.durum));
    final neden = anprNedenAdi(l10n, o.durumNedeni);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // DURUM METNI SARILIR (olculdu): "Ожидает подтверждения" 320 dp'de
            // plakayla ayni satira sigmiyor ve 33 px tasiyordu. `Wrap` ikisini
            // gerektiginde alt alta alir; kirpma yapmaz — durum metni
            // kirpilirsa kullanici "Onay bek..." okur ki bu bilgi kaybidir.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 2,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_car_outlined, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      o.plaka,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Text(
                  anprDurumAdi(l10n, o.durum),
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: vurgu),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 10,
              runSpacing: 2,
              children: [
                Text(
                  anprYonAdi(l10n, o.yon),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (o.kamera != null)
                  Text(o.kamera!, style: Theme.of(context).textTheme.bodySmall),
                Text(
                  tarihSaatBicimi(o.zaman, context.dilKodu),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (o.guvenYuzde != null)
                  Text(
                    l10n.anprGuven('${o.guvenYuzde}'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            if (neden != null)
              Text(neden, style: Theme.of(context).textTheme.bodySmall),
            if (canDecide && o.onayBekliyor) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton(
                    onPressed: () => _karar(context, ref, onay: false),
                    child: Text(l10n.anprReddet),
                  ),
                  FilledButton(
                    onPressed: () => _onayAc(context, ref),
                    child: Text(l10n.anprOnayla),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Onay diyalogu — plaka DUZELTILEBILIR (bir-iki karakter yanlis okunmasi
  /// en yaygin OCR hatasidir; P15'te Frigate'in kendi toleransi 1 karakter).
  Future<void> _onayAc(BuildContext context, WidgetRef ref) async {
    final sonuc = await showDialog<String>(
      context: context,
      builder: (ctx) => _OnayDiyalogu(plaka: olay.plaka),
    );
    if (sonuc == null || !context.mounted) return;
    await _karar(context, ref, onay: true, plaka: sonuc);
  }

  Future<void> _karar(
    BuildContext context,
    WidgetRef ref, {
    required bool onay,
    String? plaka,
  }) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(anprControllerProvider.notifier)
          .karar(olay.id, onay: onay, plaka: plaka);
      messenger.showSnackBar(SnackBar(content: Text(l10n.anprKararUygulandi)));
    } on ApiException catch (e) {
      // 409: baska bir cihaz bu okumayi zaten karara baglamis.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.statusCode == 409
                ? l10n.anprOnayBeklemiyor
                : apiHataMetni(l10n, e),
          ),
        ),
      );
    }
  }
}

/// Onay diyalogu AYRI BIR WIDGET'tir (olculdu).
///
/// Ilk surumde `showDialog` cagrisinin hemen ardindan `ctrl.dispose()`
/// yapiliyordu; diyalog KAPANIS ANIMASYONU sirasinda hala yeniden
/// cizildigi icin "A TextEditingController was used after being disposed"
/// atiyordu. Denetleyicinin sahibi diyalogun KENDISI olmali ki omru
/// widget'in omruyle ayni olsun.
///
/// Icerik ayrica KAYDIRILABILIR: dar/kisa ekranda (bes eksen surusu) sabit
/// `Column` tasiyordu.
class _OnayDiyalogu extends StatefulWidget {
  const _OnayDiyalogu({required this.plaka});

  final String plaka;

  @override
  State<_OnayDiyalogu> createState() => _OnayDiyaloguState();
}

class _OnayDiyaloguState extends State<_OnayDiyalogu> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.plaka,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.anprOnayBaslik),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.anprOnayAciklama),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l10n.aracPlaka,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.ortakIptal),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: Text(l10n.anprOnayla),
        ),
      ],
    );
  }
}
