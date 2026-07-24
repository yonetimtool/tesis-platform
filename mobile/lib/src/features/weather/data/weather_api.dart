import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../domain/weather_models.dart';

/// GET /weather istemcisi (WP-C) — tenant konumu icin hava durumu.
/// RBAC: tum kimlikli roller (ana ekran basligi). Hata/bos govde
/// savunmaci parse ile guvenli varsayilana duser.
class WeatherApi {
  WeatherApi(this._dio);
  final Dio _dio;

  Future<Weather> fetch() async {
    final res = await _dio.get<Map<String, dynamic>>('/weather');
    return Weather.fromJson(res.data ?? const {});
  }
}

final weatherApiProvider = Provider<WeatherApi>((ref) {
  return WeatherApi(ref.watch(dioProvider));
});

/// Ana ekran basligi hava blogu — hata/yuklemede blok sessizce gizlenir.
final weatherProvider = FutureProvider.autoDispose<Weather>((ref) {
  return ref.watch(weatherApiProvider).fetch();
});
