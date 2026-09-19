import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/grafik/grafik_karti.dart';
import '../../../core/ui/gorsel_cozme.dart';
import '../../auth/data/current_user_provider.dart';
import '../data/anket_api.dart';
import '../domain/anket_models.dart';
import 'anket_form.dart';
import 'anket_oy_dokumu_screen.dart';
import '../../../core/ui/bos_durum.dart';

/// Anket ekrani — SAKIN oy verir, YONETIM acar/kapatir.
///
/// (P237 §3) P38'de bu ekran BILEREK salt-okumaydi ("olusturma/kapatma
/// YONETIM isidir ve panele"). P235'te yazilan KALICI PARITE KURALI bunu
/// gecersiz kildi: bir ozellik iki yuzeyde de bulunur. Yetki yine
/// SUNUCUDA; buradaki kapi (`canManageAnket`) yalniz UX.
///
/// Oy DEGISTIRILEMEZ, bu yuzden oy verilmis bir ankette oy butonlari HIC
/// CIZILMEZ — sunucu 409 dondurup kullaniciya hata gostermek yerine,
/// yapilamayacak seyi hic teklif etmiyoruz.
class AnketScreen extends ConsumerWidget {
  const AnketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final anketler = ref.watch(anketlerProvider);
    final role = ref.watch(currentUserRoleProvider).value;
    final yonetebilir = role?.canManageAnket ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.anketBaslik)),
      floatingActionButton: yonetebilir
          ? FloatingActionButton.extended(
              key: const Key('anket-yeni'),
              icon: const Icon(Icons.add),
              label: Text(l10n.anketYeni),
              onPressed: () => anketFormuAc(context),
            )
          : null,
      body: anketler.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', textAlign: TextAlign.center),
          ),
        ),
        data: (liste) => liste.isEmpty
            ? BosDurum(
                ikon: Icons.how_to_vote_outlined,
                baslik: l10n.anketYok,
                aciklama: l10n.anketYokAlt,
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(anketlerProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: liste.length,
                  itemBuilder: (_, i) =>
                      _AnketKarti(anket: liste[i], yonetebilir: yonetebilir),
                ),
              ),
      ),
    );
  }
}

class _AnketKarti extends ConsumerStatefulWidget {
  const _AnketKarti({required this.anket, this.yonetebilir = false});

  final Anket anket;
  final bool yonetebilir;

  @override
  ConsumerState<_AnketKarti> createState() => _AnketKartiState();
}

class _AnketKartiState extends ConsumerState<_AnketKarti> {
  bool _gonderiliyor = false;

  Future<void> _oyVer(String secenekId) async {
    if (_gonderiliyor) return;
    setState(() => _gonderiliyor = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(anketApiProvider).oyVer(widget.anket.id, secenekId);
      ref.invalidate(anketlerProvider);
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.anketOyHatasi('$e'))));
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = widget.anket;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(a.baslik,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                // ANONIM ROZETI: kullanici oy vermeden ONCE gormeli.
                if (a.anonim)
                  Chip(
                    key: const Key('anket-anonim-rozet'),
                    label: Text(l10n.anketAnonimRozet),
                    visualDensity: VisualDensity.compact,
                  ),
                if (!a.acik)
                  Chip(
                    label: Text(l10n.anketKapali),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (a.gorselUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                // TEK SATIR BILINCLI: `gorsel_cozme_denetimi` kilidi
                // `NetworkImage(` oncesindeki 60 karaktere bakiyor.
                child: Image(image: sinirliGorsel(context, NetworkImage(a.gorselUrl!), 720), fit: BoxFit.cover),
              ),
            ],
            if (a.aciklama != null) ...[
              const SizedBox(height: 4),
              Text(a.aciklama!, style: Theme.of(context).textTheme.bodySmall),
            ],
            // KVKK AYDINLATMASI — OY VERMEDEN ONCE.
            //
            // Oy verme davranisi kisisel veridir. Anonim OLMAYAN ankette
            // kullanici, oyunun adiyla birlikte yonetime gorunecegini
            // OY VERMEDEN ONCE bilmeli; sonradan soylemek bilgilendirme
            // sayilmaz.
            if (a.oyVerilebilir) ...[
              const SizedBox(height: 4),
              Text(
                key: const Key('anket-kvkk'),
                a.anonim ? l10n.anketAnonimBilgi : l10n.anketKvkkAdliUyari,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            for (final s in a.secenekler)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(s.metin)),
                    // Sonuc YALNIZ sunucu verdiyse cizilir: acik ankette
                    // sayi hic gelmez (surusel etki).
                    if (s.oy != null)
                      Text('${s.oy}',
                          style: const TextStyle(
                              fontFeatures: [FontFeature.tabularFigures()])),
                    if (a.oyVerilebilir) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _gonderiliyor ? null : () => _oyVer(s.id),
                        child: Text(l10n.anketOyVer),
                      ),
                    ],
                  ],
                ),
              ),
            if (a.oyVerdim == true)
              Text(l10n.anketOyVerdiniz,
                  style: Theme.of(context).textTheme.bodySmall),
            if (a.acik && !a.sonucVar)
              Text(l10n.anketSonucKapali,
                  style: Theme.of(context).textTheme.bodySmall),
            if (a.sonucVar)
              Text(l10n.anketToplamOy(a.toplamOy!),
                  style: Theme.of(context).textTheme.bodySmall),
            // (P237 §4) SONUC GRAFIGI — web'deki `Grafik` karsiligi.
            //
            // YALNIZ SUNUCU SAYILARI VERDIYSE cizilir: acik ankette
            // secenek `oy`lari null gelir (surusel etki) ve o durumda
            // sifirlarla bir grafik cizmek, "kimse oy vermedi" gibi
            // YANLIS bir dunya gostermek olurdu.
            if (a.sonucVar &&
                a.secenekler.any((s) => s.oy != null)) ...[
              const SizedBox(height: 8),
              GrafikKarti(
                key: const Key('anket-grafik'),
                baslik: l10n.anketSonuclar,
                bicimle: (v) => l10n.anketOyAdet('${v.round()}'),
                dilimler: [
                  for (final s in a.secenekler)
                    if (s.oy != null)
                      GrafikDilimi(ad: s.metin, deger: s.oy!.toDouble()),
                ],
              ),
            ],
            // KATILIM ORANI: payda sunucudan gelir ("kac kisiye gitti") ve
            // YALNIZ yonetime doner. Payda yoksa oran CIZILMEZ — uydurma
            // bir yuzde, katilimi oldugundan iyi ya da kotu gosterirdi.
            if (a.katilimYuzde case final yuzde?)
              Text(
                key: const Key('anket-katilim'),
                l10n.anketKatilim(
                    '${a.toplamOy}', '${a.hedefKisi}', '$yuzde'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            // (P237 §4) OY DOKUMU GIRISI — YALNIZ YONETIM ve YALNIZ ADLI
            // ankette. Anonim ankette dugmeyi gostermek, basildiginda
            // "veri yok" diyen bir yol acmakti; yapilamayacak seyi hic
            // teklif etmiyoruz (ayni ekrandaki oy dugmesi kurali).
            if (widget.yonetebilir && !a.anonim)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: Key('anket-dokum-${a.id}'),
                  icon: const Icon(Icons.how_to_vote_outlined),
                  label: Text(l10n.anketOyDokumu),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AnketOyDokumuScreen(anket: a),
                    ),
                  ),
                ),
              ),
            if (widget.yonetebilir && a.aktif)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: Key('anket-kapat-${a.id}'),
                  onPressed: _gonderiliyor
                      ? null
                      : () async {
                          setState(() => _gonderiliyor = true);
                          try {
                            await ref
                                .read(anketApiProvider)
                                .kapat(a.id);
                            ref.invalidate(anketlerProvider);
                          } finally {
                            if (mounted) {
                              setState(() => _gonderiliyor = false);
                            }
                          }
                        },
                  child: Text(l10n.anketKapat),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
