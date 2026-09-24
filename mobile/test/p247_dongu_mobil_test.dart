/// (P247 §1) VARDIYA DONGUSU — mobil: ata + onizle + kaydet + geri al.
///
/// TAKLIT HTTP ADAPTER'INDA (P200 dersi): API sinifini taklit etmek, govdeyi
/// kuran katmani OLCMEZDI. Olculen: onizleme `kuru=true` ile gider, ekip
/// SIRASI + kaydirma tel uzerinde, sunucunun kapsama boslugu ekranda saat
/// araligiyla gorunur, kaydetme ayni uca `kuru=false` gider, geri alma
/// dongu partisine gider, hazir 12/36 dongusu gun asiri adim dizisiyle
/// kaydedilir.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/shifts/presentation/dongu_ata_dialogu.dart';
import 'package:mobile/src/features/shifts/presentation/vardiya_plani_screen.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';
import 'helpers/sahte_jwt.dart';

class _Tel implements HttpClientAdapter {
  final istekler = <({String yol, String metot, Map<String, dynamic> govde})>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final ham = options.data;
    final govdeIstek = ham is Map<String, dynamic>
        ? Map.of(ham)
        : <String, dynamic>{};
    istekler.add((yol: options.path, metot: options.method, govde: govdeIstek));
    final Object govde = switch ((options.method, options.path)) {
      ('GET', '/vardiya-plani/kaliplar') => {
        'items': [
          {
            'id': 'k1',
            'ad': '2-2-2',
            'aktif': true,
            'dilimler': [
              {'ad': 'Gündüz', 'baslangic': '08:00:00', 'bitis': '20:00:00'},
              {'ad': 'Gece', 'baslangic': '20:00:00', 'bitis': '08:00:00'},
            ],
            'adimlar': [
              [1],
              [1],
              [0],
              [0],
              [],
              [],
            ],
          },
          {
            'id': 'k2',
            'ad': 'Klasik',
            'aktif': true,
            'dilimler': [
              {'ad': 'Gündüz', 'baslangic': '08:00:00', 'bitis': '20:00:00'},
            ],
            'adimlar': null,
          },
        ],
      },
      ('POST', '/vardiya-plani/kaliplar') => {
        'id': 'k3',
        'ad': govdeIstek['ad'],
        'aktif': true,
        'dilimler': govdeIstek['dilimler'],
        'adimlar': govdeIstek['adimlar'],
      },
      ('GET', '/vardiya-plani/dongu-atamalari') => {
        'ufuk_gun': 62,
        'items': [
          {
            'id': 'a1',
            'kalip_id': 'k1',
            'kalip_ad': '2-2-2',
            'user_id': 'u1',
            'ad': 'Ali',
            'referans': '2026-03-02',
            'baslangic': '2026-03-02',
            'bitis': null,
            'uretildi_kadar': '2026-05-02',
            'parti_id': 'p0',
            'durum': 'aktif',
            'atlanan': <Object>[],
          },
        ],
      },
      ('POST', '/vardiya-plani/dongu-uygula') => {
        'uygulandi': govdeIstek['kuru'] != true,
        'parti_id': govdeIstek['kuru'] == true ? null : 'p1',
        'baslangic': '2026-03-02',
        'bitis': '2026-05-02',
        'eklenecek': 124,
        'eklenen': govdeIstek['kuru'] == true ? 0 : 124,
        'cakisan': 0,
        'zaten_var': 0,
        'izinli': 0,
        'satirlar': [
          {
            'tarih': '2026-03-02',
            'dilim': 'Gece',
            'baslangic': '20:00:00',
            'bitis': '08:00:00',
            'user_id': 'u1',
            'ad': 'Ali',
            'durum': 'eklenecek',
          },
        ],
        'kapsama': [
          {
            'tarih': '2026-03-02',
            'bos_dakika': 480,
            'bosluklar': [
              {'baslangic': '00:00:00', 'bitis': '08:00:00'},
            ],
          },
          {'tarih': '2026-03-03', 'bos_dakika': 0, 'bosluklar': <Object>[]},
        ],
        'ofsetler': {'u1': 0, 'u2': 2, 'u3': 4},
        'uyarilar': <String>[],
      },
      ('POST', '/vardiya-plani/parti/p0/geri-al') => {
        'parti_id': 'p0',
        'iptal_edilen': 40,
      },
      ('GET', '/users') => {
        'items': [
          {'id': 'u1', 'ad': 'Ali', 'role': 'security', 'is_active': true},
          {'id': 'u2', 'ad': 'Veli', 'role': 'security', 'is_active': true},
          {'id': 'u3', 'ad': 'Can', 'role': 'security', 'is_active': true},
        ],
      },
      ('GET', '/vardiya-plani/cizelge') => {
        'baslangic': '2026-03-02',
        'bitis': '2026-03-08',
        'personel': <Object>[],
      },
      ('GET', '/vardiya-plani/simdi') => {
        'zaman': '2026-03-02T10:00:00',
        'gorevdeki_vardiya': null,
        'gorevdekiler': <Object>[],
        'sonraki_vardiya': null,
        'sonrakiler': <Object>[],
      },
      ('GET', '/vardiya-plani/yayin-ozeti') => {
        'bekleyen': 0,
        'taslak': 0,
        'degisen': 0,
      },
      _ => <String, dynamic>{},
    };
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

Future<_Tel> _ac(
  WidgetTester tester, {
  Size boyut = const Size(1080, 2400),
}) async {
  tester.view.physicalSize = boyut;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final tel = _Tel();
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = tel;
  final kap = ProviderContainer(
    overrides: [
      dioProvider.overrideWithValue(dio),
      secureStorageProvider.overrideWithValue(
        BellekDepo({
          'auth.access_token': sahteJwt({
            'role': 'yonetici',
            'tenant_id': 't-1',
            'sub': 'y1',
          }),
        }),
      ),
    ],
  );
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: kap,
      child: l10nApp(const VardiyaPlaniScreen()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('vardiya-dongu-ac')));
  await tester.pumpAndSettle();
  return tel;
}

Future<void> _kisiSec(WidgetTester tester, String id) async {
  final f = find.byKey(Key('dongu-kisi-$id'));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _dokun(WidgetTester tester, String anahtar) async {
  final f = find.byKey(Key(anahtar));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  test('hazir 12/36 = gun asiri iki hafta gece + iki hafta gunduz', () {
    expect(hazir1236.length, 28);
    expect(hazir1236.sublist(0, 4), [
      [1],
      <int>[],
      [1],
      <int>[],
    ]);
    expect(hazir1236.sublist(14, 18), [
      [0],
      <int>[],
      [0],
      <int>[],
    ]);
    expect(hazir222, [
      [1],
      [1],
      [0],
      [0],
      <int>[],
      <int>[],
    ]);
  });

  testWidgets('YALNIZ DONGU kaliplari secilebilir', (tester) async {
    await _ac(tester);
    await tester.tap(find.byKey(const Key('dongu-kalip')));
    await tester.pumpAndSettle();
    expect(find.text('2-2-2'), findsWidgets);
    expect(find.text('Klasik'), findsNothing);
  });

  testWidgets(
    'ONIZLEME kuru=true + ekip SIRASI + kaydirma; BOSLUK saatle; KAYDET kuru=false',
    (tester) async {
      final tel = await _ac(tester);
      await tester.tap(find.byKey(const Key('dongu-kalip')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2-2-2').last);
      await tester.pumpAndSettle();
      for (final id in ['u1', 'u2', 'u3']) {
        await _kisiSec(tester, id);
      }
      await tester.enterText(find.byKey(const Key('dongu-kaydirma')), '2');
      await tester.pumpAndSettle();
      await _dokun(tester, 'dongu-onizle');

      final onizleme = tel.istekler.lastWhere(
        (i) => i.yol == '/vardiya-plani/dongu-uygula',
      );
      expect(onizleme.govde['kuru'], isTrue);
      expect(onizleme.govde['kalip_id'], 'k1');
      expect(onizleme.govde['kisiler'], ['u1', 'u2', 'u3']);
      expect(onizleme.govde['kaydirma'], 2);

      final bos = find.byKey(const Key('dongu-bosluk-2026-03-02'));
      expect(bos, findsOneWidget);
      expect(
        find.descendant(of: bos, matching: find.textContaining('00:00-08:00')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('dongu-bosluk-2026-03-03')), findsNothing);

      await _dokun(tester, 'dongu-uygula');
      final kayit = tel.istekler.lastWhere(
        (i) => i.yol == '/vardiya-plani/dongu-uygula',
      );
      expect(kayit.govde['kuru'], isFalse);
    },
  );

  testWidgets('ETKIN dongu: ekip partisi GERI ALINIR', (tester) async {
    final tel = await _ac(tester);
    await _dokun(tester, 'dongu-geri-al-p0');
    expect(
      tel.istekler.any(
        (i) => i.metot == 'POST' && i.yol == '/vardiya-plani/parti/p0/geri-al',
      ),
      isTrue,
    );
  });

  testWidgets('HAZIR 12/36 kaydi adimlari tel uzerinde tasir', (tester) async {
    final tel = await _ac(tester);
    await _dokun(tester, 'dongu-hazir-1236');
    final k = tel.istekler.lastWhere(
      (i) => i.metot == 'POST' && i.yol == '/vardiya-plani/kaliplar',
    );
    expect((k.govde['adimlar'] as List).length, 28);
    expect((k.govde['dilimler'] as List).length, 2);
    expect((k.govde['dilimler'] as List)[1]['baslangic'], '20:00');
  });

  testWidgets('360 dp telefonda diyalog + onizleme TASMAZ', (tester) async {
    // EKRAN DEGIL DIYALOG surulur: vardiya ekraninin AppBar'i 360 dp'de
    // ONCEDEN tasiyor (Yayinla + Sablonlar + izin; bu bolumun kapsami
    // disinda, rapora yazildi). Burada olculen: dongu diyalogu tasmaz.
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tel = _Tel();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = tel;
    final kap = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(kap.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: kap,
        child: l10nApp(
          Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                key: const Key('ac'),
                onPressed: () => showDialog<bool>(
                  context: c,
                  builder: (_) => const DonguAtaDialogu(),
                ),
                child: const Text('x'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('ac')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dongu-kalip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2-2-2').last);
    await tester.pumpAndSettle();
    await _kisiSec(tester, 'u1');
    await _dokun(tester, 'dongu-onizle');
    expect(
      tel.istekler.any((i) => i.yol == '/vardiya-plani/dongu-uygula'),
      isTrue,
    );
    expect(find.byKey(const Key('dongu-bosluk-2026-03-02')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
