import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../data/transparency_api.dart';
import '../domain/seffaflik_hatasi.dart';
import '../domain/transparency_models.dart';
import '../../../core/error/akis_hatasi.dart';

/// Sunucudan "YYYY-MM" gelen donemi "Temmuz 2026" gibi yazar — AY ADI aktif
/// dilden gelir (`ayAdi`); bicim tanimazsa ham deger doner.
String _ayBaslik(String ay, String dil) {
  final p = ay.split('-');
  if (p.length != 2) return ay;
  final ad = ayAdi(int.tryParse(p[1]) ?? 0, dil);
  return ad.isEmpty ? ay : '$ad ${p[0]}';
}

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

  /// Hata KANALI ikilidir (README §15): sunucu metni + yerellestirilebilir
  /// kimlik.
  String? _error;
  SeffaflikHatasi? _hataKimligi;

  @override
  void initState() {
    super.initState();
    _loadMonths();
  }

  Future<void> _loadMonths() async {
    setState(() {
      _loading = true;
      _error = null;
      _hataKimligi = null;
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
      // Sunucu metni + AG kimligi AYRI kanallarda; metin cizimde cozulur
      // (`seffaflikHatasiCoz`) — burada context'e dokunmayiz.
      _error = e.message;
      _hataKimligi = seffaflikAgHatasi(e);
    } catch (_) {
      _hataKimligi = SeffaflikHatasi.yuklenemedi;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBoard(String ay) async {
    try {
      _board = await ref.read(transparencyApiProvider).fetchBoard(ay);
    } on ApiException catch (e) {
      _error = e.message;
      _hataKimligi = seffaflikAgHatasi(e);
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
          SnackBar(
            content: Text(yayin
                ? context.l10n.seffafAyYayinlandi
                : context.l10n.seffafYayinGeriAlindi),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiHataMetni(context.l10n, e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    final canPublish = role.canPublishTransparency;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.modulSeffaflik, context.dilKodu)),
        actions: [
          IconButton(
            tooltip: l10n.ortakYenile,
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
    final l10n = context.l10n;
    final dil = context.dilKodu;
    if (_loading) return const Center(child: CircularProgressIndicator());
    final hata = seffaflikHatasiCoz(l10n, _hataKimligi, _error);
    if (hata != null && _board == null && _months.isEmpty) {
      return ListView(
        children: [const SizedBox(height: 120), Center(child: Text(hata))],
      );
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
                canPublish ? l10n.seffafVeriYokYonetim : l10n.seffafVeriYok,
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
          // Uzun ceviriler ("September 2026 • Entwurf") + prefix ikon dar
          // ekranda satiri tasiriyordu (tur 3'teki "Atanan personel" ile ayni
          // desen): secili oge genisletilir, metin gerekirse kirpilir.
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.butDonem,
            prefixIcon: const Icon(Icons.calendar_month_outlined),
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final m in _months)
              DropdownMenuItem(
                value: m.ay,
                child: Text(
                  '${_ayBaslik(m.ay, dil)}'
                  '${m.yayinlandi ? '' : l10n.seffafTaslakEki}',
                  overflow: TextOverflow.ellipsis,
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
              title: Text(l10n.seffafYayinla),
              subtitle: Text(board.yayinlandi
                  ? l10n.seffafYayindaAlt
                  : l10n.seffafOnizlemeAlt),
              value: board.yayinlandi,
              onChanged: _busy ? null : _togglePublish,
            ),
          ),
          if (!board.yayinlandi)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(l10n.seffafOnizlemeUyari,
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
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final netColor = board.netKurus >= 0 ? Colors.green : Colors.red;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.seffafOzetBaslik(_ayBaslik(board.ay, dil)),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _row(l10n.seffafToplamGelir,
                tlSonEkli(board.toplamGelirKurus, dil), Colors.green),
            _row(l10n.seffafToplamGider,
                tlSonEkli(board.toplamGiderKurus, dil), Colors.red),
            const Divider(height: 20),
            _row(l10n.seffafNet, tlSonEkli(board.netKurus, dil), netColor,
                bold: true),
            if (board.oncekiAyNetKurus != null) ...[
              const SizedBox(height: 6),
              Text(
                  l10n.seffafOncekiAyNet(
                      tlSonEkli(board.oncekiAyNetKurus!, dil)),
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
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final items = board.giderDagilimi;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.seffafGiderDagilimi,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(l10n.seffafGiderYok,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant))
            else
              for (final k in items) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(k.ad, overflow: TextOverflow.ellipsis),
                    ),
                    Text(l10n.ortakYuzde('${k.yuzde}'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12)),
                    const SizedBox(width: 8),
                    // Tutar KIRPILMAZ, gerekirse KUCULUR (tur 6 emsali):
                    // milyonluk site butcesi dar ekrana sigmiyor.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(tlSonEkli(k.toplamKurus, dil),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
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
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final daireYuzde = aidat.daireOraniYuzde;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.seffafAidatToplama,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(daireYuzde == null
                      ? l10n.seffafTahakkukYok
                      : l10n.seffafOdeyenDaire(
                          '${aidat.odeyenDaire}', '${aidat.toplamDaire}')),
                ),
                if (daireYuzde != null)
                  Text(l10n.ortakYuzde('$daireYuzde'),
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
                l10n.seffafTahsilatSatir(
                  tlSonEkli(aidat.tahsilatKurus, dil),
                  tlSonEkli(aidat.tahakkukKurus, dil),
                  '${aidat.tutarOraniYuzde ?? 0}',
                ),
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
                // Dar ekranda satira sigmayabilir — sar.
                Expanded(
                  child: Text(l10n.seffafGecikmede(aidat.gecikenDaireSayisi)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
