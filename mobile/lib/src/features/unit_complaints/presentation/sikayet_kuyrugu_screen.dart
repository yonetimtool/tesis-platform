import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/akis_hatasi.dart';
import '../../../core/i18n/l10n.dart';
import '../../../core/theme/home_tokens.dart';
import '../domain/unit_complaint_models.dart';
import 'kategori_adi.dart';
import 'sikayet_kuyrugu_controller.dart';

/// "Şikayet Kuyruğu" (P24) — YONETIM triyaj gorunumu.
///
/// NEDEN AYRI SEKME: tek liste ile yonetici, hangi sikayeti daha once
/// gordugunu HATIRLAMAK zorundaydi; yeni gelen bir sikayet, aylar once
/// kapatilmis kayitlarin arasinda kayboluyordu. "Yeni" sekmesi bir IS
/// KUYRUGUDUR: satir isaretlendiginde kuyruktan duser, "Tümü"nde kalir.
///
/// OKUMA DURUMU KISI BASINADIR: bir yoneticinin okumasi digerinin kuyrugunu
/// bosaltmaz (sunucu `okunmamis` suzgecini istegi yapan kullaniciya gore
/// uygular).
class SikayetKuyruguScreen extends ConsumerWidget {
  const SikayetKuyruguScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(sikayetKuyruguControllerProvider);
    final controller = ref.read(sikayetKuyruguControllerProvider.notifier);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title:
              Text(baslikBuyuk(l10n.sikayetKuyruguBaslik, context.dilKodu)),
          actions: [
            IconButton(
              tooltip: l10n.ortakYenile,
              icon: const Icon(Icons.refresh),
              onPressed: state.loading ? null : controller.refresh,
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                child: _YeniSekmeBasligi(
                  etiket: l10n.sikayetSekmeYeni,
                  sayi: state.okunmamisSayisi,
                ),
              ),
              Tab(text: l10n.sikayetSekmeTumu),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _Liste(
              items: state.yeni,
              state: state,
              bosMetin: l10n.sikayetOkunmamisYok,
              okunduGoster: true,
            ),
            _Liste(
              items: state.tumu,
              state: state,
              bosMetin: l10n.sikayetYokYonetim,
              okunduGoster: false,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Yeni" sekmesinin basligi + okunmamis ROZETI.
///
/// Rozet sayi SIFIRKEN CIZILMEZ: bos bir rozet "ilgilenilecek bir sey var"
/// sinyalini yanlis verirdi.
class _YeniSekmeBasligi extends StatelessWidget {
  const _YeniSekmeBasligi({required this.etiket, required this.sayi});

  final String etiket;
  final int sayi;

  @override
  Widget build(BuildContext context) {
    if (sayi <= 0) return Text(etiket);
    final renk = Theme.of(context).colorScheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(etiket, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 6),
        Semantics(
          // Ekran okuyucu SAYIYI degil ANLAMI duyurmali.
          label: context.l10n.sikayetOkunmamisRozet(sayi),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              // 99'dan sonrasi sekmeyi tasirdi (dar ekran / buyuk yazi).
              sayi > 99 ? '99+' : '$sayi',
              style: TextStyle(
                color: okunurVurgu(context, renk),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Liste extends ConsumerWidget {
  const _Liste({
    required this.items,
    required this.state,
    required this.bosMetin,
    required this.okunduGoster,
  });

  final List<UnitComplaint> items;
  final SikayetKuyruguState state;
  final String bosMetin;

  /// "Yeni" sekmesinde her satirda "Okundu işaretle" eylemi bulunur; "Tümü"
  /// sekmesinde eylem YOK (orada zaten okunmus/okunmamis karisik durur).
  final bool okunduGoster;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(sikayetKuyruguControllerProvider.notifier);
    if (state.loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final hata = akisHatasiCoz(l10n, state.hataKimligi, state.errorMessage);
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: (hata != null && items.isEmpty) || items.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Text(hata ?? bosMetin, textAlign: TextAlign.center),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length,
              itemBuilder: (context, i) => _KuyrukKarti(
                complaint: items[i],
                okunduGoster: okunduGoster,
              ),
            ),
    );
  }
}

class _KuyrukKarti extends ConsumerWidget {
  const _KuyrukKarti({required this.complaint, required this.okunduGoster});

  final UnitComplaint complaint;
  final bool okunduGoster;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = complaint;
    final okunmamis = c.okunmamisMi;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          c.acik ? Icons.hourglass_bottom_outlined : Icons.check_circle_outline,
          color: c.acik ? Colors.orange : Colors.green,
        ),
        title: Text(
          l10n.sikayetSatirBaslik(
            c.unitNo ?? '-',
            unitComplaintKategoriAdi(l10n, c.kategori),
          ),
          // Okunmamis satir KALIN: renk tek basina ayirt edici degildir
          // (renk korlugu + koyu tema).
          style: okunmamis
              ? const TextStyle(fontWeight: FontWeight.w700)
              : null,
        ),
        subtitle: Text(
          [
            tarihSaatBicimi(c.createdAt, context.dilKodu),
            if (c.notlar != null && c.notlar!.isNotEmpty) c.notlar!,
          ].join('\n'),
        ),
        isThreeLine: c.notlar != null && c.notlar!.isNotEmpty,
        trailing: okunduGoster
            ? TextButton(
                // 48 dp: dokunma hedefi kucultulmemeli (bes eksenli surus).
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () => ref
                    .read(sikayetKuyruguControllerProvider.notifier)
                    .okunduIsaretle(c.id),
                child: Text(l10n.sikayetOkunduIsaretle),
              )
            : null,
      ),
    );
  }
}
