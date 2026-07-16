import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/tenant/domain/tenant_models.dart';

void main() {
  test('TenantSettings.fromJson ad + kurulum_tamamlandi okur', () {
    final s = TenantSettings.fromJson({
      'tenant_id': 't1',
      'ad': 'Acme Plaza',
      'slug': 'acme-plaza',
      'timezone': 'Europe/Istanbul',
      'kurulum_tamamlandi': false,
    });
    expect(s.tenantId, 't1');
    expect(s.ad, 'Acme Plaza');
    expect(s.kurulumTamamlandi, isFalse);
  });

  test('kurulum_tamamlandi yoksa true varsayilir (eski tesisler)', () {
    final s = TenantSettings.fromJson({'tenant_id': 't1', 'ad': 'X'});
    expect(s.kurulumTamamlandi, isTrue);
  });
}
