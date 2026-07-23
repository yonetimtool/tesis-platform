import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../../profile/data/profile_api.dart';
import '../../tenant/data/tenant_api.dart';
import '../../tenant/presentation/setup_tenant_screen.dart';
import 'home_screen.dart';
import 'resident_home_screen.dart';

/// `/home` rotasinin kapisi (Onboarding Model A). BIRINCIL yonetici ILK
/// GIRISTE — tesis henuz adlandirilmamissa (`kurulum_tamamlandi=false`) —
/// once [SetupTenantScreen]'i gorur; diger tum durumlarda dogrudan
/// [HomeScreen].
///
/// Yonetici disi roller (sakin/saha) tesis kurulumuyla ilgilenmez → tesis
/// ayarlari hic cekilmez, dogrudan ana ekran.
class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    // R1: sakin yeni tasarim ana ekranini gorur; diger roller (R2/R3'e kadar)
    // eski izgara HomeScreen'de kalir.
    if (role == UserRole.resident) return const ResidentHomeScreen();
    if (role != UserRole.yonetici) return const HomeScreen();

    // Kapi YALNIZ BIRINCIL yoneticiye acilir; digerleri dogrudan ana ekran
    // (tesis adsizsa app-bar'da yer tutucu gorunur — bilincli karar).
    // Profil yuklenirken value null → birincil=false → kisa sure HomeScreen;
    // profil gelince kapi acilir.
    final birincil = ref.watch(profileProvider).value?.birincil ?? false;
    if (!birincil) return const HomeScreen();

    // Birincil yonetici: kurulum durumunu getir. Yukleniyorken kisa bekleme; hata
    // olursa kullaniciyi kilitlemeden ana ekrana gec (kurulum ayarlardan da
    // yapilabilir — burada sadece ILK GIRIS yonlendirmesi var).
    return ref.watch(tenantSettingsProvider).when(
          data: (settings) => settings.kurulumTamamlandi
              ? const HomeScreen()
              : const SetupTenantScreen(),
          error: (_, _) => const HomeScreen(),
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        );
  }
}
