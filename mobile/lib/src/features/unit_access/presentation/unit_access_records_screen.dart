import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/text/tr_upper.dart';
import '../../../core/error/api_exception.dart';
import '../../kargo/data/kargo_api.dart';
import '../../kargo/domain/kargo_models.dart';
import '../../visitors/data/visitor_api.dart';
import '../../visitors/domain/visitor_models.dart';

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
          _error = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baslik = _isKargo ? 'Kargolar' : 'Ziyaretçiler';
    final daire = widget.unitNo == null || widget.unitNo!.isEmpty
        ? ''
        : ' — ${widget.unitNo}';
    return Scaffold(
      appBar: AppBar(title: Text(trUpper('$baslik$daire'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_forbidden)
                    Card(
                      color: Colors.orange.withValues(alpha: 0.10),
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'İzin kullanıldı veya süresi doldu (tek seferlik). '
                          'Tekrar görüntülemek için yeni bir izin isteği açın.',
                          style: TextStyle(color: Colors.orange),
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
                  else ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Tek seferlik izinle görüntüleniyor — yenilemede erişim '
                        'kapanır.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    if (_isKargo)
                      ..._kargolar.map((k) => _KargoTile(kargo: k))
                    else
                      ..._visitors.map((v) => _VisitorTile(visitor: v)),
                    if (_isKargo && _kargolar.isEmpty ||
                        !_isKargo && _visitors.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Bu dairede kayıt yok.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ],
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
        leading: const Icon(Icons.emoji_people_outlined),
        title: Text(v.ziyaretciAd),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (v.targetResidentAd != null) Text('Hedef: ${v.targetResidentAd}'),
            if (v.kaydedenAd != null) Text('Kaydeden: ${v.kaydedenAd}'),
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
        leading: const Icon(Icons.local_shipping_outlined),
        title: Text(k.firma),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Durum: ${k.durum.label}'),
            if (k.notlar != null && k.notlar!.isNotEmpty) Text(k.notlar!),
          ],
        ),
      ),
    );
  }
}
