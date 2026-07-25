/// Ana ekran sayaclarinin HTTP sozlesmesi: hangi uc, hangi sorgu, hangi alan.
///
/// G1-G6 kapandiktan sonra dort yeni sayac eklendi (arac gecisi, ihlal,
/// ziyaretci "icerde", otopark dolulugu) + gurultu kategorisi. Bu test
/// URL/parametreleri KILITLER — yanlis sorgu sessizce yanlis sayi gostermesin.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/home/data/home_api.dart';
import 'package:mobile/src/features/home/domain/parking_occupancy.dart';

/// Istek URI'sini kaydeden, sabit JSON donen sahte adapter.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body);

  final Map<String, dynamic> body;
  final List<Uri> istekler = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add(options.uri);
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

({HomeApi api, _FakeAdapter adapter}) _kur(Map<String, dynamic> body) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
  final adapter = _FakeAdapter(body);
  dio.httpClientAdapter = adapter;
  return (api: HomeApi(dio), adapter: adapter);
}

Map<String, dynamic> _sayfa(int total) => {
      'meta': {'limit': 1, 'offset': 0, 'total': total},
      'items': const [],
    };

void main() {
  group('sayaclar — YALNIZ meta.total okunur, sayfa verisi istenmez', () {
    test('G3 ziyaretci "icerde": GET /visitors?icerde=true&limit=1', () async {
      final (api: api, adapter: adapter) = _kur(_sayfa(1));
      expect(await api.icerdekiZiyaretciSayisi(), 1);

      final uri = adapter.istekler.single;
      expect(uri.path, '/visitors');
      expect(uri.queryParameters['icerde'], 'true');
      expect(uri.queryParameters['limit'], '1');
    });

    test('G1 arac girisi: GET /vehicle-passes?baslangic=<gun basi UTC>&limit=1',
        () async {
      final (api: api, adapter: adapter) = _kur(_sayfa(4));
      // Yerel gun basi; sunucuya UTC ISO-8601 gider (offset karmasasi yok).
      final gunBasi = DateTime(2026, 7, 25);
      expect(await api.bugunkuAracGirisSayisi(gunBasi), 4);

      final uri = adapter.istekler.single;
      expect(uri.path, '/vehicle-passes');
      expect(
        uri.queryParameters['baslangic'],
        gunBasi.toUtc().toIso8601String(),
      );
      // Tek-satir gecis modelinde 'yon' parametresi YOKTUR (sozlesme sapmasi).
      expect(uri.queryParameters.containsKey('yon'), isFalse);
    });

    test('G2 ihlal: GET /violations?durum=yeni&limit=1', () async {
      final (api: api, adapter: adapter) = _kur(_sayfa(2));
      expect(await api.yeniIhlalSayisi(), 2);

      final uri = adapter.istekler.single;
      expect(uri.path, '/violations');
      expect(uri.queryParameters['durum'], 'yeni');
    });

    test('G6 gurultu: kategori suzgeci SUNUCUDA (istemci suzmez)', () async {
      final (api: api, adapter: adapter) = _kur(_sayfa(2));
      expect(await api.kendiKategoriSikayetSayisi('gurultu'), 2);

      final uri = adapter.istekler.single;
      expect(uri.path, '/unit-complaints/mine');
      expect(uri.queryParameters['kategori'], 'gurultu');
      expect(uri.queryParameters['durum'], 'acik');
    });

    test('meta YOKSA/bozuksa 0 (ekran cokmez, uydurma sayi da yok)', () async {
      final (api: api, adapter: _) = _kur(const {'items': []});
      expect(await api.yeniIhlalSayisi(), 0);
    });
  });

  group('G4 otopark dolulugu — kapasite null gracefully', () {
    test('kapasite VARSA: "3 / 120" + "%2"', () async {
      final (api: api, adapter: adapter) =
          _kur(const {'kapasite': 120, 'dolu': 3, 'oran': 2});
      final o = await api.otoparkDoluluk();

      expect(adapter.istekler.single.path, '/parking/occupancy');
      expect(o.dolu, 3);
      expect(o.kapasite, 120);
      expect(o.doluMetni, '3 / 120');
      expect(o.oranMetni, '%2');
    });

    test('kapasite TANIMSIZ: dolu tek basina ("5 araç"), oran YOK ("—")',
        () async {
      final (api: api, adapter: _) =
          _kur(const {'kapasite': null, 'dolu': 5, 'oran': null});
      final o = await api.otoparkDoluluk();

      expect(o.dolu, 5);
      expect(o.kapasite, isNull);
      expect(o.oran, isNull);
      expect(o.doluMetni, '5 araç'); // payda UYDURULMAZ
      expect(o.oranMetni, '—'); // yuzde UYDURULMAZ
    });

    test('bos yanit: dolu 0, kapasite/oran null', () {
      const o = ParkingOccupancy(dolu: 0);
      expect(ParkingOccupancy.fromJson(const {}).dolu, o.dolu);
      expect(ParkingOccupancy.fromJson(const {}).doluMetni, '0 araç');
    });
  });
}
