import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../announcements/data/announcement_api.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../budget/domain/budget_models.dart' show formatKurusAsTl;
import '../../dues/data/dues_api.dart';
import '../../kargo/data/kargo_api.dart';
import '../../kargo/domain/kargo_models.dart';
import '../../profile/data/profile_api.dart';
import '../../visitors/data/visitor_api.dart';
import '../../weather/data/weather_api.dart';
import '../data/home_repository.dart';
import '../domain/home_varyant.dart';
import '../domain/son_hareketler.dart';
import 'home_mappers.dart';
import 'widgets/bildir_menu_sheet.dart';
import 'widgets/duyuru_karti.dart';
import 'widgets/hizli_erisim.dart';
import 'widgets/home_govde.dart';
import 'widgets/home_header.dart';
import 'widgets/home_shell.dart';
import 'widgets/odeme_karti.dart';
import 'widgets/section_padding.dart';
import 'widgets/son_hareketler_karti.dart';

/// Sakin ana ekrani (referans: site-sakini.jpeg).
///
/// Bolum sirasi gorselle birebir: karsilama → 4x2 hizli erisim izgarasi →
/// Ödeme ve Aidat Durumu → Son Hareketler → Duyurular.
///
/// Veri hatasi ana ekrani DUSURMEZ: gercek uc bos/hatali oldugunda ilgili
/// bolum mock tabani ([HomeRepository]) gosterir, izgara calisir.
class ResidentHomeScreen extends ConsumerWidget {
  const ResidentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mock = ref.watch(homeRepositoryProvider);
    final ad = ref.watch(profileProvider).value?.ad ?? '';
    final now = DateTime.now();

    final hava = ref.watch(weatherProvider).value;
    final units = ref.watch(myDuesProvider).value ?? const [];
    final kargolar = ref.watch(kargoListProvider).value ?? const <Kargo>[];
    final ziyaretciler = ref.watch(visitorsListProvider).value ?? const [];
    final duyurular = ref.watch(sonDuyurularProvider).value ?? const [];

    final toplamBorc = units.fold<int>(
        0, (t, u) => t + (u.bakiyeKurus > 0 ? u.bakiyeKurus : 0));
    final kargoBekleyen =
        kargolar.where((k) => k.durum == KargoDurum.bekliyor).length;

    // Hizli erisim: mock taban + gercek sayaclar (aidat + kargo).
    final erisim = [
      for (final k in mock.hizliErisim(HomeVaryant.sakin))
        switch (k.baslik) {
          'Aidat Bilgileri' when units.isNotEmpty => k.sayacla(
              '₺${formatKurusAsTl(toplamBorc > 0 ? toplamBorc : units.first.tahakkukKurus)}',
              yeniIkinciAltMetin:
                  toplamBorc > 0 ? 'Borç Var' : 'Borç Yok',
            ),
          'Kargolarım' when kargolar.isNotEmpty =>
            k.sayacla('$kargoBekleyen Bekliyor'),
          'Ziyaretçiler' when ziyaretciler.isNotEmpty =>
            k.sayacla('${ziyaretciler.length} Kayıt'),
          _ => k,
        },
    ];

    // Son Hareketler: MISSING-BACKEND birlesik uc yerine sakinin ZATEN
    // erisebildigi kaynaklardan istemcide birlesik akis; bos ise mock taban.
    final gercekHareket = residentHareketleri(
      kargolar: kargolar,
      ziyaretciler: ziyaretciler,
      duesUnits: units,
    );
    final satirlar = gercekHareket.isEmpty
        ? mock.hareketler(HomeVaryant.sakin)
        : hareketSatirlari(gercekHareket, now);

    final odeme = odemeOzeti(units) ?? mock.odeme();
    final duyuru = duyurular.isEmpty
        ? mock.duyuru()
        : duyuruOzeti(duyurular.first, now);
    // Daire/blok bilgisi (gercek) — yoksa referans alt basligi.
    final altBaslik = units.isEmpty
        ? mock.sakinAltBaslik()
        : 'Daire ${units.map((u) => u.no).join(', ')}  •  '
            '${UserRole.resident.label}';

    return HomeShell(
      role: UserRole.resident,
      currentIndex: 0,
      onDestinationSelected: (i) => _onTab(context, i),
      onModul: (rota) => context.push(rota),
      onBildir: () => showBildirMenu(context, girisler: const [
        BildirGiris(
            icon: Icons.rate_review_outlined,
            label: 'Talep / Arıza Bildir',
            route: AppRoutes.complaints),
        BildirGiris(
            icon: Icons.event_available_outlined,
            label: 'Rezervasyon Yap',
            route: AppRoutes.rezervasyon),
      ], onSec: (r) => context.push(r)),
      onProfile: () => context.push(AppRoutes.profile),
      onLogout: () => ref.read(authControllerProvider.notifier).logout(),
      body: HomeGovde(
        header: HomeHeader(
          greetingName: ad,
          subtitle: altBaslik,
          hava: hava == null ? mock.hava() : havaOzeti(hava),
        ),
        bolumler: [
          HomeSectionPad(
            child: HizliErisimIzgarasi(
              kartlar: erisim,
              onSec: (k) => k.rota == null
                  ? _yakinda(context)
                  : context.push(k.rota!),
            ),
          ),
          HomeSectionPad(
            child: OdemeKarti(
              ozet: odeme,
              onGecmis: () => context.push(AppRoutes.myDues),
              onSeeAll: () => context.push(AppRoutes.myDues),
            ),
          ),
          HomeSectionPad(child: SonHareketlerKarti(satirlar: satirlar)),
          HomeSectionPad(
            child: DuyuruKarti(
              duyuru: duyuru,
              onTumu: () => context.push(AppRoutes.announcements),
            ),
          ),
        ],
      ),
    );
  }

  void _yakinda(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Bu bölüm yakında')));
  }

  void _onTab(BuildContext context, int index) {
    switch (index) {
      case 1: // Bildirimler — /notifications RBAC sakine kapali (backend).
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Bildirimler yakında')));
      case 3: // Raporlar — sakin icin seffaflik (aylik anonim ozet).
        context.push(AppRoutes.transparency);
      case 4: // Ayarlar.
        context.push(AppRoutes.settings);
    }
  }
}
