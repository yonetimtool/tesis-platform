/// (P253 A1) Dokumanlar (yonetim), takvim + hatirlatmalar, sakin makbuzlari.
///
/// Taklit HTTP ADAPTORUNDE: istek govdesini kuran katman da olculur
/// (yukleme uc adimi, gorunurluk govdesi, hatirlatma govdesi). Silme
/// onaylari HEDEFIN ADINI soyler.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/dokumanlar/data/dokuman_api.dart';
import 'package:mobile/src/features/dokumanlar/data/dokuman_yonetim_api.dart';
import 'package:mobile/src/features/dokumanlar/presentation/dokuman_screen.dart';
import 'package:mobile/src/features/dokumanlar/presentation/dokuman_yonetim_screen.dart';
import 'package:mobile/src/features/dues/data/makbuz_api.dart';
import 'package:mobile/src/features/dues/presentation/makbuzlar_screen.dart';
import 'package:mobile/src/features/takvim/data/takvim_api.dart';
import 'package:mobile/src/features/takvim/presentation/takvim_screen.dart';
import 'package:mobile/src/features/tasks/presentation/task_complete_controller.dart'
    show imagePickerProvider;

import 'helpers/l10n_test_app.dart';

class _Istek {
  _Istek(this.metot, this.yol, this.govde);
  final String metot;
  final String yol;
  final Object? govde;
}

class _Adaptor implements HttpClientAdapter {
  final istekler = <_Istek>[];
  final yanitlar = <String, Object>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    var govde = o.data;
    if (govde is Stream) govde = '<akis>';
    istekler.add(_Istek(o.method, o.uri.path, govde));
    final y = yanitlar['${o.method} ${o.uri.path}'];
    if (y is Uint8List) {
      return ResponseBody.fromBytes(y, 200);
    }
    return ResponseBody.fromString(
      jsonEncode(y ?? <String, dynamic>{}),
      o.method == 'DELETE' ? 204 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  Iterable<_Istek> yap(String metot, String yol) =>
      istekler.where((i) => i.metot == metot && i.yol == yol);
}

class _Secici extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async =>
      XFile.fromData(Uint8List.fromList(List<int>.filled(2048, 7)),
          name: 'plan.jpg', path: '/tmp/plan.jpg', mimeType: 'image/jpeg');
}

Map<String, dynamic> _dok({bool acik = false}) => {
      'id': 'd-1',
      'ad': 'Yönetim planı',
      'obje_anahtari': 'k',
      'boyut_bayt': 4096,
      'created_at': '2026-10-01T09:00:00Z',
      'sakine_acik': acik,
    };

(Dio, _Adaptor) _dio() {
  final a = _Adaptor();
  return (Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = a, a);
}

Widget _uygulama(Widget ekran, Dio dio, {UserRole rol = UserRole.yonetici}) => ProviderScope(
      overrides: [
        dokumanYonetimApiProvider.overrideWithValue(DokumanYonetimApi(dio, depoDio: dio)),
        dokumanApiProvider.overrideWithValue(DokumanApi(dio)),
        takvimApiProvider.overrideWithValue(TakvimApi(dio)),
        makbuzApiProvider.overrideWithValue(MakbuzApi(dio, depoDio: dio)),
        imagePickerProvider.overrideWithValue(_Secici()),
        currentUserRoleProvider.overrideWith((ref) async => rol),
      ],
      child: l10nApp(ekran),
    );

void main() {
  group('Dokumanlar — yonetim', () {
    testWidgets('rol ayrimi: yonetici yonetim ekranini, sakin kendi listesini gorur',
        (tester) async {
      final (dio, a) = _dio();
      a.yanitlar['GET /dokumanlar'] = {'meta': {'total': 1}, 'items': [_dok()]};
      a.yanitlar['GET /me/dokumanlar'] = {'meta': {'total': 0}, 'items': []};
      await tester.pumpWidget(_uygulama(const DokumanlarGirisi(), dio));
      await tester.pumpAndSettle();
      expect(find.byType(DokumanYonetimScreen), findsOneWidget);
      expect(a.yap('GET', '/dokumanlar'), isNotEmpty);
      expect(a.yap('GET', '/me/dokumanlar'), isEmpty);
    });

    testWidgets('rol ayrimi: sakin YONETIM ucuna dokunmaz', (tester) async {
      final (dio2, a2) = _dio();
      a2.yanitlar['GET /me/dokumanlar'] = {'meta': {'total': 0}, 'items': []};
      await tester.pumpWidget(_uygulama(const DokumanlarGirisi(), dio2, rol: UserRole.resident));
      await tester.pumpAndSettle();
      expect(find.byType(DokumanScreen), findsOneWidget);
      expect(a2.yap('GET', '/dokumanlar'), isEmpty, reason: 'sakin yonetim ucuna DOKUNMAZ');
    });

    testWidgets('sakine ac: PATCH govdesi yalniz gorunurluk', (tester) async {
      final (dio, a) = _dio();
      a.yanitlar['GET /dokumanlar'] = {'meta': {'total': 1}, 'items': [_dok()]};
      a.yanitlar['PATCH /dokumanlar/d-1'] = _dok(acik: true);
      await tester.pumpWidget(_uygulama(const DokumanYonetimScreen(), dio));
      await tester.pumpAndSettle();
      expect(find.textContaining('Yalnız yönetim'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dok-menu-d-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sakinlere aç'));
      await tester.pumpAndSettle();
      expect(a.yap('PATCH', '/dokumanlar/d-1').single.govde, {'sakine_acik': true});
    });

    testWidgets('sil: onay HEDEFIN ADINI soyler; vazgecince istek yok, onayla DELETE',
        (tester) async {
      final (dio, a) = _dio();
      a.yanitlar['GET /dokumanlar'] = {'meta': {'total': 1}, 'items': [_dok()]};
      await tester.pumpWidget(_uygulama(const DokumanYonetimScreen(), dio));
      await tester.pumpAndSettle();
      Future<void> silMenusu() async {
        await tester.tap(find.byKey(const Key('dok-menu-d-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sil').last);
        await tester.pumpAndSettle();
      }

      await silMenusu();
      final onay = find.byKey(const Key('dok-sil-onay'));
      expect(find.descendant(of: onay, matching: find.textContaining('Yönetim planı')), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(a.yap('DELETE', '/dokumanlar/d-1'), isEmpty);

      await silMenusu();
      await tester.tap(find.descendant(of: onay, matching: find.text('Sil')));
      await tester.pumpAndSettle();
      expect(a.yap('DELETE', '/dokumanlar/d-1'), hasLength(1));
    });

    testWidgets('yukle: bilet -> depoya PUT -> kayit (govde ayrintili)', (tester) async {
      final (dio, a) = _dio();
      a.yanitlar['POST /uploads/presign'] = {
        'foto_key': 't/belge/abc.jpg',
        'upload_url': 'http://depo/yukle',
        'method': 'PUT',
        'expires_in': 300,
      };
      a.yanitlar['POST /dokumanlar'] = _dok();
      await tester.pumpWidget(_uygulama(
        Builder(builder: (c) => const Scaffold(body: DokumanYukleFormu())),
        dio,
      ));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('dok-gonder'))).onPressed,
        isNull,
        reason: 'dosya secilmeden yukleme yok',
      );
      await tester.tap(find.byKey(const Key('dok-galeri')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dok-secilen')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('dok-ad')), 'Karar defteri sayfası');
      await tester.tap(find.byKey(const Key('dok-sakine-acik')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dok-gonder')));
      await tester.pumpAndSettle();

      final sira = a.istekler.map((i) => '${i.metot} ${i.yol}').toList();
      expect(sira, ['POST /uploads/presign', 'PUT /yukle', 'POST /dokumanlar']);
      expect(a.yap('POST', '/uploads/presign').single.govde,
          {'content_type': 'image/jpeg', 'dosya_adi': 'plan.jpg'});
      expect(a.yap('POST', '/dokumanlar').single.govde, {
        'ad': 'Karar defteri sayfası',
        'obje_anahtari': 't/belge/abc.jpg',
        'icerik_tipi': 'image/jpeg',
        'boyut_bayt': 2048,
        'aciklama': null,
        'sakine_acik': true,
      });
    });
  });

  group('Takvim + hatirlatmalar', () {
    void takvimYanitlari(_Adaptor a) {
      final simdi = DateTime.now();
      a.yanitlar['GET /takvim'] = {
        'items': [
          {
            'tip': 'hatirlatma',
            'id': 'h-1',
            'baslik': 'Asansör bakımcısını ara',
            'baslangic': DateTime(simdi.year, simdi.month, 10, 14).toUtc().toIso8601String(),
          },
          {
            'tip': 'aidat',
            'id': 'a-1',
            'baslik': 'Ekim aidatı',
            'baslangic': DateTime(simdi.year, simdi.month, 15, 9).toUtc().toIso8601String(),
          },
        ],
      };
      a.yanitlar['GET /hatirlatmalar'] = [
        {
          'id': 'h-1',
          'baslik': 'Asansör bakımcısını ara',
          'baslangic': DateTime(simdi.year, simdi.month, 10, 14).toUtc().toIso8601String(),
          'renk': 'mavi',
          'tekrar': 'haftalik',
          'created_at': '2026-10-01T00:00:00Z',
        },
      ];
    }

    testWidgets('ay gorunumu alti kaynagi tek listede, ay penceresiyle ister', (tester) async {
      final (dio, a) = _dio();
      takvimYanitlari(a);
      await tester.pumpWidget(_uygulama(const TakvimScreen(), dio));
      await tester.pumpAndSettle();
      expect(find.text('Asansör bakımcısını ara'), findsOneWidget);
      expect(find.text('Ekim aidatı'), findsOneWidget);
      final istek = a.istekler.firstWhere((i) => i.yol == '/takvim');
      expect(istek.metot, 'GET');
      await tester.tap(find.byKey(const Key('hat-sonraki-ay')));
      await tester.pumpAndSettle();
      expect(a.yap('GET', '/takvim').length, 2, reason: 'sonraki ay yeni pencere ister');
    });

    testWidgets('ekle: POST govdesi; bos baslikla kaydet pasif', (tester) async {
      final (dio, a) = _dio();
      takvimYanitlari(a);
      a.yanitlar['POST /hatirlatmalar'] = (a.yanitlar['GET /hatirlatmalar']! as List).first;
      await tester.pumpWidget(_uygulama(const TakvimScreen(), dio));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('hat-ekle')));
      await tester.pumpAndSettle();
      final kaydet = find.byKey(const Key('hat-kaydet'));
      expect(tester.widget<FilledButton>(kaydet).onPressed, isNull);
      await tester.enterText(find.byKey(const Key('hat-baslik')), 'Kurul toplantısı');
      await tester.pumpAndSettle();
      await tester.tap(kaydet);
      await tester.pumpAndSettle();
      final govde = a.yap('POST', '/hatirlatmalar').single.govde! as Map;
      expect(govde['baslik'], 'Kurul toplantısı');
      expect(govde['tekrar'], 'yok');
      expect(govde['renk'], 'mavi');
      expect(DateTime.parse(govde['baslangic'] as String).isUtc, isTrue);
    });

    testWidgets('sil: Hatirlatmalarim sekmesinden; onay basligi soyler; DELETE',
        (tester) async {
      final (dio, a) = _dio();
      takvimYanitlari(a);
      await tester.pumpWidget(_uygulama(const TakvimScreen(), dio));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hatırlatmalarım'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Her hafta'), findsOneWidget);
      await tester.tap(find.byKey(const Key('hat-h-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('hat-sil')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
            of: find.byKey(const Key('hat-sil-onay')),
            matching: find.textContaining('Asansör bakımcısını ara')),
        findsOneWidget,
      );
      await tester.tap(find.descendant(
          of: find.byKey(const Key('hat-sil-onay')), matching: find.text('Sil')));
      await tester.pumpAndSettle();
      expect(a.yap('DELETE', '/hatirlatmalar/h-1'), hasLength(1));
    });

    testWidgets('takvimdeki hatirlatmaya dokunmak KAYDIN KENDISINI duzenler (PATCH)',
        (tester) async {
      final (dio, a) = _dio();
      takvimYanitlari(a);
      a.yanitlar['PATCH /hatirlatmalar/h-1'] = (a.yanitlar['GET /hatirlatmalar']! as List).first;
      await tester.pumpWidget(_uygulama(const TakvimScreen(), dio));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asansör bakımcısını ara'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('hat-baslik')), 'Asansör firmasını ara');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('hat-kaydet')));
      await tester.pumpAndSettle();
      final govde = a.yap('PATCH', '/hatirlatmalar/h-1').single.govde! as Map;
      expect(govde['baslik'], 'Asansör firmasını ara');
      expect(govde['tekrar'], 'haftalik', reason: 'mevcut tekrar korunur');
    });
  });

  group('Makbuzlarim', () {
    testWidgets('liste + PDF paylas depodan indirir; PDF yoksa dugme pasif', (tester) async {
      final (dio, a) = _dio();
      a.yanitlar['GET /me/makbuzlar'] = {
        'meta': {'total': 2},
        'items': [
          {
            'id': 'm-1',
            'belge_no': 'MKB-2026-0001',
            'tutar_kurus': 125000,
            'created_at': '2026-09-30T10:00:00Z',
            'pdf_url': 'http://depo/makbuz.pdf',
          },
          {
            'id': 'm-2',
            'belge_no': 'MKB-2026-0002',
            'tutar_kurus': 5000,
            'created_at': '2026-09-29T10:00:00Z',
          },
        ],
      };
      a.yanitlar['GET /makbuz.pdf'] = Uint8List.fromList(utf8.encode('%PDF-1.4'));
      await tester.pumpWidget(_uygulama(const MakbuzlarScreen(), dio, rol: UserRole.resident));
      await tester.pumpAndSettle();
      expect(find.text('Makbuz MKB-2026-0001'), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byKey(const Key('mkb-paylas-m-2'))).onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('mkb-paylas-m-1')));
      // "Hazirlaniyor" penceresi doner (spinner) — pumpAndSettle bitmez;
      // indirme istegi gidene kadar pompala. Paylas menusu platform
      // kanali oldugundan testte acilmaz; olculen sey DEPODAN indirme.
      for (var i = 0; i < 10 && a.yap('GET', '/makbuz.pdf').isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(a.yap('GET', '/makbuz.pdf'), hasLength(1));
      expect(find.byKey(const Key('paylas-hazirlaniyor')), findsOneWidget);
    });
  });
}
