/// Kamera YONETIMI + rol gorunurlugu + oynatilabilirlik.
///
/// KRITIK IDDIA (KVKK): istemci gorunurluk suzgecini TEKRARLAMAZ. Sunucu
/// `GET /cameras`'i rol'e gore suzer; ekran gelen listeyi AYNEN cizer. Yani
/// sakin/tesis gorevlisi UI'i "gizli" bir kamerayi elemek zorunda kalmaz —
/// zaten almaz; ama alsaydi da gostermek DOGRU olurdu (sunucu dogruyu bilir).
/// Bu testler her iki tarafi da kilitler: gelen liste cizilir, istemci
/// tarafinda `sakin_gorebilir=false` kayitlari gizleyen bir "sahte guvenlik"
/// katmani YOKTUR.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/cameras/data/cameras_api.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';
import 'package:mobile/src/features/cameras/presentation/kamera_form_sheet.dart';
import 'package:mobile/src/features/cameras/presentation/kameralar_screen.dart';
import 'helpers/l10n_test_app.dart';
import 'package:mobile/src/core/i18n/locale_controller.dart';

const _hls = Camera(
  id: 'c1',
  ad: 'Ana Kapı',
  konum: 'Ana Kapı - Giriş',
  streamUrl: 'https://test/x.m3u8',
  aktif: true,
  sakinGorebilir: true,
);
const _rtsp = Camera(
  id: 'c4',
  ad: 'Arka Bahçe NVR',
  konum: 'NVR kanal 4',
  streamUrl: 'rtsp://nvr/kanal4',
  tur: CameraTur.rtsp,
  oynatilabilir: false,
);
const _gizli = Camera(
  id: 'c3',
  ad: 'Havuz',
  streamUrl: 'https://test/havuz.m3u8',
  tur: CameraTur.mp4,
  sakinGorebilir: false,
);

Widget _app(UserRole role, List<Camera> sunucuYaniti) => ProviderScope(
      overrides: [
        currentUserRoleProvider.overrideWith((ref) async => role),
        camerasProvider.overrideWith((ref) async => sunucuYaniti),
      ],
      child: l10nApp(KameralarScreen()),
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('Kameralar ekrani — rol gorunurlugu SUNUCUDAN', () {
    testWidgets('sakin: sunucunun gonderdigi 2 kamera cizilir; yonetim '
        'dugmeleri YOK', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.resident, const [_hls, _rtsp]));
      await tester.pumpAndSettle();

      expect(find.text('Ana Kapı'), findsOneWidget);
      expect(find.text('Arka Bahçe NVR'), findsOneWidget);
      // Yonetim yalniz admin/yonetici: FAB + duzenle/sil yok.
      expect(find.text('Kamera Ekle'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('tesis gorevlisi: istemci EK SUZGEC UYGULAMAZ — sunucu ne '
        'gonderdiyse o cizilir (sahte guvenlik katmani yok)', (tester) async {
      _tall(tester);
      // Sunucu (kurgusal olarak) sakin_gorebilir=false bir kayit gonderse bile
      // ekran onu ELEMEZ: gorunurluk karari SUNUCUNUNDUR.
      await tester.pumpWidget(
          _app(UserRole.tesisGorevlisi, const [_hls, _gizli]));
      await tester.pumpAndSettle();

      expect(find.text('Ana Kapı'), findsOneWidget);
      expect(find.text('Havuz'), findsOneWidget);
      expect(find.text('Kamera Ekle'), findsNothing);
    });

    testWidgets('yonetici: ekle/duzenle/sil gorunur', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.yonetici, const [_hls, _gizli]));
      await tester.pumpAndSettle();

      expect(find.text('Kamera Ekle'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    });

    testWidgets('bos liste (sakin): "Görüntülemenize açık kamera yok."',
        (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.resident, const []));
      await tester.pumpAndSettle();
      expect(find.text('Görüntülemenize açık kamera yok.'), findsOneWidget);
    });

    testWidgets('bos liste (admin): ekleme yonlendirmesi', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.admin, const []));
      await tester.pumpAndSettle();
      expect(
        find.text('Kamera tanımı yok. Sağ alttan ekleyebilirsiniz.'),
        findsOneWidget,
      );
    });

    testWidgets('RTSP karti listede KALIR ("Oynatılamıyor"), dokununca '
        'oynatici DEGIL bilgi karti acilir', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.security, const [_rtsp]));
      await tester.pumpAndSettle();

      expect(find.text('Oynatılamıyor'), findsOneWidget);
      await tester.tap(find.text('Arka Bahçe NVR'));
      await tester.pumpAndSettle();
      // Bilgi karti: tur + RTSP aciklamasi (oynatici acilmadi).
      expect(find.text('Tür: RTSP'), findsOneWidget);
      expect(
        find.textContaining('RTSP yayınlar şu an uygulama içinde'),
        findsOneWidget,
      );
    });
  });

  // NOT: dogrulama METIN DEGIL HATA TURU doner (i18n: domain katmani dil
  // bilmez); kullaniciya gosterilen metni form katmani secer.
  group('CameraDraft.urlHatasi — sunucu 422 kuralinin ISTEMCI aynasi', () {
    test('hls/mp4: http(s) zorunlu', () {
      expect(CameraDraft.urlHatasi('https://a/b.m3u8', CameraTur.hls), isNull);
      expect(CameraDraft.urlHatasi('http://a/b.mp4', CameraTur.mp4), isNull);
      expect(
        CameraDraft.urlHatasi('rtsp://a/b', CameraTur.hls),
        CameraUrlHatasi.httpSemasiGerekli,
      );
      expect(CameraDraft.urlHatasi('ftp://a/b', CameraTur.mp4),
          CameraUrlHatasi.httpSemasiGerekli);
    });

    test('rtsp: rtsp:// zorunlu', () {
      expect(CameraDraft.urlHatasi('rtsp://a/b', CameraTur.rtsp), isNull);
      expect(
        CameraDraft.urlHatasi('https://a/b.m3u8', CameraTur.rtsp),
        CameraUrlHatasi.rtspSemasiGerekli,
      );
    });

    test('bos URL: bos hata turu', () {
      expect(CameraDraft.urlHatasi('  ', CameraTur.hls), CameraUrlHatasi.bos);
    });

    test('govde: create bos konumu YAZMAZ, update ACIK null gonderir', () {
      const bosKonum = CameraDraft(
        ad: 'K',
        konum: '',
        streamUrl: 'https://a/b.m3u8',
        tur: CameraTur.hls,
        aktif: true,
        sakinGorebilir: false,
      );
      expect(bosKonum.toCreateJson().containsKey('konum'), isFalse);
      expect(bosKonum.toUpdateJson()['konum'], isNull);
      expect(bosKonum.toCreateJson()['tur'], 'hls');
      expect(bosKonum.toCreateJson()['sakin_gorebilir'], false);
    });
  });

  group('Kamera formu — istemci dogrulamasi (TR mesaj)', () {
    testWidgets('tur=HLS iken rtsp:// URL: kaydet ENGELLENIR + TR hata',
        (tester) async {
      _tall(tester);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: supportedLocales,
        localizationsDelegates: testLocalizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => KameraFormSheet.ac(context),
                child: const Text('ac'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('ac'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Ad *'), 'Test kamera');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Yayın URL\'si *'),
        'rtsp://nvr/kanal1',
      );
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(
        find.text('HLS yayın adresi http:// veya https:// ile başlamalı'),
        findsOneWidget,
      );
    });

    testWidgets('tur=RTSP secilince satir-ici uyari cikar', (tester) async {
      _tall(tester);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: supportedLocales,
        localizationsDelegates: testLocalizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => KameraFormSheet.ac(context),
                child: const Text('ac'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('ac'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('RTSP yayınlar şu an uygulama içinde'),
        findsNothing,
      );
      await tester.tap(find.text('RTSP'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('RTSP yayınlar şu an uygulama içinde'),
        findsOneWidget,
      );
    });

    testWidgets('duzenleme: alanlar mevcut kamera ile ON-DOLU', (tester) async {
      _tall(tester);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: supportedLocales,
        localizationsDelegates: testLocalizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => KameraFormSheet.ac(context, mevcut: _hls),
                child: const Text('ac'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('ac'));
      await tester.pumpAndSettle();

      expect(find.text('Kamerayı düzenle'), findsOneWidget);
      // DEGERLER controller'dan okunur: ipucu (hint) metinleri kayittaki
      // degerlerle ayni olabildigi icin metin aramasi cift eslesme verir.
      final degerler = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((f) => f.controller?.text)
          .toList();
      expect(degerler, ['Ana Kapı', 'Ana Kapı - Giriş', 'https://test/x.m3u8']);
      // "Site sakinleri görebilsin" acik gelir (kayitta true).
      final anahtar = tester.widgetList<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(anahtar.map((s) => s.value).toList(), [true, true]);
    });
  });
}
