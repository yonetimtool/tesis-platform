import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/announcements/presentation/announcements_screen.dart';
import '../features/assets/presentation/assets_screen.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/complaints/presentation/complaints_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/set_password_screen.dart';
import '../features/budget/presentation/budget_screen.dart';
import '../features/building_map/presentation/building_map_screen.dart';
import '../features/building_map/presentation/building_schematic_screen.dart';
import '../features/budget/presentation/financial_summary_screen.dart';
import '../features/budget/presentation/site_budget_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/kargo/presentation/kargo_screen.dart';
import '../features/nfc/presentation/nfc_screen.dart';
import '../features/dues/presentation/my_dues_screen.dart';
import '../features/emergency/presentation/emergency_screen.dart';
import '../features/etkinlik/presentation/etkinlik_screen.dart';
import '../features/patrol/presentation/patrol_screen.dart';
import '../features/patrol/presentation/patrol_tracking_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/rezervasyon/presentation/rezervasyon_screen.dart';
import '../features/scan/presentation/outbox_screen.dart';
import '../features/site_kurali/presentation/site_kurali_screen.dart';
import '../features/tasks/domain/task_models.dart';
import '../features/tasks/presentation/task_categories_screen.dart';
import '../features/tasks/presentation/task_detail_screen.dart';
import '../features/tasks/presentation/tasks_screen.dart';
import '../features/unit_access/presentation/unit_access_records_screen.dart';
import '../features/integrations/presentation/integrations_screen.dart';
import '../features/unit_access/presentation/unit_access_screen.dart';
import '../features/visitors/presentation/visitors_screen.dart';
import 'splash_screen.dart';

class AppRoutes {
  const AppRoutes._();
  static const splash = '/splash';
  static const login = '/login';
  static const setPassword = '/set-password';
  static const home = '/home';
  static const nfc = '/nfc';
  static const outbox = '/outbox';
  static const patrol = '/patrol';
  static const tasks = '/tasks';
  static const taskDetail = '/tasks/detail';
  static const taskCategories = '/tasks/categories';
  static const emergency = '/emergency';
  static const assets = '/assets';
  static const announcements = '/announcements';
  static const patrolTracking = '/patrol-tracking';
  static const reports = '/reports';
  static const budget = '/budget';
  static const financialSummary = '/financial-summary';
  static const siteBudget = '/site-budget';
  static const myDues = '/my-dues';
  static const complaints = '/complaints';
  static const visitors = '/visitors';
  static const kargo = '/kargo';
  static const unitAccess = '/unit-access';
  static const unitAccessRecords = '/unit-access/records';
  static const rezervasyon = '/rezervasyon';
  static const etkinlik = '/etkinlik';
  static const siteKurallari = '/site-kurallari';
  static const integrations = '/integrations';
  static const binaYerlesimi = '/bina-yerlesimi';
  static const sikayetHaritasi = '/sikayet-haritasi';
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
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
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
        path: AppRoutes.emergency,
        builder: (context, state) => const EmergencyScreen(),
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
        path: AppRoutes.reports,
        builder: (context, state) => const ReportsScreen(),
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
        path: AppRoutes.myDues,
        builder: (context, state) => const MyDuesScreen(),
      ),
      GoRoute(
        path: AppRoutes.complaints,
        // Push tiklamasindan gelinirse ?complaint_id=... ile ilgili talep
        // detayi otomatik acilir.
        builder: (context, state) => ComplaintsScreen(
          initialComplaintId: state.uri.queryParameters['complaint_id'],
        ),
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
        builder: (context, state) => KargoScreen(
          initialKargoId: state.uri.queryParameters['kargo_id'],
        ),
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
        path: AppRoutes.integrations,
        builder: (context, state) => const IntegrationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.binaYerlesimi,
        builder: (context, state) => const BuildingMapScreen(),
      ),
      GoRoute(
        path: AppRoutes.sikayetHaritasi,
        builder: (context, state) => const BuildingSchematicScreen(),
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
    ],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final status = auth.status;
      final location = state.matchedLocation;

      // Oturum henuz cozulmedi → splash'ta bekle.
      if (status == AuthStatus.unknown) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final loggedIn = status == AuthStatus.authenticated;
      final onAuthFlow = location == AppRoutes.login ||
          location == AppRoutes.splash ||
          location == AppRoutes.setPassword;

      if (loggedIn) {
        return onAuthFlow ? AppRoutes.home : null;
      }
      // Sakinin gecici kodla ilk girisi → zorunlu parola belirleme ekrani.
      if (auth.setupToken != null) {
        return location == AppRoutes.setPassword ? null : AppRoutes.setPassword;
      }
      // Oturum yok → login disindaki her yerden login'e.
      return location == AppRoutes.login ? null : AppRoutes.login;
    },
  );
});
