/// (P253 §B) Yoneticinin "Otopark ve arac gecisleri" girisi ARAC GECISI
/// ekranini acar (web'deki ayni adli sayfanin karsiligi: liste + doluluk).
/// Eskiden yalniz agregat doluluk ekranini aciyordu; arac giris/cikis
/// listesi yalniz amirin menusundeydi.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/home/presentation/module_card_spec.dart';
import 'package:mobile/src/routing/app_router.dart';

void main() {
  test('yonetici menusunde Otopark girisi var ve ARAC GECISI ekranina gider', () {
    expect(homeMenuForRole(UserRole.yonetici), contains(HomeMenuEntry.otopark));
    expect(moduleCardSpec(HomeMenuEntry.otopark).route, AppRoutes.aracGecis);
  });
}
