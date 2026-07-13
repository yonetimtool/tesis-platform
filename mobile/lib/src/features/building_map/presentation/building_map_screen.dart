import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../domain/building_map_models.dart';
import 'building_map_controller.dart';

/// "Bina Yerleşimi" (D-viz-1) — yonetici mobilden daire yerlesimini
/// (blok/kat/sira) girer/duzenler; liste ANONIM yogunluk rengini de gosterir
/// (blok->kat->daire + yerlesimsizler). Cizim (2D sema) SONRAKI turdur; bu
/// ekran yalniz veri girisi + onizlemedir. Backend RBAC yazmayi admin+yonetici
/// ile sinirlar.
class BuildingMapScreen extends ConsumerWidget {
  const BuildingMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(buildingMapControllerProvider);
    final controller = ref.read(buildingMapControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bina Yerleşimi'),
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
        child: _Body(state: state),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final BuildingMapState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loading && state.map == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null && state.map == null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(state.errorMessage!)),
        ],
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
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              state.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const Text(
          'Kat planı için daire yerleşimini (blok/kat/sıra) girin. '
          'Renk, anonim şikayet yoğunluğunu gösterir.',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        for (final blok in map.bloklar) _BlokCard(blok: blok),
        if (map.unplaced.isNotEmpty) _UnplacedCard(units: map.unplaced),
      ],
    );
  }
}

class _BlokCard extends StatelessWidget {
  const _BlokCard({required this.blok});

  final BuildingMapBlok blok;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Blok ${blok.blok}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            for (final kat in blok.katlar) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 2),
                child: Text('Kat ${kat.kat}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              for (final u in kat.units) _UnitTile(unit: u),
            ],
          ],
        ),
      ),
    );
  }
}

class _UnplacedCard extends StatelessWidget {
  const _UnplacedCard({required this.units});

  final List<BuildingMapUnit> units;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Yerleşimi girilmemiş',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Text('Haritaya yerleştirmek için blok ve kat girin.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 4),
            for (final u in units) _UnitTile(unit: u),
          ],
        ),
      ),
    );
  }
}

Color _renkColor(DensityRenk renk) {
  switch (renk) {
    case DensityRenk.yesil:
      return Colors.green;
    case DensityRenk.sari:
      return Colors.amber;
    case DensityRenk.kirmizi:
      return Colors.red;
    case DensityRenk.unknown:
      return Colors.grey;
  }
}

class _UnitTile extends ConsumerWidget {
  const _UnitTile({required this.unit});

  final BuildingMapUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final konum = unit.yerlesik
        ? 'Blok ${unit.blok} · Kat ${unit.kat}${unit.sira != null ? ' · Sıra ${unit.sira}' : ''}'
        : 'Yerleşim yok';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 8,
        backgroundColor: _renkColor(unit.color),
      ),
      title: Text('Daire ${unit.unitNo}'),
      subtitle: Text('$konum · ${unit.complaintCount} açık'),
      trailing: IconButton(
        tooltip: 'Yerleşimi düzenle',
        icon: const Icon(Icons.edit_location_alt_outlined),
        onPressed: () => _openLayoutSheet(context, ref, unit),
      ),
    );
  }
}

Future<void> _openLayoutSheet(
  BuildContext context,
  WidgetRef ref,
  BuildingMapUnit unit,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _LayoutForm(unit: unit),
    ),
  );
}

class _LayoutForm extends ConsumerStatefulWidget {
  const _LayoutForm({required this.unit});

  final BuildingMapUnit unit;

  @override
  ConsumerState<_LayoutForm> createState() => _LayoutFormState();
}

class _LayoutFormState extends ConsumerState<_LayoutForm> {
  late final TextEditingController _blok =
      TextEditingController(text: widget.unit.blok ?? '');
  late final TextEditingController _kat =
      TextEditingController(text: widget.unit.kat?.toString() ?? '');
  late final TextEditingController _sira =
      TextEditingController(text: widget.unit.sira?.toString() ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _blok.dispose();
    _kat.dispose();
    _sira.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final blok = _blok.text.trim();
    final katText = _kat.text.trim();
    final siraText = _sira.text.trim();
    final kat = katText.isEmpty ? null : int.tryParse(katText);
    final sira = siraText.isEmpty ? null : int.tryParse(siraText);
    // Girilmis ama sayi olmayan kat/sira -> istemci tarafinda yakala.
    if ((katText.isNotEmpty && kat == null) || (siraText.isNotEmpty && sira == null)) {
      setState(() {
        _busy = false;
        _error = 'Kat ve sıra tam sayı olmalı.';
      });
      return;
    }
    // Bos alan = "temizle" (null gonder); dolu alan = ayarla. En az biri gerekli.
    final draft = UnitLayoutDraft(
      blok: blok.isEmpty ? null : blok,
      clearBlok: blok.isEmpty,
      kat: kat,
      clearKat: katText.isEmpty,
      sira: sira,
      clearSira: siraText.isEmpty,
    );
    try {
      await ref
          .read(buildingMapControllerProvider.notifier)
          .updateLayout(widget.unit.unitId, draft);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Kaydedilemedi. Lütfen tekrar deneyin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Daire ${widget.unit.unitNo} — yerleşim',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _blok,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: 'Blok',
              hintText: 'A',
              helperText: 'Kısa alfanumerik (örn. A, B1)',
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _kat,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Kat',
                    hintText: '1',
                    helperText: '0 = zemin',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _sira,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Sıra',
                    hintText: '2',
                    helperText: 'Kattaki konum',
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Kaydediliyor...' : 'Kaydet'),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('İptal'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
