import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../budget/data/budget_api.dart';
import '../../cameras/data/cameras_api.dart';
import '../../cameras/domain/camera_models.dart';
import '../../cameras/presentation/kameralar_screen.dart' show kameraAc;
import '../../budget/domain/budget_models.dart';
import '../../complaints/data/complaint_api.dart';
import '../../notifications/data/notifications_controller.dart';
import '../../profile/data/profile_api.dart';
import '../../shifts/data/shifts_api.dart';
import '../../weather/data/weather_api.dart';
import '../data/activity_api.dart';
import '../data/home_api.dart';
import '../data/home_repository.dart';
import '../../../core/i18n/l10n.dart';
import '../domain/home_kart_id.dart';
import '../domain/home_varyant.dart';
import '../domain/home_view_models.dart';
import '../domain/parking_occupancy.dart';
import 'home_async.dart';
import 'home_refresh.dart';
import 'home_mappers.dart';
import 'widgets/bildir_menu_sheet.dart';
import 'widgets/hizli_erisim.dart';
import 'widgets/kamera_seridi.dart';
import 'widgets/home_govde.dart';
import 'widgets/home_header.dart';
import 'widgets/home_shell.dart';
import 'widgets/home_states.dart';
import 'widgets/section_header.dart';
import 'widgets/section_padding.dart';
import 'widgets/son_hareketler_karti.dart';
import 'widgets/stat_tile.dart';
import 'widgets/vardiya_seridi.dart';
import '../data/izgara_tercihi.dart';
import 'izgara_koprusu.dart';

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
    final l10n = context.l10n;
    final dil = context.dilKodu;
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
    // Kamera listesi SUNUCUDA role gore suzuludur; istemci ek suzgec
    // UYGULAMAZ. Hata -> bolum sessizce gizlenir (ana ekran rehin degil).
    final kameralar = ref.watch(camerasProvider).value ?? const <Camera>[];

    final aktifVardiya = vardiyalar.where((v) => v.aktifMi(now)).length;
    final izgaraSecimi = ref.watch(izgaraKarolariProvider(role));
    final erisim = [
      // (P139.4) IZGARA ARTIK KULLANICININ: kaynak `taban.hizliErisim`
      // degil, kullanicinin tercihinden cozulen kume. Kopru secilen
      // girisi rolun MEVCUT kartiyla ROTA uzerinden esler ve eslesirse o
      // karti OLDUGU GIBI kullanir — bu yuzden asagidaki sayac `switch`i
      // hicbir degisiklik olmadan calismaya devam eder.
      for (final k in rolunKartlari(
          izgaraKartlari(izgaraSecimi, HomeVaryant.yonetici, taban), role))
        switch (k.id) {
          HomeKartId.vardiyaDurumu => k.sayacla(
              vardiyaAsync.metin((_) => l10n.sayacAktif(aktifVardiya))),
          HomeKartId.gorevler => k.sayacla(gorev.metin(l10n.sayacBekliyor)),
          // Geciken (borclu) daire sayisi — tahsilat blogu YALNIZ yonetimde
          // dolar; sakin/saha yanitinda null gelir.
          HomeKartId.aidatDurumu => k.sayacla(finans.metin((f) =>
              f.tahsilat == null
                  ? '—'
                  : l10n.sayacDaire(f.tahsilat!.gecikenDaireSayisi))),
          // G4: kapasite tanimsizsa payda UYDURULMAZ → "N araç".
          HomeKartId.otoparkKullanimi => k.sayacla(otopark.metin(
              (o) => o.kapasite == null
                  ? l10n.sayacArac(o.dolu)
                  : l10n.otoparkDoluKapasite(o.dolu, o.kapasite!))),
          HomeKartId.ihlaller => k.sayacla(ihlal.metin(l10n.sayacYeni)),
          HomeKartId.geriBildirim => k.sayacla(talep.metin(l10n.sayacAcik)),
          HomeKartId.sikayetler =>
            k.sayacla(daireSikayet.metin(l10n.sayacAcik)),
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
          BildirGiris(
              icon: Icons.campaign_outlined,
              label: l10n.fabDuyuruYayinla,
              route: AppRoutes.announcements),
        BildirGiris(
            icon: Icons.fact_check_outlined,
            label: l10n.fabGorevOlustur,
            route: '${AppRoutes.tasks}?gorunum=yonetim'),
        BildirGiris(
            icon: Icons.support_agent_outlined,
            label: l10n.fabDestekTalebi,
            route: AppRoutes.destek),
      ], onSec: (r) => context.push(r)),
      onProfile: () => context.push(AppRoutes.profile),
      onLogout: () => ref.read(authControllerProvider.notifier).logout(),
      body: HomeGovde(
        onYenile: () => homeVerisiniYenile(ref, HomeVaryant.yonetici),
        header: HomeHeader(
          greetingName: ad,
          subtitle: l10n.anaYoneticiPaneli,
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
              l10n: l10n,
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
                SectionHeader(title: l10n.bolumHizliOzet),
                HizliOzetIzgarasi(
                  kutular: _ozet(l10n, dil, taban.ozet(), daire, finans, otopark),
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
                satirlar: hareketSatirlari(l10n, dil, satirlar, now),
                onSeeAll: () => context.push(AppRoutes.notifications),
              ),
              yukleniyor: () =>
                  HomeBolumIskeleti(baslik: l10n.bolumSonHareketler),
              hata: () => HomeBolumHatasi(
                baslik: l10n.bolumSonHareketler,
                onYenile: () => ref.invalidate(sonHareketlerProvider),
              ),
            ),
          ),
          // CANLI KAMERA (P25c) — liste SUNUCUDA role gore suzuludur;
          // yonetim tumunu, sakin yalniz `aktif && sakin_gorebilir`
          // kameralari alir. Bolum eskiden YALNIZ saha ana ekranindaydi:
          // yonetici ve sakin, gorme yetkileri olan kameralari ana ekranda
          // hic goremiyordu.
          if (kameralar.isNotEmpty)
            KameraSeridi(
              kameralar: kameralar,
              onSeeAll: () => context.push(AppRoutes.kameralar),
              // Oynatilabilirse oynatici, RTSP ise bilgi karti (tek kural).
              onAc: (kamera) => kameraAc(context, kamera),
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
    AppLocalizations l10n,
    String dil,
    List<OzetKutusu> taban,
    AsyncValue<int> daire,
    AsyncValue<FinancialSummary> finans,
    AsyncValue<ParkingOccupancy> otopark,
  ) {
    return [
      for (final k in taban)
        switch (k.id) {
          OzetKutuId.toplamDaire => k.degerle(daire.metin((n) => '$n')),
          // PARA: dil ne olursa olsun ₺ + Turkce gruplama (site-yerel kural).
          OzetKutuId.toplamTahsilat => k.degerle(finans.metin((f) =>
              f.tahsilat == null ? '—' : tlIsaretli(f.tahsilat!.tahsilatKurus, dil))),
          OzetKutuId.tahsilatOrani => k.degerle(finans.metin((f) =>
              f.tahsilat?.tahsilatOraniYuzde == null
                  ? '—'
                  : l10n.yuzdeDeger(f.tahsilat!.tahsilatOraniYuzde!))),
          // Kapasite tanimsizsa sunucu oran'i null doner → uydurma yuzde yok.
          OzetKutuId.otoparkDoluluk => k.degerle(otopark.metin(
              (o) => o.oran == null ? '—' : l10n.yuzdeDeger(o.oran!))),
        },
    ];
  }

  void _yakinda(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(context.l10n.ortakBolumYakinda)));
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
