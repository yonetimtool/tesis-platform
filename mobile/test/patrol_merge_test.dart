import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/patrol/domain/patrol_models.dart';
import 'package:mobile/src/features/scan/domain/outbox_entry.dart';

void main() {
  final baslangic = DateTime.utc(2026, 7, 2, 0, 0);
  final bitis = DateTime.utc(2026, 7, 2, 1, 0);

  const cpA = PlanCheckpoint(
    checkpointId: 'cp-a',
    sira: 0,
    ad: 'A Blok Giris',
    nfcTagUid: '04:A3:B2:C1:90:00',
  );
  const cpB = PlanCheckpoint(
    checkpointId: 'cp-b',
    sira: 1,
    ad: 'Otopark',
    nfcTagUid: '04:11:22:33:44:55',
  );

  OutboxEntry entry({
    required String uid,
    required DateTime okutma,
    String? checkpointId,
    OutboxStatus status = OutboxStatus.bekliyor,
  }) =>
      OutboxEntry(
        idempotencyKey: '$uid|${okutma.toIso8601String()}',
        nfcTagUid: uid,
        okutmaZamani: okutma,
        enqueuedAt: okutma,
        checkpointId: checkpointId,
        status: status,
      );

  List<CheckpointStatus> merge(List<OutboxEntry> entries) =>
      mergeCheckpointStatuses(
        checkpoints: const [cpA, cpB],
        pencereBaslangic: baslangic,
        pencereBitis: bitis,
        outboxEntries: entries,
      );

  test('kayit yoksa tum noktalar bekliyor', () {
    final result = merge(const []);
    expect(result, hasLength(2));
    expect(result[0].durum, CheckpointScanDurum.bekliyor);
    expect(result[1].durum, CheckpointScanDurum.bekliyor);
  });

  test('pencere icindeki gonderilmis kayit UID ile okutuldu sayilir '
      '(buyuk/kucuk harf duyarsiz)', () {
    final result = merge([
      entry(
        uid: '04:a3:b2:c1:90:00', // kucuk harf — normalize edilmeli
        okutma: DateTime.utc(2026, 7, 2, 0, 15),
        status: OutboxStatus.gonderildi,
      ),
    ]);
    expect(result[0].durum, CheckpointScanDurum.okutuldu);
    expect(result[0].okutmaZamani, DateTime.utc(2026, 7, 2, 0, 15));
    expect(result[1].durum, CheckpointScanDurum.bekliyor);
  });

  test('outbox\'ta bekleyen kayit "gonderiliyor" gorunur (offline ilerleme)',
      () {
    final result = merge([
      entry(
        uid: '04:11:22:33:44:55',
        okutma: DateTime.utc(2026, 7, 2, 0, 30),
        status: OutboxStatus.bekliyor,
      ),
    ]);
    expect(result[1].durum, CheckpointScanDurum.gonderiliyor);
  });

  test('pencere disindaki okutma sayilmaz (onceki tur karismaz)', () {
    final result = merge([
      entry(
        uid: '04:A3:B2:C1:90:00',
        okutma: DateTime.utc(2026, 7, 1, 23, 59), // pencereden once
        status: OutboxStatus.gonderildi,
      ),
      entry(
        uid: '04:11:22:33:44:55',
        okutma: DateTime.utc(2026, 7, 2, 1, 0), // bitis dahil DEGIL
        status: OutboxStatus.gonderildi,
      ),
    ]);
    expect(result[0].durum, CheckpointScanDurum.bekliyor);
    expect(result[1].durum, CheckpointScanDurum.bekliyor);
  });

  test('kalici hata (404 vb.) okutma sayilmaz', () {
    final result = merge([
      entry(
        uid: '04:A3:B2:C1:90:00',
        okutma: DateTime.utc(2026, 7, 2, 0, 10),
        status: OutboxStatus.kaliciHata,
      ),
    ]);
    expect(result[0].durum, CheckpointScanDurum.bekliyor);
  });

  test('ayni noktaya coklu kayitta en ileri durum kazanir', () {
    final result = merge([
      entry(
        uid: '04:A3:B2:C1:90:00',
        okutma: DateTime.utc(2026, 7, 2, 0, 5),
        status: OutboxStatus.bekliyor,
      ),
      entry(
        uid: '04:A3:B2:C1:90:00',
        okutma: DateTime.utc(2026, 7, 2, 0, 20),
        status: OutboxStatus.gonderildi,
      ),
    ]);
    expect(result[0].durum, CheckpointScanDurum.okutuldu);
  });

  test('checkpoint_id eslesmesi UID olmadan da calisir', () {
    final result = merge([
      entry(
        uid: 'FF:FF:FF:FF', // plan noktasindaki UID ile uyusmuyor
        checkpointId: 'cp-b',
        okutma: DateTime.utc(2026, 7, 2, 0, 40),
        status: OutboxStatus.gonderildi,
      ),
    ]);
    expect(result[1].durum, CheckpointScanDurum.okutuldu);
  });
}
