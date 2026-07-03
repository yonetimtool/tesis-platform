import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/patrol/domain/patrol_models.dart';
import 'package:mobile/src/features/scan/domain/outbox_entry.dart';

/// Yeni veri akisi (GET /me/patrol-window sonrasi):
///
///   * `okutuldu` durumunun TEK KAYNAGI SUNUCUDUR (pencere-geneli — baska
///     elemanin okutmasi da gorunur).
///   * Yerel birlesimin kalan tek rolu: bu cihazin outbox'ta BEKLEYEN
///     (henuz gonderilmemis) okutmalarini "gonderiliyor" olarak sunucu
///     verisinin UZERINE bindirmek. Gonderilmis (gonderildi) kayitlar
///     bindirilmez — onlar icin kaynak sunucudur.
void main() {
  final baslangic = DateTime.utc(2026, 7, 2, 0, 0);
  final bitis = DateTime.utc(2026, 7, 2, 1, 0);

  MePatrolCheckpoint server({
    required String id,
    required int sira,
    String ad = 'Nokta',
    bool okutuldu = false,
    DateTime? okutmaZamani,
    String? okutanUserId,
  }) =>
      MePatrolCheckpoint(
        checkpointId: id,
        ad: ad,
        sira: sira,
        okutuldu: okutuldu,
        okutmaZamani: okutmaZamani,
        okutanUserId: okutanUserId,
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

  // cp-a: UID haritasinda var; cp-b: UID'siz (yalnizca checkpoint_id eslesir).
  const uidByCheckpointId = {'cp-a': '04:A3:B2:C1:90:00'};

  List<CheckpointStatus> merge(
    List<MePatrolCheckpoint> serverCheckpoints,
    List<OutboxEntry> entries,
  ) =>
      mergeCheckpointStatuses(
        serverCheckpoints: serverCheckpoints,
        pencereBaslangic: baslangic,
        pencereBitis: bitis,
        outboxEntries: entries,
        uidByCheckpointId: uidByCheckpointId,
      );

  test('okutuldu durumu sunucudan gelir — baska elemanin okutmasi da gorunur',
      () {
    final zaman = DateTime.utc(2026, 7, 2, 0, 10);
    final result = merge([
      server(
        id: 'cp-a',
        sira: 0,
        okutuldu: true,
        okutmaZamani: zaman,
        okutanUserId: 'user-baska',
      ),
      server(id: 'cp-b', sira: 1),
    ], const []);
    expect(result, hasLength(2));
    expect(result[0].durum, CheckpointScanDurum.okutuldu);
    expect(result[0].okutmaZamani, zaman);
    expect(result[1].durum, CheckpointScanDurum.bekliyor);
  });

  test('outbox\'ta bekleyen okutma "gonderiliyor" olarak bindirilir '
      '(UID eslesmesi buyuk/kucuk harf duyarsiz)', () {
    final zaman = DateTime.utc(2026, 7, 2, 0, 15);
    final result = merge(
      [server(id: 'cp-a', sira: 0)],
      [
        entry(uid: '04:a3:b2:c1:90:00', okutma: zaman), // kucuk harf
      ],
    );
    expect(result[0].durum, CheckpointScanDurum.gonderiliyor);
    expect(result[0].okutmaZamani, zaman);
  });

  test('gonderilmis (gonderildi) outbox kaydi BINDIRILMEZ — tek kaynak sunucu',
      () {
    final result = merge(
      [server(id: 'cp-a', sira: 0)], // sunucu: okutulmadi
      [
        entry(
          uid: '04:A3:B2:C1:90:00',
          okutma: DateTime.utc(2026, 7, 2, 0, 15),
          status: OutboxStatus.gonderildi,
        ),
      ],
    );
    expect(result[0].durum, CheckpointScanDurum.bekliyor);
  });

  test('sunucu okutuldu diyorsa bekleyen kayit durumu DEGISTIREMEZ '
      '(sunucu kazanir, zaman sunucudan)', () {
    final sunucuZamani = DateTime.utc(2026, 7, 2, 0, 5);
    final result = merge(
      [
        server(id: 'cp-a', sira: 0, okutuldu: true, okutmaZamani: sunucuZamani),
      ],
      [
        entry(
          uid: '04:A3:B2:C1:90:00',
          okutma: DateTime.utc(2026, 7, 2, 0, 20),
        ),
      ],
    );
    expect(result[0].durum, CheckpointScanDurum.okutuldu);
    expect(result[0].okutmaZamani, sunucuZamani);
  });

  test('pencere disindaki bekleyen okutma bindirilmez (onceki tur karismaz)',
      () {
    final result = merge(
      [server(id: 'cp-a', sira: 0), server(id: 'cp-b', sira: 1)],
      [
        entry(
          uid: '04:A3:B2:C1:90:00',
          okutma: DateTime.utc(2026, 7, 1, 23, 59), // pencereden once
        ),
        entry(
          uid: 'ignore',
          checkpointId: 'cp-b',
          okutma: DateTime.utc(2026, 7, 2, 1, 0), // bitis dahil DEGIL
        ),
      ],
    );
    expect(result[0].durum, CheckpointScanDurum.bekliyor);
    expect(result[1].durum, CheckpointScanDurum.bekliyor);
  });

  test('kalici hata (404 vb.) bindirilmez', () {
    final result = merge(
      [server(id: 'cp-a', sira: 0)],
      [
        entry(
          uid: '04:A3:B2:C1:90:00',
          okutma: DateTime.utc(2026, 7, 2, 0, 10),
          status: OutboxStatus.kaliciHata,
        ),
      ],
    );
    expect(result[0].durum, CheckpointScanDurum.bekliyor);
  });

  test('checkpoint_id eslesmesi UID haritasi olmadan da calisir', () {
    final result = merge(
      [server(id: 'cp-b', sira: 1)],
      [
        entry(
          uid: 'FF:FF:FF:FF',
          checkpointId: 'cp-b',
          okutma: DateTime.utc(2026, 7, 2, 0, 40),
        ),
      ],
    );
    expect(result[0].durum, CheckpointScanDurum.gonderiliyor);
  });

  test('sonuc sira\'ya gore sirali doner ve UID haritasi satira islenir', () {
    final result = merge(
      [server(id: 'cp-b', sira: 1), server(id: 'cp-a', sira: 0, ad: 'A Blok')],
      const [],
    );
    expect(result[0].checkpoint.checkpointId, 'cp-a');
    expect(result[0].checkpoint.ad, 'A Blok');
    expect(result[0].checkpoint.nfcTagUid, '04:A3:B2:C1:90:00');
    expect(result[1].checkpoint.checkpointId, 'cp-b');
    expect(result[1].checkpoint.nfcTagUid, isNull);
  });
}
