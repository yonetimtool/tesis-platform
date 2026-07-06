import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/device_api.dart';
import '../data/push_messaging.dart';
import '../data/push_token_store.dart';
import '../domain/push_models.dart';

/// FCM token yasam dongusu: login sonrasi kayit, rotasyonda yeniden kayit,
/// logout'ta pasiflestirme; on plan mesajlarini state'e yansitir.
///
/// Auth'a BILEREK bagimli degildir (AuthController logout'ta bunu cagirir;
/// ters yonde de bagimlilik olsaydi provider dongusu olusurdu) — login
/// tetiklemesi [pushSetupProvider] uzerinden gelir.
///
/// TUM hatalar burada yutulur (log'lanir): push, cekirdek akislari (login/
/// logout/scan) hicbir kosulda bozamaz. Firebase baslatilamazsa (orn.
/// google-services.json'siz build) durum [PushDurum.devreDisi] olur ve
/// uygulama normal calisir.
class PushRegistrar extends Notifier<PushState> {
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<PushMessageEvent>? _foregroundSub;

  /// initialize() tek kez kossun; es zamanli tetiklerde ayni Future paylasilir.
  Future<bool>? _initFuture;

  @override
  PushState build() {
    ref.onDispose(() {
      _refreshSub?.cancel();
      _foregroundSub?.cancel();
    });
    return const PushState();
  }

  PushMessaging get _messaging => ref.read(pushMessagingProvider);
  DeviceApi get _api => ref.read(deviceApiProvider);
  PushTokenStore get _store => ref.read(pushTokenStoreProvider);

  /// Firebase'i (bir kez) baslatir, dinleyicileri kurar. false → devre disi.
  Future<bool> _ensureReady() async {
    if (state.durum == PushDurum.devreDisi) return false;
    final ok = await (_initFuture ??= _messaging.initialize());
    if (!ref.mounted) return false;
    if (!ok) {
      state = state.copyWith(durum: PushDurum.devreDisi);
      return false;
    }
    if (state.durum != PushDurum.hazir) {
      state = state.copyWith(durum: PushDurum.hazir);
      // Dinleyiciler tek kez kurulur (hazir'a ilk gecis).
      _refreshSub = _messaging.onTokenRefresh.listen(_onTokenRefresh);
      _foregroundSub = _messaging.onForegroundMessage.listen((event) {
        if (ref.mounted) state = state.copyWith(sonBildirim: event);
      });
    }
    return true;
  }

  /// Guncel FCM token'i alip backend'e kaydeder. Login/acilis sonrasi
  /// [pushSetupProvider] cagirir; backend idempotent upsert yaptigi icin
  /// her cagri guvenlidir.
  Future<void> registerCurrentToken() async {
    try {
      if (!await _ensureReady()) return;
      await _messaging.requestPermission();
      final token = await _messaging.getToken();
      if (token == null || !ref.mounted) return;
      await _register(token);
    } catch (e) {
      debugPrint('Push token kaydi basarisiz (sonraki acilista denenir): $e');
    }
  }

  /// FCM token rotasyonu: eski kaydi pasiflestir (best-effort), yeniyi yaz.
  /// Yerel isaret yoksa (hic kayit olmadi / logout sonrasi) atlanir — oturum
  /// yokken POST 401 uretirdi; sonraki login zaten guncel token'i kaydeder.
  Future<void> _onTokenRefresh(String newToken) async {
    try {
      final old = await _store.read();
      if (old == null) return;
      if (old != newToken) {
        try {
          await _api.unregister(old);
        } on Exception catch (e) {
          debugPrint('Eski push token pasiflestirilemedi: $e');
        }
      }
      await _register(newToken);
    } catch (e) {
      debugPrint('Push token yenileme kaydi basarisiz: $e');
    }
  }

  Future<void> _register(String token) async {
    try {
      await _api.register(
        fcmToken: token,
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      );
      await _store.save(token);
      if (ref.mounted) state = state.copyWith(kayitliToken: token);
    } catch (e) {
      // Ag yok / sunucu hatasi: sonraki login/acilista yeniden denenir
      // (backend idempotent). Login akisini ASLA bozma.
      debugPrint('POST /devices basarisiz: $e');
    }
  }

  /// Logout ANINDA (auth token'lar henuz gecerliyken) cagrilir: sunucudaki
  /// cihaz kaydini pasiflestirir + yerel isareti temizler. Hatalar yutulur —
  /// push sorunu logout'u asla engellemez.
  Future<void> onLogout() async {
    try {
      final token = await _store.read();
      if (token != null) {
        try {
          await _api.unregister(token);
        } on Exception catch (e) {
          debugPrint('Push token pasiflestirilemedi (logout): $e');
        }
      }
      await _store.clear();
      if (ref.mounted) state = state.copyWith(kayitliToken: null);
    } catch (e) {
      debugPrint('Push logout temizligi basarisiz: $e');
    }
  }
}

final pushMessagingProvider =
    Provider<PushMessaging>((ref) => FirebasePushMessaging());

final pushRegistrarProvider =
    NotifierProvider<PushRegistrar, PushState>(PushRegistrar.new);
