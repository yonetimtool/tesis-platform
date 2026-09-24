/// (P240 §3) AKILLI EV — mobil yuzey.
///
/// OLCULEN:
///  * KAPALI BOLUM = GORUNMEZ (anahtarlar sunucudan gelir),
///  * SENSORE KOMUT DUGMESI CIZILMEZ (`eylemler` bos),
///  * komut UCA gider ve gonderilen eylem DOGRU.
///
/// OLCULMEYEN (ve olculemez): gercek bir Home Assistant kurulumunda
/// isigin yanmasi. Burada dogrulanan sey ISTEMCININ SOZLESMESI.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/akilli_ev/data/akilli_ev_api.dart';
import 'package:mobile/src/features/akilli_ev/domain/akilli_ev_models.dart';
import 'package:mobile/src/features/akilli_ev/presentation/akilli_ev_ekrani.dart';

import 'helpers/l10n_test_app.dart';

class _SahteApi extends AkilliEvApi {
  _SahteApi(this.cihazKayitlari, this.bolumKayitlari) : super(Dio());

  final List<AkilliEvCihaz> cihazKayitlari;
  final List<AkilliEvBolum> bolumKayitlari;
  final List<String> komutlar = [];

  @override
  Future<List<AkilliEvCihaz>> cihazlar() async => cihazKayitlari;

  @override
  Future<List<AkilliEvBolum>> bolumler() async => bolumKayitlari;

  @override
  Future<bool> komut(String cihazId, String eylem) async {
    komutlar.add('$cihazId:$eylem');
    return true;
  }
}

AkilliEvCihaz _c({
  String id = 'c1',
  String tip = 'isik',
  List<String> eylemler = const ['ac', 'kapat'],
}) =>
    AkilliEvCihaz(
      id: id,
      ad: 'Salon',
      tip: tip,
      disKimlik: 'light.salon',
      eylemler: eylemler,
      daireNo: 'A-1',
    );

// (E2E 2026-09) Sunucunun GERCEK dokuz bolumu (`BOLUMLER`); eski liste
// sunucuda olmayan adlar tasiyordu ve kusuru gizliyordu.
List<AkilliEvBolum> _bolumler(Set<String> acik) => const [
      'protokol',
      'panik',
      'ziyaretci',
      'kacak',
      'enerji',
      'ortak_alan',
      'isitma',
      'kapi',
      'yangin',
    ].map((b) => AkilliEvBolum(bolum: b, acik: acik.contains(b))).toList();

Widget _ekran(_SahteApi api) => ProviderScope(
      overrides: [akilliEvApiProvider.overrideWithValue(api)],
      child: l10nApp(const AkilliEvEkrani()),
    );

void main() {
  testWidgets('KAPALI BOLUM: cihaz GORUNMEZ (yoklukta hepsi kapali)',
      (tester) async {
    final api = _SahteApi([_c()], _bolumler(const {}));
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('akilli-ev-cihaz-c1')), findsNothing);
  });

  testWidgets('ACIK BOLUM: cihaz gorunur ve eylem dugmeleri cizilir',
      (tester) async {
    final api = _SahteApi([_c()], _bolumler(const {'enerji'}));
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('akilli-ev-cihaz-c1')), findsOneWidget);
    expect(find.byKey(const Key('akilli-ev-komut-c1-ac')), findsOneWidget);
    expect(find.byKey(const Key('akilli-ev-komut-c1-kapat')), findsOneWidget);
  });

  testWidgets('SENSOR: hicbir komut dugmesi CIZILMEZ', (tester) async {
    // Sunucu zaten 422 doner; ama basinca hata verecek bir dugme
    // gostermek, olmayan bir yetenegi vaat etmek olurdu.
    final api = _SahteApi(
      [_c(tip: 'sensor_su', eylemler: const [])],
      _bolumler(const {'kacak'}),
    );
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('akilli-ev-cihaz-c1')), findsOneWidget);
    expect(find.byKey(const Key('akilli-ev-komut-c1-ac')), findsNothing);
  });

  testWidgets('KOMUT uca gider ve DOGRU eylemi tasir', (tester) async {
    final api = _SahteApi([_c()], _bolumler(const {'enerji'}));
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('akilli-ev-komut-c1-kapat')));
    await tester.pumpAndSettle();
    expect(api.komutlar, ['c1:kapat']);
  });

  test('TIP -> BOLUM yedek eslemesi SUNUCUNUN TIP_BOLUM tablosuyla ayni', () {
    expect(akilliEvBolumu('vana'), 'kacak');
    expect(akilliEvBolumu('sensor_duman'), 'yangin');
    expect(akilliEvBolumu('kilit'), 'kapi');
    expect(akilliEvBolumu('termostat'), 'isitma');
    expect(akilliEvBolumu('sayac'), 'enerji');
  });

  // (E2E 2026-09) TESIS-13: kapi kilidi eskiden HICBIR bolumde
  // gorunmuyordu (istemci sunucuda olmayan `kilit` bolumunu ariyordu).
  testWidgets('KILIT kapi bolumu acikken gorunur; sunucu bolumu esas',
      (tester) async {
    final api = _SahteApi(
      [
        _c(tip: 'kilit', eylemler: const ['kilit_ac']),
        AkilliEvCihaz(
          id: 'c2',
          ad: 'Ozel',
          tip: 'isik',
          disKimlik: 'light.x',
          eylemler: const ['ac'],
          bolum: 'kapi',
        ),
      ],
      _bolumler(const {'kapi'}),
    );
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('akilli-ev-cihaz-c1')), findsOneWidget);
    // Sunucunun `bolum` alani yerel tablonun ONUNDE gelir.
    expect(find.byKey(const Key('akilli-ev-cihaz-c2')), findsOneWidget);
  });
}
