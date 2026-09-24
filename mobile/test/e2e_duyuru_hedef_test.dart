/// (E2E 2026-09, BILDIRIM-12) DUYURU HEDEF KITLESI — mobil form + rozet.
///
/// Taklit HTTP adapter'inda: form -> denetleyici -> api -> TEL UZERINDEKI
/// GOVDE. Olculen: secilen blok/sakin tipi POST govdesine giriyor mu,
/// personel-yalniz secimde gizli suzgec govdeden temizleniyor mu, rozet
/// yalniz yonetimde ve yalniz hedefli duyuruda mi.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/announcements/domain/announcement_models.dart';
import 'package:mobile/src/features/announcements/presentation/announcements_screen.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';

import 'helpers/l10n_test_app.dart';

class _Tel implements HttpClientAdapter {
  _Tel(this.liste);

  final List<Map<String, dynamic>> liste;
  final postlar = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object govde;
    if (options.path == '/blocks') {
      govde = {
        'items': [
          {'id': 'b1', 'ad': 'A', 'unit_sayisi': 3},
          {'id': 'b2', 'ad': 'B', 'unit_sayisi': 2},
        ],
      };
    } else if (options.path == '/announcements' && options.method == 'POST') {
      postlar.add(Map.of(options.data as Map<String, dynamic>));
      govde = {..._duyuru('yeni'), ...(options.data as Map)};
    } else if (options.path == '/announcements') {
      govde = {
        'meta': {'limit': 200, 'offset': 0, 'total': liste.length},
        'items': liste,
      };
    } else {
      govde = {
        'error': {'code': 'not_found', 'message': 'yok'},
      };
    }
    return ResponseBody.fromString(
      jsonEncode(govde),
      options.path == '/announcements' && options.method == 'POST' ? 201 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _duyuru(String id, {Map<String, dynamic> ek = const {}}) =>
    {
      'id': id,
      'baslik': 'Baslik $id',
      'govde': 'Govde',
      'olusturan_user_id': 'u-1',
      'olusturan_ad': 'Yonetici',
      'created_at': '2026-09-01T10:00:00Z',
      'updated_at': '2026-09-01T10:00:00Z',
      ...ek,
    };

Future<_Tel> _sur(
  WidgetTester tester, {
  UserRole rol = UserRole.yonetici,
  List<Map<String, dynamic>> liste = const [],
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  final tel = _Tel(liste);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = tel;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        currentUserRoleProvider.overrideWith((ref) async => rol),
      ],
      child: l10nApp(const AnnouncementsScreen()),
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

Future<void> _formuAcVeDoldur(WidgetTester tester) async {
  await _dokun(tester, find.byType(FloatingActionButton));
  await tester.enterText(find.byType(TextFormField).at(0), 'Su kesintisi');
  await tester.enterText(find.byType(TextFormField).at(1), 'Yarin 10-12');
  // Hedef bolumu KAPALI baslar (en sik hal "herkes").
  expect(find.byKey(const Key('duyuru-hedef-security')), findsNothing);
  await _dokun(tester, find.byKey(const Key('duyuru-hedef')));
}

void main() {
  testWidgets('hedefsiz gonderim: bos listeler = HERKES', (tester) async {
    final tel = await _sur(tester);
    await _dokun(tester, find.byType(FloatingActionButton));
    await tester.enterText(find.byType(TextFormField).at(0), 'Su');
    await tester.enterText(find.byType(TextFormField).at(1), 'Kesinti');
    await _dokun(tester, find.text('Yayınla'));
    expect(tel.postlar.single, {
      'baslik': 'Su',
      'govde': 'Kesinti',
      'hedef_roller': <String>[],
      'hedef_sakin_tipi': null,
      'hedef_bloklar': <String>[],
    });
  });

  testWidgets('secilen BLOK + SAKIN TIPI POST govdesine girer',
      (tester) async {
    final tel = await _sur(tester);
    await _formuAcVeDoldur(tester);
    await _dokun(tester, find.byKey(const Key('duyuru-blok-A')));
    await _dokun(tester, find.byKey(const Key('duyuru-sakin-tipi')));
    await _dokun(tester, find.text('Yalnız malikler').last);
    await _dokun(tester, find.text('Yayınla'));
    expect(tel.postlar.single['hedef_bloklar'], ['A']);
    expect(tel.postlar.single['hedef_sakin_tipi'], 'malik');
    expect(tel.postlar.single['hedef_roller'], <String>[]);
  });

  testWidgets('YALNIZ PERSONEL secilince blok/sakin tipi GIZLENIR ve '
      'govdeden TEMIZLENIR', (tester) async {
    final tel = await _sur(tester);
    await _formuAcVeDoldur(tester);
    await _dokun(tester, find.byKey(const Key('duyuru-blok-A')));
    await _dokun(tester, find.byKey(const Key('duyuru-hedef-security')));
    expect(find.byKey(const Key('duyuru-blok-A')), findsNothing);
    expect(find.byKey(const Key('duyuru-sakin-tipi')), findsNothing);
    await _dokun(tester, find.text('Yayınla'));
    expect(tel.postlar.single['hedef_roller'], ['security']);
    expect(tel.postlar.single['hedef_bloklar'], <String>[]);
    expect(tel.postlar.single['hedef_sakin_tipi'], isNull);
  });

  testWidgets('ROZET: yonetimde yalniz HEDEFLI duyuruda', (tester) async {
    await _sur(tester, liste: [
      _duyuru('h1', ek: {
        'hedef_roller': <String>[],
        'hedef_bloklar': ['A'],
        'hedef_sakin_tipi': 'malik',
      }),
      _duyuru('h2'),
    ]);
    expect(find.byKey(const Key('duyuru-hedef-rozet-h1')), findsOneWidget);
    expect(find.byKey(const Key('duyuru-hedef-rozet-h2')), findsNothing);
    expect(find.textContaining('Blok: A'), findsOneWidget);
    expect(find.textContaining('Yalnız malikler'), findsOneWidget);
  });

  testWidgets('ROZET sakinde YOK (sunucu zaten yalniz kendisine gideni '
      'dondurur)', (tester) async {
    await _sur(tester, rol: UserRole.resident, liste: [
      _duyuru('h1', ek: {'hedef_bloklar': ['A']}),
    ]);
    expect(find.byKey(const Key('duyuru-hedef-rozet-h1')), findsNothing);
  });

  test('DuyuruHedef.toJson: personel-yalniz secimde sakin suzgeci dusurulur',
      () {
    const h = DuyuruHedef(
      roller: ['security'],
      sakinTipi: 'malik',
      bloklar: ['A'],
    );
    expect(h.toJson(), {
      'hedef_roller': ['security'],
      'hedef_sakin_tipi': null,
      'hedef_bloklar': <String>[],
    });
    // Duzenleme taslaginda hedef YOK (sunucu PATCH'te tasimaz).
    expect(
      const AnnouncementDraft(baslik: 'a', govde: 'b').toJson().keys,
      isNot(contains('hedef_roller')),
    );
  });

  test('Announcement.fromJson: NULL hedef (eski duyuru) = herkes', () {
    final a = Announcement.fromJson(_duyuru('x', ek: {
      'hedef_roller': null,
      'hedef_bloklar': null,
    }));
    expect(a.hedefli, isFalse);
  });
}
