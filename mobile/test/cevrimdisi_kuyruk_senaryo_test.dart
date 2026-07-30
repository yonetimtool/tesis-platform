/// TUR 66 — CEVRIMDISI KUYRUK: UZUN KESINTI + YENIDEN BAGLANMA + CAKISMA.
///
/// Ucuncu envanterin E maddesi: "`scan_outbox` testleri var; ama UZUN
/// CEVRIMDISI SURE + YENIDEN BAGLANMA + CAKISMA senaryosu surulmedi."
/// Mevcut testler tek kayit / tek hata uzerineydi. Burada olculenler:
///
///  1. PIL/VERI KORUMASI: baglanti yokken kuyrukta UC kayit varsa yalniz
///     BIR gonderim denenir (tur kesilir). Bu, `pump()` icindeki `break`in
///     davranissal kanitidir — kodu okumak yetmez, sayacla dogrulanir.
///  2. USTEL GERI CEKILME: 15s → 30s → 60s diye BUYUR ve 10 dakikada
///     TAVANLANIR. Zamanlayiciyi sahte saatle ilerletmek BU ORTAMDA
///     OLCULEMIYOR (kuyruk her gecisde GERCEK disk yazmasi yapiyor ve sahte
///     saat kilitleniyor — denendi, test asildi); bu yuzden hesap saf bir
///     fonksiyona cikarildi ve invariant orada kilitlendi.
///  3. YENIDEN BAGLANMA: ag geri gelince kuyruk FIFO sirayla TAMAMEN bosalir.
///  4. CAKISMA: kesinti sirasinda sunucu kaydi zaten almissa (200 duplicate)
///     kayit `gonderildi` + `duplicate` olur — kullaniciya "tekrar" degil
///     "gonderildi" gorunur.
///  5. KARISIK KUYRUK: kalici hata (404) turu KESMEZ, gecici hata KESER.
///  6. 401 (refresh olu) KALICI DEGILDIR: oturum donunce gonderilebilsin.
///  7. YENIDEN GIRME: pump surerken gelen ikinci pump kaybolmaz.
library;

import 'dart:async';
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

class _SahteScanApi extends ScanApi {
  _SahteScanApi() : super(Dio());

  final gonderilen = <ScanDraft>[];
  late Future<ScanSubmitResult> Function(ScanDraft draft) davranis;

  @override
  Future<ScanSubmitResult> submit(ScanDraft draft) {
    gonderilen.add(draft);
    return davranis(draft);
  }
}

ScanSubmitResult _basari(ScanDraft d, {bool tekrar = false}) => ScanSubmitResult(
  wasDuplicate: tekrar,
  event: ScanEvent(
    id: 'evt-${d.nfcTagUid}',
    guardId: 'g-1',
    checkpointId: 'cp-1',
    nfcTagUid: d.nfcTagUid,
    okutmaZamani: d.okutmaZamani,
    imzaDogrulandi: false,
  ),
);

const _agHatasi = ApiException(
  code: 'network_error',
  message: 'Sunucuya ulasilamadi.',
);

ScanDraft _taslak(String uid) => ScanDraft(
  nfcTagUid: uid,
  okutmaZamani: DateTime.parse('2026-07-02T10:00:00.000Z'),
);

void main() {
  late Directory dizin;
  late _SahteScanApi api;

  setUp(() async {
    dizin = await Directory.systemTemp.createTemp('kuyruk_test');
    api = _SahteScanApi();
  });

  tearDown(() async => dizin.delete(recursive: true));

  ProviderContainer kap() {
    final c = ProviderContainer(
      overrides: [
        scanApiProvider.overrideWithValue(api),
        scanOutboxStoreProvider.overrideWithValue(
          ScanOutboxStore(
            resolveFile: () async => File('${dizin.path}/outbox.json'),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> bekle(
    bool Function() kosul, {
    Duration sinir = const Duration(seconds: 5),
  }) async {
    final son = DateTime.now().add(sinir);
    while (!kosul()) {
      if (DateTime.now().isAfter(son)) fail('bekle: zaman asimi');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('PIL KORUMASI: baglanti yokken UC kayit icin YALNIZ BIR deneme',
      () async {
    api.davranis = (_) async => throw _agHatasi;
    final c = kap();
    final not = c.read(scanOutboxProvider.notifier);
    for (final uid in ['04A1', '04A2', '04A3']) {
      await not.enqueue(_taslak(uid));
    }
    await bekle(() => api.gonderilen.length >= 3);
    // ONEMLI AYRIM (ilk surumde kacirdim): her `enqueue` KENDI pump'ini
    // tetikler, yani uc okutma = uc deneme. Bu DOGRU davranistir — yeni bir
    // okutma denemeye deger. Olculecek degismez su: TEK bir pump turunda ilk
    // ag hatasindan sonra siradakiler DENENMEZ.
    api.gonderilen.clear();
    // `syncNow()` BEKLEMEK YETMEZ: onceki tur hala `_pumping` ise cagri erken
    // doner ve tur SONRADAN kosar (`_pumpAgain`). Bu yuzden denemeyi BEKLEYIP
    // sonra bir sure daha bekleyerek "baska deneme gelmedigi" dogrulanir.
    await not.syncNow();
    await bekle(() => api.gonderilen.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(api.gonderilen, hasLength(1),
        reason: 'tek turda ilk ag hatasindan sonra tur KESILMELI; '
            'pil/veri bosa harcanmamali');
    final d = c.read(scanOutboxProvider);
    expect(d.pendingCount, 3, reason: 'ucu de bekliyor kalmali');
    expect(d.failedCount, 0);
  });

  test('YENIDEN BAGLANMA: kuyruk FIFO sirayla TAMAMEN bosalir', () async {
    api.davranis = (_) async => throw _agHatasi;
    final c = kap();
    final not = c.read(scanOutboxProvider.notifier);
    for (final uid in ['04A1', '04A2', '04A3']) {
      await not.enqueue(_taslak(uid));
    }
    await bekle(() => api.gonderilen.isNotEmpty);

    // Ag geri geldi.
    api.gonderilen.clear();
    api.davranis = (d) async => _basari(d);
    await not.syncNow();
    await bekle(() => c.read(scanOutboxProvider).pendingCount == 0);

    expect(api.gonderilen.map((d) => d.nfcTagUid), ['04A1', '04A2', '04A3'],
        reason: 'FIFO sira korunmali');
    final d = c.read(scanOutboxProvider);
    expect(d.pendingCount, 0);
    expect(
      d.entries.every((e) => e.status == OutboxStatus.gonderildi),
      isTrue,
    );
  });

  test('CAKISMA: kesinti sirasinda sunucu almissa 200 duplicate -> gonderildi',
      () async {
    // Ilk deneme ag hatasi; ikinci denemede sunucu "zaten var" diyor.
    var ilk = true;
    api.davranis = (d) async {
      if (ilk) {
        ilk = false;
        throw _agHatasi;
      }
      return _basari(d, tekrar: true);
    };
    final c = kap();
    final not = c.read(scanOutboxProvider.notifier);
    await not.enqueue(_taslak('04A1'));
    await bekle(() => api.gonderilen.isNotEmpty);
    await not.syncNow();
    await bekle(() => c.read(scanOutboxProvider).pendingCount == 0);

    final kayit = c.read(scanOutboxProvider).entries.single;
    expect(kayit.status, OutboxStatus.gonderildi);
    expect(kayit.outcome, OutboxOutcome.duplicate,
        reason: 'kullaniciya "hata" degil "gonderildi (tekrar)" gorunmeli');
    expect(kayit.attemptCount, 2);
  });

  test('KARISIK KUYRUK: kalici hata turu KESMEZ, gecici hata KESER', () async {
    // Once hepsi ag hatasi alsin ki kuyruk UC bekleyenle dolsun.
    api.davranis = (_) async => throw _agHatasi;
    final c = kap();
    final not = c.read(scanOutboxProvider.notifier);
    for (final uid in ['04A1', '04A2', '04A3']) {
      await not.enqueue(_taslak(uid));
    }
    await bekle(() => api.gonderilen.length >= 3);

    // Simdi TEK tur: 04A1 -> 404 (kalici), 04A2 -> ag hatasi (tur kesilir),
    // 04A3 -> hic denenmez.
    api.gonderilen.clear();
    api.davranis = (d) async {
      if (d.nfcTagUid == '04A1') {
        throw const ApiException(
          code: 'not_found',
          message: 'Etiket yok',
          statusCode: 404,
        );
      }
      throw _agHatasi;
    };
    await not.syncNow();
    await bekle(() => api.gonderilen.length >= 2);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(api.gonderilen.map((d) => d.nfcTagUid), ['04A1', '04A2'],
        reason: '404 sonrasi siradaki DENENIR; ag hatasinda tur KESILIR');
    final d = c.read(scanOutboxProvider);
    expect(d.failedCount, 1, reason: '404 kalici hata');
    expect(d.pendingCount, 2, reason: 'ikisi bekliyor kalir');
  });

  test('401 KALICI DEGIL: oturum donunce gonderilir', () async {
    api.davranis = (_) async => throw const ApiException(
      code: 'unauthorized',
      message: 'Oturum sona erdi',
      statusCode: 401,
    );
    final c = kap();
    final not = c.read(scanOutboxProvider.notifier);
    await not.enqueue(_taslak('04A1'));
    await bekle(() => api.gonderilen.isNotEmpty);

    var d = c.read(scanOutboxProvider);
    expect(d.failedCount, 0,
        reason: '401 KALICI SAYILMAZ — oturum yenilenince gonderilebilir');
    expect(d.pendingCount, 1);

    // Oturum geri geldi.
    api.davranis = (x) async => _basari(x);
    await not.syncNow();
    await bekle(() => c.read(scanOutboxProvider).pendingCount == 0);
    d = c.read(scanOutboxProvider);
    expect(d.pendingCount, 0);
    expect(d.entries.single.status, OutboxStatus.gonderildi);
  });

  test('KALICILIK: uzun kesinti sonrasi YENI OTURUM kuyrugu devralir',
      () async {
    api.davranis = (_) async => throw _agHatasi;
    final c1 = kap();
    final not1 = c1.read(scanOutboxProvider.notifier);
    for (final uid in ['04A1', '04A2']) {
      await not1.enqueue(_taslak(uid));
    }
    await bekle(() => api.gonderilen.isNotEmpty);
    c1.dispose();

    // Uygulama kapandi, ag geri geldi, yeniden acildi.
    api.gonderilen.clear();
    api.davranis = (d) async => _basari(d);
    final c2 = kap();
    final not2 = c2.read(scanOutboxProvider.notifier);
    await bekle(() => c2.read(scanOutboxProvider).loaded);
    await not2.syncNow();
    await bekle(() => c2.read(scanOutboxProvider).pendingCount == 0);

    expect(api.gonderilen.map((d) => d.nfcTagUid), ['04A1', '04A2'],
        reason: 'diskteki kuyruk yeni oturumda FIFO gonderilmeli');
    expect(c2.read(scanOutboxProvider).pendingCount, 0);
  });

  group('USTEL GERI CEKILME (saf hesap)', () {
    // NEDEN SAF FONKSIYON: zamanlayiciyi sahte saatle ilerletmeyi denedim ve
    // test ASILDI — `testWidgets`in sahte zamani, kuyrugun her gecisde yaptigi
    // GERCEK disk yazmasiyla kilitleniyor. Yani "zamanlayici 15 saniye sonra
    // atesliyor mu" bu kosum ortaminda OLCULEMIYOR. Hesap saf fonksiyona
    // cikarildi (davranis degismedi) ve invariant BOYLE kilitlendi.
    test('ilk hata: taban sure', () {
      expect(geriCekilmeSuresi(1), ScanOutbox.baseBackoff);
    });

    test('IKIYE KATLANIR: 15s -> 30s -> 60s -> 120s', () {
      expect(geriCekilmeSuresi(1), const Duration(seconds: 15));
      expect(geriCekilmeSuresi(2), const Duration(seconds: 30));
      expect(geriCekilmeSuresi(3), const Duration(seconds: 60));
      expect(geriCekilmeSuresi(4), const Duration(seconds: 120));
    });

    test('TAVAN: 10 dakikayi ASMAZ (uzun kesintide bile)', () {
      for (final n in [8, 10, 12, 50, 1000]) {
        expect(geriCekilmeSuresi(n), lessThanOrEqualTo(ScanOutbox.maxBackoff),
            reason: 'n=$n');
      }
      expect(geriCekilmeSuresi(1000), ScanOutbox.maxBackoff);
    });

    test('MONOTON: sure asla kucuLMEZ', () {
      var onceki = Duration.zero;
      for (var n = 1; n <= 20; n++) {
        final s = geriCekilmeSuresi(n);
        expect(s, greaterThanOrEqualTo(onceki), reason: 'n=$n');
        onceki = s;
      }
    });

    test('SAVUNMA: 0 ya da negatif sayac tabana duser (cokme yok)', () {
      expect(geriCekilmeSuresi(0), ScanOutbox.baseBackoff);
      expect(geriCekilmeSuresi(-3), ScanOutbox.baseBackoff);
    });
  });

  test('YENIDEN GIRME: pump surerken gelen ikinci pump KAYBOLMAZ', () async {
    // Ilk gonderim askidayken ikinci bir kayit eklenir; `_pumpAgain` sayesinde
    // tur bitince yeni kayit da gonderilmeli.
    final kilit = Completer<void>();
    var ilkCagri = true;
    api.davranis = (d) async {
      if (ilkCagri) {
        ilkCagri = false;
        await kilit.future;
      }
      return _basari(d);
    };
    final c = kap();
    final not = c.read(scanOutboxProvider.notifier);
    await not.enqueue(_taslak('04A1'));
    await bekle(() => api.gonderilen.isNotEmpty);
    // Ilk gonderim ASKIDA; ikinci kayit ekleniyor (kendi pump'i kilide takilir).
    await not.enqueue(_taslak('04A2'));
    kilit.complete();

    await bekle(() => c.read(scanOutboxProvider).pendingCount == 0);
    expect(api.gonderilen.map((d) => d.nfcTagUid), ['04A1', '04A2']);
  });
}
