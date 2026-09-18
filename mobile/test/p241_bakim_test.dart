/// (P241 §1) PERIYODIK BAKIM — mobil yuzey.
///
/// OLCULEN:
///  * durum rozetinin YANINDA GUN SAYISI yazili (renk tek basina anlam
///    tasimamali — istegin acik maddesi),
///  * SAHA rolu kayit dugmesini GORMEZ (sunucu da 403 doner),
///  * suzgec istemcide calisir,
///  * kayit formu ucu DOGRU govdeyle cagirir (gidere_yaz dahil).
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/bakim/data/bakim_api.dart';
import 'package:mobile/src/features/bakim/domain/bakim_models.dart';
import 'package:mobile/src/features/bakim/presentation/bakim_ekrani.dart';

import 'helpers/l10n_test_app.dart';

class _SahteApi extends BakimApi {
  _SahteApi(this.satirlar) : super(Dio());

  final List<BakimEkipmani> satirlar;
  BakimKaydiTaslak? gonderilen;
  String? gonderilenEkipman;

  @override
  Future<List<BakimEkipmani>> ekipmanlar({String? durum}) async => satirlar;

  @override
  Future<BakimKaydi> kayitEkle(String ekipmanId, BakimKaydiTaslak t) async {
    gonderilenEkipman = ekipmanId;
    gonderilen = t;
    return BakimKaydi(id: 'k1', ekipmanId: ekipmanId, tarih: t.tarih);
  }
}

BakimEkipmani _e({
  String id = 'e1',
  String ad = 'A Blok asansörü',
  String durum = 'yaklasti',
  int kalanGun = 12,
  bool yasal = true,
}) =>
    BakimEkipmani(
      id: id,
      ad: ad,
      tur: 'asansor',
      periyot: 'alti_aylik',
      sonrakiBakim: '2026-10-01',
      durum: durum,
      kalanGun: kalanGun,
      yasal: yasal,
    );

Widget _ekran(_SahteApi api, {bool yonetim = true}) => ProviderScope(
      overrides: [bakimApiProvider.overrideWithValue(api)],
      child: l10nApp(BakimEkrani(yonetim: yonetim)),
    );

void main() {
  testWidgets('GUN SAYISI YAZILI — renk tek basina anlam tasimaz',
      (tester) async {
    final api = _SahteApi([_e(kalanGun: 12)]);
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    final satir = tester
        .widget<ListTile>(find.byKey(const ValueKey('bakim-ekipman-e1')));
    final alt = (satir.subtitle! as Text).data ?? '';
    expect(alt, contains('12'));
    expect(alt, contains('Yaklaşıyor'));
  });

  testWidgets('GECIKME NEGATIF GUNLE DEGIL, "gecikti" METNIYLE yazilir',
      (tester) async {
    // "-4 gun kaldi" anlamsiz bir cumledir.
    final api = _SahteApi([_e(durum: 'gecikti', kalanGun: -4)]);
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    final satir = tester
        .widget<ListTile>(find.byKey(const ValueKey('bakim-ekipman-e1')));
    final alt = (satir.subtitle! as Text).data ?? '';
    expect(alt, contains('4 gün gecikti'));
    expect(alt, isNot(contains('-4')));
  });

  testWidgets('YASAL ZORUNLULUK basliktan okunur', (tester) async {
    final api = _SahteApi([_e(yasal: true)]);
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    final satir = tester
        .widget<ListTile>(find.byKey(const ValueKey('bakim-ekipman-e1')));
    expect((satir.title! as Text).data, contains('Yasal zorunluluk'));
  });

  testWidgets('SAHA ROLU kayit dugmesini GORMEZ', (tester) async {
    // Sunucu da 403 doner; dugmeyi gizlemek, calismayacak bir sey
    // vaat etmemek icin.
    final api = _SahteApi([_e()]);
    await tester.pumpWidget(_ekran(api, yonetim: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bakim-ekipman-e1')), findsOneWidget);
    expect(find.byKey(const ValueKey('bakim-kayit-e1')), findsNothing);
  });

  testWidgets('SUZGEC istemcide suzer', (tester) async {
    final api = _SahteApi([
      _e(id: 'e1', ad: 'Geciken', durum: 'gecikti', kalanGun: -2),
      _e(id: 'e2', ad: 'Planlı', durum: 'planli', kalanGun: 200),
    ]);
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bakim-ekipman-e2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bakim-durum-suzgeci')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gecikti').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bakim-ekipman-e1')), findsOneWidget);
    expect(find.byKey(const ValueKey('bakim-ekipman-e2')), findsNothing);
  });

  testWidgets('KAYIT FORMU ucu DOGRU govdeyle cagirir', (tester) async {
    final api = _SahteApi([_e()]);
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bakim-kayit-e1')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('bakim-kayit-yapan')), 'Kone Servis');
    await tester.enterText(
        find.byKey(const ValueKey('bakim-kayit-tutar')), '4800');
    await tester.tap(find.byKey(const ValueKey('bakim-kayit-kaydet')));
    await tester.pumpAndSettle();

    expect(api.gonderilenEkipman, 'e1');
    expect(api.gonderilen!.yapanAd, 'Kone Servis');
    // KURUSA CEVRILIR: 4800 TL = 480000 kurus. Lira gondermek,
    // defterde yuz kat kucuk bir gider yazardi.
    expect(api.gonderilen!.tutarKurus, 480000);
    // VARSAYILAN: gidere yaz (P192 — onay bekleyen).
    expect(api.gonderilen!.gidereYaz, isTrue);
  });
}
