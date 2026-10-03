/// (P253 Asama 2) TANIMLAR — TEK GENEL DEFTER (mobil).
///
/// Web `tanimlar.tsx` ile ayni govde kurali: bos alan null, zorunlu bos /
/// gecersiz tutar ISTEK ATMADAN durur, `sadeceOlustur` alan duzenlemede
/// gitmez. Taklit HTTP ADAPTORUNDE: govdeyi kuran katman da olculur.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/gen/app_localizations.dart';
import 'package:mobile/src/features/tanimlar/data/defter_api.dart';
import 'package:mobile/src/features/tanimlar/domain/defter_tanimi.dart';
import 'package:mobile/src/features/tanimlar/presentation/genel_defter_screen.dart';
import 'package:mobile/src/features/tasks/data/task_category_api.dart';
import 'package:mobile/src/features/tasks/presentation/task_categories_screen.dart';

import 'helpers/l10n_test_app.dart';

class _Istek {
  _Istek(this.metot, this.yol, this.govde);
  final String metot;
  final String yol;
  final Object? govde;
}

class _Adaptor implements HttpClientAdapter {
  _Adaptor(this.kayitlar);

  /// uc -> liste ogeleri
  final Map<String, List<Map<String, dynamic>>> kayitlar;
  final List<_Istek> istekler = [];

  /// Bu yola DELETE gelirse 409 (kayit kullanimda).
  String? kullanimda;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    istekler.add(_Istek(o.method, o.path, o.data));
    int durum = 200;
    Object govde = <String, dynamic>{};
    if (o.method == 'GET') {
      if (o.path == '/muhasebe-ayarlari') {
        govde = {'evrak_seri': 'AB', 'evrak_sira': 7, 'para_birimi': 'TRY'};
      } else {
        final items = kayitlar[o.path] ?? const [];
        govde = {'items': items, 'meta': {'total': items.length}};
      }
    } else if (o.method == 'DELETE' && o.path == kullanimda) {
      durum = 409;
      govde = {'error': {'code': 'conflict', 'message': ''}};
    } else if (o.path == '/sayaclar/bolum/otomatik') {
      govde = {'olusturulan': 4, 'atlanan': 1};
    } else if (o.path.startsWith('/task-categories/')) {
      govde = {'id': 'g1', 'ad': (o.data as Map)['ad'], 'aktif': true};
    }
    return ResponseBody.fromString(jsonEncode(govde), durum, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}

  Iterable<_Istek> yazanlar() => istekler.where((i) => i.metot != 'GET');
}

Dio _dio(_Adaptor a) => Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = a;

Future<void> _ac(WidgetTester t, _Adaptor a, Widget ekran) async {
  t.view.physicalSize = const Size(1080, 3000);
  t.view.devicePixelRatio = 2.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [
      defterApiProvider.overrideWithValue(DefterApi(_dio(a))),
      taskCategoryApiProvider.overrideWithValue(TaskCategoryApi(_dio(a))),
    ],
    child: l10nApp(ekran),
  ));
  await t.pumpAndSettle();
}

DefterTanimi _d(String k) => defterBul(k)!;

Future<void> _yaz(WidgetTester t, String alan, String metin) async {
  await t.enterText(find.byKey(Key('defter-alan-$alan')), metin);
  await t.pump();
}

Future<void> _kaydet(WidgetTester t) async {
  await t.tap(find.byKey(const Key('defter-form-kaydet')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('KASA EKLE: govde web kuraliyla (bos=null, tutar kurus, aktif varsayilan)', (t) async {
    final a = _Adaptor({'/kasalar': []});
    await _ac(t, a, GenelDefterScreen(defter: _d('kasalar')));
    await t.tap(find.byKey(const Key('defter-yeni')));
    await t.pumpAndSettle();
    await _yaz(t, 'kod', 'MRK');
    await _yaz(t, 'ad', 'Merkez Kasa');
    await _yaz(t, 'acilis_bakiye_kurus', '1.250,50');
    await _yaz(t, 'iban', 'tr33 0006 1005 1978 6457 8413 26');
    await _kaydet(t);
    final p = a.yazanlar().single;
    expect(p.metot, 'POST');
    expect(p.yol, '/kasalar');
    expect(p.govde, {
      'kod': 'MRK',
      'ad': 'Merkez Kasa',
      'acilis_tarihi': null,
      'acilis_bakiye_kurus': 125050,
      'banka_mi': true,
      'iban': 'TR330006100519786457841326',
      'banka_adi': null,
      'sube': null,
      'aktif': true,
    });
  });

  testWidgets('ZORUNLU bos ve GECERSIZ tutar istek ATMAZ', (t) async {
    final a = _Adaptor({'/firmalar': []});
    await _ac(t, a, GenelDefterScreen(defter: _d('firmalar')));
    await t.tap(find.byKey(const Key('defter-yeni')));
    await t.pumpAndSettle();
    await _kaydet(t);
    expect(find.byKey(const Key('defter-form-hata')), findsOneWidget);
    expect(find.textContaining('Ad'), findsWidgets);
    await _yaz(t, 'ad', 'Asansör A.Ş.');
    await _yaz(t, 'acilis_bakiye_kurus', '12,');
    await _kaydet(t);
    expect(find.textContaining('geçerli bir tutar'), findsOneWidget);
    expect(a.yazanlar(), isEmpty);
  });

  testWidgets('(P253 acil) FIRMA E-POSTASI BUYUK HARFLE GONDERILMEZ', (t) async {
    final a = _Adaptor({'/firmalar': []});
    await _ac(t, a, GenelDefterScreen(defter: _d('firmalar')));
    await t.tap(find.byKey(const Key('defter-yeni')));
    await t.pumpAndSettle();
    await _yaz(t, 'ad', 'Asansör A.Ş.');
    await _yaz(t, 'email', 'Servis@Asansor.com');
    // Alan ANINDA soyler (blur beklemeden).
    expect(find.text('E-posta adresi küçük harfle yazılmalıdır.'), findsWidgets);
    await _kaydet(t);
    expect(a.yazanlar(), isEmpty);
    await _yaz(t, 'email', 'servis@asansor.com');
    await _kaydet(t);
    expect((a.yazanlar().single.govde as Map)['email'], 'servis@asansor.com');
  });

  testWidgets('DUZENLE: PATCH {id} + secim degeri; SIL onayi adi yazar, 409 anlasilir', (t) async {
    final a = _Adaptor({
      '/gelir-gider-tanimlari': [
        {'id': 't1', 'ad': 'Aidat', 'tip': 'gelir', 'aktif': true},
      ],
    })..kullanimda = '/gelir-gider-tanimlari/t1';
    await _ac(t, a, GenelDefterScreen(defter: _d('gelir-gider-tanimlari')));
    expect(find.text('Gelir'), findsOneWidget); // secim etiketi, ham enum degil
    await t.tap(find.text('Aidat'));
    await t.pumpAndSettle();
    await _yaz(t, 'ad', 'Aylık aidat');
    await _kaydet(t);
    final p = a.yazanlar().single;
    expect((p.metot, p.yol), ('PATCH', '/gelir-gider-tanimlari/t1'));
    expect((p.govde as Map)['ad'], 'Aylık aidat');
    expect((p.govde as Map)['tip'], 'gelir');

    await t.tap(find.byKey(const Key('defter-menu-t1')));
    await t.pumpAndSettle();
    await t.tap(find.text('Sil').last);
    await t.pumpAndSettle();
    expect(find.textContaining('"Aidat" silinsin mi'), findsOneWidget);
    await t.tap(find.byKey(const Key('defter-sil-evet')));
    await t.pumpAndSettle();
    expect(a.yazanlar().last.metot, 'DELETE');
    expect(find.textContaining('kullanıldığı için silinemiyor'), findsOneWidget);
  });

  testWidgets('BOLUM SAYACI: daire referansi olusturmada gider, duzenlemede GITMEZ', (t) async {
    final a = _Adaptor({
      '/sayaclar/bolum': [
        {'id': 'b1', 'unit_id': 'u1', 'unit_no': 'A-1', 'ana_sayac_id': null, 'aktif': true},
      ],
      '/units': [
        {'id': 'u1', 'no': 'A-1'},
        {'id': 'u2', 'no': 'A-2'},
      ],
      '/sayaclar/ana': [
        {'id': 'm1', 'ad': 'Su ana'},
      ],
    });
    await _ac(t, a, GenelDefterScreen(defter: _d('sayaclar-bolum')));
    // Duzenle: unit_id govdede yok.
    await t.tap(find.text('A-1'));
    await t.pumpAndSettle();
    await _yaz(t, 'tesisat_no', 'T-9');
    await _kaydet(t);
    final patch = a.yazanlar().single;
    expect(patch.yol, '/sayaclar/bolum/b1');
    expect((patch.govde as Map).containsKey('unit_id'), isFalse);

    // Olustur: daire secilir ve gider.
    await t.tap(find.byKey(const Key('defter-yeni')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('defter-alan-unit_id')));
    await t.pumpAndSettle();
    await t.tap(find.text('A-2').last);
    await t.pumpAndSettle();
    await _kaydet(t);
    final post = a.yazanlar().last;
    expect((post.metot, post.yol), ('POST', '/sayaclar/bolum'));
    expect((post.govde as Map)['unit_id'], 'u2');

    // Toplu uretim.
    await t.tap(find.byKey(const Key('defter-sayac-uret')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('defter-ana-sayac')));
    await t.pumpAndSettle();
    await t.tap(find.text('Su ana').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('defter-sayac-uret-onay')));
    await t.pumpAndSettle();
    final uret = a.yazanlar().last;
    expect(uret.yol, '/sayaclar/bolum/otomatik');
    expect(uret.govde, {'ana_sayac_id': 'm1'});
    expect(find.textContaining('4 sayaç açıldı'), findsOneWidget);
  });

  testWidgets('HER DEFTER: ekle formu acilir ve POST kendi ucuna gider', (t) async {
    for (final d in defterler.where((d) => d.kimlik != 'sayaclar-bolum')) {
      final a = _Adaptor({d.uc: []});
      await _ac(t, a, GenelDefterScreen(defter: d));
      await t.tap(find.byKey(const Key('defter-yeni')));
      await t.pumpAndSettle();
      for (final alan in d.alanlar.where((x) => x.zorunlu)) {
        if (alan.tur == AlanTuru.secim) {
          await t.tap(find.byKey(Key('defter-alan-${alan.ad}')));
          await t.pumpAndSettle();
          await t.tap(find.text(alan.secenekler.first.etiket(lookupAppLocalizations(const Locale('tr')))).last);
          await t.pumpAndSettle();
        } else {
          await _yaz(t, alan.ad, 'X1');
        }
      }
      await _kaydet(t);
      final p = a.yazanlar().single;
      expect((p.metot, p.yol), ('POST', d.uc), reason: d.kimlik);
    }
  });

  testWidgets('MUHASEBE AYARLARI: okunur ve PATCH buyuk harfle gider', (t) async {
    final a = _Adaptor({});
    await _ac(t, a, const MuhasebeAyarlariScreen());
    expect(find.text('AB'), findsOneWidget);
    await t.enterText(find.byKey(const Key('muhasebe-seri')), 'xyz');
    await t.tap(find.byKey(const Key('muhasebe-kaydet')));
    await t.pumpAndSettle();
    final p = a.yazanlar().single;
    expect((p.metot, p.yol), ('PATCH', '/muhasebe-ayarlari'));
    expect(p.govde, {'evrak_seri': 'XYZ', 'evrak_sira': 7, 'para_birimi': 'TRY'});
  });

  testWidgets('GOREV KATEGORISI: dokun -> ad duzelt -> PATCH', (t) async {
    final a = _Adaptor({
      '/task-categories': [
        {'id': 'g1', 'ad': 'Temizlk', 'aktif': true},
      ],
    });
    await _ac(t, a, const TaskCategoriesScreen());
    await t.tap(find.byKey(const Key('kategori-g1')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'Temizlik');
    await t.tap(find.text('Kaydet').last);
    await t.pumpAndSettle();
    final p = a.yazanlar().single;
    expect((p.metot, p.yol), ('PATCH', '/task-categories/g1'));
    expect(p.govde, {'ad': 'Temizlik'});
  });
}
