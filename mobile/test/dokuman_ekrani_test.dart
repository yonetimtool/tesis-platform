import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/dokumanlar/data/dokuman_api.dart';
import 'package:mobile/src/features/dokumanlar/domain/dokuman_models.dart';
import 'package:mobile/src/features/dokumanlar/presentation/dokuman_screen.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';

import 'helpers/l10n_test_app.dart';

/// (P167 ek) SITE DOKUMANLARI — sakin gorunumu.
///
/// =========================================================================
/// BU DOSYANIN OLCTUGU EN PAHALI SEY: GORUNURLUK SUZGECI ISTEMCIDE DEGIL
/// =========================================================================
/// Ekran hicbir gorunurluk karari VERMEZ; sunucudan ne gelirse onu cizer.
/// Bu bilincli: istemcide ikinci bir "acik mi" suzgeci yazsaydik, o suzgec
/// bir gun yanlis yazildiginda KAPALI bir belge sakinin ekraninda
/// gorunurdu — ve bu sessiz olurdu.
///
/// Bunun testteki karsiligi: model `sakineAcik` alani TASIMAZ ve ekran
/// yalnizca `/me/dokumanlar` ucunu cagirir.
class _FakeDokumanApi extends DokumanApi {
  _FakeDokumanApi(this._items, {this.url = 'https://depo/x.pdf'}) : super(Dio());

  final List<SiteDokumani> _items;
  final String url;

  /// Hangi uclarin cagrildigi KAYDEDILIR: yonetim ucuna dokunulmadigini
  /// ancak boyle olcebiliriz.
  final List<String> cagrilar = [];

  @override
  Future<List<SiteDokumani>> fetchAll() async {
    cagrilar.add('/me/dokumanlar');
    return _items;
  }

  @override
  Future<String> indirmeBaglantisi(String id) async {
    cagrilar.add('/me/dokumanlar/$id/indir');
    return url;
  }
}

SiteDokumani _d({
  String id = 'd-1',
  String ad = 'Yonetim Plani',
  int? boyut = 2048,
}) => SiteDokumani(
  id: id,
  ad: ad,
  boyutBayt: boyut,
  createdAt: DateTime.utc(2026, 3, 12),
);

Widget _app(_FakeDokumanApi api) => ProviderScope(
  overrides: [dokumanApiProvider.overrideWithValue(api)],
  child: l10nApp(const DokumanScreen()),
);

void main() {
  testWidgets('liste SUNUCUDAN gelir; ekran suzgec UYGULAMAZ', (tester) async {
    final api = _FakeDokumanApi([
      _d(ad: 'Yonetim Plani'),
      _d(id: 'd-2', ad: 'Butce 2026'),
    ]);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Yonetim Plani'), findsOneWidget);
    expect(find.text('Butce 2026'), findsOneWidget);
    // YALNIZ SAKIN UCU cagrildi — yonetim ucu (`/dokumanlar`) TUM arsivi
    // doner ve bu ekran ona hic dokunmamali.
    expect(api.cagrilar, ['/me/dokumanlar']);
  });

  testWidgets('BOS listede arama kutusu CIZILMEZ', (tester) async {
    // Bos bir arsivde arama kutusu, aranacak bir sey varmis izlenimi
    // verirdi.
    await tester.pumpWidget(_app(_FakeDokumanApi(const [])));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.folder_open_outlined), findsOneWidget);
  });

  testWidgets('arama ada gore ANLIK suzer', (tester) async {
    final api = _FakeDokumanApi([
      _d(ad: 'Yonetim Plani'),
      _d(id: 'd-2', ad: 'Butce 2026'),
    ]);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'but');
    await tester.pumpAndSettle();

    expect(find.text('Butce 2026'), findsOneWidget);
    expect(find.text('Yonetim Plani'), findsNothing);
    // SUZME ISTEMCIDE: ikinci bir ag cagrisi YAPILMAZ (liste zaten cekili).
    expect(api.cagrilar, ['/me/dokumanlar']);
  });

  testWidgets('dokunma INDIRME BAGLANTISI ucunu cagirir', (tester) async {
    final api = _FakeDokumanApi([_d()]);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yonetim Plani'));
    await tester.pump();

    expect(api.cagrilar, contains('/me/dokumanlar/d-1/indir'));
  });

  testWidgets('BOYUT YOKSA yazilmaz — "0 KB" UYDURULMAZ', (tester) async {
    // "0 KB" yazmak, dosyanin BOS oldugunu soylemek olurdu; oysa yalnizca
    // boyutu kayitli degil (eski kayitlar boyutsuz yuklendi).
    await tester.pumpWidget(_app(_FakeDokumanApi([_d(boyut: null)])));
    await tester.pumpAndSettle();

    expect(find.textContaining('KB'), findsNothing);
  });

  testWidgets('boyut VARSA KB olarak yazilir', (tester) async {
    await tester.pumpWidget(_app(_FakeDokumanApi([_d(boyut: 2048)])));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 KB'), findsOneWidget);
  });

  test('SAKIN menusunde dokumanlar VAR, saha rollerinde YOK', () {
    // Dokuman SAKIN icin acildi. Guvenlik ve gorevli tesisin sakini degil
    // CALISANIDIR; site dokumani onlarin isi degil ve uc de onlara kapali
    // (403). Menude gostermek, tiklaninca hata veren bir karo olurdu.
    expect(
      homeMenuForRole(UserRole.resident),
      contains(HomeMenuEntry.dokumanlar),
    );
    for (final rol in [
      UserRole.security,
      UserRole.tesisGorevlisi,
      UserRole.guvenlikAmiri,
    ]) {
      expect(
        homeMenuForRole(rol),
        isNot(contains(HomeMenuEntry.dokumanlar)),
        reason: '$rol',
      );
    }
  });

  test('model `sakineAcik` alani TASIMAZ', () {
    // Alani tasimak, istemcide "acik mi" diye ikinci bir suzgec yazma
    // ihtimali dogururdu — ve o suzgec bir gun yanlis yazilirsa kapali
    // bir belge ekranda gorunurdu. Sakin ucundan gelen her kayit zaten
    // aciktir.
    final json = SiteDokumani.fromJson({
      'id': 'x',
      'ad': 'A',
      'created_at': '2026-03-12T00:00:00Z',
      'sakine_acik': false,
    });
    expect(json.ad, 'A');
    expect(
      SiteDokumani.fromJson(const {}).ad,
      isEmpty,
      reason: 'eksik govde COKMEMELI',
    );
  });
}
