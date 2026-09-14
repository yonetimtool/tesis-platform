/// (P232) TEK DIYALOGDA COK GRUPLU VARDIYA — mobil yuzey.
///
/// =========================================================================
/// OLCUM: MOBILDE `kalip-uygula` HIC CAGRILMIYORDU
/// =========================================================================
/// Mobilde yalniz `topluEkle` vardi: TEK aralik + TEK saat. Yani "pazartesi
/// gunduz, sali-carsamba gece" icin diyalogu DEFALARCA acmak gerekiyordu ve
/// her acilis AYRI bir parti uretiyordu — ayri onizleme, ayri catisma
/// kontrolu ve geri alirken AYRI BIR ISTEK.
///
/// TAKLIT HTTP ADAPTER'INDA (P200 dersi): API sinifini taklit etmek,
/// govdeyi kuran katmani OLCMEZDI — kusur tam orada olabilirdi.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/shifts/data/vardiya_plani_api.dart';
import 'package:mobile/src/features/shifts/domain/vardiya_plani_models.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body);

  final Map<String, dynamic> body;
  final List<(String, Uri, String)> istekler = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add((
      options.method,
      options.uri,
      jsonEncode(options.data ?? const {}),
    ));
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

({VardiyaPlaniApi api, _FakeAdapter adapter}) _kur(Map<String, dynamic> body) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
  final adapter = _FakeAdapter(body);
  dio.httpClientAdapter = adapter;
  return (api: VardiyaPlaniApi(dio), adapter: adapter);
}

const _GUNDUZ = VardiyaDilim(
  ad: 'Gunduz',
  baslangic: '08:00',
  bitis: '16:00',
);
const _GECE = VardiyaDilim(ad: 'Gece', baslangic: '22:00', bitis: '06:00');

Map<String, dynamic> _yanit({bool uygulandi = true}) => {
  'uygulandi': uygulandi,
  'parti_id': uygulandi ? 'p1' : null,
  'eklenecek': 3,
  'eklenen': uygulandi ? 3 : 0,
  'cakisan': 0,
  'zaten_var': 0,
  'satirlar': const [],
  'uyarilar': const [],
};

void main() {
  test('COK GRUP TEK ISTEKTE gider — "pazartesi gunduz, sali-carsamba gece"',
      () async {
    final (api: api, adapter: adapter) = _kur(_yanit());
    await api.kalipUygula(gruplar: const [
      VardiyaGunGrubu(
        gunler: ['2026-03-02'],
        dilimler: [_GUNDUZ],
        atamalar: {0: ['u1']},
      ),
      VardiyaGunGrubu(
        gunler: ['2026-03-03', '2026-03-04'],
        dilimler: [_GECE],
        atamalar: {0: ['u1']},
      ),
    ]);

    // TEK ISTEK: gruplar ayri ayri gonderilseydi geri alma da birden cok
    // istek olurdu.
    expect(adapter.istekler.length, 1);
    final (metot, uri, govde) = adapter.istekler.single;
    expect(metot, 'POST');
    expect(uri.path, '/vardiya-plani/kalip-uygula');

    final j = jsonDecode(govde) as Map<String, dynamic>;
    final gruplar = j['gruplar'] as List;
    expect(gruplar.length, 2);
    expect((gruplar[0] as Map)['gunler'], ['2026-03-02']);
    expect(((gruplar[0] as Map)['dilimler'] as List).first['baslangic'],
        '08:00');
    expect((gruplar[1] as Map)['gunler'], ['2026-03-03', '2026-03-04']);
    expect(((gruplar[1] as Map)['dilimler'] as List).first['baslangic'],
        '22:00');
  });

  test('ATAMA ANAHTARLARI DIZGEYE cevrilir (JSON nesne anahtari)', () async {
    // Dart `int` anahtarli `Map` gonderirse sunucu govdeyi COZEMEZ;
    // hata 422 olur ve sebebi ekranda "gecersiz istek" gibi gorunur.
    final (api: api, adapter: adapter) = _kur(_yanit());
    await api.kalipUygula(gruplar: const [
      VardiyaGunGrubu(
        gunler: ['2026-03-02'],
        dilimler: [_GUNDUZ, _GECE],
        atamalar: {0: ['u1'], 1: ['u2']},
      ),
    ]);
    final j = jsonDecode(adapter.istekler.single.$3) as Map<String, dynamic>;
    final atamalar = ((j['gruplar'] as List).first as Map)['atamalar'] as Map;
    expect(atamalar.keys.every((k) => k is String), isTrue,
        reason: 'anahtarlar dizge olmali');
    expect(atamalar['0'], ['u1']);
    expect(atamalar['1'], ['u2']);
  });

  test('ONIZLEME `kuru=true` gonderir ve HICBIR SEY yazmaz', () async {
    final (api: api, adapter: adapter) = _kur(_yanit(uygulandi: false));
    final sonuc = await api.kalipUygula(
      kuru: true,
      gruplar: const [
        VardiyaGunGrubu(
          gunler: ['2026-03-02'],
          dilimler: [_GUNDUZ],
          atamalar: {0: ['u1']},
        ),
      ],
    );
    final j = jsonDecode(adapter.istekler.single.$3) as Map<String, dynamic>;
    expect(j['kuru'], isTrue);
    expect(sonuc.uygulandi, isFalse);
    expect(sonuc.eklenecek, 3);
    expect(sonuc.partiId, isNull, reason: 'onizlemede parti OLMAMALI');
  });

  test('GERI ALMA icin parti_id cozulur', () async {
    final (api: api, adapter: _) = _kur(_yanit());
    final sonuc = await api.kalipUygula(gruplar: const [
      VardiyaGunGrubu(
        gunler: ['2026-03-02'],
        dilimler: [_GUNDUZ],
        atamalar: {0: ['u1']},
      ),
    ]);
    expect(sonuc.partiId, 'p1');
  });
}
