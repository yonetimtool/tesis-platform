import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/weather/domain/weather_models.dart';

void main() {
  test('fromJson savunmaci parse + tempLabel yuvarlama', () {
    final w = Weather.fromJson(
        {'sicaklik_c': 23.6, 'durum': 'acik', 'konum_ad': 'İstanbul'});
    expect(w.sicaklikC, 23.6);
    expect(w.tempLabel, '24°C');
    expect(w.konumAd, 'İstanbul');
  });

  test('bozuk govde varsayilanlara duser (cokme yok)', () {
    final w = Weather.fromJson(const {});
    expect(w.tempLabel, '0°C');
    expect(w.durum, 'kapali');
  });

  test('weatherIcon eslemesi', () {
    expect(weatherIcon('acik'), Icons.wb_sunny_outlined);
    expect(weatherIcon('yagmur'), Icons.umbrella_outlined);
    expect(weatherIcon('kar'), Icons.ac_unit);
    expect(weatherIcon('firtina'), Icons.thunderstorm_outlined);
    expect(weatherIcon('bilinmeyen'), Icons.cloud_outlined);
  });
}
