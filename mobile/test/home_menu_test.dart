import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';

void main() {
  group('homeMenuForRole (auth.md §4 UX aynasi)', () {
    test('admin ve security tum operasyon kartlarini gorur', () {
      const beklenen = [
        HomeMenuEntry.emergency,
        HomeMenuEntry.announcements,
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
          HomeMenuEntry.announcements,
          HomeMenuEntry.tasks,
          HomeMenuEntry.assets,
          HomeMenuEntry.nfc,
          HomeMenuEntry.outbox,
        ]),
      );
    });

    test(
        'yonetici: acil durum + duyurular + devriye TAKIBI + gorev TAKIBI; '
        'saha kartlari yok', () {
      final menu = homeMenuForRole(UserRole.yonetici);
      expect(
        menu,
        const [
          HomeMenuEntry.emergency,
          HomeMenuEntry.announcements,
          HomeMenuEntry.patrolTracking,
          HomeMenuEntry.taskTracking,
          HomeMenuEntry.yoneticiInfo,
        ],
      );
      expect(menu, isNot(contains(HomeMenuEntry.tasks)));
      expect(menu, isNot(contains(HomeMenuEntry.nfc)));
      expect(menu, isNot(contains(HomeMenuEntry.assets)));
      expect(menu, isNot(contains(HomeMenuEntry.outbox)));
      expect(menu, isNot(contains(HomeMenuEntry.patrol))); // Turlarim degil
    });

    test('devriye TAKIBI yalniz yonetici menusunde (saha Turlarim kullanir)',
        () {
      for (final role in [
        UserRole.admin,
        UserRole.security,
        UserRole.tesisGorevlisi,
        UserRole.resident,
      ]) {
        expect(
          homeMenuForRole(role),
          isNot(contains(HomeMenuEntry.patrolTracking)),
          reason: role.wire,
        );
      }
    });

    test('resident: duyurular (ilk gercek kaynagi) + bilgi karti', () {
      expect(homeMenuForRole(UserRole.resident), const [
        HomeMenuEntry.announcements,
        HomeMenuEntry.residentInfo,
      ]);
    });

    test('unknown (rol cozulmeden/eski token) bos menu — yanlis kart yok', () {
      expect(homeMenuForRole(UserRole.unknown), isEmpty);
    });

    test('duyurulari 5 rolun 5i de gorur (okuma herkese acik)', () {
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.security,
        UserRole.tesisGorevlisi,
        UserRole.resident,
      ]) {
        expect(
          homeMenuForRole(role),
          contains(HomeMenuEntry.announcements),
          reason: role.wire,
        );
      }
    });
  });
}
