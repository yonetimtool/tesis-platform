import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/text/tr_upper.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../data/dis_hizmet_api.dart';

/// Dis Hizmetler — guvenilir esnaf/hizmet kisileri (cilingir/elektrik/tesisat)
/// + yonetici notu. Yonetici/admin ekler/duzenler/siler + notu yazar; guvenlik
/// ve sakin salt-okuma gorur (arayabilir).
class DisHizmetScreen extends ConsumerWidget {
  const DisHizmetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role =
        ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    final canWrite = role == UserRole.admin || role == UserRole.yonetici;
    final async = ref.watch(disHizmetlerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(trUpper('Dış Hizmetler'))),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(context, ref),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Kişi ekle'),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e is ApiException ? e.message : 'Liste alınamadı.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(disHizmetlerProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              _NoteCard(note: data.note, canWrite: canWrite),
              const SizedBox(height: 8),
              if (data.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      canWrite
                          ? 'Henüz kayıt yok. Sağ alttan güvendiğiniz esnafı ekleyin.'
                          : 'Henüz dış hizmet kaydı yok.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              else
                for (final h in data.items)
                  _HizmetTile(hizmet: h, canWrite: canWrite),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _HizmetForm(),
    );
    if (saved == true) ref.invalidate(disHizmetlerProvider);
  }
}

class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.note, required this.canWrite});

  final String? note;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final has = note != null && note!.trim().isNotEmpty;
    if (!has && !canWrite) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                has ? note! : 'Not ekleyin (yalnızca yönetici düzenler).',
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontStyle: has ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
            if (canWrite)
              IconButton(
                tooltip: 'Notu düzenle',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editNote(context, ref),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: note ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Bölüm notu'),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          minLines: 3,
          decoration: const InputDecoration(
            hintText: 'örn. Yıllardır güvendiğimiz esnaflar; site güvenliği '
                'için yabancı kişileri içeri almayın.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dctx).pop(null),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.of(dctx).pop(ctrl.text.trim()),
              child: const Text('Kaydet')),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(disHizmetApiProvider).setNote(result.isEmpty ? null : result);
      ref.invalidate(disHizmetlerProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Not güncellendi ✓')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _HizmetTile extends ConsumerWidget {
  const _HizmetTile({required this.hizmet, required this.canWrite});

  final DisHizmet hizmet;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = hizmet;
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(h.tur.isNotEmpty ? h.tur[0] : '?')),
        title: Text(h.adSoyad),
        subtitle: Text(
          h.tur +
              (h.aciklama != null && h.aciklama!.isNotEmpty
                  ? '\n${h.aciklama}'
                  : ''),
        ),
        isThreeLine: h.aciklama != null && h.aciklama!.isNotEmpty,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Ara',
              icon: const Icon(Icons.call, color: Colors.green),
              onPressed: () => _call(h.telefon),
            ),
            if (canWrite)
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

  Future<void> _call(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-().]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    await launchUrl(uri);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HizmetForm(existing: hizmet),
    );
    if (saved == true) ref.invalidate(disHizmetlerProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Kayıt silinsin mi?'),
        content: Text('"${hizmet.adSoyad}" silinecek.'),
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
      await ref.read(disHizmetApiProvider).delete(hizmet.id);
      ref.invalidate(disHizmetlerProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Silindi ✓')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _HizmetForm extends ConsumerStatefulWidget {
  const _HizmetForm({this.existing});

  final DisHizmet? existing;

  @override
  ConsumerState<_HizmetForm> createState() => _HizmetFormState();
}

class _HizmetFormState extends ConsumerState<_HizmetForm> {
  final _formKey = GlobalKey<FormState>();
  final _tur = TextEditingController();
  final _ad = TextEditingController();
  final _soyad = TextEditingController();
  final _telefon = TextEditingController();
  final _aciklama = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _tur.text = e.tur;
      _ad.text = e.ad;
      _soyad.text = e.soyad;
      _telefon.text = e.telefon;
      _aciklama.text = e.aciklama ?? '';
    }
  }

  @override
  void dispose() {
    _tur.dispose();
    _ad.dispose();
    _soyad.dispose();
    _telefon.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final aciklama =
        _aciklama.text.trim().isEmpty ? null : _aciklama.text.trim();
    try {
      final api = ref.read(disHizmetApiProvider);
      if (_isEdit) {
        await api.update(
          widget.existing!.id,
          tur: _tur.text.trim(),
          ad: _ad.text.trim(),
          soyad: _soyad.text.trim(),
          telefon: _telefon.text.trim(),
          aciklama: aciklama,
        );
      } else {
        await api.create(
          tur: _tur.text.trim(),
          ad: _ad.text.trim(),
          soyad: _soyad.text.trim(),
          telefon: _telefon.text.trim(),
          aciklama: aciklama,
        );
      }
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
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Kişi düzenle' : 'Yeni dış hizmet kişisi',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tur,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Hizmet türü',
                hintText: 'örn. Çilingir, Elektrik, Tesisat',
                prefixIcon: Icon(Icons.handyman_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? 'Tür zorunludur' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ad,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Ad',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v?.trim() ?? '').isEmpty ? 'Ad gerekli' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _soyad,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Soyad',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v?.trim() ?? '').isEmpty ? 'Soyad gerekli' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefon,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                hintText: 'örn. 0532 111 22 33',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? 'Telefon zorunludur' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aciklama,
              enabled: !_busy,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Açıklama (opsiyonel)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
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
