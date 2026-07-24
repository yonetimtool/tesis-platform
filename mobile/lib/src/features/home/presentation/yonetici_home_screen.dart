import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../budget/data/budget_api.dart';
import '../../budget/domain/budget_models.dart';
import '../../complaints/data/complaint_api.dart';
import '../../notifications/data/notifications_controller.dart';
import '../../profile/data/profile_api.dart';
import '../../shifts/data/shifts_api.dart';
import '../../weather/data/weather_api.dart';
import '../data/home_repository.dart';
import '../domain/home_varyant.dart';
import '../domain/home_view_models.dart';
import '../domain/son_hareketler.dart';
import 'home_mappers.dart';
import 'widgets/bildir_menu_sheet.dart';
import 'widgets/hizli_erisim.dart';
import 'widgets/home_govde.dart';
import 'widgets/home_header.dart';
import 'widgets/home_shell.dart';
import 'widgets/section_header.dart';
import 'widgets/section_padding.dart';
import 'widgets/son_hareketler_karti.dart';
import 'widgets/stat_tile.dart';
import 'widgets/vardiya_seridi.dart';

/// Yonetim ana ekrani (referans: yonetici.jpeg) — site yoneticisi VE platform
/// admini ayni duzeni gorur (brief: admin→yönetici varyanti).
///
/// Bolum sirasi gorselle birebir: karsilama → 4x2 hizli erisim izgarasi →
/// Vardiya Durumu → Hızlı Özet → Son Hareketler.
class YoneticiHomeScreen extends ConsumerWidget {
  const YoneticiHomeScreen({super.key, this.role = UserRole.yonetici});

  /// yonetici (varsayilan) ya da admin — duzen ayni, yalniz FAB menusu ve
  /// bazi RBAC ayrintilari role gore degisir.
  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mock = ref.watch(homeRepositoryProvider);
    final ad = ref.watch(profileProvider).value?.ad ?? '';
    final now = DateTime.now();

    final hava = ref.watch(weatherProvider).value;
    // Okunmamis bildirim rozeti; hata/yukleme → 0 (rozet yok, ekran calisir).
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    // Hizli Ozet: finans verisi gelince gercek tahsilat/oran; yoksa mock.
    final finans = ref.watch(financialSummaryProvider).value;
    // Acik sikayet sayaci; hata → mock sayac (ekran calisir).
    final acikSikayet = ref.watch(acikSikayetSayisiProvider).value;
    final vardiyalar = ref.watch(shiftsProvider).value ?? const [];
    final hareketler =
        yoneticiHareketleri(ref.watch(notificationsProvider).value ?? const []);

    final vardiyaKartlar = vardiyalar.isEmpty
        ? mock.vardiyalar()
        : vardiyaKartlari(
            vardiyalar: vardiyalar,
            now: now,
            // Yonetici kendi adiyla serinin sonunda durur (referans gorsel).
            yoneticiAd: ad.isEmpty ? mock.yoneticiAd() : ad,
          );

    final aktifVardiya = vardiyalar.where((v) => v.aktifMi(now)).length;
    final erisim = [
      for (final k in mock.hizliErisim(HomeVaryant.yonetici))
        switch (k.baslik) {
          'Vardiya Durumu' when vardiyalar.isNotEmpty =>
            k.sayacla('$aktifVardiya Aktif'),
          'Şikayetler' when acikSikayet != null =>
            k.sayacla('$acikSikayet Açık'),
          _ => k,
        },
    ];

    final satirlar = hareketler.isEmpty
        ? mock.hareketler(HomeVaryant.yonetici)
        : hareketSatirlari(hareketler, now);

    return HomeShell(
      role: role,
      currentIndex: 0,
      unreadCount: unread,
      onDestinationSelected: (i) => _onTab(context, i),
      onModul: (rota) => context.push(rota),
      onBildir: () => showBildirMenu(context, girisler: [
        // Duyuru YAYINLAMA mobilde yalniz yonetici (admin panelden moderasyon).
        if (role.canManageAnnouncements)
          const BildirGiris(
              icon: Icons.campaign_outlined,
              label: 'Duyuru Yayınla',
              route: AppRoutes.announcements),
        const BildirGiris(
            icon: Icons.fact_check_outlined,
            label: 'Görev Oluştur',
            route: '${AppRoutes.tasks}?gorunum=yonetim'),
        const BildirGiris(
            icon: Icons.support_agent_outlined,
            label: 'Destek Talebi',
            route: AppRoutes.destek),
      ], onSec: (r) => context.push(r)),
      onProfile: () => context.push(AppRoutes.profile),
      onLogout: () => ref.read(authControllerProvider.notifier).logout(),
      body: HomeGovde(
        header: HomeHeader(
          greetingName: ad,
          subtitle: 'Yönetici Paneli',
          // Referans: yonetici alt basligi MAVI.
          altBaslikStili: HomeAltBaslikStili.mavi,
          hava: hava == null ? mock.hava() : havaOzeti(hava),
        ),
        bolumler: [
          HomeSectionPad(
            child: HizliErisimIzgarasi(
              kartlar: erisim,
              onSec: (k) =>
                  k.rota == null ? _yakinda(context) : context.push(k.rota!),
            ),
          ),
          VardiyaSeridi(
            kartlar: vardiyaKartlar,
            onSeeAll: () => context.push(AppRoutes.vardiyalar),
          ),
          HomeSectionPad(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // "Hızlı Özet" — tam liste yok, "Tümünü Gör" gizli.
                const SectionHeader(title: 'Hızlı Özet'),
                HizliOzetIzgarasi(kutular: _ozet(mock.ozet(), finans)),
              ],
            ),
          ),
          HomeSectionPad(
            child: SonHareketlerKarti(
              satirlar: satirlar,
              onSeeAll: () => context.push(AppRoutes.notifications),
            ),
          ),
        ],
      ),
    );
  }

  /// Mock taban + gercek finans: "Toplam Tahsilat" ve "Aidat Tahsilat Oranı"
  /// GET /reports/financial-summary'den gelir; "Toplam Daire" ve "Otopark
  /// Doluluk" MISSING-BACKEND (README "TODO: gerçek uç").
  List<OzetKutusu> _ozet(List<OzetKutusu> taban, FinancialSummary? finans) {
    final tahsilat = finans?.tahsilat;
    if (tahsilat == null) return taban;
    return [
      for (final k in taban)
        switch (k.etiket) {
          'Toplam Tahsilat' => OzetKutusu(
              ikon: k.ikon,
              deger: '₺${formatKurusAsTl(tahsilat.tahsilatKurus)}',
              etiket: k.etiket,
              altEtiket: k.altEtiket,
              accent: k.accent),
          'Aidat Tahsilat Oranı' => OzetKutusu(
              ikon: k.ikon,
              deger: '%${tahsilat.tahsilatOraniYuzde}',
              etiket: k.etiket,
              altEtiket: k.altEtiket,
              accent: k.accent),
          _ => k,
        },
    ];
  }

  void _yakinda(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Bu bölüm yakında')));
  }

  void _onTab(BuildContext context, int index) {
    switch (index) {
      case 1: // Bildirimler inbox (RBAC: yonetici + admin izinli).
        context.push(AppRoutes.notifications);
      case 3: // Raporlar — aylik raporlar.
        context.push(AppRoutes.reports);
      case 4: // Ayarlar.
        context.push(AppRoutes.settings);
    }
  }
}
