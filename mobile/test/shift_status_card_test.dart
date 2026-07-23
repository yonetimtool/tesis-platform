import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/home/presentation/widgets/shift_status_card.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('ShiftStatusCard — "Vardiya Durumu" kisi karti (referans)', () {
    testWidgets('vardiya adi + saat araligi + gorevli sayisi gosterir',
        (tester) async {
      await tester.pumpWidget(_wrap(const ShiftStatusCard(
        title: 'Sabah Vardiyası',
        subtitle: '06:00 - 14:00',
        status: ShiftStatus.aktif,
        footer: '2 Görevli',
      )));
      expect(find.text('Sabah Vardiyası'), findsOneWidget);
      expect(find.text('06:00 - 14:00'), findsOneWidget);
      expect(find.text('2 Görevli'), findsOneWidget);
    });

    testWidgets('durum cipi etiketi: AKTİF / PLANLANDI / YÖNETİCİ',
        (tester) async {
      await tester.pumpWidget(_wrap(const ShiftStatusCard(
        title: 'Sabah',
        subtitle: '06:00 - 14:00',
        status: ShiftStatus.aktif,
        footer: '2 Görevli',
      )));
      expect(find.text('AKTİF'), findsOneWidget);

      await tester.pumpWidget(_wrap(const ShiftStatusCard(
        title: 'Gece',
        subtitle: '22:00 - 06:00',
        status: ShiftStatus.planlandi,
        footer: '2 Görevli',
      )));
      expect(find.text('PLANLANDI'), findsOneWidget);

      await tester.pumpWidget(_wrap(const ShiftStatusCard(
        title: 'Yönetici',
        subtitle: 'Kerem Aşçı',
        status: ShiftStatus.yonetici,
        footer: 'Online',
        online: true,
      )));
      expect(find.text('YÖNETİCİ'), findsOneWidget);
      expect(find.text('Kerem Aşçı'), findsOneWidget);
    });
  });
}
