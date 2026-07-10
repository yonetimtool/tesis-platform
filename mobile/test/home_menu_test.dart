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
        HomeMenuEntry.visitors,
        HomeMenuEntry.kargo,
        HomeMenuEntry.rezervasyon,
        HomeMenuEntry.patrol,
        HomeMenuEntry.tasks,
        HomeMenuEntry.assets,
        HomeMenuEntry.nfc,
        HomeMenuEntry.outbox,
      ]);
      expect(homeMenuForRole(UserRole.security), const [
        HomeMenuEntry.emergency,
        HomeMenuEntry.announcements,
        HomeMenuEntry.complaints,
        HomeMenuEntry.visitors,
        HomeMenuEntry.kargo,
        HomeMenuEntry.patrol,
        HomeMenuEntry.tasks,
        HomeMenuEntry.taskTracking,
        HomeMenuEntry.assets,
        HomeMenuEntry.nfc,
        HomeMenuEntry.outbox,
      ]);
    });

    test('Gorev-YONETIMI karti (kesin matris): yonetici+security+'
        'tesis_gorevlisi VAR, resident YOK; "Gorevlerim" saha rollerinde '
        'AYRICA durur (korundu)', () {
      for (final role in [
        UserRole.yonetici,
        UserRole.security,
        UserRole.tesisGorevlisi,
      ]) {
        expect(
          homeMenuForRole(role),
          contains(HomeMenuEntry.taskTracking),
          reason: role.wire,
        );
      }
      expect(
        homeMenuForRole(UserRole.resident),
        isNot(contains(HomeMenuEntry.taskTracking)),
      );
      expect(
        homeMenuForRole(UserRole.resident),
        isNot(contains(HomeMenuEntry.tasks)),
      );
      // "Gorevlerim" saha rollerinde ayrica durur — iki kart birlikte.
      for (final role in [UserRole.security, UserRole.tesisGorevlisi]) {
        expect(
          homeMenuForRole(role),
          containsAll(const [HomeMenuEntry.tasks, HomeMenuEntry.taskTracking]),
          reason: role.wire,
        );
      }
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
          HomeMenuEntry.visitors,
          HomeMenuEntry.kargo,
          HomeMenuEntry.rezervasyon,
          HomeMenuEntry.patrolTracking,
          HomeMenuEntry.taskTracking,
          HomeMenuEntry.budget,
          HomeMenuEntry.financialSummary,
          HomeMenuEntry.reports,
        ],
      );
      expect(menu, isNot(contains(HomeMenuEntry.tasks)));
      expect(menu, isNot(contains(HomeMenuEntry.nfc)));
      expect(menu, isNot(contains(HomeMenuEntry.assets)));
      expect(menu, isNot(contains(HomeMenuEntry.outbox)));
      expect(menu, isNot(contains(HomeMenuEntry.patrol))); // Turlarim degil
    });

    test('Butce karti (Wave 2A) YALNIZ yonetici menusunde — sakin okumasi '
        'Wave 2B', () {
      expect(
        homeMenuForRole(UserRole.yonetici),
        contains(HomeMenuEntry.budget),
      );
      for (final role in [
        UserRole.admin, // admin butceyi panelden yonetir
        UserRole.security,
        UserRole.tesisGorevlisi,
        UserRole.resident,
      ]) {
        expect(
          homeMenuForRole(role),
          isNot(contains(HomeMenuEntry.budget)),
          reason: role.wire,
        );
      }
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

    test('resident: SOS + Ziyaretciler + Kargo + Rezervasyon + duyurular '
        '+ Sikayet/Oneri + Aidatim + Site Butcesi', () {
      expect(homeMenuForRole(UserRole.resident), const [
        HomeMenuEntry.emergency,
        HomeMenuEntry.visitors,
        HomeMenuEntry.kargo,
        HomeMenuEntry.rezervasyon,
        HomeMenuEntry.announcements,
        HomeMenuEntry.complaints,
        HomeMenuEntry.myDues,
        HomeMenuEntry.siteBudget,
      ]);
    });

    test('Rezervasyon karti (ortak alan): admin+yonetici+resident VAR; '
        'saha rolleri (security+tesis_gorevlisi) YOK (auth.md §4)', () {
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.resident,
      ]) {
        expect(
          homeMenuForRole(role),
          contains(HomeMenuEntry.rezervasyon),
          reason: role.wire,
        );
      }
      for (final role in [UserRole.security, UserRole.tesisGorevlisi]) {
        expect(
          homeMenuForRole(role),
          isNot(contains(HomeMenuEntry.rezervasyon)),
          reason: role.wire,
        );
      }
    });

    test('Kargo karti (paket takibi, ziyaretci matrisi): admin+yonetici+'
        'security+resident VAR; tesis_gorevlisi YOK (auth.md §4)', () {
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.security,
        UserRole.resident,
      ]) {
        expect(
          homeMenuForRole(role),
          contains(HomeMenuEntry.kargo),
          reason: role.wire,
        );
      }
      expect(
        homeMenuForRole(UserRole.tesisGorevlisi),
        isNot(contains(HomeMenuEntry.kargo)),
      );
    });

    test('Ziyaretciler karti (kapi onay akisi): admin+yonetici+security+'
        'resident VAR; tesis_gorevlisi YOK (auth.md §4 — erisemez)', () {
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.security,
        UserRole.resident,
      ]) {
        expect(
          homeMenuForRole(role),
          contains(HomeMenuEntry.visitors),
          reason: role.wire,
        );
      }
      expect(
        homeMenuForRole(UserRole.tesisGorevlisi),
        isNot(contains(HomeMenuEntry.visitors)),
      );
    });

    test('Wave 2B kartlari: Site Butcesi yalniz resident, Finansal Ozet '
        'yalniz yonetici', () {
      expect(
        homeMenuForRole(UserRole.yonetici),
        contains(HomeMenuEntry.financialSummary),
      );
      for (final role in [
        UserRole.admin,
        UserRole.security,
        UserRole.tesisGorevlisi,
        UserRole.resident,
      ]) {
        expect(
          homeMenuForRole(role),
          isNot(contains(HomeMenuEntry.financialSummary)),
          reason: role.wire,
        );
      }
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.security,
        UserRole.tesisGorevlisi,
      ]) {
        expect(
          homeMenuForRole(role),
          isNot(contains(HomeMenuEntry.siteBudget)),
          reason: role.wire,
        );
      }
    });

    test('Acil Durum karti 5 rolun 5inde de var (panik herkese acik)', () {
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.security,
        UserRole.tesisGorevlisi,
        UserRole.resident,
      ]) {
        expect(
          homeMenuForRole(role),
          contains(HomeMenuEntry.emergency),
          reason: role.wire,
        );
      }
    });

    test('Sikayet/Oneri karti bilinen 5 rolun 5inde (acanlar acar+kendini, '
        'yonetim tumunu gorur+yanitlar)', () {
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.security,
        UserRole.tesisGorevlisi,
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
