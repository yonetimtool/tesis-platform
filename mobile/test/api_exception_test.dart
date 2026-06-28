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
      expect(ex.message, contains('ulasilamadi'));
    });
  });
}
