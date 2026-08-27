import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/auth/data/auth_api.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
import 'package:mobile/src/features/auth/domain/auth_repository.dart';
import 'package:mobile/src/features/auth/presentation/davet_screen.dart';

import 'helpers/l10n_test_app.dart';
import 'helpers/sosyal_kapali.dart';

/// (P155 §7/§8) DAVET EKRANI — derin baglantiyla gelen kayit.
///
/// Olculen: jeton cozulunce tesis/daire/telefon cizilir; parola yolu
/// `davetParola`yi jeton + parola ile cagirir; gecersiz jetonda dogru
/// metin. SMS HIC istenmez (ne parola ne sosyal yolda kod alani yok).

class _SahteAuthApi extends AuthApi {
  _SahteAuthApi(this._cozum, {this.hataKodu}) : super(Dio());

  final DavetCozum? _cozum;
  final String? hataKodu;

  @override
  Future<DavetCozum> davetCoz(String jeton) async {
    if (hataKodu != null) {
      throw ApiException(code: hataKodu!, message: '', statusCode: 410);
    }
    return _cozum!;
  }
}

/// Davet tamamlamayi kaydeden sahte depo; tum arayuzu doldurur ama yalniz
/// `davetParola`/`davetSosyal`i olcer.
class _SahteRepo implements AuthRepository {
  final davetParolaCagrilari = <Map<String, String?>>[];

  @override
  Future<void> davetParola({
    required String jeton,
    String? ad,
    required String newPassword,
  }) async {
    davetParolaCagrilari.add({'jeton': jeton, 'ad': ad, 'parola': newPassword});
  }

  @override
  Future<void> davetSosyal({
    required String jeton,
    required String baglamaJetonu,
    String? ad,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

Future<ProviderContainer> _sur(
  WidgetTester tester, {
  DavetCozum? cozum,
  String? hataKodu,
  _SahteRepo? repo,
}) async {
  final kap = ProviderContainer(overrides: [
    ...sosyalKapali,
    authApiProvider.overrideWithValue(_SahteAuthApi(cozum, hataKodu: hataKodu)),
    if (repo != null) authRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: kap,
      child: l10nApp(const DavetScreen(jeton: 'davet-jeton-1')),
    ),
  );
  await tester.pumpAndSettle();
  return kap;
}

const _sakinCozum = DavetCozum(
  tesisAd: 'Oltu Sitesi',
  rol: 'resident',
  ad: 'A-12 sakini',
  telefonMaskeli: '+9053***203',
  daireNo: 'A-12',
);

void main() {
  testWidgets('gecerli jeton: tesis + daire + telefon(maskeli) cizilir',
      (tester) async {
    await _sur(tester, cozum: _sakinCozum);
    expect(find.textContaining('Oltu Sitesi'), findsOneWidget);
    expect(find.text('A-12'), findsOneWidget);
    expect(find.text('+9053***203'), findsOneWidget);
    // Yontem: parola dugmesi var, SMS/kod alani YOK.
    expect(find.byKey(const Key('davet-yontem-parola')), findsOneWidget);
  });

  testWidgets('parola yolu: davetParola jeton + parola ile cagrilir',
      (tester) async {
    final repo = _SahteRepo();
    await _sur(tester, cozum: _sakinCozum, repo: repo);

    await tester.tap(find.byKey(const Key('davet-yontem-parola')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('davet-parola')), 'DavetParola1!');
    await tester.tap(find.byKey(const Key('davet-parola-gonder')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(repo.davetParolaCagrilari.single['jeton'], 'davet-jeton-1');
    expect(repo.davetParolaCagrilari.single['parola'], 'DavetParola1!');
    // Ad DAIREDEN turetilen on-doldurma ile gitti (kullanici degistirebilir).
    expect(repo.davetParolaCagrilari.single['ad'], 'A-12 sakini');
  });

  testWidgets('yonetici daveti: daire SATIRI YOK', (tester) async {
    await _sur(
      tester,
      cozum: const DavetCozum(
        tesisAd: 'Oltu Sitesi',
        rol: 'yonetici',
        ad: 'Ali Veli',
        telefonMaskeli: '+9053***201',
      ),
    );
    expect(find.text('A-12'), findsNothing);
    expect(find.byKey(const Key('davet-yontem-parola')), findsOneWidget);
  });

  testWidgets('suresi dolmus jeton: gecersiz metni', (tester) async {
    await _sur(tester, hataKodu: 'davet_suresi_doldu');
    expect(find.textContaining('süresi dolmuş'), findsOneWidget);
    expect(find.byKey(const Key('davet-yontem-parola')), findsNothing);
  });
}
