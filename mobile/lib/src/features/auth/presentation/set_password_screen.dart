import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/l10n.dart';
import '../../../core/validators/password_rule.dart';
import 'auth_controller.dart';
import 'giris_hata_metni.dart';

/// Sakinin gecici kodla ILK girisinden sonraki ZORUNLU kalici parola
/// belirleme ekrani. Basarida oturum acilir (router ana ekrana goturur);
/// vazgecilirse login'e donulur.
class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _repeatCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _repeatCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .submitNewPassword(_passwordCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final submitting = auth.submitting;
    final l10n = context.l10n;
    final hata = girisHatasiCoz(l10n, auth.hataKimligi, auth.errorMessage);

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
                    const Icon(Icons.password_outlined, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      l10n.parolaBelirleBaslik,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.parolaBelirleAciklama,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _passwordCtrl,
                      enabled: !submitting,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.ortakYeniParola,
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          // EKRAN OKUYUCU: etiketsiz dugme yalnizca "dugme"
                          // diye okunur (tur 29 surusu yakaladi). Etiket
                          // DURUMA gore degisir ki kullanici ne olacagini
                          // bilsin — ve elbette cevrilidir.
                          tooltip: _obscure
                              ? l10n.ortakParolayiGoster
                              : l10n.ortakParolayiGizle,
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v ?? '').isEmpty
                          ? l10n.ortakParolaZorunlu
                          : parolaHataMetni(l10n, v),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _repeatCtrl,
                      enabled: !submitting,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.ortakYeniParolaTekrar,
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v == _passwordCtrl.text
                          ? null
                          : l10n.ortakParolalarEslesmiyor,
                    ),
                    if (hata != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: hata),
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
                          : Text(l10n.parolaBelirleButon),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: submitting
                          ? null
                          : () => ref
                              .read(authControllerProvider.notifier)
                              .cancelPasswordSetup(),
                      child: Text(l10n.parolaGiriseDon),
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
