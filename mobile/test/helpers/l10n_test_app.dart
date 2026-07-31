/// Widget testleri icin YERELLESTIRME KABUGU.
///
/// Uygulamanin ekranlari `context.l10n` okur; bu yuzden testte de
/// `AppLocalizations` delegeleri kurulmalidir. Yalin `MaterialApp` ile
/// cizilen ekran "Null check operator used on a null value" ile duser.
///
/// VARSAYILAN DIL TURKCE'dir: mevcut testlerin (ve altin gorsellerin) TR
/// metin beklentileri korunur. Dil-duyarli testler [locale] gecer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mobile/l10n/gen/app_localizations.dart';
import 'package:mobile/src/core/i18n/locale_controller.dart';

/// SURUS TEMASI (tur 32) — kurulunca [l10nApp] ile uretilen HER
/// `MaterialApp` bu temayi alir.
///
/// Neden global bir anahtar: koyu tema surusu, mevcut surus kuruculariyla
/// (`_destekEkrani(Locale)` gibi, her biri kendi `l10nApp`ini cagirir) ayni
/// ekranlari surer. Her kurucuya tema parametresi eklemek yerine tek
/// anahtar cevrilir; `koyuTemaSurusu` bunu kendi `addTearDown`unda geri
/// alir, yani sizinti olmaz.
ThemeData? testTemasi;

const testLocalizationsDelegates = <LocalizationsDelegate<Object>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Yerellestirilmis `MaterialApp` — testlerde `MaterialApp(home: x)` yerine.
MaterialApp l10nApp(
  Widget home, {
  Locale locale = const Locale('tr'),
  GlobalKey<NavigatorState>? navigatorKey,
  List<NavigatorObserver> navigatorObservers = const [],
}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: testLocalizationsDelegates,
      navigatorKey: navigatorKey,
      navigatorObservers: navigatorObservers,
      theme: testTemasi,
      home: home,
    );

/// `GoRouter` ile yerellestirilmis uygulama — yonlendirme YAPAN ekranlar
/// icin (`context.push` duz `MaterialApp`ta "No GoRouter found" atar).
MaterialApp l10nRouterApp(
  RouterConfig<Object> router, {
  Locale locale = const Locale('tr'),
}) => MaterialApp.router(
  locale: locale,
  supportedLocales: supportedLocales,
  localizationsDelegates: testLocalizationsDelegates,
  theme: testTemasi,
  routerConfig: router,
);

/// Kaydirilabilir `Scaffold` govdesi + yerellestirme (widget parcalari icin).
MaterialApp l10nScaffold(Widget child, {Locale locale = const Locale('tr')}) =>
    l10nApp(
      Scaffold(body: SingleChildScrollView(child: child)),
      locale: locale,
    );
