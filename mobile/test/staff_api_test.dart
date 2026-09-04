import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/staff/data/staff_api.dart';

/// Taklit HTTP ADAPTER'inda (P200 dersi): govdeyi kuran katman testin
/// icinden geciyor.
class _Tel implements HttpClientAdapter {
  final istekler = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final ham = options.data;
    istekler.add(ham is Map<String, dynamic> ? Map.of(ham) : <String, dynamic>{});
    return ResponseBody.fromString(
      jsonEncode({'id': 'u-yeni'}),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('StaffMember avatar_url savunmaci parse', () {
    final s = StaffMember.fromJson(const {
      'id': 'u1', 'ad': 'Guard A', 'role': 'security',
      'is_active': true, 'avatar_url': 'https://x/a.jpg',
    });
    expect(s.avatarUrl, 'https://x/a.jpg');
    expect(
      StaffMember.fromJson(const {
        'id': 'u2', 'ad': 'B', 'role': 'security', 'is_active': true,
      }).avatarUrl,
      isNull,
    );
  });

  // =====================================================================
  // (P212-ek §2) TELEFON OPSIYONEL — COKLU TESISIN ONUNDEKI ENGELDI
  // =====================================================================
  // Telefon PLATFORM GENELINDE benzersiz; zorunlu oldugu surece ayni
  // kisi IKINCI bir tesise ancak UYDURMA bir numarayla eklenebiliyordu
  // (backend'de olculdu: telefonsuz 422, gercek numarayla 409).
  // Kimlik P197'den beri E-POSTADIR.
  test('TELEFONSUZ personel: `telefon` alani GOVDEYE KONMAZ', () async {
    final tel = _Tel();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = tel;
    await StaffApi(dio).addStaff(
        ad: 'Telefonsuz', email: 'a@b.com', role: 'security');
    expect(tel.istekler.single.containsKey('telefon'), isFalse);
    expect(tel.istekler.single['email'], 'a@b.com');
  });

  test('BOS telefon da GONDERILMEZ ("" gecersiz numara sayilirdi)', () async {
    final tel = _Tel();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = tel;
    await StaffApi(dio).addStaff(
        ad: 'Bos', email: 'a@b.com', role: 'security', telefon: '   ');
    expect(tel.istekler.single.containsKey('telefon'), isFalse);
  });

  test('TELEFON VERILIRSE gonderilir (gerileme yok)', () async {
    final tel = _Tel();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = tel;
    await StaffApi(dio).addStaff(
        ad: 'Numarali', email: 'a@b.com', role: 'security',
        telefon: '+905321112203');
    expect(tel.istekler.single['telefon'], '+905321112203');
  });

  test('avatarUrlFromUsers SAF parse', () {
    expect(avatarUrlFromUsers({'avatar_url': 'https://x/y.jpg'}),
        'https://x/y.jpg');
    expect(avatarUrlFromUsers(const {}), isNull);
  });
}
