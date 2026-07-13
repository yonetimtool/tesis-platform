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
/// Varsayilan: aranamiyor (404). callable=true ise hedef doner.
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

/// Aga cikmayan sahte istemci — liste sabit doner; yanit cagrilari kaydedilir
/// (widget testi).
class _FakeVisitorApi extends VisitorApi {
  _FakeVisitorApi(this._items) : super(Dio());

  final List<Visitor> _items;
  final List<(String, bool)> answered = [];

  @override
  Future<List<Visitor>> fetchAll({String? unitId}) async => _items;

  @override
  Future<Visitor> answer(String id, {required bool onayla}) async {
    answered.add((id, onayla));
    return _items.first;
  }
}

Visitor _v({
  String id = 'v-1',
  VisitorDurum durum = VisitorDurum.bekliyor,
  String? yanitlayanAd,
}) =>
    Visitor(
      id: id,
      unitId: 'u-1',
      unitNo: 'A-12',
      ziyaretciAd: 'Kurye Mehmet',
      notlar: 'Koli teslimati',
      durum: durum,
      kaydedenUserId: 'g-1',
      kaydedenAd: 'Acme Guard',
      targetResidentUserId: 'r-1',
      targetResidentAd: 'Hedef Sakin',
      yanitlayanAd: yanitlayanAd,
      yanitZamani: yanitlayanAd == null ? null : DateTime.utc(2026, 7, 10, 10),
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

  group('Onayla/Reddet butonlari (yalniz sakin + bekleyen kayit)', () {
    testWidgets('resident bekleyen kartta butonlari gorur; Onayla API cagirir',
        (tester) async {
      final (api, app) = _app(UserRole.resident, items: [_v()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Onayla'), findsOneWidget);
      expect(find.text('Reddet'), findsOneWidget);

      await tester.tap(find.text('Onayla'));
      await tester.pumpAndSettle();
      expect(api.answered, [('v-1', true)]);
    });

    testWidgets('resident Reddet -> API reddedildi ile cagrilir',
        (tester) async {
      final (api, app) = _app(UserRole.resident, items: [_v()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reddet'));
      await tester.pumpAndSettle();
      expect(api.answered, [('v-1', false)]);
    });

    for (final role in [
      UserRole.security,
      UserRole.yonetici,
      UserRole.admin,
    ]) {
      testWidgets('${role.name}: bekleyen kartta buton YOK (salt izleme)',
          (tester) async {
        final (_, app) = _app(role, items: [_v()]);
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.text('Onayla'), findsNothing);
        expect(find.text('Reddet'), findsNothing);
      });
    }

    testWidgets('sonuclanmis kayitta buton YOK (Gecmis sekmesi)',
        (tester) async {
      final (_, app) = _app(
        UserRole.resident,
        items: [_v(durum: VisitorDurum.onaylandi, yanitlayanAd: 'Acme Sakin')],
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Geçmiş (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Onayla'), findsNothing);
      // sonuc satiri: kim yanitladi gorunur
      expect(find.textContaining('Acme Sakin'), findsOneWidget);
    });
  });

  group('Bekleyen / Gecmis sekmeleri', () {
    testWidgets('kayitlar durumuna gore dogru sekmede', (tester) async {
      final (_, app) = _app(UserRole.security, items: [
        _v(),
        _v(
          id: 'v-2',
          durum: VisitorDurum.reddedildi,
          yanitlayanAd: 'Acme Sakin',
        ),
      ]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Bekleyen (1)'), findsOneWidget);
      expect(find.text('Geçmiş (1)'), findsOneWidget);
      // Varsayilan sekme Bekleyen: rozet 'Bekliyor'
      expect(find.text('Bekliyor'), findsOneWidget);
      await tester.tap(find.text('Geçmiş (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Reddedildi'), findsWidgets);
    });

    testWidgets('bos sekmeler anlamli mesaj gosterir', (tester) async {
      final (_, app) = _app(UserRole.security);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Onay bekleyen ziyaretçi yok.'), findsOneWidget);
      await tester.tap(find.text('Geçmiş (0)'));
      await tester.pumpAndSettle();
      expect(
        find.text('Henüz sonuçlanan ziyaretçi kaydı yok.'),
        findsOneWidget,
      );
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
    // Hedef sakin secicisi: daire girip "Sakinleri getir" ile sakinler cekilir.
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
      // Sakin icin sheet'te de Onayla/Reddet sunulur (kart + sheet).
      expect(find.text('Onayla'), findsNWidgets(2));
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
