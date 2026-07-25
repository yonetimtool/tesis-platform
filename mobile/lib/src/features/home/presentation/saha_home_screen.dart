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
import '../../visitors/data/visitor_api.dart';
import '../../weather/data/weather_api.dart';
import '../../yonetici_iletisim/data/yonetici_iletisim_api.dart';
import '../data/home_api.dart';
import '../data/home_repository.dart';
import '../domain/home_varyant.dart';
import '../domain/home_view_models.dart';
import 'home_async.dart';
import 'home_mappers.dart';
import 'widgets/bildir_menu_sheet.dart';
import 'widgets/hizli_erisim.dart';
import 'widgets/home_govde.dart';
import 'widgets/home_header.dart';
import 'widgets/home_shell.dart';
import 'widgets/home_states.dart';
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
///
/// VERI: sayaclar GERCEK uctan (/shifts, /kargo, /visitors); "Araç Plaka" ve
/// "İhlaller" sozlesmede YOK → 'Yakında' (README "CONTRACT GAPS").
class SahaHomeScreen extends ConsumerWidget {
  const SahaHomeScreen({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taban = ref.watch(homeRepositoryProvider);
    final ad = ref.watch(profileProvider).value?.ad ?? '';
    final guvenlik = role == UserRole.security;
    final now = DateTime.now();

    // /notifications RBAC: security izinli, tesis_gorevlisi DEGIL — izinsiz
    // rolde provider hic izlenmez (401 uretecek istek atilmaz), rozet yok.
    final unread =
        guvenlik ? ref.watch(unreadNotificationCountProvider).value ?? 0 : 0;

    final hava = ref.watch(weatherProvider).value;
    final tesisAd = ref.watch(tenantSettingsProvider).value?.ad ?? '';
    final vardiyaAsync = ref.watch(shiftsProvider);
    final vardiyalar = vardiyaAsync.value ?? const [];
    // KVKK: kargo/ziyaretci UCLARI tesis_gorevlisine kapali — o rolde hic
    // izlenmez (403 uretecek istek atilmaz).
    final kargoAsync = guvenlik
        ? ref.watch(kargoListProvider)
        : const AsyncValue<List<Kargo>>.data([]);
    final ziyaretciAsync =
        guvenlik ? ref.watch(visitorsListProvider) : null;
    // Vardiya seridinin son karti tenant yoneticisidir (referans gorsel).
    // /yonetici-iletisim saha rollerine aciktir.
    final yoneticiler =
        ref.watch(yoneticiIletisimProvider).value?.yoneticiler ?? const [];
    final hareketler = ref.watch(sahaHareketleriProvider(guvenlik));

    final aktifVardiya = vardiyalar.where((v) => v.aktifMi(now)).length;
    final pending = ref.watch(scanOutboxProvider).pendingCount;
    final erisim = [
      for (final k in taban.hizliErisim(HomeVaryant.gorevli))
        if (_gorunur(k, guvenlik))
          switch (k.baslik) {
            'Vardiya Durum' =>
              k.sayacla(vardiyaAsync.sayac((_) => aktifVardiya, 'Aktif')),
            'Kargo' => k.sayacla(kargoAsync.sayac(
                (l) => l.where((x) => x.durum == KargoDurum.bekliyor).length,
                'Bekliyor',
              )),
            // Ziyaretci LOG'unda cikis alani YOK (sozlesme) — "içeride"
            // hesaplanamaz; BUGUNKU kayit sayisi gosterilir.
            'Ziyaretçi' when ziyaretciAsync != null => k.sayacla(
                ziyaretciAsync.sayac(
                  (l) => l.where((z) => _bugun(z.createdAt, now)).length,
                  'Bugün',
                ),
              ),
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
          // Referans: tesis secici gorunumu ("Mavi Residence ⌄") — ad
          // GET /tenant/settings'ten; gelmeden satir cizilmez.
          subtitle: tesisAd,
          altBaslikStili: HomeAltBaslikStili.tesisSecici,
          hava: hava == null ? null : havaOzeti(hava),
        ),
        bolumler: [
          HizliErisimSeridi(kartlar: erisim, onSec: (k) => _ac(context, k)),
          VardiyaSeridi(
            kartlar: vardiyaKartlari(
              vardiyalar: vardiyalar,
              now: now,
              yoneticiAd:
                  yoneticiler.isNotEmpty ? yoneticiler.first.adSoyad : null,
            ),
            onSeeAll: () => context.push(AppRoutes.vardiyalar),
          ),
          HomeSectionPad(
            child: hareketler.durum(
              veri: (satirlar) => SonHareketlerKarti(
                satirlar: hareketSatirlari(satirlar, now),
                onSeeAll:
                    guvenlik ? () => context.push(AppRoutes.notifications) : null,
              ),
              yukleniyor: () =>
                  const HomeBolumIskeleti(baslik: 'Son Hareketler'),
              hata: () => HomeBolumHatasi(
                baslik: 'Son Hareketler',
                onYenile: () =>
                    ref.invalidate(sahaHareketleriProvider(guvenlik)),
              ),
            ),
          ),
          if (kameralar.isNotEmpty)
            KameraSeridi(
              kameralar: kameraOzetleri(kameralar),
              onSeeAll: () => context.push(AppRoutes.kameralar),
              onIzle: (i) => i < kameralar.length
                  ? context.push(AppRoutes.kameraIzle, extra: kameralar[i])
                  : _yakinda(context),
            ),
        ],
      ),
    );
  }

  bool _bugun(DateTime t, DateTime now) {
    final yerel = t.toLocal();
    return yerel.year == now.year &&
        yerel.month == now.month &&
        yerel.day == now.day;
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
