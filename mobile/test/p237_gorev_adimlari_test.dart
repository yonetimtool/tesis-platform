/// (P237 §2) GOREV ALT ADIMLARI — mobil yuzey.
///
/// =========================================================================
/// DIKIS YERI: TAKLIT HTTP ADAPTER'INDA (P198/P200/P229 dersi)
/// =========================================================================
/// `TaskApi`yi taklit etmek govdeyi KURAN ve COZEN katmani olcmezdi;
/// kusur tam orada olabilir (alan adi yanlis yazilmis bir `foto_key`,
/// uc yolunda bir harf). Taklit adapter, gercek Dio yigininin altina
/// kondu: yol, metot ve govde GERCEKTEN uretiliyor.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/tasks/data/task_api.dart';
import 'package:mobile/src/features/tasks/domain/task_models.dart';

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

({TaskApi api, _FakeAdapter adapter}) _kur(Map<String, dynamic> body,
    {int status = 200}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
  final adapter = _FakeAdapter(body, status: status);
  dio.httpClientAdapter = adapter;
  return (api: TaskApi(dio), adapter: adapter);
}

Map<String, dynamic> _adimJson({
  String id = 'a1',
  bool tamamlandi = false,
  bool fotoZorunlu = false,
}) => {
  'id': id,
  'task_id': 't1',
  'sira': 0,
  'ad': 'A blok',
  'foto_zorunlu': fotoZorunlu,
  'tamamlandi': tamamlandi,
  'tamamlayan_user_id': tamamlandi ? 'u1' : null,
  'tamamlayan_ad': tamamlandi ? 'Ali Guard' : null,
  'tamamlanma_zamani': tamamlandi ? '2026-09-15T08:00:00Z' : null,
  'foto_key': tamamlandi && fotoZorunlu ? 'gorev/x.jpg' : null,
  'foto_url': tamamlandi && fotoZorunlu ? 'https://s/x.jpg' : null,
  'notlar': tamamlandi ? 'bitti' : null,
};

void main() {
  group('MODEL — sunucu alanlari COZULUYOR', () {
    test('Task ILERLEME sayilarini tasir; adimlar AYRINTIDA', () {
      final t = Task.fromJson({
        'id': 't1',
        'ad': 'Temizlik',
        'aktif': true,
        'adim_toplam': 3,
        'adim_tamam': 2,
        'adim_sirali': true,
        'adimlar': [_adimJson(id: 'a1', tamamlandi: true)],
      });
      expect(t.adimToplam, 3);
      expect(t.adimTamam, 2);
      expect(t.adimSirali, isTrue);
      expect(t.adimlar, hasLength(1));
      expect(t.adimlar!.first.tamamlayanAd, 'Ali Guard');
    });

    test('ALANLAR YOKSA (eski sunucu) ilerleme SIFIR, adimlar null', () {
      final t = Task.fromJson({'id': 't1', 'ad': 'X', 'aktif': true});
      expect(t.adimToplam, 0);
      expect(t.adimTamam, 0);
      expect(t.adimSirali, isFalse);
      expect(t.adimlar, isNull);
    });
  });

  group('ZINCIR — gercek Dio yigini, taklit adapter', () {
    test('fetchSteps DOGRU YOLU cagirir ve listeyi cozer', () async {
      final k = _kur({
        'meta': {'limit': 1, 'offset': 0, 'total': 1},
        'items': [_adimJson()],
      });
      final liste = await k.api.fetchSteps('t1');
      expect(liste.single.ad, 'A blok');
      expect(k.adapter.istekler.single.$1, 'GET');
      expect(k.adapter.istekler.single.$2.path, '/tasks/t1/adimlar');
    });

    test('addStep AD ve SIRA gonderir', () async {
      final k = _kur(_adimJson(id: 'yeni'));
      final adim = await k.api.addStep('t1', 'D blok', sira: 3);
      expect(adim.id, 'yeni');
      final (metot, uri, govde) = k.adapter.istekler.single;
      expect(metot, 'POST');
      expect(uri.path, '/tasks/t1/adimlar');
      expect(jsonDecode(govde!), {'ad': 'D blok', 'sira': 3});
    });

    test('completeStep FOTO ANAHTARINI ve NOTU govdeye koyar', () async {
      final k = _kur(_adimJson(tamamlandi: true, fotoZorunlu: true));
      final adim = await k.api.completeStep(
        't1', 'a1', fotoKey: 'gorev/x.jpg', notlar: 'bitti',
      );
      expect(adim.tamamlandi, isTrue);
      expect(adim.fotoUrl, 'https://s/x.jpg');
      final (metot, uri, govde) = k.adapter.istekler.single;
      expect(metot, 'POST');
      expect(uri.path, '/tasks/t1/adimlar/a1/tamamla');
      expect(jsonDecode(govde!), {'foto_key': 'gorev/x.jpg', 'notlar': 'bitti'});
    });

    test('reopenStep ve deleteStep DOGRU YOL/METOT', () async {
      final k1 = _kur(_adimJson());
      await k1.api.reopenStep('t1', 'a1');
      expect(k1.adapter.istekler.single.$1, 'POST');
      expect(k1.adapter.istekler.single.$2.path, '/tasks/t1/adimlar/a1/geri-al');

      final k2 = _kur(const {});
      await k2.api.deleteStep('t1', 'a1');
      expect(k2.adapter.istekler.single.$1, 'DELETE');
      expect(k2.adapter.istekler.single.$2.path, '/tasks/t1/adimlar/a1');
    });

    test('IKINCI TAMAMLAMA 409 — sessizce yutulmaz', () async {
      final k = _kur({
        'error': {'code': 'conflict', 'message': 'gorev_adimi_zaten_tamam'},
      }, status: 409);
      expect(
        () => k.api.completeStep('t1', 'a1'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('TASLAK — adimlar YALNIZ olusturmada govdeye girer', () {
    test('adimlar SIRA ile birlikte gonderilir', () {
      const d = TaskDraft(
        ad: 'Temizlik',
        adimlar: ['A blok', 'B blok'],
        adimSirali: true,
      );
      final j = d.toJson();
      expect(j['adim_sirali'], isTrue);
      expect(j['adimlar'], [
        {'ad': 'A blok', 'sira': 0},
        {'ad': 'B blok', 'sira': 1},
      ]);
    });

    test('ADIM YOKSA alan HIC gonderilmez (mevcutlari ezmesin)', () {
      const d = TaskDraft(ad: 'Temizlik');
      expect(d.toJson().containsKey('adimlar'), isFalse);
    });

    test('fromTask SIRALILIGI tasir, ADIMLARI TASIMAZ', () {
      final t = Task.fromJson({
        'id': 't1', 'ad': 'X', 'aktif': true, 'adim_sirali': true,
        'adimlar': [_adimJson()],
      });
      final d = TaskDraft.fromTask(t);
      expect(d.adimSirali, isTrue);
      // DUZENLEMEDE ADIM GONDERILMEZ: gonderilseydi tamamlanmis adimlar
      // dahil hepsi EZILIRDI.
      expect(d.adimlar, isEmpty);
      expect(d.toJson().containsKey('adimlar'), isFalse);
    });
  });
}
