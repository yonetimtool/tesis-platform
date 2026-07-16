import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/core/theme/app_theme.dart';
import 'src/core/theme/theme_controller.dart';
import 'src/features/push/presentation/push_registrar.dart';
import 'src/features/push/presentation/push_setup.dart';
import 'src/features/scan/data/scan_outbox.dart';
import 'src/routing/app_router.dart';

void main() {
  runApp(const ProviderScope(child: TesisGuvenlikApp()));
}

/// On plan push bildirimini SnackBar ile gostermek icin kok messenger.
/// (Arka plan/kapali durumda FCM bildirimi sistem tepsisine kendisi dusurur;
/// on planda dusurmez — biz gosteririz.)
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class TesisGuvenlikApp extends ConsumerWidget {
  const TesisGuvenlikApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Outbox otomatik senkron tetikleyicileri (baglanti/on plana gelme/login)
    // uygulama boyunca canli kalsin.
    ref.watch(outboxAutoSyncProvider);
    // Push: login sonrasi FCM token kaydi (Firebase yoksa sessizce devre disi).
    ref.watch(pushSetupProvider);
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // On planda gelen push → SnackBar; hedefi olan bildirimde "Ac" aksiyonu
    // ilgili ekrana goturur (on plan mesaji tepsiye dusmez — tiklama bu).
    ref.listen(pushRegistrarProvider.select((s) => s.sonBildirim),
        (prev, next) {
      if (next == null || identical(prev, next)) return;
      final route = routeForPushData(next.data);
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(next.displayText),
          duration: const Duration(seconds: 5),
          action: route == null
              ? null
              : SnackBarAction(label: 'Ac', onPressed: () => router.push(route)),
        ),
      );
    });

    // Tepsideki bildirime tiklama (arka plan/kapali) → ilgili ekran.
    // Bilinmeyen tip'te yonlendirme yapilmaz. Oturum yoksa router redirect
    // login'e dusurur (hedef korunmaz — bilinen kisit, giriste ana ekran).
    ref.listen(pushRegistrarProvider.select((s) => s.sonTiklanan),
        (prev, next) {
      if (next == null || identical(prev, next)) return;
      final route = routeForPushData(next.data);
      if (route != null) router.push(route);
    });
    return MaterialApp.router(
      title: 'Yönetio',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
