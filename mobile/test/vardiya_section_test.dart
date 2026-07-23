import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/shifts/domain/shift_models.dart';
import 'package:mobile/src/features/shifts/presentation/vardiya_section.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

const _vardiyalar = [
  Shift(
      id: 'v1',
      ad: 'Sabah Vardiyası',
      baslangicSaat: '06:00',
      bitisSaat: '14:00',
      gunTipi: 'hafta_ici'),
  Shift(
      id: 'v2',
      ad: 'Gece Vardiyası',
      baslangicSaat: '22:00',
      bitisSaat: '06:00',
      gunTipi: null),
];

void main() {
  group('VardiyaSection — "Vardiya Durumu" (gercek /shifts verisi)', () {
    testWidgets('baslik + kartlar; now araliktakine AKTİF, digerine PLANLANDI',
        (tester) async {
      await tester.pumpWidget(_wrap(VardiyaSection(
        vardiyalar: _vardiyalar,
        now: DateTime(2026, 7, 23, 9, 30), // sabah araliginda
      )));

      expect(find.text('Vardiya Durumu'), findsOneWidget);
      expect(find.text('Sabah Vardiyası'), findsOneWidget);
      expect(find.text('06:00 - 14:00'), findsOneWidget);
      expect(find.text('AKTİF'), findsOneWidget); // yalniz sabah
      expect(find.text('PLANLANDI'), findsOneWidget); // gece
      expect(find.text('Hafta içi'), findsOneWidget);
      expect(find.text('Her gün'), findsOneWidget);
    });

    testWidgets('gece sarkmasinda gece yarisi sonrasi gece vardiyasi AKTİF',
        (tester) async {
      await tester.pumpWidget(_wrap(VardiyaSection(
        vardiyalar: _vardiyalar,
        now: DateTime(2026, 7, 23, 2, 0),
      )));
      // Gece aktif, sabah planli.
      final aktifKartlar = find.text('AKTİF');
      expect(aktifKartlar, findsOneWidget);
      expect(find.text('PLANLANDI'), findsOneWidget);
    });

    testWidgets('bos liste: bolum HIC cizilmez (baslik dahil)', (tester) async {
      await tester.pumpWidget(_wrap(VardiyaSection(
        vardiyalar: const [],
        now: DateTime(2026, 7, 23, 9, 30),
      )));
      expect(find.text('Vardiya Durumu'), findsNothing);
    });
  });
}
