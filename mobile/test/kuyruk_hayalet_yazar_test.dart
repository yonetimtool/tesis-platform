/// P10 — KALICILIK YARISI: "hayalet yazar" + paylasilan gecici dosya.
///
/// BELIRTI: `cevrimdisi_kuyruk_senaryo_test.dart::KALICILIK` testi TEK BASINA
/// gecerken TAM SUITTE arada bir dusuyordu (b7bd5eb tarihcesi). Tanilama icin
/// senaryo 60 kez ust uste kosuldu ve yaris GORUNUR oldu:
///
///   PathNotFoundException: Cannot rename `<dosya>.tmp` -> `<dosya>`
///
/// IKI AYRI URUN HATASI vardi:
///
///  1. HAYALET YAZAR — `ProviderContainer.dispose()` cagrildiginda kuyrukta
///     ucusan `_persist()` cagrilari IPTAL OLMUYORDU. Kapanmis kuyruk, YERINE
///     GECEN yeni kuyrugun dosyasini KENDI BAYAT durumuyla eziyordu; kayit
///     sessizce kayboluyor, "yeni oturum kuyrugu devralir" iddiasi dusuyordu.
///
///  2. PAYLASILAN `.tmp` — depo SABIT `<dosya>.tmp` adini kullaniyordu. Ayni
///     dosyaya yazan iki ornegin kilitleri AYRI oldugu icin adimlar ic ice
///     giriyordu:
///        A: tmp.write(A) → B: tmp.write(B) → A: rename (dosyaya B yazilir)
///        → B: rename (tmp yok → istisna)
///     Yani ya sessiz veri kaybi ya yutulan istisna.
///
/// Duzeltmeler: `_persist()` kapanmis bildiricide ERKEN DONER; depo her yazim
/// icin TEKIL bir gecici ad uretir. Bu dosya ikisini de kilitler.
library;

import 'dart:convert';
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
  late Future<ScanSubmitResult> Function(ScanDraft d) davranis;

  @override
  Future<ScanSubmitResult> submit(ScanDraft d) {
    gonderilen.add(d);
    return davranis(d);
  }
}

const _agHatasi = ApiException(code: 'network_error', message: 'yok');

ScanDraft _taslak(String uid) => ScanDraft(
  nfcTagUid: uid,
  okutmaZamani: DateTime.parse('2026-07-02T10:00:00.000Z'),
);

Future<void> beklePolla(
  bool Function() kosul, {
  Duration sinir = const Duration(seconds: 5),
}) async {
  final son = DateTime.now().add(sinir);
  while (!kosul()) {
    if (DateTime.now().isAfter(son)) fail('bekle: zaman asimi');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late Directory dizin;

  setUp(() async {
    dizin = await Directory.systemTemp.createTemp('hayalet_yazar');
  });
  tearDown(() async => dizin.delete(recursive: true));

  File dosya() => File('${dizin.path}/outbox.json');

  ProviderContainer kapVer(_SahteScanApi api) => ProviderContainer(
    overrides: [
      scanApiProvider.overrideWithValue(api),
      scanOutboxStoreProvider.overrideWithValue(
        ScanOutboxStore(resolveFile: () async => dosya()),
      ),
    ],
  );

  test('HAYALET YAZAR: kapanmis kuyruk DISKE DOKUNMAZ', () async {
    final api = _SahteScanApi()..davranis = (_) async => throw _agHatasi;
    final c1 = kapVer(api);
    final not = c1.read(scanOutboxProvider.notifier);
    for (final uid in ['04A1', '04A2']) {
      await not.enqueue(_taslak(uid));
    }
    await beklePolla(() => api.gonderilen.isNotEmpty);
    // Kuyruk HALA is basindayken kapatilir — gercek senaryo bu.
    c1.dispose();

    // Kapanistan SONRA dosyaya bilinen bir icerik yazilir. Hayalet yazar
    // hala yasiyorsa bunu kendi bayat durumuyla EZER.
    const nirengi = '{"version":1,"entries":[]}';
    await dosya().writeAsString(nirengi, flush: true);

    // Ucusan tum yazimlarin inmesi icin cömert bir pencere.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(
      await dosya().readAsString(),
      nirengi,
      reason:
          'kapanmis kuyruk diske yazdi — yerine gecen kuyrugun dosyasini '
          'bayat durumuyla ezer',
    );
  });

  test(
    'YENI OTURUM: iki kayit da FIFO devralinir (50 tekrar)',
    () async {
      // Ayni senaryonun sikistirilmis hali. Yaris zamanlamaya bagli oldugu
      // icin TEK kosum kanit degildir; tekrar sayisi dedektoru anlamli kilar
      // (duzeltme oncesi bu dongu ilk birkac turda dusuyordu).
      for (var tur = 0; tur < 50; tur++) {
        final alt = await Directory.systemTemp.createTemp('yeni_oturum');
        final dosya = File('${alt.path}/outbox.json');
        final api = _SahteScanApi();
        ProviderContainer kap() => ProviderContainer(
          overrides: [
            scanApiProvider.overrideWithValue(api),
            scanOutboxStoreProvider.overrideWithValue(
              ScanOutboxStore(resolveFile: () async => dosya),
            ),
          ],
        );

        api.davranis = (_) async => throw _agHatasi;
        final c1 = kap();
        final n1 = c1.read(scanOutboxProvider.notifier);
        for (final uid in ['04A1', '04A2']) {
          await n1.enqueue(_taslak(uid));
        }
        await beklePolla(() => api.gonderilen.isNotEmpty);
        c1.dispose();

        api.gonderilen.clear();
        api.davranis = (d) async => ScanSubmitResult(
          wasDuplicate: false,
          event: ScanEvent(
            id: 'evt',
            guardId: 'g',
            checkpointId: 'c',
            nfcTagUid: d.nfcTagUid,
            okutmaZamani: d.okutmaZamani,
            imzaDogrulandi: false,
          ),
        );
        final c2 = kap();
        final n2 = c2.read(scanOutboxProvider.notifier);
        await beklePolla(() => c2.read(scanOutboxProvider).loaded);
        await n2.syncNow();
        await beklePolla(() => c2.read(scanOutboxProvider).pendingCount == 0);
        expect(
          api.gonderilen.map((d) => d.nfcTagUid).toList(),
          ['04A1', '04A2'],
          reason: 'tur $tur: diskteki kuyruk FIFO devralinmadi',
        );
        c2.dispose();
        await alt.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'PAYLASILAN DOSYA: iki depo ornegi carpismaz, dosya HEP gecerli',
    () async {
      // Depo "tek yazar" varsayar ama iki ornek olusmasi (oturum degisimi)
      // veri KAYBETTIRMEMELI: en kotu ihtimalle son yazan kazanir.
      final a = ScanOutboxStore(resolveFile: () async => dosya());
      final b = ScanOutboxStore(resolveFile: () async => dosya());
      OutboxEntry kayit(String uid) =>
          OutboxEntry.fromDraft(_taslak(uid), now: DateTime.now());

      // Ic ice 40 yazim — eski surumde bu dizilim `rename` istisnasi veriyordu.
      final isler = <Future<void>>[];
      for (var i = 0; i < 20; i++) {
        isler.add(a.save([kayit('A$i')]));
        isler.add(b.save([kayit('B$i')]));
      }
      await Future.wait(isler);

      final ham = await dosya().readAsString();
      final coz = jsonDecode(ham) as Map<String, dynamic>;
      expect(coz['version'], 1);
      expect(
        (coz['entries'] as List),
        hasLength(1),
        reason: 'dosya YARIM yazilmis (atomik rename bozuldu)',
      );
      // Gecerli bir kayit okunabiliyor mu (bozuk JSON degil).
      expect(await a.load(), hasLength(1));
    },
  );
}
