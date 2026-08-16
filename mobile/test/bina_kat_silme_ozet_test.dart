// (P165 §1) MOBIL: KAT SILME — ETKI OZETI VE IKINCI KAPI.
//
// Brief'in ilkesi: "kullanici ne kaybedecegini SILMEDEN ONCE gorsun."
//
// Dort iddia kilitlenir:
//
//  1. OZET SUNUCUDAN GELIR. Yerel liste yalniz DAIREYI bilir; sakini,
//     tahakkugu, talebi bilmez — oysa kaybedilen esas sey onlar.
//  2. BOS KAT AYRI: kaybedilecek bir sey yoksa uyari da olmaz (her seye
//     uyari koymak, uyarinin anlamini yok eder).
//  3. MALI KAYIT VARSA IKINCI KAPI: sakin ya da talep yeniden
//     olusturulabilir, bir TAHSILAT KAYDI olusturulamaz. Dugme, kat
//     numarasi YAZILANA KADAR kapali — islev kaldirilmadi, KAZA engellendi.
//  4. UST SEVIYEDEN ACILINCA BLOK SECILIR. Onceden bos blok gonderiliyor
//     ve uc 422 doniyordu (`blok` min_length=1).
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/building_map/data/bina_duzenleme_api.dart';
import 'package:mobile/src/features/building_map/domain/bina_duzenleme_models.dart';
import 'package:mobile/src/features/building_map/presentation/bina_duzenleme_screen.dart';

import 'helpers/l10n_test_app.dart';

class _FakeApi extends BinaDuzenlemeApi {
  _FakeApi({required this.onizleme}) : super(Dio());

  /// Sunucunun dondurecegi ozet.
  KatOnizleme onizleme;

  /// `(blok, kat)` ciftleri — ozetin SUNUCUYA soruldugunu kanitlar.
  final List<(String, int)> onizlemeCagrilari = [];

  /// `deleteFloor` cagrisi — silmenin gercekten gittigini kanitlar.
  final List<(String, int)> silmeler = [];

  @override
  Future<List<BuildingBlock>> listBlocks() async =>
      const [BuildingBlock(id: 'b-A', ad: 'A', unitSayisi: 2)];

  @override
  Future<List<EditorUnit>> listUnits() async => const [
        EditorUnit(id: 'u-1', no: 'A-1', blok: 'A', kat: 1, sira: 1),
        EditorUnit(id: 'u-2', no: 'A-2', blok: 'A', kat: 1, sira: 2),
      ];

  @override
  Future<KatOnizleme> fetchKatOnizleme({
    required String blok,
    required int kat,
  }) async {
    onizlemeCagrilari.add((blok, kat));
    return onizleme;
  }

  @override
  Future<int> deleteFloor({
    required String blok,
    required int kat,
    bool cascade = true,
  }) async {
    silmeler.add((blok, kat));
    return 2;
  }
}

KatOnizleme _ozet({
  int daire = 2,
  int sakin = 3,
  int tahakkuk = 0,
  int odeme = 0,
  int talep = 1,
  int rezervasyon = 0,
}) =>
    KatOnizleme(
      daire: daire,
      sakin: sakin,
      tahakkuk: tahakkuk,
      odeme: odeme,
      talep: talep,
      rezervasyon: rezervasyon,
      maliKayit: tahakkuk > 0 || odeme > 0,
    );

Widget _app(_FakeApi api) => ProviderScope(
      overrides: [
        binaDuzenlemeApiProvider.overrideWithValue(api),
        currentUserRoleProvider.overrideWith((ref) async => UserRole.yonetici),
      ],
      child: l10nApp(const BinaDuzenlemeScreen()),
    );

/// Bloga girer, "Yapısal araçlar" menusunden "Katı sil"i acar ve 1. kati secer.
Future<void> _katSilAc(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('Blok A'));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.construction_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Katı sil').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<int>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Kat 1').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('KAT SECILINCE ozet SUNUCUYA sorulur ve SOMUT sayilar cikar',
      (tester) async {
    final api = _FakeApi(onizleme: _ozet(daire: 2, sakin: 3, talep: 1));
    await tester.pumpWidget(_app(api));
    await _katSilAc(tester);

    // Ozet ISTEMCIDE hesaplanmadi: uca (blok, kat) ile gidildi.
    expect(api.onizlemeCagrilari, [('A', 1)]);
    expect(find.textContaining('2 daire'), findsOneWidget);
    expect(find.textContaining('3 sakin'), findsOneWidget);
    expect(find.textContaining('1 açık şikayet'), findsOneWidget);
  });

  testWidgets('BOS KAT: uyari YOK, tek onayla gider', (tester) async {
    final api = _FakeApi(
      onizleme: _ozet(daire: 0, sakin: 0, talep: 0),
    );
    await tester.pumpWidget(_app(api));
    await _katSilAc(tester);

    expect(find.textContaining('Bu katta daire yok'), findsOneWidget);
    expect(find.textContaining('Onaylamak için kat numarasını'), findsNothing);
    // Dugme ACIK: kaybedilecek bir sey yok.
    final sil = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sil'),
    );
    expect(sil.onPressed, isNotNull);
  });

  testWidgets('MALI KAYIT: ayri uyari + IKINCI KAPI (kat no yazilana kadar kapali)',
      (tester) async {
    final api = _FakeApi(onizleme: _ozet(tahakkuk: 9, odeme: 4));
    await tester.pumpWidget(_app(api));
    await _katSilAc(tester);

    expect(find.textContaining('aidat kaydı var'), findsOneWidget);
    expect(find.textContaining('9 tahakkuk'), findsOneWidget);

    FilledButton silDugmesi() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Sil'),
        );
    // KAPI KAPALI.
    expect(silDugmesi().onPressed, isNull);

    // YANLIS sayi kapiyi ACMAZ.
    await tester.enterText(find.byType(TextField).last, '2');
    await tester.pumpAndSettle();
    expect(silDugmesi().onPressed, isNull);

    // DOGRU sayi acar — islev KALDIRILMADI, yalnizca kaza engellendi.
    await tester.enterText(find.byType(TextField).last, '1');
    await tester.pumpAndSettle();
    expect(silDugmesi().onPressed, isNotNull);

    // Onay diyalogu SOMUT sayilarla cikar ve silme gercekten gider.
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 daire, 3 sakin'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sil').last);
    await tester.pumpAndSettle();
    expect(api.silmeler, [('A', 1)]);
  });

  testWidgets('UST SEVIYEDEN: blok secilmeden Sil KAPALI, secilince ozet gelir',
      (tester) async {
    // Onceki davranis: blok BOS gidiyordu ve uc 422 doniyordu (`blok`
    // min_length=1) — kullanici sebebini anlamadigi bir hata aliyordu.
    final api = _FakeApi(onizleme: _ozet());
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.construction_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Katı sil').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Sil'))
          .onPressed,
      isNull,
    );
    // Blok secilmeden ozet de SORULMAZ.
    expect(api.onizlemeCagrilari, isEmpty);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kat 1').last);
    await tester.pumpAndSettle();

    expect(api.onizlemeCagrilari, [('A', 1)]);
  });
}
