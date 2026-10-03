/// (P253 Asama 1) FINANS DEFTERI — web `/finans` sayfasinin mobil karsiligi.
///
/// Web sayfasi tek soruyu yanitlar: "para nerede ve bugun ne oldu". Mobilde
/// ayni uc ucla (`/finans/ozet`, `/finans/kasa-bakiyeleri`,
/// `/finans/hareketler`) iki sekme:
///   * OZET — ozet kartlari + kasa bazinda bakiye (bekleyen cikis ayri);
///   * HAREKETLER — tahsilat, gider, gelir...; tip ve kasa suzgeci (web'le
///     ayni sunucu suzgecleri). Onay bekleyen satirda ONAYLA / REDDET.
///
/// BAKIYE SUNUCUDAN: istemci toplam almaz (iki yerde iki rakam olmasin).
///
/// §C KURALI (docs/P253-kararlar.md): onay ve red `finansOnayla`
/// diyalogundan gecer — tutar + hedef yazili, redde sebep zorunlu, ret
/// geri alinamaz diye ONCEDEN soylenir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/finans_onay.dart';
import '../../../core/ui/liste_ekrani.dart';
import '../../../routing/app_router.dart';
import '../data/finans_api.dart';
import '../domain/finans_models.dart';

final finansOzetiProvider = FutureProvider.autoDispose<FinansOzeti>(
  (ref) => ref.watch(finansApiProvider).ozet(),
);

final kasaBakiyeleriProvider = FutureProvider.autoDispose<KasaBakiyeleri>(
  (ref) => ref.watch(finansApiProvider).kasaBakiyeleri(),
);

/// Sunucu `finansal_hareket.tip` degerleri (web `TIPLER` + iptal).
const hareketTipleri = ['tahsilat', 'gider', 'gelir', 'virman', 'iade', 'acilis', 'iptal'];

String hareketTipAdi(AppLocalizations l10n, String tip) => switch (tip) {
      'tahsilat' => l10n.finTipTahsilat,
      'gider' => l10n.finTipGider,
      'gelir' => l10n.finTipGelir,
      'virman' => l10n.finTipVirman,
      'iade' => l10n.finTipIade,
      'acilis' => l10n.finTipAcilis,
      'iptal' => l10n.finTipIptal,
      _ => tip,
    };

class FinansDefteriScreen extends ConsumerStatefulWidget {
  const FinansDefteriScreen({super.key});

  @override
  ConsumerState<FinansDefteriScreen> createState() => _FinansDefteriScreenState();
}

class _FinansDefteriScreenState extends ConsumerState<FinansDefteriScreen> {
  final _liste = GlobalKey<ListeEkraniState<FinansHareketi>>();

  void _tazele() {
    ref.invalidate(finansOzetiProvider);
    ref.invalidate(kasaBakiyeleriProvider);
    _liste.currentState?.yenile();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(baslikBuyuk(l10n.butFinansalOzet, context.dilKodu)),
          actions: [
            TextButton.icon(
              key: const Key('fin-donemsel-rapor'),
              icon: const Icon(Icons.query_stats_outlined),
              label: Text(l10n.finDonemselRapor),
              onPressed: () => context.push(AppRoutes.financialSummary),
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(text: l10n.finSekmeOzet),
            Tab(text: l10n.finSekmeHareketler),
          ]),
        ),
        body: TabBarView(children: [
          _OzetSekmesi(onTazele: _tazele),
          _HareketlerSekmesi(listeAnahtari: _liste, onDegisti: _tazele),
        ]),
      ),
    );
  }
}

// ================================= OZET =================================== #

class _OzetSekmesi extends ConsumerWidget {
  const _OzetSekmesi({required this.onTazele});

  final VoidCallback onTazele;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ozet = ref.watch(finansOzetiProvider);
    final kasalar = ref.watch(kasaBakiyeleriProvider);
    return RefreshIndicator(
      onRefresh: () async => onTazele(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ozet.when(
            data: (o) => Wrap(
              key: const Key('fin-ozet'),
              spacing: 8,
              runSpacing: 8,
              children: [
                _OzetKarti(l10n.finOzetBorclandirilan, tlTutar(o.borclandirilanAyKurus)),
                _OzetKarti(l10n.finOzetTahsil, tlTutar(o.tahsilEdilenAyKurus)),
                _OzetKarti(l10n.finOzetAcikBorc, tlTutar(o.acikBorcKurus)),
                _OzetKarti(l10n.finOzetKasa, tlTutar(o.kasaToplamKurus)),
                _OzetKarti(l10n.finOzetPersonel, tlTutar(o.personelGideriAyKurus)),
                _OzetKarti(l10n.finOzetIcra, '${o.icraAcikDosya}'),
                if (o.onayBekleyenAdet > 0)
                  _OzetKarti(l10n.finOzetOnayBekleyen, '${o.onayBekleyenAdet}',
                      vurgu: true),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(_hata(l10n, e)),
          ),
          const SizedBox(height: 20),
          Text(l10n.finKasalar, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          kasalar.when(
            data: (k) => k.kasalar.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l10n.finKasaYok),
                  )
                : Column(
                    key: const Key('fin-kasalar'),
                    children: [
                      for (final b in k.kasalar)
                        ListTile(
                          key: Key('fin-kasa-${b.kasaId}'),
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(b.bankaMi
                              ? Icons.account_balance_outlined
                              : Icons.payments_outlined),
                          title: Text(b.ad),
                          subtitle: b.bekleyenCikisKurus > 0
                              ? Text(l10n.finKasaBekleyen(tlTutar(b.bekleyenCikisKurus)))
                              : (b.kod.isEmpty ? null : Text(b.kod)),
                          trailing: Text(
                            tlTutar(b.bakiyeKurus),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.finGenelToplam),
                        trailing: Text(
                          tlTutar(k.genelToplamKurus),
                          key: const Key('fin-genel-toplam'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(_hata(l10n, e)),
          ),
        ],
      ),
    );
  }
}

String _hata(AppLocalizations l10n, Object e) =>
    e is ApiException ? apiHataMetni(l10n, e) : l10n.ortakBeklenmeyenHata;

class _OzetKarti extends StatelessWidget {
  const _OzetKarti(this.etiket, this.deger, {this.vurgu = false});

  final String etiket;
  final String deger;
  final bool vurgu;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final genislik = (MediaQuery.sizeOf(context).width - 40) / 2;
    return SizedBox(
      width: genislik,
      child: Card(
        margin: EdgeInsets.zero,
        color: vurgu ? tema.colorScheme.tertiaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiket, style: tema.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(deger,
                  style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================== HAREKETLER =============================== #

class _HareketlerSekmesi extends ConsumerWidget {
  const _HareketlerSekmesi({required this.listeAnahtari, required this.onDegisti});

  final GlobalKey<ListeEkraniState<FinansHareketi>> listeAnahtari;
  final VoidCallback onDegisti;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(finansApiProvider);
    // Kasa suzgeci sunucudaki kasalardan (bakiye listesi zaten yuklu).
    final kasalar = ref.watch(kasaBakiyeleriProvider).value?.kasalar ?? const [];
    return ListeEkrani<FinansHareketi>(
      key: listeAnahtari,
      kimlik: (h) => h.id,
      suzgecler: [
        SuzgecTanimi(
          ad: 'tip',
          etiket: (l) => l.finSuzgecTip,
          secenekler: [
            for (final t in hareketTipleri)
              SuzgecSecenegi(t, (l) => hareketTipAdi(l, t)),
          ],
        ),
        if (kasalar.length > 1)
          SuzgecTanimi(
            ad: 'kasa_id',
            etiket: (l) => l.finansSutunKasa,
            secenekler: [
              for (final k in kasalar) SuzgecSecenegi(k.kasaId, (_) => k.ad),
            ],
          ),
      ],
      bosMetin: (l) => l.finHareketYok,
      yukle: (s) async {
        final r = await api.hareketler(
          tip: s.suzgec['tip'],
          kasaId: s.suzgec['kasa_id'],
          limit: s.limit,
          offset: s.offset,
        );
        return ListeSayfasi(r.items, toplam: r.toplam);
      },
      kart: (context, h, _) => HareketKarti(hareket: h),
      onDokun: (h) async {
        final degisti = await hareketAyrintisi(context, ref, h);
        if (degisti == true) onDegisti();
      },
    );
  }
}

/// Liste karti: tip + tarih, hedef, tutar (yon isaretli), durum.
class HareketKarti extends StatelessWidget {
  const HareketKarti({super.key, required this.hareket});

  final FinansHareketi hareket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final h = hareket;
    final tema = Theme.of(context);
    final renk = h.giris ? Colors.green.shade700 : tema.colorScheme.error;
    return Card(
      key: Key('fin-hareket-${h.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Text('${hareketTipAdi(l10n, h.tip)} · ${tarihBicimi(h.tarih, context.dilKodu)}'),
        subtitle: Text(
          [
            if (h.hedef.isNotEmpty) h.hedef,
            if (h.kasaAd != null) h.kasaAd!,
            if (h.onayBekliyor) l10n.finDurumOnayBekliyor,
            if (h.durum == 'iptal') l10n.finDurumReddedildi,
            if (h.iptalEdildi) l10n.finDurumIptalEdildi,
          ].join('\n'),
        ),
        isThreeLine: h.hedef.isNotEmpty && (h.kasaAd != null || h.onayBekliyor),
        trailing: Text(
          '${h.giris ? '+' : '−'}${tlTutar(h.tutarKurus)}',
          style: TextStyle(color: renk, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Hareket ayrintisi; onay bekleyen satirda ONAYLA / REDDET (§C).
/// Donus: bir islem yapildiysa `true`.
Future<bool?> hareketAyrintisi(BuildContext context, WidgetRef ref, FinansHareketi h) {
  return showDialog<bool>(
    context: context,
    builder: (dctx) {
      final l10n = dctx.l10n;
      final satirlar = <(String, String)>[
        (l10n.finSuzgecTip, hareketTipAdi(l10n, h.tip)),
        (l10n.finTarih, tarihBicimi(h.tarih, dctx.dilKodu)),
        (l10n.finansAlanTutar, tlTutar(h.tutarKurus)),
        if (h.hedef.isNotEmpty) (l10n.finHedef, h.hedef),
        if (h.kasaAd != null) (l10n.finansSutunKasa, h.kasaAd!),
        if ((h.aciklama ?? '').isNotEmpty) (l10n.finansAlanAciklama, h.aciklama!),
      ];
      return AlertDialog(
        key: const Key('fin-hareket-ayrinti'),
        title: Text(hareketTipAdi(l10n, h.tip)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (e, d) in satirlar)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('$e: $d'),
                ),
              if (h.onayBekliyor)
                Text(l10n.finDurumOnayBekliyor,
                    style: TextStyle(color: Theme.of(dctx).colorScheme.tertiary)),
            ],
          ),
        ),
        actions: [
          if (h.onayBekliyor) ...[
            TextButton(
              key: const Key('fin-reddet'),
              onPressed: () async {
                if (await hareketReddet(dctx, ref, h) && dctx.mounted) {
                  Navigator.of(dctx).pop(true);
                }
              },
              child: Text(l10n.finReddet),
            ),
            FilledButton(
              key: const Key('fin-onayla'),
              onPressed: () async {
                if (await hareketOnayla(dctx, ref, h) && dctx.mounted) {
                  Navigator.of(dctx).pop(true);
                }
              },
              child: Text(l10n.finOnayla),
            ),
          ] else
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: Text(l10n.ortakKapat),
            ),
        ],
      );
    },
  );
}

/// §C: tutar + hedef yazili onay; onay ancak ters kayitla duzeltilir.
Future<bool> hareketOnayla(BuildContext context, WidgetRef ref, FinansHareketi h) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final sonuc = await finansOnayla(
    context,
    baslik: l10n.finOnayBaslik,
    hedef: h.hedef,
    tutar: tlTutar(h.tutarKurus),
    sonuc: l10n.finOnaySonuc,
    onayMetni: l10n.finOnayla,
  );
  if (sonuc == null) return false;
  try {
    await ref.read(finansApiProvider).hareketOnayla(h.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.finOnaylandi)));
    return true;
  } on ApiException catch (e) {
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    }
    return false;
  }
}

/// §C: sebep ZORUNLU, ret geri alinamaz diye ONCEDEN soylenir.
Future<bool> hareketReddet(BuildContext context, WidgetRef ref, FinansHareketi h) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final sebep = await finansOnayla(
    context,
    baslik: l10n.finRedBaslik,
    hedef: h.hedef,
    tutar: tlTutar(h.tutarKurus),
    sonuc: l10n.finRedSonuc,
    onayMetni: l10n.finReddet,
    sebepZorunlu: true,
    tehlikeli: true,
  );
  if (sebep == null) return false;
  try {
    await ref.read(finansApiProvider).hareketReddet(h.id, sebep);
    messenger.showSnackBar(SnackBar(content: Text(l10n.finReddedildi)));
    return true;
  } on ApiException catch (e) {
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    }
    return false;
  }
}
