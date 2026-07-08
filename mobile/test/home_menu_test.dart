import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';

void main() {
  group('homeMenuForRole (auth.md §4 UX aynasi)', () {
    test('admin ve security tum operasyon kartlarini gorur', () {
      const beklenen = [
        HomeMenuEntry.emergency,
        HomeMenuEntry.patrol,
        HomeMenuEntry.tasks,
        HomeMenuEntry.assets,
        HomeMenuEntry.nfc,
        HomeMenuEntry.outbox,
      ];
      expect(homeMenuForRole(UserRole.admin), beklenen);
      expect(homeMenuForRole(UserRole.security), beklenen);
    });

    test('tesis_gorevlisi Turlarim GORMEZ (me/patrol-window admin+security)',
        () {
      final menu = homeMenuForRole(UserRole.tesisGorevlisi);
      expect(menu, isNot(contains(HomeMenuEntry.patrol)));
      expect(
        menu,
        containsAll(const [
          HomeMenuEntry.emergency,
          HomeMenuEntry.tasks,
          HomeMenuEntry.assets,
          HomeMenuEntry.nfc,
          HomeMenuEntry.outbox,
        ]),
      );
    });

    test('yonetici: acil durum + gorev TAKIBI; saha kaniti kartlari yok', () {
      final menu = homeMenuForRole(UserRole.yonetici);
      expect(
        menu,
        const [
          HomeMenuEntry.emergency,
          HomeMenuEntry.taskTracking,
          HomeMenuEntry.yoneticiInfo,
        ],
      );
      expect(menu, isNot(contains(HomeMenuEntry.tasks)));
      expect(menu, isNot(contains(HomeMenuEntry.nfc)));
      expect(menu, isNot(contains(HomeMenuEntry.assets)));
      expect(menu, isNot(contains(HomeMenuEntry.outbox)));
      expect(menu, isNot(contains(HomeMenuEntry.patrol)));
    });

    test('resident yalniz bilgi karti gorur (acil durum POST 403)', () {
      expect(homeMenuForRole(UserRole.resident), const [
        HomeMenuEntry.residentInfo,
      ]);
    });

    test('unknown (rol cozulmeden/eski token) bos menu — yanlis kart yok', () {
      expect(homeMenuForRole(UserRole.unknown), isEmpty);
    });
  });
}
