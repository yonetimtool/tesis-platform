/// (P247 §3) KARGO VE ZIYARETCI "BEKLIYOR"DA KALIYORDU — mobil yuzey.
///
/// Taklit HTTP adapter'inda: ekran -> denetleyici -> api -> TEL UZERINDEKI
/// GOVDE. Olculen kusurlar:
///   * Guvenlikte kargo "Teslim et" dugmesi YOKTU (sunucu da 403 veriyordu);
///     sakin isaretlemezse kayit sonsuza dek bekliyordu.
///   * Ziyaretci modeli `cikis_zamani`ni OKUMUYORDU ve cikis dugmesi yoktu:
///     guvenligin "N iceride" sayaci yalnizca artiyordu.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/kargo/presentation/kargo_screen.dart';
import 'package:mobile/src/features/visitors/presentation/visitors_screen.dart';
import 'package:mobile/src/routing/app_router.dart';
import 'package:mobile/src/routing/push_yonlendirme.dart';

import 'helpers/l10n_test_app.dart';

/// Istekleri kaydeden taklit adapter. Liste uclari sabit doner; PATCH/POST
/// govdesi kaydedilir ve sunucunun dondurecegi kayit taklit edilir.
class _Tel implements HttpClientAdapter {
  _Tel({this.kargolar = const [], this.ziyaretciler = const []});

  List<Map<String, dynamic>> kargolar;
  List<Map<String, dynamic>> ziyaretciler;
  final istekler = <(String, String, Object?)>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add((o.method, o.path, o.data));
    Object govde;
    var kod = 200;
    if (o.path == '/kargo' && o.method == 'GET') {
      govde = {
        'meta': {'limit': 200, 'offset': 0, 'total': kargolar.length},
        'items': kargolar,
      };
    } else if (o.path.startsWith('/kargo/') && o.method == 'PATCH') {
      final veri = o.data as Map<String, dynamic>;
      kargolar = [
        for (final k in kargolar)
          k['id'] == o.path.split('/').last
              ? {
                  ...k,
                  'durum': 'teslim_alindi',
                  'teslim_alan_user_id': veri['teslim_alan_user_id'],
                  'teslim_eden_ad': 'Ali Guvenlik',
                  'gecikmis': false,
                }
              : k,
      ];
      govde = kargolar.first;
    } else if (o.path.startsWith('/units/by-no/')) {
      govde = [
        {'user_id': 'r-1', 'ad': 'Can Kiraci'},
        {'user_id': 'r-2', 'ad': 'Zeynep Malik'},
      ];
    } else if (o.path == '/visitors' && o.method == 'GET') {
      govde = {
        'meta': {'limit': 200, 'offset': 0, 'total': ziyaretciler.length},
        'items': ziyaretciler,
      };
    } else if (o.path.endsWith('/checkout') && o.method == 'POST') {
      final id = o.path.split('/')[2];
      ziyaretciler = [
        for (final v in ziyaretciler)
          v['id'] == id ? {...v, 'cikis_zamani': '2026-09-24T10:00:00Z'} : v,
      ];
      govde = ziyaretciler.firstWhere((v) => v['id'] == id);
    } else {
      kod = 404;
      govde = {
        'error': {'code': 'not_found', 'message': 'yok'},
      };
    }
    return ResponseBody.fromString(
      jsonEncode(govde),
      kod,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _kargo(
  String id, {
  String durum = 'bekliyor',
  bool gecikmis = false,
  String? teslimEdenAd,
}) => {
  'id': id,
  'unit_id': 'u-1',
  'unit_no': 'A-1',
  'firma': 'Yurtici $id',
  'durum': durum,
  'kaydeden_user_id': 'g-1',
  'kaydeden_ad': 'Ali Guvenlik',
  'teslim_eden_ad': teslimEdenAd,
  'teslim_zamani': durum == 'bekliyor' ? null : '2026-09-24T09:00:00Z',
  'gecikmis': gecikmis,
  'created_at': '2026-09-20T09:00:00Z',
};

Map<String, dynamic> _ziyaretci(
  String id, {
  String? cikis,
  bool otomatik = false,
}) => {
  'id': id,
  'unit_id': 'u-1',
  'unit_no': 'A-1',
  'ziyaretci_ad': 'Misafir $id',
  'kaydeden_user_id': 'g-1',
  'kaydeden_ad': 'Ali Guvenlik',
  'target_resident_user_id': 'r-1',
  'target_resident_ad': 'Can Kiraci',
  'cikis_zamani': cikis,
  'cikis_otomatik': otomatik,
  'created_at': '2026-09-24T08:00:00Z',
};

Future<_Tel> _sur(WidgetTester tester, UserRole rol, Widget ekran, _Tel tel) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = tel;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        currentUserRoleProvider.overrideWith((ref) async => rol),
      ],
      child: l10nApp(ekran),
    ),
  );
  await tester.pumpAndSettle();
  return tel;
}

Future<void> _dokun(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  group('KARGO — guvenlik teslim eder', () {
    testWidgets('secilen sakin PATCH govdesine girer; kart teslim sekmesine gecer',
        (tester) async {
      final tel = await _sur(
        tester,
        UserRole.security,
        const KargoScreen(),
        _Tel(kargolar: [_kargo('k1')]),
      );
      await _dokun(tester, find.text('Teslim et'));
      // Sakin secici dairenin AKTIF sakinlerini listeler.
      expect(find.text('Kargoyu kime teslim ettiniz?'), findsOneWidget);
      await _dokun(tester, find.text('Zeynep Malik'));

      final patch = tel.istekler.where((i) => i.$1 == 'PATCH').single;
      expect(patch.$2, '/kargo/k1');
      expect(patch.$3, {'durum': 'teslim_alindi', 'teslim_alan_user_id': 'r-2'});
      // Liste tazelendi: bekleyen yok, "teslim eden" satiri teslim sekmesinde.
      expect(find.text('Teslim et'), findsNothing);
      await _dokun(tester, find.text('Teslim alınan (1)'));
      expect(find.textContaining('teslim eden: Ali Guvenlik'), findsOneWidget);
    });

    testWidgets('"Sakin belirtmeden": teslim_alan_user_id govdeye HIC yazilmaz',
        (tester) async {
      final tel = await _sur(
        tester,
        UserRole.security,
        const KargoScreen(),
        _Tel(kargolar: [_kargo('k1')]),
      );
      await _dokun(tester, find.text('Teslim et'));
      await _dokun(tester, find.text('Sakin belirtmeden'));
      final patch = tel.istekler.where((i) => i.$1 == 'PATCH').single;
      expect(patch.$3, {'durum': 'teslim_alindi'});
    });

    testWidgets('sakin "Teslim aldım" der: govdede yalniz durum', (tester) async {
      final tel = await _sur(
        tester,
        UserRole.resident,
        const KargoScreen(),
        _Tel(kargolar: [_kargo('k1')]),
      );
      expect(find.text('Teslim et'), findsNothing);
      await _dokun(tester, find.text('Teslim aldım'));
      final patch = tel.istekler.where((i) => i.$1 == 'PATCH').single;
      expect(patch.$3, {'durum': 'teslim_alindi'});
    });

    for (final rol in [UserRole.yonetici, UserRole.admin]) {
      testWidgets('${rol.name}: teslim dugmesi YOK', (tester) async {
        await _sur(tester, rol, const KargoScreen(), _Tel(kargolar: [_kargo('k1')]));
        expect(find.text('Teslim et'), findsNothing);
        expect(find.text('Teslim aldım'), findsNothing);
      });
    }

    testWidgets('sunucu gecikmis=true dediginde "Gecikmiş" rozeti', (tester) async {
      await _sur(
        tester,
        UserRole.security,
        const KargoScreen(),
        _Tel(kargolar: [_kargo('k1', gecikmis: true), _kargo('k2')]),
      );
      expect(find.text('Gecikmiş'), findsOneWidget);
    });
  });

  group('ZIYARETCI — cikis', () {
    testWidgets('guvenlik "Çıkış yaptı" -> POST /visitors/{id}/checkout, rozet Çıktı',
        (tester) async {
      final tel = await _sur(
        tester,
        UserRole.security,
        const VisitorsScreen(),
        _Tel(ziyaretciler: [_ziyaretci('v1')]),
      );
      expect(find.text('İçeride'), findsOneWidget);
      await _dokun(tester, find.text('Çıkış yaptı'));
      // Onay penceresi — ikinci "Çıkış yaptı" onay dugmesidir.
      expect(find.text('Ziyaretçi çıkışı kaydedilsin mi?'), findsOneWidget);
      await _dokun(tester, find.widgetWithText(FilledButton, 'Çıkış yaptı'));

      final post = tel.istekler.where((i) => i.$1 == 'POST').single;
      expect(post.$2, '/visitors/v1/checkout');
      expect(post.$3, isNull); // govde YOK
      expect(find.text('Çıktı'), findsOneWidget);
      expect(find.text('Çıkış yaptı'), findsNothing);
    });

    testWidgets('sunucunun kapattigi kayit "Çıkış kaydedilmedi"; dugme yok',
        (tester) async {
      await _sur(
        tester,
        UserRole.security,
        const VisitorsScreen(),
        _Tel(ziyaretciler: [
          _ziyaretci('v1', cikis: '2026-09-24T09:00:00Z', otomatik: true),
        ]),
      );
      expect(find.text('Çıkış kaydedilmedi'), findsWidgets);
      expect(find.text('Çıkış yaptı'), findsNothing);
    });

    testWidgets('sakin durumu gorur ama cikis dugmesi YOK', (tester) async {
      await _sur(
        tester,
        UserRole.resident,
        const VisitorsScreen(),
        _Tel(ziyaretciler: [_ziyaretci('v1')]),
      );
      expect(find.text('İçeride'), findsOneWidget);
      expect(find.text('Çıkış yaptı'), findsNothing);
    });
  });

  test('push "kargo_teslim" ayni kargo kaydina derin baglanir', () {
    expect(
      pushHedefi({'tip': 'kargo_teslim', 'kargo_id': 'k9'}, UserRole.resident),
      '${AppRoutes.kargo}?kargo_id=k9',
    );
  });
}
