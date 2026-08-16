import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/current_user_provider.dart';
import '../../auth/domain/user_role.dart';
import '../../kvkk/data/kvkk_api.dart';
import '../../kvkk/presentation/kvkk_onay_screen.dart';
import '../../profile/data/profile_api.dart';
import '../../tenant/data/tenant_api.dart';
import '../../tenant/presentation/setup_tenant_screen.dart';
import '../../../routing/splash_screen.dart';
import '../../kurulum/presentation/kurulum_hatirlatici.dart';
import 'denetci_yonlendirme_screen.dart';
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
    // (P36) KVKK KAPISI ROL AYRIMINDAN ONCE: aydinlatma metni HERKES icindir
    // ve onay verilmeden hicbir ana ekran gosterilmez. Kapi yalniz tenant
    // metin YAYINLADIYSA kurulur; ag/uc hatasinda ACILMAZ (bkz.
    // KvkkDurum.kapaliVarsayilan) — metni getiremeyen bir ekranda
    // kullaniciyi kilitlemek, onu uygulamadan tamamen dislamak olurdu.
    final kvkk = ref.watch(kvkkDurumProvider).value;
    if (kvkk != null && kvkk.onayGerekli) return const KvkkOnayScreen();

    final role = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
    // Tum bilinen roller yeni tasarim ana ekranlarinda (eski izgara
    // HomeScreen EMEKLI). 'unknown' rol cozulmeden gecen saniye-alti
    // durumdur: yalin bekleme — yanlis kart gostermekten iyidir.
    if (role == UserRole.resident) return const ResidentHomeScreen();
    if (role == UserRole.security || role == UserRole.tesisGorevlisi) {
      return SahaHomeScreen(role: role);
    }
    // (P35 duzeltmesi) Guvenlik amiri de SAHA duzeni gorur. Bu dal
    // eklenmeseydi amir asagidaki `role != yonetici` dalina duser ve
    // SPLASH ekraninda KILITLI kalirdi — `homeVaryantForRole` dogru
    // varyanti soyluyordu ama HomeGate onu kullanmiyor.
    if (role == UserRole.guvenlikAmiri) {
      return SahaHomeScreen(role: role);
    }
    // Platform admini yonetim duzenini gorur (brief: admin→yönetici varyanti).
    if (role == UserRole.admin) {
      return const KurulumHatirlatici(
        child: YoneticiHomeScreen(role: UserRole.admin),
      );
    }
    // (P139.2) DENETCI ACIK UCTA KALIYORDU. Bu dal `denetci`yi de yutuyor
    // ve rol cozulmus olmasina ragmen ekran KALICI olarak splash'ta
    // kaliyordu — cikisi olmayan bir bekleme.
    //
    // P128/P129 notu "ekran, giris yapan denetciye web adresini soyler
    // (home_gate)" diyordu; KOD BUNU YAPMIYORDU. Karar dogruydu, uygulamasi
    // eksikti: denetimin isi masabasi isidir ve mobil onun yuzeyi degil —
    // ama bunu SOYLEMEK gerekir, sonsuz bir acilis ekrani gostermek degil.
    if (role == UserRole.denetci) {
      return const DenetciYonlendirmeScreen();
    }
    // Kalan tek durum `unknown`: rol cozulmeden gecen saniye-alti an.
    if (role != UserRole.yonetici) {
      return const SplashScreen();
    }

    // Kapi YALNIZ BIRINCIL yoneticiye acilir; digerleri dogrudan ana ekran
    // (tesis adsizsa app-bar'da yer tutucu gorunur — bilincli karar).
    // Profil yuklenirken value null → birincil=false → kisa sure ana ekran;
    // profil gelince kapi acilir.
    final birincil = ref.watch(profileProvider).value?.birincil ?? false;
    if (!birincil) {
      return const KurulumHatirlatici(child: YoneticiHomeScreen());
    }

    // Birincil yonetici: kurulum durumunu getir. Kapi ZAMAN SINIRLIDIR
    // (bkz. kurulumKapisiProvider) — yavas/hatali uc kullaniciyi giris
    // sonrasinda bos bir ekranda TUTAMAZ; bilinmiyorsa ana ekran gosterilir.
    // Kisa bekleme markali acilis ekraniyla yapilir (bos beyaz ekran degil).
    // (P140.3) SPLASH REGRESYONUNUN KOK NEDENI — OLCULDU VE COZULDU.
    //
    // ZINCIR: ana ekrana donus (`RouteAware.didPopNext` — diyalog kapanisi
    // dahil) TAM YENILEME tetikler -> `home_refresh` `tenantSettings`i
    // invalidate eder -> `kurulumKapisiProvider` ONU watch ettigi icin
    // yeniden yuklenir -> `when` LOADING dalini kosar -> SplashScreen.
    //
    // OLCUM (gercek `ProviderContainer` ile, elle kurulmus AsyncValue ile
    // DEGIL):
    //     invalidate sonrasi: isLoading=true, hasValue=true
    //     when(...)              -> "SPLASH"
    //     when(skipLoadingOnReload: true) -> "ekran"
    //
    // P139'DA BU DUZELTMEYI YAZIP SONRA GERI ALMISTIM ve geri alma
    // YANLISTI: o turdaki "curutme" olcumu `AsyncLoading().copyWithPrevious(
    // AsyncData(...))` ile ELLE kurulmus bir deger uzerindeydi ve gercek
    // yeniden-yukleme durumunu temsil etmiyordu. Ders: bir hipotezi
    // curutmek icin kullanilan olcum de en az hipotez kadar dikkatli
    // kurulmali.
    //
    // Kapinin karari SOGUK ACILISA aittir ("tesis kurulmus mu?"); cevap
    // bir kez bilindikten sonra bir YENILEME kullaniciyi splash'a atmaz.
    // ILK yuklemede (deger henuz yok) splash yine gosterilir.
    return ref.watch(kurulumKapisiProvider).when(
          skipLoadingOnReload: true,
          // (P166 §8.2) HATIRLATICI TESIS ADLANDIRMASINDAN SONRA.
          // `SetupTenantScreen` zaten bir kurulum adimidir; onun ustune
          // ikinci bir kurulum diyalogu bindirmek, kullaniciyi ayni anda
          // iki ise cagirmakti.
          data: (kurulumGerekli) => kurulumGerekli
              ? const SetupTenantScreen()
              : const KurulumHatirlatici(child: YoneticiHomeScreen()),
          error: (_, _) => const KurulumHatirlatici(child: YoneticiHomeScreen()),
          loading: () => const SplashScreen(),
        );
  }
}
