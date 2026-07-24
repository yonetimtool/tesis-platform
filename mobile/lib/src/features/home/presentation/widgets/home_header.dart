import 'package:flutter/material.dart';

/// Hava durumu verisi — SAF deger tipi. Veri GET /weather'dan gelir
/// (weatherProvider); yukleme/hata durumunda [HomeHeader.weather] null gecilir
/// ve blok gizli kalir.
class HomeWeather {
  const HomeWeather({
    required this.tempLabel,
    required this.city,
    this.icon = Icons.wb_sunny_outlined,
  });

  final String tempLabel; // or. "24°C"
  final String city; // or. "İstanbul"
  final IconData icon; // durum ikonu (weatherIcon); varsayilan gunes
}

/// Referans ana ekranin karsilama blogu: solda "Merhaba, {ad}" + rol/daire
/// alt-basligi, sagda opsiyonel hava (gunes ikonu + sicaklik + sehir). Bildirim
/// zili + avatar app-bar satirindadir (HomeShell) — burada DEGIL.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.greetingName,
    required this.subtitle,
    this.weather,
  });

  final String greetingName;
  final String subtitle;
  final HomeWeather? weather;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Merhaba, $greetingName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        if (weather != null) ...[
          const SizedBox(width: 12),
          _WeatherBlock(weather: weather!),
        ],
      ],
    );
  }
}

class _WeatherBlock extends StatelessWidget {
  const _WeatherBlock({required this.weather});

  final HomeWeather weather;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          weather.icon,
          size: 22,
          // Amber yalniz gunes ikonunda; diger durumlar notr renkte.
          color: weather.icon == Icons.wb_sunny_outlined
              ? Colors.amber
              : theme.hintColor,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              weather.tempLabel,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              weather.city,
              style:
                  theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      ],
    );
  }
}
