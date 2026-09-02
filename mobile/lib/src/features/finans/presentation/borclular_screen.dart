/// (P206 §4.4) MOBIL BORCLULAR — yaslandirma + toplu hatirlatma.
///
/// ===========================================================================
/// YASLANDIRMA KOVALARI DAR EKRANDA NASIL? — KARAR
/// ===========================================================================
/// Web'de kovalar YAN YANA dort kart (0-30 / 31-60 / 61-90 / 90+).
/// Telefonda dort karti yan yana koymak, her birini 80 px'e sikistirir:
/// baslik kirilir, tutar okunmaz. Alt alta koymak ise ekranin tamamini
/// ozet kartlara verir ve ASIL LISTE (kim, ne kadar) katlanir.
///
/// SECILEN: kovalar YATAY KAYDIRILAN bir SERIT (her biri ~140 px, tek
/// bakista ikisi gorunur), altinda SECILI KOVANIN listesi. Yonetici
/// "en eski borclular" sorusunu tek dokunusla yanitlar — sahada sorulan
/// soru budur; "toplam borc ne kadar" sorusu ise serit ozetinde durur.
///
/// TAHSILAT ORANI TEK KAYNAKTAN (P192): `/finans/tahsilat-gostergesi`.
/// Ayni sayiyi burada yeniden hesaplamak, iki ekranda iki farkli oran
/// gostermek demekti — P192'nin duzelttigi kusurun ta kendisi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/i18n/l10n.dart';
import '../data/finans_api.dart';
import '../domain/finans_models.dart';
import 'tahsilat_screen.dart' show borclularProvider;

final tahsilatGostergesiProvider =
    FutureProvider.autoDispose<TahsilatGostergesi>((ref) async {
  return ref.watch(finansApiProvider).tahsilatGostergesi();
});

class BorclularScreen extends ConsumerStatefulWidget {
  const BorclularScreen({super.key});

  @override
  ConsumerState<BorclularScreen> createState() => _BorclularScreenState();
}

class _BorclularScreenState extends ConsumerState<BorclularScreen> {
  String? _kova;
  final _secili = <String>{};
  bool _gonderiyor = false;

  Future<void> _hatirlat() async {
    final l10n = context.l10n;
    if (_secili.isEmpty) return;
    setState(() => _gonderiyor = true);
    try {
      final adet = await ref.read(finansApiProvider).hatirlat(_secili.toList());
      if (!mounted) return;
      setState(() {
        _secili.clear();
        _gonderiyor = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.finansHatirlatmaGonderildi(adet))),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _gonderiyor = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final veri = ref.watch(borclularProvider);
    final gosterge = ref.watch(tahsilatGostergesiProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.finansBorclularBaslik)),
      body: veri.when(
        data: (y) {
          final kovalar = y.kovalar;
          final secili = _kova ?? (kovalar.isNotEmpty ? kovalar.first.kova : null);
          final liste = kovalar
              .where((k) => k.kova == secili)
              .expand((k) => k.borclular)
              .toList();
          return Column(
            children: [
              // TAHSILAT ORANI — TEK KAYNAK (P192 §5.2).
              gosterge.when(
                data: (g) => ListTile(
                  key: const Key('borclular-oran'),
                  title: Text(l10n.finansTahsilatOrani),
                  subtitle: Text(
                    g.oranYuzde == null
                        ? l10n.finansOranYok
                        : l10n.finansOranDegeri(g.oranYuzde!, g.donem),
                  ),
                ),
                loading: () => const LinearProgressIndicator(),
                // GOSTERGE DUSERSE LISTE YINE CIZILIR: kart bir
                // KOLAYLIKTIR, ekranin tamamini kirmasi orantisiz.
                error: (_, _) => const SizedBox.shrink(),
              ),
              // KOVA SERIDI — yatay kaydirir.
              SizedBox(
                height: 92,
                child: ListView(
                  key: const Key('borclular-kovalar'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final k in kovalar)
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: SizedBox(
                          width: 140,
                          child: Card(
                            key: Key('borclular-kova-${k.kova}'),
                            color: k.kova == secili
                                ? Theme.of(context).colorScheme.secondaryContainer
                                : null,
                            child: InkWell(
                              onTap: () => setState(() {
                                _kova = k.kova;
                                _secili.clear();
                              }),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(k.kova,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall),
                                    Text(l10n.finansKovaDaire(k.daire)),
                                    Text(tlTutar(k.kalanKurus)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (kovalar.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.finansBorcluYok,
                    key: const Key('borclular-bos'),
                  ),
                ),
              Expanded(
                child: ListView(
                  children: [
                    for (final b in liste)
                      CheckboxListTile(
                        key: Key('borclular-satir-${b.unitId}'),
                        value: _secili.contains(b.unitId),
                        title: Text('${b.ad ?? ''} · ${b.unitNo}'),
                        subtitle: Text(
                          '${tlTutar(b.kalanKurus)} · '
                          '${l10n.finansGecikmeGun(b.enEskiGun)}',
                        ),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _secili.add(b.unitId);
                          } else {
                            _secili.remove(b.unitId);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            e is ApiException ? apiHataMetni(l10n, e) : l10n.ortakBeklenmeyenHata,
          ),
        ),
      ),
      // TOPLU HATIRLATMA: secim VARKEN gorunur. Bos secimle basilabilen
      // bir dugme, hicbir sey yapmayip kullaniciyi "gitti mi" diye
      // birakirdi.
      floatingActionButton: _secili.isEmpty
          ? null
          : FloatingActionButton.extended(
              key: const Key('borclular-hatirlat'),
              onPressed: _gonderiyor ? null : _hatirlat,
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(l10n.finansHatirlat(_secili.length)),
            ),
    );
  }
}
