import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
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

    test('baglanti hatasinda anlamli mesaj uretir', () {
      final e = DioException(
        requestOptions: req,
        type: DioExceptionType.connectionError,
      );

      final ex = ApiException.fromDio(e);
      expect(ex.code, 'network_error');
      expect(ex.message, contains('ulaşılamadı'));
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
