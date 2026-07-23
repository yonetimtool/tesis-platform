import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/text/tr_upper.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../../budget/domain/budget_models.dart' show formatKurusAsTl;
import '../data/transparency_api.dart';
import '../domain/transparency_models.dart';

const _ayAdlari = [
  '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

String _ayBaslik(String ay) {
  final p = ay.split('-');
  if (p.length != 2) return ay;
  final m = int.tryParse(p[1]) ?? 0;
  return (m >= 1 && m <= 12) ? '${_ayAdlari[m]} ${p[0]}' : ay;
}

String _tl(int kurus) => '${formatKurusAsTl(kurus)} TL';

/// Şeffaflık Panosu — aylık ANONİM finansal özet. Sakin: yalnız yayınlanmış
/// aylar. Yönetici/admin: her ay + yayınla/geri-al anahtarı (yayınlanmamış =
/// önizleme). Ad/daire/bireysel tutar İÇERMEZ (backend agregat döner).
class TransparencyScreen extends ConsumerStatefulWidget {
  const TransparencyScreen({super.key});

  @override
  ConsumerState<TransparencyScreen> createState() => _TransparencyScreenState();
}

class _TransparencyScreenState extends ConsumerState<TransparencyScreen> {
  List<TransparencyAyOzet> _months = const [];
  String? _ay;
  TransparencyBoard? _board;
  bool _loading = true;
  bool _busy = false; // yayın anahtarı işlemde
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMonths();
  }

  Future<void> _loadMonths() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final m = await ref.read(transparencyApiProvider).fetchMonths();
      _months = m;
      if (m.isNotEmpty) {
        _ay = m.first.ay;
        await _loadBoard(_ay!);
      } else {
        _board = null;
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Yüklenemedi. Lütfen tekrar deneyin.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBoard(String ay) async {
    try {
      _board = await ref.read(transparencyApiProvider).fetchBoard(ay);
    } on ApiException catch (e) {
      _error = e.message;
      _board = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> _selectAy(String ay) async {
    setState(() => _ay = ay);
    await _loadBoard(ay);
  }

  Future<void> _togglePublish(bool yayin) async {
    final ay = _ay;
    if (ay == null) return;
    setState(() => _busy = true);
    try {
      _board = await ref.read(transparencyApiProvider).setPublish(ay, yayin);
      _months = [
        for (final m in _months)
          if (m.ay == ay)
            TransparencyAyOzet(ay: m.ay, yayinlandi: yayin, netKurus: m.netKurus)
          else
            m,
      ];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(yayin ? 'Ay yayınlandı.' : 'Yayın geri alındı.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    final canPublish = role.canPublishTransparency;

    return Scaffold(
      appBar: AppBar(
        title: Text(trUpper('Şeffaflık')),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadMonths,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMonths,
        child: _body(context, canPublish),
      ),
    );
  }

  Widget _body(BuildContext context, bool canPublish) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _board == null && _months.isEmpty) {
      return ListView(children: [const SizedBox(height: 120), Center(child: Text(_error!))]);
    }
    if (_months.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.insights_outlined,
              size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                canPublish
                    ? 'Henüz finansal veri yok. Gelir/gider veya aidat girildiğinde aylar burada listelenir.'
                    : 'Yönetim henüz özet yayınlamadı.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      );
    }

    final board = _board;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Ay seçici.
        DropdownButtonFormField<String>(
          key: const Key('transparency_ay_dropdown'),
          initialValue: _ay,
          decoration: const InputDecoration(
            labelText: 'Dönem',
            prefixIcon: Icon(Icons.calendar_month_outlined),
            border: OutlineInputBorder(),
          ),
          items: [
            for (final m in _months)
              DropdownMenuItem(
                value: m.ay,
                child: Text(
                  '${_ayBaslik(m.ay)}${m.yayinlandi ? '' : ' • taslak'}',
                ),
              ),
          ],
          onChanged: _busy ? null : (v) => v == null ? null : _selectAy(v),
        ),
        const SizedBox(height: 12),

        // Yönetici: yayın anahtarı + önizleme uyarısı.
        if (canPublish && board != null) ...[
          Card(
            child: SwitchListTile(
              key: const Key('transparency_publish_switch'),
              title: const Text('Bu ayı yayınla'),
              subtitle: Text(board.yayinlandi
                  ? 'Sakinler bu özeti görüyor.'
                  : 'Yalnızca yönetim görüyor (önizleme).'),
              value: board.yayinlandi,
              onChanged: _busy ? null : _togglePublish,
            ),
          ),
          if (!board.yayinlandi)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text('Önizleme — henüz yayınlanmadı.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic)),
            ),
          const SizedBox(height: 8),
        ],

        if (board != null) ...[
          _OzetCard(board: board),
          const SizedBox(height: 12),
          _GiderDagilimCard(board: board),
          const SizedBox(height: 12),
          _AidatCard(aidat: board.aidat),
        ],
      ],
    );
  }
}

// --------------------------------------------------------------------------- //
class _OzetCard extends StatelessWidget {
  const _OzetCard({required this.board});
  final TransparencyBoard board;

  @override
  Widget build(BuildContext context) {
    final netColor = board.netKurus >= 0 ? Colors.green : Colors.red;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_ayBaslik(board.ay)} — Özet',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _row('Toplam gelir', _tl(board.toplamGelirKurus), Colors.green),
            _row('Toplam gider', _tl(board.toplamGiderKurus), Colors.red),
            const Divider(height: 20),
            _row('Net', _tl(board.netKurus), netColor, bold: true),
            if (board.oncekiAyNetKurus != null) ...[
              const SizedBox(height: 6),
              Text('Önceki ay net: ${_tl(board.oncekiAyNetKurus!)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v, Color c, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(k)),
            Text(v,
                style: TextStyle(
                    color: c,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
          ],
        ),
      );
}

class _GiderDagilimCard extends StatelessWidget {
  const _GiderDagilimCard({required this.board});
  final TransparencyBoard board;

  @override
  Widget build(BuildContext context) {
    final items = board.giderDagilimi;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gider dağılımı',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text('Bu ay gider kaydı yok.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant))
            else
              for (final k in items) ...[
                Row(
                  children: [
                    Expanded(child: Text(k.ad)),
                    Text('%${k.yuzde}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12)),
                    const SizedBox(width: 8),
                    Text(_tl(k.toplamKurus),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (k.yuzde.clamp(0, 100)) / 100,
                    minHeight: 6,
                    color: const Color(0xFF3949AB),
                    backgroundColor: Colors.blueGrey.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _AidatCard extends StatelessWidget {
  const _AidatCard({required this.aidat});
  final TransparencyAidat aidat;

  @override
  Widget build(BuildContext context) {
    final daireYuzde = aidat.daireOraniYuzde;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Aidat toplama',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(daireYuzde == null
                      ? 'Bu ay için tahakkuk yok.'
                      : 'Ödeyen daire: ${aidat.odeyenDaire}/${aidat.toplamDaire}'),
                ),
                if (daireYuzde != null)
                  Text('%$daireYuzde',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: daireYuzde >= 80 ? Colors.green : Colors.orange)),
              ],
            ),
            if (daireYuzde != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: daireYuzde / 100,
                  minHeight: 6,
                  color: daireYuzde >= 80 ? Colors.green : Colors.orange,
                  backgroundColor: Colors.blueGrey.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tahsilat: ${_tl(aidat.tahsilatKurus)} / ${_tl(aidat.tahakkukKurus)}'
                '  (tutar: %${aidat.tutarOraniYuzde ?? 0})',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning_amber_outlined,
                    size: 18,
                    color: aidat.gecikenDaireSayisi > 0
                        ? Colors.orange
                        : Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Gecikmede ${aidat.gecikenDaireSayisi} daire'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
