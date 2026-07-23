import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/transparency/data/transparency_api.dart';
import 'package:mobile/src/features/transparency/domain/transparency_models.dart';
import 'package:mobile/src/features/transparency/presentation/transparency_screen.dart';

TransparencyBoard _board({bool yayinlandi = true}) => TransparencyBoard(
      ay: '2026-06',
      yayinlandi: yayinlandi,
      toplamGelirKurus: 300000,
      toplamGiderKurus: 200000,
      netKurus: 100000,
      oncekiAyNetKurus: 50000,
      giderDagilimi: const [
        TransparencyKategori(ad: 'Elektrik', toplamKurus: 200000, yuzde: 100),
      ],
      aidat: const TransparencyAidat(
        tahakkukKurus: 150000,
        tahsilatKurus: 75000,
        tutarOraniYuzde: 50,
        toplamDaire: 2,
        odeyenDaire: 1,
        daireOraniYuzde: 50,
        gecikenDaireSayisi: 1,
      ),
    );

class _FakeApi extends TransparencyApi {
  _FakeApi({required this.months, TransparencyBoard? board})
      : _b = board ?? _board(),
        super(Dio());

  final List<TransparencyAyOzet> months;
  final TransparencyBoard _b;
  bool? lastPublishArg;

  @override
  Future<List<TransparencyAyOzet>> fetchMonths() async => months;

  @override
  Future<TransparencyBoard> fetchBoard(String ay) async => _b;

  @override
  Future<TransparencyBoard> setPublish(String ay, bool yayin) async {
    lastPublishArg = yayin;
    return _board(yayinlandi: yayin);
  }
}

Widget _app(_FakeApi api, UserRole role) => ProviderScope(
      overrides: [
        transparencyApiProvider.overrideWithValue(api),
        currentUserRoleProvider.overrideWith((ref) async => role),
      ],
      child: const MaterialApp(home: TransparencyScreen()),
    );

void main() {
  testWidgets('sakin + yayin yok -> bos durum mesaji', (tester) async {
    await tester.pumpWidget(_app(_FakeApi(months: const []), UserRole.resident));
    await tester.pumpAndSettle();
    expect(find.textContaining('Yönetim henüz özet yayınlamadı'), findsOneWidget);
    // yayin anahtari YOK (sakin).
    expect(find.byKey(const Key('transparency_publish_switch')), findsNothing);
  });

  testWidgets('sakin + yayinlanmis ay -> ozet kartlari gorunur', (tester) async {
    final api = _FakeApi(months: const [
      TransparencyAyOzet(ay: '2026-06', yayinlandi: true, netKurus: 100000),
    ]);
    await tester.pumpWidget(_app(api, UserRole.resident));
    await tester.pumpAndSettle();
    expect(find.text('1.000,00 TL'), findsWidgets); // net = 100000 kurus
    expect(find.textContaining('Gecikmede 1 daire'), findsOneWidget);
    expect(find.byKey(const Key('transparency_publish_switch')), findsNothing);
  });

  testWidgets('yonetici -> yayin anahtari gorunur, tiklayinca setPublish cagrilir',
      (tester) async {
    final api = _FakeApi(months: const [
      TransparencyAyOzet(ay: '2026-06', yayinlandi: false, netKurus: 100000),
    ], board: _board(yayinlandi: false));
    await tester.pumpWidget(_app(api, UserRole.yonetici));
    await tester.pumpAndSettle();
    final sw = find.byKey(const Key('transparency_publish_switch'));
    expect(sw, findsOneWidget);
    expect(find.textContaining('Önizleme'), findsOneWidget);
    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(api.lastPublishArg, isTrue);
  });
}
