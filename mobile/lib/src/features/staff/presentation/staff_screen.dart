import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/domain/user_role.dart';
import '../data/staff_api.dart';

/// Saha Personeli (Ozellik 3) — yonetici/admin: guvenlik + tesis gorevlisi
/// hesaplarini listeler ve ekler. yonetici backend'de YALNIZ saha personeli
/// acabilir; parola bossa donen gecici kod gosterilir.
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(fieldStaffProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saha Personeli')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Personel ekle'),
      ),
      body: staffAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e is ApiException ? e.message : 'Personel listelenemedi.',
          onRetry: () => ref.invalidate(fieldStaffProvider),
        ),
        data: (list) => list.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(fieldStaffProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _StaffTile(member: list[i]),
                ),
              ),
      ),
    );
  }

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddStaffSheet(),
    );
    if (created != null) {
      ref.invalidate(fieldStaffProvider);
    }
  }
}

class _StaffTile extends StatelessWidget {
  const _StaffTile({required this.member});

  final StaffMember member;

  @override
  Widget build(BuildContext context) {
    final roleLabel = UserRole.fromClaim(member.role).label;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            member.role == 'security'
                ? Icons.shield_outlined
                : Icons.cleaning_services_outlined,
          ),
        ),
        title: Text(member.ad),
        subtitle: Text(roleLabel),
        trailing: member.isActive
            ? null
            : Chip(
                label: const Text('Pasif'),
                visualDensity: VisualDensity.compact,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
      ),
    );
  }
}

class _AddStaffSheet extends ConsumerStatefulWidget {
  const _AddStaffSheet();

  @override
  ConsumerState<_AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends ConsumerState<_AddStaffSheet> {
  final _formKey = GlobalKey<FormState>();
  final _adCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _role = 'security';
  bool _submitting = false;

  @override
  void dispose() {
    _adCtrl.dispose();
    _phoneCtrl.dispose();
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
      final tempCode = await ref.read(staffApiProvider).addStaff(
            ad: _adCtrl.text.trim(),
            telefon: _phoneCtrl.text.trim(),
            role: _role,
            password: _passwordCtrl.text,
          );
      if (!mounted) return;
      navigator.pop('ok');
      if (tempCode != null && tempCode.isNotEmpty) {
        await _showTempCodeDialog(navigator.context, tempCode);
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Personel eklendi ✓')),
        );
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
          'Personel eklendi. Geçici kod:\n\n$code\n\n'
          'Bu kod yalnızca bir kez gösterilir; personele iletin. '
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
            Text('Personel ekle',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'security',
                    label: Text('Güvenlik'),
                    icon: Icon(Icons.shield_outlined)),
                ButtonSegment(
                    value: 'tesis_gorevlisi',
                    label: Text('Tesis Görevlisi'),
                    icon: Icon(Icons.cleaning_services_outlined)),
              ],
              selected: {_role},
              onSelectionChanged: _submitting
                  ? null
                  : (s) => setState(() => _role = s.first),
            ),
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
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
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
            const Icon(Icons.groups_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'Henüz saha personeli yok.\nSağ alttan ekleyebilirsiniz.',
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
