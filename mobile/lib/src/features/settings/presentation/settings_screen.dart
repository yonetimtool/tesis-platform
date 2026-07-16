import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/text/tr_upper.dart';
import '../../../core/theme/theme_controller.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../../tenant/data/tenant_api.dart';

/// Ayarlar — kullanici tercihleri (tema modu) + yonetici'ye ozel tesis
/// adlandirmasi. Tema secimi kalicidir ([ThemeModeController] guvenli depoya
/// yazar).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final role = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    return Scaffold(
      appBar: AppBar(title: Text(trUpper('Ayarlar'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tesis adini YALNIZ yonetici degistirir (backend RBAC zorlar).
          if (role == UserRole.yonetici) ...[
            Text('Tesis', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const _TesisAdiKarti(),
            const SizedBox(height: 24),
          ],
          Text('Görünüm',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tema',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Sistem: cihaz ayarını izler. Açık/Koyu: elle seçim.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_outlined),
                          label: Text('Sistem'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('Açık'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('Koyu'),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) =>
                          ref.read(themeModeProvider.notifier).set(s.first),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tesis adi karti (yonetici) — `PATCH /tenant/settings {ad}`. Kaydedince
/// [tenantSettingsProvider] tazelenir → ana ekran app-bar'i guncellenir.
/// slug DEGISMEZ.
class _TesisAdiKarti extends ConsumerStatefulWidget {
  const _TesisAdiKarti();

  @override
  ConsumerState<_TesisAdiKarti> createState() => _TesisAdiKartiState();
}

class _TesisAdiKartiState extends ConsumerState<_TesisAdiKarti> {
  /// Sunucu-tarafi yer tutucu — kullaniciya gosterilmez, alan bos baslar.
  static const _placeholder = '(Kurulum bekliyor)';

  late final TextEditingController _adCtrl = TextEditingController(
    text: () {
      final ad = ref.read(tenantSettingsProvider).value?.ad ?? '';
      return ad == _placeholder ? '' : ad;
    }(),
  );
  bool _submitting = false;

  @override
  void dispose() {
    _adCtrl.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    FocusScope.of(context).unfocus();
    final ad = _adCtrl.text.trim();
    if (ad.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref.read(tenantApiProvider).updateAd(ad);
      ref.invalidate(tenantSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tesis adı güncellendi')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.'),
          ),
        );
      }
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tesis adı',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Ana ekranın başlığında görünür; tüm kullanıcılar bu adı görür.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _adCtrl,
              enabled: !_submitting,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _kaydet(),
              decoration: const InputDecoration(
                hintText: 'Örn. Örnek Sitesi',
                prefixIcon: Icon(Icons.business_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: (_submitting || _adCtrl.text.trim().isEmpty)
                    ? null
                    : _kaydet,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
