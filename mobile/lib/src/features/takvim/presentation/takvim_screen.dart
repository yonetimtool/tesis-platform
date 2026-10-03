import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/bos_durum.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../data/takvim_api.dart';
import '../domain/takvim_models.dart';
import 'hatirlatma_formu.dart';


/// Ayin baslangici (yerel) — pencere `[ay, sonraki ay)`, sunucu siniri 120 gun.
DateTime ayBasi(DateTime t) => DateTime(t.year, t.month);

final takvimAyiProvider =
    FutureProvider.autoDispose.family<List<TakvimOgesi>, DateTime>((ref, ay) {
  return ref.watch(takvimApiProvider).takvim(ay, DateTime(ay.year, ay.month + 1));
});

final hatirlatmalarimProvider = FutureProvider.autoDispose<List<Hatirlatma>>((ref) {
  return ref.watch(takvimApiProvider).hatirlatmalar();
});

/// (P253 A1) TAKVIM — web Ozet'teki takvim kartinin mobil ikizi.
///
/// Iki sekme: "Takvim" (alti kaynagin ay gorunumu, gune gore gruplu
/// gundem) ve "Hatirlatmalarim" (kendi notlari; duzenle/sil). Tekrar eden
/// bir hatirlatma takvimde her tekrarinda gorunur ama TEK kayittir —
/// duzenleme kaydin kendisine gider.
class TakvimScreen extends ConsumerStatefulWidget {
  const TakvimScreen({super.key});

  @override
  ConsumerState<TakvimScreen> createState() => _TakvimScreenState();
}

class _TakvimScreenState extends ConsumerState<TakvimScreen> {
  DateTime _ay = ayBasi(DateTime.now());

  void _tazele() {
    ref.invalidate(takvimAyiProvider);
    ref.invalidate(hatirlatmalarimProvider);
  }

  Future<void> _form([Hatirlatma? h]) async {
    final degisti = await merkezSayfaAc<bool>(
      context,
      builder: (_) => HatirlatmaFormu(mevcut: h),
    );
    if (degisti == true) _tazele();
  }

  /// Takvimdeki hatirlatma satirindan kaydin KENDISINE gider.
  Future<void> _ogeDokun(TakvimOgesi o) async {
    if (!o.hatirlatma) return;
    final liste = await ref.read(hatirlatmalarimProvider.future);
    final h = liste.where((x) => x.id == o.id).firstOrNull;
    if (h != null && mounted) await _form(h);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(baslikBuyuk(l10n.hatTakvimBaslik, context.dilKodu)),
          actions: [
            IconButton(
              tooltip: l10n.ortakYenile,
              icon: const Icon(Icons.refresh),
              onPressed: _tazele,
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(text: l10n.hatSekmeTakvim),
            Tab(text: l10n.hatSekmeHatirlatmalarim),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('hat-ekle'),
          onPressed: () => _form(),
          icon: const Icon(Icons.add_alert_outlined),
          label: Text(l10n.hatEkle),
        ),
        body: TabBarView(children: [
          _AyGorunumu(
            ay: _ay,
            onAy: (a) => setState(() => _ay = a),
            onDokun: _ogeDokun,
          ),
          _Hatirlatmalarim(onDokun: _form),
        ]),
      ),
    );
  }
}

String _hata(AppLocalizations l10n, Object e) =>
    e is ApiException ? apiHataMetni(l10n, e) : akisHataMetni(l10n, AkisHatasi.beklenmeyen);

IconData _ikon(String tip) => switch (tip) {
      'etkinlik' => Icons.celebration_outlined,
      'devriye' => Icons.route_outlined,
      'aidat' => Icons.account_balance_wallet_outlined,
      'gorev' => Icons.task_alt,
      'rezervasyon' => Icons.event_available_outlined,
      _ => Icons.notifications_active_outlined,
    };

class _AyGorunumu extends ConsumerWidget {
  const _AyGorunumu({required this.ay, required this.onAy, required this.onDokun});

  final DateTime ay;
  final ValueChanged<DateTime> onAy;
  final ValueChanged<TakvimOgesi> onDokun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final durum = ref.watch(takvimAyiProvider(ay));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Row(children: [
          IconButton(
            key: const Key('hat-onceki-ay'),
            tooltip: l10n.hatOncekiAy,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onAy(DateTime(ay.year, ay.month - 1)),
          ),
          Expanded(
            child: Text(
              '${ayAdi(ay.month, dil)} ${ay.year}',
              key: const Key('hat-ay'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          IconButton(
            key: const Key('hat-sonraki-ay'),
            tooltip: l10n.hatSonrakiAy,
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onAy(DateTime(ay.year, ay.month + 1)),
          ),
        ]),
      ),
      Expanded(
        child: durum.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(_hata(l10n, e), textAlign: TextAlign.center)),
          data: (ogeler) {
            if (ogeler.isEmpty) {
              return BosDurum(
                ikon: Icons.event_available_outlined,
                baslik: l10n.hatAyBos,
                aciklama: l10n.hatBosRehber,
              );
            }
            // Gune gore grupla (yerel gun).
            final gunler = <DateTime, List<TakvimOgesi>>{};
            for (final o in ogeler) {
              final g = DateTime(o.baslangic.year, o.baslangic.month, o.baslangic.day);
              (gunler[g] ??= []).add(o);
            }
            final sirali = gunler.keys.toList()..sort();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final g in sirali) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text('${gunAdi(g, dil)} · ${uzunTarihBicimi(g, dil)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  for (final o in gunler[g]!)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: Icon(_ikon(o.tip)),
                        title: Text(o.baslik),
                        subtitle: Text([
                          takvimTipAdi(l10n, o.tip),
                          saatBicimi(o.baslangic, dil),
                        ].join(' · ')),
                        onTap: o.hatirlatma ? () => onDokun(o) : null,
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    ]);
  }
}

String takvimTipAdi(AppLocalizations l10n, String tip) => switch (tip) {
      'etkinlik' => l10n.hatTipEtkinlik,
      'devriye' => l10n.hatTipDevriye,
      'aidat' => l10n.hatTipAidat,
      'gorev' => l10n.hatTipGorev,
      'rezervasyon' => l10n.hatTipRezervasyon,
      _ => l10n.hatTipHatirlatma,
    };

class _Hatirlatmalarim extends ConsumerWidget {
  const _Hatirlatmalarim({required this.onDokun});

  final ValueChanged<Hatirlatma> onDokun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final durum = ref.watch(hatirlatmalarimProvider);
    return durum.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(_hata(l10n, e), textAlign: TextAlign.center)),
      data: (liste) => liste.isEmpty
          ? BosDurum(
              ikon: Icons.notes_outlined,
              baslik: l10n.hatBos,
              aciklama: l10n.hatBosRehber,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final h in liste)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      key: Key('hat-${h.id}'),
                      leading: const Icon(Icons.notifications_active_outlined),
                      title: Text(h.baslik),
                      subtitle: Text([
                        tarihSaatBicimi(h.baslangic, dil),
                        if (h.tekrar != 'yok') hatTekrarAdi(l10n, h.tekrar),
                      ].join(' · ')),
                      onTap: () => onDokun(h),
                    ),
                  ),
              ],
            ),
    );
  }
}
