import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';
import 'package:mobile/src/features/notifications/domain/notification_models.dart';
import 'package:mobile/src/features/notifications/presentation/notifications_screen.dart';

import 'helpers/l10n_test_app.dart';

/// API'ye dokunmayan sahte controller — markRead cagrilari kaydedilir.
class _FakeNotifications extends NotificationsController {
  _FakeNotifications(this._items);
  final List<AppNotification> _items;
  final List<String> marked = [];

  @override
  Future<List<AppNotification>> build() async => _items;

  @override
  Future<void> markRead(String id) async {
    marked.add(id);
    state = AsyncData([
      for (final n in state.value ?? <AppNotification>[])
        n.id == id ? n.copyWith(okundu: true) : n,
    ]);
  }
}

/// P22b sonrasi bildirime dokunmak ILGILI EKRANI da acar; bu yuzden ekran
/// artik bir `GoRouter` baglaminda cizilmelidir (duz `MaterialApp` ile
/// "No GoRouter found in context" atar). Router BURADA kurulur ve gidilen
/// rota [gidilen] listesine yazilir — yonlendirme de olculebilsin.
final gidilen = <String>[];

Widget _app(_FakeNotifications fake) {
  gidilen.clear();
  final router = GoRouter(
    initialLocation: '/bildirimler',
    routes: [
      GoRoute(
        path: '/bildirimler',
        builder: (_, _) => const NotificationsScreen(),
      ),
      // Bildirimlerin gidebilecegi hedefler (bkz. bildirim_rotasi.dart).
      for (final r in ['/patrol-tracking', '/complaints', '/tasks'])
        GoRoute(
          path: r,
          builder: (_, _) {
            gidilen.add(r);
            return Scaffold(body: Text('HEDEF $r'));
          },
        ),
    ],
  );
  return ProviderScope(
    overrides: [notificationsProvider.overrideWith(() => fake)],
    child: l10nRouterApp(router),
  );
}

void main() {
  final ornekler = [
    AppNotification(
      id: 'n1',
      tip: 'kacirilan_tur',
      mesaj: 'Gece turu kaçırıldı',
      okundu: false,
      createdAt: DateTime(2026, 7, 23, 9, 32),
    ),
    AppNotification(
      id: 'n2',
      tip: 'eksik_checkpoint',
      mesaj: 'B Blok noktası okutulmadı',
      okundu: true,
      createdAt: DateTime(2026, 7, 22, 22, 5),
    ),
  ];

  testWidgets('liste: mesajlar gorunur; okunmamis satirda "Yeni" rozeti',
      (tester) async {
    await tester.pumpWidget(_app(_FakeNotifications(ornekler)));
    await tester.pumpAndSettle();

    expect(find.text('Bildirimler'), findsOneWidget);
    expect(find.text('Gece turu kaçırıldı'), findsOneWidget);
    expect(find.text('B Blok noktası okutulmadı'), findsOneWidget);
    expect(find.text('Yeni'), findsOneWidget); // yalniz okunmamis
  });

  testWidgets('okunmamisa dokununca markRead(id) cagrilir ve rozet kalkar',
      (tester) async {
    final fake = _FakeNotifications(ornekler);
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gece turu kaçırıldı'));
    await tester.pumpAndSettle();

    expect(fake.marked, ['n1']);
    expect(find.text('Yeni'), findsNothing);
  });

  testWidgets('okunmusa dokunmak markRead CAGIRMAZ (gereksiz PATCH yok)',
      (tester) async {
    final fake = _FakeNotifications(ornekler);
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('B Blok noktası okutulmadı'));
    await tester.pumpAndSettle();
    expect(fake.marked, isEmpty);
  });

  testWidgets('bos liste: anlamli bos-durum mesaji', (tester) async {
    await tester.pumpWidget(_app(_FakeNotifications(const [])));
    await tester.pumpAndSettle();
    expect(find.text('Bildirim yok'), findsOneWidget);
  });

  testWidgets('P22b: dokunma ILGILI EKRANI acar (okunmus satirda da)',
      (tester) async {
    final fake = _FakeNotifications(ornekler);
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    // OKUNMUS satir (n2, eksik_checkpoint) — eskiden dokunma OLUYDU.
    await tester.tap(find.text('B Blok noktası okutulmadı'));
    await tester.pumpAndSettle();
    expect(gidilen, ['/patrol-tracking']);
    // Okunmusta gereksiz PATCH yok (eski davranis KORUNDU).
    expect(fake.marked, isEmpty);
  });

  testWidgets('P22b: okunmamis satir hem okundu isaretler HEM gider',
      (tester) async {
    final fake = _FakeNotifications(ornekler);
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gece turu kaçırıldı'));
    await tester.pumpAndSettle();
    expect(fake.marked, ['n1']);
    expect(gidilen, ['/patrol-tracking']);
  });
}
