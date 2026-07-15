import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/residents_api.dart';

/// Site Sakinleri — yonetici/admin: sakinleri listeler, yeni tasinani ekler
/// (gecici kod), ayrilani cikarir (pasiflestir). Sakin KENDI kayit olamaz.
class ResidentsScreen extends ConsumerWidget {
  const ResidentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(residentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Site Sakinleri')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Sakin ekle'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e is ApiException ? e.message : 'Sakinler listelenemedi.',
          onRetry: () => ref.invalidate(residentsProvider),
        ),
        data: (list) => list.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(residentsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      _ResidentTile(member: list[i], ref: ref),
                ),
              ),
      ),
    );
  }

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddResidentSheet(),
    );
    if (created != null) ref.invalidate(residentsProvider);
  }
}

class _ResidentTile extends StatelessWidget {
  const _ResidentTile({required this.member, required this.ref});

  final ResidentMember member;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final subtitle = member.unitNo?.isNotEmpty == true
        ? 'Daire ${member.unitNo}'
        : 'Daire atanmamış';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(member.isActive ? Icons.home_outlined : Icons.person_off_outlined),
        ),
        title: Text(member.ad),
        subtitle: Text(subtitle),
        trailing: member.isActive
            ? TextButton.icon(
                onPressed: () => _confirmRemove(context),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Çıkar'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              )
            : Chip(
                label: const Text('Pasif'),
                visualDensity: VisualDensity.compact,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sakini çıkar?'),
        content: Text(
          '"${member.ad}" siteden çıkarılır: daire bağı sonlanır ve hesabı '
          'pasifleşir (artık giriş yapamaz).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(residentsApiProvider).removeResident(member.userId);
      ref.invalidate(residentsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('"${member.ad}" çıkarıldı')),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _AddResidentSheet extends ConsumerStatefulWidget {
  const _AddResidentSheet();

  @override
  ConsumerState<_AddResidentSheet> createState() => _AddResidentSheetState();
}

class _AddResidentSheetState extends ConsumerState<_AddResidentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _adCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _adCtrl.dispose();
    _phoneCtrl.dispose();
    _unitCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _submitting = true);
    try {
      final tempCode = await ref.read(residentsApiProvider).addResident(
            ad: _adCtrl.text.trim(),
            telefon: _phoneCtrl.text.trim(),
            unitNo: _unitCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      if (!mounted) return;
      navigator.pop('ok');
      if (tempCode != null && tempCode.isNotEmpty) {
        await _showTempCodeDialog(navigator.context, tempCode);
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Sakin eklendi ✓')));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _submitting = false);
    }
  }

  Future<void> _showTempCodeDialog(BuildContext context, String code) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Geçici giriş kodu'),
        content: Text(
          'Sakin eklendi. Geçici kod:\n\n$code\n\n'
          'Bu kod yalnızca bir kez gösterilir; sakine iletin. '
          'Telefon + bu kod ile girip parolasını belirler.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
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
            Text('Sakin ekle', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _adCtrl,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: 'Ad Soyad',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.trim() ?? '').length < 2 ? 'Ad zorunludur' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              enabled: !_submitting,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Cep telefonu',
                hintText: 'örn. 0532 111 22 03',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
                helperText: 'Giriş anahtarı (global benzersiz).',
              ),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? 'Telefon zorunludur' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unitCtrl,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: 'Daire no',
                hintText: 'örn. A-12',
                prefixIcon: Icon(Icons.door_front_door_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? 'Daire no zorunludur' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              enabled: !_submitting,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Parola (opsiyonel)',
                helperText: 'Boş bırakırsanız geçici kod üretilir',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final value = v ?? '';
                if (value.isNotEmpty && value.length < 8) {
                  return 'En az 8 karakter olmalı';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.home_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'Henüz site sakini yok.\nSağ alttan ekleyebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}
