import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/home/presentation/widgets/home_header.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('HomeHeader — karsilama blogu (referans)', () {
    testWidgets('"Merhaba, {ad}" ve alt-basligi gosterir', (tester) async {
      await tester.pumpWidget(_wrap(const HomeHeader(
        greetingName: 'Kerem',
        subtitle: 'Yönetici Paneli',
      )));
      expect(find.text('Merhaba, Kerem'), findsOneWidget);
      expect(find.text('Yönetici Paneli'), findsOneWidget);
    });

    testWidgets('sakin alt-basligi (daire/blok) gosterir', (tester) async {
      await tester.pumpWidget(_wrap(const HomeHeader(
        greetingName: 'Çiğdem Hanım',
        subtitle: 'Daire 12, A Blok • Kat Maliki',
      )));
      expect(find.text('Merhaba, Çiğdem Hanım'), findsOneWidget);
      expect(find.text('Daire 12, A Blok • Kat Maliki'), findsOneWidget);
    });

    testWidgets('hava YOKken (MISSING-BACKEND, varsayilan) sicaklik gorunmez',
        (tester) async {
      await tester.pumpWidget(_wrap(const HomeHeader(
        greetingName: 'Kerem',
        subtitle: 'Yönetici Paneli',
      )));
      expect(find.text('24°C'), findsNothing);
      expect(find.text('İstanbul'), findsNothing);
    });

    testWidgets('hava VERILINCE sicaklik + sehir gorunur', (tester) async {
      await tester.pumpWidget(_wrap(const HomeHeader(
        greetingName: 'Kerem',
        subtitle: 'Yönetici Paneli',
        weather: HomeWeather(tempLabel: '24°C', city: 'İstanbul'),
      )));
      expect(find.text('24°C'), findsOneWidget);
      expect(find.text('İstanbul'), findsOneWidget);
    });
  });
}
