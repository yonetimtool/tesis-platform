/// (E2E 2026-09, MOBIL-10) Web ikizi iki yonetici ekrani: DAVETLER ve
/// GURULTU UYARILARI.
///
/// Taklit HTTP adapter'inda (P200 dersi). Olculen: durum etiketleri web
/// ile AYNI ayrimi yapiyor mu, "yeniden gonder" / "anons yapildi" dogru
/// uca gidiyor mu ve dugmeler yalniz anlamli satirda mi.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/davetler/data/davet_yonetim_api.dart';
import 'package:mobile/src/features/davetler/presentation/davetler_screen.dart';
import 'package:mobile/src/features/gurultu/presentation/gurultu_uyarilari_screen.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';

import 'helpers/l10n_test_app.dart';

class _Tel implements HttpClientAdapter {
  _Tel(this.getler);

  final Map<String, Object> getler;
  final postlar = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object govde;
    if (options.method == 'POST') {
      postlar.add(options.path);
      govde = <String, dynamic>{};
    } else {
      govde = getler[options.path] ??
          {
            'error': {'code': 'not_found', 'message': 'yok'},
          };
    }
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

Map<String, dynamic> _davet(
  String id, {
  String? durum,
  String? hata,
  String? used,
}) =>
    {
      'user_id': id,
      'ad': 'Kisi $id',
      'rol': 'resident',
      'telefon': '+90532000000$id',
      'daire_no': 'A-$id',
      'son_kanal': 'eposta',
      'son_durum': durum,
      'son_hata': hata,
      'son_gonderim_at': '2026-09-20T10:00:00Z',
      'used_at': used,
      'son_gecerlilik': '2026-10-20T10:00:00Z',
    };

Future<_Tel> _sur(
  WidgetTester tester,
  Widget ekran,
  Map<String, Object> getler,
) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  final tel = _Tel(getler);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = tel;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: l10nApp(ekran),
    ),
  );
  await tester.pumpAndSettle();
  return tel;
}

void main() {
  group('DAVETLER', () {
    test('durum eslemesi web durumBilgisi ile AYNI', () {
      DavetDurumu d(String? durum, {String? hata, String? used}) =>
          davetDurumu(DavetSatiri.fromJson(
              _davet('1', durum: durum, hata: hata, used: used)));
      expect(d('gonderildi', used: '2026-09-21T10:00:00Z'),
          DavetDurumu.kaydoldu);
      expect(d('basarisiz', hata: 'bounce'), DavetDurumu.geriDondu);
      expect(d('basarisiz', hata: 'smtp_hata'), DavetDurumu.gitmedi);
      expect(d('yapilandirilmadi'), DavetDurumu.ayarYok);
      expect(d('okundu'), DavetDurumu.acildi);
      expect(d('iletildi'), DavetDurumu.iletildi);
      expect(d('gonderildi'), DavetDurumu.gonderildi);
      expect(d(null), DavetDurumu.bekliyor);
    });

    testWidgets('etiketler + tesis kodu + yeniden gonder dogru uca gider',
        (tester) async {
      final tel = await _sur(tester, const DavetlerScreen(), {
        '/davet': {
          'tesis_kodu': 'OLTU-260715',
          'items': [
            _davet('1', durum: 'iletildi'),
            _davet('2', durum: 'okundu'),
            _davet('3', durum: 'basarisiz', hata: 'bounce'),
            _davet('4', durum: 'yapilandirilmadi'),
            _davet('5', durum: 'gonderildi', used: '2026-09-21T10:00:00Z'),
          ],
        },
      });
      expect(find.text('İletildi'), findsOneWidget);
      expect(find.text('Açıldı'), findsOneWidget);
      expect(find.text('Geri döndü'), findsOneWidget);
      expect(find.text('E-posta ayarı yok'), findsOneWidget);
      expect(find.text('Kaydoldu'), findsOneWidget);
      expect(find.text('OLTU-260715'), findsOneWidget);
      // Geri donmede SEBEP gorunur.
      expect(find.text('bounce'), findsOneWidget);
      // Kaydolmus kisiye yeniden gonder dugmesi YOK.
      expect(find.byKey(const Key('davet-yeniden-5')), findsNothing);

      await tester.tap(find.byKey(const Key('davet-yeniden-3')));
      await tester.pumpAndSettle();
      expect(tel.postlar, ['/davet/3/yeniden']);
      expect(find.text('Davet yeniden gönderildi.'), findsOneWidget);
    });

    testWidgets('bos liste -> bos durum', (tester) async {
      await _sur(tester, const DavetlerScreen(), {
        '/davet': {'tesis_kodu': null, 'items': <Object>[]},
      });
      expect(find.text('Henüz davet yok.'), findsOneWidget);
    });
  });

  group('GURULTU UYARILARI', () {
    Map<String, dynamic> u(String id, String durum) => {
          'id': id,
          'unit_id': 'un-$id',
          'unit_no': 'B-$id',
          'esik': 3,
          'sayac': 4,
          'kanal': 'manuel',
          'durum': durum,
          'created_at': '2026-09-20T21:30:00Z',
        };

    testWidgets('durum etiketleri + "Anons yapildi" YALNIZ bekleyende',
        (tester) async {
      final tel = await _sur(tester, const GurultuUyarilariScreen(), {
        '/unit-uyarilari': {
          'meta': {'limit': 200, 'offset': 0, 'total': 2},
          'items': [u('1', 'manuel_bekliyor'), u('2', 'gonderildi')],
        },
      });
      expect(find.text('B-1'), findsOneWidget);
      expect(find.textContaining('Sayaç: 4/3'), findsNWidgets(2));
      expect(find.textContaining('Anons bekliyor'), findsOneWidget);
      expect(find.byKey(const Key('gurultu-yapildi-2')), findsNothing);

      await tester.tap(find.byKey(const Key('gurultu-yapildi-1')));
      await tester.pumpAndSettle();
      expect(tel.postlar, ['/unit-uyarilari/1/yapildi']);
      expect(find.text('Uyarı işaretlendi.'), findsOneWidget);
    });

    testWidgets('bos liste -> bos durum', (tester) async {
      await _sur(tester, const GurultuUyarilariScreen(), {
        '/unit-uyarilari': {
          'meta': {'limit': 200, 'offset': 0, 'total': 0},
          'items': <Object>[],
        },
      });
      expect(find.text('Uyarı yok'), findsOneWidget);
    });
  });

  test('MENU: iki giris YALNIZ yoneticide (admin panelden yonetir)', () {
    for (final rol in UserRole.values) {
      final menu = homeMenuForRole(rol);
      final beklenen = rol == UserRole.yonetici;
      expect(menu.contains(HomeMenuEntry.davetler), beklenen, reason: '$rol');
      expect(menu.contains(HomeMenuEntry.gurultuUyarilari), beklenen,
          reason: '$rol');
    }
  });
}
