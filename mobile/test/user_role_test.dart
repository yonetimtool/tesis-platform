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
      expect(UserRole.resident.canTriggerEmergency, isFalse);
    });

    test('duyuru yonetimi yalniz admin + yonetici (okuma herkese acik)', () {
      expect(UserRole.admin.canManageAnnouncements, isTrue);
      expect(UserRole.yonetici.canManageAnnouncements, isTrue);
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

    test('TR gorunen adlar', () {
      expect(UserRole.yonetici.label, 'Yonetici');
      expect(UserRole.security.label, 'Guvenlik');
      expect(UserRole.tesisGorevlisi.label, 'Tesis Gorevlisi');
      expect(UserRole.resident.label, 'Site Sakini');
    });
  });
}
