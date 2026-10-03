/// (P253 A2) Gorev gecmisi CSV'si UST SINIRA takilinca rapor EKSIK —
/// istemci bunu bilmeli (web `raporKesildi` ile ayni). Taklit HTTP adaptoru.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/raporlar/data/rapor_motoru_api.dart';

class _Tel implements HttpClientAdapter {
  _Tel(this.toplam);
  final int toplam;
  int istek = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    istek++;
    final offset = o.queryParameters['offset'] as int;
    final limit = o.queryParameters['limit'] as int;
    final adet = (toplam - offset).clamp(0, limit);
    final govde = {
      'meta': {'limit': limit, 'offset': offset, 'total': toplam},
      'items': [for (var i = 0; i < adet; i++) {'id': '${offset + i}'}],
    };
    return ResponseBody.fromString(jsonEncode(govde), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<({List<Map<String, dynamic>> satirlar, bool kesildi})> _cek(int toplam) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = _Tel(toplam);
  return RaporMotoruApi(dio).gorevGecmisi(
      baslangic: DateTime.utc(2026, 9, 1), bitis: DateTime.utc(2026, 10, 1));
}

void main() {
  test('sinirin ALTINDA: tum satirlar, kesildi YOK', () async {
    final c = await _cek(450);
    expect(c.satirlar.length, 450);
    expect(c.kesildi, isFalse);
  });

  test('sinirin USTUNDE: 5000 satirda durur ve kesildi=true', () async {
    final c = await _cek(6000);
    expect(c.satirlar.length, 5000);
    expect(c.kesildi, isTrue);
  });

  test('tam sinir: 5000 satir, eksik DEGIL', () async {
    final c = await _cek(5000);
    expect(c.satirlar.length, 5000);
    expect(c.kesildi, isFalse);
  });
}
