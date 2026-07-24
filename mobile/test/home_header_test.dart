import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/theme/home_tokens.dart';
import 'package:mobile/src/features/home/domain/home_view_models.dart';
import 'package:mobile/src/features/home/presentation/widgets/home_header.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

const _hava = HomeHava(
    sicaklik: '24°C', sehir: 'İstanbul', ikon: Icons.wb_sunny_outlined);

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
        subtitle: 'Daire 12, A Blok  •  Kat Maliki',
      )));
      expect(find.text('Merhaba, Çiğdem Hanım'), findsOneWidget);
      expect(find.text('Daire 12, A Blok  •  Kat Maliki'), findsOneWidget);
    });

    testWidgets('hava VERILINCE sicaklik + sehir gorunur; verilmeyince gizli',
        (tester) async {
      await tester.pumpWidget(_wrap(const HomeHeader(
        greetingName: 'Kerem',
        subtitle: 'Yönetici Paneli',
        hava: _hava,
      )));
      expect(find.text('24°C'), findsOneWidget);
      expect(find.text('İstanbul'), findsOneWidget);

      await tester.pumpWidget(_wrap(const HomeHeader(
        greetingName: 'Kerem',
        subtitle: 'Yönetici Paneli',
      )));
      expect(find.text('24°C'), findsNothing);
    });

    testWidgets('yonetici alt-basligi MAVI (referans: "Yönetici Paneli")',
        (tester) async {
      await tester.pumpWidget(_wrap(const HomeHeader(
        greetingName: 'Kerem',
        subtitle: 'Yönetici Paneli',
        altBaslikStili: HomeAltBaslikStili.mavi,
      )));
      final metin = tester.widget<Text>(find.text('Yönetici Paneli'));
      expect(metin.style?.color, HomeTokens.primary);
    });

    testWidgets('gorevli alt-basligi tesis SECICI: asagi ok + dokunma',
        (tester) async {
      var dokunma = 0;
      await tester.pumpWidget(_wrap(HomeHeader(
        greetingName: 'Mehmet',
        subtitle: 'Mavi Residence',
        altBaslikStili: HomeAltBaslikStili.tesisSecici,
        onAltBaslik: () => dokunma++,
      )));
      expect(find.text('Mavi Residence'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

      await tester.tap(find.text('Mavi Residence'));
      expect(dokunma, 1);
    });
  });
}
