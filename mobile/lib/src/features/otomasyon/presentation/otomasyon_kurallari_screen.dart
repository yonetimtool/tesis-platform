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
import '../../../core/girdi_siniri.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/para.dart';
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
    ref.invalidate(maasKuraliProvider);
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

  Future<void> _maaslariCalistir(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final (yazilan, toplam) =
          await ref.read(otomasyonApiProvider).maaslariCalistir();
      messenger.showSnackBar(SnackBar(
        content: Text(yazilan > 0
            ? l10n.otoKuralMaasCalisti('$yazilan', tlIsaretli(toplam, dil))
            : l10n.otoKuralMaasYazilacakYok),
      ));
      _tazele(ref);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    }
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
    final maas = ref.watch(maasKuraliProvider).value;

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
    // (P252 §2) Maas otomasyonu — yalniz yonetime (403 -> null -> cizilmez).
    if (maas != null) {
      kartlar.add(
        _KuralKarti(
          id: 'maas',
          cumle: maasCumlesi(l10n, dil, maas),
          son: sonCalismaCumlesi(l10n, dil, sonlar['maas']),
          aktif: maas.aktif,
          onAnahtar: (v) =>
              _yap(context, ref, (a) => a.maasAyariYaz({'aktif': v})),
          eylemler: [
            TextButton(
              key: const Key('maas-calistir'),
              onPressed: !maas.aktif || maas.gruplar.isEmpty
                  ? null
                  : () => _maaslariCalistir(context, ref),
              child: Text(l10n.otoKuralMaasCalistir),
            ),
          ],
          alt: SwitchListTile(
            key: const Key('maas-otomatik-onay'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.otoKuralMaasOtomatik),
            subtitle: Text(l10n.otoKuralMaasOtomatikIpucu),
            value: maas.otomatikOnay,
            onChanged: (v) =>
                _yap(context, ref, (a) => a.maasAyariYaz({'otomatik_onay': v})),
          ),
        ),
      );
      if (maas.onayBekleyenler.isNotEmpty) {
        kartlar.add(_MaasOnayKarti(maas: maas, onDegisti: () => _tazele(ref)));
      }
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
    this.alt,
  });

  final String id;
  final String cumle;
  final String son;
  final String? ek;
  final bool aktif;
  final ValueChanged<bool> onAnahtar;
  final List<Widget> eylemler;

  /// (P252) Kurala ozgu ek ayar (maas: otomatik onay).
  final Widget? alt;

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
            ?alt,
          ],
        ),
      ),
    );
  }
}

/// (P252 §2) Onay bekleyen maaslar — satir basina tutar duzeltilerek onay
/// ya da tek tikla toplu onay (web `MaasOnayBekleyenler` ikizi).
class _MaasOnayKarti extends ConsumerStatefulWidget {
  const _MaasOnayKarti({required this.maas, required this.onDegisti});

  final MaasKurali maas;
  final VoidCallback onDegisti;

  @override
  ConsumerState<_MaasOnayKarti> createState() => _MaasOnayKartiState();
}

class _MaasOnayKartiState extends ConsumerState<_MaasOnayKarti> {
  final _tutarlar = <String, TextEditingController>{};
  bool _mesgul = false;

  TextEditingController _ktrl(String id, int kurus) =>
      _tutarlar.putIfAbsent(id, () => TextEditingController(text: tlTutar(kurus)));

  @override
  void dispose() {
    for (final c in _tutarlar.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _calis(Future<int> Function(OtomasyonApi api) is_) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _mesgul = true);
    try {
      final adet = await is_(ref.read(otomasyonApiProvider));
      messenger.showSnackBar(SnackBar(content: Text(l10n.otoMaasOnaylandi('$adet'))));
      widget.onDegisti();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _tekOnay(String id, int varsayilan) async {
    final l10n = context.l10n;
    final kurus = tlMetniniKurusaCevir(_ktrl(id, varsayilan).text);
    if (kurus == null || kurus <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.calismaUcretGecersiz)),
      );
      return;
    }
    await _calis((a) async {
      await a.hareketOnayla(id, tutarKurus: kurus == varsayilan ? null : kurus);
      return 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final tema = Theme.of(context).textTheme;
    final satirlar = widget.maas.onayBekleyenler;
    return Card(
      key: const Key('maas-onay-bekleyenler'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.otoMaasOnayBaslik, style: tema.titleSmall),
            Text(l10n.otoMaasOnayAlt, style: tema.bodySmall),
            for (final b in satirlar)
              Padding(
                key: Key('maas-bekleyen-${b.id}'),
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${b.aciklama} · ${tarihBicimi(b.tarih, dil)}',
                        style: tema.bodySmall,
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        key: Key('maas-tutar-${b.id}'),
                        controller: _ktrl(b.id, b.tutarKurus),
                        enabled: !_mesgul,
                        inputFormatters: GirdiSiniri.sinir(GirdiSiniri.tutar),
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(isDense: true),
                      ),
                    ),
                    TextButton(
                      key: Key('maas-onayla-${b.id}'),
                      onPressed: _mesgul ? null : () => _tekOnay(b.id, b.tutarKurus),
                      child: Text(l10n.otoMaasOnayla),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('maas-toplu-onay'),
              onPressed: _mesgul
                  ? null
                  : () => _calis(
                      (a) => a.maaslariOnayla([for (final b in satirlar) b.id])),
              child: Text(l10n.otoMaasTumunuOnayla('${satirlar.length}')),
            ),
          ],
        ),
      ),
    );
  }
}
