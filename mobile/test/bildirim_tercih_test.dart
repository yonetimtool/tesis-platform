/// (P183 §5) Bildirim kanal tercihleri HTTP sozlesmesi: hangi uc, PATCH
/// govdesi YALNIZ degisen kanali tasir (oteki kanallari sessizce geri
/// almasin — backend BildirimTercihUpdate kismidir).
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/settings/data/bildirim_tercih_api.dart';
import 'package:mobile/src/features/settings/domain/bildirim_tercihleri.dart';

/// Istek metod/uri/govdesini kaydeden, sabit JSON donen sahte adapter.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body);

  final Map<String, dynamic> body;
  String? sonMetod;
  Uri? sonUri;
  Map<String, dynamic>? sonGovde;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sonMetod = options.method;
    sonUri = options.uri;
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      final bytes = chunks.expand((e) => e).toList();
      if (bytes.isNotEmpty) {
        sonGovde = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      }
    }
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

({BildirimTercihApi api, _FakeAdapter adapter}) _kur(Map<String, dynamic> body) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
  final adapter = _FakeAdapter(body);
  dio.httpClientAdapter = adapter;
  return (api: BildirimTercihApi(dio), adapter: adapter);
}

const _tamYanit = {
  'bildirim_eposta': true,
  'bildirim_sms': false,
  'bildirim_mobil': true,
};

void main() {
  test('fromJson: uc kanali okur; eksik alan varsayilan ACIK', () {
    final t = BildirimTercihleri.fromJson(_tamYanit);
    expect(t.eposta, true);
    expect(t.sms, false);
    expect(t.mobil, true);
    // Eksik alan (eski sunucu) -> varsayilan acik (bildirim bir tercih).
    final bos = BildirimTercihleri.fromJson(const {});
    expect(bos.eposta, true);
    expect(bos.sms, true);
    expect(bos.mobil, true);
  });

  test('getir: GET /me/bildirim-tercihleri', () async {
    final (api: api, adapter: adapter) = _kur(_tamYanit);
    final t = await api.getir();
    expect(adapter.sonMetod, 'GET');
    expect(adapter.sonUri!.path, '/me/bildirim-tercihleri');
    expect(t.mobil, true);
    expect(t.sms, false);
  });

  test('guncelle(mobil:false): PATCH govdesi YALNIZ mobil kanali tasir',
      () async {
    final (api: api, adapter: adapter) =
        _kur({..._tamYanit, 'bildirim_mobil': false});
    final t = await api.guncelle(mobil: false);
    expect(adapter.sonMetod, 'PATCH');
    expect(adapter.sonUri!.path, '/me/bildirim-tercihleri');
    // KISMI: yalniz degisen kanal gonderilir (oteki iki kanal govdede YOK).
    expect(adapter.sonGovde, {'bildirim_mobil': false});
    expect(t.mobil, false);
  });

  test('guncelle(eposta:true): yalniz eposta kanali gonderilir', () async {
    final (api: api, adapter: adapter) = _kur(_tamYanit);
    await api.guncelle(eposta: true);
    expect(adapter.sonGovde, {'bildirim_eposta': true});
  });
}
