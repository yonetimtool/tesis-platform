import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/startup/acilis_tercihleri.dart';
import '../features/announcements/presentation/announcements_screen.dart';
import '../features/cameras/domain/camera_models.dart';
import '../features/cameras/presentation/camera_player_screen.dart';
import '../features/cameras/presentation/kameralar_screen.dart';
import '../features/shifts/presentation/vardiyalar_screen.dart';
import '../features/assets/presentation/assets_screen.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/complaints/presentation/complaints_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/davet_screen.dart';
import '../features/auth/presentation/kayit_screen.dart';
import '../features/auth/presentation/set_password_screen.dart';
import '../features/budget/presentation/budget_screen.dart';
import '../features/building_map/presentation/bina_duzenleme_screen.dart';
import '../features/building_map/presentation/building_schematic_screen.dart';
import '../features/unit_complaints/presentation/my_complaints_screen.dart';
import '../features/unit_complaints/presentation/sikayet_kuyrugu_screen.dart';
import '../features/unit_tanimlari/presentation/unit_tanimlari_screen.dart';
import '../features/dues/presentation/ode_screen.dart';
import '../features/budget/presentation/financial_summary_screen.dart';
import '../features/budget/presentation/site_budget_screen.dart';
import '../features/transparency/presentation/transparency_screen.dart';
import '../features/home/presentation/home_gate.dart';
import '../features/home/presentation/izgara_duzenle_screen.dart';
import '../features/home/presentation/home_refresh.dart' show homeRouteObserver;
import '../features/kargo/presentation/kargo_screen.dart';
import '../features/nfc/presentation/nfc_screen.dart';
import '../features/dues/presentation/my_dues_screen.dart';
import '../features/yonetici_iletisim/presentation/yonetici_iletisim_screen.dart';
import '../features/etkinlik/presentation/etkinlik_screen.dart';
import '../features/patrol/presentation/patrol_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/residents/presentation/residents_screen.dart';
import '../features/checkpoints/presentation/checkpoints_screen.dart';
import '../features/patrol/presentation/patrol_plans_screen.dart';
import '../features/patrol/presentation/patrol_tracking_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/rezervasyon/presentation/rezervasyon_screen.dart';
import '../features/scan/presentation/outbox_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/support/presentation/destek_screen.dart';
import '../features/anket/presentation/anket_screen.dart';
import '../features/kvkk/presentation/kvkk_metin_screen.dart';
import '../features/kurulum/presentation/kurulum_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/staff/presentation/staff_screen.dart';
import '../features/dis_hizmet/presentation/dis_hizmet_screen.dart';
import '../features/site_kurali/presentation/site_kurali_screen.dart';
import '../features/tasks/domain/task_models.dart';
import '../features/tasks/presentation/task_categories_screen.dart';
import '../features/tasks/presentation/task_detail_screen.dart';
import '../features/tasks/presentation/tasks_screen.dart';
import '../features/unit_access/presentation/unit_access_records_screen.dart';
import '../features/integrations/presentation/integrations_screen.dart';
import '../features/unit_access/presentation/unit_access_screen.dart';
import '../features/anpr/presentation/anpr_screen.dart';
import '../features/vehicle_pass/presentation/parking_screen.dart';
import '../features/vehicle_pass/presentation/vehicle_pass_screen.dart';
import '../features/violations/presentation/violations_screen.dart';
import '../features/visitors/presentation/visitors_screen.dart';
import '../features/dokumanlar/presentation/dokuman_screen.dart';
import '../features/kvkk/presentation/yasal_metinler_screen.dart';
import 'splash_screen.dart';

class AppRoutes {
  const AppRoutes._();
  static const splash = '/splash';
  static const login = '/login';
  static const setPassword = '/set-password';
  /// (P154 / Asama 3) Rol secimli kayit — OTURUM GEREKTIRMEZ.
  static const kayit = '/kayit';
  /// (P155 §7/§8) Davet derin baglantisi — OTURUM GEREKTIRMEZ. Gercek yol
  /// `/davet/:jeton`; bu sabit yalniz onektir (yonlendirme karsilastirmasi).
  static const davet = '/davet';
  static const home = '/home';
  static const nfc = '/nfc';
  static const outbox = '/outbox';
  static const patrol = '/patrol';
  static const tasks = '/tasks';
  static const taskDetail = '/tasks/detail';
  static const taskCategories = '/tasks/categories';

  /// (P166 §8.2) Kurulum sihirbazi — web ile AYNI adimlar, AYNI uc.
  static const kurulum = '/kurulum';
  static const yoneticiIletisim = '/yonetici-iletisim';
  static const assets = '/assets';
  static const announcements = '/announcements';
  static const patrolTracking = '/patrol-tracking';
  // (P154 / Asama 7.2) Bu iki ekran BUGUNE KADAR yonlendiricide YOKTU:
  // yalnizca Devriye Takibi'nin sag ustundeki ETIKETSIZ ikonlardan
  // `MaterialPageRoute` ile aciliyorlardi. Brief "gizli aksiyonlar daha
  // gorunur olsun" diyor; gorunur kilmanin ilk sarti ADRESLENEBILIR
  // olmalari.
  static const patrolPlans = '/patrol-plans';
  static const checkpoints = '/checkpoints';
  static const reports = '/reports';
  static const budget = '/budget';
  static const financialSummary = '/financial-summary';
  static const siteBudget = '/site-budget';
  static const transparency = '/transparency';
  static const myDues = '/my-dues';
  static const ode = '/ode';
  static const complaints = '/complaints';
  static const visitors = '/visitors';
  static const kargo = '/kargo';
  static const unitAccess = '/unit-access';
  static const unitAccessRecords = '/unit-access/records';
  static const rezervasyon = '/rezervasyon';
  static const etkinlik = '/etkinlik';
  static const siteKurallari = '/site-kurallari';
  /// (P167 ek) Site dokumanlari — sakin YALNIZ acilanlari gorur.
  static const dokumanlar = '/dokumanlar';
  static const disHizmet = '/dis-hizmetler';
  static const integrations = '/integrations';
  static const binaDuzenleme = '/bina-duzenleme';
  static const sikayetHaritasi = '/sikayet-haritasi';
  static const sikayetlerim = '/sikayetlerim';
  static const sikayetKuyrugu = '/sikayet-kuyrugu';
  static const daireTanimlari = '/daire-tanimlari';
  static const vardiyalar = '/vardiyalar';
  static const kameralar = '/kameralar';
  static const kameraIzle = '/kamera-izle';
  static const settings = '/settings';
  /// (P36) Aydinlatma metni SALT-OKUMA (onay kapisindan AYRI rota:
  /// kullanici NEYI onayladigini sonradan gorebilmeli).
  static const kvkkMetin = '/kvkk-metin';
  /// (P168 §5) Bes yasal metnin tamami + onay gecmisi (SALT OKUMA).
  static const yasalMetinler = '/yasal-metinler';
  /// (P38) Anketler — sakin oy verir; olusturma YONETIM/panel isidir.
  static const anketler = '/anketler';
  static const notifications = '/notifications';
  static const destek = '/destek';
  static const profile = '/profile';
  static const personel = '/personel';
  static const sakinler = '/sakinler';
  static const aracGecis = '/arac-gecisleri';
  static const otopark = '/otopark';
  // (P139.3) Ana ekran izgarasini duzenleme — mevcut ekranlara ek bir
  // YUZEY degil, gorunum ayari.
  static const izgaraDuzenle = '/ana-ekran-duzenle';
  static const ihlaller = '/ihlaller';
  static const plakaOlaylari = '/plaka-okumalari';
}

/// Push bildirimi DATA'sindan hedef rota uretir (tiklama yonlendirmesi).
/// Bilinmeyen/eksik tip → null (yonlendirme yapilmaz, uygulama oldugu
/// yerde kalir). Backend data sozlesmesi: contracts/openapi.yaml.
String? routeForPushData(Map<String, String> data) {
  switch (data['tip']) {
    // Yeni talep (yonetime) / talep yaniti (sakine) → ilgili talep acilir.
    case 'talep':
    case 'talep_yanit':
      final id = data['complaint_id'];
      return id == null || id.isEmpty
          ? AppRoutes.complaints
          : '${AppRoutes.complaints}?complaint_id=$id';
    // Ziyaretci LOG kaydi (hedef sakine bilgilendirme) → ilgili kayit acilir.
    // (Onay/red kaldirildi; 'ziyaretci_sonuc' push'u artik yok.)
    case 'ziyaretci':
      final id = data['visitor_id'];
      return id == null || id.isEmpty
          ? AppRoutes.visitors
          : '${AppRoutes.visitors}?visitor_id=$id';
    // Gelen paket (daire sakinlerine) → ilgili kargo kaydi acilir.
    case 'kargo':
      final id = data['kargo_id'];
      return id == null || id.isEmpty
          ? AppRoutes.kargo
          : '${AppRoutes.kargo}?kargo_id=$id';
    // Tek-seferlik erisim talebi (dairenin sakinine, Onayla/Reddet) VEYA
    // sonuc (talebi acan yonetici/admin'e) → izin ekrani acilir. Liste zaten
    // ilgili kaydi one alir; ekran icinde deep-link id'ye gerek yok.
    case 'erisim_talebi':
    case 'erisim_sonuc':
      return AppRoutes.unitAccess;
    // Yeni talep (yonetime) / karar (talep eden sakine) → ilgili rezervasyon.
    case 'rezervasyon':
    case 'rezervasyon_karar':
      final id = data['rezervasyon_id'];
      return id == null || id.isEmpty
          ? AppRoutes.rezervasyon
          : '${AppRoutes.rezervasyon}?rezervasyon_id=$id';
    // Yeni etkinlik duyurusu (sakinlere) → ilgili etkinlik acilir.
    case 'etkinlik':
      final id = data['etkinlik_id'];
      return id == null || id.isEmpty
          ? AppRoutes.etkinlik
          : '${AppRoutes.etkinlik}?etkinlik_id=$id';
    case 'duyuru':
      return AppRoutes.announcements;
    // (P181 Bölüm 10.1) DEVRİYE alarmları — görevliye KİŞİ olarak gider
    // (uzak/gecikmiş okutmayı düzeltebilecek kişi odur) → aktif tur ekranı.
    case 'gecikmis_okutma':
    case 'uzak_okutma':
      return AppRoutes.patrol;
    // Kaçırılan tur → yönetime rol olarak gider; plan/pencere genel görünümü.
    case 'kacirilan_tur':
      return AppRoutes.patrolPlans;
    // (P181 Bölüm 10.2) Vardiya sonu özeti → yönetime; vardiyalar ekranı.
    case 'vardiya_ozeti':
      return AppRoutes.vardiyalar;
    default:
      return null;
  }
}

/// Auth durumundaki degisimleri go_router'a bildiren kopru. `status` her
/// degistiginde router redirect'i yeniden degerlendirilir.
class _AuthRouterListenable extends ChangeNotifier {
  _AuthRouterListenable(Ref ref) {
    ref.listen(
      // Parola-kurulum akisina giris/cikis da yonlendirme gerektirir.
      authControllerProvider.select((s) => (s.status, s.setupToken)),
      (_, _) => notifyListeners(),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRouterListenable(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    // Ana ekran "geri donuldu" sinyalini bu gozlemciden alir (RouteAware) —
    // baska ekrandan donunce sayaclar/akis yenilenir (bkz. home_refresh.dart).
    observers: [homeRouteObserver],
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.setPassword,
        builder: (context, state) => const SetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.kayit,
        builder: (context, state) => const KayitScreen(),
      ),
      // (P155 §7/§8) DAVET DERIN BAGLANTISI. Universal/App Link
      // `https://<portal>/davet/<jeton>` -> Flutter yolu `/davet/<jeton>`
      // -> bu rota. Jeton yol parametresidir; ekran onu cozup yontem
      // sectirir (tesis kodu/daire SORULMAZ).
      GoRoute(
        path: '/davet/:jeton',
        builder: (context, state) =>
            DavetScreen(jeton: state.pathParameters['jeton'] ?? ''),
      ),
      GoRoute(
        // Onboarding Model A: yonetici ilk giriste tesisi adlandirmamissa
        // kapi once kurulum ekranini gosterir (bkz. HomeGate).
        path: AppRoutes.home,
        builder: (context, state) => const HomeGate(),
      ),
      GoRoute(
        path: AppRoutes.nfc,
        builder: (context, state) => const NfcScreen(),
      ),
      GoRoute(
        path: AppRoutes.outbox,
        builder: (context, state) => const OutboxScreen(),
      ),
      GoRoute(
        path: AppRoutes.patrol,
        builder: (context, state) => const PatrolScreen(),
      ),
      GoRoute(
        path: AppRoutes.tasks,
        // ?gorunum=yonetim → Gorev-YONETIMI gorunumu (tum liste, "Herkes"
        // kapsami); parametresiz → "Gorevlerim" (bana atananlar).
        builder: (context, state) => TasksScreen(
          yonetimGorunumu: state.uri.queryParameters['gorunum'] == 'yonetim',
        ),
      ),
      GoRoute(
        path: AppRoutes.yoneticiIletisim,
        builder: (context, state) => const YoneticiIletisimScreen(),
      ),
      GoRoute(
        path: AppRoutes.assets,
        builder: (context, state) => const AssetsScreen(),
      ),
      GoRoute(
        path: AppRoutes.announcements,
        builder: (context, state) => const AnnouncementsScreen(),
      ),
      GoRoute(
        path: AppRoutes.patrolTracking,
        builder: (context, state) => const PatrolTrackingScreen(),
      ),
      GoRoute(
        path: AppRoutes.patrolPlans,
        builder: (context, state) => const PatrolPlansScreen(),
      ),
      GoRoute(
        path: AppRoutes.checkpoints,
        builder: (context, state) => const CheckpointsScreen(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: AppRoutes.vardiyalar,
        builder: (context, state) => const VardiyalarScreen(),
      ),
      GoRoute(
        path: AppRoutes.kameralar,
        builder: (context, state) => const KameralarScreen(),
      ),
      GoRoute(
        path: AppRoutes.kameraIzle,
        builder: (context, state) =>
            CameraPlayerScreen(kamera: state.extra as Camera),
      ),
      GoRoute(
        path: AppRoutes.budget,
        builder: (context, state) => const BudgetScreen(),
      ),
      GoRoute(
        path: AppRoutes.financialSummary,
        builder: (context, state) => const FinancialSummaryScreen(),
      ),
      GoRoute(
        path: AppRoutes.siteBudget,
        builder: (context, state) => const SiteBudgetScreen(),
      ),
      GoRoute(
        path: AppRoutes.transparency,
        builder: (context, state) => const TransparencyScreen(),
      ),
      GoRoute(
        path: AppRoutes.myDues,
        builder: (context, state) => const MyDuesScreen(),
      ),
      GoRoute(
        path: AppRoutes.complaints,
        // Push tiklamasindan gelinirse ?complaint_id=... ile ilgili talep
        // detayi otomatik acilir.
        // `?bildir=1` — ana ekranin "Olay/Talep bildir" kisayolu (P22c):
        // form aninda acilir, gonderimden sonra ana ekrana donulur.
        builder: (context, state) => ComplaintsScreen(
          initialComplaintId: state.uri.queryParameters['complaint_id'],
          bildirModu: state.uri.queryParameters['bildir'] == '1',
        ),
      ),
      GoRoute(
        path: AppRoutes.aracGecis,
        builder: (context, state) => const VehiclePassScreen(),
      ),
      GoRoute(
        path: AppRoutes.izgaraDuzenle,
        builder: (context, state) => const IzgaraDuzenleScreen(),
      ),
      GoRoute(
        path: AppRoutes.otopark,
        builder: (context, state) => const ParkingScreen(),
      ),
      GoRoute(
        path: AppRoutes.ihlaller,
        builder: (context, state) => const ViolationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.plakaOlaylari,
        builder: (context, state) => const AnprScreen(),
      ),
      GoRoute(
        path: AppRoutes.visitors,
        // Push tiklamasindan gelinirse ?visitor_id=... ile ilgili kaydin
        // detayi otomatik acilir (onay bekleyen kartta Onayla/Reddet).
        builder: (context, state) => VisitorsScreen(
          initialVisitorId: state.uri.queryParameters['visitor_id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.kargo,
        // Push tiklamasindan gelinirse ?kargo_id=... ile ilgili kaydin
        // detayi otomatik acilir (bekleyen pakette "Teslim aldim").
        builder: (context, state) =>
            KargoScreen(initialKargoId: state.uri.queryParameters['kargo_id']),
      ),
      GoRoute(
        path: AppRoutes.unitAccess,
        builder: (context, state) => const UnitAccessScreen(),
      ),
      GoRoute(
        path: AppRoutes.unitAccessRecords,
        // Onaylanan tek-seferlik izinle bir dairenin ziyaretci/kargo kayitlari
        // (?unit_id=&unit_no=&kind=visitor|kargo). unit_id yoksa izin ekranina
        // geri don.
        redirect: (context, state) =>
            (state.uri.queryParameters['unit_id'] ?? '').isEmpty
            ? AppRoutes.unitAccess
            : null,
        builder: (context, state) => UnitAccessRecordsScreen(
          unitId: state.uri.queryParameters['unit_id']!,
          unitNo: state.uri.queryParameters['unit_no'],
          kind: state.uri.queryParameters['kind'] ?? 'visitor',
        ),
      ),
      GoRoute(
        path: AppRoutes.rezervasyon,
        // Push tiklamasindan gelinirse ?rezervasyon_id=... ile ilgili kaydin
        // detayi otomatik acilir (yonetimde Onayla/Reddet ile).
        builder: (context, state) => RezervasyonScreen(
          initialRezervasyonId: state.uri.queryParameters['rezervasyon_id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.etkinlik,
        // Push tiklamasindan gelinirse ?etkinlik_id=... ile ilgili etkinligin
        // detayi otomatik acilir (sakinde Katiliyorum/Katilmiyorum ile).
        builder: (context, state) => EtkinlikScreen(
          initialEtkinlikId: state.uri.queryParameters['etkinlik_id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.siteKurallari,
        builder: (context, state) => const SiteKuraliScreen(),
      ),
      GoRoute(
        path: AppRoutes.dokumanlar,
        builder: (context, state) => const DokumanScreen(),
      ),
      GoRoute(
        path: AppRoutes.yasalMetinler,
        builder: (context, state) => const YasalMetinlerScreen(),
      ),
      GoRoute(
        path: AppRoutes.disHizmet,
        builder: (context, state) => const DisHizmetScreen(),
      ),
      GoRoute(
        path: AppRoutes.integrations,
        builder: (context, state) => const IntegrationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.binaDuzenleme,
        builder: (context, state) => const BinaDuzenlemeScreen(),
      ),
      GoRoute(
        path: AppRoutes.sikayetHaritasi,
        builder: (context, state) => const BuildingSchematicScreen(),
      ),
      GoRoute(
        path: AppRoutes.sikayetlerim,
        builder: (context, state) => const MyComplaintsScreen(),
      ),
      GoRoute(
        path: AppRoutes.sikayetKuyrugu,
        builder: (context, state) => const SikayetKuyruguScreen(),
      ),
      GoRoute(
        path: AppRoutes.ode,
        builder: (context, state) => const OdeScreen(),
      ),
      GoRoute(
        path: AppRoutes.daireTanimlari,
        builder: (context, state) => const UnitTanimlariScreen(),
      ),
      GoRoute(
        path: AppRoutes.taskDetail,
        // Detay, listeden secilen Task nesnesiyle acilir (extra). Dogrudan
        // URL ile gelinirse (extra yok) listeye yonlendirilir.
        redirect: (context, state) =>
            state.extra is Task ? null : AppRoutes.tasks,
        builder: (context, state) =>
            TaskDetailScreen(task: state.extra! as Task),
      ),
      GoRoute(
        // Gorev kategorisi yonetimi (A6) — yonetici; giris "Gorev yonetimi"
        // ekranindaki AppBar aksiyonundan. Backend RBAC yazmayi zorlar.
        path: AppRoutes.taskCategories,
        builder: (context, state) => const TaskCategoriesScreen(),
      ),
      GoRoute(
        // (P166 §8.2) Kurulum sihirbazi. Giris noktalari: ilk giristeki
        // hatirlatici, ana ekrandaki "Tum Moduller" ve Ayarlar.
        path: AppRoutes.kurulum,
        builder: (context, state) => const KurulumScreen(),
      ),
      GoRoute(
        path: AppRoutes.anketler,
        builder: (context, state) => const AnketScreen(),
      ),
      GoRoute(
        path: AppRoutes.kvkkMetin,
        builder: (context, state) => const KvkkMetinScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        // Bildirimler inbox — RBAC: admin+yonetici+security (sakin/tesis
        // gorevlisi ekranlarindan baglanmaz).
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        // Destek (WP1) — yonetici -> Yonetio ekibi (RBAC backend'de).
        path: AppRoutes.destek,
        builder: (context, state) => const DestekScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.personel,
        builder: (context, state) => const StaffScreen(),
      ),
      GoRoute(
        path: AppRoutes.sakinler,
        builder: (context, state) => const ResidentsScreen(),
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final status = auth.status;
      final location = state.matchedLocation;

      // Oturum henuz cozulmedi → splash'ta bekle.
      if (status == AuthStatus.unknown) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // (P155 §7/§8) DAVET derin baglantisi oturumdan BAGIMSIZDIR: bagi
      // acan kisi oturumsuzdur ve kaydini burada tamamlar. Oturumu OLAN
      // birine davet gelirse (nadir) davet ekranini gostermeye devam
      // etmeyiz — ana ekrana atariz; yoksa zaten kayitli biri kendini
      // yeniden kaydetmeye calisirdi.
      final davettte = location.startsWith(AppRoutes.davet);

      final loggedIn = status == AuthStatus.authenticated;
      final onAuthFlow =
          location == AppRoutes.login ||
          location == AppRoutes.splash ||
          // (P154) Kayit da bir OTURUM ONCESI ekrandir: oturum acilinca
          // buradan da ana ekrana gecilmeli, yoksa kaydini bitiren
          // kullanici kayit formunda asili kalirdi.
          location == AppRoutes.kayit ||
          davettte ||
          location == AppRoutes.setPassword;

      if (loggedIn) {
        return onAuthFlow ? AppRoutes.home : null;
      }
      // Oturum yok + davet bagi → davet ekranini GOSTER (login'e atma).
      if (davettte) return null;
      // Sakinin gecici kodla ilk girisi → zorunlu parola belirleme ekrani.
      if (auth.setupToken != null) {
        return location == AppRoutes.setPassword ? null : AppRoutes.setPassword;
      }
      // (P154 / Asama 2) ILK ACILIS ROL LISTESINE DUSER — girise degil.
      // Brief: "uygulamayi indirip ilk actiginda ekranda 'Size uygun olanı
      // seçiniz' yazar ve rol listesi cikar."
      //
      // YALNIZ SPLASH'TAN: kullanici rol listesinden girise gectiyse
      // (`login-kayit-baglantisi`nin tersi) onu geri surukleyemeyiz;
      // bayrak zaten ekran acilirken yaziliyor ama yazma ASENKRON ve
      // yonlendirme SENKRON — kosulu splash'a baglamak ikisinin
      // yarismasini imkânsiz kilar.
      if (location == AppRoutes.splash &&
          ref.read(rolSecimiBekliyorProvider)) {
        return AppRoutes.kayit;
      }
      // Oturum yok → login disindaki her yerden login'e. (P154) `/kayit`
      // de oturumsuz erisilebilir olmali; aksi hâlde kaydolmak icin once
      // giris yapmak gerekirdi.
      return location == AppRoutes.login || location == AppRoutes.kayit
          ? null
          : AppRoutes.login;
    },
  );
});
