import 'package:flutter/material.dart';

/// GET /weather yaniti (WP-C). Savunmaci parse: alan yoksa guvenli varsayilan.
class Weather {
  const Weather({
    required this.sicaklikC,
    required this.durum,
    required this.konumAd,
  });

  final double sicaklikC;
  final String durum; // acik|parcali|kapali|sis|yagmur|kar|firtina
  final String konumAd;

  String get tempLabel => '${sicaklikC.round()}°C';

  factory Weather.fromJson(Map<String, dynamic> json) => Weather(
        sicaklikC: (json['sicaklik_c'] as num?)?.toDouble() ?? 0,
        durum: json['durum'] as String? ?? 'kapali',
        konumAd: json['konum_ad'] as String? ?? '',
      );
}

/// Durum anahtari -> baslik ikonu; bilinmeyen anahtar bulut.
IconData weatherIcon(String durum) => switch (durum) {
      'acik' => Icons.wb_sunny_outlined,
      'parcali' => Icons.wb_cloudy_outlined,
      'sis' => Icons.foggy,
      'yagmur' => Icons.umbrella_outlined,
      'kar' => Icons.ac_unit,
      'firtina' => Icons.thunderstorm_outlined,
      _ => Icons.cloud_outlined,
    };
