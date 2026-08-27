import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../domain/push_models.dart';

/// (P181 Bölüm 10.1) ARKA PLAN mesaj handler'ı — uygulama ARKA PLANDA veya
/// TAMAMEN KAPALIYKEN gelen FCM mesajı için çağrılır.
///
/// AYRI İZOLASYON: Bu fonksiyon uygulamanın ana izolasyonunda DEĞİL, plugin'in
/// yeniden başlattığı bir arka-plan izolasyonunda koşar → Firebase burada
/// TEKRAR başlatılmalı ve TOP-LEVEL + `@pragma('vm:entry-point')` olmalı
/// (native taraf bu giriş noktasını çağırır; kapalıyken de çalışsın diye).
///
/// EK BİLDİRİM GÖSTERMEZ: backend `notification` (başlık+gövde) + `data`
/// gönderir; FCM tepsi bildirimini KENDİSİ düşürür. Burada ikinci bir bildirim
/// göstermek ÇİFT bildirim olurdu. Dokunma → yönlendirme ana izolasyonda
/// `onMessageOpenedApp`/`getInitialMessage` ile yapılır (bkz. PushRegistrar).
/// Data-ONLY mesaj ileride eklenirse işlenecek yer burasıdır.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint('BG push: tip=${message.data['tip']}');
  } catch (e) {
    debugPrint('BG push handler hatası (yutuldu): $e');
  }
}

/// Firebase katmanina acilan dar kapi. [PushRegistrar] yalniz bu arayuzu
/// gorur; testlerde sahtelenir, gercekte [FirebasePushMessaging] calisir.
abstract class PushMessaging {
  /// Firebase'i baslatir. google-services.json'siz build'de (veya herhangi
  /// bir baslatma hatasinda) false doner — ASLA firlatmaz; push devre disi
  /// kalir, uygulama normal calisir.
  Future<bool> initialize();

  /// Android 13+ bildirim izni istemi (POST_NOTIFICATIONS). Reddedilse de
  /// akis durmaz — token yine alinir, yalniz bildirim gosterilmez.
  Future<void> requestPermission();

  /// Cihazin guncel FCM kayit token'i (alinamazsa null).
  Future<String?> getToken();

  /// FCM token rotasyonu — yeni token backend'e yeniden kaydedilmeli.
  Stream<String> get onTokenRefresh;

  /// Uygulama ON PLANDAYKEN gelen mesajlar (sistem tepsisine dusmez;
  /// uygulama ici gosterim bizim isimiz).
  Stream<PushMessageEvent> get onForegroundMessage;

  /// Uygulama ARKA PLANDAYKEN tepsideki bildirime tiklanip acilmasi.
  Stream<PushMessageEvent> get onMessageOpenedApp;

  /// Uygulama KAPALIYKEN bildirime tiklanarak acildiysa o mesaj (yoksa
  /// null). Baslatma sonrasi BIR KEZ okunur.
  Future<PushMessageEvent?> getInitialMessage();
}

/// Gercek Firebase uyarlamasi. Platform kanali gerektirdigi icin birim
/// testlerde kullanilmaz (fake'i vardir); mantik icermez, sadece cevirir.
class FirebasePushMessaging implements PushMessaging {
  bool _initialized = false;

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      await Firebase.initializeApp();
      // (P181 Bölüm 10.1) ARKA PLAN handler'ını KAYDET — ana izolasyonda bir
      // kez çağrılır, native tarafta KALICI olur (uygulama kapalıyken de gelen
      // mesajda plugin bu giriş noktasını çağırır). Firebase yapılandırılmamış
      // build'de buraya HİÇ ulaşılmaz (üstteki initializeApp fırlatır).
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _initialized = true;
      return true;
    } catch (e) {
      // google-services.json'siz build / eksik yapilandirma: push kapali,
      // uygulama COKMEZ (kabul kriteri).
      debugPrint('Firebase baslatilamadi, push devre disi: $e');
      return false;
    }
  }

  @override
  Future<void> requestPermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (e) {
      debugPrint('Bildirim izni istenemedi: $e');
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('FCM token alinamadi: $e');
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  @override
  Stream<PushMessageEvent> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(_toEvent);

  @override
  Stream<PushMessageEvent> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(_toEvent);

  @override
  Future<PushMessageEvent?> getInitialMessage() async {
    try {
      final m = await FirebaseMessaging.instance.getInitialMessage();
      return m == null ? null : _toEvent(m);
    } catch (e) {
      debugPrint('Acilis bildirimi okunamadi: $e');
      return null;
    }
  }

  static PushMessageEvent _toEvent(RemoteMessage m) => PushMessageEvent(
        title: m.notification?.title,
        body: m.notification?.body,
        data: m.data.map((k, v) => MapEntry(k, v.toString())),
      );
}
