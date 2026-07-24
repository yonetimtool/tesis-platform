import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import 'widgets/bildir_menu_sheet.dart';
import '../../notifications/data/notifications_controller.dart';
import '../../profile/data/profile_api.dart';
import '../../scan/data/scan_outbox.dart';
import '../../cameras/data/cameras_api.dart';
import '../../cameras/presentation/canli_kamera_section.dart';
import '../../shifts/data/shifts_api.dart';
import '../../shifts/presentation/vardiya_section.dart';
import '../../weather/data/weather_api.dart';
import '../../weather/domain/weather_models.dart';
import '../domain/home_menu.dart';
import 'module_card_spec.dart';
import 'role_home_body.dart';
import 'widgets/home_header.dart';
import 'widgets/home_shell.dart';
import 'widgets/yakinda_section.dart';

const _purple = Color(0xFF7C3AED);
const _red = Color(0xFFDC2626);

/// Saha ana ekrani (R3, gorevli.jpeg) — guvenlik + tesis gorevlisi TEK
/// rol-parametrik ekranda: alt-baslik rol etiketi, "Yakında" kart seti role
/// gore. tesis_gorevlisi KVKK geregi Ziyaretci/Kargo/Kamera/Plaka GORMEZ
/// (gercek kartlar home_menu'de zaten yok; "yakında" setine de konmaz).
/// Outbox bekleyen sayisi kartta sayac olarak gorunur (eski ekran rozetinin
/// karsiligi — cevrimdisi saha kaniti kaybolmasin).
class SahaHomeScreen extends ConsumerWidget {
  const SahaHomeScreen({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ad = ref.watch(profileProvider).value?.ad ?? '';
    final pending = ref.watch(scanOutboxProvider).pendingCount;
    // /notifications RBAC: security izinli, tesis_gorevlisi DEGIL — izinsiz
    // rolde provider hic izlenmez (401 uretecek istek atilmaz), rozet yok.
    final bildirimliRol = role == UserRole.security;
    final unread = bildirimliRol
        ? ref.watch(unreadNotificationCountProvider).value ?? 0
        : 0;
    // Vardiya Durumu — GERCEK /shifts verisi (iki saha rolu de RBAC-izinli).
    // Hata/yukleme → bolum sessizce gizli (VardiyaSection bos listede hic
    // cizilmez).
    final vardiyalar = ref.watch(shiftsProvider).value ?? const [];
    // Baslik hava blogu — veri gelince gorunur; yukleme/hatada SESSIZCE gizli.
    final hava = ref.watch(weatherProvider).maybeWhen(
          data: (w) => HomeWeather(
            tempLabel: w.tempLabel,
            city: w.konumAd,
            icon: weatherIcon(w.durum),
          ),
          orElse: () => null,
        );

    return HomeShell(
      role: role,
      currentIndex: 0,
      unreadCount: unread,
      onDestinationSelected: (i) => _onTab(context, i),
      // WP2.4: merkez FAB rol-bazli olusturma menusu acar.
      onBildir: () => showBildirMenu(context, girisler: [
        const BildirGiris(icon: Icons.rate_review_outlined,
            label: 'Olay Bildir', route: AppRoutes.complaints),
        const BildirGiris(icon: Icons.task_alt,
            label: 'Görevlerim', route: AppRoutes.tasks),
        if (role == UserRole.security)
          const BildirGiris(icon: Icons.directions_walk,
              label: 'Turlarım', route: AppRoutes.patrol),
      ], onSec: (r) => context.push(r)),
      onProfile: () => context.push(AppRoutes.profile),
      onLogout: () =>
          ref.read(authControllerProvider.notifier).logout(),
      body: RoleHomeBody(
        role: role,
        greetingName: ad,
        subtitle: role.label,
        weather: hava,
        onOpen: (entry) => context.push(moduleCardSpec(entry).route),
        counters: {
          if (pending > 0) HomeMenuEntry.outbox: '$pending bekleyen',
        },
        sections: [
          if (vardiyalar.isNotEmpty) ...[
            const SizedBox(height: 12),
            VardiyaSection(
              vardiyalar: vardiyalar,
              now: DateTime.now(),
              onSeeAll: () => context.push(AppRoutes.vardiyalar),
            ),
          ],
          // WP-F: Canlı Kamera seridi YALNIZ security'de (tesis_gorevlisi KVKK
          // geregi kamera gormez). Hata/bos → bolum sessizce gizli.
          if (role == UserRole.security) ...[
            const SizedBox(height: 12),
            ref.watch(camerasProvider).maybeWhen(
                  data: (list) => CanliKameraSection(
                    kameralar: list,
                    onIzle: (c) =>
                        context.push(AppRoutes.kameraIzle, extra: c),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
          ],
          const SizedBox(height: 12),
          // MISSING-BACKEND kartlari yalniz security'de (tesis_gorevlisi KVKK
          // geregi Plaka gormez; bos liste → izgara hic cizilmez). Canlı Kamera
          // artik gercek serit (yukarida) — Yakında'dan kaldirildi.
          YakindaSection(kartlar: [
            if (role == UserRole.security) ...const [
              YakindaKart(
                  icon: Icons.directions_car_outlined,
                  title: 'Araç Plaka',
                  accent: _purple),
              YakindaKart(
                  icon: Icons.error_outline, title: 'İhlaller', accent: _red),
            ],
          ]),
        ],
      ),
    );
  }

  void _onTab(BuildContext context, int index) {
    switch (index) {
      case 1: // Bildirimler: security inbox'a gider; tesis gorevlisi RBAC
        // disi — durust mesaj (sahte bos ekran degil).
        if (role == UserRole.security) {
          context.push(AppRoutes.notifications);
        } else {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                  content: Text('Bildirimler bu rolde kullanılamıyor')),
            );
        }
      case 3: // Raporlar — saha rollerine acik rapor ucu yok (RBAC yonetici).
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Raporlar yakında')),
          );
      case 4: // Ayarlar.
        context.push(AppRoutes.settings);
    }
  }
}
