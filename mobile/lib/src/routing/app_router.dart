import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/announcements/presentation/announcements_screen.dart';
import '../features/assets/presentation/assets_screen.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/nfc/presentation/nfc_screen.dart';
import '../features/emergency/presentation/emergency_screen.dart';
import '../features/patrol/presentation/patrol_screen.dart';
import '../features/patrol/presentation/patrol_tracking_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/scan/presentation/outbox_screen.dart';
import '../features/tasks/domain/task_models.dart';
import '../features/tasks/presentation/task_detail_screen.dart';
import '../features/tasks/presentation/tasks_screen.dart';
import 'splash_screen.dart';

class AppRoutes {
  const AppRoutes._();
  static const splash = '/splash';
  static const login = '/login';
  static const home = '/home';
  static const nfc = '/nfc';
  static const outbox = '/outbox';
  static const patrol = '/patrol';
  static const tasks = '/tasks';
  static const taskDetail = '/tasks/detail';
  static const emergency = '/emergency';
  static const assets = '/assets';
  static const announcements = '/announcements';
  static const patrolTracking = '/patrol-tracking';
  static const reports = '/reports';
}

/// Auth durumundaki degisimleri go_router'a bildiren kopru. `status` her
/// degistiginde router redirect'i yeniden degerlendirilir.
class _AuthRouterListenable extends ChangeNotifier {
  _AuthRouterListenable(Ref ref) {
    ref.listen(
      authControllerProvider.select((s) => s.status),
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
        builder: (context, state) => const TasksScreen(),
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
        path: AppRoutes.taskDetail,
        // Detay, listeden secilen Task nesnesiyle acilir (extra). Dogrudan
        // URL ile gelinirse (extra yok) listeye yonlendirilir.
        redirect: (context, state) =>
            state.extra is Task ? null : AppRoutes.tasks,
        builder: (context, state) =>
            TaskDetailScreen(task: state.extra! as Task),
      ),
    ],
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final location = state.matchedLocation;

      // Oturum henuz cozulmedi → splash'ta bekle.
      if (status == AuthStatus.unknown) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final loggedIn = status == AuthStatus.authenticated;
      final onAuthFlow =
          location == AppRoutes.login || location == AppRoutes.splash;

      if (loggedIn) {
        return onAuthFlow ? AppRoutes.home : null;
      }
      // Oturum yok → login disindaki her yerden login'e.
      return location == AppRoutes.login ? null : AppRoutes.login;
    },
  );
});
