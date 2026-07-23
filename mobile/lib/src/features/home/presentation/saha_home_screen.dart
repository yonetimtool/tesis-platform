import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../auth/domain/user_role.dart';
import '../../notifications/data/notifications_controller.dart';
import '../../profile/data/profile_api.dart';
import '../../scan/data/scan_outbox.dart';
import '../../shifts/data/shifts_api.dart';
import '../../shifts/presentation/vardiya_section.dart';
import '../domain/home_menu.dart';
import 'module_card_spec.dart';
import 'role_home_body.dart';
import 'widgets/home_shell.dart';
import 'widgets/module_card.dart';
import 'widgets/section_header.dart';

const _purple = Color(0xFF7C3AED);
const _red = Color(0xFFDC2626);
const _navy = Color(0xFF0E3C91);

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

    return HomeShell(
      role: role,
      currentIndex: 0,
      unreadCount: unread,
      onDestinationSelected: (i) => _onTab(context, i),
      onBildir: () => context.push(AppRoutes.complaints),
      onProfile: () => context.push(AppRoutes.profile),
      body: RoleHomeBody(
        role: role,
        greetingName: ad,
        subtitle: role.label,
        onOpen: (entry) => context.push(moduleCardSpec(entry).route),
        counters: {
          if (pending > 0) HomeMenuEntry.outbox: '$pending bekleyen',
        },
        sections: [
          if (vardiyalar.isNotEmpty) ...[
            const SizedBox(height: 12),
            VardiyaSection(vardiyalar: vardiyalar, now: DateTime.now()),
          ],
          const SizedBox(height: 12),
          _YakindaSection(role: role),
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

/// MISSING-BACKEND referans kartlari — pasif "Yakında" izgarasi. Vardiya
/// Durumu ARTIK GERCEK bolum ([VardiyaSection]); kalanlar yalniz security'de
/// (Plaka/İhlaller/Kamera). Kart kalmazsa (tesis_gorevlisi) izgara HIC
/// cizilmez.
class _YakindaSection extends StatelessWidget {
  const _YakindaSection({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final cards = <ModuleCard>[
      if (role == UserRole.security) ...const [
        ModuleCard(
          icon: Icons.directions_car_outlined,
          title: 'Araç Plaka',
          accent: _purple,
          comingSoon: true,
        ),
        ModuleCard(
          icon: Icons.error_outline,
          title: 'İhlaller',
          accent: _red,
          comingSoon: true,
        ),
        ModuleCard(
          icon: Icons.videocam_outlined,
          title: 'Canlı Kamera',
          accent: _navy,
          comingSoon: true,
        ),
      ],
    ];
    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Yakında Eklenecekler'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: cards,
        ),
      ],
    );
  }
}
