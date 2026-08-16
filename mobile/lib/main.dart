import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Dile bagli tarih/saat bicimleyicileri icin locale verisi (intl).
import 'package:intl/date_symbol_data_local.dart';

import 'l10n/gen/app_localizations.dart';
import 'src/core/i18n/locale_controller.dart';
import 'src/core/startup/acilis_tercihleri.dart';
import 'src/core/teshis/teshis.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/theme/theme_controller.dart';
import 'src/features/push/presentation/push_registrar.dart';
import 'src/features/push/presentation/push_setup.dart';
import 'src/features/scan/data/scan_outbox.dart';
import 'src/routing/app_router.dart';

Future<void> main() async {
  // Depo okumasi platform kanali kullanir → baglama once kurulmalidir.
  WidgetsFlutterBinding.ensureInitialized();
  // 7 dilin tarih/ay/gun adlari icin intl locale verisi — bicimleyiciler
  // widget agacindan BAGIMSIZ da cagrilabildigi icin acikca baslatilir.
  initializeDateFormatting();
  // ILK KARE DOGRU DILDE: dil/tema tercihi runApp'ten ONCE okunur (tek depo
  // okumasi; platformun kendi acilis ekraninda gecer, yeni splash YOK).
  // Eskiden bunlar asenkron okunuyordu → ilk kare varsayilan dille cizilip
  // hemen yenileniyordu; kullanicinin gordugu METIN TITREMESI buydu.
  final tercihler = await acilisTercihleriniOku();
  // (P119) CALISAN PAKETIN GERCEKLERI konsola yazilir (yalniz iOS).
  // Beklenmez: `await` etmek ilk kareyi bir platform cagrisi kadar
  // geciktirirdi ve teshis, acilis hizindan onemli degildir.
  teshisBlogunuYazdir().ignore();
  runApp(ProviderScope(
    overrides: [acilisTercihleriProvider.overrideWithValue(tercihler)],
    child: const TesisGuvenlikApp(),
  ));
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
    // Dil: kullanici secimi (kalici) — null ise cihaz dili, o da
    // desteklenmiyorsa Turkce (bkz. localeCozumle). Secim degisince
    // MaterialApp yeniden cizilir; UYGULAMA YENIDEN BASLAMAZ.
    final locale = ref.watch(aktifLocaleProvider);

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
      title: 'Yönetiyor',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Cihaz dili desteklenmiyorsa Turkce'ye duser (ulke kodu yok sayilir).
      localeResolutionCallback: (cihaz, desteklenen) =>
          localeCozumle(cihaz, desteklenen),
      routerConfig: router,
    );
  }
}
