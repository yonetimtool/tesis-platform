import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../data/tenant_api.dart';

/// Yoneticinin ILK GIRISTE tesisini adlandirdigi kurulum ekrani (Onboarding
/// Model A). Admin tesisi isimsiz acar; burada girilen ad `POST /tenant/setup`
/// ile kaydedilir ve `kurulum_tamamlandi=true` olur. Basarida [tenantSettingsProvider]
/// tazelenir → home gate ana ekrani gosterir.
class SetupTenantScreen extends ConsumerStatefulWidget {
  const SetupTenantScreen({super.key});

  @override
  ConsumerState<SetupTenantScreen> createState() => _SetupTenantScreenState();
}

class _SetupTenantScreenState extends ConsumerState<SetupTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adCtrl = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _adCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(tenantApiProvider).setup(_adCtrl.text.trim());
      // Ayarlar tazelenince home gate kurulum_tamamlandi=true gorup ana
      // ekrani acar; ayni oturum, yonlendirmeye gerek yok.
      ref.invalidate(tenantSettingsProvider);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _errorMessage = 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    const Icon(Icons.apartment_outlined, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Tesisinizi tanımlayın',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Yönetici olarak ilk girişinizi yaptınız. Devam etmek için '
                      'sitenizin/tesisinizin adını girin. Bu adı daha sonra '
                      'ayarlardan değiştirebilirsiniz.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _adCtrl,
                      enabled: !_submitting,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.words,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Tesis adı',
                        hintText: 'Örn. Örnek Sitesi',
                        prefixIcon: Icon(Icons.business_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.length < 2) return 'Tesis adı en az 2 karakter olmalı';
                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: _errorMessage!),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const Text('Tesisi oluştur'),
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
