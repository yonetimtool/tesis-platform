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

    test('foto_zorunlu eslenir; eksikse false (eski yanit/guvenli varsayilan)',
        () {
      Map<String, dynamic> base(bool? fotoZorunlu) => {
            'id': 't-f',
            'tip': 'temizlik',
            'ad': 'X',
            'aktif': true,
            'created_at': '2026-07-01T08:00:00Z',
            'foto_zorunlu': ?fotoZorunlu,
          };
      expect(Task.fromJson(base(true)).fotoZorunlu, isTrue);
      expect(Task.fromJson(base(false)).fotoZorunlu, isFalse);
      expect(Task.fromJson(base(null)).fotoZorunlu, isFalse);
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

  group('sortTasksByPlan', () {
    // "Bana atananlar one" istemci mantigi KALDIRILDI (§11 #1 kapandi —
    // suzme artik sunucuda: ?atanan_user_id=me). Kalan tek is: tarih sirasi.
    Task task(String id, {DateTime? planlanan}) => Task(
          id: id,
          tip: TaskTip.temizlik,
          ad: id,
          aktif: true,
          sonrakiPlanlanan: planlanan,
        );

    test('sonraki_planlanan ASC; plansizlar sona, esitlikte ad', () {
      final sorted = sortTasksByPlan([
        task('plansiz-b'),
        task('gec', planlanan: DateTime.utc(2026, 7, 5)),
        task('plansiz-a'),
        task('erken', planlanan: DateTime.utc(2026, 7, 4)),
      ]);
      expect(
        [for (final t in sorted) t.id],
        ['erken', 'gec', 'plansiz-a', 'plansiz-b'],
      );
    });
  });

  group('TaskDraft (gorev olustur/duzenle govdesi)', () {
    test('toJson TAM-GOVDE: null alanlar da gonderilir (PATCH temizleme)', () {
      const draft = TaskDraft(tip: TaskTip.kontrol, ad: 'Kapi kontrol');
      expect(draft.toJson(), {
        'tip': 'kontrol',
        'ad': 'Kapi kontrol',
        'aciklama': null,
        'atanan_user_id': null,
        'periyot_dakika': null,
        'foto_zorunlu': false,
        'aktif': true,
      });
    });

    test('fromTask mevcut gorevi forma tasir', () {
      final task = Task.fromJson(const {
        'id': 't-1',
        'tip': 'peyzaj',
        'ad': 'Cim bicme',
        'aciklama': 'Haftalik',
        'atanan_user_id': 'u-9',
        'periyot_dakika': 10080,
        'foto_zorunlu': true,
        'aktif': true,
      });
      final draft = TaskDraft.fromTask(task);
      expect(draft.tip, TaskTip.peyzaj);
      expect(draft.atananUserId, 'u-9');
      expect(draft.periyotDakika, 10080);
      expect(draft.fotoZorunlu, isTrue);
    });
  });

  group('assignableFromUsersJson — atama secicisi suzgeci', () {
    test('yalniz AKTIF saha personeli (security + tesis_gorevlisi), ada gore',
        () {
      final out = assignableFromUsersJson(const [
        {'id': 'u1', 'ad': 'Zeynep', 'role': 'security', 'is_active': true},
        {'id': 'u2', 'ad': 'Ali', 'role': 'tesis_gorevlisi', 'is_active': true},
        {'id': 'u3', 'ad': 'Pasif', 'role': 'security', 'is_active': false},
        {'id': 'u4', 'ad': 'Yonetici', 'role': 'yonetici', 'is_active': true},
        {'id': 'u5', 'ad': 'Sakin', 'role': 'resident', 'is_active': true},
        {'id': 'u6', 'ad': 'Admin', 'role': 'admin', 'is_active': true},
      ]);
      expect(out.map((u) => u.ad).toList(), ['Ali', 'Zeynep']);
      expect(out.map((u) => u.role).toSet(),
          {'security', 'tesis_gorevlisi'});
    });

    test('bozuk ogeler sessizce atlanir', () {
      final out = assignableFromUsersJson(const [
        null,
        'sacma',
        {'ad': 'idsiz', 'role': 'security', 'is_active': true},
      ]);
      expect(out, isEmpty);
    });
  });
}
