import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/auth/domain/token_pair.dart';

/// (P170 §1) "BENI HATIRLA" — PAROLA NEREDE DURUYOR VE NE ZAMAN SILINIYOR.
///
/// =========================================================================
/// BU TEST NE OLCER
/// =========================================================================
/// 1. Isaretliyse telefon + parola saklanir ve ON-DOLDURMA icin geri okunur.
/// 2. Isaretsizse HICBIR SEY saklanmaz — ve onceden saklanan da SILINIR.
/// 3. Cikis saklanan kimlik bilgisini TEMIZLER (P170'te degisen davranis;
///    once bilerek birakiliyordu).
/// 4. Parola yalniz `flutter_secure_storage` kanalina gider. Bu kanal
///    iOS'ta Keychain, Android'de Keystore destekli EncryptedSharedPrefs
///    kullanir; testte kanal taklit edildigi icin dogrulanan sey KANALIN
///    KENDISIDIR — yani parolanin duz `SharedPreferences`a ya da baska bir
///    yere yazilmadigi.
///
/// OLCMEZ: isletim sisteminin sifrelemesinin gucunu. O platformun isi ve
/// birim testiyle dogrulanamaz; dogrulanan sey DOGRU KAPIYA gidildigidir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final store = <String, String>{};
  final yazilanKanallar = <String>{};
  const guvenliKanal =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const tercihKanali = MethodChannel('plugins.flutter.io/shared_preferences');

  setUp(() {
    store.clear();
    yazilanKanallar.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(guvenliKanal, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      switch (call.method) {
        case 'write':
          yazilanKanallar.add('guvenli');
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
    // SharedPreferences'a yazilirsa YAKALANIR — testin asil kirmizi cizgisi.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tercihKanali, (call) async {
      if (call.method.startsWith('set')) yazilanKanallar.add('tercih');
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(guvenliKanal, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(tercihKanali, null);
  });

  TokenStorage depo() => TokenStorage(const FlutterSecureStorage());

  test('isaretli: telefon + parola saklanir ve geri okunur', () async {
    final d = depo();
    await d.saveCredentials(phone: '05551112233', password: 'Parola1234');

    final okunan = await d.readCredentials();
    expect(okunan, isNotNull);
    expect(okunan!.phone, '05551112233');
    expect(okunan.password, 'Parola1234');
  });

  test('parola YALNIZ guvenli depo kanalina yazilir', () async {
    await depo().saveCredentials(phone: '05551112233', password: 'Parola1234');

    expect(yazilanKanallar, contains('guvenli'));
    // SharedPreferences'a TEK BIR yazma bile olmamali.
    expect(yazilanKanallar, isNot(contains('tercih')));
  });

  test('isaretsiz: onceden saklanan da SILINIR', () async {
    final d = depo();
    await d.saveCredentials(phone: '05551112233', password: 'Parola1234');
    // Kullanici kutuyu kaldirip yeniden giriyor.
    await d.clearCredentials();

    expect(await d.readCredentials(), isNull);
  });

  test('CIKIS saklanan kimlik bilgisini temizler', () async {
    final d = depo();
    await d.save(const TokenPair(
      accessToken: 'a',
      refreshToken: 'r',
      tokenType: 'Bearer',
      expiresIn: 900,
    ));
    await d.saveRememberMe(true);
    await d.saveCredentials(phone: '05551112233', password: 'Parola1234');

    // `AuthRepositoryImpl.logout` bu ikisini cagirir.
    await d.clear();
    await d.clearCredentials();

    expect(await d.readCredentials(), isNull);
    expect(await d.readAccessToken(), isNull);
    expect(await d.readRememberMe(), isFalse);
    // Depoda parolayi andiran HICBIR deger kalmamali.
    expect(store.values, isNot(contains('Parola1234')));
  });

  test('eksik alan tam sayilmaz: yalniz telefon varsa on-doldurma YOK',
      () async {
    final d = depo();
    await d.saveCredentials(phone: '05551112233', password: '');

    // Yarim bir kayit, parola alanini bos birakip kullaniciyi
    // "kaydedilmis ama calismiyor" durumunda birakirdi.
    expect(await d.readCredentials(), isNull);
  });
}
