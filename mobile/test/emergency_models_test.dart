import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/emergency/domain/emergency_models.dart';

/// Acil durum modulunun domain modelleri — `contracts/openapi.yaml`'daki
/// EmergencyCreate / EmergencyAlert / TenantSettings semalarina uyar.
void main() {
  group('EmergencyDraft', () {
    final basisAni = DateTime.utc(2026, 7, 3, 14, 5, 30);

    test('idempotency key basis aninda sabit — not/GPS sonradan eklense de '
        'degismez (cift dokunus cift alarm uretmez)', () {
      final d1 = EmergencyDraft(basisAni: basisAni);
      final d2 = d1.copyWith(
        notlar: 'B blok yangin',
        gpsLat: 41.01,
        gpsLng: 28.97,
      );
      expect(d1.idempotencyKey, d2.idempotencyKey);
      expect(
        EmergencyDraft(basisAni: basisAni).idempotencyKey,
        d1.idempotencyKey,
      );
      // Sozlesme siniri: minLength 8, maxLength 200.
      expect(d1.idempotencyKey.length, greaterThanOrEqualTo(8));
      expect(d1.idempotencyKey.length, lessThanOrEqualTo(200));
      // Farkli basis ani → farkli anahtar.
      expect(
        EmergencyDraft(basisAni: basisAni.add(const Duration(seconds: 1)))
            .idempotencyKey,
        isNot(d1.idempotencyKey),
      );
    });

    test('toJson: yalnizca dolu alanlar (EmergencyCreate — zaman sunucuda)',
        () {
      expect(EmergencyDraft(basisAni: basisAni).toJson(), isEmpty);
      expect(
        EmergencyDraft(basisAni: basisAni)
            .copyWith(notlar: 'yardim', gpsLat: 41.0, gpsLng: 29.0)
            .toJson(),
        {'gps_lat': 41.0, 'gps_lng': 29.0, 'notlar': 'yardim'},
      );
    });
  });

  test('EmergencyAlert.fromJson eslenir', () {
    final a = EmergencyAlert.fromJson({
      'id': 'e-1',
      'tetikleyen_user_id': 'user-1',
      'tetiklenme_zamani': '2026-07-03T14:05:31Z',
      'gps_lat': 41.01,
      'gps_lng': 28.97,
      'durum': 'acik',
      'notlar': 'B blok',
      'idempotency_key': 'emergency|x',
      'created_at': '2026-07-03T14:05:31Z',
    });
    expect(a.id, 'e-1');
    expect(a.tetiklenmeZamani, DateTime.utc(2026, 7, 3, 14, 5, 31));
    expect(a.gpsLat, 41.01);
    expect(a.notlar, 'B blok');
  });

  test('TenantSettings.fromJson: acil_durum_telefon nullable', () {
    final s = TenantSettings.fromJson({
      'tenant_id': 't-1',
      'ad': 'Acme Plaza',
      'slug': 'acme-plaza',
      'timezone': 'Europe/Istanbul',
      'acil_durum_telefon': '+90 212 555 00 00',
    });
    expect(s.ad, 'Acme Plaza');
    expect(s.acilDurumTelefon, '+90 212 555 00 00');

    final bos = TenantSettings.fromJson({
      'tenant_id': 't-1',
      'ad': 'Acme',
      'slug': 'acme',
      'timezone': 'UTC',
    });
    expect(bos.acilDurumTelefon, isNull);
  });

  group('telUri', () {
    test('bosluk/tire/parantez temizlenir, + ve rakamlar kalir', () {
      expect(
        telUri('+90 (212) 555-00-00').toString(),
        'tel:+902125550000',
      );
      expect(telUri('0212 555 00 00').toString(), 'tel:02125550000');
    });

    test('aranabilir icerik yoksa null (bos buton gosterilmez)', () {
      expect(telUri(''), isNull);
      expect(telUri('   '), isNull);
      expect(telUri('yok'), isNull);
    });
  });
}
