// TUR 14 — sunucu hata metinleri artik `Accept-Language`e gore uretiliyor.
//
// Bu baslik gitmezse sunucu 7 dilin hepsinde TURKCE hata doner ve tur 13'te
// kapatilan sizinti sunucu tarafindan geri gelir. Burada kilitlenen sozlesme:
//   * her istekte baslik VAR,
//   * degeri CIHAZ dili degil, uygulamanin O AN cizdigi dil,
//   * dil calisma aninda degisince SONRAKI istek yeni dili tasir,
//   * geri-dusme zinciri var (`ar, tr;q=0.8`) — sunucuda ceviri eksikse
//     Turkce'ye duser, bos metin gelmez.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/locale_controller.dart';
import 'package:mobile/src/core/network/dil_interceptor.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';

class _YakalayanAdapter implements HttpClientAdapter {
  final List<RequestOptions> istekler = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add(options);
    return ResponseBody.fromString(jsonEncode({'ok': true}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _YakalayanAdapter adapter;
  late Dio dio;
  late String aktifDil;

  setUp(() {
    aktifDil = 'tr';
    adapter = _YakalayanAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://ornek.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(DilInterceptor(dilKodu: () => aktifDil));
  });

  String? sonBaslik() =>
      adapter.istekler.last.headers['Accept-Language'] as String?;

  test('her istek Accept-Language tasir', () async {
    await dio.get('/units');
    expect(sonBaslik(), 'tr');
  });

  test('Turkce disi dilde geri-dusme zinciri eklenir', () async {
    for (final dil in ['en', 'ar', 'ru', 'de', 'fr', 'es']) {
      aktifDil = dil;
      await dio.get('/units');
      expect(sonBaslik(), '$dil, tr;q=0.8', reason: dil);
    }
  });

  test('dil DEGISINCE sonraki istek yeni dili tasir', () async {
    await dio.get('/units');
    expect(sonBaslik(), 'tr');

    // Kullanici uygulama icinden Arapca sectiyse: sabit header olsaydi bu
    // istek hala tr giderdi (baslik istek aninda okunuyor).
    aktifDil = 'ar';
    await dio.get('/units');
    expect(sonBaslik(), 'ar, tr;q=0.8');
  });

  test('mevcut baslikları ezmez, yalnız kendi anahtarını yazar', () async {
    await dio.get(
      '/units',
      options: Options(headers: {'Authorization': 'Bearer abc'}),
    );
    expect(adapter.istekler.last.headers['Authorization'], 'Bearer abc');
    expect(sonBaslik(), 'tr');
  });

  // --- KABLOLAMA: baslik gercekten paylasilan Dio'lara takili mi? ---
  group('kablolama', () {
    ProviderContainer kap() {
      final c = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(_BosDepo())],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('paylasilan VE ham Dio ikisi de DilInterceptor tasir', () {
      final c = kap();
      // Ham Dio da onemli: refresh 401'i de kullanicinin dilinde gelmeli.
      for (final dio in [c.read(dioProvider), c.read(rawDioProvider)]) {
        expect(dio.interceptors.whereType<DilInterceptor>(), hasLength(1));
      }
    });

    test('aktif dil kodu: secim varsa o, yoksa cihazdan cozulur', () async {
      final c = kap();
      // Secim yok -> cihaz dili desteklenmiyorsa tr'ye duser.
      expect(supportedLocales.map((l) => l.languageCode),
          contains(c.read(aktifDilKoduProvider)));
      await c.read(localeControllerProvider.notifier).sec(AppDil.ar);
      expect(c.read(aktifDilKoduProvider), 'ar');
    });
  });
}

/// Testte diske yazmayan bos guvenli depo.
class _BosDepo extends FlutterSecureStorage {
  const _BosDepo();

  final Map<String, String> _kutu = const {};

  @override
  Future<String?> read({required String key, dynamic iOptions, dynamic aOptions,
      dynamic lOptions, dynamic webOptions, dynamic mOptions, dynamic wOptions}) async =>
      _kutu[key];

  @override
  Future<void> write({required String key, required String? value,
      dynamic iOptions, dynamic aOptions, dynamic lOptions, dynamic webOptions,
      dynamic mOptions, dynamic wOptions}) async {}

  @override
  Future<void> delete({required String key, dynamic iOptions, dynamic aOptions,
      dynamic lOptions, dynamic webOptions, dynamic mOptions, dynamic wOptions}) async {}
}
