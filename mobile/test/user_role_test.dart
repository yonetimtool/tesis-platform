import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';

void main() {
  group('UserRole.fromClaim', () {
    test('bes backend degeri dogru esleme (auth.md §4)', () {
      expect(UserRole.fromClaim('admin'), UserRole.admin);
      expect(UserRole.fromClaim('yonetici'), UserRole.yonetici);
      expect(UserRole.fromClaim('security'), UserRole.security);
      expect(UserRole.fromClaim('tesis_gorevlisi'), UserRole.tesisGorevlisi);
      expect(UserRole.fromClaim('resident'), UserRole.resident);
    });

    test('bilinmeyen/eksik deger unknown doner (cokme yok)', () {
      expect(UserRole.fromClaim('cleaning'), UserRole.unknown); // eski ad
      expect(UserRole.fromClaim(null), UserRole.unknown);
      expect(UserRole.fromClaim(''), UserRole.unknown);
    });
  });

  group('yetenek bayraklari (auth.md §4 UX aynasi)', () {
    test('Turlarim yalniz admin + security', () {
      expect(UserRole.admin.canViewMyPatrol, isTrue);
      expect(UserRole.security.canViewMyPatrol, isTrue);
      expect(UserRole.yonetici.canViewMyPatrol, isFalse);
      expect(UserRole.tesisGorevlisi.canViewMyPatrol, isFalse);
      expect(UserRole.resident.canViewMyPatrol, isFalse);
    });

    test('saha kaniti (scan/tamamlama/zimmet) yonetici ve resident DISI', () {
      expect(UserRole.admin.isFieldWorker, isTrue);
      expect(UserRole.security.isFieldWorker, isTrue);
      expect(UserRole.tesisGorevlisi.isFieldWorker, isTrue);
      expect(UserRole.yonetici.isFieldWorker, isFalse);
      expect(UserRole.resident.isFieldWorker, isFalse);
      expect(UserRole.unknown.isFieldWorker, isFalse);
    });

    test('gorev okuma saha rolleri + yonetici; acil durum resident haric', () {
      expect(UserRole.yonetici.canViewTasks, isTrue);
      expect(UserRole.resident.canViewTasks, isFalse);
      expect(UserRole.yonetici.canTriggerEmergency, isTrue);
      // Panik butonu sakinin de hakki (canli test karari, auth.md §4).
      expect(UserRole.resident.canTriggerEmergency, isTrue);
    });

    test('duyuru yonetimi YALNIZ yonetici — admin mobilde salt okur '
        '(canli test karari; okuma herkese acik)', () {
      expect(UserRole.yonetici.canManageAnnouncements, isTrue);
      expect(UserRole.admin.canManageAnnouncements, isFalse);
      expect(UserRole.security.canManageAnnouncements, isFalse);
      expect(UserRole.tesisGorevlisi.canManageAnnouncements, isFalse);
      expect(UserRole.resident.canManageAnnouncements, isFalse);
    });

    test('gorev yonetimi (olustur/ata/sil) yalniz admin + yonetici', () {
      expect(UserRole.admin.canManageTasks, isTrue);
      expect(UserRole.yonetici.canManageTasks, isTrue);
      expect(UserRole.security.canManageTasks, isFalse);
      expect(UserRole.tesisGorevlisi.canManageTasks, isFalse);
      expect(UserRole.resident.canManageTasks, isFalse);
    });

    test('sikayet/oneri kesin kurali: acma saha+sakin; yanit admin+yonetici; '
        'goruntuleme bilinen 5 rolde', () {
      // ACMA: security + tesis_gorevlisi + resident
      expect(UserRole.security.canCreateComplaint, isTrue);
      expect(UserRole.tesisGorevlisi.canCreateComplaint, isTrue);
      expect(UserRole.resident.canCreateComplaint, isTrue);
      // yonetici kanalin cevaplayan tarafi; admin platform operatoru
      expect(UserRole.yonetici.canCreateComplaint, isFalse);
      expect(UserRole.admin.canCreateComplaint, isFalse);

      // CEVAPLAMA: yalniz yonetim
      expect(UserRole.admin.canRespondComplaints, isTrue);
      expect(UserRole.yonetici.canRespondComplaints, isTrue);
      expect(UserRole.security.canRespondComplaints, isFalse);
      expect(UserRole.tesisGorevlisi.canRespondComplaints, isFalse);
      expect(UserRole.resident.canRespondComplaints, isFalse);

      // GORUNTULEME: bilinen 5 rolun 5'i (acanlar kendi, yonetim tumu)
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.security,
        UserRole.tesisGorevlisi,
        UserRole.resident,
      ]) {
        expect(role.canViewComplaints, isTrue, reason: role.wire);
      }
      expect(UserRole.unknown.canViewComplaints, isFalse);
    });

    test('ziyaretci kesin kurali: kayit yalniz security; yanit yalniz '
        'resident; goruntuleme tesis_gorevlisi DISINDA', () {
      // KAYIT: yalniz guvenlik (kapi operasyonu)
      expect(UserRole.security.canRegisterVisitor, isTrue);
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.tesisGorevlisi,
        UserRole.resident,
        UserRole.unknown,
      ]) {
        expect(role.canRegisterVisitor, isFalse, reason: role.wire);
      }

      // YANIT: yalniz sakin (daire kosulunu sunucu ayrica zorlar)
      expect(UserRole.resident.canAnswerVisitor, isTrue);
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.security,
        UserRole.tesisGorevlisi,
        UserRole.unknown,
      ]) {
        expect(role.canAnswerVisitor, isFalse, reason: role.wire);
      }

      // GORUNTULEME: tesis_gorevlisi ERISMEZ (auth.md §4)
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.security,
        UserRole.resident,
      ]) {
        expect(role.canViewVisitors, isTrue, reason: role.wire);
      }
      expect(UserRole.tesisGorevlisi.canViewVisitors, isFalse);
      expect(UserRole.unknown.canViewVisitors, isFalse);
    });

    test('kargo kesin kurali (ziyaretci matrisi): kayit yalniz security; '
        'teslim yalniz resident; goruntuleme tesis_gorevlisi DISINDA', () {
      // KAYIT: yalniz guvenlik (kapi operasyonu)
      expect(UserRole.security.canRegisterKargo, isTrue);
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.tesisGorevlisi,
        UserRole.resident,
        UserRole.unknown,
      ]) {
        expect(role.canRegisterKargo, isFalse, reason: role.wire);
      }

      // TESLIM: yalniz sakin (daire kosulunu sunucu ayrica zorlar)
      expect(UserRole.resident.canReceiveKargo, isTrue);
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.security,
        UserRole.tesisGorevlisi,
        UserRole.unknown,
      ]) {
        expect(role.canReceiveKargo, isFalse, reason: role.wire);
      }

      // GORUNTULEME: tesis_gorevlisi ERISMEZ (ziyaretci ile ayni)
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.security,
        UserRole.resident,
      ]) {
        expect(role.canViewKargo, isTrue, reason: role.wire);
      }
      expect(UserRole.tesisGorevlisi.canViewKargo, isFalse);
      expect(UserRole.unknown.canViewKargo, isFalse);
    });

    test('TR gorunen adlar', () {
      expect(UserRole.yonetici.label, 'Yonetici');
      expect(UserRole.security.label, 'Guvenlik');
      expect(UserRole.tesisGorevlisi.label, 'Tesis Gorevlisi');
      expect(UserRole.resident.label, 'Site Sakini');
    });
  });
}
