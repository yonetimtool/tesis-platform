/// (P237 §3) ANKET — mobil yuzey: olusturma, anonimlik, katilim orani.
///
/// DIKIS YERI TAKLIT HTTP ADAPTER'INDA (P198/P200 dersi): `AnketApi`yi
/// taklit etmek govdeyi KURAN katmani olcmezdi — `anonim` bayraginin
/// govdeye hic konmamasi ya da yanlis adla konmasi tam orada olur.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/anket/data/anket_api.dart';
import 'package:mobile/src/features/anket/domain/anket_models.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body, {this.status = 200});

  final Map<String, dynamic> body;
  final int status;
  final List<(String, Uri, String?)> istekler = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add((
      options.method,
      options.uri,
      options.data == null ? null : jsonEncode(options.data),
    ));
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

({AnketApi api, _FakeAdapter adapter}) _kur(Map<String, dynamic> body,
    {int status = 200}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
  final adapter = _FakeAdapter(body, status: status);
  dio.httpClientAdapter = adapter;
  return (api: AnketApi(dio), adapter: adapter);
}

Map<String, dynamic> _anketJson({
  bool anonim = false,
  int? hedefKisi,
  int? toplamOy,
}) => {
  'id': 'a1',
  'baslik': 'Otopark',
  'aciklama': null,
  'gorsel_url': 'https://s/g.jpg',
  'baslangic_at': null,
  'kapanis_at': '2026-10-01T00:00:00Z',
  'aktif': true,
  'acik': true,
  'anonim': anonim,
  'hedef_roller': ['resident', 'security'],
  'hedef_sakin_tipi': 'malik',
  'hedef_kisi': hedefKisi,
  'toplam_oy': toplamOy,
  'oy_verdim': false,
  'secenekler': [
    {'id': 's1', 'metin': 'Evet', 'sira': 0, 'oy': null},
    {'id': 's2', 'metin': 'Hayır', 'sira': 1, 'oy': null},
  ],
  'created_at': '2026-09-01T00:00:00Z',
};

void main() {
  group('MODEL — P237 alanlari cozuluyor', () {
    test('hedef kitle, anonimlik, gorsel, tarih', () {
      final a = Anket.fromJson(_anketJson(anonim: true));
      expect(a.anonim, isTrue);
      expect(a.hedefRoller, ['resident', 'security']);
      expect(a.hedefSakinTipi, 'malik');
      expect(a.gorselUrl, 'https://s/g.jpg');
      expect(a.kapanisAt, isNotNull);
      expect(a.aktif, isTrue);
    });

    test('KATILIM ORANI hesaplanir', () {
      final a = Anket.fromJson(_anketJson(hedefKisi: 40, toplamOy: 10));
      expect(a.katilimYuzde, 25);
    });

    test('PAYDA YOKSA oran NULL — uydurma yuzde uretilmez', () {
      // Sakine `hedef_kisi` gelmez; "0 oy" ile "olcusu yok" ayni sey degil.
      final a = Anket.fromJson(_anketJson(toplamOy: 10));
      expect(a.katilimYuzde, isNull);
    });

    test('PAYDA SIFIRSA oran NULL (sifira bolme yok)', () {
      final a = Anket.fromJson(_anketJson(hedefKisi: 0, toplamOy: 0));
      expect(a.katilimYuzde, isNull);
    });

    test('ESKI SUNUCU alanlari yoksa varsayilanlar', () {
      final a = Anket.fromJson(const {
        'id': 'a', 'baslik': 'x', 'acik': true, 'secenekler': [],
      });
      expect(a.anonim, isFalse);
      expect(a.hedefRoller, isEmpty);
      expect(a.gorselUrl, isNull);
    });
  });

  group('TASLAK — govde GERCEKTEN kuruluyor', () {
    test('maddeler SIRA ile, anonim ve hedef roller govdede', () {
      const taslak = AnketTaslak(
        baslik: 'Otopark',
        maddeler: ['Evet', 'Hayır'],
        hedefRoller: ['resident'],
        anonim: true,
      );
      final j = taslak.toJson();
      expect(j['baslik'], 'Otopark');
      expect(j['anonim'], isTrue);
      expect(j['hedef_roller'], ['resident']);
      expect(j['secenekler'], [
        {'metin': 'Evet', 'sira': 0},
        {'metin': 'Hayır', 'sira': 1},
      ]);
    });
  });

  group('ZINCIR — gercek Dio yigini', () {
    test('olustur DOGRU YOLA ve govdeyle POST atar', () async {
      final k = _kur(_anketJson(anonim: true));
      await k.api.olustur(const AnketTaslak(
        baslik: 'Otopark',
        maddeler: ['Evet', 'Hayır'],
        anonim: true,
      ));
      final (metot, uri, govde) = k.adapter.istekler.single;
      expect(metot, 'POST');
      expect(uri.path, '/anketler');
      // ANONIM BAYRAGI GOVDEDE: burasi kopmus olsaydi anket adli
      // acilirdi ve kullaniciya verilen vaat bozulurdu.
      expect(jsonDecode(govde!)['anonim'], isTrue);
    });

    test('kapat PATCH ile aktif=false gonderir', () async {
      final k = _kur(_anketJson());
      await k.api.kapat('a1');
      final (metot, uri, govde) = k.adapter.istekler.single;
      expect(metot, 'PATCH');
      expect(uri.path, '/anketler/a1');
      expect(jsonDecode(govde!), {'aktif': false});
      // ANONIMLIK PATCH GOVDESINE KONMAZ: sunucu `extra="forbid"` ile
      // 422 verir, veritabani tetikleyicisi de reddeder.
      expect(jsonDecode(govde).containsKey('anonim'), isFalse);
    });

    test('oyDokumu DOGRU YOLU cagirir', () async {
      final k = _kur({
        'meta': {'limit': 1, 'offset': 0, 'total': 1},
        'items': [
          {
            'user_id': 'u1', 'ad': 'Ali', 'secenek_id': 's1',
            'secenek_metin': 'Evet', 'created_at': '2026-09-02T10:00:00Z',
          },
        ],
      });
      final liste = await k.api.oyDokumu('a1');
      expect(liste.single.ad, 'Ali');
      expect(liste.single.secenekMetin, 'Evet');
      expect(k.adapter.istekler.single.$2.path, '/anketler/a1/oylar');
    });

    test('ANONIM ankette dokum 409 — sessizce bos liste DONMEZ', () async {
      final k = _kur({
        'error': {'code': 'conflict', 'message': 'anket_anonim_dokum_yok'},
      }, status: 409);
      expect(() => k.api.oyDokumu('a1'), throwsA(isA<Exception>()));
    });
  });
}
