/// TUR 61 — UZUN LISTEDE TEMBELLIK (performans).
///
/// Envanterin (tur 49, E maddesi) performans satiri: "uzun listede kaydirma".
/// `lib/src` icindeki veri listeleri tarandi; **bir** ekran butun kayitlari
/// govdede aciyordu — `unit_access_records_screen`:
/// `ListView(children: [..._kargolar.map(...)])`. Iki API de (`visitor_api`,
/// `kargo_api`) 200'luk sayfalarla TUM veriyi cekiyor, ust sinir YOK.
///
/// ILK IDDIAM YANLISTI, dedektor testi duzeltti: `ListView(children:)`
/// **eleman duzeyinde zaten tembeldir** (`SliverChildListDelegate` yalniz
/// gorunen + on bellek araligindaki cocuklar icin element/render nesnesi kurar).
/// Yani yerlesim/boyama zaten tembeldi; 500 satir yerlesime GIRMIYORDU.
///
/// Gercek fark su: `children:` kalibi ekran her yeniden insa edildiginde 500
/// satir WIDGET NESNESINI kuruyor (liste literali `build` icinde
/// materyallesir); `ListView.builder` yalniz gorunenleri kurar. Yani kazanc
/// yerlesimde degil, her karede yapilan O(N) nesne insasinda. Bu testler
/// ikisini AYRI AYRI olcuyor ve iddiayi bu ayrimla kaydediyor.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/kargo/data/kargo_api.dart';
import 'package:mobile/src/features/kargo/domain/kargo_models.dart';
import 'package:mobile/src/features/unit_access/presentation/unit_access_records_screen.dart';

import 'helpers/l10n_test_app.dart';

const int _kayitSayisi = 500;

class _FakeKargoApi extends KargoApi {
  _FakeKargoApi(this._items) : super(Dio());
  final List<Kargo> _items;

  @override
  Future<List<Kargo>> fetchAll({String? unitId, String? durum}) async => _items;
}

List<Kargo> _kargolar() => [
  for (var i = 0; i < _kayitSayisi; i++)
    Kargo(
      id: 'kg$i',
      unitId: 'u1',
      unitNo: 'A-12',
      firma: 'Aras Kargo',
      durum: KargoDurum.bekliyor,
      kaydedenUserId: 'g1',
      createdAt: DateTime(2026, 1, 1).add(Duration(minutes: i)),
    ),
];

Widget _ekran(List<Kargo> items) => ProviderScope(
  overrides: [kargoApiProvider.overrideWithValue(_FakeKargoApi(items))],
  child: l10nApp(
    const UnitAccessRecordsScreen(unitId: 'u1', kind: 'kargo'),
    locale: const Locale('tr'),
  ),
);

/// Ekranda o an MONTE EDILMIS (element'i olan) kargo satiri sayisi.
int _monteSatir(WidgetTester tester) =>
    find.text('Aras Kargo', skipOffstage: false).evaluate().length;

/// Kac kez INSA edildigini sayan satir uretici.
int _insaSayaci = 0;
Widget _sayanSatir() {
  _insaSayaci++;
  return const SizedBox(height: 56, child: Text('Aras Kargo'));
}

void main() {
  setUp(() => _insaSayaci = 0);

  testWidgets('TEMBEL: 500 kayitta monte satir sayisi goruntuyle sinirli', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_ekran(_kargolar()));
    await tester.pumpAndSettle();

    final sayi = _monteSatir(tester);
    // OLCUM BOS KOSMASIN: hic satir yoksa ekran cizilmemis demektir.
    expect(sayi, greaterThan(0), reason: 'hic kargo satiri cizilmedi');
    expect(
      sayi,
      lessThan(60),
      reason: '$_kayitSayisi kayittan $sayi satir MONTE EDILDI',
    );
  });

  testWidgets('KAYDIRMA: kaydirma sonrasi da sinirli kalir', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_ekran(_kargolar()));
    await tester.pumpAndSettle();
    final ilk = _monteSatir(tester);

    await tester.fling(find.byType(ListView), const Offset(0, -3000), 2000);
    await tester.pumpAndSettle();
    final sonra = _monteSatir(tester);

    expect(sonra, greaterThan(0), reason: 'kaydirma sonrasi satir yok');
    expect(
      sonra,
      lessThan(60),
      reason: 'kaydirma sonrasi $sonra satir monte (once $ilk)',
    );
  });

  testWidgets('OLCUM: `children:` 500 WIDGET kurar, `builder` kurmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // (a) ESKI kalip: liste literali `build` icinde materyallesir.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [for (var i = 0; i < _kayitSayisi; i++) _sayanSatir()],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final eager = _insaSayaci;
    // MONTE edilen sayisi ise burada da sinirli — `children:` eleman duzeyinde
    // TEMBELDIR. Iddiayi bu satir kayda geciriyor.
    final eagerMonte = _monteSatir(tester);

    // (b) YENI kalip.
    _insaSayaci = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: _kayitSayisi,
            itemBuilder: (_, _) => _sayanSatir(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final lazy = _insaSayaci;

    expect(eager, _kayitSayisi, reason: '`children:` 500 widget kurmali');
    expect(
      lazy,
      lessThan(60),
      reason: '`builder` yalniz gorunenleri kurmali (kurulan: $lazy)',
    );
    // Ve ELEMAN duzeyinde ikisi de tembel: kazanc yerlesimde degil, nesne
    // insasinda. Bu, ilk (yanlis) iddiami duzelten olcumdur.
    expect(
      eagerMonte,
      lessThan(60),
      reason: '`children:` eleman duzeyinde de tembel olmali (monte: '
          '$eagerMonte) — degilse bu dosyadaki aciklama gozden gecirilmeli',
    );
  });
}
