import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../announcements/data/announcement_api.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import 'widgets/bildir_menu_sheet.dart';
import '../../budget/domain/budget_models.dart' show formatKurusAsTl;
import '../../dues/data/dues_api.dart';
import '../../kargo/data/kargo_api.dart';
import '../../kargo/domain/kargo_models.dart';
import '../../profile/data/profile_api.dart';
import '../../visitors/data/visitor_api.dart';
import '../../weather/data/weather_api.dart';
import '../../weather/domain/weather_models.dart';
import '../domain/home_menu.dart';
import '../domain/son_hareketler.dart';
import 'aidat_ozet_karti.dart';
import 'duyurular_karti.dart';
import 'module_card_spec.dart';
import 'role_home_body.dart';
import 'son_hareketler_section.dart';
import 'widgets/home_header.dart';
import 'widgets/home_shell.dart';

/// Sakin ana ekrani (R1 + R1.1) — [HomeShell] + [RoleHomeBody] birlestirir,
/// provider'lari ve gezinmeyi baglar. R1.1 zenginlestirme: "Ödeme ve Aidat
/// Durumu" karti (/me/dues) + Aidatım ve Kargo kart sayaclari. Veri hatasi
/// ana ekrani DUSURMEZ: kart/sayac sessizce gizlenir, izgara calisir.
/// Ziyaretci "bekliyor" sayaci YOK — veri modelinde durum alani yok
/// (bilgilendirme akisi, onay yok).
class ResidentHomeScreen extends ConsumerWidget {
  const ResidentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ad = ref.watch(profileProvider).value?.ad ?? '';
    final units = ref.watch(myDuesProvider).value ?? const [];
    final kargolar = ref.watch(kargoListProvider).value ?? const <Kargo>[];
    final ziyaretciler = ref.watch(visitorsListProvider).value ?? const [];
    final duyurular = ref.watch(sonDuyurularProvider).value ?? const [];
    // Baslik hava blogu — veri gelince gorunur; yukleme/hatada SESSIZCE gizli.
    final hava = ref.watch(weatherProvider).maybeWhen(
          data: (w) => HomeWeather(
            tempLabel: w.tempLabel,
            city: w.konumAd,
            icon: weatherIcon(w.durum),
          ),
          orElse: () => null,
        );

    final toplamBorc = units.fold<int>(
        0, (t, u) => t + (u.bakiyeKurus > 0 ? u.bakiyeKurus : 0));
    final kargoBekleyen =
        kargolar.where((k) => k.durum == KargoDurum.bekliyor).length;
    // Son Hareketler: ayni fetch'lerden istemcide birlesik akis (MISSING-
    // BACKEND birlesik uc yerine); now yalniz etiket icin.
    final hareketler = residentHareketleri(
      kargolar: kargolar,
      ziyaretciler: ziyaretciler,
      duesUnits: units,
    );
    final now = DateTime.now();

    return HomeShell(
      role: UserRole.resident,
      currentIndex: 0,
      onDestinationSelected: (i) => _onTab(context, i),
      // WP2.4: merkez FAB rol-bazli olusturma menusu acar.
      onBildir: () => showBildirMenu(context, girisler: const [
        BildirGiris(icon: Icons.rate_review_outlined,
            label: 'Talep / Arıza Bildir', route: AppRoutes.complaints),
        BildirGiris(icon: Icons.event_available_outlined,
            label: 'Rezervasyon Yap', route: AppRoutes.rezervasyon),
      ], onSec: (r) => context.push(r)),
      onProfile: () => context.push(AppRoutes.profile),
      onLogout: () =>
          ref.read(authControllerProvider.notifier).logout(),
      body: RoleHomeBody(
        role: UserRole.resident,
        greetingName: ad,
        subtitle: UserRole.resident.label,
        weather: hava,
        onOpen: (entry) => context.push(moduleCardSpec(entry).route),
        counters: {
          if (units.isNotEmpty)
            HomeMenuEntry.myDues: toplamBorc > 0
                ? '₺${formatKurusAsTl(toplamBorc)} borç'
                : 'Borç Yok',
          if (kargoBekleyen > 0)
            HomeMenuEntry.kargo: '$kargoBekleyen Bekliyor',
        },
        sections: [
          if (units.isNotEmpty) ...[
            const SizedBox(height: 12),
            AidatOzetKarti(
              units: units,
              onDetay: () => context.push(AppRoutes.myDues),
            ),
          ],
          if (hareketler.isNotEmpty) ...[
            const SizedBox(height: 12),
            SonHareketlerSection(hareketler: hareketler, now: now),
          ],
          if (duyurular.isNotEmpty) ...[
            const SizedBox(height: 12),
            DuyurularKarti(
              duyurular: duyurular,
              now: now,
              onTumu: () => context.push(AppRoutes.announcements),
            ),
          ],
        ],
      ),
    );
  }

  void _onTab(BuildContext context, int index) {
    switch (index) {
      case 1: // Bildirimler — /notifications RBAC sakine kapali (backend).
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Bildirimler yakında')),
          );
      case 3: // Raporlar — sakin icin seffaflik (aylik anonim ozet).
        context.push(AppRoutes.transparency);
      case 4: // Ayarlar.
        context.push(AppRoutes.settings);
    }
  }
}
