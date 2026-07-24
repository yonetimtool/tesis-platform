import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../../profile/data/profile_api.dart';
import '../../tenant/data/tenant_api.dart';
import '../../tenant/presentation/setup_tenant_screen.dart';
import 'resident_home_screen.dart';
import 'saha_home_screen.dart';
import 'yonetici_home_screen.dart';

/// `/home` rotasinin kapisi (Onboarding Model A). BIRINCIL yonetici ILK
/// GIRISTE — tesis henuz adlandirilmamissa (`kurulum_tamamlandi=false`) —
/// once [SetupTenantScreen]'i gorur; diger tum durumlarda rolun yeni
/// tasarim ana ekrani.
///
/// Yonetici disi roller (sakin/saha) tesis kurulumuyla ilgilenmez → tesis
/// ayarlari hic cekilmez, dogrudan ana ekran.
class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    // Tum bilinen roller yeni tasarim ana ekranlarinda (eski izgara
    // HomeScreen EMEKLI). 'unknown' rol cozulmeden gecen saniye-alti
    // durumdur: yalin bekleme — yanlis kart gostermekten iyidir.
    if (role == UserRole.resident) return const ResidentHomeScreen();
    if (role == UserRole.security || role == UserRole.tesisGorevlisi) {
      return SahaHomeScreen(role: role);
    }
    // Platform admini yonetim duzenini gorur (brief: admin→yönetici varyanti).
    if (role == UserRole.admin) {
      return const YoneticiHomeScreen(role: UserRole.admin);
    }
    if (role != UserRole.yonetici) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Kapi YALNIZ BIRINCIL yoneticiye acilir; digerleri dogrudan ana ekran
    // (tesis adsizsa app-bar'da yer tutucu gorunur — bilincli karar).
    // Profil yuklenirken value null → birincil=false → kisa sure ana ekran;
    // profil gelince kapi acilir.
    final birincil = ref.watch(profileProvider).value?.birincil ?? false;
    if (!birincil) return const YoneticiHomeScreen();

    // Birincil yonetici: kurulum durumunu getir. Yukleniyorken kisa bekleme; hata
    // olursa kullaniciyi kilitlemeden ana ekrana gec (kurulum ayarlardan da
    // yapilabilir — burada sadece ILK GIRIS yonlendirmesi var).
    return ref.watch(tenantSettingsProvider).when(
          data: (settings) => settings.kurulumTamamlandi
              ? const YoneticiHomeScreen()
              : const SetupTenantScreen(),
          error: (_, _) => const YoneticiHomeScreen(),
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        );
  }
}
