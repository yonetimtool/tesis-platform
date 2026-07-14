import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../auth/domain/user_role.dart';
import '../data/profile_api.dart';
import '../domain/profile.dart';

/// Self-servis profil ekrani — kullanici KENDI parolasini ve telefon/arama
/// rizasini gunceller (contracts/auth.md self-servis profil). Sag-ust profil
/// ikonundan acilir.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: e is ApiException ? e.message : 'Profil yüklenemedi.',
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (profile) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Header(profile: profile),
            const SizedBox(height: 16),
            const _PasswordCard(),
            const SizedBox(height: 16),
            _ContactCard(
              initialTelefon: profile.telefon ?? '',
              initialAranabilir: profile.aranabilir,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final roleLabel = UserRole.fromClaim(profile.role).label;
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: scheme.primaryContainer,
          child: Icon(Icons.person_outline,
              size: 32, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.ad,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(roleLabel, style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                profile.telefon?.isNotEmpty == true
                    ? profile.telefon!
                    : 'Numara girilmemiş',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Parola degistirme karti: mevcut / yeni / yeni (tekrar). Client-side eslesme
/// + min 8; backend mevcut parolayi dogrular (hatali → 400).
class _PasswordCard extends ConsumerStatefulWidget {
  const _PasswordCard();

  @override
  ConsumerState<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends ConsumerState<_PasswordCard> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      await ref.read(profileApiProvider).changePassword(
            currentPassword: _currentCtrl.text,
            newPassword: _newCtrl.text,
          );
      if (!mounted) return;
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Parola güncellendi ✓')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Parola değiştir',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _currentCtrl,
                enabled: !_submitting,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Mevcut parola',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Mevcut parola zorunludur' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newCtrl,
                enabled: !_submitting,
                obscureText: _obscure,
                decoration: const InputDecoration(
                  labelText: 'Yeni parola',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final value = v ?? '';
                  if (value.isEmpty) return 'Yeni parola zorunludur';
                  if (value.length < 8) return 'En az 8 karakter olmalı';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmCtrl,
                enabled: !_submitting,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Yeni parola (tekrar)',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '') != _newCtrl.text ? 'Parolalar eşleşmiyor' : null,
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
                    : const Text('Parolayı güncelle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Iletisim karti: telefon + "Aranabilir" (aranmaya riza). En az bir alan
/// degisince kaydedilir; kayit sonrasi profil tazelenir.
class _ContactCard extends ConsumerStatefulWidget {
  const _ContactCard({
    required this.initialTelefon,
    required this.initialAranabilir,
  });

  final String initialTelefon;
  final bool initialAranabilir;

  @override
  ConsumerState<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends ConsumerState<_ContactCard> {
  late final TextEditingController _telefonCtrl =
      TextEditingController(text: widget.initialTelefon);
  late bool _aranabilir = widget.initialAranabilir;
  bool _submitting = false;

  @override
  void dispose() {
    _telefonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      await ref.read(profileApiProvider).updateContact(
            telefon: _telefonCtrl.text.trim(),
            aranabilir: _aranabilir,
          );
      if (!mounted) return;
      ref.invalidate(profileProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('İletişim bilgileri güncellendi ✓')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('İletişim',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _telefonCtrl,
              enabled: !_submitting,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                hintText: 'örn. +905551112233',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              value: _aranabilir,
              onChanged:
                  _submitting ? null : (v) => setState(() => _aranabilir = v),
              title: const Text('Aranabilir'),
              subtitle: const Text(
                'Yetkili roller (rıza gerektiren arama) numaranıza ulaşabilir',
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
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
                  : const Text('İletişimi kaydet'),
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
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
