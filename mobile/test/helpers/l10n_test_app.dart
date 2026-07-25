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
      home: home,
    );

/// Kaydirilabilir `Scaffold` govdesi + yerellestirme (widget parcalari icin).
MaterialApp l10nScaffold(Widget child, {Locale locale = const Locale('tr')}) =>
    l10nApp(
      Scaffold(body: SingleChildScrollView(child: child)),
      locale: locale,
    );
