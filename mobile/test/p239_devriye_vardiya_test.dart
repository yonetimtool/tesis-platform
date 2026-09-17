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

  group('(P239 §4) HAFTALIK GUN SECIMI + EK TARIHLER', () {
    test('SECILEN GUNLER govdeye SIRALI gider (ISO)', () async {
      // JS 0=Pazar der, veritabani ve Python ISO kullanir (1=Pzt).
      // Siralama karsilastirmayi belirli kilar.
      final a = _Adapter();
      await _api(a).create(
        ad: 'Gece turu',
        baslangicSaat: '22:00:00',
        bitisSaat: '06:00:00',
        periyotDakika: 60,
        gunler: [4, 1],
      );
      expect((a.istekler.single.data as Map)['gunler'], [1, 4]);
    });

    test('BOS LISTE null GIDER — sunucuya 422 uretecek govde YOLLANMAZ', () async {
      // Bos dizi "hicbir gun" demek olurdu; sunucu hakli olarak 422
      // verir. Istemci o istegi hic atmamali: gun secilmediyse
      // "her gun" (null) kastedilir.
      final a = _Adapter();
      await _api(a).create(
        ad: 'Gece turu',
        baslangicSaat: '22:00:00',
        bitisSaat: '06:00:00',
        periyotDakika: 60,
        gunler: const [],
      );
      final govde = a.istekler.single.data as Map;
      expect(govde.containsKey('gunler'), isTrue);
      expect(govde['gunler'], isNull);
    });

    test('EK TARIHLER YYYY-MM-DD gider — SAAT KIRPILIR', () async {
      // Tam ISO damgasi gondermek yerel saat/UTC farkiyla gunu BIR
      // KAYDIRABILIRDI (23:00'te secilen gun ertesi gun olurdu).
      final a = _Adapter();
      await _api(a).create(
        ad: 'Gece turu',
        baslangicSaat: '22:00:00',
        bitisSaat: '06:00:00',
        periyotDakika: 60,
        ekTarihler: [DateTime(2026, 8, 30, 23, 30)],
      );
      expect((a.istekler.single.data as Map)['ek_tarihler'], ['2026-08-30']);
    });

    test('PATCH null GONDERIR: "her gune don" mumkun', () async {
      final a = _Adapter();
      await _api(a).update(
        'p1',
        ad: 'Gece turu',
        baslangicSaat: '22:00:00',
        bitisSaat: '06:00:00',
        periyotDakika: 60,
        aktif: true,
      );
      final govde = a.istekler.single.data as Map;
      expect(govde['gunler'], isNull);
      expect(govde['ek_tarihler'], isNull);
    });

    test('YANITTAN gunler ve ek_tarihler OKUNUR', () {
      final plan = PatrolPlan.fromJson(const {
        'id': 'p1',
        'ad': 'Gece turu',
        'baslangic_saat': '22:00:00',
        'bitis_saat': '06:00:00',
        'periyot_dakika': 60,
        'aktif': true,
        'gunler': [1, 4],
        'ek_tarihler': ['2026-08-30'],
      });
      expect(plan.gunler, [1, 4]);
      expect(plan.ekTarihler, [DateTime(2026, 8, 30)]);
    });

    test('ALANLAR YOKSA null (eski kayitlar = HER GUN)', () {
      final plan = PatrolPlan.fromJson(const {
        'id': 'p1',
        'ad': 'Gece turu',
        'baslangic_saat': '22:00:00',
        'bitis_saat': '06:00:00',
        'periyot_dakika': 60,
        'aktif': true,
      });
      expect(plan.gunler, isNull);
      expect(plan.ekTarihler, isNull);
    });
  });
}
