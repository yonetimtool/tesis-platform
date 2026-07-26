import 'package:flutter/material.dart';

import '../core/branding/yonetio_logo.dart';

/// Acilista saklanan oturum kontrol edilirken (ve yonetici kurulum kapisi
/// yanit beklerken) gosterilen gecici ekran.
///
/// MARKALI: bos beyaz ekran + cirilciplak spinner, kullaniciya "uygulama
/// takildi" hissi veriyordu. Ayni bilesen iki bekleme noktasinda da kullanilir
/// (yeni bir splash EKLENMEZ, var olan bu).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            YonetioLogoVertical(iconSize: 84),
            SizedBox(height: 24),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
