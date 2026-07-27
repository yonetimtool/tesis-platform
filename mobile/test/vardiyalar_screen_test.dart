import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/shifts/data/shifts_api.dart';
import 'package:mobile/src/features/shifts/domain/shift_models.dart';
import 'package:mobile/src/features/shifts/presentation/vardiyalar_screen.dart';

import 'helpers/l10n_test_app.dart';

void main() {
  testWidgets('vardiyalar listelenir; personel adlari gorunur', (tester) async {
    const v = Shift(
      id: 's1', ad: 'Sabah Vardiyası',
      baslangicSaat: '06:00', bitisSaat: '14:00',
      personel: [ShiftPersonel(userId: 'u1', ad: 'Guard A')],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [shiftsProvider.overrideWith((ref) async => [v])],
      child: l10nApp(const VardiyalarScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sabah Vardiyası'), findsOneWidget);
    expect(find.textContaining('Guard A'), findsOneWidget);
  });
}
