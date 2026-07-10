import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/kargo/data/kargo_api.dart';
import 'package:mobile/src/features/kargo/domain/kargo_models.dart';
import 'package:mobile/src/features/kargo/presentation/kargo_screen.dart';

/// Aga cikmayan sahte istemci — liste sabit doner; teslim cagrilari
/// kaydedilir (widget testi).
class _FakeKargoApi extends KargoApi {
  _FakeKargoApi(this._items) : super(Dio());

  final List<Kargo> _items;
  final List<String> received = [];

  @override
  Future<List<Kargo>> fetchAll() async => _items;

  @override
  Future<Kargo> markReceived(String id) async {
    received.add(id);
    return _items.first;
  }
}

Kargo _k({
  String id = 'k-1',
  KargoDurum durum = KargoDurum.bekliyor,
  String? teslimAlanAd,
  String? fotoUrl,
}) =>
    Kargo(
      id: id,
      unitId: 'u-1',
      unitNo: 'A-12',
      firma: 'Aras Kargo',
      notlar: 'Orta boy koli',
      fotoUrl: fotoUrl,
      durum: durum,
      kaydedenUserId: 'g-1',
      kaydedenAd: 'Acme Guard',
      teslimAlanAd: teslimAlanAd,
      teslimZamani:
          teslimAlanAd == null ? null : DateTime.utc(2026, 7, 10, 13),
      createdAt: DateTime.utc(2026, 7, 10, 12),
    );

(_FakeKargoApi, Widget) _app(
  UserRole role, {
  List<Kargo> items = const [],
  String? initialKargoId,
}) {
  final api = _FakeKargoApi(items);
  return (
    api,
    ProviderScope(
      overrides: [
        kargoApiProvider.overrideWithValue(api),
        currentUserRoleProvider.overrideWith((ref) async => role),
      ],
      child: MaterialApp(
        home: KargoScreen(initialKargoId: initialKargoId),
      ),
    ),
  );
}

void main() {
  group('"Yeni kargo" FAB rol gorunurlugu (auth.md §4 kesin kurali)', () {
    testWidgets('security: FAB GORUNUR (kapi operasyonu)', (tester) async {
      final (_, app) = _app(UserRole.security, items: [_k()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Yeni kargo'), findsOneWidget);
    });

    for (final role in [
      UserRole.admin,
      UserRole.yonetici,
      UserRole.resident,
    ]) {
      testWidgets('${role.name}: FAB YOK (kayit yalniz guvenlik)',
          (tester) async {
        final (_, app) = _app(role, items: [_k()]);
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.text('Yeni kargo'), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
      });
    }
  });

  group('"Teslim aldim" butonu (yalniz sakin + bekleyen kayit)', () {
    testWidgets('resident bekleyen kartta butonu gorur; tiklama API cagirir',
        (tester) async {
      final (api, app) = _app(UserRole.resident, items: [_k()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Teslim aldim'), findsOneWidget);

      await tester.tap(find.text('Teslim aldim'));
      await tester.pumpAndSettle();
      expect(api.received, ['k-1']);
    });

    for (final role in [
      UserRole.security,
      UserRole.yonetici,
      UserRole.admin,
    ]) {
      testWidgets('${role.name}: bekleyen kartta buton YOK (salt izleme)',
          (tester) async {
        final (_, app) = _app(role, items: [_k()]);
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.text('Teslim aldim'), findsNothing);
      });
    }

    testWidgets('teslim alinan kayitta buton YOK; kim aldigi gorunur',
        (tester) async {
      final (_, app) = _app(
        UserRole.resident,
        items: [
          _k(durum: KargoDurum.teslimAlindi, teslimAlanAd: 'Acme Sakin'),
        ],
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Teslim alinan (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Teslim aldim'), findsNothing);
      expect(find.textContaining('Acme Sakin'), findsOneWidget);
    });
  });

  group('Bekleyen / Teslim alinan sekmeleri', () {
    testWidgets('kayitlar durumuna gore dogru sekmede', (tester) async {
      final (_, app) = _app(UserRole.security, items: [
        _k(),
        _k(
          id: 'k-2',
          durum: KargoDurum.teslimAlindi,
          teslimAlanAd: 'Acme Sakin',
        ),
      ]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Bekleyen (1)'), findsOneWidget);
      expect(find.text('Teslim alinan (1)'), findsOneWidget);
      // Varsayilan sekme Bekleyen: rozet 'Bekliyor'
      expect(find.text('Bekliyor'), findsOneWidget);
      await tester.tap(find.text('Teslim alinan (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Teslim alindi'), findsWidgets);
    });

    testWidgets('bos sekmeler anlamli mesaj gosterir', (tester) async {
      final (_, app) = _app(UserRole.security);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Teslim bekleyen kargo yok.'), findsOneWidget);
      await tester.tap(find.text('Teslim alinan (0)'));
      await tester.pumpAndSettle();
      expect(
        find.text('Henuz teslim alinan kargo kaydi yok.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('guvenlik formu acar: daire no + firma + not + foto akisi '
      '(mevcut Kamera/Galeri deseni)', (tester) async {
    final (_, app) = _app(UserRole.security);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni kargo'));
    await tester.pumpAndSettle();
    expect(find.text('Daire no * (orn. A-12)'), findsOneWidget);
    expect(find.text('Kargo firmasi *'), findsOneWidget);
    expect(find.text('Not (opsiyonel)'), findsOneWidget);
    expect(find.text('Paket fotografi (opsiyonel)'), findsOneWidget);
    // foto butonlari mevcut akisin adlariyla (complaints/gorev ile ayni)
    expect(find.text('Kamera'), findsOneWidget);
    expect(find.text('Galeriden sec'), findsOneWidget);
    expect(find.text('Kaydet ve sakinlere bildir'), findsOneWidget);
  });

  group('push tiklamasi (initialKargoId)', () {
    testWidgets('liste yuklenince ilgili kaydin detayi OTOMATIK acilir',
        (tester) async {
      final (_, app) = _app(
        UserRole.resident,
        items: [_k()],
        initialKargoId: 'k-1',
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      // Detay sheet'e ozgu satir: kaydeden guvenlik adiyla "Kayit: ..." satiri.
      expect(find.textContaining('Acme Guard'), findsOneWidget);
      // Sakin icin sheet'te de "Teslim aldim" sunulur (kart + sheet).
      expect(find.text('Teslim aldim'), findsNWidgets(2));
    });

    testWidgets('kayit listede yoksa sessizce listede kalinir (cokme yok)',
        (tester) async {
      final (_, app) = _app(
        UserRole.resident,
        items: [_k()],
        initialKargoId: 'olmayan-id',
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Aras Kargo'), findsOneWidget); // liste ekrani
      expect(tester.takeException(), isNull);
    });
  });
}
