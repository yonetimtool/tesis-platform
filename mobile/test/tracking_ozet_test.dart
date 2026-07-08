import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/patrol/domain/patrol_models.dart';
import 'package:mobile/src/features/patrol/domain/tracking_ozet.dart';

ActivePatrolWindow _w({
  required String id,
  required DateTime start,
  required DateTime end,
  PatrolWindowDurum durum = PatrolWindowDurum.bekliyor,
  int beklenen = 0,
  int okutulan = 0,
}) =>
    ActivePatrolWindow(
      patrolWindowId: id,
      patrolPlanId: 'plan-1',
      pencereBaslangic: start,
      pencereBitis: end,
      durum: durum,
      beklenenCheckpointSayisi: beklenen,
      okutulanCheckpointSayisi: okutulan,
    );

void main() {
  final now = DateTime.utc(2026, 7, 8, 12, 0);

  group('trackingOzet — bugunun pencereleri sinifllanir', () {
    test('aktif / yaklasan / tamamlandi / kacirildi ayrimi', () {
      final ozet = trackingOzet([
        // su an icinde, bekliyor → aktif
        _w(id: 'a', start: now.subtract(const Duration(hours: 1)), end: now.add(const Duration(hours: 1))),
        // henuz baslamadi → yaklasan
        _w(id: 'b', start: now.add(const Duration(hours: 2)), end: now.add(const Duration(hours: 3))),
        _w(id: 'c', start: now.subtract(const Duration(hours: 4)), end: now.subtract(const Duration(hours: 3)), durum: PatrolWindowDurum.tamamlandi),
        _w(id: 'd', start: now.subtract(const Duration(hours: 6)), end: now.subtract(const Duration(hours: 5)), durum: PatrolWindowDurum.kacirildi),
      ], now);
      expect(ozet.aktif, 1);
      expect(ozet.yaklasan, 1);
      expect(ozet.tamamlandi, 1);
      expect(ozet.kacirildi, 1);
      expect(ozet.toplam, 4);
    });

    test('suresi gecmis ama hala bekliyor olan pencere kacirildi sayilir '
        '(scheduler durumu birazdan cevirecek)', () {
      final ozet = trackingOzet([
        _w(id: 'x', start: now.subtract(const Duration(hours: 3)), end: now.subtract(const Duration(hours: 2))),
      ], now);
      expect(ozet.kacirildi, 1);
      expect(ozet.aktif, 0);
      expect(ozet.yaklasan, 0);
    });

    test('bos liste sifir ozet', () {
      final ozet = trackingOzet(const [], now);
      expect(ozet.toplam, 0);
    });
  });
}
