import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/home/presentation/role_home_body.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Govde kaydirilabilir ListView; tum bolumlerin ayni anda insa edilmesi icin
/// uzun bir gorunum penceresi (tembel-insa disi kalanlar bulunamazdi).
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('RoleHomeBody — rol-parametrik ana ekran govdesi', () {
    testWidgets('resident: karsilama + one cikanlar + "Tüm Modüller" '
        '(R1 davranisi korunur)', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap(RoleHomeBody(
        role: UserRole.resident,
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

    testWidgets('yonetici: one cikanlarda Görev Yönetimi + Finansal Özet; '
        '"Tüm Modüller"de Bütçe', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_wrap(RoleHomeBody(
        role: UserRole.yonetici,
        greetingName: 'Kerem',
        subtitle: 'Yönetici Paneli',
        onOpen: (_) {},
      )));

      expect(find.text('Merhaba, Kerem'), findsOneWidget);
      expect(find.text('Yönetici Paneli'), findsOneWidget);
      expect(find.text('Görev Yönetimi'), findsOneWidget);
      expect(find.text('Finansal Özet'), findsOneWidget);
      expect(find.text('Tüm Modüller'), findsOneWidget);
      expect(find.text('Bütçe'), findsOneWidget);
      // Yonetici saha/sakin kartlarini GORMEZ (KVKK — home_menu korunur).
      expect(find.text('Ziyaretçiler'), findsNothing);
      expect(find.text('Kargo'), findsNothing);
    });

    testWidgets('yonetici bir karta dokununca onOpen(entry) doner',
        (tester) async {
      _tall(tester);
      HomeMenuEntry? opened;
      await tester.pumpWidget(_wrap(RoleHomeBody(
        role: UserRole.yonetici,
        greetingName: 'Kerem',
        subtitle: 'Yönetici Paneli',
        onOpen: (e) => opened = e,
      )));

      await tester.tap(find.text('Finansal Özet'));
      expect(opened, HomeMenuEntry.financialSummary);
    });
  });
}
