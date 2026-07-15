import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';

void main() {
  group('homeMenuForRole (auth.md §4 UX aynasi)', () {
    test('admin: ziyaretci/kargo DOGRUDAN GORMEZ (KVKK) — yerine unitAccess; '
        'security saha kartlarini (ziyaretci+kargo dahil) gorur', () {
      expect(homeMenuForRole(UserRole.admin), const [
        HomeMenuEntry.emergency,
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.siteKurallari,
        HomeMenuEntry.disHizmet,
        HomeMenuEntry.sikayetHaritasi,
        HomeMenuEntry.complaints,
        HomeMenuEntry.unitAccess,
        HomeMenuEntry.rezervasyon,
        HomeMenuEntry.patrol,
        HomeMenuEntry.tasks,
        HomeMenuEntry.assets,
        HomeMenuEntry.outbox,
      ]);
      expect(homeMenuForRole(UserRole.security), const [
        HomeMenuEntry.emergency,
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.siteKurallari,
        HomeMenuEntry.disHizmet,
        HomeMenuEntry.complaints,
        HomeMenuEntry.visitors,
        HomeMenuEntry.kargo,
        HomeMenuEntry.patrol,
        HomeMenuEntry.tasks,
        HomeMenuEntry.assets,
        HomeMenuEntry.outbox,
        // Sikayet Haritasi (yogunluk) YOK; salt-okuma Bina Duzenleme EN ALTTA.
        HomeMenuEntry.binaDuzenleme,
      ]);
    });

    test('Gorev-YONETIMI karti (A4 kesin matris): YALNIZ yonetici; saha '
        'rolleri (security/tesis_gorevlisi) ve resident GORMEZ — onlar yalniz '
        '"Gorevlerim" kullanir', () {
      expect(
        homeMenuForRole(UserRole.yonetici),
        contains(HomeMenuEntry.taskTracking),
      );
      for (final role in [
        UserRole.admin,
        UserRole.security,
        UserRole.tesisGorevlisi,
        UserRole.resident,
      ]) {
        expect(
          homeMenuForRole(role),
          isNot(contains(HomeMenuEntry.taskTracking)),
          reason: role.wire,
        );
      }
      // "Gorevlerim" saha rollerinde durur; yonetim/gorev-YONETIMI ayridir.
      for (final role in [UserRole.security, UserRole.tesisGorevlisi]) {
        expect(
          homeMenuForRole(role),
          contains(HomeMenuEntry.tasks),
          reason: role.wire,
        );
      }
      expect(
        homeMenuForRole(UserRole.resident),
        isNot(contains(HomeMenuEntry.tasks)),
      );
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
          HomeMenuEntry.etkinlik,
          HomeMenuEntry.siteKurallari,
        HomeMenuEntry.disHizmet,
          HomeMenuEntry.sikayetHaritasi,
          HomeMenuEntry.complaints,
          HomeMenuEntry.unitAccess,
          HomeMenuEntry.rezervasyon,
          HomeMenuEntry.patrolTracking,
          HomeMenuEntry.taskTracking,
          HomeMenuEntry.budget,
          HomeMenuEntry.financialSummary,
          HomeMenuEntry.reports,
          HomeMenuEntry.personel,
          HomeMenuEntry.sakinler,
          HomeMenuEntry.integrations,
          HomeMenuEntry.binaDuzenleme,
        ],
      );
      // ziyaretci/kargo DOGRUDAN GORMEZ (KVKK — varsayilan kapali)
      expect(menu, isNot(contains(HomeMenuEntry.visitors)));
      expect(menu, isNot(contains(HomeMenuEntry.kargo)));
      expect(menu, isNot(contains(HomeMenuEntry.tasks)));
      expect(menu, isNot(contains(HomeMenuEntry.nfc)));
      expect(menu, isNot(contains(HomeMenuEntry.assets)));
      expect(menu, isNot(contains(HomeMenuEntry.outbox)));
      expect(menu, isNot(contains(HomeMenuEntry.patrol))); // Turlarim degil
    });

    test('Entegrasyonlar karti (C1b): YALNIZ yonetici mobil menusunde; '
        'admin panelden yonetir, saha/sakin YOK', () {
      expect(
        homeMenuForRole(UserRole.yonetici),
        contains(HomeMenuEntry.integrations),
      );
      for (final role in [
        UserRole.admin,
        UserRole.security,
        UserRole.tesisGorevlisi,
        UserRole.resident,
      ]) {
        expect(
          homeMenuForRole(role),
          isNot(contains(HomeMenuEntry.integrations)),
          reason: role.wire,
        );
      }
    });

    test('NFC etiket okutma tile\'i HICBIR rolde menude YOK — okutma Turlarim '
        've Gorevlerim icinden yapilir (enum/rota reuse icin korunur)', () {
      for (final role in UserRole.values) {
        expect(
          homeMenuForRole(role),
          isNot(contains(HomeMenuEntry.nfc)),
          reason: role.wire,
        );
      }
    });

    test('Bina Duzenleme karti: yonetici (duzenler) + security/tesis_gorevlisi '
        '(SALT-OKUMA); admin panelden yonetir, resident YOK', () {
      // yonetici + saha rolleri kartI gorur (saha salt-okuma; ekran kilitler).
      for (final role in [
        UserRole.yonetici,
        UserRole.security,
        UserRole.tesisGorevlisi,
      ]) {
        expect(
          homeMenuForRole(role),
          contains(HomeMenuEntry.binaDuzenleme),
          reason: role.wire,
        );
      }
      // admin (panelden) + resident GORMEZ.
      for (final role in [UserRole.admin, UserRole.resident]) {
        expect(
          homeMenuForRole(role),
          isNot(contains(HomeMenuEntry.binaDuzenleme)),
          reason: role.wire,
        );
      }
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

    test('resident: SOS + Ziyaretciler + Kargo + Goruntuleme izni + '
        'Rezervasyon + duyurular + Sikayet Haritasi + Sikayet/Oneri + Aidatim + '
        'Site Butcesi (ayri "Sikayetlerim" sayfasi YOK — harita uzerinde)', () {
      expect(homeMenuForRole(UserRole.resident), const [
        HomeMenuEntry.emergency,
        HomeMenuEntry.visitors,
        HomeMenuEntry.kargo,
        HomeMenuEntry.unitAccess,
        HomeMenuEntry.rezervasyon,
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.siteKurallari,
        HomeMenuEntry.disHizmet,
        HomeMenuEntry.sikayetHaritasi,
        HomeMenuEntry.complaints,
        HomeMenuEntry.myDues,
        HomeMenuEntry.siteBudget,
      ]);
    });

    test('Sikayetlerim karti KALDIRILDI (D-viz Rev-1.1 fix): resident kendi '
        'sikayetlerini Sikayet Haritasi uzerinde gorur — HICBIR rol menusunde '
        'ayri "Sikayetlerim" sayfasi YOK', () {
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.security,
        UserRole.tesisGorevlisi,
        UserRole.resident,
      ]) {
        expect(
          homeMenuForRole(role),
          isNot(contains(HomeMenuEntry.sikayetlerim)),
          reason: role.wire,
        );
      }
    });

    test('Goruntuleme izni karti (unitAccess): admin+yonetici (talep) + '
        'resident (karar) VAR; security+tesis_gorevlisi YOK (KVKK)', () {
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.resident,
      ]) {
        expect(
          homeMenuForRole(role),
          contains(HomeMenuEntry.unitAccess),
          reason: role.wire,
        );
      }
      for (final role in [UserRole.security, UserRole.tesisGorevlisi]) {
        expect(
          homeMenuForRole(role),
          isNot(contains(HomeMenuEntry.unitAccess)),
          reason: role.wire,
        );
      }
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

    test('Kargo karti (KVKK): YALNIZ security+resident dogrudan gorur; '
        'admin+yonetici (varsayilan kapali) ve tesis_gorevlisi YOK', () {
      for (final role in [UserRole.security, UserRole.resident]) {
        expect(
          homeMenuForRole(role),
          contains(HomeMenuEntry.kargo),
          reason: role.wire,
        );
      }
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.tesisGorevlisi,
      ]) {
        expect(
          homeMenuForRole(role),
          isNot(contains(HomeMenuEntry.kargo)),
          reason: role.wire,
        );
      }
    });

    test('Etkinlikler karti bilinen 5 rolun 5inde (okuma + seffaf sayilar '
        'herkese acik; RSVP yalniz sakinde, yonetim olusturur)', () {
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.security,
        UserRole.tesisGorevlisi,
        UserRole.resident,
      ]) {
        expect(
          homeMenuForRole(role),
          contains(HomeMenuEntry.etkinlik),
          reason: role.wire,
        );
      }
    });

    test('Site Kurallari karti bilinen 5 rolun 5inde (okuma herkese acik; '
        'CRUD yalniz yonetimde)', () {
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.security,
        UserRole.tesisGorevlisi,
        UserRole.resident,
      ]) {
        expect(
          homeMenuForRole(role),
          contains(HomeMenuEntry.siteKurallari),
          reason: role.wire,
        );
      }
    });

    test('Sikayet Haritasi karti (yogunluk): admin+yonetici+resident VAR; '
        'security+tesis_gorevlisi YOK (yogunluk yonetim/sakin konusu)', () {
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.resident,
      ]) {
        expect(
          homeMenuForRole(role),
          contains(HomeMenuEntry.sikayetHaritasi),
          reason: role.wire,
        );
      }
      for (final role in [UserRole.security, UserRole.tesisGorevlisi]) {
        expect(
          homeMenuForRole(role),
          isNot(contains(HomeMenuEntry.sikayetHaritasi)),
          reason: role.wire,
        );
      }
    });

    test('security/tesis_gorevlisi: Sikayet Haritasi yerine Bina Duzenleme '
        '(salt-okuma, EN ALTTA) — yogunluk haritasi GORMEZ, yapiyi gorur', () {
      for (final role in [UserRole.security, UserRole.tesisGorevlisi]) {
        final menu = homeMenuForRole(role);
        expect(menu, contains(HomeMenuEntry.binaDuzenleme), reason: role.wire);
        expect(menu, isNot(contains(HomeMenuEntry.sikayetHaritasi)),
            reason: role.wire);
        // Salt-okuma girisi menunun EN ALTINDA (yonetici konumuyla ayni).
        expect(menu.last, HomeMenuEntry.binaDuzenleme, reason: role.wire);
      }
    });

    test('Ziyaretciler karti (KVKK): YALNIZ security+resident dogrudan gorur; '
        'admin+yonetici (varsayilan kapali) ve tesis_gorevlisi YOK', () {
      for (final role in [UserRole.security, UserRole.resident]) {
        expect(
          homeMenuForRole(role),
          contains(HomeMenuEntry.visitors),
          reason: role.wire,
        );
      }
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.tesisGorevlisi,
      ]) {
        expect(
          homeMenuForRole(role),
          isNot(contains(HomeMenuEntry.visitors)),
          reason: role.wire,
        );
      }
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
