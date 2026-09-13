/// (P229 §3) GOREV TAMAMLAMA BILGISI — mobil yuzey.
///
/// =========================================================================
/// OLCULEN KUSUR: VERI VARDI, ARAYUZ YOKTU
/// =========================================================================
/// `POST /tasks/{id}/completions` kim/ne zaman/foto/not zaten kaydediyordu.
/// Ama:
///   * `Task` semasi tamamlama hakkinda HICBIR SEY tasimiyordu,
///   * `GET /tasks/{id}/completions` HICBIR ISTEMCIDEN cagrilmiyordu,
///   * detay ekrani yalniz KENDI POST yanitini ciziyor, ekran kapaninca
///     unutuyordu — yani baska kimse "kim tamamladi"yi goremiyordu.
///
/// TAKLIT HTTP ADAPTER'INDA (P200 dersi): API sinifini taklit etmek,
/// govdeyi kuran/cozen katmani OLCMEZDI — kusur tam orada olabilirdi.
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
  final List<(String, Uri)> istekler = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add((options.method, options.uri));
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

void main() {
  group('Task semasi tamamlama ozetini TASIR', () {
    test('tamamlanmamis gorev: tamamlandi=false, sonTamamlama=null', () {
      final t = Task.fromJson({
        'id': 't1',
        'ad': 'Cop toplama',
        'aktif': true,
        'foto_zorunlu': false,
      });
      expect(t.tamamlandi, isFalse);
      expect(t.sonTamamlama, isNull);
    });

    test('KIM, NE ZAMAN, FOTO, NOT cozulur', () {
      final t = Task.fromJson({
        'id': 't1',
        'ad': 'Cop toplama',
        'aktif': true,
        'foto_zorunlu': false,
        'tamamlandi': true,
        'son_tamamlama': {
          'id': 'c1',
          'tamamlayan_user_id': 'u1',
          'tamamlayan_ad': 'Mehmet Yilmaz',
          'tamamlanma_zamani': '2026-03-05T08:30:00Z',
          'foto_var': true,
          'notlar': 'Bahce sulandi',
        },
      });
      expect(t.tamamlandi, isTrue);
      expect(t.sonTamamlama!.tamamlayanAd, 'Mehmet Yilmaz');
      expect(t.sonTamamlama!.tamamlanmaZamani.toUtc().hour, 8);
      expect(t.sonTamamlama!.fotoVar, isTrue);
      expect(t.sonTamamlama!.notlar, 'Bahce sulandi');
    });

    test('ESKI YANIT (alanlar yok) DUSMEZ', () {
      // Yayindaki sunucu henuz guncellenmemis olabilir; istemci
      // guncellendiginde liste EKRANI KIRILMAMALI.
      final t = Task.fromJson({'id': 't1', 'ad': 'x', 'aktif': true});
      expect(t.tamamlandi, isFalse);
    });
  });

  group('GET /tasks/{id}/completions — HICBIR ISTEMCIDEN cagrilmiyordu', () {
    test('dogru uca gider ve AD cozulur', () async {
      final (api: api, adapter: adapter) = _kur({
        'meta': {'limit': 20, 'offset': 0, 'total': 1},
        'items': [
          {
            'id': 'c1',
            'task_id': 't1',
            'tamamlayan_user_id': 'u1',
            'tamamlayan_ad': 'Ayse Demir',
            'tamamlanma_zamani': '2026-03-05T08:30:00Z',
            'foto_url': 'https://depo/x.jpg',
            'notlar': 'tamam',
            'idempotency_key': 'k',
            'created_at': '2026-03-05T08:30:00Z',
          }
        ],
      });
      final liste = await api.fetchCompletions('t1');
      final (metot, uri) = adapter.istekler.single;
      expect(metot, 'GET');
      expect(uri.path, '/tasks/t1/completions');
      expect(liste.single.tamamlayanAd, 'Ayse Demir');
      expect(liste.single.fotoUrl, 'https://depo/x.jpg');
    });
  });

  group('DELETE — tamamlamayi geri al', () {
    test('dogru uca DELETE atar', () async {
      final (api: api, adapter: adapter) = _kur(const {}, status: 204);
      await api.deleteCompletion('t1', 'c1');
      final (metot, uri) = adapter.istekler.single;
      expect(metot, 'DELETE');
      expect(uri.path, '/tasks/t1/completions/c1');
    });

    test('SUNUCU 403 verirse ISTEMCI YUTMAZ', () async {
      // Yetki kurali SUNUCUDA (`_REOPENER`). Istemci hatayi yutarsa
      // kullanici geri aldigini sanir, kayit yerinde durur.
      final (api: api, adapter: _) = _kur(const {'detail': 'forbidden'},
          status: 403);
      expect(() => api.deleteCompletion('t1', 'c1'), throwsA(anything));
    });
  });
}
