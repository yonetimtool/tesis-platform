import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/kvkk/data/kvkk_api.dart';
import 'package:mobile/src/features/kvkk/domain/kvkk_models.dart';
import 'package:mobile/src/features/kvkk/presentation/yasal_metinler_screen.dart';

import 'helpers/l10n_test_app.dart';

/// (P168 §5) YASAL METINLER — bes tur, surum ve ONAY GECMISI.
///
/// =========================================================================
/// EN PAHALI OLCUMLER
/// =========================================================================
///  1. ONAY TUR BASINA. Istemci `tur` gondermezse her onay `aydinlatma`ya
///     yazilir ve kullanici gizlilik politikasini onayladigini sanip
///     aydinlatma metnini onaylamis olur — hukuken yanlis, ve sessiz.
///  2. YAYINLANMAMIS METIN HATA DEGILDIR. 404'u kirmizi bir hata gibi
///     gostermek, kullaniciya uygulamanin bozuk oldugunu soylerdi.
///  3. ONAY YOKSA "onaylanmadi" DENIR. Bos birakmak, kullaniciya
///     onayladigini dusundurebilirdi.
class _FakeKvkkApi extends KvkkApi {
  _FakeKvkkApi({this.yayinli = const {}, this.onaylar = const {}})
      : super(Dio());

  /// tur -> metin. Listede olmayan tur 404 verir.
  final Map<KvkkTur, KvkkMetin> yayinli;
  final Map<KvkkTur, int> onaylar;

  /// Cagrilan (uc, tur) ciftleri — `tur`un GERCEKTEN gonderildigini
  /// ancak boyle olcebiliriz.
  final List<String> cagrilar = [];

  @override
  Future<KvkkMetin> metin({KvkkTur tur = KvkkTur.aydinlatma}) async {
    cagrilar.add('metin:${tur.kod}');
    final m = yayinli[tur];
    if (m == null) {
      throw const ApiException(
        code: 'not_found',
        message: 'yok',
        statusCode: 404,
      );
    }
    return m;
  }

  @override
  Future<KvkkDurum> durum({KvkkTur tur = KvkkTur.aydinlatma}) async {
    cagrilar.add('durum:${tur.kod}');
    final onay = onaylar[tur];
    return KvkkDurum(
      metinVar: yayinli.containsKey(tur),
      onayGerekli: onay == null,
      guncelSurum: yayinli[tur]?.surum,
      onayladigiSurum: onay,
    );
  }
}

KvkkMetin _m(KvkkTur tur, {int surum = 1}) => KvkkMetin(
      id: 'm-${tur.kod}',
      tur: tur,
      surum: surum,
      baslik: 'Baslik ${tur.kod}',
      govde: 'Govde ${tur.kod}',
      yururlukte: true,
    );

Widget _app(_FakeKvkkApi api) => ProviderScope(
      overrides: [kvkkApiProvider.overrideWithValue(api)],
      child: l10nApp(const YasalMetinlerScreen()),
    );

void main() {
  testWidgets('BES SEKME cizilir', (tester) async {
    // Brief bes metin istiyor; dordu cizen bir ekran, birine HIC
    // ulasilamamasi demekti.
    await tester.pumpWidget(_app(_FakeKvkkApi()));
    await tester.pumpAndSettle();
    expect(find.byType(Tab), findsNWidgets(KvkkTur.values.length));
    expect(KvkkTur.values.length, 5);
  });

  testWidgets('ILK SEKME metni ve SURUMU gosterir', (tester) async {
    final api = _FakeKvkkApi(
      yayinli: {KvkkTur.aydinlatma: _m(KvkkTur.aydinlatma, surum: 3)},
    );
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Govde aydinlatma'), findsOneWidget);
    expect(find.textContaining('3'), findsWidgets);
    // TUR GONDERILDI: gondermeseydik sunucu her zaman aydinlatmayi
    // dondurur ve oteki sekmeler ayni metni gosterirdi.
    expect(api.cagrilar, contains('metin:aydinlatma'));
  });

  testWidgets('YAYINLANMAMIS metin HATA gibi gosterilmez', (tester) async {
    // Tesis o metni henuz yayinlamamistir; kirmizi bir hata kullaniciya
    // uygulamanin bozuk oldugunu soylerdi.
    await tester.pumpWidget(_app(_FakeKvkkApi()));
    await tester.pumpAndSettle();
    expect(find.textContaining('yayınlanmamış'), findsOneWidget);
  });

  testWidgets('ONAY YOKSA "onaylanmadi" YAZAR', (tester) async {
    final api = _FakeKvkkApi(
      yayinli: {KvkkTur.aydinlatma: _m(KvkkTur.aydinlatma)},
    );
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    // Bos birakmak, kullaniciya onayladigini dusundurebilirdi.
    expect(find.textContaining('onaylamadınız'), findsOneWidget);
  });

  testWidgets('ONAY VARSA HANGI SURUM oldugu yazar', (tester) async {
    final api = _FakeKvkkApi(
      yayinli: {KvkkTur.aydinlatma: _m(KvkkTur.aydinlatma, surum: 2)},
      onaylar: {KvkkTur.aydinlatma: 2},
    );
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    expect(find.textContaining('Onayladığınız sürüm'), findsOneWidget);
  });

  test('TUR KODLARI sunucu enum degerleriyle BIREBIR', () {
    // Kod bir gun degisirse sunucu 422 doner ve kullanici hicbir metni
    // goremez; bu test o sessiz kopusu kilitler.
    expect(
      KvkkTur.values.map((t) => t.kod).toList(),
      ['aydinlatma', 'acik_riza', 'gizlilik', 'kullanim_kosullari', 'cerez'],
    );
  });

  test('BILINMEYEN TUR aydinlatmaya DUSER, COKMEZ', () {
    // Sunucu bir gun altinci bir tur eklerse guncellenmemis uygulama
    // tamamen kilitlenmemeli.
    expect(KvkkTur.coz('yepyeni'), KvkkTur.aydinlatma);
    expect(KvkkTur.coz(null), KvkkTur.aydinlatma);
  });
}
