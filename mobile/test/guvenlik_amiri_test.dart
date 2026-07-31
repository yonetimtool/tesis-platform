// P35 — guvenlik amiri rolunun ISTEMCI aynasi. Yetki SUNUCUDA zorlanir;
// burada olculen sey rolun DOGRU EKRANLARI gormesi ve sakin/finans
// girislerinin ona ACILMAMASIDIR.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/home/domain/home_varyant.dart';

void main() {
  const amir = UserRole.guvenlikAmiri;

  test('wire degeri sozlesmeyle AYNI', () {
    expect(amir.wire, 'guvenlik_amiri');
    expect(UserRole.fromClaim('guvenlik_amiri'), amir);
    // Bilinmeyen claim hala unknown'a duser (eski token kirilmaz).
    expect(UserRole.fromClaim('bilinmeyen'), UserRole.unknown);
  });

  test('GUVENLIK duzeni gorur, yonetici duzenini DEGIL', () {
    // Yonetici duzeni finans ozeti ve odeme tasir: dis sirket personeline
    // site yonetimi ekrani vermek olurdu.
    expect(homeVaryantForRole(amir), HomeVaryant.gorevli);
  });

  test('menude TUR ve EKIP var; SAKIN/KARGO/ZIYARETCI YOK', () {
    final menu = homeMenuForRole(amir);
    expect(menu, contains(HomeMenuEntry.patrol));
    expect(menu, contains(HomeMenuEntry.personel));
    for (final kapali in [
      HomeMenuEntry.kargo,
      HomeMenuEntry.visitors,
      HomeMenuEntry.sakinler,
      HomeMenuEntry.myDues,
      HomeMenuEntry.budget,
      HomeMenuEntry.financialSummary,
    ]) {
      expect(menu, isNot(contains(kapali)), reason: '$kapali amire kapali');
    }
  });

  test('yetenek bayraklari: guvenlik ALANI acik, sakin verisi KAPALI', () {
    expect(amir.canViewMyPatrol, isTrue);
    expect(amir.isGuvenlikYonetimi, isTrue);
    expect(amir.canViewViolations, isTrue);
    expect(amir.canViewVehiclePasses, isTrue);
    // KVKK: dis sirket personeline sakin kisisel verisi acilamaz.
    expect(amir.canViewKargo, isFalse);
    expect(amir.canViewVisitors, isFalse);
    expect(amir.canViewReservations, isFalse);
    // Site yonetimi islevleri de kapali.
    expect(amir.canManageAnnouncements, isFalse);
    expect(amir.canManageTasks, isFalse);
    expect(amir.canPublishTransparency, isFalse);
  });

  test('KART BAYRAKLARI: bildirim/arac/ihlal ACIK, kargo/ziyaretci KAPALI', () {
    // BULGU: saha ana ekrani tek bir `role == security` bayragina bakiyordu;
    // amir icin bu ya 403 uretecek istekler atardi ya da gordugu kartlari
    // gizlerdi. Kartlar artik YETENEK bayraklarina bakiyor.
    expect(amir.canViewNotifications, isTrue);
    expect(amir.canViewVehiclePasses, isTrue);
    expect(amir.canViewViolations, isTrue);
    expect(amir.canViewKargo, isFalse);
    expect(amir.canViewVisitors, isFalse);
    // Tesis gorevlisi bildirim GORMEZ (mevcut davranis korunuyor).
    expect(UserRole.tesisGorevlisi.canViewNotifications, isFalse);
    expect(UserRole.security.canViewNotifications, isTrue);
  });

  test('DIGER ROLLER degismedi (regresyon)', () {
    // P35 yalniz EKLEME olmali: mevcut rollerin yetenekleri aynen durmali.
    expect(UserRole.yonetici.isGuvenlikYonetimi, isTrue);
    expect(UserRole.security.isGuvenlikYonetimi, isFalse);
    expect(UserRole.security.canViewKargo, isTrue);
    expect(UserRole.resident.canViewKargo, isTrue);
    expect(UserRole.tesisGorevlisi.canViewKargo, isFalse);
    expect(homeVaryantForRole(UserRole.security), HomeVaryant.gorevli);
    expect(homeVaryantForRole(UserRole.yonetici), HomeVaryant.yonetici);
  });
}
