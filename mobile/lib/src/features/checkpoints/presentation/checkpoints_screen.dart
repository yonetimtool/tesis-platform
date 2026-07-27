import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../data/checkpoint_api.dart';
import '../../../core/error/akis_hatasi.dart';

/// Kontrol noktalari (NFC) yonetimi — yonetici/admin ekler/duzenler/siler
/// (Parca D). Guvenlik/tesis gorevlisi bu noktalari NFC ile okutur; okutmalar
/// "Devriye takibi" gun-gun raporunda gorunur.
class CheckpointsScreen extends ConsumerWidget {
  const CheckpointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(checkpointsProvider);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(baslikBuyuk(l10n.noktaBaslik, context.dilKodu)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(l10n.noktaEkle),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              // Sunucu metni varsa o (SERVER-LOCALIZED siniri).
              e is ApiException ? apiHataMetni(l10n, e) : l10n.noktaListelenemedi,
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
    final l10n = context.l10n;
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
          '${l10n.nfcUidSatir(ltrIzole(cp.nfcTagUid))}'
          '${cp.gpsLat != null ? ' · ${cp.gpsLat!.toStringAsFixed(4)}, ${cp.gpsLng?.toStringAsFixed(4)}' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!cp.aktif)
              Chip(
                label: Text(l10n.devriyePasif),
                visualDensity: VisualDensity.compact,
              ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _edit(context, ref);
                if (v == 'delete') _delete(context, ref);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l10n.ortakDuzenle)),
                PopupMenuItem(value: 'delete', child: Text(l10n.ortakSil)),
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
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(l10n.noktaSilOnay),
        content: Text(l10n.noktaSilGovde(cp.ad)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(false),
              child: Text(l10n.ortakVazgec)),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(dctx).pop(true),
              child: Text(l10n.ortakSil)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(checkpointApiProvider).delete(cp.id);
      ref.invalidate(checkpointsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.noktaSilindi)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiHataMetni(l10n, e))));
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
          // KOD ile karar (tur 11): eskiden sunucu METNINDE 'zaten' aranıyordu
          // — sunucu yerellestirilirse ya da metni degisirse sessizce bozulur.
          _error = (e.code == 'conflict' || e.statusCode == 409)
              ? _l10n.noktaUidZatenVar
              : apiHataMetni(_l10n, e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = _l10n.devriyeKaydedilemedi);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? l10n.noktaDuzenleBaslik : l10n.noktaYeniBaslik,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ad,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.kameraAd,
                hintText: l10n.noktaAdIpucu,
                prefixIcon: const Icon(Icons.place_outlined),
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? l10n.butAdZorunlu : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _uid,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: l10n.noktaUidAlan,
                hintText: l10n.noktaUidIpucu,
                prefixIcon: const Icon(Icons.nfc),
                border: const OutlineInputBorder(),
                helperText: l10n.noktaUidHelper,
              ),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? l10n.noktaUidZorunlu : null,
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
                    decoration: InputDecoration(
                      labelText: l10n.noktaEnlem,
                      border: const OutlineInputBorder(),
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
                    decoration: InputDecoration(
                      labelText: l10n.noktaBoylam,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.cipAktif),
              subtitle: Text(l10n.noktaPasifAlt),
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
                  : Text(_isEdit ? l10n.ortakGuncelle : l10n.ortakEkle),
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
              context.l10n.noktaYok,
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
