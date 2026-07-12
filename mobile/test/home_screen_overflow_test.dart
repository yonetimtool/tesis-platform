import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/presentation/home_screen.dart';
import 'package:mobile/src/features/scan/data/scan_outbox.dart';

/// Depoya dokunmayan sahte kuyruk — widget testinde path_provider yok.
class _FakeScanOutbox extends ScanOutbox {
  @override
  ScanOutboxState build() => const ScanOutboxState(loaded: true);
}

Widget _app() => ProviderScope(
      overrides: [
        scanOutboxProvider.overrideWith(_FakeScanOutbox.new),
        // Guvenlik: en cok karti goren rol (7 kart) — en kotu durum.
        currentUserRoleProvider.overrideWith((ref) async => UserRole.security),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );

void main() {
  testWidgets(
      'kucuk ekranda en cok kartli rolde (security) overflow olmaz '
      've son kart kaydirilarak gorunur', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Overflow ("BOTTOM OVERFLOWED BY ...") FlutterError olarak yakalanirdi.
    expect(tester.takeException(), isNull);

    // Ust baslik gorunur, listenin sonundaki kart kaydirilarak erisilebilir.
    expect(find.text('Giriş başarılı'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Gönderim kuyruğu'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Gönderim kuyruğu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('genis ekranda icerik yine ortali ve hatasiz', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Giriş başarılı'), findsOneWidget);
    expect(find.text('Gönderim kuyruğu'), findsOneWidget);
  });
}
