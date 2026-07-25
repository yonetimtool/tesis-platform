import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/text/tr_upper.dart';
import '../../../core/theme/home_tokens.dart';
import '../../../routing/app_router.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../data/cameras_api.dart';
import '../domain/camera_models.dart';
import 'camera_player_screen.dart';
import 'kamera_form_sheet.dart';
import 'kamera_karti.dart';

/// Kameralar ekrani — 2'li IZGARA (ana ekran kart diliyle ayni).
///
/// Rol farki YALNIZ yonetimde: admin/yonetici ekler/duzenler/siler. LISTE
/// icin istemci hicbir suzgec uygulamaz — `GET /cameras` sunucuda rol'e gore
/// suzuludur, sakin/tesis gorevlisi zaten yalniz kendisine acilan kameralari
/// alir. Dokunma: oynatilabilir → oynatici, RTSP → bilgi karti.
class KameralarScreen extends ConsumerWidget {
  const KameralarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camerasAsync = ref.watch(camerasProvider);
    final role = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    final yonetebilir = role == UserRole.admin || role == UserRole.yonetici;

    return Scaffold(
      appBar: AppBar(title: Text(trUpper('Kameralar'))),
      floatingActionButton: yonetebilir
          ? FloatingActionButton.extended(
              onPressed: () => KameraFormSheet.ac(context),
              icon: const Icon(Icons.add),
              label: const Text('Kamera Ekle'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(camerasProvider),
        child: camerasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                e is ApiException ? e.message : 'Kameralar yüklenemedi.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          data: (kameralar) {
            if (kameralar.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    yonetebilir
                        ? 'Kamera tanımı yok. Sağ alttan ekleyebilirsiniz.'
                        : 'Görüntülemenize açık kamera yok.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: HomeTokens.gridGap,
                crossAxisSpacing: HomeTokens.gridGap,
                // 16:10 gorsel + ad + konum + durum + yonetim satiri.
                childAspectRatio: 0.78,
              ),
              itemCount: kameralar.length,
              itemBuilder: (context, i) {
                final k = kameralar[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: KameraKarti(
                        kamera: k,
                        onTap: () => kameraAc(context, k),
                      ),
                    ),
                    if (yonetebilir)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!k.aktif)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.pause_circle_outline, size: 16),
                            ),
                          if (k.sakinGorebilir)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.groups_outlined, size: 16),
                            ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Düzenle',
                            onPressed: () =>
                                KameraFormSheet.ac(context, mevcut: k),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            tooltip: 'Sil',
                            onPressed: () => _sil(context, ref, k),
                          ),
                        ],
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _sil(BuildContext context, WidgetRef ref, Camera k) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kamerayı sil'),
        content: Text('"${k.ad}" silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (onay != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(camerasApiProvider).delete(k.id);
      ref.invalidate(camerasProvider);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Kamera dokunmasinin TEK kurali (serit + izgara ayni davranir):
/// `oynatilabilir` → tam ekran oynatici; RTSP → bilgi karti.
void kameraAc(BuildContext context, Camera kamera) {
  if (kamera.oynatilabilir) {
    context.push(AppRoutes.kameraIzle, extra: kamera);
  } else {
    CameraBilgiSheet.ac(context, kamera);
  }
}
