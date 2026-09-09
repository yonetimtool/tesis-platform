/// (P220 §5) DAIRE PENCERESINDE SAKIN BILGISI — istemci sozlesmesi.
///
/// ===========================================================================
/// EN KRITIK KILIT: ROL DEGISIMI DAIRE BAZLI UCA GIDER
/// ===========================================================================
/// `PATCH /residents/{user}` kullanicinin AKTIF TUM daire baglarina
/// uyguluyor. Daire penceresinden yapilan bir rol degisikligi o ucu
/// cagirsaydi, iki dairesi olan bir sakinde (birinde malik, otekinde
/// kiraci) IKI DAIREYI DE degistirirdi.
///
/// Bu dosya cagrinin `/units/{id}/residents/{user}` ucuna gittigini
/// olcuyor — taklit HTTP katmaninda, API sinifinda degil (P200 dersi).
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/building_map/data/daire_sakin_api.dart';

class _Kayit {
  _Kayit(this.metot, this.yol, this.govde);
  final String metot;
  final String yol;
  final dynamic govde;
}

class _SahteAdapter implements HttpClientAdapter {
  _SahteAdapter(this.govde);
  final String govde;
  final List<_Kayit> istekler = [];

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    istekler.add(_Kayit(o.method, o.path, o.data));
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

const _liste = '''
[
 {"id":"b1","unit_id":"u1","user_id":"k1","user_ad":"Ayse Malik",
  "rol_tipi":"malik","oturuyor":false,"bitis":null,
  "created_at":"2026-01-01T00:00:00Z"},
 {"id":"b2","unit_id":"u1","user_id":"k2","user_ad":"Veli Kiraci",
  "rol_tipi":"kiraci","oturuyor":true,"bitis":null,
  "created_at":"2026-01-01T00:00:00Z"},
 {"id":"b3","unit_id":"u1","user_id":"k3","user_ad":"Eski Sakin",
  "rol_tipi":"malik","oturuyor":false,"bitis":"2026-02-01T00:00:00Z",
  "created_at":"2025-01-01T00:00:00Z"}
]
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AKTIF BAGLAR DONER, GECMIS BAGLAR SUZULUR', () async {
    final a = _SahteAdapter(_liste);
    final kap = _kap(a);
    addTearDown(kap.dispose);

    final liste = await kap.read(daireSakinleriProvider('u1').future);
    // Daire penceresinin sorusu "SU ANDA kim oturuyor"; kapanmis bag
    // gosterilseydi cikmis bir sakin dairede duruyor gorunurdu.
    expect(liste.length, 2);
    expect(liste.map((s) => s.userId).toList(), ['k1', 'k2']);
    expect(liste.first.ad, 'Ayse Malik');
    expect(liste.first.rolTipi, 'malik');
    // (P218) Oturma MULKIYETTEN AYRI: malik oturmuyor, kiraci oturuyor.
    expect(liste.first.oturuyor, isFalse);
    expect(liste.last.oturuyor, isTrue);
  });

  test('BIRDEN COK SAKIN LISTELENIR', () async {
    // Bir dairede malik VE kiraci olabilir (P154 karari) — ikisi de
    // gorunmeli.
    final a = _SahteAdapter(_liste);
    final kap = _kap(a);
    addTearDown(kap.dispose);
    final liste = await kap.read(daireSakinleriProvider('u1').future);
    expect(liste.map((s) => s.rolTipi).toSet(), {'malik', 'kiraci'});
  });

  test('BOS DAIRE BOS LISTE — HATA DEGIL', () async {
    final a = _SahteAdapter('[]');
    final kap = _kap(a);
    addTearDown(kap.dispose);
    expect(await kap.read(daireSakinleriProvider('u9').future), isEmpty);
  });

  test('ROL DEGISIMI DAIRE BAZLI UCA GIDER', () async {
    final a = _SahteAdapter('{}');
    final kap = _kap(a);
    addTearDown(kap.dispose);

    await kap
        .read(daireSakinApiProvider)
        .guncelle('u1', 'k1', rolTipi: 'kiraci');

    final istek = a.istekler.last;
    expect(istek.metot, 'PATCH');
    // KRITIK: `/residents/k1` DEGIL. O uc TUM baglara uygular.
    expect(istek.yol, '/units/u1/residents/k1');
    expect(istek.govde['rol_tipi'], 'kiraci');
    expect(istek.govde.containsKey('oturuyor'), isFalse);
  });

  test('OTURUYOR TEK BASINA GUNCELLENEBILIR', () async {
    final a = _SahteAdapter('{}');
    final kap = _kap(a);
    addTearDown(kap.dispose);

    await kap.read(daireSakinApiProvider).guncelle('u1', 'k1', oturuyor: true);
    final istek = a.istekler.last;
    // Rol GONDERILMIYOR: yalniz oturma durumu degisiyor ve rolu de
    // gondermek, degistirilmek istenmeyen bir alani yazmak olurdu.
    expect(istek.govde.containsKey('rol_tipi'), isFalse);
    expect(istek.govde['oturuyor'], true);
  });

  test('EKLEME ve CIKARMA dogru uclara gider', () async {
    final a = _SahteAdapter('{}');
    final kap = _kap(a);
    addTearDown(kap.dispose);

    await kap.read(daireSakinApiProvider).ekle('u1', 'k5', 'kiraci');
    expect(a.istekler.last.metot, 'POST');
    expect(a.istekler.last.yol, '/units/u1/residents');
    expect(a.istekler.last.govde['user_id'], 'k5');

    await kap.read(daireSakinApiProvider).cikar('u1', 'k5');
    expect(a.istekler.last.metot, 'DELETE');
    expect(a.istekler.last.yol, '/units/u1/residents/k5');
  });
}
