import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/branding/yonetio_logo.dart';
import '../../../core/i18n/l10n.dart';
import '../data/auth_repository_impl.dart';
import 'auth_controller.dart';
import 'giris_hata_metni.dart';
import '../../../core/ui/telefon_alani.dart';
import '../../../core/ui/telefon_hata_metni.dart';

/// Telefonla giris ekrani (contracts/auth.md §1): cep telefonu (global
/// benzersiz) + parola/gecici kod. Tenant numaradan otomatik cozulur — tesis
/// kodu/e-posta/daire no ISTENMEZ. Ilk giriste gecici parola girilince parola
/// belirleme ekranina gecilir.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _prefillSavedCredentials();
  }

  /// "Beni hatirla" ile saklanmis giris bilgileri varsa alanlari ON-DOLDURUR
  /// (uygulama yeniden acilisinda VE cikis sonrasi). Yoksa alanlar bos kalir.
  Future<void> _prefillSavedCredentials() async {
    final saved = await ref.read(authRepositoryProvider).readSavedCredentials();
    if (saved == null || !mounted) return;
    setState(() {
      _phoneCtrl.text = saved.phone;
      _passwordCtrl.text = saved.password;
      _rememberMe = true;
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).loginPhone(
          phone: telefonNormalle(_phoneCtrl.text),
          password: _passwordCtrl.text,
          rememberMe: _rememberMe,
        );
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
                    const Center(child: YonetioLogoVertical(iconSize: 100)),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _phoneCtrl,
                      enabled: !submitting,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.phone,
                      // (P123) TEK bicimlendirici: gruplar, rakam disini
                      // yutar, uzunlugu SERT sinirlar, yapistirmayi cozer.
                      inputFormatters: const [TelefonBicimlendirici()],
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l10n.ortakCepTelefonu,
                        hintText: l10n.ortakTelefonIpucu,
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => telefonHataMetni(l10n, v ?? ''),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      enabled: !submitting,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.girisParolaVeyaKod,
                        helperText: l10n.girisIlkKodIpucu,
                        helperMaxLines: 2,
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
                      validator: (v) =>
                          (v ?? '').isEmpty ? l10n.ortakParolaZorunlu : null,
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
                      title: Text(l10n.girisBeniHatirla),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
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
                          : Text(l10n.girisYap),
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
