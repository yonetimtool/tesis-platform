import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/auth_interceptor.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/auth/domain/token_pair.dart';

/// (DUKKAN F4) IKI JETON DUNYASI BIRBIRINE KARISMAZ.
///
/// =========================================================================
/// ONLENEN KUSUR
/// =========================================================================
/// `AuthInterceptor` HER istege Yonetiyor jetonunu koyuyor. Dukkan'in
/// korunan uclarina o jetonla gidilirse:
///   1. uc 401 doner (Yonetiyor jetonu `tur: "dukkan"` iddiasi tasimaz),
///   2. `onError` bunu "oturum bitti" sanip YONETIYOR REFRESH'i dener,
///   3. refresh de basarisiz olursa `onSessionExpired()` cagrilir ve
///      KULLANICI YONETIYOR'DAN ATILIR.
///
/// Yani Dukkan'da talep listesi acmak, kullaniciyi TESIS UYGULAMASINDAN
/// cikarabilirdi — sessiz ve teshisi cok zor bir kusur.
///
/// Cozum: istek `extra[dukkanJetonu]` tasidiginda o jeton kullanilir ve
/// refresh/oturum mantigi ATLANIR. Bu dosya ucunu de olcuyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final store = <String, String>{};

  setUp(() {
    store.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      final args = (call.arguments as Map).cast<String, dynamic>();
      switch (call.method) {
        case 'write':
          store[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          return store[args['key'] as String];
        case 'delete':
          store.remove(args['key'] as String);
          return null;
        case 'readAll':
          return store;
        case 'deleteAll':
          store.clear();
          return null;
        case 'containsKey':
          return store.containsKey(args['key'] as String);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<TokenStorage> depoHazirla() async {
    final s = TokenStorage(const FlutterSecureStorage());
    await s.save(const TokenPair(
      accessToken: 'YONETIYOR_JETONU',
      refreshToken: 'ref',
      tokenType: 'Bearer',
      expiresIn: 900,
    ));
    return s;
  }

  test('Dukkan jetonlu istekte YONETIYOR jetonu KULLANILMAZ', () async {
    final interceptor = AuthInterceptor(
      storage: await depoHazirla(),
      rawDio: Dio(),
      onSessionExpired: () async {},
    );
    final istek = RequestOptions(
      path: '/dukkan/talep',
      extra: {AuthInterceptor.dukkanJetonu: 'DUKKAN_JETONU'},
    );
    await interceptor.onRequest(istek, RequestInterceptorHandler());
    expect(istek.headers['Authorization'], 'Bearer DUKKAN_JETONU',
        reason: 'Dukkan jetonu yerine Yonetiyor jetonu konmus');
  });

  test('Dukkan jetonu YOKSA Yonetiyor jetonu konur (mevcut davranis korunur)',
      () async {
    // TERS YONLU KANIT: ustteki test, interceptor HICBIR jeton koymasa da
    // gecerdi. Bu test mevcut davranisin bozulmadigini olcuyor.
    final interceptor = AuthInterceptor(
      storage: await depoHazirla(),
      rawDio: Dio(),
      onSessionExpired: () async {},
    );
    final istek = RequestOptions(path: '/units');
    await interceptor.onRequest(istek, RequestInterceptorHandler());
    expect(istek.headers['Authorization'], 'Bearer YONETIYOR_JETONU');
  });

  test('Dukkan 401i YONETIYOR OTURUMUNU KAPATMAZ', () async {
    var oturumKapandi = false;
    final interceptor = AuthInterceptor(
      storage: await depoHazirla(),
      rawDio: Dio(),
      onSessionExpired: () async => oturumKapandi = true,
    );
    final istek = RequestOptions(
      path: '/dukkan/talep',
      extra: {AuthInterceptor.dukkanJetonu: 'SURESI_DOLMUS_DUKKAN_JETONU'},
    );
    final hata = DioException(
      requestOptions: istek,
      response: Response(requestOptions: istek, statusCode: 401),
    );
    // `ErrorInterceptorHandler.next()` hatayi YUKARI ILETIR ve bu DOGRU
    // davranis — cagiran (Dukkan katmani) 401'i kendisi ele almali.
    //
    // Hata handler'in `future`'ina ASENKRON dusuyor; `try/catch`
    // yakalayamiyor ve zone'da "unhandled" olarak patliyor (olculdu).
    // Bu yuzden future'a ONCEDEN tutamak takiliyor.
    final handler = ErrorInterceptorHandler();
    handler.future.then((_) {}, onError: (_) {});
    await interceptor.onError(hata, handler);
    expect(oturumKapandi, isFalse,
        reason: 'Dukkan 401i Yonetiyor oturumunu KAPATTI — '
            'kullanici tesis uygulamasindan atilirdi');
  });
}
