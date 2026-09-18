/// (P240 §2) DIYAFON — mobil yuzey.
///
/// OLCULEN: yetenek listesi SUNUCUDAN gelir ve eylem dugmeleri ona gore
/// cizilir; "Test et" saglik ucuna gider (zil/kapi ucuna DEGIL) — bir
/// test dugmesinin zil calmasi, izlemenin izledigi seyi calistirmasi
/// olurdu.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/diyafon/data/diyafon_api.dart';
import 'package:mobile/src/features/diyafon/domain/diyafon_models.dart';
import 'package:mobile/src/features/diyafon/presentation/diyafon_ekrani.dart';

import 'helpers/l10n_test_app.dart';

class _SahteApi extends DiyafonApi {
  _SahteApi(this.kayitlar) : super(Dio());

  final List<Diyafon> kayitlar;
  final List<String> cagrilar = [];
  DiyafonTaslak? gonderilen;

  @override
  Future<List<Diyafon>> liste() async => kayitlar;

  @override
  Future<Diyafon> olustur(DiyafonTaslak taslak) async {
    gonderilen = taslak;
    return kayitlar.first;
  }

  @override
  Future<({bool ok, String? kod})> saglik(String id) async {
    cagrilar.add('saglik');
    return (ok: true, kod: null);
  }

  @override
  Future<({bool ok, String? kod})> zil(String id) async {
    cagrilar.add('zil');
    return (ok: true, kod: null);
  }

  @override
  Future<({bool ok, String? kod})> kapiAc(String id) async {
    cagrilar.add('kapi');
    return (ok: true, kod: null);
  }
}

Diyafon _d({
  String yontem = 'sip',
  bool metin = true,
  bool zil = false,
  bool kapi = false,
}) =>
    Diyafon(
      id: 'd1',
      ad: 'Kapı paneli',
      yontem: yontem,
      host: '192.168.1.50',
      aktif: true,
      yetenekler: DiyafonYetenek(
        metinAnons: metin,
        sesliAnons: false,
        kapiAc: kapi,
        zilCal: zil,
      ),
    );

Widget _ekran(_SahteApi api) => ProviderScope(
      overrides: [diyafonApiProvider.overrideWithValue(api)],
      child: l10nApp(const DiyafonEkrani()),
    );

void main() {
  testWidgets('YETENEK LISTESI ve "sesli anons yok" satiri CIZILIR',
      (tester) async {
    final api = _SahteApi([_d()]);
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();

    final yetenek =
        tester.widget<Text>(find.byKey(const Key('diyafon-yetenek-d1'))).data ?? '';
    expect(yetenek, contains('Metin anonsu'));
    // "Neden ses gelmiyor" sorusu sahada degil SECIM ANINDA yanitlanmali.
    final sesli =
        tester.widget<Text>(find.byKey(const Key('diyafon-sesli-yok-d1'))).data ?? '';
    expect(sesli, contains('Sesli anons yok'));
  });

  testWidgets('SIP: zil/kapi dugmesi CIZILMEZ (422 alacak dugme gosterilmez)',
      (tester) async {
    final api = _SahteApi([_d()]);
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diyafon-zil-d1')), findsNothing);
    expect(find.byKey(const Key('diyafon-kapi-d1')), findsNothing);
  });

  testWidgets('KURU KONTAK: zil+kapi VAR, metin anonsu YOK', (tester) async {
    final api = _SahteApi([
      _d(yontem: 'kuru_kontak', metin: false, zil: true, kapi: true),
    ]);
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diyafon-zil-d1')), findsOneWidget);
    expect(find.byKey(const Key('diyafon-kapi-d1')), findsOneWidget);
    final yetenek =
        tester.widget<Text>(find.byKey(const Key('diyafon-yetenek-d1'))).data ?? '';
    expect(yetenek, isNot(contains('Metin anonsu')));
  });

  testWidgets('TEST ET saglik ucuna gider — ZIL/KAPI ucuna DEGIL',
      (tester) async {
    final api = _SahteApi([
      _d(yontem: 'kuru_kontak', metin: false, zil: true, kapi: true),
    ]);
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('diyafon-test-d1')));
    await tester.pumpAndSettle();
    expect(api.cagrilar, ['saglik']);
  });

  testWidgets('KAPI ACMA ONAY ISTER — yanlislikla tiklanan dugme kapi acmaz',
      (tester) async {
    final api = _SahteApi([
      _d(yontem: 'kuru_kontak', metin: false, zil: true, kapi: true),
    ]);
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('diyafon-kapi-d1')));
    await tester.pumpAndSettle();
    // Onay diyalogu ACIK, istek HENUZ gitmedi.
    expect(api.cagrilar, isEmpty);

    await tester.tap(find.byKey(const Key('diyafon-kapi-onay')));
    await tester.pumpAndSettle();
    expect(api.cagrilar, ['kapi']);
  });

  testWidgets('BOS SIFRE GOVDEYE GIRMEZ — "degistirme" demektir', (tester) async {
    final taslak = DiyafonTaslak(ad: 'X', yontem: 'sip', host: 'h', sifre: '');
    expect(taslak.toJson().containsKey('sifre'), isFalse);

    final dolu = DiyafonTaslak(ad: 'X', yontem: 'sip', host: 'h', sifre: 'g');
    expect(dolu.toJson()['sifre'], 'g');
  });

  testWidgets('FORMDA alanlar YONTEME GORE degisir', (tester) async {
    final api = _SahteApi([_d()]);
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diyafon-hedef')), findsOneWidget);
    expect(find.byKey(const Key('diyafon-zil-yolu')), findsNothing);
  });
}
