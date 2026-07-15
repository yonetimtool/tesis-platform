import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/text/tr_upper.dart';
import '../data/checkpoint_api.dart';

/// Kontrol noktalari (NFC) yonetimi — yonetici/admin ekler/duzenler/siler
/// (Parca D). Guvenlik/tesis gorevlisi bu noktalari NFC ile okutur; okutmalar
/// "Devriye takibi" gun-gun raporunda gorunur.
class CheckpointsScreen extends ConsumerWidget {
  const CheckpointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(checkpointsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(trUpper('Kontrol Noktaları'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Nokta ekle'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e is ApiException ? e.message : 'Noktalar listelenemedi.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (list) => list.isEmpty
            ? const _Empty()
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(checkpointsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _CheckpointTile(cp: list[i]),
                ),
              ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CheckpointForm(),
    );
    if (saved == true) ref.invalidate(checkpointsProvider);
  }
}

class _CheckpointTile extends ConsumerWidget {
  const _CheckpointTile({required this.cp});

  final Checkpoint cp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cp.aktif
              ? null
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(cp.aktif ? Icons.nfc : Icons.block),
        ),
        title: Text(cp.ad),
        subtitle: Text(
          'UID: ${cp.nfcTagUid}'
          '${cp.gpsLat != null ? ' · ${cp.gpsLat!.toStringAsFixed(4)}, ${cp.gpsLng?.toStringAsFixed(4)}' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!cp.aktif)
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
      builder: (_) => _CheckpointForm(existing: cp),
    );
    if (saved == true) ref.invalidate(checkpointsProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Nokta silinsin mi?'),
        content: Text('"${cp.ad}" kontrol noktası silinecek.'),
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
      await ref.read(checkpointApiProvider).delete(cp.id);
      ref.invalidate(checkpointsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Nokta silindi ✓')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _CheckpointForm extends ConsumerStatefulWidget {
  const _CheckpointForm({this.existing});

  final Checkpoint? existing;

  @override
  ConsumerState<_CheckpointForm> createState() => _CheckpointFormState();
}

class _CheckpointFormState extends ConsumerState<_CheckpointForm> {
  final _formKey = GlobalKey<FormState>();
  final _ad = TextEditingController();
  final _uid = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  bool _aktif = true;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _ad.text = e.ad;
      _uid.text = e.nfcTagUid;
      _lat.text = e.gpsLat?.toString() ?? '';
      _lng.text = e.gpsLng?.toString() ?? '';
      _aktif = e.aktif;
    }
  }

  @override
  void dispose() {
    _ad.dispose();
    _uid.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      final api = ref.read(checkpointApiProvider);
      if (_isEdit) {
        await api.update(
          widget.existing!.id,
          ad: _ad.text.trim(),
          nfcTagUid: _uid.text.trim().toUpperCase(),
          gpsLat: lat,
          gpsLng: lng,
          aktif: _aktif,
        );
      } else {
        await api.create(
          ad: _ad.text.trim(),
          nfcTagUid: _uid.text.trim().toUpperCase(),
          gpsLat: lat,
          gpsLng: lng,
          aktif: _aktif,
        );
      }
      if (mounted) navigator.pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message.contains('zaten')
              ? 'Bu NFC etiketi zaten kayıtlı.'
              : e.message;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Kaydedilemedi. Tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Nokta düzenle' : 'Yeni kontrol noktası',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ad,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ad',
                hintText: 'örn. Giriş Kapısı',
                prefixIcon: Icon(Icons.place_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? 'Ad zorunludur' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _uid,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'NFC etiket UID',
                hintText: 'örn. 04A2B3C4D5',
                prefixIcon: Icon(Icons.nfc),
                border: OutlineInputBorder(),
                helperText: 'Etiketin benzersiz kimliği (hex).',
              ),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? 'NFC UID zorunludur' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _lat,
                    enabled: !_busy,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Enlem (ops.)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lng,
                    enabled: !_busy,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: const InputDecoration(
                      labelText: 'Boylam (ops.)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktif'),
              subtitle: const Text('Pasif nokta okutmada eşleşmez'),
              value: _aktif,
              onChanged: _busy ? null : (v) => setState(() => _aktif = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(_isEdit ? 'Güncelle' : 'Ekle'),
            ),
          ],
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
            const Icon(Icons.location_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'Henüz kontrol noktası yok.\nSağ alttan NFC noktası ekleyin.',
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
