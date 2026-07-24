import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cameras/data/cameras_api.dart';
import '../../cameras/domain/camera_models.dart';
import '../../kargo/data/kargo_api.dart';
import '../../kargo/domain/kargo_models.dart';
import '../../notifications/data/notifications_controller.dart';
import '../../../core/theme/home_tokens.dart';
import '../../profile/data/profile_api.dart';
import '../../scan/data/scan_outbox.dart';
import '../../shifts/data/shifts_api.dart';
import '../../tenant/data/tenant_api.dart';
import '../../weather/data/weather_api.dart';
import '../../yonetici_iletisim/data/yonetici_iletisim_api.dart';
import '../data/home_repository.dart';
import '../domain/home_varyant.dart';
import '../domain/home_view_models.dart';
import 'home_mappers.dart';
import 'widgets/bildir_menu_sheet.dart';
import 'widgets/hizli_erisim.dart';
import 'widgets/home_govde.dart';
import 'widgets/home_header.dart';
import 'widgets/home_shell.dart';
import 'widgets/kamera_seridi.dart';
import 'widgets/section_padding.dart';
import 'widgets/son_hareketler_karti.dart';
import 'widgets/vardiya_seridi.dart';

/// Gorevli ana ekrani (referans: gorevli.jpeg) — guvenlik + tesis gorevlisi
/// TEK rol-parametrik ekranda.
///
/// Bolum sirasi gorselle birebir: karsilama → yatay hizli erisim seridi →
/// Vardiya Durumu → Son Hareketler → Canlı Kamera.
///
/// KVKK: tesis_gorevlisi ziyaretci/kargo/plaka/kamera GORMEZ — o kartlar ve
/// kamera seridi bu rolde cizilmez (backend RBAC de 403 doner).
class SahaHomeScreen extends ConsumerWidget {
  const SahaHomeScreen({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mock = ref.watch(homeRepositoryProvider);
    final ad = ref.watch(profileProvider).value?.ad ?? '';
    final guvenlik = role == UserRole.security;
    final now = DateTime.now();

    // /notifications RBAC: security izinli, tesis_gorevlisi DEGIL — izinsiz
    // rolde provider hic izlenmez (401 uretecek istek atilmaz), rozet yok.
    final unread =
        guvenlik ? ref.watch(unreadNotificationCountProvider).value ?? 0 : 0;

    // ---- gercek veri; yoksa mock taban -----------------------------------
    final hava = ref.watch(weatherProvider).value;
    final tesisAd = ref.watch(tenantSettingsProvider).value?.ad;
    final vardiyalar = ref.watch(shiftsProvider).value ?? const [];
    final kargolar = guvenlik
        ? ref.watch(kargoListProvider).value ?? const <Kargo>[]
        : const <Kargo>[];
    // Vardiya seridinin son karti tenant yoneticisidir (referans gorsel).
    // /yonetici-iletisim saha rollerine aciktir; hata/bos → mock ad.
    final yoneticiler =
        ref.watch(yoneticiIletisimProvider).value?.yoneticiler ?? const [];

    final vardiyaKartlar = vardiyalar.isEmpty
        ? mock.vardiyalar()
        : vardiyaKartlari(
            vardiyalar: vardiyalar,
            now: now,
            yoneticiAd: yoneticiler.isNotEmpty
                ? yoneticiler.first.adSoyad
                : mock.yoneticiAd(),
          );

    // Hizli erisim: mock taban + elde GERCEK verisi olan sayaclar. Karsiligi
    // olmayan kartlar (Araç Plaka, İhlaller) mock degerde kalir.
    final kargoBekleyen =
        kargolar.where((k) => k.durum == KargoDurum.bekliyor).length;
    final aktifVardiya = vardiyalar.where((v) => v.aktifMi(now)).length;
    final pending = ref.watch(scanOutboxProvider).pendingCount;
    final erisim = [
      for (final k in mock.hizliErisim(HomeVaryant.gorevli))
        if (_gorunur(k, guvenlik))
          switch (k.baslik) {
            'Vardiya Durum' when vardiyalar.isNotEmpty =>
              k.sayacla('$aktifVardiya Aktif'),
            'Kargo' when kargolar.isNotEmpty =>
              k.sayacla('$kargoBekleyen Bekliyor'),
            _ => k,
          },
      // Cevrimdisi saha kaniti kaybolmasin: bekleyen okutma VARSA seride
      // ek bir kart girer. pending=0 iken (normal durum) serit referans
      // gorselle birebir 5 karttir — bu kart yalniz sorun varken belirir.
      if (pending > 0)
        HizliErisimKart(
          ikon: Icons.outbox_outlined,
          baslik: 'Gönderim Kuyruğu',
          accent: HomeTokens.orange,
          altMetin: '$pending bekleyen',
          rota: AppRoutes.outbox,
        ),
    ];

    final kameralar = guvenlik
        ? (ref.watch(camerasProvider).value ?? const <Camera>[])
        : const <Camera>[];
    final kameraKartlar = !guvenlik
        ? const <KameraOzeti>[]
        : (kameralar.isEmpty ? mock.kameralar() : kameraOzetleri(kameralar));

    return HomeShell(
      role: role,
      currentIndex: 0,
      unreadCount: unread,
      onDestinationSelected: (i) => _onTab(context, i),
      onModul: (rota) => context.push(rota),
      onBildir: () => showBildirMenu(context, girisler: [
        const BildirGiris(
            icon: Icons.rate_review_outlined,
            label: 'Olay Bildir',
            route: AppRoutes.complaints),
        const BildirGiris(
            icon: Icons.task_alt, label: 'Görevlerim', route: AppRoutes.tasks),
        if (guvenlik)
          const BildirGiris(
              icon: Icons.directions_walk,
              label: 'Turlarım',
              route: AppRoutes.patrol),
      ], onSec: (r) => context.push(r)),
      onProfile: () => context.push(AppRoutes.profile),
      onLogout: () => ref.read(authControllerProvider.notifier).logout(),
      body: HomeGovde(
        header: HomeHeader(
          greetingName: ad,
          // Referans: tesis secici gorunumu ("Mavi Residence ⌄").
          subtitle: (tesisAd == null || tesisAd.isEmpty) ? mock.tesisAd() : tesisAd,
          altBaslikStili: HomeAltBaslikStili.tesisSecici,
          hava: hava == null ? mock.hava() : havaOzeti(hava),
        ),
        bolumler: [
          HizliErisimSeridi(kartlar: erisim, onSec: (k) => _ac(context, k)),
          VardiyaSeridi(
            kartlar: vardiyaKartlar,
            onSeeAll: () => context.push(AppRoutes.vardiyalar),
          ),
          HomeSectionPad(
            child: SonHareketlerKarti(
              // MISSING-BACKEND: birlesik saha aktivite ucu yok — referans
              // satirlar (README "TODO: gerçek uç").
              satirlar: mock.hareketler(HomeVaryant.gorevli),
              onSeeAll:
                  guvenlik ? () => context.push(AppRoutes.notifications) : null,
            ),
          ),
          if (kameraKartlar.isNotEmpty)
            KameraSeridi(
              kameralar: kameraKartlar,
              onSeeAll: () => context.push(AppRoutes.kameralar),
              onIzle: (i) => i < kameralar.length
                  ? context.push(AppRoutes.kameraIzle, extra: kameralar[i])
                  : _yakinda(context),
            ),
        ],
      ),
    );
  }

  /// KVKK: tesis_gorevlisi kargo/ziyaretci/plaka kartlarini gormez.
  bool _gorunur(HizliErisimKart k, bool guvenlik) =>
      guvenlik ||
      !const {'Kargo', 'Ziyaretçi', 'Araç Plaka'}.contains(k.baslik);

  void _ac(BuildContext context, HizliErisimKart k) {
    final rota = k.rota;
    if (rota == null) {
      _yakinda(context);
      return;
    }
    context.push(rota);
  }

  void _yakinda(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Bu bölüm yakında')));
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
          ..showSnackBar(const SnackBar(content: Text('Raporlar yakında')));
      case 4: // Ayarlar.
        context.push(AppRoutes.settings);
    }
  }
}
