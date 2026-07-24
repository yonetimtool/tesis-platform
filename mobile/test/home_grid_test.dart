import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/presentation/role_home_body.dart';
import 'package:mobile/src/features/home/presentation/widgets/home_grid.dart';
import 'package:mobile/src/features/home/presentation/widgets/module_card.dart';

Widget _body(double width) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: 800,
            child: RoleHomeBody(
              role: UserRole.resident,
              greetingName: 'Kerem',
              subtitle: 'Site Sakini',
              onOpen: (_) {},
            ),
          ),
        ),
      ),
    );

void main() {
  test('homeGridCols: genis ekranda 4, dar ekranda 2', () {
    expect(homeGridCols(412), 4);
    expect(homeGridCols(360), 2);
    expect(homeGridCols(320), 2);
  });

  testWidgets('412dp genislikte ilk 4 ModuleCard AYNI satirda', (tester) async {
    await tester.pumpWidget(_body(412));
    final cards = find.byType(ModuleCard);
    expect(cards, findsWidgets);
    final dy0 = tester.getTopLeft(cards.at(0)).dy;
    for (var i = 1; i < 4; i++) {
      expect(tester.getTopLeft(cards.at(i)).dy, dy0);
    }
  });

  testWidgets('320dp genislikte 3. kart ALT satira duser (2 sutun)',
      (tester) async {
    await tester.pumpWidget(_body(320));
    final cards = find.byType(ModuleCard);
    final dy0 = tester.getTopLeft(cards.at(0)).dy;
    expect(tester.getTopLeft(cards.at(1)).dy, dy0);
    expect(tester.getTopLeft(cards.at(2)).dy, greaterThan(dy0));
  });
}
