/// (P183) Ayarlar/push iceren widget testleri icin sahteler.
///
/// NEDEN GEREKLI: `SettingsScreen` artik "Bildirim tercihleri" kartini cizer.
/// Kart `bildirimTercihProvider` (GET /me/bildirim-tercihleri) ve
/// `pushRegistrarProvider`i okur. Gercek istemci testte AG cagrisi yapar
/// (sonsuz donen spinner + "Timer is still pending") ve `pumpAndSettle`
/// asla oturmaz. Bu gecersiz kilmalar kanali SABIT bir degere/kapali push'a
/// baglar — tenantApi'nin sahtelenmesiyle ayni desen.
library;

import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:mobile/src/features/push/data/push_messaging.dart';
import 'package:mobile/src/features/push/domain/push_models.dart';
import 'package:mobile/src/features/push/presentation/push_registrar.dart';
import 'package:mobile/src/features/settings/data/bildirim_tercih_api.dart';
import 'package:mobile/src/features/settings/domain/bildirim_tercihleri.dart';

/// Platform kanalina inmeyen sahte push katmani. `initialize`→false ile push
/// SESSIZCE devre disidir (Firebase yok); kayit/izin akislari tetiklenmez.
class SahtePushMessaging implements PushMessaging {
  @override
  Future<bool> initialize() async => false;

  @override
  Future<PushIzinDurumu> requestPermission() async => PushIzinDurumu.verildi;

  @override
  Future<PushIzinDurumu> izinDurumu() async => PushIzinDurumu.verildi;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => Stream<String>.empty();

  @override
  Stream<PushMessageEvent> get onForegroundMessage =>
      Stream<PushMessageEvent>.empty();

  @override
  Stream<PushMessageEvent> get onMessageOpenedApp =>
      Stream<PushMessageEvent>.empty();

  @override
  Future<PushMessageEvent?> getInitialMessage() async => null;
}

/// `SettingsScreen` iceren testlerin ProviderScope'una eklenecek gecersiz
/// kilmalar: bildirim tercihi SABIT (ag cagrisi yok) + push devre disi.
List<Override> bildirimTestOverrides({
  BildirimTercihleri tercih = const BildirimTercihleri(
    eposta: true,
    sms: true,
    mobil: true,
  ),
}) =>
    [
      pushMessagingProvider.overrideWithValue(SahtePushMessaging()),
      bildirimTercihProvider.overrideWith((ref) async => tercih),
    ];
