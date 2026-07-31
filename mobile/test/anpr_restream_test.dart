/// P17 — RESTREAM (RTSP kamerayi oynatilabilir yapar) + PLAKA OKUMALARI.
///
/// Iki ayri is, tek dosyada cunku ikisi de P16'nin sunucu tarafinin mobil
/// karsiligidir:
///
///  1. RESTREAM — P15'te olculdu: Frigate/go2rtc'nin yeniden yayini gercekten
///     oynatilabilir (h264 1280x720). Kamera kaydi opsiyonel bir
///     `restream_url` kazandi; DOLU ise `oynatilabilir` true olur ve oynatici
///     ONU calar. Kameranin KENDI adresi (`stream_url`) KORUNUR.
///  2. PLAKA OKUMALARI — ANPR olay defteri + dusuk guvenli okumalarin onay
///     kuyrugu.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/features/anpr/data/anpr_api.dart';
import 'package:mobile/src/features/anpr/domain/anpr_models.dart';
import 'package:mobile/src/features/anpr/presentation/anpr_screen.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

// --------------------------------------------------------------------------
// 1) RESTREAM — kamera modeli
// --------------------------------------------------------------------------
Camera _kamera(Map<String, dynamic> ek) => Camera.fromJson({
  'id': 'c1',
  'ad': 'Ana Kapı',
  'stream_url': 'rtsp://10.0.0.5:554/stream1',
  'tur': 'rtsp',
  'aktif': true,
  'sakin_gorebilir': false,
  ...ek,
});

void main() {
  group('RESTREAM — model', () {
    test('restreamsiz rtsp OYNATILAMAZ (davranis degismedi)', () {
      final k = _kamera({'oynatilabilir': false});
      expect(k.oynatilabilir, isFalse);
      expect(k.restreamUrl, isNull);
      expect(k.oynatilacakUrl, 'rtsp://10.0.0.5:554/stream1');
      expect(k.restreamUzerinden, isFalse);
    });

    test('restream VARSA rtsp oynatilabilir ve GECIT calinir', () {
      final k = _kamera({
        'restream_url': 'https://gecit/api/kapi/stream.m3u8',
        'oynatilabilir': true,
      });
      expect(k.oynatilabilir, isTrue);
      expect(k.oynatilacakUrl, 'https://gecit/api/kapi/stream.m3u8');
      expect(k.restreamUzerinden, isTrue);
      // Kameranin KENDI adresi KORUNUR — gecit bozulunca kaybolmasin.
      expect(k.streamUrl, 'rtsp://10.0.0.5:554/stream1');
    });

    test('sunucu `oynatilabilir` GONDERMEZSE yerelde ayni kural uygulanir', () {
      // Eski sunucuya karsi geri dusus: alan yoksa restream'e bakilir.
      final gecitli = _kamera({'restream_url': 'https://g/stream.m3u8'});
      expect(gecitli.oynatilabilir, isTrue);
      final gecitsiz = _kamera(const {});
      expect(gecitsiz.oynatilabilir, isFalse);
    });

    test('hls kamera restreamsiz da oynatilabilir', () {
      final k = Camera.fromJson({
        'id': 'c2',
        'ad': 'Havuz',
        'stream_url': 'https://x/s.m3u8',
        'tur': 'hls',
        'aktif': true,
        'sakin_gorebilir': true,
      });
      expect(k.oynatilabilir, isTrue);
      expect(k.oynatilacakUrl, 'https://x/s.m3u8');
      expect(k.restreamUzerinden, isFalse, reason: 'hls gecit uzerinden degil');
    });

    test('restream dogrulamasi: YALNIZ http(s)', () {
      expect(CameraDraft.restreamHatasi(null), isNull);
      expect(CameraDraft.restreamHatasi(''), isNull);
      expect(CameraDraft.restreamHatasi('https://g/s.m3u8'), isNull);
      expect(CameraDraft.restreamHatasi('http://g/s.m3u8'), isNull);
      // rtsp gecit adresi "oynatilabilir isaretli ama OYNAMAYAN" kamera
      // uretirdi — tam da bu ozelligin cozdugu sorunu geri getirirdi.
      expect(
        CameraDraft.restreamHatasi('rtsp://g:8554/kapi'),
        CameraUrlHatasi.httpSemasiGerekli,
      );
    });

    test('draft govdesi: bos restream OLUSTURMADA yazilmaz, PATCH te null', () {
      const bos = CameraDraft(
        ad: 'A',
        streamUrl: 'rtsp://x/s',
        tur: CameraTur.rtsp,
        aktif: true,
        sakinGorebilir: false,
        restreamUrl: '',
      );
      expect(bos.toCreateJson().containsKey('restream_url'), isFalse);
      // PATCH'te ACIK null: gecit KALDIRILIR (sunucu sozlesmesi).
      expect(bos.toUpdateJson()['restream_url'], isNull);

      const dolu = CameraDraft(
        ad: 'A',
        streamUrl: 'rtsp://x/s',
        tur: CameraTur.rtsp,
        aktif: true,
        sakinGorebilir: false,
        restreamUrl: 'https://g/s.m3u8',
      );
      expect(dolu.toCreateJson()['restream_url'], 'https://g/s.m3u8');
    });
  });

  // ------------------------------------------------------------------------
  // 2) PLAKA OKUMALARI
  // ------------------------------------------------------------------------
  group('ANPR — model', () {
    test('cozumleme + guven yuzdesi + onay bayragi', () {
      final o = AnprOlay.fromJson({
        'id': 'e1',
        'kaynak': 'frigate',
        'kaynak_olay_id': '178.1-a',
        'plaka': '34ABC123',
        'zaman': '2026-07-31T10:00:00Z',
        'kamera': 'kapi',
        'yon': 'bilinmiyor',
        'guven': 0.412,
        'durum': 'onay_bekliyor',
        'durum_nedeni': 'dusuk_guven',
        'created_at': '2026-07-31T10:00:01Z',
      });
      expect(o.plaka, '34ABC123');
      expect(o.yon, AnprYon.bilinmiyor);
      expect(o.durum, AnprDurum.onayBekliyor);
      expect(o.onayBekliyor, isTrue);
      expect(o.guvenYuzde, 41);
      expect(o.vehiclePassId, isNull, reason: 'onay bekleyen olay gecis ACMAZ');
    });

    test('guven YOKSA yuzde de yok (uydurma sayi uretilmez)', () {
      final o = AnprOlay.fromJson({
        'id': 'e2',
        'kaynak': 'dahua',
        'kaynak_olay_id': 'x',
        'plaka': '06XY99',
        'zaman': '2026-07-31T10:00:00Z',
        'durum': 'islendi',
        'created_at': '2026-07-31T10:00:00Z',
      });
      expect(o.guven, isNull);
      expect(o.guvenYuzde, isNull);
    });

    test('bilinmeyen durum/yon savunmasi', () {
      expect(AnprDurum.fromWire('gelecekte_eklenen'), AnprDurum.islendi);
      expect(AnprYon.fromWire(null), AnprYon.bilinmiyor);
    });
  });

  group('ANPR — neden KODU cevirisi', () {
    testWidgets('bilinen kodlar cevrilir, BILINMEYEN kod GOSTERILMEZ', (
      tester,
    ) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        l10nApp(
          Builder(
            builder: (ctx) {
              l10n = ctx.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(anprNedenAdi(l10n, 'dusuk_guven'), 'Düşük güven');
      expect(anprNedenAdi(l10n, 'zaten_iceride'), 'Araç zaten içeride');
      // Ham kodu kullaniciya basmak ceviri BOSLUGUNU gizlemek olurdu.
      expect(anprNedenAdi(l10n, 'gelecekte_eklenen_kod'), isNull);
      expect(anprNedenAdi(l10n, null), isNull);
    });
  });

  group('ANPR — ekran', () {
    testWidgets('onay bekleyen okumada Onayla/Reddet VAR', (tester) async {
      final api = _SahteAnprApi(items: [_olay()]);
      await tester.pumpWidget(_ekran(UserRole.security, api));
      await tester.pumpAndSettle();
      expect(find.text('34ABC123'), findsOneWidget);
      expect(find.text('Onay bekliyor'), findsWidgets);
      expect(find.text('Düşük güven'), findsOneWidget);
      expect(find.text('Onayla'), findsOneWidget);
      expect(find.text('Reddet'), findsOneWidget);
    });

    testWidgets('ISLENMIS okumada karar dugmesi YOK', (tester) async {
      final api = _SahteAnprApi(
        items: [_olay(durum: AnprDurum.islendi, neden: null)],
      );
      await tester.pumpWidget(_ekran(UserRole.security, api));
      await tester.pumpAndSettle();
      expect(find.text('Onayla'), findsNothing);
      expect(find.text('Reddet'), findsNothing);
    });

    testWidgets('ONAY: plaka duzeltilerek gonderilir', (tester) async {
      final api = _SahteAnprApi(items: [_olay()]);
      await tester.pumpWidget(_ekran(UserRole.admin, api));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Onayla'));
      await tester.pumpAndSettle();
      // OCR duzeltmesi: bir karakter degistirilir.
      await tester.enterText(find.byType(TextField), '34ABC124');
      // Iki "Onayla" dugmesi var: kartinki ve DIYALOGUNKI. Diyalog en son
      // acildigi icin `.last` dogru hedeftir.
      await tester.tap(find.widgetWithText(FilledButton, 'Onayla').last);
      await tester.pumpAndSettle();
      expect(api.kararlar, [('e1', true, '34ABC124')]);
    });

    testWidgets('RED: plaka gonderilmez', (tester) async {
      final api = _SahteAnprApi(items: [_olay()]);
      await tester.pumpWidget(_ekran(UserRole.admin, api));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reddet'));
      await tester.pumpAndSettle();
      expect(api.kararlar, [('e1', false, null)]);
    });

    testWidgets('409: "artik onay beklemiyor" gosterilir', (tester) async {
      final api = _SahteAnprApi(items: [_olay()])
        ..kararHatasi = const ApiException(
          code: 'conflict',
          message: '',
          statusCode: 409,
        );
      await tester.pumpWidget(_ekran(UserRole.admin, api));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reddet'));
      await tester.pumpAndSettle();
      expect(find.text('Bu okuma artık onay beklemiyor'), findsOneWidget);
    });

    testWidgets('403: aciklayici bos durum (hata bandi degil)', (tester) async {
      final api = _SahteAnprApi(
        listeHatasi: const ApiException(
          code: 'forbidden',
          message: '',
          statusCode: 403,
        ),
      );
      await tester.pumpWidget(_ekran(UserRole.yonetici, api));
      await tester.pumpAndSettle();
      expect(
        find.text('Plaka okumaları yalnız yönetim ve güvenlik içindir'),
        findsOneWidget,
      );
    });

    testWidgets('bos liste', (tester) async {
      await tester.pumpWidget(_ekran(UserRole.security, _SahteAnprApi()));
      await tester.pumpAndSettle();
      expect(find.text('Plaka okuma kaydı yok'), findsOneWidget);
    });

    testWidgets('plaka okumalari (bes eksen)', (tester) async {
      final api = _SahteAnprApi(
        items: [
          _olay(),
          _olay(
            id: 'e2',
            durum: AnprDurum.islendi,
            neden: null,
            plaka: '06XY99',
          ),
          _olay(id: 'e3', durum: AnprDurum.hata, neden: 'anpr_plaka_bicimi'),
        ],
      );
      await tumEksenlerSurusu(
        tester,
        (dil) => _ekran(UserRole.admin, api, locale: Locale(dil)),
        veri: const {'34ABC123', '06XY99', 'kapi'},
      );
    });
  });
}

// --------------------------------------------------------------------------
// Sahte uc
// --------------------------------------------------------------------------
class _SahteAnprApi extends AnprApi {
  _SahteAnprApi({this.items = const [], this.listeHatasi}) : super(Dio());

  final List<AnprOlay> items;
  final ApiException? listeHatasi;
  final kararlar = <(String, bool, String?)>[];
  ApiException? kararHatasi;

  @override
  Future<List<AnprOlay>> fetchAll({AnprDurum? durum, String? plaka}) async {
    if (listeHatasi != null) throw listeHatasi!;
    return items.where((o) => durum == null || o.durum == durum).toList();
  }

  @override
  Future<AnprOlay> onayla(
    String id, {
    required bool onay,
    String? plaka,
  }) async {
    if (kararHatasi != null) throw kararHatasi!;
    kararlar.add((id, onay, plaka));
    return items.firstWhere((o) => o.id == id);
  }
}

AnprOlay _olay({
  String id = 'e1',
  String plaka = '34ABC123',
  AnprDurum durum = AnprDurum.onayBekliyor,
  String? neden = 'dusuk_guven',
}) => AnprOlay(
  id: id,
  kaynak: 'frigate',
  kaynakOlayId: '178.1-$id',
  plaka: plaka,
  zaman: DateTime.utc(2026, 7, 31, 10),
  kamera: 'kapi',
  yon: AnprYon.bilinmiyor,
  guven: durum == AnprDurum.onayBekliyor ? 0.41 : 0.97,
  durum: durum,
  durumNedeni: neden,
  vehiclePassId: durum == AnprDurum.islendi ? 'vp1' : null,
  createdAt: DateTime.utc(2026, 7, 31, 10),
);

Widget _ekran(
  UserRole rol,
  _SahteAnprApi api, {
  Locale locale = const Locale('tr'),
}) => ProviderScope(
  overrides: [
    anprApiProvider.overrideWithValue(api),
    currentUserRoleProvider.overrideWith((ref) async => rol),
  ],
  child: l10nApp(const AnprScreen(), locale: locale),
);
