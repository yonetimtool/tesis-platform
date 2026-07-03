import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/nfc/presentation/nfc_screen.dart';
import '../features/patrol/presentation/patrol_screen.dart';
import '../features/scan/presentation/outbox_screen.dart';
import 'splash_screen.dart';

class AppRoutes {
  const AppRoutes._();
  static const splash = '/splash';
  static const login = '/login';
  static const home = '/home';
  static const nfc = '/nfc';
  static const outbox = '/outbox';
  static const patrol = '/patrol';
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
