import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/tasks/domain/task_models.dart';

/// Gorev modulunun domain modelleri — `contracts/openapi.yaml`'daki Task /
/// TaskCompletion / TaskCompletionCreate / PresignResponse semalarina uyar.
void main() {
  group('Task.fromJson', () {
    test('tum alanlar eslenir', () {
      final t = Task.fromJson({
        'id': 't-1',
        'tip': 'temizlik',
        'ad': 'Cop toplama',
        'aciklama': 'A blok cevresi',
        'atanan_user_id': 'user-1',
        'checkpoint_id': 'cp-1',
        'periyot_dakika': 120,
        'sonraki_planlanan': '2026-07-04T09:00:00Z',
        'aktif': true,
        'created_at': '2026-07-01T08:00:00Z',
      });
      expect(t.id, 't-1');
      expect(t.tip, TaskTip.temizlik);
      expect(t.ad, 'Cop toplama');
      expect(t.aciklama, 'A blok cevresi');
      expect(t.atananUserId, 'user-1');
      expect(t.checkpointId, 'cp-1');
      expect(t.periyotDakika, 120);
      expect(t.sonrakiPlanlanan, DateTime.utc(2026, 7, 4, 9));
      expect(t.aktif, isTrue);
      expect(t.isAssignedTo('user-1'), isTrue);
      expect(t.isAssignedTo('user-2'), isFalse);
      expect(t.isAssignedTo(null), isFalse);
    });

    test('opsiyoneller null olabilir; bilinmeyen tip guvenli fallback', () {
      final t = Task.fromJson({
        'id': 't-2',
        'tip': 'yeni_tip', // sozlesme disi deger — cokme yok
        'ad': 'Bilinmeyen',
        'aktif': false,
        'created_at': '2026-07-01T08:00:00Z',
      });
      expect(t.tip, TaskTip.bilinmiyor);
      expect(t.aciklama, isNull);
      expect(t.atananUserId, isNull);
      expect(t.checkpointId, isNull);
      expect(t.sonrakiPlanlanan, isNull);
      expect(t.isAssignedTo('user-1'), isFalse);
    });
  });

  group('TaskCompletionDraft', () {
    final zaman = DateTime.utc(2026, 7, 3, 10, 30);

    test('idempotency key baslatma aninda sabit ve deterministik '
        '(alanlar sonradan degisse de degismez)', () {
      final d1 = TaskCompletionDraft(taskId: 't-1', tamamlanmaZamani: zaman);
      final d2 = d1.copyWith(
        nfcTagUid: '04:A3:B2:C1:90:00',
        fotoKey: 'tenant/foto.jpg',
        notlar: 'temizlendi',
      );
      expect(d1.idempotencyKey, d2.idempotencyKey);
      expect(
        TaskCompletionDraft(taskId: 't-1', tamamlanmaZamani: zaman)
            .idempotencyKey,
        d1.idempotencyKey,
      );
      // Sozlesme siniri: minLength 8, maxLength 200.
      expect(d1.idempotencyKey.length, greaterThanOrEqualTo(8));
      expect(d1.idempotencyKey.length, lessThanOrEqualTo(200));
      // Farkli gorev / farkli an → farkli anahtar.
      expect(
        TaskCompletionDraft(taskId: 't-2', tamamlanmaZamani: zaman)
            .idempotencyKey,
        isNot(d1.idempotencyKey),
      );
    });

    test('toJson: zorunlu tamamlanma_zamani + yalnizca dolu opsiyoneller', () {
      final d = TaskCompletionDraft(taskId: 't-1', tamamlanmaZamani: zaman);
      expect(d.toJson(), {
        'tamamlanma_zamani': '2026-07-03T10:30:00.000Z',
      });
      final full = d.copyWith(
        nfcTagUid: '04:A3:B2:C1:90:00',
        fotoKey: 'acme/tasks/abc.jpg',
        notlar: 'ok',
      );
      expect(full.toJson(), {
        'tamamlanma_zamani': '2026-07-03T10:30:00.000Z',
        'nfc_tag_uid': '04:A3:B2:C1:90:00',
        'foto_key': 'acme/tasks/abc.jpg',
        'notlar': 'ok',
      });
    });
  });

  test('TaskCompletion.fromJson eslenir', () {
    final c = TaskCompletion.fromJson({
      'id': 'c-1',
      'task_id': 't-1',
      'tamamlayan_user_id': 'user-1',
      'tamamlanma_zamani': '2026-07-03T10:30:00Z',
      'nfc_tag_uid': '04:A3:B2:C1:90:00',
      'foto_key': 'acme/tasks/abc.jpg',
      'foto_url': 'http://minio/acme/tasks/abc.jpg',
      'notlar': 'ok',
      'idempotency_key': 'task-completion|t-1|x',
      'created_at': '2026-07-03T10:30:05Z',
    });
    expect(c.id, 'c-1');
    expect(c.taskId, 't-1');
    expect(c.tamamlayanUserId, 'user-1');
    expect(c.tamamlanmaZamani, DateTime.utc(2026, 7, 3, 10, 30));
    expect(c.nfcTagUid, '04:A3:B2:C1:90:00');
    expect(c.fotoKey, 'acme/tasks/abc.jpg');
    expect(c.notlar, 'ok');
  });

  test('PresignTicket.fromJson eslenir', () {
    final p = PresignTicket.fromJson({
      'foto_key': 'acme/uploads/abc.jpg',
      'upload_url': 'http://minio:9000/bucket/acme/uploads/abc.jpg?X-Amz=1',
      'method': 'PUT',
      'expires_in': 300,
    });
    expect(p.fotoKey, 'acme/uploads/abc.jpg');
    expect(p.uploadUrl, contains('X-Amz'));
    expect(p.expiresIn, 300);
  });

  group('sortTasksForUser', () {
    Task task(String id, {String? atanan, DateTime? planlanan}) => Task(
          id: id,
          tip: TaskTip.temizlik,
          ad: id,
          aktif: true,
          atananUserId: atanan,
          sonrakiPlanlanan: planlanan,
        );

    test('bana atananlar one; sonra sonraki_planlanan ASC (null sona)', () {
      final sorted = sortTasksForUser([
        task('digerinin', atanan: 'user-2'),
        task('benim-gec',
            atanan: 'user-1', planlanan: DateTime.utc(2026, 7, 5)),
        task('atanmamis-erken', planlanan: DateTime.utc(2026, 7, 4)),
        task('benim-erken',
            atanan: 'user-1', planlanan: DateTime.utc(2026, 7, 4)),
        task('benim-plansiz', atanan: 'user-1'),
      ], 'user-1');
      expect(
        [for (final t in sorted) t.id],
        ['benim-erken', 'benim-gec', 'benim-plansiz', 'atanmamis-erken',
          'digerinin'],
      );
    });

    test('kullanici id yoksa yalnizca tarih sirasi', () {
      final sorted = sortTasksForUser([
        task('plansiz'),
        task('erken', planlanan: DateTime.utc(2026, 7, 4)),
      ], null);
      expect([for (final t in sorted) t.id], ['erken', 'plansiz']);
    });
  });
}
