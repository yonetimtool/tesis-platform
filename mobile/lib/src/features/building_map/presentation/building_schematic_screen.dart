import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../../unit_complaints/data/unit_complaint_api.dart';
import '../../unit_complaints/domain/unit_complaint_models.dart';
import '../domain/building_map_models.dart';
import 'building_map_controller.dart';

/// "Şikayet Haritası" (D-viz Rev-1) — 2D bina semasi (kat plani), ROL-FARKINDA.
/// GET /building-map verisini cizer: blok -> kat (ust kat yukarida) -> daire
/// hucreleri.
///   * yonetici/admin (shows_density=true): hucreler RENKLI + sayi; detayda
///     ANONIM-OLMAYAN sikayet listesi (sikayet eden kimligi + not — denetim).
///   * resident: YALNIZ kendi blogu; hucreler RENKSIZ + sayisiz (yogunlugu
///     GORMEZ); detayda yalniz "Bu daireyi sikayet et" (own-block).
///   * security/tesis_gorevlisi: tum yapi, renksiz/sayisiz; detay salt yapi.
///
/// Renk API'den gelir; istemci ESIK HESAPLAMAZ. Hafif: Wrap + ListView.
class BuildingSchematicScreen extends ConsumerWidget {
  const BuildingSchematicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(buildingMapControllerProvider);
    final controller = ref.read(buildingMapControllerProvider.notifier);
    final isResident =
        ref.watch(currentUserRoleProvider).value == UserRole.resident;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Şikayet Haritası'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: state.loading ? null : controller.refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: _Body(state: state, isResident: isResident),
      ),
    );
  }
}

/// Yogunluk rengini Flutter rengine cevirir (API'nin dondurdugu renk).
Color densityColor(DensityRenk? renk) {
  switch (renk) {
    case DensityRenk.yesil:
      return const Color(0xFF43A047);
    case DensityRenk.sari:
      return const Color(0xFFF9A825);
    case DensityRenk.kirmizi:
      return const Color(0xFFE53935);
    case DensityRenk.unknown:
    case null:
      return Colors.blueGrey; // yapi gorunumu (yogunluk yok)
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.isResident});

  final BuildingMapState state;
  final bool isResident;

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.map == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.map == null) {
      return ListView(
        children: [const SizedBox(height: 120), Center(child: Text(state.errorMessage!))],
      );
    }
    final map = state.map;
    if (map == null || map.bos) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text('Henüz daire yok.')),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (map.showsDensity)
          const _Legend()
        else
          const _StructureNote(),
        const SizedBox(height: 12),
        for (final blok in map.bloklar)
          _BlokSchematic(blok: blok, map: map, isResident: isResident),
        if (map.unplaced.isNotEmpty)
          _UnplacedList(units: map.unplaced, map: map, isResident: isResident),
      ],
    );
  }
}

/// Renk esiklerini aciklayan gosterge (0-2 yesil, 3-4 sari, 5+ kirmizi) —
/// yalniz yonetim gorunumunde.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(DensityRenk renk, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: densityColor(renk),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            const Text('Yoğunluk:', style: TextStyle(fontWeight: FontWeight.w600)),
            item(DensityRenk.yesil, '0–2'),
            item(DensityRenk.sari, '3–4'),
            item(DensityRenk.kirmizi, '5+'),
          ],
        ),
      ),
    );
  }
}

/// Yapi gorunumunde (resident/saha) yogunluk gizlidir — kisa bilgi notu.
class _StructureNote extends StatelessWidget {
  const _StructureNote();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Bina yerleşimi. Şikayet yoğunluğu yalnızca yönetime gösterilir.',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ),
    );
  }
}

/// Bir blok — katlar UST KAT YUKARIDA (kat azalan) dizilir.
class _BlokSchematic extends StatelessWidget {
  const _BlokSchematic({
    required this.blok,
    required this.map,
    required this.isResident,
  });

  final BuildingMapBlok blok;
  final BuildingMap map;
  final bool isResident;

  @override
  Widget build(BuildContext context) {
    final katlar = blok.katlar.reversed.toList(growable: false);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Blok ${blok.blok}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final kat in katlar)
              _KatRow(kat: kat, map: map, isResident: isResident),
          ],
        ),
      ),
    );
  }
}

class _KatRow extends StatelessWidget {
  const _KatRow({required this.kat, required this.map, required this.isResident});

  final BuildingMapKat kat;
  final BuildingMap map;
  final bool isResident;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text('Kat ${kat.kat}',
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final u in kat.units)
                  _UnitCell(unit: u, map: map, isResident: isResident),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek daire hucresi — yonetimde renk+sayi; digerinde noturr (yapi).
class _UnitCell extends StatelessWidget {
  const _UnitCell({required this.unit, required this.map, required this.isResident});

  final BuildingMapUnit unit;
  final BuildingMap map;
  final bool isResident;

  @override
  Widget build(BuildContext context) {
    final density = map.showsDensity;
    final color = density ? densityColor(unit.color) : Colors.blueGrey.shade300;
    return InkWell(
      onTap: () => showUnitDetailSheet(context, unit, map: map, isResident: isResident),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 58,
        height: 46,
        decoration: BoxDecoration(
          color: density ? color.withValues(alpha: 0.85) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: density ? 1 : 1.5),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              unit.unitNo,
              style: TextStyle(
                color: density ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            // Sayi YALNIZ yonetimde (resident/saha yogunlugu gormez).
            if (density)
              Text(
                '${unit.complaintCount ?? 0}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnplacedList extends StatelessWidget {
  const _UnplacedList({
    required this.units,
    required this.map,
    required this.isResident,
  });

  final List<BuildingMapUnit> units;
  final BuildingMap map;
  final bool isResident;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Haritada yerleşimi girilmemiş',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final u in units)
                  _UnitCell(unit: u, map: map, isResident: isResident),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Daire detay alt sayfasi — ROL-FARKINDA: yonetimde sayim + renk + sikayet
/// listesi (sikayet eden kimligi); resident'ta yalniz "sikayet et"; sahada
/// salt yapi.
void showUnitDetailSheet(
  BuildContext context,
  BuildingMapUnit unit, {
  required BuildingMap map,
  required bool isResident,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _UnitDetailSheet(
        unit: unit,
        showsDensity: map.showsDensity,
        isResident: isResident,
      ),
    ),
  );
}

class _UnitDetailSheet extends ConsumerStatefulWidget {
  const _UnitDetailSheet({
    required this.unit,
    required this.showsDensity,
    required this.isResident,
  });

  final BuildingMapUnit unit;
  final bool showsDensity;
  final bool isResident;

  @override
  ConsumerState<_UnitDetailSheet> createState() => _UnitDetailSheetState();
}

class _UnitDetailSheetState extends ConsumerState<_UnitDetailSheet> {
  Future<List<UnitComplaint>>? _future;

  @override
  void initState() {
    super.initState();
    // Sikayet listesi YALNIZ yonetim gorunumunde cekilir (backend 403 verir
    // digerlerine — bosuna cagirmayiz).
    if (widget.showsDensity) _future = _load();
  }

  Future<List<UnitComplaint>> _load() => ref
      .read(unitComplaintApiProvider)
      .fetchForUnit(widget.unit.unitId, acikOnly: true);

  void _reload() {
    if (widget.showsDensity) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.unit;
    final color = densityColor(u.color);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.showsDensity) ...[
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text('Daire ${u.unitNo}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (widget.showsDensity)
                  Text('${u.complaintCount ?? 0} açık şikayet',
                      style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            // Sikayet listesi YALNIZ yonetim (denetim: sikayet eden + not).
            if (widget.showsDensity)
              SizedBox(height: 220, child: _ComplaintList(future: _future))
            else
              const Text(
                'Şikayet yoğunluğu yalnızca yönetime gösterilir.',
                style: TextStyle(color: Colors.black54),
              ),
            if (widget.isResident) ...[
              const Divider(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_alert_outlined),
                  label: const Text('Bu daireyi şikayet et'),
                  onPressed: () => _openFileForm(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openFileForm(BuildContext context) async {
    final filed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FileComplaintForm(unit: widget.unit),
    );
    if (filed == true) {
      await ref.read(buildingMapControllerProvider.notifier).refresh();
      if (mounted) _reload();
    }
  }
}

/// Yonetim gorunumu: bir dairenin ACIK sikayetleri (kategori + tarih + sikayet
/// eden adi + not — DENETIM). resident/saha bu listeye erisemez (403).
class _ComplaintList extends StatelessWidget {
  const _ComplaintList({required this.future});

  final Future<List<UnitComplaint>>? future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UnitComplaint>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(child: Text('Şikayetler yüklenemedi.'));
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return const Center(child: Text('Bu daire için açık şikayet yok.'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final c = items[i];
            final kimlik = c.complainantAd != null ? ' · ${c.complainantAd}' : '';
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.report_gmailerrorred_outlined),
              title: Text(c.kategori.label),
              subtitle: Text(
                '${_fmtDate(c.createdAt.toLocal())}$kimlik'
                '${c.notlar != null ? '\n${c.notlar}' : ''}',
              ),
              isThreeLine: c.notlar != null,
            );
          },
        );
      },
    );
  }
}

/// Daire sikayeti formu (YALNIZ resident) — kategori + opsiyonel not.
class _FileComplaintForm extends ConsumerStatefulWidget {
  const _FileComplaintForm({required this.unit});

  final BuildingMapUnit unit;

  @override
  ConsumerState<_FileComplaintForm> createState() => _FileComplaintFormState();
}

class _FileComplaintFormState extends ConsumerState<_FileComplaintForm> {
  UnitComplaintKategori _kategori = UnitComplaintKategori.gurultu;
  final _notlar = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _notlar.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(unitComplaintApiProvider).file(
            UnitComplaintDraft(
              targetUnitId: widget.unit.unitId,
              kategori: _kategori,
              notlar: _notlar.text.trim().isEmpty ? null : _notlar.text.trim(),
            ),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // 409: zaten acik sikayet; 403: kendi blogun disi.
        _error = switch (e.statusCode) {
          409 => 'Bu daire için zaten açık bir şikayetiniz var.',
          403 => 'Yalnızca kendi bloğunuzdaki daireleri şikayet edebilirsiniz.',
          _ => e.message,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Gönderilemedi. Lütfen tekrar deneyin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daire ${widget.unit.unitNo} — şikayet et',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Şikayetiniz yönetime iletilir; komşularınıza gösterilmez.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<UnitComplaintKategori>(
            initialValue: _kategori,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final k in UnitComplaintKategori.values)
                DropdownMenuItem(value: k, child: Text(k.label)),
            ],
            onChanged: (v) => setState(() => _kategori = v ?? _kategori),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notlar,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Not (opsiyonel)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Gönderiliyor...' : 'Şikayeti gönder'),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtDate(DateTime dt) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(dt.day)}.${p(dt.month)}.${dt.year}';
}
