/// (P220 §4) SAKINLER BLOKLARA GORE GRUPLANIR + BLOKTA ARAMA.
///
/// ===========================================================================
/// NE OLCULUYOR
/// ===========================================================================
/// 1. Gruplama: bloklar ALFABETIK, "blok atanmamis" EN SONDA ve
///    GIZLENMIYOR.
/// 2. Suzgec sunucuya dogru parametrelerle gidiyor: `q` (ad+daire+blok
///    metin aramasi) ve `blok` (TAM eslesme daraltmasi) AYRI.
/// 3. Iki karakterden kisa arama GITMIYOR.
///
/// Taklit HTTP katmaninda (P200 dersi): `ResidentsApi` degil `Dio`
/// taklit ediliyor, boylece yol ve sorgu parametreleri GERCEKTEN
/// olculuyor.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/residents/data/residents_api.dart';

class _Kayit {
  _Kayit(this.yol, this.sorgu);
  final String yol;
  final Map<String, dynamic>? sorgu;
}

class _SahteAdapter implements HttpClientAdapter {
  _SahteAdapter(this.govde);
  final String govde;
  final List<_Kayit> istekler = [];

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<List<int>>? _, Future<void>? __) async {
    istekler.add(_Kayit(options.path, options.queryParameters));
    return ResponseBody.fromString(govde, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

ProviderContainer _kap(_SahteAdapter a) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = a;
  return ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
}

ResidentMember _uye(String ad, {String? blok, String? daire}) =>
    ResidentMember(
      userId: 'u-$ad',
      ad: ad,
      unitNo: daire,
      blok: blok,
      isActive: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bloklaraGore', () {
    test('BLOKLAR ALFABETIK, BLOKSUZ EN SONDA', () {
      final gruplar = bloklaraGore([
        _uye('Zeynep', blok: 'B'),
        _uye('Dairesiz'),
        _uye('Ayse', blok: 'A'),
        _uye('Mehmet', blok: 'A'),
      ]);
      expect(gruplar.map((g) => g.blok).toList(), ['A', 'B', null]);
      expect(gruplar.first.sakinler.map((m) => m.ad).toList(),
          ['Ayse', 'Mehmet']);
    });

    test('BLOKSUZ SAKIN GIZLENMEZ', () {
      // Gizlemek, siteden ayrilmis ama hesabi duran bir sakini
      // BULUNAMAZ yapardi — istegin gerekcesi tam olarak onu bulup
      // silmek.
      final gruplar = bloklaraGore([_uye('Dairesiz')]);
      expect(gruplar.length, 1);
      expect(gruplar.single.blok, isNull);
      expect(gruplar.single.sakinler.single.ad, 'Dairesiz');
    });

    test('BOS LISTE BOS GRUP', () {
      expect(bloklaraGore(const []), isEmpty);
    });

    test('AYNI BLOKTA IKI DAIRESI OLAN SAKIN TEK GRUPTA', () {
      // Sunucu `string_agg(DISTINCT ...)` ile tek blok adi donuyor;
      // istemci onu tek grup sayar.
      final gruplar = bloklaraGore([_uye('Ali', blok: 'A', daire: 'A-1, A-2')]);
      expect(gruplar.length, 1);
      expect(gruplar.single.blok, 'A');
    });
  });

  group('suzgec sunucuya gider', () {
    const bosGovde = '{"items":[]}';

    test('ARAMA 2 KARAKTERDEN KISAYSA GITMEZ', () async {
      final a = _SahteAdapter(bosGovde);
      final kap = _kap(a);
      addTearDown(kap.dispose);

      kap.read(sakinSuzgeciProvider.notifier).ara('A');
      await kap.read(residentsProvider.future);
      expect(a.istekler.last.sorgu?.containsKey('q'), false);

      kap.read(sakinSuzgeciProvider.notifier).ara('Ayse');
      await kap.read(residentsProvider.future);
      expect(a.istekler.last.sorgu?['q'], 'Ayse');
    });

    test('BLOK DARALTMASI AYRI PARAMETRE', () async {
      final a = _SahteAdapter(bosGovde);
      final kap = _kap(a);
      addTearDown(kap.dispose);

      kap.read(sakinSuzgeciProvider.notifier).blokSec('A');
      await kap.read(residentsProvider.future);
      // `q` DEGIL `blok`: `q=A` metin arar ("A-12" dairesindekiler de
      // gelir), `blok=A` yalniz A blogunu getirir.
      expect(a.istekler.last.sorgu?['blok'], 'A');
      expect(a.istekler.last.sorgu?.containsKey('q'), false);
    });

    test('BLOK DARALTMASI KALDIRILABILIR', () async {
      final a = _SahteAdapter(bosGovde);
      final kap = _kap(a);
      addTearDown(kap.dispose);

      kap.read(sakinSuzgeciProvider.notifier).blokSec('A');
      await kap.read(residentsProvider.future);
      kap.read(sakinSuzgeciProvider.notifier).blokSec(null);
      await kap.read(residentsProvider.future);
      // Gizli kalan bir suzgec, "sakinim listede yok" sorusunun en sik
      // sebebidir; kaldirilabilmesi sart.
      expect(a.istekler.last.sorgu?.containsKey('blok'), false);
    });

    test('ARAMA ve BLOK BIRLIKTE calisir', () async {
      final a = _SahteAdapter(bosGovde);
      final kap = _kap(a);
      addTearDown(kap.dispose);

      kap.read(sakinSuzgeciProvider.notifier).blokSec('B');
      kap.read(sakinSuzgeciProvider.notifier).ara('Zeynep');
      await kap.read(residentsProvider.future);
      expect(a.istekler.last.sorgu?['blok'], 'B');
      expect(a.istekler.last.sorgu?['q'], 'Zeynep');
    });
  });

  test('BLOK yanittan OKUNUYOR', () {
    final m = ResidentMember.fromJson(const {
      'user_id': 'u1',
      'ad': 'Ayse',
      'unit_no': 'A-1',
      'blok': 'A',
      'is_active': true,
    });
    expect(m.blok, 'A');

    // Sunucu blok gondermezse (eski surum) COKMEZ, `null` olur.
    final eski = ResidentMember.fromJson(const {
      'user_id': 'u2', 'ad': 'Veli', 'unit_no': 'B-2', 'is_active': true,
    });
    expect(eski.blok, isNull);
  });
}
