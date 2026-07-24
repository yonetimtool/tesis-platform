import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/shifts/domain/shift_models.dart';

void main() {
  group('Shift.fromJson (GET /shifts sozlesmesi)', () {
    test('tam kayit: ad + HH:MM saatler + gun_tipi', () {
      final s = Shift.fromJson(const {
        'id': 's1',
        'ad': 'Sabah Vardiyası',
        'baslangic_saat': '06:00',
        'bitis_saat': '14:00',
        'gun_tipi': 'hafta_ici',
      });
      expect(s.ad, 'Sabah Vardiyası');
      expect(s.baslangicSaat, '06:00');
      expect(s.bitisSaat, '14:00');
      expect(s.gunTipi, 'hafta_ici');
    });

    test('eksik alanlar patlatmaz', () {
      final s = Shift.fromJson(const {'id': 'x'});
      expect(s.ad, '');
      expect(s.baslangicSaat, '');
    });
  });

  group('Shift.aktifMi(now) — saat-flake YOK: now DISARIDAN verilir', () {
    Shift vardiya(String bas, String bit) => Shift(
        id: 'v', ad: 'V', baslangicSaat: bas, bitisSaat: bit, gunTipi: null);

    test('gunduz araligi: icindeyse aktif, disindaysa degil', () {
      final v = vardiya('06:00', '14:00');
      expect(v.aktifMi(DateTime(2026, 7, 23, 9, 30)), isTrue);
      expect(v.aktifMi(DateTime(2026, 7, 23, 6, 0)), isTrue); // baslangic dahil
      expect(v.aktifMi(DateTime(2026, 7, 23, 14, 0)), isFalse); // bitis haric
      expect(v.aktifMi(DateTime(2026, 7, 23, 22, 0)), isFalse);
    });

    test('GECE SARKMASI (22:00-06:00): gece yarisi oncesi VE sonrasi aktif',
        () {
      final v = vardiya('22:00', '06:00');
      expect(v.aktifMi(DateTime(2026, 7, 23, 23, 30)), isTrue);
      expect(v.aktifMi(DateTime(2026, 7, 23, 2, 0)), isTrue);
      expect(v.aktifMi(DateTime(2026, 7, 23, 12, 0)), isFalse);
    });

    test('bozuk saat metni: aktif SAYILMAZ (cokme yok)', () {
      expect(vardiya('', '14:00').aktifMi(DateTime(2026, 1, 1)), isFalse);
      expect(vardiya('ab:cd', 'x').aktifMi(DateTime(2026, 1, 1)), isFalse);
    });
  });

  group('gunTipiLabel', () {
    test('bilinen degerler TR etiket; null/bilinmeyen bos degil', () {
      expect(gunTipiLabel('hafta_ici'), 'Hafta içi');
      expect(gunTipiLabel('hafta_sonu'), 'Hafta sonu');
      expect(gunTipiLabel('her_gun'), 'Her gün');
      expect(gunTipiLabel('resmi_tatil'), 'Resmî tatil');
      expect(gunTipiLabel(null), 'Her gün'); // null = kisitsiz -> her gun
    });
  });

  group('Shift.personel (WP-E)', () {
    test('personel listesi savunmaci parse edilir', () {
      final s = Shift.fromJson({
        'id': 's1', 'ad': 'Sabah', 'baslangic_saat': '06:00',
        'bitis_saat': '14:00',
        'personel': [
          {'user_id': 'u1', 'ad': 'Guard A', 'avatar_url': 'https://x/a.jpg'},
          {'user_id': 'u2', 'ad': 'Gorevli A'},
        ],
      });
      expect(s.personel.length, 2);
      expect(s.personel.first.avatarUrl, 'https://x/a.jpg');
      expect(s.personel.last.avatarUrl, isNull);
    });

    test('personel alani yoksa bos liste (eski sunucu uyumu)', () {
      final s = Shift.fromJson({'id': 's1', 'ad': 'Sabah',
          'baslangic_saat': '06:00', 'bitis_saat': '14:00'});
      expect(s.personel, isEmpty);
    });
  });
}
