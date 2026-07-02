import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/scan/data/scan_api.dart';
import 'package:mobile/src/features/scan/data/scan_outbox.dart';
import 'package:mobile/src/features/scan/data/scan_outbox_store.dart';
import 'package:mobile/src/features/scan/domain/outbox_entry.dart';
import 'package:mobile/src/features/scan/domain/scan.dart';

/// Testte gonderim davranisi degistirilebilen sahte API. [ScanApi.submit]
/// imzasi korunur; outbox gercek koddaki gibi bu imza uzerinden calisir.
class _FakeScanApi extends ScanApi {
  _FakeScanApi() : super(Dio());

  final submitted = <ScanDraft>[];
  late Future<ScanSubmitResult> Function(ScanDraft draft) handler;

  @override
  Future<ScanSubmitResult> submit(ScanDraft draft) {
    submitted.add(draft);
    return handler(draft);
  }
}

ScanSubmitResult _ok(ScanDraft d, {bool duplicate = false}) => ScanSubmitResult(
      wasDuplicate: duplicate,
      event: ScanEvent(
        id: 'evt-1',
        guardId: 'guard-1',
        checkpointId: 'cp-1',
        nfcTagUid: d.nfcTagUid,
        okutmaZamani: d.okutmaZamani,
        imzaDogrulandi: false,
      ),
    );

ApiException _apiError(int status) => ApiException(
      code: status == 404 ? 'not_found' : 'server_error',
      message: 'hata $status',
      statusCode: status,
    );

const _networkError = ApiException(
  code: 'network_error',
  message: 'Sunucuya ulasilamadi.',
);

ScanDraft _draft(String uid, [String iso = '2026-07-02T10:00:00.000Z']) =>
    ScanDraft(nfcTagUid: uid, okutmaZamani: DateTime.parse(iso));

void main() {
  late Directory tmpDir;
  late _FakeScanApi api;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('outbox_test');
    api = _FakeScanApi();
  });

  tearDown(() async {
    await tmpDir.delete(recursive: true);
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        scanApiProvider.overrideWithValue(api),
        scanOutboxStoreProvider.overrideWithValue(
          ScanOutboxStore(
            resolveFile: () async => File('${tmpDir.path}/outbox.json'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> waitFor(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('waitFor zaman asimi');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('basarili gonderim: bekliyor → gonderildi (201 → created)', () async {
    api.handler = (d) async => _ok(d);
    final container = makeContainer();
    final outbox = container.read(scanOutboxProvider.notifier);

    await outbox.enqueue(_draft('04:AA'));
    await waitFor(() {
      final e = container.read(scanOutboxProvider).byKey(_draft('04:AA').idempotencyKey);
      return e?.status == OutboxStatus.gonderildi;
    });

    final entry =
        container.read(scanOutboxProvider).byKey(_draft('04:AA').idempotencyKey)!;
    expect(entry.outcome, OutboxOutcome.created);
    expect(api.submitted.single.idempotencyKey, entry.idempotencyKey);
    expect(container.read(scanOutboxProvider).pendingCount, 0);
  });

  test('200 idempotent tekrar da basaridir (outcome: duplicate)', () async {
    api.handler = (d) async => _ok(d, duplicate: true);
    final container = makeContainer();
    await container.read(scanOutboxProvider.notifier).enqueue(_draft('04:BB'));

    await waitFor(() =>
        container.read(scanOutboxProvider).entries.isNotEmpty &&
        container.read(scanOutboxProvider).entries.first.status ==
            OutboxStatus.gonderildi);
    expect(
      container.read(scanOutboxProvider).entries.first.outcome,
      OutboxOutcome.duplicate,
    );
  });

  test('404 → kalici_hata, yeniden deneme yok, siradaki gonderilir', () async {
    api.handler = (d) async {
      if (d.nfcTagUid == '04:BAD') throw _apiError(404);
      return _ok(d);
    };
    final container = makeContainer();
    final outbox = container.read(scanOutboxProvider.notifier);

    await outbox.enqueue(_draft('04:BAD'));
    await outbox.enqueue(_draft('04:OK', '2026-07-02T10:01:00.000Z'));

    await waitFor(() {
      final s = container.read(scanOutboxProvider);
      return s.failedCount == 1 &&
          s.entries.any((e) => e.status == OutboxStatus.gonderildi);
    });

    final bad = container
        .read(scanOutboxProvider)
        .entries
        .firstWhere((e) => e.nfcTagUid == '04:BAD');
    expect(bad.status, OutboxStatus.kaliciHata);
    expect(bad.attemptCount, 1); // tekrar denenmedi
    // 404'lu kayit siradakini engellemedi:
    expect(api.submitted.map((d) => d.nfcTagUid), ['04:BAD', '04:OK']);
  });

  test('ag hatasi → bekliyor kalir; syncNow sonrasi gonderilir', () async {
    api.handler = (d) async => throw _networkError;
    final container = makeContainer();
    final outbox = container.read(scanOutboxProvider.notifier);

    await outbox.enqueue(_draft('04:CC'));
    await waitFor(() {
      final e = container.read(scanOutboxProvider).entries.firstOrNull;
      return e != null &&
          e.status == OutboxStatus.bekliyor &&
          e.attemptCount == 1;
    });
    expect(container.read(scanOutboxProvider).pendingCount, 1);

    // Baglanti "geri geldi": API artik basarili.
    api.handler = (d) async => _ok(d);
    await outbox.syncNow();
    await waitFor(() =>
        container.read(scanOutboxProvider).entries.first.status ==
        OutboxStatus.gonderildi);
    expect(container.read(scanOutboxProvider).pendingCount, 0);
  });

  test('FIFO: kayitlar eklenme sirasiyla gonderilir', () async {
    api.handler = (d) async => _ok(d);
    final container = makeContainer();
    final outbox = container.read(scanOutboxProvider.notifier);

    for (var i = 0; i < 3; i++) {
      await outbox.enqueue(
        _draft('04:0$i', '2026-07-02T10:0$i:00.000Z'),
      );
    }
    await waitFor(() => container
        .read(scanOutboxProvider)
        .entries
        .every((e) => e.status == OutboxStatus.gonderildi));
    expect(api.submitted.map((d) => d.nfcTagUid), ['04:00', '04:01', '04:02']);
  });

  test('kalicilik: yeniden acilista bekleyenler durur ve gonderilir', () async {
    // 1. "oturum": ag yok, kayit bekliyor'da kalir.
    api.handler = (d) async => throw _networkError;
    final container1 = makeContainer();
    await container1.read(scanOutboxProvider.notifier).enqueue(_draft('04:DD'));
    await waitFor(() =>
        container1.read(scanOutboxProvider).entries.firstOrNull?.attemptCount ==
        1);
    container1.dispose();

    // 2. "oturum" (uygulama yeniden acildi): ayni dosya, API artik saglam.
    api.handler = (d) async => _ok(d);
    final container2 = makeContainer();
    await waitFor(() {
      final s = container2.read(scanOutboxProvider);
      return s.loaded &&
          s.entries.length == 1 &&
          s.entries.first.status == OutboxStatus.gonderildi;
    });
  });

  test('cokme kurtarma: gonderiliyor kaydi acilista bekliyor olur', () async {
    final store = ScanOutboxStore(
      resolveFile: () async => File('${tmpDir.path}/outbox.json'),
    );
    final stuck = OutboxEntry.fromDraft(_draft('04:EE'), now: DateTime.now())
        .copyWith(status: OutboxStatus.gonderiliyor);
    await store.save([stuck]);

    api.handler = (d) async => _ok(d);
    final container = makeContainer();
    await waitFor(() {
      final s = container.read(scanOutboxProvider);
      return s.loaded &&
          s.entries.firstOrNull?.status == OutboxStatus.gonderildi;
    });
    // Idempotency-key okuma anindaki degeriyle korundu.
    expect(api.submitted.single.idempotencyKey, stuck.idempotencyKey);
  });

  test('clearFailed yalnizca kalici hatalari siler', () async {
    api.handler = (d) async => throw _apiError(404);
    final container = makeContainer();
    final outbox = container.read(scanOutboxProvider.notifier);
    await outbox.enqueue(_draft('04:FF'));
    await waitFor(() => container.read(scanOutboxProvider).failedCount == 1);

    await outbox.clearFailed();
    expect(container.read(scanOutboxProvider).entries, isEmpty);
  });

  test('OutboxEntry JSON gidis-donus kayipsizdir', () {
    final entry = OutboxEntry.fromDraft(
      ScanDraft(
        nfcTagUid: '04:A3:B2:C1:90:00',
        okutmaZamani: DateTime.utc(2026, 7, 2, 11, 30, 15),
        gpsLat: 41.0,
        gpsLng: 29.0,
      ),
      now: DateTime.utc(2026, 7, 2, 12),
    ).copyWith(
      status: OutboxStatus.kaliciHata,
      attemptCount: 3,
      lastError: 'hata 404',
    );

    final restored = OutboxEntry.fromJson(entry.toJson());
    expect(restored.idempotencyKey, entry.idempotencyKey);
    expect(restored.nfcTagUid, entry.nfcTagUid);
    expect(restored.okutmaZamani, entry.okutmaZamani);
    expect(restored.enqueuedAt, entry.enqueuedAt);
    expect(restored.gpsLat, 41.0);
    expect(restored.gpsLng, 29.0);
    expect(restored.status, OutboxStatus.kaliciHata);
    expect(restored.attemptCount, 3);
    expect(restored.lastError, 'hata 404');
    // Anahtar, taslaktan deterministik turetilenle ayni kalir.
    expect(restored.toDraft().idempotencyKey, entry.idempotencyKey);
  });
}
