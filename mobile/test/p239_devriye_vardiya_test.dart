/// (P239 §3) DEVRIYE PLANINDA VARDIYA SECIMI — mobil paritesi.
///
/// =========================================================================
/// OLCULEN KUSUR
/// =========================================================================
/// Web devriye plani formunda `shift_id` (vardiya) secicisi VARDI;
/// MOBILDE YOKTU. `patrol_plan` tablosunda atanan KISI kolonu hic yok —
/// "kim yuruyecek" sorusunun bugunku yaniti plani bir VARDIYAYA
/// baglamak ve o vardiyanin kadrosunun yurumesi. Yani mobilden acilan
/// her plan kadrosuz kaliyordu ve kimin yuruyecegi hicbir yerde
/// yazmiyordu.
///
/// Bu dosya GOVDEYI olcer: secim sunucuya GIDIYOR mu, bosaltmak
/// GONDERILIYOR mu (tam-govde PATCH kurali), yanittan GERI OKUNUYOR mu.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/patrol/data/patrol_plan_api.dart';

/// Taklit HTTP adapter — DIKIS YERI BURASI (repo/API duzeyinde taklit,
/// govdeyi kuran katmani olcmezdi).
class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> istekler = [];
  Map<String, dynamic> yanit = const {
    'id': 'p1',
    'ad': 'Gece turu',
    'baslangic_saat': '22:00:00',
    'bitis_saat': '06:00:00',
    'periyot_dakika': 60,
    'aktif': true,
    'shift_id': 's1',
  };

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    istekler.add(options);
    return ResponseBody.fromString(
      jsonEncode(yanit),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

PatrolPlanApi _api(_Adapter a) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.httpClientAdapter = a;
  return PatrolPlanApi(dio);
}

void main() {
  test('OLUSTURMA govdesinde shift_id GIDER', () async {
    final a = _Adapter();
    await _api(a).create(
      ad: 'Gece turu',
      baslangicSaat: '22:00:00',
      bitisSaat: '06:00:00',
      periyotDakika: 60,
      shiftId: 's1',
    );
    expect((a.istekler.single.data as Map)['shift_id'], 's1');
  });

  test('VARDIYA SECILMEZSE null gider — uydurma bag kurulmaz', () async {
    final a = _Adapter();
    await _api(a).create(
      ad: 'Gece turu',
      baslangicSaat: '22:00:00',
      bitisSaat: '06:00:00',
      periyotDakika: 60,
    );
    final govde = a.istekler.single.data as Map;
    expect(govde.containsKey('shift_id'), isTrue);
    expect(govde['shift_id'], isNull);
  });

  test('DUZENLEMEDE null GONDERILIR: vardiya bagi KALDIRILABILIR', () async {
    // Alan govdeden dusseydi "vardiyayi kaldir" istegi sunucuya hic
    // ulasmazdi (tam-govde PATCH kurali).
    final a = _Adapter();
    await _api(a).update(
      'p1',
      ad: 'Gece turu',
      baslangicSaat: '22:00:00',
      bitisSaat: '06:00:00',
      periyotDakika: 60,
      aktif: true,
      shiftId: null,
    );
    final govde = a.istekler.single.data as Map;
    expect(govde.containsKey('shift_id'), isTrue);
    expect(govde['shift_id'], isNull);
  });

  test('YANITTAN shift_id OKUNUR — duzenleme formu secimi tasiyabilsin',
      () async {
    final a = _Adapter();
    final plan = await _api(a).create(
      ad: 'Gece turu',
      baslangicSaat: '22:00:00',
      bitisSaat: '06:00:00',
      periyotDakika: 60,
      shiftId: 's1',
    );
    expect(plan.shiftId, 's1');
  });

  test('shift_id YOKSA model null tasir (eski kayitlar)', () {
    final plan = PatrolPlan.fromJson(const {
      'id': 'p1',
      'ad': 'Gece turu',
      'baslangic_saat': '22:00:00',
      'bitis_saat': '06:00:00',
      'periyot_dakika': 60,
      'aktif': true,
    });
    expect(plan.shiftId, isNull);
  });
}
