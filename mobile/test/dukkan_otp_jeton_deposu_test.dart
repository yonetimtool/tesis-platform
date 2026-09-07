import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/auth/domain/token_pair.dart';
import 'package:mobile/src/features/dukkan/data/dukkan_jeton_deposu.dart';

/// (DUKKAN F7 §2) DUKKAN JETONUNUN KALICI DEPOSU — SIZINTI KILIDI.
///
/// ===========================================================================
/// NE OLCULUYOR
/// ===========================================================================
/// OTP akisinin ise yaramasi jetonun CIHAZDA KALMASINA bagli (yoksa her
/// acilista yeniden SMS). Ama "sakla" demek tek basina bir SIZINTI acar:
/// A cikis yapmadan uygulamayi oldurur, ayni telefonda B giris yapar ve
/// B, A'nin pazar yeri kimligiyle iceri girer.
///
/// Bu dosya dort seyi olcuyor:
///   1. Jeton yazilip okunuyor (akis calisiyor).
///   2. BASKA bir Yonetiyor kullanicisi okuyamiyor (sizinti kapali).
///   3. Suresi dolmus jeton yok sayiliyor.
///   4. `sil()` gercekten siliyor (cikis yolu).

String _jwt(Map<String, dynamic> claims) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${b64({'alg': 'none'})}.${b64(claims)}.imza';
}

String _dukkanJetonu({Duration omur = const Duration(days: 30)}) => _jwt({
      'sub': 'dukkan-kullanici',
      'tur': 'dukkan',
      'exp': DateTime.now().add(omur).millisecondsSinceEpoch ~/ 1000,
    });

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

  /// Yonetiyor oturumunu `kullanici` olarak kurar ve depoyu dondurur.
  Future<DukkanJetonDeposu> depo(String kullanici) async {
    const guvenli = FlutterSecureStorage();
    final yonetiyor = TokenStorage(guvenli);
    await yonetiyor.save(TokenPair(
      accessToken: _jwt({'sub': kullanici, 'tenant_id': 't-1'}),
      refreshToken: 'r',
      tokenType: 'Bearer',
      expiresIn: 900,
    ));
    return DukkanJetonDeposu(guvenli, yonetiyor);
  }

  test('JETON YAZILIR VE OKUNUR', () async {
    final d = await depo('kullanici-A');
    final j = _dukkanJetonu();
    await d.yaz(j);
    expect(await d.oku(), j);
  });

  test('BASKA KULLANICI OKUYAMAZ — sizinti kilidi', () async {
    // A jetonunu birakir ve cikis YAPMADAN uygulama olur.
    final a = await depo('kullanici-A');
    await a.yaz(_dukkanJetonu());

    // Ayni cihazda B giris yapar. Depodaki kayit HALA duruyor.
    final b = await depo('kullanici-B');
    expect(await b.oku(), isNull,
        reason: 'B, A nin Dukkan kimligiyle pazar yerine girerdi');
  });

  test('YABANCI KAYIT OKUNURKEN SILINIR', () async {
    final a = await depo('kullanici-A');
    await a.yaz(_dukkanJetonu());
    final b = await depo('kullanici-B');
    await b.oku();
    // A geri donse bile kayit artik yok: okuma sirasinda temizlendi.
    // Bu bilincli — cihazda baskasinin jetonunun DURMASI, okunamiyor
    // olsa bile gereksiz bir risktir.
    final a2 = await depo('kullanici-A');
    expect(await a2.oku(), isNull);
  });

  test('SURESI DOLMUS JETON YOK SAYILIR', () async {
    final d = await depo('kullanici-A');
    await d.yaz(_dukkanJetonu(omur: const Duration(seconds: -1)));
    expect(await d.oku(), isNull);
  });

  test('SIL gercekten siler', () async {
    final d = await depo('kullanici-A');
    await d.yaz(_dukkanJetonu());
    await d.sil();
    expect(await d.oku(), isNull);
  });

  test('YONETIYOR OTURUMU YOKSA yazilmaz', () async {
    // Sahipsiz bir jeton saklamak, bir sonraki kullaniciya devrederdi.
    const guvenli = FlutterSecureStorage();
    final d = DukkanJetonDeposu(guvenli, TokenStorage(guvenli));
    await d.yaz(_dukkanJetonu());
    expect(await d.oku(), isNull);
  });
}
