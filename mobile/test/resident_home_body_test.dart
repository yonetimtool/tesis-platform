import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/home/presentation/resident_home_body.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Govde kaydirilabilir ListView; tum bolumlerin ayni anda insa edilmesi icin
/// uzun bir gorunum penceresi kullaniriz (aksi halde ekran disi cocuklar
/// tembel-insa nedeniyle bulunamaz).
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('ResidentHomeBody — sakin ana ekran govdesi (referans)', () {
    testWidgets('karsilama + one cikan kartlar + "Tüm Modüller" bolumu',
        (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap(ResidentHomeBody(
        greetingName: 'Çiğdem Hanım',
        subtitle: 'Site Sakini',
        onOpen: (_) {},
      )));

      expect(find.text('Merhaba, Çiğdem Hanım'), findsOneWidget);
      expect(find.text('Ziyaretçiler'), findsOneWidget);
      expect(find.text('Aidatım'), findsOneWidget);
      expect(find.text('Tüm Modüller'), findsOneWidget);
      expect(find.text('Etkinlikler'), findsOneWidget);
    });

    testWidgets('bir karta dokununca onOpen(entry) cagrilir', (tester) async {
      _tall(tester);
      HomeMenuEntry? opened;
      await tester.pumpWidget(_wrap(ResidentHomeBody(
        greetingName: 'Çiğdem',
        subtitle: 'Site Sakini',
        onOpen: (e) => opened = e,
      )));

      await tester.tap(find.text('Aidatım'));
      expect(opened, HomeMenuEntry.myDues);
    });
  });
}
