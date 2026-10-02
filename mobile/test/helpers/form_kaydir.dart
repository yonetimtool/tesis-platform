import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// (P252) Personel formu "Calisma bilgileri" ile uzadi: kaydet dugmesi
/// 800x600 test yuzeyinde pencerenin altinda kalir. Pencerenin KENDI
/// kaydirma alaninda dugme gorunene kadar kaydirir. Once ODAK birakilir:
/// odaktaki metin alani duzen degisince (kasa listesi yuklendi) kendini
/// yeniden gorunur kilip kaydirmayi geri aliyordu.
Future<void> kaydetGorunsun(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byType(FilledButton).last,
    120,
    scrollable: find
        .descendant(of: find.byType(Dialog), matching: find.byType(Scrollable))
        .first,
  );
  await tester.pumpAndSettle();
}
