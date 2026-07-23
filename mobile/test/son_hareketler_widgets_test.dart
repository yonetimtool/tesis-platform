import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/announcements/domain/announcement_models.dart';
import 'package:mobile/src/features/home/domain/son_hareketler.dart';
import 'package:mobile/src/features/home/presentation/duyurular_karti.dart';
import 'package:mobile/src/features/home/presentation/son_hareketler_section.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('SonHareketlerSection', () {
    final hareketler = [
      Hareket(
          tip: HareketTip.kargoTeslim,
          baslik: 'Kargo Teslim Edildi',
          altBaslik: 'Mng - Daire 12',
          zaman: DateTime(2026, 7, 23, 9, 47)),
      Hareket(
          tip: HareketTip.aidatOdeme,
          baslik: 'Aidat Ödemesi',
          altBaslik: '₺1.250,00',
          zaman: DateTime(2026, 7, 22, 10, 0)),
    ];

    testWidgets('baslik + satirlar + zaman etiketleri (bugun HH:mm, dun Dün)',
        (tester) async {
      await tester.pumpWidget(_wrap(SonHareketlerSection(
        hareketler: hareketler,
        now: DateTime(2026, 7, 23, 14, 0),
      )));
      expect(find.text('Son Hareketler'), findsOneWidget);
      expect(find.text('Kargo Teslim Edildi'), findsOneWidget);
      expect(find.text('09:47'), findsOneWidget);
      expect(find.text('Dün'), findsOneWidget);
    });

    testWidgets('bos akis: bolum HIC cizilmez', (tester) async {
      await tester.pumpWidget(_wrap(SonHareketlerSection(
        hareketler: const [],
        now: DateTime(2026, 7, 23),
      )));
      expect(find.text('Son Hareketler'), findsNothing);
    });
  });

  group('DuyurularKarti', () {
    Announcement duyuru(DateTime t) => Announcement(
          id: 'd1',
          baslik: 'Bahçe Düzenlemesi',
          govde: 'Site bahçemizde peyzaj düzenlemesi yapılacaktır.',
          olusturanUserId: 'y1',
          createdAt: t,
          updatedAt: t,
        );

    testWidgets('son duyuru: baslik + govde ozeti; yeni (<=3 gun) "Yeni" cipi',
        (tester) async {
      var tumu = 0;
      await tester.pumpWidget(_wrap(DuyurularKarti(
        duyurular: [duyuru(DateTime(2026, 7, 22))],
        now: DateTime(2026, 7, 23),
        onTumu: () => tumu++,
      )));
      expect(find.text('Duyurular'), findsOneWidget);
      expect(find.text('Bahçe Düzenlemesi'), findsOneWidget);
      expect(find.textContaining('peyzaj'), findsOneWidget);
      expect(find.text('Yeni'), findsOneWidget);

      await tester.tap(find.text('Tümünü Gör'));
      expect(tumu, 1);
    });

    testWidgets('eski duyuru (>3 gun): "Yeni" cipi YOK', (tester) async {
      await tester.pumpWidget(_wrap(DuyurularKarti(
        duyurular: [duyuru(DateTime(2026, 7, 10))],
        now: DateTime(2026, 7, 23),
        onTumu: () {},
      )));
      expect(find.text('Yeni'), findsNothing);
    });

    testWidgets('duyuru yok: kart HIC cizilmez', (tester) async {
      await tester.pumpWidget(_wrap(DuyurularKarti(
        duyurular: const [],
        now: DateTime(2026, 7, 23),
        onTumu: () {},
      )));
      expect(find.text('Duyurular'), findsNothing);
    });
  });
}
