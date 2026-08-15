import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_router.dart';
import '../../announcements/data/announcement_api.dart';
import '../../announcements/domain/announcement_models.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cameras/data/cameras_api.dart';
import '../../cameras/domain/camera_models.dart';
import '../../cameras/presentation/kameralar_screen.dart' show kameraAc;
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
import '../../complaints/data/complaint_api.dart';
import '../data/activity_api.dart';
import '../data/home_api.dart';
import '../data/home_repository.dart';
import '../../../core/i18n/l10n.dart';
import '../domain/home_kart_id.dart';
import '../domain/home_varyant.dart';
import '../domain/home_view_models.dart';
import 'home_async.dart';
import 'home_refresh.dart';
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
import '../data/izgara_tercihi.dart';
import 'izgara_koprusu.dart';

/// Gorevli ana ekrani (referans: gorevli.jpeg) — guvenlik + tesis gorevlisi
/// TEK rol-parametrik ekranda.
///
/// Bolum sirasi: karsilama → 4'LU IZGARA (yonetici izgarasiyla ayni kart
/// tipi) → Vardiya Durumu → Son Hareketler → Canlı Kamera.
///
/// IZGARA (bu tur): yatay 5'li serit KALKTI. Guvenlik 8 kart gorur (vardiya,
/// kargo, ziyaretci, plaka, ihlal + gorevlerim, demirbas, turlarim); tesis
/// gorevlisi KENDI 8 karti (vardiya, gorevlerim, demirbas, talep, duyuru,
/// etkinlik, kurallar, yonetici) — KVKK geregi ziyaretci/kargo/plaka/ihlal
/// YOK; o kartlarin ucu bu role 403 doner, dolayisiyla kart hic cizilmez.
///
/// KAMERA: iki rolde de gosterilir. Liste SUNUCUDA suzulur — tesis gorevlisi
/// yalniz `aktif && sakin_gorebilir` kameralari alir; istemci ek suzgec
/// UYGULAMAZ (gelen ne ise o cizilir).
///
/// VERI: her sayac GERCEK uctan gelir; akis TEK uctan (/activity). Ana ekran
/// CANLI: donus/on plan/asagi-cekme/periyodik yenileme
/// ([HomeCanliVeri], bkz. home_refresh.dart).
class SahaHomeScreen extends ConsumerWidget {
  const SahaHomeScreen({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final taban = ref.watch(homeRepositoryProvider);
    final ad = ref.watch(profileProvider).value?.ad ?? '';
    // (P35) TEK BAYRAK YETMEZ: amir bildirimi ve arac/ihlal sayacini
    // GORUR ama kargo/ziyaretci ona KAPALIDIR (KVKK). Kartlar artik rolun
    // YETENEK bayraklarina bakar — `role == security` kisayolu amir icin
    // 403 uretecek istekler atardi.
    final guvenlik = role == UserRole.security;
    final kapiOps = role.canViewKargo;          // kargo + ziyaretci
    final aracIhlal = role.canViewVehiclePasses;
    final now = DateTime.now();

    // /notifications RBAC: security izinli, tesis_gorevlisi DEGIL — izinsiz
    // rolde provider hic izlenmez (401 uretecek istek atilmaz), rozet yok.
    final unread = role.canViewNotifications
        ? ref.watch(unreadNotificationCountProvider).value ?? 0
        : 0;

    final hava = ref.watch(weatherProvider).value;
    final tesisAd = ref.watch(tenantSettingsProvider).value?.ad ?? '';
    final vardiyaAsync = ref.watch(shiftsProvider);
    final vardiyalar = vardiyaAsync.value ?? const [];
    // KVKK: kargo/ziyaretci UCLARI tesis_gorevlisine kapali — o rolde hic
    // izlenmez (403 uretecek istek atilmaz).
    final kargoAsync = kapiOps
        ? ref.watch(kargoListProvider)
        : const AsyncValue<List<Kargo>>.data([]);
    // /visitors + /vehicle-passes + /violations: RBAC'i security'dir; hepsi
    // ?limit=1 sayacidir (liste tasinmaz). tesis_gorevlisi rolunde kart
    // cizilmedigi icin saglayici hic izlenmez.
    final icerdeAsync =
        kapiOps ? ref.watch(icerdekiZiyaretciSayisiProvider) : null;
    final aracAsync =
        aracIhlal ? ref.watch(bugunkuAracGirisSayisiProvider) : null;
    final ihlalAsync =
        role.canViewViolations ? ref.watch(yeniIhlalSayisiProvider) : null;
    // Saha personelinin gunluk isleri — iki rolde de izlenir (/tasks ve
    // /assets saha rollerine aciktir; sunucu kendi kapsamiyla suzer).
    final gorevAsync = ref.watch(aktifGorevSayisiProvider);
    final zimmetAsync = ref.watch(uzerimdekiZimmetSayisiProvider);
    // Tesis gorevlisi izgarasinin kendi sayaclari (RBAC'i bu role acik).
    final talepAsync = guvenlik ? null : ref.watch(acikSikayetSayisiProvider);
    final duyuruAsync = guvenlik ? null : ref.watch(sonDuyurularProvider);
    final etkinlikAsync =
        guvenlik ? null : ref.watch(yaklasanEtkinlikSayisiProvider);
    // Vardiya seridinin son karti tenant yoneticisidir (referans gorsel).
    // /yonetici-iletisim saha rollerine aciktir.
    final yoneticiler =
        ref.watch(yoneticiIletisimProvider).value?.yoneticiler ?? const [];
    // Son Hareketler TEK uctan: rol suzgeci SUNUCUDA (tesis_gorevlisi yalniz
    // gorev tamamlamalarini gorur) — istemci artik kaynak birlestirmez.
    final hareketler = ref.watch(sonHareketlerProvider);

    final aktifVardiya = vardiyalar.where((v) => v.aktifMi(now)).length;
    final pending = ref.watch(scanOutboxProvider).pendingCount;
    final varyant =
        guvenlik ? HomeVaryant.gorevli : HomeVaryant.tesisGorevlisi;
    final izgaraSecimi = ref.watch(izgaraKarolariProvider(role));
    final erisim = [
      // (P139.4) IZGARA ARTIK KULLANICININ: kaynak `taban.hizliErisim`
      // degil, kullanicinin tercihinden cozulen kume. Kopru secilen
      // girisi rolun MEVCUT kartiyla ROTA uzerinden esler ve eslesirse o
      // karti OLDUGU GIBI kullanir — bu yuzden asagidaki sayac `switch`i
      // hicbir degisiklik olmadan calismaya devam eder.
      for (final k in rolunKartlari(
          izgaraKartlari(izgaraSecimi, varyant, taban), role))
          switch (k.id) {
            HomeKartId.vardiyaDurum =>
              k.sayacla(vardiyaAsync.metin((_) => l10n.sayacAktif(aktifVardiya))),
            HomeKartId.kargo => k.sayacla(kargoAsync.metin((l) => l10n.sayacBekliyor(
                  l.where((x) => x.durum == KargoDurum.bekliyor).length))),
            // G3: cikis damgasi geldi → halen ICERIDE olanlar sunucuda
            // sayilir (?icerde=true), istemci bugun/dun hesabi yapmaz.
            HomeKartId.ziyaretci when icerdeAsync != null =>
              k.sayacla(icerdeAsync.metin(l10n.sayacIceride)),
            // G1: bugunku arac girisi. Tek-satir gecis modelinde "acik gecis"
            // sayisi otopark DOLULUGUDUR (yonetici karti) — serit karti gun
            // icindeki GIRIS akisini gosterir.
            HomeKartId.aracPlaka when aracAsync != null =>
              k.sayacla(aracAsync.metin(l10n.sayacGiris)),
            // G2: henuz ele alinmamis ihlal.
            HomeKartId.ihlaller when ihlalAsync != null =>
              k.sayacla(ihlalAsync.metin(l10n.sayacYeni)),
            // Kendi rol grubuna atanan + atanmamis AKTIF gorevler (sunucu
            // saha gorunurlugunu kendisi uygular).
            HomeKartId.gorevlerim => k.sayacla(gorevAsync.metin(l10n.sayacBekliyor)),
            // Uzerimdeki ACIK zimmet (/assets?checked_out_by=me).
            HomeKartId.demirbas => k.sayacla(zimmetAsync.metin(l10n.sayacZimmetli)),
            HomeKartId.talepAriza when talepAsync != null =>
              k.sayacla(talepAsync.metin(l10n.sayacAcik)),
            HomeKartId.duyurular when duyuruAsync != null => k.sayacla(
                duyuruAsync.metin((l) => l10n.sayacYeni(_yeniDuyuru(l, now))),
              ),
            HomeKartId.etkinlikler when etkinlikAsync != null =>
              k.sayacla(etkinlikAsync.metin(l10n.sayacYaklasan)),
            _ => k,
          },
      // Cevrimdisi saha kaniti kaybolmasin: bekleyen okutma VARSA izgaraya
      // ek bir kart girer (9. hucre). pending=0 iken (normal durum) izgara
      // 4x2'dir — bu kart yalniz sorun varken belirir.
      if (pending > 0)
        HizliErisimKart(
          ikon: Icons.outbox_outlined,
          id: HomeKartId.gonderimKuyrugu,
          accent: HomeTokens.orange,
          altMetin: l10n.sayacBekleyen(pending),
          rota: AppRoutes.outbox,
        ),
    ];

    // Kamera listesi SUNUCUDA rol'e gore suzuludur: tesis gorevlisi yalniz
    // sakine acilmis kameralari alir. Istemci burada suzgec UYGULAMAZ.
    final kameralar = ref.watch(camerasProvider).value ?? const <Camera>[];

    return HomeCanliVeri(
      varyant: varyant,
      child: HomeShell(
      role: role,
      currentIndex: 0,
      unreadCount: unread,
      onDestinationSelected: (i) => _onTab(context, i),
      onModul: (rota) => context.push(rota),
      onBildir: () => showBildirMenu(context, girisler: [
        BildirGiris(
            icon: Icons.rate_review_outlined,
            label: l10n.fabOlayBildir,
            route: '${AppRoutes.complaints}?bildir=1'),
        BildirGiris(
            icon: Icons.task_alt,
            label: l10n.kartGorevlerim,
            route: AppRoutes.tasks),
        if (guvenlik)
          BildirGiris(
              icon: Icons.directions_walk,
              label: l10n.kartTurlarim,
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
        onYenile: () => homeVerisiniYenile(ref, varyant),
        bolumler: [
          HomeSectionPad(
            child: HizliErisimIzgarasi(
              kartlar: erisim,
              onSec: (k) => _ac(context, k),
            ),
          ),
          VardiyaSeridi(
            kartlar: vardiyaKartlari(
              l10n: l10n,
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
                satirlar: hareketSatirlari(l10n, dil, satirlar, now),
                // (P162 §9) Satira dokununca ilgili ekrana git. `rota`
                // bos olan satirlar TIKLANMAZ kalir (bkz. hareketRotasi).
                onSatir: (h) {
                  if (h.rota != null) context.push(h.rota!);
                },
                onSeeAll:
                    guvenlik ? () => context.push(AppRoutes.notifications) : null,
              ),
              yukleniyor: () =>
                  HomeBolumIskeleti(baslik: l10n.bolumSonHareketler),
              hata: () => HomeBolumHatasi(
                baslik: l10n.bolumSonHareketler,
                onYenile: () =>
                    ref.invalidate(sonHareketlerProvider),
              ),
            ),
          ),
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

  /// "N Yeni" — son 3 gunde yayinlanan duyuru sayisi (sakin ekraniyla ayni
  /// esik).
  int _yeniDuyuru(List<Announcement> liste, DateTime now) => liste
      .where((d) => now.difference(d.createdAt) <= const Duration(days: 3))
      .length;

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
      ..showSnackBar(
          SnackBar(content: Text(context.l10n.ortakBolumYakinda)));
  }

  void _onTab(BuildContext context, int index) {
    switch (index) {
      case 1: // Bildirimler: security inbox'a gider; tesis gorevlisi RBAC
        // disi — durust mesaj (sahte bos ekran degil).
        if (role.canViewNotifications) {
          context.push(AppRoutes.notifications);
        } else {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(context.l10n.anaBildirimlerRolYok),
            ));
        }
      case 3:
        // (P154 / Asama 7.2) ARTIK GERCEK BIR EKRAN. Once burada
        // "raporlar yakinda" yaziyordu ve sebebi de dogruydu: rapor ucu
        // saha rollerine kapali (RBAC yonetici). Ama sonuc, bes yuvanin
        // BIRININ saha personeli icin HICBIR ISE YARAMAMASIYDI.
        //
        // Brief 7.2: "guvenlik + tesis gorevlisi -> 'Gorevlerim'".
        // Gorevlerim zaten saha personelinin gunluk ekrani ve ucu ONLARA
        // ACIK; yuva bos bir vaat yerine ona baglandi.
        context.push(AppRoutes.tasks);
      case 4: // Ayarlar.
        context.push(AppRoutes.settings);
    }
  }
}
