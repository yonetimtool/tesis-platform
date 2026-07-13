import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/call/data/call_api.dart';
import 'package:mobile/src/features/call/data/call_launcher.dart';
import 'package:mobile/src/features/call/domain/call_models.dart';
import 'package:mobile/src/features/visitors/data/visitor_api.dart';
import 'package:mobile/src/features/visitors/domain/visitor_models.dart';
import 'package:mobile/src/features/visitors/presentation/visitors_screen.dart';

/// Sahte call API — detay ekranindaki CallButton gercek aga cikmasin diye.
class _FakeCallApi extends CallApi {
  _FakeCallApi({this.callable = false}) : super(Dio());
  final bool callable;

  @override
  Future<CallTarget> resolve(String userId) async {
    if (!callable) {
      throw const ApiException(
        code: 'not_found',
        message: 'aranamiyor',
        statusCode: 404,
      );
    }
    return CallTarget(
      userId: userId,
      ad: 'Hedef',
      role: 'resident',
      channel: 'phone',
      telefon: '+905550000000',
      telUri: 'tel:+905550000000',
    );
  }
}

class _FakeLauncher implements CallLauncher {
  final List<String> dialed = [];
  @override
  Future<bool> dial(String telUri) async {
    dialed.add(telUri);
    return true;
  }
}

/// Aga cikmayan sahte istemci — LOG listesi sabit doner (widget testi).
class _FakeVisitorApi extends VisitorApi {
  _FakeVisitorApi(this._items) : super(Dio());

  final List<Visitor> _items;

  @override
  Future<List<Visitor>> fetchAll({String? unitId}) async => _items;
}

Visitor _v({String id = 'v-1'}) => Visitor(
      id: id,
      unitId: 'u-1',
      unitNo: 'A-12',
      ziyaretciAd: 'Kurye Mehmet',
      notlar: 'Koli teslimati',
      kaydedenUserId: 'g-1',
      kaydedenAd: 'Acme Guard',
      targetResidentUserId: 'r-1',
      targetResidentAd: 'Hedef Sakin',
      createdAt: DateTime.utc(2026, 7, 10, 9),
    );

(_FakeVisitorApi, Widget) _app(
  UserRole role, {
  List<Visitor> items = const [],
  String? initialVisitorId,
  bool callable = false,
  _FakeLauncher? launcher,
}) {
  final api = _FakeVisitorApi(items);
  return (
    api,
    ProviderScope(
      overrides: [
        visitorApiProvider.overrideWithValue(api),
        currentUserRoleProvider.overrideWith((ref) async => role),
        callApiProvider.overrideWithValue(_FakeCallApi(callable: callable)),
        callLauncherProvider.overrideWithValue(launcher ?? _FakeLauncher()),
      ],
      child: MaterialApp(
        home: VisitorsScreen(initialVisitorId: initialVisitorId),
      ),
    ),
  );
}

void main() {
  group('"Yeni ziyaretci" FAB rol gorunurlugu (auth.md §4 kesin kurali)', () {
    testWidgets('security: FAB GORUNUR (kapi operasyonu)', (tester) async {
      final (_, app) = _app(UserRole.security, items: [_v()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Yeni ziyaretçi'), findsOneWidget);
    });

    for (final role in [
      UserRole.admin,
      UserRole.yonetici,
      UserRole.resident,
    ]) {
      testWidgets('${role.name}: FAB YOK (kayit yalniz guvenlik)',
          (tester) async {
        final (_, app) = _app(role, items: [_v()]);
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.text('Yeni ziyaretçi'), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
      });
    }
  });

  group('LOG-ONLY: onay/red UI YOK', () {
    testWidgets('hicbir rolde Onayla/Reddet butonu yok (log kaydi)',
        (tester) async {
      for (final role in [UserRole.resident, UserRole.security]) {
        final (_, app) = _app(role, items: [_v()]);
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.text('Onayla'), findsNothing, reason: role.name);
        expect(find.text('Reddet'), findsNothing, reason: role.name);
        // Durum rozeti de yok (bekliyor/onaylandi/reddedildi)
        expect(find.text('Bekliyor'), findsNothing, reason: role.name);
      }
    });

    testWidgets('kayit karti ziyaretci + daire + tarih gosterir', (tester) async {
      final (_, app) = _app(UserRole.security, items: [_v()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Kurye Mehmet'), findsOneWidget);
      expect(find.textContaining('A-12'), findsWidgets);
    });

    testWidgets('bos liste anlamli mesaj gosterir', (tester) async {
      final (_, app) = _app(UserRole.security);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Henüz ziyaretçi kaydı yok.'), findsOneWidget);
    });
  });

  group('rol-bazli arama (C1a) — ziyaretci detayinda', () {
    testWidgets('security: aranabilir hedef sakine "Sakini ara" gorunur',
        (tester) async {
      final (_, app) = _app(UserRole.security, items: [_v()], callable: true);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kurye Mehmet'));
      await tester.pumpAndSettle();
      expect(find.text('Sakini ara'), findsOneWidget); // security -> resident
      expect(find.text('Güvenliği ara'), findsNothing);
    });

    testWidgets('resident: kaydi acan guvenlige "Güvenliği ara" gorunur',
        (tester) async {
      final (_, app) = _app(UserRole.resident, items: [_v()], callable: true);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kurye Mehmet'));
      await tester.pumpAndSettle();
      expect(find.text('Güvenliği ara'), findsOneWidget); // resident -> security
      expect(find.text('Sakini ara'), findsNothing);
    });

    testWidgets('riza yoksa "Aranamıyor" — numara/buton yok', (tester) async {
      final (_, app) = _app(UserRole.security, items: [_v()]); // callable=false
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kurye Mehmet'));
      await tester.pumpAndSettle();
      expect(find.text('Aranamıyor'), findsOneWidget);
      expect(find.text('Sakini ara'), findsNothing);
    });
  });

  testWidgets('guvenlik formu acar: ad + daire no + sakin secici + not',
      (tester) async {
    final (_, app) = _app(UserRole.security);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni ziyaretçi'));
    await tester.pumpAndSettle();
    expect(find.text('Ziyaretçi adı *'), findsOneWidget);
    expect(find.text('Daire no * (örn. A-12)'), findsOneWidget);
    expect(find.text('Sakinleri getir'), findsOneWidget);
    expect(find.text('Not (opsiyonel)'), findsOneWidget);
    expect(find.text('Kaydet ve sakine bildir'), findsOneWidget);
  });

  group('push tiklamasi (initialVisitorId)', () {
    testWidgets('liste yuklenince ilgili kaydin detayi OTOMATIK acilir',
        (tester) async {
      final (_, app) = _app(
        UserRole.resident,
        items: [_v()],
        initialVisitorId: 'v-1',
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      // Detay sheet'e ozgu satir: kaydeden guvenlik adiyla "Kayit: ..." satiri.
      expect(find.textContaining('Acme Guard'), findsOneWidget);
    });

    testWidgets('kayit listede yoksa sessizce listede kalinir (cokme yok)',
        (tester) async {
      final (_, app) = _app(
        UserRole.resident,
        items: [_v()],
        initialVisitorId: 'olmayan-id',
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Kurye Mehmet'), findsOneWidget); // liste ekrani
      expect(tester.takeException(), isNull);
    });
  });
}
