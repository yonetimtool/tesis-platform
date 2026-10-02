/// (P250 §9) OTOMASYON KURALLARI — mobil (web `KurallarKarti` ikizi).
///
/// Her kural TEK CÜMLE; yanında aç/kapat, en son ne zaman çalıştığı ve
/// ne yaptığı; tekil kurallarda (hatırlatma, gecikme faizi) "bugün
/// çalışsaydı". Yeni kural dört adımlı sihirbazla kurulur.
///
/// Hatırlatma TEK KAYIT: buradaki anahtar ile "Ayarla"nın açtığı
/// hatırlatma ekranı (§7) ve web aynı `hatirlatma-ayari` kaydını yazar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../data/hatirlatma_api.dart';
import '../data/otomasyon_api.dart';
import 'hatirlatma_cumlesi.dart';
import 'kural_cumlesi.dart';
import 'kural_sihirbazi_screen.dart';
import 'otomatik_hatirlatma_screen.dart';

String _buAy(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

class OtomasyonKurallariScreen extends ConsumerWidget {
  const OtomasyonKurallariScreen({super.key});

  void _tazele(WidgetRef ref) {
    ref.invalidate(planKurallariProvider);
    ref.invalidate(giderKurallariProvider);
    ref.invalidate(gecikmeKuraliProvider);
    ref.invalidate(hatirlatmaAyariProvider);
    ref.invalidate(sonCalismalarProvider);
    ref.invalidate(hatirlatmaOnizlemeProvider);
    ref.invalidate(gecikmeOnizlemeProvider);
  }

  Future<void> _yap(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(OtomasyonApi api) is_,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await is_(ref.read(otomasyonApiProvider));
      _tazele(ref);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    }
  }

  Future<void> _sil(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(OtomasyonApi api) is_,
  ) async {
    final l10n = context.l10n;
    final tamam = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(l10n.otoKuralSilOnay),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l10n.ortakIptal),
          ),
          FilledButton(
            key: const Key('kural-sil-onay'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l10n.ortakSil),
          ),
        ],
      ),
    );
    if (tamam == true && context.mounted) await _yap(context, ref, is_);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final planlar = ref.watch(planKurallariProvider);
    final giderler = ref.watch(giderKurallariProvider);
    final hatirlatma = ref.watch(hatirlatmaAyariProvider);
    final gecikme = ref.watch(gecikmeKuraliProvider);
    final sonlar = ref.watch(sonCalismalarProvider).value ?? const {};
    final hOniz = ref.watch(hatirlatmaOnizlemeProvider).value;
    final gOniz = ref.watch(gecikmeOnizlemeProvider).value;

    final kartlar = <Widget>[];
    for (final p in planlar.value ?? const <PlanKurali>[]) {
      kartlar.add(
        _KuralKarti(
          id: p.id,
          cumle: planCumlesi(
            l10n,
            dil,
            ad: p.ad,
            dagitim: p.dagitim,
            tutarKurus: p.tutarKurus,
            toplamTutarKurus: p.toplamTutarKurus,
            gun: p.gun,
            vadeGun: p.vadeGun,
          ),
          son: sonCalismaCumlesi(l10n, dil, sonlar[p.id]),
          ek: p.ertelenenDonem == _buAy(DateTime.now())
              ? l10n.otoKuralBuAyAtlanacak
              : null,
          aktif: p.aktif,
          onAnahtar: (v) => _yap(context, ref, (a) => a.planAktif(p.id, v)),
          eylemler: [
            TextButton(
              key: Key('kural-atla-${p.id}'),
              onPressed: () => _yap(
                context,
                ref,
                (a) => a.planErtele(p.id, _buAy(DateTime.now())),
              ),
              child: Text(l10n.otoKuralBuAyAtla),
            ),
            TextButton(
              key: Key('kural-sil-${p.id}'),
              onPressed: () => _sil(context, ref, (a) => a.planSil(p.id)),
              child: Text(l10n.ortakSil),
            ),
          ],
        ),
      );
    }
    for (final g in giderler.value ?? const <GiderKurali>[]) {
      kartlar.add(
        _KuralKarti(
          id: g.id,
          cumle: giderCumlesi(
            l10n,
            dil,
            ad: g.ad,
            tutarKurus: g.tutarKurus,
            periyot: g.periyot,
            sonrakiTarih: g.sonrakiTarih,
            otomatikOnay: g.otomatikOnay,
          ),
          son: sonCalismaCumlesi(l10n, dil, sonlar[g.id]),
          aktif: g.aktif,
          onAnahtar: (v) => _yap(context, ref, (a) => a.giderAktif(g.id, v)),
          eylemler: [
            TextButton(
              key: Key('kural-sil-${g.id}'),
              onPressed: () => _sil(context, ref, (a) => a.giderSil(g.id)),
              child: Text(l10n.ortakSil),
            ),
          ],
        ),
      );
    }
    final h = hatirlatma.value;
    if (h != null) {
      kartlar.add(
        _KuralKarti(
          id: 'borc_hatirlatma',
          cumle: hatirlatmaCumlesi(l10n, h),
          son: sonCalismaCumlesi(l10n, dil, sonlar['borc_hatirlatma']),
          ek: hOniz == null
              ? null
              : l10n.otoKuralBugunHatirlatma('${hOniz.adet}'),
          aktif: h.aktif,
          onAnahtar: (v) => _yap(context, ref, (a) => a.hatirlatmaAktif(v)),
          eylemler: [
            TextButton(
              key: const Key('kural-hatirlatma-ayarla'),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OtomatikHatirlatmaScreen(),
                  ),
                );
                _tazele(ref);
              },
              child: Text(l10n.otoKuralAyarla),
            ),
          ],
        ),
      );
    }
    final g = gecikme.value;
    if (g != null) {
      kartlar.add(
        _KuralKarti(
          id: 'gecikme_faizi',
          cumle: gecikmeCumlesi(l10n, g),
          son: sonCalismaCumlesi(l10n, dil, sonlar['gecikme_faizi']),
          ek: gOniz == null || !g.uygula
              ? null
              : l10n.otoKuralBugunGecikme(
                  '${gOniz.adet}',
                  tlIsaretli(gOniz.toplamKurus, dil),
                ),
          aktif: g.uygula,
          onAnahtar: (v) => _yap(context, ref, (a) => a.gecikmeAktif(v)),
        ),
      );
    }

    final yukleniyor = planlar.isLoading || giderler.isLoading;
    final hata = planlar.hasError || giderler.hasError;
    final bos = !yukleniyor &&
        (planlar.value?.isEmpty ?? false) &&
        (giderler.value?.isEmpty ?? false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.otoKurallarEkranBaslik)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('kural-yeni'),
        icon: const Icon(Icons.add),
        label: Text(l10n.otoKuralYeni),
        onPressed: () async {
          final kaydedildi = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const KuralSihirbaziScreen()),
          );
          if (kaydedildi == true) _tazele(ref);
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async => _tazele(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text(
              l10n.otoKurallarAlt,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (yukleniyor) const LinearProgressIndicator(),
            if (hata) Text(l10n.ortakBeklenmeyenHata),
            if (bos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.otoKuralYok),
              ),
            ...kartlar,
          ],
        ),
      ),
    );
  }
}

class _KuralKarti extends StatelessWidget {
  const _KuralKarti({
    required this.id,
    required this.cumle,
    required this.son,
    required this.aktif,
    required this.onAnahtar,
    this.ek,
    this.eylemler = const [],
  });

  final String id;
  final String cumle;
  final String son;
  final String? ek;
  final bool aktif;
  final ValueChanged<bool> onAnahtar;
  final List<Widget> eylemler;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tema = Theme.of(context).textTheme;
    final ikincil = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      key: Key('kural-$id'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cumle,
              key: Key('kural-cumle-$id'),
              style: tema.titleSmall?.copyWith(color: aktif ? null : ikincil),
            ),
            const SizedBox(height: 4),
            Text(
              son,
              key: Key('kural-son-$id'),
              style: tema.bodySmall?.copyWith(color: ikincil),
            ),
            if (ek != null)
              Text(
                ek!,
                key: Key('kural-bugun-$id'),
                style: tema.bodySmall?.copyWith(color: ikincil),
              ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Semantics(
                  label: l10n.otoKuralAnahtar(cumle),
                  child: Switch(
                    key: Key('kural-anahtar-$id'),
                    value: aktif,
                    onChanged: onAnahtar,
                  ),
                ),
                Text(aktif ? l10n.otoKuralAcik : l10n.otoKuralKapali),
                ...eylemler,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
