import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';

void main() {
  group('homeMenuForRole (auth.md §4 UX aynasi)', () {
    test('admin ve security tum operasyon kartlarini gorur '
        '(admin ek olarak talepleri)', () {
      expect(homeMenuForRole(UserRole.admin), const [
        HomeMenuEntry.emergency,
        HomeMenuEntry.announcements,
        HomeMenuEntry.complaints,
        HomeMenuEntry.patrol,
        HomeMenuEntry.tasks,
        HomeMenuEntry.assets,
        HomeMenuEntry.nfc,
        HomeMenuEntry.outbox,
      ]);
      expect(homeMenuForRole(UserRole.security), const [
        HomeMenuEntry.emergency,
        HomeMenuEntry.announcements,
        HomeMenuEntry.patrol,
        HomeMenuEntry.tasks,
        HomeMenuEntry.assets,
        HomeMenuEntry.nfc,
        HomeMenuEntry.outbox,
      ]);
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
          HomeMenuEntry.complaints,
          HomeMenuEntry.patrolTracking,
          HomeMenuEntry.taskTracking,
          HomeMenuEntry.reports,
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

    test('resident: duyurular + Sikayet/Oneri + Aidatim', () {
      expect(homeMenuForRole(UserRole.resident), const [
        HomeMenuEntry.announcements,
        HomeMenuEntry.complaints,
        HomeMenuEntry.myDues,
      ]);
    });

    test('Sikayet/Oneri saha rollerinde YOK (sakin<->yonetim kanali)', () {
      for (final role in [UserRole.security, UserRole.tesisGorevlisi]) {
        expect(
          homeMenuForRole(role),
          isNot(contains(HomeMenuEntry.complaints)),
          reason: role.wire,
        );
      }
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.resident,
      ]) {
        expect(
          homeMenuForRole(role),
          contains(HomeMenuEntry.complaints),
          reason: role.wire,
        );
      }
    });

    test('Aidatim yalniz resident menusunde (/me/dues resident-only)', () {
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.security,
        UserRole.tesisGorevlisi,
      ]) {
        expect(
          homeMenuForRole(role),
          isNot(contains(HomeMenuEntry.myDues)),
          reason: role.wire,
        );
      }
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
