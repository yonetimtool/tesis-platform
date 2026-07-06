import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../domain/push_models.dart';

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
      FirebaseMessaging.onMessage.map(
        (RemoteMessage m) => PushMessageEvent(
          title: m.notification?.title,
          body: m.notification?.body,
          data: m.data.map((k, v) => MapEntry(k, v.toString())),
        ),
      );
}
