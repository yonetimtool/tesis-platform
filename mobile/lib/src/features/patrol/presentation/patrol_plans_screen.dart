import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/text/tr_upper.dart';
import '../../checkpoints/data/checkpoint_api.dart';
import '../data/patrol_plan_api.dart';

/// Devriye planlari yonetimi — yonetici/admin: her gun tekrar eden devriye
/// planlari (ad + baslangic/bitis saati + tur sikligi + kontrol noktalari).
/// Scheduler plandan pencere uretir; saha okutur; yonetici gun-gun takip eder.
class PatrolPlansScreen extends ConsumerWidget {
  const PatrolPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(patrolPlansProvider);
    return Scaffold(
      appBar: AppBar(title: Text(trUpper('Devriye Planları'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Plan ekle'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e is ApiException ? e.message : 'Planlar listelenemedi.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (list) => list.isEmpty
            ? const _Empty()
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(patrolPlansProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _PlanTile(plan: list[i]),
                ),
              ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PlanForm(),
    );
    if (saved == true) ref.invalidate(patrolPlansProvider);
  }
}

class _PlanTile extends ConsumerWidget {
  const _PlanTile({required this.plan});

  final PatrolPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: plan.aktif
              ? null
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(plan.aktif ? Icons.route_outlined : Icons.block),
        ),
        title: Text(plan.ad),
        subtitle: Text(
          '${plan.baslangicHHMM}–${plan.bitisHHMM} · her ${plan.periyotDakika} dk',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!plan.aktif)
              const Chip(
                label: Text('Pasif'),
                visualDensity: VisualDensity.compact,
              ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _edit(context, ref);
                if (v == 'delete') _delete(context, ref);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                PopupMenuItem(value: 'delete', child: Text('Sil')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlanForm(existing: plan),
    );
    if (saved == true) ref.invalidate(patrolPlansProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Plan silinsin mi?'),
        content: Text('"${plan.ad}" devriye planı silinecek.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: const Text('Vazgeç')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(dctx).pop(true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(patrolPlanApiProvider).delete(plan.id);
      ref.invalidate(patrolPlansProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Plan silindi ✓')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _PlanForm extends ConsumerStatefulWidget {
  const _PlanForm({this.existing});

  final PatrolPlan? existing;

  @override
  ConsumerState<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends ConsumerState<_PlanForm> {
  final _formKey = GlobalKey<FormState>();
  final _ad = TextEditingController();
  final _periyot = TextEditingController(text: '60');
  TimeOfDay _baslangic = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _bitis = const TimeOfDay(hour: 6, minute: 0);
  bool _aktif = true;
  final Set<String> _selected = {};
  bool _busy = false;
  String? _error;
  bool _loadingSelection = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _ad.text = e.ad;
      _periyot.text = '${e.periyotDakika}';
      _baslangic = _parse(e.baslangicSaat);
      _bitis = _parse(e.bitisSaat);
      _aktif = e.aktif;
      // Mevcut atanmis noktalari yukle.
      _loadingSelection = true;
      Future.microtask(() async {
        try {
          final ids = await ref.read(patrolPlanApiProvider).checkpointIds(e.id);
          if (mounted) setState(() => _selected.addAll(ids));
        } finally {
          if (mounted) setState(() => _loadingSelection = false);
        }
      });
    }
  }

  static TimeOfDay _parse(String hhmmss) {
    final p = hhmmss.split(':');
    return TimeOfDay(
      hour: int.tryParse(p.isNotEmpty ? p[0] : '') ?? 0,
      minute: int.tryParse(p.length > 1 ? p[1] : '') ?? 0,
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  @override
  void dispose() {
    _ad.dispose();
    _periyot.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool baslangic) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: baslangic ? _baslangic : _bitis,
    );
    if (picked != null) {
      setState(() => baslangic ? _baslangic = picked : _bitis = picked);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final periyot = int.tryParse(_periyot.text.trim());
    if (periyot == null || periyot < 1) {
      setState(() => _error = 'Tur sıklığı (dk) pozitif olmalı.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      final api = ref.read(patrolPlanApiProvider);
      final String planId;
      if (_isEdit) {
        await api.update(
          widget.existing!.id,
          ad: _ad.text.trim(),
          baslangicSaat: _fmt(_baslangic),
          bitisSaat: _fmt(_bitis),
          periyotDakika: periyot,
          aktif: _aktif,
        );
        planId = widget.existing!.id;
      } else {
        final created = await api.create(
          ad: _ad.text.trim(),
          baslangicSaat: _fmt(_baslangic),
          bitisSaat: _fmt(_bitis),
          periyotDakika: periyot,
          aktif: _aktif,
        );
        planId = created.id;
      }
      // Kontrol noktalarini ata (sira = secim listesindeki index).
      await api.setCheckpoints(planId, _selected.toList());
      if (mounted) navigator.pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Kaydedilemedi. Tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final checkpoints =
        (ref.watch(checkpointsProvider).value ?? const <Checkpoint>[])
            .where((c) => c.aktif)
            .toList();
    final allSelected =
        checkpoints.isNotEmpty && checkpoints.every((c) => _selected.contains(c.id));
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isEdit ? 'Devriye planı düzenle' : 'Yeni devriye planı',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ad,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Plan adı',
                  hintText: 'örn. Gece devriyesi',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v?.trim() ?? '').isEmpty ? 'Ad zorunludur' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: Text('Başlangıç ${_fmt(_baslangic).substring(0, 5)}'),
                      onPressed: _busy ? null : () => _pickTime(true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: Text('Bitiş ${_fmt(_bitis).substring(0, 5)}'),
                      onPressed: _busy ? null : () => _pickTime(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _periyot,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tur sıklığı (dakika)',
                  helperText: 'örn. 60 = saatte bir tur',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif'),
                value: _aktif,
                onChanged: _busy ? null : (v) => setState(() => _aktif = v),
              ),
              const Divider(),
              Row(
                children: [
                  const Expanded(
                    child: Text('Kontrol noktaları',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  if (checkpoints.isNotEmpty)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                if (allSelected) {
                                  _selected.clear();
                                } else {
                                  _selected
                                    ..clear()
                                    ..addAll(checkpoints.map((c) => c.id));
                                }
                              }),
                      child: Text(allSelected ? 'Tümünü kaldır' : 'Tümünü seç'),
                    ),
                ],
              ),
              if (_loadingSelection)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(),
                ),
              if (checkpoints.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Aktif kontrol noktası yok. Önce "Kontrol noktaları"ndan ekleyin.',
                    style: TextStyle(color: Colors.orange),
                  ),
                )
              else
                for (final c in checkpoints)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(c.ad),
                    subtitle: Text('UID: ${c.nfcTagUid}'),
                    value: _selected.contains(c.id),
                    onChanged: _busy
                        ? null
                        : (v) => setState(() {
                              if (v == true) {
                                _selected.add(c.id);
                              } else {
                                _selected.remove(c.id);
                              }
                            }),
                  ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(_isEdit ? 'Güncelle' : 'Oluştur'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.route_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'Henüz devriye planı yok.\nSağ alttan ekleyin (saatler + noktalar).',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
