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
import '../data/activity_api.dart';
import '../data/home_api.dart';
import '../data/home_repository.dart';
import '../domain/home_varyant.dart';
import '../domain/home_view_models.dart';
import '../domain/parking_occupancy.dart';
import 'home_async.dart';
import 'home_refresh.dart';
import 'home_mappers.dart';
import 'widgets/bildir_menu_sheet.dart';
import 'widgets/hizli_erisim.dart';
import 'widgets/home_govde.dart';
import 'widgets/home_header.dart';
import 'widgets/home_shell.dart';
import 'widgets/home_states.dart';
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
///
/// VERI: izgaradaki SEKIZ kartin ve Hızlı Özet'in TAMAMI gercek uctan gelir
/// (esleme tablosu README "Ana ekran veri eslemesi") — 'Yakında' etiketi
/// kalmadi. Ekranda uydurma sayi YOKTUR: veri gelene kadar iskelet, uc hata
/// verirse "Yüklenemedi" + yeniden dene ya da sayac yerine '—'.
class YoneticiHomeScreen extends ConsumerWidget {
  const YoneticiHomeScreen({super.key, this.role = UserRole.yonetici});

  /// yonetici (varsayilan) ya da admin — duzen ayni, yalniz FAB menusu ve
  /// bazi RBAC ayrintilari role gore degisir.
  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taban = ref.watch(homeRepositoryProvider);
    final ad = ref.watch(profileProvider).value?.ad ?? '';
    final now = DateTime.now();

    final hava = ref.watch(weatherProvider).value;
    // Okunmamis bildirim rozeti; hata/yukleme → 0 (rozet yok, ekran calisir).
    final unread = ref.watch(unreadNotificationCountProvider).value ?? 0;
    final finans = ref.watch(financialSummaryProvider);
    final daire = ref.watch(toplamDaireSayisiProvider);
    final gorev = ref.watch(aktifGorevSayisiProvider);
    final talep = ref.watch(acikSikayetSayisiProvider);
    final daireSikayet = ref.watch(acikDaireSikayetSayisiProvider);
    final ihlal = ref.watch(yeniIhlalSayisiProvider);
    // Otopark: kart ("dolu / kapasite") ve "Hızlı Özet" kutusu ("%oran")
    // AYNI yaniti kullanir — tek istek.
    final otopark = ref.watch(otoparkDolulukProvider);
    final vardiyaAsync = ref.watch(shiftsProvider);
    final vardiyalar = vardiyaAsync.value ?? const [];
    // Son Hareketler TEK uctan (/activity); sunucu rol suzer. KVKK: yonetim
    // bu akista ziyaretci/kargo olaylarini GORMEZ — istemci geri EKLEMEZ.
    final hareketler = ref.watch(sonHareketlerProvider);

    final aktifVardiya = vardiyalar.where((v) => v.aktifMi(now)).length;
    final erisim = [
      for (final k in taban.hizliErisim(HomeVaryant.yonetici))
        switch (k.baslik) {
          'Vardiya Durumu' =>
            k.sayacla(vardiyaAsync.sayac((_) => aktifVardiya, 'Aktif')),
          'Görevler' => k.sayacla(gorev.sayac((n) => n, 'Bekliyor')),
          // Geciken (borclu) daire sayisi — tahsilat blogu YALNIZ yonetimde
          // dolar; sakin/saha yanitinda null gelir.
          'Aidat Durumu' => k.sayacla(finans.metin((f) => f.tahsilat == null
              ? '—'
              : '${f.tahsilat!.gecikenDaireSayisi} Daire')),
          // G4: kapasite tanimsizsa payda UYDURULMAZ → "N araç".
          'Otopark Kullanımı' => k.sayacla(otopark.metin((o) => o.doluMetni)),
          'İhlaller' => k.sayacla(ihlal.sayac((n) => n, 'Yeni')),
          'Geri Bildirim' => k.sayacla(talep.sayac((n) => n, 'Açık')),
          'Şikayetler' => k.sayacla(daireSikayet.sayac((n) => n, 'Açık')),
          _ => k,
        },
    ];

    return HomeCanliVeri(
      varyant: HomeVaryant.yonetici,
      child: HomeShell(
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
        onYenile: () => homeVerisiniYenile(ref, HomeVaryant.yonetici),
        header: HomeHeader(
          greetingName: ad,
          subtitle: 'Yönetici Paneli',
          // Referans: yonetici alt basligi MAVI.
          altBaslikStili: HomeAltBaslikStili.mavi,
          hava: hava == null ? null : havaOzeti(hava),
        ),
        bolumler: [
          HomeSectionPad(
            child: HizliErisimIzgarasi(
              kartlar: erisim,
              onSec: (k) =>
                  k.rota == null ? _yakinda(context) : context.push(k.rota!),
            ),
          ),
          // Vardiya serisi GERCEK /shifts'ten; yonetici kendi adiyla serinin
          // sonunda durur (referans gorsel). Bos/hatali → bolum cizilmez.
          VardiyaSeridi(
            kartlar: vardiyaKartlari(
              vardiyalar: vardiyalar,
              now: now,
              yoneticiAd: ad,
            ),
            onSeeAll: () => context.push(AppRoutes.vardiyalar),
          ),
          HomeSectionPad(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // "Hızlı Özet" — tam liste yok, "Tümünü Gör" gizli.
                const SectionHeader(title: 'Hızlı Özet'),
                HizliOzetIzgarasi(
                  kutular: _ozet(taban.ozet(), daire, finans, otopark),
                  // Ozetten DETAYA kisa yol; ekrani olmayan kutu (otopark)
                  // "yakında" bilgilendirmesi verir.
                  onSec: (k) => k.rota == null
                      ? _yakinda(context)
                      : context.push(k.rota!),
                ),
              ],
            ),
          ),
          HomeSectionPad(
            child: hareketler.durum(
              veri: (satirlar) => SonHareketlerKarti(
                satirlar: hareketSatirlari(satirlar, now),
                onSeeAll: () => context.push(AppRoutes.notifications),
              ),
              yukleniyor: () =>
                  const HomeBolumIskeleti(baslik: 'Son Hareketler'),
              hata: () => HomeBolumHatasi(
                baslik: 'Son Hareketler',
                onYenile: () => ref.invalidate(sonHareketlerProvider),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// "Hızlı Özet": Toplam Daire → GET /units, Toplam Tahsilat + Aidat
  /// Tahsilat Oranı → GET /reports/financial-summary, Otopark Doluluk →
  /// GET /parking/occupancy (`oran`; kapasite tanimsizsa sunucu null doner →
  /// kutu '—' gosterir, uydurma yuzde yok).
  List<OzetKutusu> _ozet(
    List<OzetKutusu> taban,
    AsyncValue<int> daire,
    AsyncValue<FinancialSummary> finans,
    AsyncValue<ParkingOccupancy> otopark,
  ) {
    return [
      for (final k in taban)
        switch (k.etiket) {
          'Toplam Daire' => k.degerle(daire.metin((n) => '$n')),
          'Toplam Tahsilat' => k.degerle(finans.metin((f) => f.tahsilat == null
              ? '—'
              : '₺${formatKurusAsTl(f.tahsilat!.tahsilatKurus)}')),
          'Aidat Tahsilat Oranı' =>
            k.degerle(finans.metin((f) => f.tahsilat?.tahsilatOraniYuzde == null
                ? '—'
                : '%${f.tahsilat!.tahsilatOraniYuzde}')),
          'Otopark Doluluk' => k.degerle(otopark.metin((o) => o.oranMetni)),
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
