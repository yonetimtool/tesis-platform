import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/tasks/domain/task_category_models.dart';

/// Gorev kategorisi domain modeli (A6) — `contracts/openapi.yaml` TaskCategory.
void main() {
  group('TaskCategory.fromJson', () {
    test('tum alanlar eslenir', () {
      final k = TaskCategory.fromJson(const {
        'id': 'kat-1',
        'ad': 'Havuz bakimi',
        'aktif': true,
        'created_at': '2026-07-01T08:00:00Z',
      });
      expect(k.id, 'kat-1');
      expect(k.ad, 'Havuz bakimi');
      expect(k.aktif, isTrue);
    });

    test('eksik/bos alanlar guvenli varsayilan (cokme yok)', () {
      final k = TaskCategory.fromJson(const {});
      expect(k.id, '');
      expect(k.ad, '');
      expect(k.aktif, isTrue);
    });
  });
}
