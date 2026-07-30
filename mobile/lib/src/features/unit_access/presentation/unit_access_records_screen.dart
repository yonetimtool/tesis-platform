import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../kargo/data/kargo_api.dart';
import '../../kargo/domain/kargo_models.dart';
import '../../visitors/data/visitor_api.dart';
import '../../visitors/domain/visitor_models.dart';
import '../../../core/i18n/l10n.dart';
import '../../kargo/presentation/kargo_durum_adi.dart';
import '../../../core/error/akis_hatasi.dart';

/// Onaylanan tek-seferlik izinle bir dairenin ziyaretci/kargo kayitlarinin
/// SALT-OKUNUR gorunumu (admin/yonetici). Izin ILK okumada tuketilir; tekrar
/// (pull-to-refresh) 403 doner -> "izin kullanildi" durumu gosterilir.
class UnitAccessRecordsScreen extends ConsumerStatefulWidget {
  const UnitAccessRecordsScreen({
    super.key,
    required this.unitId,
    required this.kind, // 'visitor' | 'kargo'
    this.unitNo,
  });

  final String unitId;
  final String kind;
  final String? unitNo;

  @override
  ConsumerState<UnitAccessRecordsScreen> createState() =>
      _UnitAccessRecordsScreenState();
}

class _UnitAccessRecordsScreenState
    extends ConsumerState<UnitAccessRecordsScreen> {
  bool _loading = true;
  bool _forbidden = false;
  String? _error;
  List<Visitor> _visitors = const [];
  List<Kargo> _kargolar = const [];

  bool get _isKargo => widget.kind == 'kargo';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _forbidden = false;
      _error = null;
    });
    try {
      if (_isKargo) {
        final list =
            await ref.read(kargoApiProvider).fetchAll(unitId: widget.unitId);
        if (!mounted) return;
        setState(() => _kargolar = list);
      } else {
        final list =
            await ref.read(visitorApiProvider).fetchAll(unitId: widget.unitId);
        if (!mounted) return;
        setState(() => _visitors = list);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.statusCode == 403) {
          _forbidden = true;
        } else {
          _error = apiHataMetni(context.l10n, e);
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baslik = _isKargo ? context.l10n.izinKargolar : context.l10n.modulZiyaretciler;
    final daire = widget.unitNo == null || widget.unitNo!.isEmpty
        ? ''
        : context.l10n.izinDaireEki(widget.unitNo!);
    return Scaffold(
      // DILE DUYARLI buyuk harf: `trUpper` TURKCE kuralini (i -> İ) her dile
      // uyguluyordu ve Fransizca "Colis" ekranda "COLİS" cikiyordu (tur 37).
      // `baslikBuyuk` aktif dile gore davranir (Arapca'da hic buyutmez).
      appBar: AppBar(
          title: Text(baslikBuyuk('$baslik$daire', context.dilKodu))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Builder(
                builder: (context) {
                  // TUR 61 — TEMBEL LISTE.
                  //
                  // Onceki surum `ListView(children: [..._kargolar.map(...)])`
                  // kullaniyordu. Iki API de (`visitor_api`, `kargo_api`)
                  // 200'luk sayfalarla TUM veriyi cekiyor, ust sinir YOK.
                  //
                  // OLCULEN FARK (test/uzun_liste_tembellik_test.dart):
                  // `children:` kalibi ELEMAN duzeyinde zaten tembeldi —
                  // yerlesim/boyama yalniz gorunen satirlar icin olurdu. Asil
                  // maliyet, ekran her yeniden insa edildiginde 500 satir
                  // WIDGET NESNESININ kurulmasiydi (liste literali `build`
                  // icinde materyallesir). `builder` yalniz gorunenleri kurar:
                  // 500 -> ~10. Yani kazanc yerlesimde degil, her karedeki
                  // O(N) nesne insasinda.
                  //
                  // Basliklar ve bos-hal karti indeks eslemesiyle korunur.
                  final kayitSayisi =
                      _isKargo ? _kargolar.length : _visitors.length;
                  final basliklar = <Widget>[
                    if (_forbidden)
                      Card(
                        color: Colors.orange.withValues(alpha: 0.10),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            context.l10n.izinSuresiDoldu,
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ),
                      )
                    else if (_error != null)
                      Card(
                        color: Colors.red.withValues(alpha: 0.08),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          context.l10n.izinTekSeferlikUyari,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                  ];
                  // Kayit gosterilmeyen hallerde (403/hata) satir da yoktur.
                  final satirVar = !_forbidden && _error == null;
                  final kuyruk = <Widget>[
                    if (satirVar && kayitSayisi == 0)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            context.l10n.izinKayitYok,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ];
                  final toplam = basliklar.length +
                      (satirVar ? kayitSayisi : 0) +
                      kuyruk.length;
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: toplam,
                    itemBuilder: (context, i) {
                      if (i < basliklar.length) return basliklar[i];
                      final j = i - basliklar.length;
                      if (satirVar && j < kayitSayisi) {
                        return _isKargo
                            ? _KargoTile(kargo: _kargolar[j])
                            : _VisitorTile(visitor: _visitors[j]);
                      }
                      return kuyruk[j - (satirVar ? kayitSayisi : 0)];
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _VisitorTile extends StatelessWidget {
  const _VisitorTile({required this.visitor});

  final Visitor visitor;

  @override
  Widget build(BuildContext context) {
    final v = visitor;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.emoji_people_outlined),
        title: Text(v.ziyaretciAd),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (v.targetResidentAd != null) Text(context.l10n.izinHedef(v.targetResidentAd!)),
            if (v.kaydedenAd != null) Text(context.l10n.izinKaydeden(v.kaydedenAd!)),
            if (v.notlar != null && v.notlar!.isNotEmpty) Text(v.notlar!),
          ],
        ),
      ),
    );
  }
}

class _KargoTile extends StatelessWidget {
  const _KargoTile({required this.kargo});

  final Kargo kargo;

  @override
  Widget build(BuildContext context) {
    final k = kargo;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.local_shipping_outlined),
        title: Text(k.firma),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.izinDurumEtiket(kargoDurumAdi(context.l10n, k.durum))),
            if (k.notlar != null && k.notlar!.isNotEmpty) Text(k.notlar!),
          ],
        ),
      ),
    );
  }
}
