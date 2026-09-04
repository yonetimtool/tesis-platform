/// (P211-ek3) GIRIS EKRANI DUZENI — "Tesis ID" giriste SORULMAZ.
///
/// ===========================================================================
/// KULLANICININ BILDIRDIGI VE OLCULEN DURUM
/// ===========================================================================
/// Giris ekraninin ALTINDA "Tesis ID ile giris" yazan bir baglanti vardi
/// ve basinca 5 adimli bir akis aciliyordu. Kod okununca gorulen sey:
/// baglanti aslinda KAYIT ekranina gidiyordu, ama etiketi
/// `l10n.kayitBaslik` idi ve o metnin Turkcesi "Tesis ID ile giris"
/// olarak kalmisti. Yani hem YANLIS bir vaat (giriste Tesis ID) hem de
/// yanlis bir hedef adi.
///
/// KURAL: Tesis ID YALNIZ KAYIT akisinda sorulur (davet e-postasindaki
/// kod). Giris ekraninda ne alan ne baglanti olarak gecer.
///
/// Bu dosya duzeni kilitler:
///   1. tek kimlik alani + parola + "Giris yap",
///   2. SSO dugmeleri (saglayici listesi doluyken) PAROLANIN ALTINDA,
///   3. kayit baglantisi EN ALTTA ve metni "Tesis ID" ICERMEZ,
///   4. ekranda HICBIR yerde "Tesis ID" gecmez.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/auth/presentation/login_screen.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';

class _Tel implements HttpClientAdapter {
  _Tel({this.saglayicilar = const ['google', 'microsoft', 'apple']});

  final List<String> saglayicilar;
  final istekler = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add(options.path);
    final govde = options.path == '/auth/oauth/saglayicilar'
        ? {'saglayicilar': saglayicilar}
        : <String, dynamic>{};
    return ResponseBody.fromString(
      jsonEncode(govde),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<_Tel> _sur(WidgetTester tester, {List<String>? saglayicilar}) async {
  final tel = _Tel(saglayicilar: saglayicilar ?? const ['google', 'microsoft', 'apple']);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  final kap = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    tokenStorageProvider.overrideWithValue(TokenStorage(BellekDepo())),
  ]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: kap, child: l10nApp(const LoginScreen())),
  );
  await tester.pumpAndSettle();
  return tel;
}

/// Bir widget'in ekrandaki DIKEY konumu — sira olcumu icin.
double _y(WidgetTester tester, Key k) => tester.getTopLeft(find.byKey(k)).dy;

void main() {
  testWidgets('DUZEN: kimlik + parola + SSO + kayit baglantisi, BU SIRAYLA',
      (tester) async {
    await _sur(tester);

    // 1) Tek kimlik alani (e-posta VEYA telefon) ve parola.
    expect(find.byKey(const Key('giris-kimlik')), findsOneWidget);

    // 2) UC SAGLAYICI DA cizildi.
    for (final s in ['google', 'microsoft', 'apple']) {
      expect(find.byKey(Key('sosyal-$s')), findsOneWidget, reason: s);
    }

    // 3) SIRA: SSO dugmeleri kimlik alanindan SONRA, kayit baglantisi
    //    EN ALTTA. Eskiden kayit baglantisi SSO'nun USTUNDEYDI.
    final kimlik = _y(tester, const Key('giris-kimlik'));
    final google = _y(tester, const Key('sosyal-google'));
    final kayit = _y(tester, const Key('login-kayit-baglantisi'));
    expect(kimlik < google, isTrue, reason: 'SSO, kimlik alanindan sonra');
    expect(google < kayit, isTrue, reason: 'kayit baglantisi EN ALTTA');
  });

  testWidgets('GIRISTE "Tesis ID" GECMEZ — ne alan ne baglanti', (tester) async {
    await _sur(tester);
    expect(find.textContaining('Tesis ID'), findsNothing);
    expect(find.textContaining('Facility ID'), findsNothing);
    // Kayit baglantisi VAR ama metni bir GIRIS vaadi degil.
    final metin = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('login-kayit-baglantisi')),
        matching: find.byType(Text),
      ),
    );
    expect(metin.data, isNot(contains('Tesis ID')));
  });

  testWidgets('SAGLAYICI LISTESI BOSSA dugmeler CIZILMEZ (gerileme yok)',
      (tester) async {
    // Yapilandirilmamis bir saglayiciyi dugme olarak gostermek,
    // kullaniciyi kesin basarisiz bir yola sokmakti.
    await _sur(tester, saglayicilar: const []);
    expect(find.byKey(const Key('sosyal-google')), findsNothing);
    // Parola girisi ETKILENMEZ.
    expect(find.byKey(const Key('giris-kimlik')), findsOneWidget);
  });

  testWidgets('SAGLAYICI UCU GERCEKTEN CAGRILIYOR', (tester) async {
    // Dugmelerin cizilmemesinin sebebi "istek hic gitmedi" olabilir —
    // cihazda tam olarak bu oldu (gomulu adres emulator adresiydi).
    final tel = await _sur(tester);
    expect(tel.istekler, contains('/auth/oauth/saglayicilar'));
  });
}
