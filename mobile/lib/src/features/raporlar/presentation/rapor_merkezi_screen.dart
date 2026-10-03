import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/ui/bos_durum.dart';
import '../../../core/ui/merkez_diyalog.dart';
import '../../../routing/app_router.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../data/rapor_motoru_api.dart';
import '../domain/rapor_motoru_models.dart';
import 'gorev_gecmisi_formu.dart';
import 'rapor_formu.dart';
import 'rapor_paylas.dart';

/// (P253 Asama 2) RAPOR MERKEZI — web `/raporlar` sayfasinin karsiligi.
///
/// Iki sekme, iki ayri soru (web ile ayni ayrim):
///   * KATALOG — sunucunun tanimladigi raporlar, kategoriye gore. Rapora
///     dokununca parametre formu acilir: Goster / Excel / PDF.
///   * ISLERIM — kuyruga alinmis agir raporlar; hazir olunca paylasilir.
///
/// HAZIR BILDIRIMI: sunucu kuyruk isi bitince bildirim GONDERMIYOR (P253
/// A2 raporu). Web gibi bekleyen is varken liste 5 sn'de bir tazelenir;
/// bir is bu ekrandayken hazir olursa kullaniciya soylenir.
///
/// Eski "Aylik ozet" (devriye/gorev/aidat) yalniz yonetimde ve ust
/// cubuktan acilir: denetci o uclari goremez.
final raporKatalogProvider = FutureProvider.autoDispose<RaporKatalog>(
  (ref) => ref.watch(raporMotoruApiProvider).katalog(),
);

class RaporMerkeziScreen extends ConsumerStatefulWidget {
  const RaporMerkeziScreen({
    super.key,
    this.tazelemeAraligi = const Duration(seconds: 5),
    this.islerSekmesi = false,
  });

  /// (P253 A2) "Rapor hazir" bildiriminden gelince ISLERIM sekmesi acik.
  final bool islerSekmesi;

  /// Bekleyen is varken isler listesinin tazelenme araligi (test kisaltir).
  final Duration tazelemeAraligi;

  @override
  ConsumerState<RaporMerkeziScreen> createState() => _RaporMerkeziScreenState();
}

class _RaporMerkeziScreenState extends ConsumerState<RaporMerkeziScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _sekme =
      TabController(length: 2, vsync: this, initialIndex: widget.islerSekmesi ? 1 : 0);
  List<RaporIsi>? _isler;
  Object? _isHata;
  Timer? _zamanlayici;

  @override
  void initState() {
    super.initState();
    _isleriYukle();
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    _sekme.dispose();
    super.dispose();
  }

  Future<void> _isleriYukle() async {
    try {
      final yeni = await ref.read(raporMotoruApiProvider).isler();
      if (!mounted) return;
      final onceBekleyen = {for (final i in _isler ?? const <RaporIsi>[]) if (i.bekliyor) i.id};
      final biten = [for (final i in yeni) if (i.hazir && onceBekleyen.contains(i.id)) i];
      setState(() {
        _isler = yeni;
        _isHata = null;
      });
      // HAZIR bilgisi bekleyen "kuyruga alindi" bilgisinin ARKASINDA
      // sira beklemez (4 sn): kullanicinin bekledigi asil haber budur.
      if (biten.isNotEmpty) ScaffoldMessenger.of(context).removeCurrentSnackBar();
      for (final i in biten) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.rprIsHazirBildirim(i.dosyaAdi ?? i.kod)),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _isHata = e);
    }
    _zamanlayici?.cancel();
    if (mounted && (_isler ?? const []).any((i) => i.bekliyor)) {
      _zamanlayici = Timer(widget.tazelemeAraligi, _isleriYukle);
    }
  }

  Future<void> _raporAc(RaporKatalogOgesi rapor) async {
    final kuyruga = await merkezSayfaAc<bool>(
      context,
      builder: (_) => RaporFormu(rapor: rapor),
    );
    if (kuyruga == true && mounted) {
      _sekme.animateTo(1);
      await _isleriYukle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rol = ref.watch(currentUserRoleProvider).value;
    final yonetim = rol == UserRole.admin || rol == UserRole.yonetici;
    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.raporBaslik, context.dilKodu)),
        actions: [
          if (yonetim)
            TextButton.icon(
              key: const Key('rpr-aylik'),
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(l10n.rprAylikOzet),
              onPressed: () => context.push(AppRoutes.aylikRapor),
            ),
        ],
        bottom: TabBar(
          controller: _sekme,
          tabs: [Tab(text: l10n.rprSekmeKatalog), Tab(text: l10n.rprIslerim)],
        ),
      ),
      body: TabBarView(
        controller: _sekme,
        children: [
          _Katalog(
            onAc: _raporAc,
            // Gorev gecmisi `/task-completions`tan: denetci o ucu okuyamaz.
            onGorevGecmisi: yonetim
                ? () => merkezSayfaAc<void>(context, builder: (_) => const GorevGecmisiFormu())
                : null,
          ),
          _Isler(isler: _isler, hata: _isHata, onYenile: _isleriYukle),
        ],
      ),
    );
  }
}

class _Katalog extends ConsumerWidget {
  const _Katalog({required this.onAc, this.onGorevGecmisi});
  final void Function(RaporKatalogOgesi) onAc;

  /// (ISTEMCI /reports/tasks) Gorev gecmisi CSV — yalniz yonetimde.
  final VoidCallback? onGorevGecmisi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final katalog = ref.watch(raporKatalogProvider);
    return katalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => BosDurum(
        ikon: Icons.error_outline,
        baslik: l10n.rprKatalogHata,
        aciklama: e is ApiException && e.message.isNotEmpty ? e.message : l10n.rprKatalogBosAlt,
      ),
      data: (k) {
        if (k.items.isEmpty) {
          return BosDurum(
            ikon: Icons.description_outlined,
            baslik: l10n.rprKatalog,
            aciklama: l10n.rprKatalogBosAlt,
          );
        }
        final sira = [...k.kategoriler, ...{for (final r in k.items) r.kategori}.where((x) => !k.kategoriler.contains(x))];
        return RefreshIndicator(
          onRefresh: () => ref.refresh(raporKatalogProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final kat in sira)
                if (k.items.any((r) => r.kategori == kat)) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(kategoriBasligi(l10n, kat),
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  for (final r in k.items.where((r) => r.kategori == kat))
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        key: Key('rpr-kart-${r.kod}'),
                        leading: const Icon(Icons.description_outlined),
                        title: Text(r.baslik),
                        subtitle: Text(r.aciklama),
                        onTap: () => onAc(r),
                      ),
                    ),
                ],
              if (onGorevGecmisi != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(l10n.rprBolumDisaAktarim,
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                Card(
                  child: ListTile(
                    key: const Key('rpr-gorev-gecmisi'),
                    leading: const Icon(Icons.task_alt_outlined),
                    title: Text(l10n.rprGorevGecmisi),
                    subtitle: Text(l10n.rprGorevGecmisiAlt),
                    onTap: onGorevGecmisi,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Isler extends ConsumerWidget {
  const _Isler({required this.isler, required this.hata, required this.onYenile});
  final List<RaporIsi>? isler;
  final Object? hata;
  final Future<void> Function() onYenile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final liste = isler;
    if (liste == null && hata == null) return const Center(child: CircularProgressIndicator());
    if (liste == null || liste.isEmpty) {
      return RefreshIndicator(
        onRefresh: onYenile,
        child: ListView(children: [
          BosDurum(
            ikon: Icons.inbox_outlined,
            baslik: hata != null ? l10n.rprKatalogHata : l10n.rprIsYok,
            aciklama: l10n.rprIsYokAlt,
          ),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: onYenile,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: liste.length,
        itemBuilder: (context, i) {
          final is_ = liste[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              key: Key('rpr-is-${is_.id}'),
              title: Text(is_.dosyaAdi ?? is_.kod),
              subtitle: Text([
                '${is_.bicim.toUpperCase()} · ${isDurumu(l10n, is_.durum)}',
                tarihSaatBicimi(is_.createdAt.toLocal(), context.dilKodu),
                if (is_.hata != null) is_.hata!,
              ].join('\n')),
              isThreeLine: true,
              trailing: is_.hazir
                  ? Builder(
                      builder: (bctx) => TextButton.icon(
                        key: Key('rpr-is-indir-${is_.id}'),
                        icon: const Icon(Icons.ios_share),
                        label: Text(l10n.rprIsIndir),
                        onPressed: () => raporuPaylas(
                          bctx,
                          ref,
                          uret: () => ref.read(raporMotoruApiProvider).isIndir(is_),
                          konu: is_.dosyaAdi ?? is_.kod,
                        ),
                      ),
                    )
                  : is_.bekliyor
                      ? const SizedBox(
                          width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
            ),
          );
        },
      ),
    );
  }
}
