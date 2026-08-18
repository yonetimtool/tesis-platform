import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/routing/app_router.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/home/presentation/resident_home_screen.dart';

// (P38) `anketler` girisi BILINEN TUM ROLLERDE durur: anket OKUMASI
// herkese aciktir (site kararlarinin seffafligi — seffaflik panosuyla ayni
// gerekce), OY ise YALNIZ sakindedir ve bunu sunucu zorlar. Menuden saklamak,
// personelin sitesinde alinan karari hic gormemesi olurdu.
void main() {
  group('homeMenuForRole (auth.md §4 UX aynasi)', () {
    test('admin: ziyaretci/kargo DOGRUDAN GORMEZ (KVKK) — yerine unitAccess; '
        'security saha kartlarini (ziyaretci+kargo dahil) gorur', () {
      expect(homeMenuForRole(UserRole.admin), const [
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.anketler,
        HomeMenuEntry.siteKurallari,
        HomeMenuEntry.disHizmet,
        HomeMenuEntry.sikayetHaritasi,
        HomeMenuEntry.complaints,
        HomeMenuEntry.unitAccess,
        HomeMenuEntry.rezervasyon,
        HomeMenuEntry.patrol,
        HomeMenuEntry.tasks,
        HomeMenuEntry.assets,
        // (P26) Bagimsiz Bolum Tanimlari — site KURULUM adimi; yalniz
        // yonetim gorur.
      // (P139.3) `otopark` + `vardiyalar` — ana ekran izgarasi icin
      // yuzeye cikarildi. Rotalari (`/otopark`, `/vardiyalar`) ZATEN
      // vardi; eksik olan MODUL GIRISIYDI, o yuzden izgaraya konamiyordu.
      // Gorunurluk UYDURULMADI: kartlarinin bugun cizildigi rollerden
      // turedi (otopark -> `_yoneticiErisim`; vardiya -> `_gorevliErisim`
      // + `_tesisGorevlisiErisim` + `_yoneticiErisim`).
        HomeMenuEntry.daireTanimlari,
        HomeMenuEntry.otopark,
        // (P139.5) `ihlaller` yuzeye cikarildi: rotasi ZATEN vardi, MODUL
        // GIRISI yoktu — kart izgaradan dustugunde kullanici GERI
        // EKLEYEMIYORDU. Gorunurluk kartinin cizildigi rollerden turedi.
        HomeMenuEntry.ihlaller,
        HomeMenuEntry.vardiyalar,
        // (P166 §10) Gorev kategorileri: ekran VARDI, girisi yalniz
        // "Gorev yonetimi"nin sag ustundeki etiketsiz ikondu.
        HomeMenuEntry.taskCategories,
        // (P166 §8.2) Kurulum sihirbazi — mobilde ilk kez.
        HomeMenuEntry.kurulum,
        HomeMenuEntry.outbox,
      ]);
      expect(homeMenuForRole(UserRole.security), const [
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.anketler,
        HomeMenuEntry.siteKurallari,
        HomeMenuEntry.disHizmet,
        HomeMenuEntry.complaints,
        HomeMenuEntry.visitors,
        HomeMenuEntry.kargo,
        HomeMenuEntry.patrol,
        HomeMenuEntry.tasks,
        HomeMenuEntry.assets,
        HomeMenuEntry.outbox,
        // (P139.3) Vardiyalar yuzeye cikarildi — rotasi ZATEN vardi, eksik
        // olan modul girisiydi. Gorunurluk kartinin bugun cizildigi
        // rollerden turedi (`_gorevliErisim` + `_tesisGorevlisiErisim` +
        // `_yoneticiErisim`). `binaDuzenleme`nin EN ALTTA kalmasi kurali
        // korundu: yeni giris ONUN ONUNE kondu.
        // (P139.5) `ihlaller` de ayni gerekceyle yuzeye cikarildi.
        HomeMenuEntry.ihlaller,
        HomeMenuEntry.vardiyalar,
        // Sikayet Haritasi (yogunluk) YOK; salt-okuma Bina Duzenleme EN ALTTA.
        HomeMenuEntry.binaDuzenleme,
        HomeMenuEntry.yoneticiIletisim,
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
          HomeMenuEntry.announcements,
          HomeMenuEntry.tasks,
          HomeMenuEntry.assets,
          HomeMenuEntry.outbox,
        ]),
      );
    });

    test(
        'yonetici: duyurular + devriye TAKIBI + gorev TAKIBI; '
        'saha kartlari yok', () {
      final menu = homeMenuForRole(UserRole.yonetici);
      expect(
        menu,
        const [
          HomeMenuEntry.announcements,
          HomeMenuEntry.etkinlik,
          HomeMenuEntry.anketler,
          HomeMenuEntry.siteKurallari,
        HomeMenuEntry.disHizmet,
          HomeMenuEntry.sikayetHaritasi,
          HomeMenuEntry.complaints,
          HomeMenuEntry.unitAccess,
          HomeMenuEntry.rezervasyon,
          HomeMenuEntry.patrolTracking,
          // (P154 / Asama 7.2) Devriye planlari + Kontrol noktalari
          // MENUYE GELDI. Ikisi de EKRAN olarak vardi ama yalnizca Devriye
          // Takibi'nin sag ustundeki ETIKETSIZ ikonlardan aciliyordu;
          // brief "gizli aksiyonlar daha gorunur olsun" diyor.
          HomeMenuEntry.patrolPlans,
          HomeMenuEntry.checkpoints,
          HomeMenuEntry.taskTracking,
          HomeMenuEntry.budget,
          HomeMenuEntry.financialSummary,
          HomeMenuEntry.transparency,
          HomeMenuEntry.reports,
          HomeMenuEntry.personel,
          HomeMenuEntry.sakinler,
          HomeMenuEntry.integrations,
          HomeMenuEntry.binaDuzenleme,
          // (P26) Bagimsiz Bolum Tanimlari — yonetim kurulum adimi.
          HomeMenuEntry.daireTanimlari,
          // (P166 §10) Gorev kategorileri: ekran VARDI, girisi yalniz
          // "Gorev yonetimi"nin sag ustundeki etiketsiz ikondu.
          HomeMenuEntry.taskCategories,
          // (P166 §8.2) Kurulum sihirbazi — mobilde ilk kez.
          HomeMenuEntry.kurulum,
          // (P139.3) Yuzeye cikarildi (rotalari zaten vardi); gorunurluk
          // kartlarinin cizildigi rolden turedi — bkz. admin blogu.
          HomeMenuEntry.otopark,
          HomeMenuEntry.ihlaller,
          HomeMenuEntry.vardiyalar,
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

    test('resident: Ziyaretciler + Kargo + Goruntuleme izni + '
        'Rezervasyon + duyurular + Sikayet Haritasi + Aidatim + '
        'Site Butcesi (ayri "Sikayetlerim" sayfasi YOK — harita uzerinde · '
        '(P145) Talep/Ariza MENUDE YOK — ana ekranda)', () {
      expect(homeMenuForRole(UserRole.resident), const [
        HomeMenuEntry.visitors,
        HomeMenuEntry.kargo,
        HomeMenuEntry.unitAccess,
        HomeMenuEntry.rezervasyon,
        HomeMenuEntry.announcements,
        HomeMenuEntry.etkinlik,
        HomeMenuEntry.anketler,
        HomeMenuEntry.siteKurallari,
        // (P167 ek) SITE DOKUMANLARI — sakine acilmis dosyalar.
        // Site kurallarinin YANINDA: ikisi de BASVURU icerigidir
        // (duyuru gibi anlik degil, gerektiginde bakilan sey).
        HomeMenuEntry.dokumanlar,
        HomeMenuEntry.disHizmet,
        HomeMenuEntry.sikayetHaritasi,
        // (P145) `complaints` KALKTI — izin degil UCUNCU KAPI kalkti.
        HomeMenuEntry.myDues,
        HomeMenuEntry.siteBudget,
        HomeMenuEntry.transparency,
        HomeMenuEntry.yoneticiIletisim,
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
        // Salt-okuma girisi saha kartlarinin EN ALTINDA; ardindan yalnizca
        // Yonetici Iletisim gelir (o her zaman en son).
        final sonSalt =
            menu.where((e) => e != HomeMenuEntry.yoneticiIletisim).last;
        expect(sonSalt, HomeMenuEntry.binaDuzenleme, reason: role.wire);
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

    test('Acil durum girisi hicbir rolde YOK (SOS kaldirildi)', () {
      for (final role in UserRole.values) {
        final entries = homeMenuForRole(role);
        expect(
          entries.map((e) => e.name),
          isNot(contains('emergency')),
          reason: '$role menusunde emergency kalmis',
        );
      }
    });

    test('Yonetici Iletisim yalniz saha rolleri + sakinde, EN SONDA', () {
      for (final role in [
        UserRole.security,
        UserRole.tesisGorevlisi,
        UserRole.resident,
      ]) {
        final entries = homeMenuForRole(role);
        expect(entries, contains(HomeMenuEntry.yoneticiIletisim),
            reason: '$role');
        expect(entries.last, HomeMenuEntry.yoneticiIletisim,
            reason: '$role sonda degil');
      }
      for (final role in [UserRole.yonetici, UserRole.admin]) {
        expect(homeMenuForRole(role),
            isNot(contains(HomeMenuEntry.yoneticiIletisim)),
            reason: '$role gormemeli');
      }
    });

    test('Sikayet/Oneri karti bilinen 5 rolun 5inde (acanlar acar+kendini, '
        'yonetim tumunu gorur+yanitlar)', () async {
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.security,
        UserRole.tesisGorevlisi,
        // (P145) `resident` bu listeden CIKTI ve bu bir IZIN DEGISIKLIGI
        // DEGIL. auth.md §4 sakine talep/ariza kanalini aciyor; kanal
        // duruyor — sakin ana ekrandaki "Talep/Bildir" butonundan bildirir,
        // izgaradaki karodan takip eder. MENUDEKI giris ayni yere UCUNCU
        // kapiydi ve Kerem "kalksin" dedi. Izni asagidaki testte ayrica
        // olcuyoruz ki kaldirma sessizce yetki kaybina donusmesin.
      ]) {
        expect(
          homeMenuForRole(role),
          contains(HomeMenuEntry.complaints),
          reason: role.wire,
        );
      }
      // (P147) Sakinin talep/ariza KANALI: olcum noktasi UCUNCU KEZ
      // tasindi ve her seferinde SEBEBI VAR —
      //   menu (P145'e kadar) -> izgara karosu (P145) -> "Bildir" menusu
      // Karo P147'de kalkti (yerini Bildirimler sayfasi aldi) ama KANAL
      // KAPANMADI: sakin hala "Bildir"den talep acar, sonucunu Bildirimler
      // satirindan takip eder. Kanal gercekten kapanirsa bu test duser.
      final l10nTr = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(
        sakinBildirGirisleri(l10nTr).map((g) => g.route),
        contains(startsWith(AppRoutes.complaints)),
        reason: 'sakin talep/ariza kanali acik kalmali',
      );
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
