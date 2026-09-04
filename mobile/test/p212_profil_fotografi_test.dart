/// (P212 §2) PROFIL FOTOGRAFI — yukleme, kaldirma, BAS HARFLER, hata.
///
/// ===========================================================================
/// OLCULEN DURUM
/// ===========================================================================
/// Uc noktayi ayri ayri olctum:
///
///   1. SUNUCU + ISTEMCI API KATMANI CALISIYOR. Dev API'ye gercek istek
///      gonderildi: presign 200 -> presigned PUT 200 -> `PATCH /me/avatar`
///      200 -> `GET /me` avatar_url dolu -> `PATCH {avatar_key: null}` 200
///      -> `GET /me` avatar_url null. Ayni akis mobil `AvatarApi` SINIFIYLA
///      da surulup gecti. Yani "kaldirilamiyor" sikayetinin sebebi bu
///      katman DEGIL.
///
///   2. EKRAN HATAYI YUTUYORDU. `myAvatarUrlProvider` her hatayi
///      `null`a ceviriyordu; sonuc "fotograf yok" gibi gorunuyor,
///      "Kaldir" dugmesi GIZLENIYOR ve kullaniciya hicbir sey
///      soylenmiyordu. Artik hata yukari cikar ve ekranda gorunur.
///
///   3. FOTOGRAF YOKKEN BAS HARF YOKTU: genel bir silüet ciziliyordu
///      (web'de bas harf ZATEN vardi — iki yuzey ayrisiyordu).
///
/// Taklit HTTP ADAPTER'inda (P200 dersi): govdeyi ve baslıklari kuran
/// katman testin icinden geciyor.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/core/widgets/bas_harf_avatar.dart';
import 'package:mobile/src/features/profile/data/avatar_api.dart';

import 'helpers/l10n_test_app.dart';

class _Tel implements HttpClientAdapter {
  _Tel({this.avatarUrl, this.meDurumu = 200});

  String? avatarUrl;
  final int meDurumu;
  final istekler = <({String yol, String metot, Object? govde})>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add((yol: options.path, metot: options.method, govde: options.data));
    if (options.path == '/me') {
      if (meDurumu != 200) {
        return ResponseBody.fromString('{}', meDurumu, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
      }
      return _json({'avatar_url': avatarUrl});
    }
    if (options.path == '/uploads/presign') {
      return _json({
        'foto_key': 't-1/tasks/abc.jpg',
        'upload_url': 'https://storage.test/tesis-foto/t-1/tasks/abc.jpg?imza=1',
        'method': 'PUT',
        'expires_in': 900,
      });
    }
    if (options.path == '/me/avatar') {
      final govde = options.data as Map<String, dynamic>;
      avatarUrl = govde['avatar_key'] == null
          ? null
          : 'https://storage.test/${govde['avatar_key']}?imza=2';
      return _json({'avatar_url': avatarUrl});
    }
    return _json(const {});
  }

  ResponseBody _json(Object govde) => ResponseBody.fromString(
        jsonEncode(govde),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

({ProviderContainer kap, _Tel tel}) _kur({String? avatarUrl, int meDurumu = 200}) {
  final tel = _Tel(avatarUrl: avatarUrl, meDurumu: meDurumu);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  final kap = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
  addTearDown(kap.dispose);
  return (kap: kap, tel: tel);
}

void main() {
  // ======================= BAS HARFLER ================================== //

  test('BAS HARFLER: iki kelime, tek kelime, Turkce `i`', () {
    expect(basHarfler('Kerem Yonetici'), 'KY');
    expect(basHarfler('  Ayse   Kiraci  '), 'AK');
    // Tek kelimede ILK IKI harf: tek harf iki kisiyi ayirt etmeye zayif.
    expect(basHarfler('Kurum'), 'KU');
    // Turkce buyutme: `i` -> `İ` (Dart'in toUpperCase()'i bunu yapmaz).
    expect(basHarfler('ismail Arslan'), 'İA');
    expect(basHarfler('   '), '');
  });

  test('RENK ADDAN TURETILIR ve KARARLIDIR', () {
    // Ayni kisi her acilista ayni rengi alir; rastgele olsaydi "hesap
    // degisti mi?" sorusu her yenilemede yeniden sorulurdu.
    expect(adTonu('Kerem Yonetici'), adTonu('Kerem Yonetici'));
    expect(adTonu('Kerem Yonetici'), isNot(adTonu('Ayse Kiraci')));
  });

  testWidgets('FOTOGRAF YOKSA bas harfler CIZILIR (silüet DEGIL)',
      (tester) async {
    await tester.pumpWidget(
      l10nApp(const Center(child: BasHarfAvatar(ad: 'Kerem Yonetici'))),
    );
    expect(find.text('KY'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);
  });

  testWidgets('FOTOGRAF VARSA harf DEGIL gorsel cizilir', (tester) async {
    await tester.pumpWidget(l10nApp(Center(
      child: BasHarfAvatar(
        ad: 'Kerem Yonetici',
        url: 'https://storage.test/x.jpg',
        // Ag istegi YAPILMAZ: gorsel saglayici gecersiz kilindi.
        // 1x1 saydam PNG — gercek bir goruntu, cozucu hata vermesin.
        gorsel: MemoryImage(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
        )),
      ),
    )));
    expect(find.text('KY'), findsNothing);
  });

  // ======================= YUKLEME / KALDIRMA =========================== //

  test('YUKLEME: presign -> PUT -> PATCH zinciri ve GIDEN GOVDE', () async {
    final (kap: kap, tel: tel) = _kur();
    final api = kap.read(avatarApiProvider);

    final bilet = await api.presignUpload(contentType: 'image/jpeg');
    expect(bilet.fotoKey, 't-1/tasks/abc.jpg');
    final url = await api.setAvatar(bilet.fotoKey);
    expect(url, contains('t-1/tasks/abc.jpg'));

    final presign = tel.istekler.firstWhere((i) => i.yol == '/uploads/presign');
    expect((presign.govde as Map)['content_type'], 'image/jpeg');
    final patch = tel.istekler.firstWhere((i) => i.yol == '/me/avatar');
    expect(patch.metot, 'PATCH');
    expect((patch.govde as Map)['avatar_key'], 't-1/tasks/abc.jpg');
  });

  test('KALDIRMA: govdede `avatar_key: null` GIDER ve url BOSALIR', () async {
    // Kritik: `null` govdeden DUSMEMELI — dusseydi sunucu alani
    // "degistirme" diye yorumlar ve fotograf DURURDU.
    final (kap: kap, tel: tel) = _kur(avatarUrl: 'https://storage.test/eski.jpg');
    final api = kap.read(avatarApiProvider);

    final sonuc = await api.setAvatar(null);
    expect(sonuc, isNull);

    final patch = tel.istekler.firstWhere((i) => i.yol == '/me/avatar');
    final govde = patch.govde as Map;
    expect(govde.containsKey('avatar_key'), isTrue);
    expect(govde['avatar_key'], isNull);
    // Sunucu durumu da bosaldi.
    expect(await api.fetchMyAvatarUrl(), isNull);
  });

  test('HATA YUTULMAZ: /me basarisizsa saglayici HATA verir', () async {
    // Eski hâl her hatayi `null`a ceviriyordu: ekran "fotograf yok"
    // gibi gorunuyor, "Kaldir" gizleniyor, kullaniciya hicbir sey
    // soylenmiyordu.
    final (kap: kap, tel: _) = _kur(meDurumu: 500);
    await expectLater(
      kap.read(myAvatarUrlProvider.future),
      throwsA(isA<DioException>()),
    );
  });
}
