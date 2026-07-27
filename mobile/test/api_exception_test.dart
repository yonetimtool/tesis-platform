import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/akis_hatasi.dart';
import 'package:mobile/src/core/error/api_exception.dart';

void main() {
  final req = RequestOptions(path: '/auth/login');

  group('ApiException.fromDio', () {
    test('sozlesme hata zarfini { error: { code, message } } cozer', () {
      final e = DioException(
        requestOptions: req,
        response: Response(
          requestOptions: req,
          statusCode: 401,
          data: {
            'error': {
              'code': 'invalid_credentials',
              'message': 'E-posta veya parola hatali',
            },
          },
        ),
      );

      final ex = ApiException.fromDio(e);
      expect(ex.code, 'invalid_credentials');
      expect(ex.message, 'E-posta veya parola hatali');
      expect(ex.statusCode, 401);
    });

    // TUR 13: ag hatasinda `core` artik METIN uretmez — KIMLIK tasir.
    // Metin cizim katmaninda `apiHataMetni(l10n, e)` ile uretilir; boylece
    // Arapca UI'da Turkce cumle gorunmez.
    test('baglanti hatasinda METIN degil KIMLIK uretir', () {
      final e = DioException(
        requestOptions: req,
        type: DioExceptionType.connectionError,
      );

      final ex = ApiException.fromDio(e);
      expect(ex.code, 'network_error');
      expect(ex.message, isEmpty);
      expect(ex.agHatasi, AkisHatasi.sunucuyaUlasilamadi);
    });

    test('timeout → zamanAsimi kimligi, mesaj BOS', () {
      for (final t in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final ex = ApiException.fromDio(
          DioException(requestOptions: req, type: t),
        );
        expect(ex.message, isEmpty, reason: '$t');
        expect(ex.agHatasi, AkisHatasi.zamanAsimi, reason: '$t');
      }
    });

    // Zarf VAR ama `message` yok: eskiden bos metin gosterilirdi.
    test('zarf var / mesaj yok → beklenmeyen kimligi', () {
      final ex = ApiException.fromDio(DioException(
        requestOptions: req,
        response: Response(
          requestOptions: req,
          statusCode: 500,
          data: {
            'error': {'code': 'server_error'}
          },
        ),
      ));
      expect(ex.code, 'server_error');
      expect(ex.message, isEmpty);
      expect(ex.agHatasi, AkisHatasi.beklenmeyen);
    });
  });

  group('ApiException.kind (tiplenmis hata)', () {
    test('baglanti hatasi → network', () {
      final ex = ApiException.fromDio(
        DioException(
          requestOptions: req,
          type: DioExceptionType.connectionError,
        ),
      );
      expect(ex.kind, ApiErrorKind.network);
    });

    test('401 invalid_credentials → auth', () {
      const ex = ApiException(
        code: 'invalid_credentials',
        message: 'Hatali',
        statusCode: 401,
      );
      expect(ex.kind, ApiErrorKind.auth);
    });

    test('403 forbidden → auth', () {
      const ex = ApiException(
        code: 'forbidden',
        message: 'Yetkisiz',
        statusCode: 403,
      );
      expect(ex.kind, ApiErrorKind.auth);
    });

    test('422 validation_error → api', () {
      const ex = ApiException(
        code: 'validation_error',
        message: 'Gecersiz alan',
        statusCode: 422,
      );
      expect(ex.kind, ApiErrorKind.api);
    });
  });
}
