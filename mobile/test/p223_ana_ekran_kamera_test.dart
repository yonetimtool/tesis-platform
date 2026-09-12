/// (P223 §1) ANA EKRANDA KAMERA YOKSA SEBEBI SOYLENIR + ISARET MOBILDEN
/// KONABILIR.
///
/// ===========================================================================
/// OLCULEN KUSUR
/// ===========================================================================
/// Backend uctan uca CALISIYORDU (dev'de suruldu: PATCH 200, suzgec
/// meta.total 1, `/kare` 200 image/jpeg 12 461 bayt). Veritabani sayimi
/// ise 6 kamera / ana_ekranda 0 idi.
///
/// IKI AYRI KUSUR:
///   1. `if (kameralar.isNotEmpty)` disinda hicbir sey yoktu — isaretli
///      kamera olmayinca bolum HIC cizilmiyor, kullanici Kameralar
///      ekraninda kareleri gorurken ana ekranda hicbir sey gormuyor ve
///      NEDENINI ogrenemiyordu.
///   2. `CameraDraft` `ana_ekranda` GONDERMIYORDU ve form sayfasinda
///      anahtar YOKTU: mobilden yoneten kullanici ozelligi HIC acamiyor.
///      P213 §4'te bayrak backend + okuma tarafinda yapilmis, YAZMA
///      tarafi yalniz web'e konmus.
///
/// Taklit HTTP ADAPTER'INDA (P200 dersi): govdeyi kuran katman da testin
/// icinden geciyor — `toUpdateJson()`u taklit etseydik tam da kirik olan
/// halkayi olcmemis olurduk.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';
import 'package:mobile/src/features/cameras/data/cameras_api.dart';

class _Tel implements HttpClientAdapter {
  final istekler = <({String yol, Map<String, dynamic> sorgu, Object? govde})>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add((
      yol: options.path,
      sorgu: Map<String, dynamic>.from(options.queryParameters),
      govde: options.data,
    ));
    final govde = options.method == 'GET'
        ? {'items': const [], 'meta': {'limit': 1, 'offset': 0, 'total': 0}}
        : {
            'id': 'k-1',
            'ad': 'Ana Kapı',
            'stream_url': 'https://a.test/x.m3u8',
            'tur': 'hls',
            'aktif': true,
            'sakin_gorebilir': false,
            'ana_ekranda': true,
            'oynatilabilir': true,
          };
    return ResponseBody.fromString(
      jsonEncode(govde),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

({CamerasApi api, _Tel tel}) _kur() {
  final tel = _Tel();
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = tel;
  return (api: CamerasApi(dio), tel: tel);
}

const _taslak = CameraDraft(
  ad: 'Ana Kapı',
  streamUrl: 'https://a.test/x.m3u8',
  tur: CameraTur.hls,
  aktif: true,
  sakinGorebilir: false,
  anaEkranda: true,
);

void main() {
  test('GUNCELLEME govdesi `ana_ekranda` TASIR', () async {
    final (api: api, tel: tel) = _kur();
    await api.update('k-1', _taslak);
    final govde = tel.istekler.single.govde as Map<String, dynamic>;
    expect(govde['ana_ekranda'], isTrue);
  });

  test('OLUSTURMA govdesi de `ana_ekranda` TASIR', () async {
    final (api: api, tel: tel) = _kur();
    await api.create(_taslak);
    final govde = tel.istekler.single.govde as Map<String, dynamic>;
    expect(govde['ana_ekranda'], isTrue);
  });

  test('VARSAYILAN KAPALI: bayrak verilmezse `false` gider', () async {
    // Her kare bir ffmpeg surecidir; acik varsayilan, kamera ekleyen
    // yoneticinin FARKINDA OLMADAN sunucuya yuk bindirmesi olurdu.
    final (api: api, tel: tel) = _kur();
    await api.create(const CameraDraft(
      ad: 'X',
      streamUrl: 'https://a.test/x.m3u8',
      tur: CameraTur.hls,
      aktif: true,
      sakinGorebilir: false,
    ));
    final govde = tel.istekler.single.govde as Map<String, dynamic>;
    expect(govde['ana_ekranda'], isFalse);
  });

  test('SUNUCU YANITINDAKI `ana_ekranda` COZULUR', () async {
    final (api: api, tel: _) = _kur();
    final k = await api.update('k-1', _taslak);
    expect(k.anaEkranda, isTrue);
  });

  test('`kameraVarMiProvider` TEK KAYIT ister (tum listeyi indirmez)',
      () async {
    final (api: api, tel: tel) = _kur();
    await api.fetch(limit: 1);
    expect(tel.istekler.single.sorgu['limit'], 1);
    // Bos hal sorusu ANA EKRAN SUZGECI TASIMAZ: "tesiste hic kamera var
    // mi" sorusu isaretten bagimsizdir; suzgeci tasisaydi cevap her
    // zaman "yok" cikar ve mesaj HEP yanlis olurdu.
    expect(tel.istekler.single.sorgu.containsKey('ana_ekranda'), isFalse);
  });
}
