/// `GET /activity` (G5) — TEK uc, sunucu birlestirir/siralar/rol suzer.
///
/// Kilitlenen sozlesme: bilesik IMLEC (offset/meta.total YOK), opak cursor
/// gecisi, tur/renk esleme, taninmayan turun akista KALMASI ve zamanin YEREL
/// saate cevrilmesi.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/home/data/activity_api.dart';
import 'package:mobile/src/features/home/domain/activity_models.dart';

/// Sirayla sayfa donen sahte adapter (imlec akisini taklit eder).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.sayfalar);

  final List<Map<String, dynamic>> sayfalar;
  final List<Uri> istekler = [];
  int _i = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add(options.uri);
    final body = sayfalar[_i.clamp(0, sayfalar.length - 1)];
    _i++;
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

({ActivityApi api, _FakeAdapter adapter}) _kur(
    List<Map<String, dynamic>> sayfalar) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
  final adapter = _FakeAdapter(sayfalar);
  dio.httpClientAdapter = adapter;
  return (api: ActivityApi(dio), adapter: adapter);
}

Map<String, dynamic> _olay(
  String tur,
  String id, {
  String baslik = 'Olay',
  String? altMetin = 'detay',
  String zaman = '2026-07-25T06:52:03.210069Z',
  String? renk = 'notr',
}) =>
    {
      'id': '$tur:$id',
      'tur': tur,
      'baslik': baslik,
      'alt_metin': altMetin,
      'zaman': zaman,
      'renk_ipucu': renk,
      'kaynak_id': id,
    };

void main() {
  test('ilk sayfa: /activity?limit=N, cursor GONDERILMEZ', () async {
    final (api: api, adapter: adapter) = _kur([
      {
        'meta': {'limit': 5, 'next_cursor': 'imlec-1'},
        'items': [_olay('kargo', 'k1')],
      },
    ]);

    final sayfa = await api.sayfa(limit: 5);
    final uri = adapter.istekler.single;
    expect(uri.path, '/activity');
    expect(uri.queryParameters['limit'], '5');
    expect(uri.queryParameters.containsKey('cursor'), isFalse);
    // Sozlesmede offset YOK — istemci de gondermez.
    expect(uri.queryParameters.containsKey('offset'), isFalse);
    expect(sayfa.nextCursor, 'imlec-1');
    expect(sayfa.items.single.tur, ActivityTur.kargo);
  });

  test('imlecle sayfalama: cursor OLDUGU GIBI gecer, tekrar/atlama yok',
      () async {
    final (api: api, adapter: adapter) = _kur([
      {
        'meta': {'limit': 2, 'next_cursor': 'MjAyNi0wNy0yNXww'},
        'items': [_olay('ihlal', 'v1'), _olay('ihlal', 'v2')],
      },
      {
        'meta': {'limit': 2, 'next_cursor': null},
        'items': [_olay('kargo', 'k1')],
      },
    ]);

    final ilk = await api.sayfa(limit: 2);
    final ikinci = await api.sayfa(limit: 2, cursor: ilk.nextCursor);

    // Imlec OPAK: istemci ayristirmadan aynen geri gonderir.
    expect(adapter.istekler[1].queryParameters['cursor'], 'MjAyNi0wNy0yNXww');
    expect(ikinci.nextCursor, isNull); // akisin sonu
    final idler = [...ilk.items, ...ikinci.items].map((o) => o.id).toList();
    expect(idler.toSet(), hasLength(idler.length)); // TEKRAR YOK
  });

  test('tur/renk eslemesi + alt_metin null olabilir', () async {
    final (api: api, adapter: _) = _kur([
      {
        'meta': {'limit': 20},
        'items': [
          _olay('devriye_okutma', 'p1', renk: 'olumlu'),
          _olay('daire_sikayeti', 's1', renk: 'uyari'),
          _olay('arac_cikis', 'a1', altMetin: null),
          _olay('alarm', 'n1', renk: 'alarm'),
        ],
      },
    ]);

    final items = (await api.sayfa()).items;
    expect([for (final o in items) o.tur], [
      ActivityTur.devriyeOkutma,
      ActivityTur.daireSikayeti,
      ActivityTur.aracCikis,
      ActivityTur.alarm,
    ]);
    expect([for (final o in items) o.renk], [
      ActivityRenk.olumlu,
      ActivityRenk.uyari,
      ActivityRenk.notr, // renk_ipucu 'notr'
      ActivityRenk.alarm,
    ]);
    expect(items[2].altMetin, isNull);
    expect(items[2].kaynakId, 'a1');
  });

  test('TANINMAYAN tur akistan DUSMEZ (sunucu yeni tur ekleyebilir)', () async {
    final (api: api, adapter: _) = _kur([
      {
        'meta': {'limit': 20},
        'items': [_olay('yepyeni_tur', 'x1', baslik: 'Yeni Olay')],
      },
    ]);

    final olay = (await api.sayfa()).items.single;
    expect(olay.tur, ActivityTur.bilinmeyen);
    expect(olay.baslik, 'Yeni Olay'); // metin SUNUCUDAN, satir cizilir
  });

  test('zaman YEREL saate cevrilir (etiket cihaz saatiyle tutarli)', () async {
    final (api: api, adapter: _) = _kur([
      {
        'meta': {'limit': 20},
        'items': [_olay('kargo', 'k1', zaman: '2026-07-25T06:52:03Z')],
      },
    ]);

    final olay = (await api.sayfa()).items.single;
    expect(olay.zaman.isUtc, isFalse);
    expect(olay.zaman, DateTime.utc(2026, 7, 25, 6, 52, 3).toLocal());
  });

  test('bos/bozuk yanit: bos akis + imlec null (ekran cokmez)', () async {
    final (api: api, adapter: _) = _kur([const <String, dynamic>{}]);
    final sayfa = await api.sayfa();
    expect(sayfa.items, isEmpty);
    expect(sayfa.nextCursor, isNull);
  });
}
