import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/patrol/domain/patrol_models.dart';

/// `GET /me/patrol-window` yanitinin domain modele eslenmesi
/// (contracts/openapi.yaml → MePatrolWindowResponse).
void main() {
  test('dolu yanit: window + checkpoints + windows eslenir', () {
    final json = {
      'generated_at': '2026-07-02T00:30:00Z',
      'window': {
        'id': 'w-1',
        'patrol_plan_id': 'plan-1',
        'plan_adi': 'Gece Turu',
        'pencere_baslangic': '2026-07-02T00:00:00Z',
        'pencere_bitis': '2026-07-02T01:00:00Z',
        'durum': 'bekliyor',
      },
      'checkpoints': [
        {
          'checkpoint_id': 'cp-a',
          'ad': 'A Blok Giris',
          'sira': 0,
          'okutuldu': true,
          'okutma_zamani': '2026-07-02T00:10:00Z',
          'okutan_user_id': 'user-1',
        },
        {
          'checkpoint_id': 'cp-b',
          'ad': 'Otopark',
          'sira': 1,
          'okutuldu': false,
          'okutma_zamani': null,
          'okutan_user_id': null,
        },
      ],
      'windows': [
        {
          'id': 'w-1',
          'patrol_plan_id': 'plan-1',
          'plan_adi': 'Gece Turu',
          'pencere_baslangic': '2026-07-02T00:00:00Z',
          'pencere_bitis': '2026-07-02T01:00:00Z',
          'durum': 'bekliyor',
          'checkpoints': [
            {
              'checkpoint_id': 'cp-a',
              'ad': 'A Blok Giris',
              'sira': 0,
              'okutuldu': true,
              'okutma_zamani': '2026-07-02T00:10:00Z',
              'okutan_user_id': 'user-1',
            },
          ],
        },
        {
          'id': 'w-2',
          'patrol_plan_id': 'plan-2',
          'plan_adi': 'Cevre Turu',
          'pencere_baslangic': '2026-07-02T00:15:00Z',
          'pencere_bitis': '2026-07-02T02:00:00Z',
          'durum': 'bekliyor',
          'checkpoints': <Map<String, dynamic>>[],
        },
      ],
    };

    final res = MePatrolWindowResponse.fromJson(json);

    expect(res.generatedAt, DateTime.utc(2026, 7, 2, 0, 30));
    expect(res.window, isNotNull);
    expect(res.window!.id, 'w-1');
    expect(res.window!.planAdi, 'Gece Turu');
    expect(res.window!.durum, PatrolWindowDurum.bekliyor);
    // window'un nokta listesi ust-duzey `checkpoints` alanindan gelir.
    expect(res.window!.checkpoints, hasLength(2));
    expect(res.window!.checkpoints[0].okutuldu, isTrue);
    expect(
      res.window!.checkpoints[0].okutmaZamani,
      DateTime.utc(2026, 7, 2, 0, 10),
    );
    expect(res.window!.checkpoints[0].okutanUserId, 'user-1');
    expect(res.window!.checkpoints[1].okutuldu, isFalse);
    expect(res.window!.checkpoints[1].okutmaZamani, isNull);

    expect(res.windows, hasLength(2));
    expect(res.windows[1].id, 'w-2');
    expect(res.windows[1].checkpoints, isEmpty);
  });

  test('aktif pencere yok: window null + bos listeler (hata degil)', () {
    final res = MePatrolWindowResponse.fromJson({
      'generated_at': '2026-07-02T03:00:00Z',
      'window': null,
      'checkpoints': <Map<String, dynamic>>[],
      'windows': <Map<String, dynamic>>[],
    });
    expect(res.window, isNull);
    expect(res.windows, isEmpty);
  });

  test('toActiveWindow: sayilar checkpoint listesinden turetilir', () {
    final w = MePatrolWindowItem(
      id: 'w-1',
      patrolPlanId: 'plan-1',
      planAdi: 'Gece Turu',
      pencereBaslangic: DateTime.utc(2026, 7, 2, 0, 0),
      pencereBitis: DateTime.utc(2026, 7, 2, 1, 0),
      durum: PatrolWindowDurum.bekliyor,
      checkpoints: const [
        MePatrolCheckpoint(
          checkpointId: 'cp-a',
          ad: 'A',
          sira: 0,
          okutuldu: true,
        ),
        MePatrolCheckpoint(
          checkpointId: 'cp-b',
          ad: 'B',
          sira: 1,
          okutuldu: false,
        ),
      ],
    );
    final active = w.toActiveWindow();
    expect(active.patrolWindowId, 'w-1');
    expect(active.patrolPlanAd, 'Gece Turu');
    expect(active.beklenenCheckpointSayisi, 2);
    expect(active.okutulanCheckpointSayisi, 1);
  });
}
