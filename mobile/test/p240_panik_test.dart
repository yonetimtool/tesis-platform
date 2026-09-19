/// (P240 §1) PANIK BUTONU — MOBIL YUZEY.
///
/// =========================================================================
/// NE OLCULUYOR
/// =========================================================================
///   1. ROL KAPISI: her rol YALNIZ tetikleyebildigi tipleri gorur.
///   2. IPTAL PENCERESI: geri sayim cizilir, iptal istegi gider ve
///      SAYIM BITINCE ISTEMCI IKINCI ISTEK ATMAZ (yayin sunucunun isi).
///   3. YASAL UYARI dugmelerden ONCE.
///   4. TAM EKRAN ALARM: GERI TUSU KAPATMAZ; yalniz gordum/gidiyorum.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/panik/data/panik_api.dart';
import 'package:mobile/src/features/panik/domain/panik_models.dart';
import 'package:mobile/src/features/panik/presentation/panik_gozcusu.dart';
import 'package:mobile/src/features/panik/presentation/panik_sayfasi.dart';

import 'helpers/l10n_test_app.dart';

class _SahtePanikApi extends PanikApi {
  _SahtePanikApi({this.aktif = const []}) : super(Dio());

  final List<PanikAlarm> aktif;
  final List<String> cagrilar = [];
  String iptalDurumu = 'iptal';

  PanikAlarm _alarm({String durum = 'beklemede'}) => PanikAlarm(
        id: 'p1',
        tip: 'sakin',
        durum: durum,
        iptalPenceresiSn: 5,
      );

  @override
  Future<PanikAlarm> tetikle(
    PanikTip tip, {
    PanikKategori? kategori,
    double? gpsLat,
    double? gpsLng,
    String? checkpointId,
    String? aciklama,
  }) async {
    // (P243 §5c) KATEGORI de kaydedilir: hangi talimatin gidecegini o
    // belirliyor ve testler bunu olcebilmeli.
    cagrilar.add('tetikle:${tip.kimlik}:${kategori?.kimlik ?? "-"}');
    return _alarm();
  }

  @override
  Future<PanikAlarm> iptal(String id) async {
    cagrilar.add('iptal');
    return _alarm(durum: iptalDurumu);
  }

  @override
  Future<PanikAlarm> gordum(String id) async {
    cagrilar.add('gordum');
    return _alarm(durum: 'acik');
  }

  @override
  Future<PanikAlarm> mudahale(String id) async {
    cagrilar.add('mudahale');
    return _alarm(durum: 'mudahale');
  }

  @override
  Future<List<PanikAlarm>> aktifler() async {
    cagrilar.add('aktifler');
    return aktif;
  }

  @override
  Future<List<PanikAlarm>> liste({int limit = 50}) async => const [];
}

Widget _sayfa(_SahtePanikApi api, UserRole rol) => ProviderScope(
      overrides: [
        panikApiProvider.overrideWithValue(api),
        currentUserRoleProvider.overrideWith((ref) async => rol),
      ],
      child: l10nApp(const PanikSayfasi()),
    );

Widget _gozcu(_SahtePanikApi api) => ProviderScope(
      overrides: [
        panikApiProvider.overrideWithValue(api),
        // OTURUM SART: gozcu, giris ekranindayken yoklama YAPMAZ
        // (bos yere 401 uretmesin ve acilista bitmeyen bir is
        // baslatmasin diye).
        currentUserIdProvider.overrideWith((ref) async => 'ben'),
      ],
      child: l10nApp(
        PanikGozcusu(child: const Scaffold(body: Text('altta ne varsa'))),
      ),
    );

void main() {
  group('1) ROL KAPISI', () {
    testWidgets('SAKIN yalniz "evde acil durum"u gorur', (tester) async {
      await tester.pumpWidget(_sayfa(_SahtePanikApi(), UserRole.resident));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('panik-tip-sakin')), findsOneWidget);
      // Site geneline anons YAPAMAZ; dugmeyi gostermek, basinca 403
      // alacagi bir yol sunmak olurdu.
      expect(find.byKey(const Key('panik-tip-yonetici_anons')), findsNothing);
      expect(find.byKey(const Key('panik-tip-guvenlik')), findsNothing);
    });

    testWidgets('GUVENLIK yalniz "guvenlik acili"ni gorur', (tester) async {
      await tester.pumpWidget(_sayfa(_SahtePanikApi(), UserRole.security));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('panik-tip-guvenlik')), findsOneWidget);
      expect(find.byKey(const Key('panik-tip-sakin')), findsNothing);
    });

    testWidgets('YONETICI ikisini gorur, SAKIN PANIGINI gormez',
        (tester) async {
      // Yoneticinin dairesi yoktur; onun actigi sakin panigi gidilecek
      // ADRES tasimazdi (sunucu da 403 verir).
      await tester.pumpWidget(_sayfa(_SahtePanikApi(), UserRole.yonetici));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('panik-tip-guvenlik')), findsOneWidget);
      expect(find.byKey(const Key('panik-tip-yonetici_anons')), findsOneWidget);
      expect(find.byKey(const Key('panik-tip-sakin')), findsNothing);
    });

    testWidgets('DENETCI hicbir dugme gormez, ACIKCA soylenir', (tester) async {
      // Bos bir ekran "yukleniyor mu, bozuk mu" sorusunu dogururdu.
      await tester.pumpWidget(_sayfa(_SahtePanikApi(), UserRole.denetci));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('panik-yetki-yok')), findsOneWidget);
    });
  });

  group('2) IPTAL PENCERESI', () {
    testWidgets('YASAL UYARI dugmelerden ONCE cizilir', (tester) async {
      // "112 yerine gecmez" cumlesi alarmi BASTIKTAN SONRA
      // gosterilseydi en kritik anda okunmazdi.
      await tester.pumpWidget(_sayfa(_SahtePanikApi(), UserRole.resident));
      await tester.pumpAndSettle();
      final uyari = tester.getTopLeft(find.byKey(const Key('panik-yasal'))).dy;
      final dugme =
          tester.getTopLeft(find.byKey(const Key('panik-tip-sakin'))).dy;
      expect(uyari, lessThan(dugme));
      expect(
        (tester.widget<Text>(find.byKey(const Key('panik-yasal'))).data ?? ''),
        contains('112'),
      );
    });

    testWidgets('TETIKLE -> geri sayim; IPTAL -> istek gider', (tester) async {
      final api = _SahtePanikApi();
      await tester.pumpWidget(_sayfa(api, UserRole.resident));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('panik-tip-sakin')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('panik-geri-sayim')), findsOneWidget);
      expect(api.cagrilar, ['tetikle:sakin:-']);

      await tester.tap(find.byKey(const Key('panik-iptal')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(api.cagrilar, ['tetikle:sakin:-', 'iptal']);
    });

    testWidgets('SAYIM BITINCE ISTEMCI IKINCI ISTEK ATMAZ', (tester) async {
      // Yayin sunucudaki gecikmeli gorevin isi. Istemciye baglamak,
      // uygulama kapaninca alarmin HIC gitmemesi demekti.
      final api = _SahtePanikApi();
      await tester.pumpWidget(_sayfa(api, UserRole.resident));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('panik-tip-sakin')));
      await tester.pump();

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(api.cagrilar, ['tetikle:sakin:-'],
          reason: 'ikinci istek ATILMAMALI');
    });
  });

  group('3) TAM EKRAN ALARM', () {
    final gelen = PanikAlarm(
      id: 'a1',
      tip: 'sakin',
      durum: 'acik',
      iptalPenceresiSn: 5,
      olusturanAd: 'Ayşe Yılmaz',
      daireNo: '12',
      blok: 'A',
      son24sYanlisAlarm: 2,
    );

    testWidgets('ALARM VARSA ekrani kaplar ve ALTTAKI icerigi orter',
        (tester) async {
      final api = _SahtePanikApi(aktif: [gelen]);
      await tester.pumpWidget(_gozcu(api));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('panik-tam-ekran')), findsOneWidget);
      expect(find.byKey(const Key('panik-alarm-kim')), findsOneWidget);
      expect(find.text('A 12'), findsOneWidget);
      expect(find.byKey(const Key('panik-alarm-yanlis-sayaci')), findsOneWidget);
    });

    testWidgets('GERI TUSU KAPATMAZ', (tester) async {
      // Android'de geri tusu refleks hareketidir; uyariyi kapatmasi
      // "kapatilamaz" iddiasini bos birakirdi.
      final api = _SahtePanikApi(aktif: [gelen]);
      await tester.pumpWidget(_gozcu(api));
      await tester.pumpAndSettle();

      final kapsam = tester.widget<PopScope>(
        find.ancestor(
          of: find.byKey(const Key('panik-tam-ekran')),
          matching: find.byType(PopScope),
        ),
      );
      expect(kapsam.canPop, isFalse);
    });

    testWidgets('GIDIYORUM istegi sunucuya gider', (tester) async {
      final api = _SahtePanikApi(aktif: [gelen]);
      await tester.pumpWidget(_gozcu(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('panik-mudahale')));
      await tester.pump();
      expect(api.cagrilar, contains('mudahale'));
    });

    testWidgets('ALARM YOKSA hicbir katman cizilmez', (tester) async {
      final api = _SahtePanikApi(aktif: const []);
      await tester.pumpWidget(_gozcu(api));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('panik-tam-ekran')), findsNothing);
      expect(find.text('altta ne varsa'), findsOneWidget);
    });
  });

  group('4) ROL -> TIP ESLEMESI (SAF)', () {
    test('sunucudaki TETIKLEYEBILIR tablosunun AYNASI', () {
      expect(tetiklenebilirTipler(UserRole.resident), [PanikTip.sakin]);
      expect(tetiklenebilirTipler(UserRole.security), [PanikTip.guvenlik]);
      expect(tetiklenebilirTipler(UserRole.guvenlikAmiri), [PanikTip.guvenlik]);
      expect(tetiklenebilirTipler(UserRole.tesisGorevlisi), [PanikTip.guvenlik]);
      expect(tetiklenebilirTipler(UserRole.yonetici),
          [PanikTip.guvenlik, PanikTip.yoneticiAnons]);
      expect(tetiklenebilirTipler(UserRole.admin),
          [PanikTip.guvenlik, PanikTip.yoneticiAnons]);
      // Denetci SALT-OKUMA mali gozetim rolu: sahada degil.
      expect(tetiklenebilirTipler(UserRole.denetci), isEmpty);
    });
  });
}
