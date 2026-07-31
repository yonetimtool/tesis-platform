/// P23 — sakin yasam donusu (mobil tarafi).
///
/// Sunucu tarafi `backend/tests/test_residents.py` icinde uctan uca
/// kilitlendi; burada ISTEMCININ gonderdigi GOVDE olculur. Kritik nokta:
/// "bos birakmak" (degistirme) ile "SILMEK" (acikca null) AYRI seylerdir —
/// ikisi karisirsa yonetici e-postayi yanlislikla siler ya da silemez.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/residents/data/residents_api.dart';

/// GERCEK `ResidentsApi`yi surer; istek AGA CIKMADAN once yakalanir.
///
/// Onemli: govde kurma mantigini testte TEKRARLAMAYIZ. Ilk surumde
/// `updateResident` override edilip govde elle kuruluyordu — o test URUNU
/// degil KENDI KOPYASINI olcerdi ve urundeki bir degisikligi hic gormezdi.
/// Bunun yerine Dio'ya bir interceptor takilir: istek gercekten kurulur,
/// gonderilmeden yakalanir.
class _Yakalayici extends Interceptor {
  Map<String, dynamic>? sonGovde;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    sonGovde = Map<String, dynamic>.from(options.data as Map);
    // Agi HIC acmadan basarili yanit uret.
    handler.resolve(
      Response(requestOptions: options, statusCode: 204),
    );
  }
}

({ResidentsApi api, _Yakalayici yakala}) _kur() {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
  final y = _Yakalayici();
  dio.interceptors.add(y);
  return (api: ResidentsApi(dio), yakala: y);
}

void main() {
  group('P23b — duzenleme govdesi', () {
    test('BOS alanlar GONDERILMEZ (degismez)', () async {
      final k = _kur();
      await k.api.updateResident('u1', ad: 'Ayse', telefon: '', email: '');
      expect(k.yakala.sonGovde, {'ad': 'Ayse'});
    });

    test('e-posta ACIKCA null: "bos birakmak" ile "SILMEK" ayri', () async {
      final k = _kur();
      // Kutu doldurulmus OLSA BILE temizle anahtari kazanir — kullanici
      // "sil" dediyse eski metnin gonderilmesi sessiz bir hata olurdu.
      await k.api.updateResident('u1', email: 'a@b.com', emailTemizle: true);
      expect(k.yakala.sonGovde!.containsKey('email'), isTrue);
      expect(k.yakala.sonGovde!['email'], isNull);
    });

    test('rol_tipi yalniz SECILDIGINDE gonderilir', () async {
      final k = _kur();
      await k.api.updateResident('u1', ad: 'X');
      expect(k.yakala.sonGovde!.containsKey('rol_tipi'), isFalse);
      await k.api.updateResident('u1', rolTipi: 'malik');
      expect(k.yakala.sonGovde!['rol_tipi'], 'malik');
    });

    test('tum alanlar birlikte', () async {
      final k = _kur();
      await k.api.updateResident('u1',
          ad: 'Ayse', telefon: '+905321112203',
          email: 'a@b.com', rolTipi: 'kiraci');
      expect(k.yakala.sonGovde, {
        'ad': 'Ayse',
        'telefon': '+905321112203',
        'email': 'a@b.com',
        'rol_tipi': 'kiraci',
      });
    });
  });
}
