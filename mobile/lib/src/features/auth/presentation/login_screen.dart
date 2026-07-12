import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

/// Giris modu: personel (email) vs sakin (daire no) — auth.md §1.1/§1.2.
enum _LoginMode { personel, sakin }

/// Iki modlu login ekrani:
///   * Personel: tenant_slug + email + parola (LoginRequest — mevcut akis).
///   * Sakin: tenant_slug + daire no + parola/gecici kod
///     (ResidentLoginRequest; ilk giriste parola belirleme ekranina gecilir).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tenantCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _unitNoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = false;
  _LoginMode _mode = _LoginMode.personel;

  @override
  void dispose() {
    _tenantCtrl.dispose();
    _emailCtrl.dispose();
    _unitNoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authControllerProvider.notifier);
    if (_mode == _LoginMode.sakin) {
      await auth.loginResident(
        tenantSlug: _tenantCtrl.text.trim(),
        unitNo: _unitNoCtrl.text.trim(),
        password: _passwordCtrl.text,
        rememberMe: _rememberMe,
      );
    } else {
      await auth.login(
        tenantSlug: _tenantCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        rememberMe: _rememberMe,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final submitting = auth.submitting;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.shield_outlined, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Tesis Güvenlik',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    // Personel (email) / Sakin (daire no) giris modu secimi.
                    SegmentedButton<_LoginMode>(
                      key: const Key('login_mode_toggle'),
                      segments: const [
                        ButtonSegment(
                          value: _LoginMode.personel,
                          label: Text('Personel'),
                          icon: Icon(Icons.badge_outlined),
                        ),
                        ButtonSegment(
                          value: _LoginMode.sakin,
                          label: Text('Sakin'),
                          icon: Icon(Icons.home_outlined),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: submitting
                          ? null
                          : (selection) =>
                              setState(() => _mode = selection.single),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _tenantCtrl,
                      enabled: !submitting,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Tesis kodu (tenant)',
                        hintText: 'örn. acme-plaza',
                        prefixIcon: Icon(Icons.apartment_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Tesis kodu zorunludur';
                        if (!RegExp(r'^[a-z0-9-]+$').hasMatch(value)) {
                          return 'Yalnızca küçük harf, rakam ve tire';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_mode == _LoginMode.personel)
                      TextFormField(
                        controller: _emailCtrl,
                        enabled: !submitting,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'E-posta',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return 'E-posta zorunludur';
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Geçerli bir e-posta girin';
                          }
                          return null;
                        },
                      )
                    else
                      TextFormField(
                        controller: _unitNoCtrl,
                        enabled: !submitting,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Daire no',
                          hintText: 'örn. A-12',
                          prefixIcon: Icon(Icons.door_front_door_outlined),
                          border: OutlineInputBorder(),
                          helperText:
                              'İlk girişte yönetimden aldığınız geçici kodu '
                              'parola alanına yazın.',
                          helperMaxLines: 2,
                        ),
                        validator: (v) {
                          if ((v?.trim() ?? '').isEmpty) {
                            return 'Daire no zorunludur';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      enabled: !submitting,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: _mode == _LoginMode.sakin
                            ? 'Parola veya geçici kod'
                            : 'Parola',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        final value = v ?? '';
                        if (value.isEmpty) return 'Parola zorunludur';
                        if (value.length < 8) {
                          return 'Parola en az 8 karakter olmalı';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    // Isaretliyse oturum kalici saklanir → sonraki acilista
                    // sifre sorulmadan dogrudan ana ekran.
                    CheckboxListTile(
                      key: const Key('remember_me_checkbox'),
                      value: _rememberMe,
                      onChanged: submitting
                          ? null
                          : (v) => setState(() => _rememberMe = v ?? false),
                      title: const Text('Beni hatırla'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    if (auth.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: auth.errorMessage!),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const Text('Giriş yap'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
