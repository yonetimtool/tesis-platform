import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
import 'package:mobile/src/features/auth/domain/auth_repository.dart';
import 'package:mobile/src/features/auth/domain/phone_login_result.dart';
import 'package:mobile/src/features/auth/presentation/auth_controller.dart';
import 'package:mobile/src/features/push/data/device_api.dart';
import 'package:mobile/src/features/push/data/push_messaging.dart';
import 'package:mobile/src/features/push/data/push_token_store.dart';
import 'package:mobile/src/features/push/domain/push_models.dart';
import 'package:mobile/src/features/push/presentation/push_registrar.dart';
import 'package:mobile/src/features/push/presentation/push_setup.dart';

/// Davranisi test basina ayarlanabilen sahte Firebase katmani.
class _FakeMessaging implements PushMessaging {
  bool initResult = true;
  String? token = 'tok-1';
  int initCalls = 0;
  int permissionCalls = 0;
  int getTokenCalls = 0;

  final tokenRefresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessageEvent>.broadcast();
  final opened = StreamController<PushMessageEvent>.broadcast();

  /// Uygulama kapaliyken tiklanan bildirim (varsa) — bir kez okunur.
  PushMessageEvent? initialMessage;

  @override
  Future<bool> initialize() async {
    initCalls++;
    return initResult;
  }

  @override
  Future<void> requestPermission() async => permissionCalls++;

  @override
  Future<String?> getToken() async {
    getTokenCalls++;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => tokenRefresh.stream;

  @override
  Stream<PushMessageEvent> get onForegroundMessage => foreground.stream;

  @override
  Stream<PushMessageEvent> get onMessageOpenedApp => opened.stream;

  @override
  Future<PushMessageEvent?> getInitialMessage() async => initialMessage;
}

/// register/unregister cagrilarini kaydeden, hatasi ayarlanabilen sahte API.
class _FakeDeviceApi extends DeviceApi {
  _FakeDeviceApi() : super(Dio());

  final registered = <({String token, String platform})>[];
  final unregistered = <String>[];
  ApiException? registerError;
  ApiException? unregisterError;

  @override
  Future<void> register({
    required String fcmToken,
    required String platform,
  }) async {
    if (registerError != null) throw registerError!;
    registered.add((token: fcmToken, platform: platform));
  }

  @override
  Future<void> unregister(String fcmToken) async {
    if (unregisterError != null) throw unregisterError!;
    unregistered.add(fcmToken);
  }
}

/// Bellek-ici token isareti (secure storage platform kanali gerektirir).
class _MemTokenStore extends PushTokenStore {
  _MemTokenStore() : super(const FlutterSecureStorage());

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> save(String token) async => value = token;

  @override
  Future<void> clear() async => value = null;
}

/// Oturum durumu ayarlanabilen sahte auth deposu (secure storage'a inmez).
class _FakeAuthRepository implements AuthRepository {
  bool sessionExists = false;

  @override
  Future<bool> restoreSession() async => sessionExists;

  @override
  Future<PhoneLoginResult> loginPhone({
    required String phone,
    required String password,
    bool rememberMe = false,
  }) async {
    sessionExists = true;
    return const PhoneLoginResult(passwordSetupRequired: false);
  }

  @override
  Future<void> signup({
    required String tenantAd,
    required String yoneticiAd,
    required String phone,
    required String password,
    bool rememberMe = false,
  }) async {
    sessionExists = true;
  }

  @override
  Future<void> setPassword({
    required String setupToken,
    required String newPassword,
    bool rememberMe = false,
  }) async {
    sessionExists = true;
  }

  @override
  Future<void> logout() async {
    sessionExists = false;
  }
}

void main() {
  late _FakeMessaging messaging;
  late _FakeDeviceApi api;
  late _MemTokenStore store;
  late _FakeAuthRepository authRepo;

  setUp(() {
    messaging = _FakeMessaging();
    api = _FakeDeviceApi();
    store = _MemTokenStore();
    authRepo = _FakeAuthRepository();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        pushMessagingProvider.overrideWithValue(messaging),
        deviceApiProvider.overrideWithValue(api),
        pushTokenStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(authRepo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> waitFor(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('waitFor zaman asimi');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  /// Registrar'i aktive eder ve login akisini calistirir.
  Future<ProviderContainer> loginAndRegister() async {
    final container = makeContainer();
    container.read(pushSetupProvider); // auth→push tetikleyicisini canlandir
    await container.read(authControllerProvider.notifier).loginPhone(
          phone: '+905321112203',
          password: 'p',
        );
    await waitFor(
        () => container.read(pushRegistrarProvider).kayitliToken != null);
    return container;
  }

  test('login sonrasi: init + izin + token al + POST /devices (android)',
      () async {
    final container = await loginAndRegister();

    expect(messaging.initCalls, greaterThanOrEqualTo(1));
    expect(messaging.permissionCalls, greaterThanOrEqualTo(1));
    expect(api.registered.single.token, 'tok-1');
    expect(api.registered.single.platform, 'android');
    expect(store.value, 'tok-1');

    final state = container.read(pushRegistrarProvider);
    expect(state.durum, PushDurum.hazir);
    expect(state.kayitliToken, 'tok-1');
  });

  test('acilista oturum zaten aciksa da kayit yapilir (restore akisi)',
      () async {
    authRepo.sessionExists = true;
    final container = makeContainer();
    container.read(pushSetupProvider);
    container.read(authControllerProvider); // restore'u tetikle

    await waitFor(
        () => container.read(pushRegistrarProvider).kayitliToken == 'tok-1');
    expect(api.registered.single.token, 'tok-1');
  });

  test('Firebase baslatilamazsa: push devre disi, kayit yok, cokme yok',
      () async {
    messaging.initResult = false;
    final container = makeContainer();
    container.read(pushSetupProvider);
    await container.read(authControllerProvider.notifier).loginPhone(
          phone: '+905321112203',
          password: 'p',
        );

    await waitFor(() =>
        container.read(pushRegistrarProvider).durum == PushDurum.devreDisi);
    expect(api.registered, isEmpty);
    expect(messaging.getTokenCalls, 0);
    expect(store.value, isNull);
  });

  test('token alinamazsa (null) kayit denenmez ama push hazir kalir',
      () async {
    messaging.token = null;
    final container = makeContainer();
    container.read(pushSetupProvider);
    await container.read(authControllerProvider.notifier).loginPhone(
          phone: '+905321112203',
          password: 'p',
        );

    await waitFor(
        () => container.read(pushRegistrarProvider).durum == PushDurum.hazir);
    expect(api.registered, isEmpty);
    expect(container.read(pushRegistrarProvider).kayitliToken, isNull);
  });

  test('POST /devices hatasi yutulur (login akisi bozulmaz)', () async {
    api.registerError = const ApiException(
      code: 'network_error',
      message: 'ag yok',
    );
    final container = makeContainer();
    container.read(pushSetupProvider);
    await container.read(authControllerProvider.notifier).loginPhone(
          phone: '+905321112203',
          password: 'p',
        );

    await waitFor(
        () => container.read(pushRegistrarProvider).durum == PushDurum.hazir);
    expect(container.read(pushRegistrarProvider).kayitliToken, isNull);
    expect(store.value, isNull);
    // Auth akisi etkilenmedi:
    expect(container.read(authControllerProvider).status,
        AuthStatus.authenticated);
  });

  test('onTokenRefresh: eski token pasiflestirilir, yenisi kaydedilir',
      () async {
    final container = await loginAndRegister();

    messaging.tokenRefresh.add('tok-2');
    await waitFor(
        () => container.read(pushRegistrarProvider).kayitliToken == 'tok-2');

    expect(api.unregistered, ['tok-1']);
    expect(api.registered.last.token, 'tok-2');
    expect(store.value, 'tok-2');
  });

  test('logout: unregister + yerel isaret temizlenir', () async {
    final container = await loginAndRegister();

    await container.read(pushRegistrarProvider.notifier).onLogout();

    expect(api.unregistered, ['tok-1']);
    expect(store.value, isNull);
    expect(container.read(pushRegistrarProvider).kayitliToken, isNull);
  });

  test('logout: unregister hatasi yutulur, yerel isaret yine temizlenir',
      () async {
    final container = await loginAndRegister();
    api.unregisterError = const ApiException(
      code: 'network_error',
      message: 'ag yok',
    );

    await container.read(pushRegistrarProvider.notifier).onLogout();

    expect(store.value, isNull);
    expect(container.read(pushRegistrarProvider).kayitliToken, isNull);
  });

  test('hic kayit yokken logout no-op (unregister cagrilmaz)', () async {
    final container = makeContainer();
    container.read(pushSetupProvider);

    await container.read(pushRegistrarProvider.notifier).onLogout();

    expect(api.unregistered, isEmpty);
  });

  test('on plan mesaji state.sonBildirim olarak yansir', () async {
    final container = await loginAndRegister();

    messaging.foreground.add(const PushMessageEvent(
      title: 'Kacirilan tur',
      body: 'A blogu turu kacirildi',
      data: {'tip': 'kacirilan_tur'},
    ));

    await waitFor(
        () => container.read(pushRegistrarProvider).sonBildirim != null);
    final bildirim = container.read(pushRegistrarProvider).sonBildirim!;
    expect(bildirim.displayText, 'Kacirilan tur — A blogu turu kacirildi');
    expect(bildirim.data['tip'], 'kacirilan_tur');
  });

  test('tekrar login ayni token ile idempotent kayit (cift abonelik yok)',
      () async {
    final container = await loginAndRegister();

    await container.read(pushRegistrarProvider.notifier).onLogout();
    await container.read(authControllerProvider.notifier).logout();
    await container.read(authControllerProvider.notifier).loginPhone(
          phone: '+905321112203',
          password: 'p',
        );
    await waitFor(
        () => container.read(pushRegistrarProvider).kayitliToken == 'tok-1');

    // Iki login → iki kayit (idempotent, sorun degil) ama refresh'te
    // cift abonelikten dolayi cift kayit OLMAMALI:
    final before = api.registered.length;
    messaging.tokenRefresh.add('tok-9');
    await waitFor(
        () => container.read(pushRegistrarProvider).kayitliToken == 'tok-9');
    expect(api.registered.length, before + 1);
  });

  test('logout SONRASI token refresh kayit denemez (oturum yok → 401 olurdu)',
      () async {
    final container = await loginAndRegister();
    await container.read(authControllerProvider.notifier).logout();
    final before = api.registered.length;

    messaging.tokenRefresh.add('tok-3');
    // Islenecek bir sey yok; kuyrugun bosalmasini bekle.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(api.registered.length, before);
    expect(store.value, isNull);
  });

  test('AuthController.logout push kaydini da pasiflestirir (kanca)',
      () async {
    final container = await loginAndRegister();

    await container.read(authControllerProvider.notifier).logout();

    expect(api.unregistered, ['tok-1']);
    expect(store.value, isNull);
    expect(container.read(authControllerProvider).status,
        AuthStatus.unauthenticated);
  });

  test('tepsiden tiklanan bildirim state.sonTiklanan olarak yansir', () async {
    final container = await loginAndRegister();

    messaging.opened.add(const PushMessageEvent(
      title: 'Sikayet/Oneri',
      body: 'Talebiniz yanitlandi: Asansor',
      data: {'tip': 'talep_yanit', 'complaint_id': 'c-1'},
    ));

    await waitFor(
        () => container.read(pushRegistrarProvider).sonTiklanan != null);
    final tiklanan = container.read(pushRegistrarProvider).sonTiklanan!;
    expect(tiklanan.data['tip'], 'talep_yanit');
    expect(tiklanan.data['complaint_id'], 'c-1');
  });

  test('uygulama kapaliyken tiklanan bildirim (initial message) islenir',
      () async {
    messaging.initialMessage = const PushMessageEvent(
      title: 'Sikayet/Oneri',
      data: {'tip': 'talep', 'complaint_id': 'c-9'},
    );
    final container = await loginAndRegister();

    await waitFor(
        () => container.read(pushRegistrarProvider).sonTiklanan != null);
    expect(container.read(pushRegistrarProvider).sonTiklanan!.data['complaint_id'],
        'c-9');
  });

  test('PushMessageEvent.displayText: bos alanlarda makul metin', () {
    expect(const PushMessageEvent().displayText, 'Yeni bildirim');
    expect(const PushMessageEvent(title: 'Baslik').displayText, 'Baslik');
    expect(const PushMessageEvent(body: 'Govde').displayText, 'Govde');
  });
}
