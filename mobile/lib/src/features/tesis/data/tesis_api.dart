/// (P203 §2) COKLU TESIS — uyelikler ve gecis (mobil).
///
/// ===========================================================================
/// MOBILDE GIRIS TEK TESISE DUSER — OLCULDU
/// ===========================================================================
/// Mobil giris TELEFONLADIR ve `uq_app_user_telefon` GLOBAL benzersizdir:
/// bir numara TEK bir tesis satirina karsilik gelir. Yani mobilde
/// "hangi tesise gireyim" sorusu GIRISTE sorulamaz — kisi bir tesise
/// girer ve UYGULAMA ICINDEN gecer. Web'de durum farklidir (e-postayla
/// girilir ve e-posta tesis icinde benzersizdir).
///
/// Bu yuzden mobilde `/auth/tesislerim` (giris oncesi) KULLANILMAZ;
/// yalnizca oturum ici iki uc gerekir.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../../auth/domain/token_pair.dart';
import '../domain/tesis_uyeligi.dart';

class TesisApi {
  TesisApi(this._dio);

  final Dio _dio;

  Future<List<TesisUyeligi>> uyelikler() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/me/tesislerim');
      final ham = (res.data?['tesisler'] as List?) ?? const [];
      return ham
          .whereType<Map<String, dynamic>>()
          .map(TesisUyeligi.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Hedef tesis icin YENI jeton. Parola SORMAZ (bkz. backend
  /// `routers/me.py` — kimlik e-postadir).
  Future<TokenPair> degistir(String tenantId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/me/tesis-degistir',
        data: {'tenant_id': tenantId},
      );
      return TokenPair.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final tesisApiProvider = Provider<TesisApi>((ref) => TesisApi(ref.watch(dioProvider)));
