import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// (P247 §5) Uygulama simgesi rozetini GERCEK okunmamis sayiya ceker.
///
/// Push `aps.badge` ile gelir; uygulama acilip okununca sayi yalniz burada
/// duzelir. YALNIZ iOS: Android'de simge rozeti bildirim tepsisinden
/// turetilir (bildirim silinince kendiliginden duser) ve sunucu sayiyi
/// `notification_count` ile zaten verir. Kanal yoksa (test, eski paket)
/// sessizce gecilir — rozet bir suslemedir, akisi durdurmamali.
const uygulamaRozetiKanali = MethodChannel('site.yonetio.app/rozet');

Future<void> uygulamaRozetiniAyarla(int sayi) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
  try {
    await uygulamaRozetiKanali.invokeMethod<void>('ayarla', sayi < 0 ? 0 : sayi);
  } catch (e) {
    debugPrint('rozet ayarlanamadi (yutuldu): $e');
  }
}
