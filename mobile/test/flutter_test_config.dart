/// TEST SUITE ONHAZIRLIGI — `flutter test` her test dosyasindan ONCE burayi
/// calistirir (Flutter'in `flutter_test_config.dart` kancasi).
///
/// NEDEN: `DateFormat('tr')`/`DateFormat('ar')` gibi DILE BAGLI bicimleyiciler
/// intl'in locale verisini gerektirir. Uygulamada bu veriyi
/// `GlobalMaterialLocalizations` yukler; saf birim testlerinde (widget kabugu
/// olmadan mapper cagiran testler) yuklenmedigi icin
/// "Locale data has not been initialized" hatasi duser. Burada BIR KEZ
/// baslatiliyor.
library;

import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  initializeDateFormatting();
  await testMain();
}
