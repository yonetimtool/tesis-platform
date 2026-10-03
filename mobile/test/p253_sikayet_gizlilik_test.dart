/// (P253 §D) Sikayet gizliligi — mobil yonetim ayrintisi.
///
/// Web harita daire ayrintisiyla AYNI eylemler: oruntu satiri + tek kaynak
/// uyarisi + "asilsiz" (gerekce zorunlu) ve geri alma. Taklit HTTP
/// ADAPTORUNDE: istek govdesini kuran katman da olculur.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/unit_complaints/data/unit_complaint_api.dart';
import 'package:mobile/src/features/unit_complaints/domain/unit_complaint_models.dart';
import 'package:mobile/src/features/unit_complaints/presentation/sikayet_ayrinti_sheet.dart';

import 'helpers/l10n_test_app.dart';

class _Adaptor implements HttpClientAdapter {
  final List<(String, String, Object?)> istekler = [];

  Map<String, dynamic> _sikayet({required bool asilsiz}) => {
        'id': 'c-1',
        'target_unit_id': 'u-1',
        'unit_no': 'A-2',
        'kategori': 'gurultu',
        'durum': 'acik',
        'created_at': '2026-10-01T20:00:00Z',
        'asilsiz': asilsiz,
        'asilsiz_gerekce': asilsiz ? 'Kamerada olay yok' : null,
      };

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add((o.method, o.path, o.data));
    final Object govde = switch ((o.method, o.path)) {
      ('GET', '/unit-complaints/kaynak-ozeti') => {
          'gun': 30,
          'sikayet_sayisi': 12,
          'farkli_kaynak': 2,
          'tek_kaynak_yogun': true,
          'asilsiz_sayisi': 1,
        },
      ('POST', '/unit-complaints/c-1/asilsiz') => _sikayet(asilsiz: true),
      ('DELETE', '/unit-complaints/c-1/asilsiz') => _sikayet(asilsiz: false),
      _ => <String, dynamic>{},
    };
    return ResponseBody.fromString(jsonEncode(govde), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

UnitComplaint _c({bool asilsiz = false}) => UnitComplaint(
      id: 'c-1',
      targetUnitId: 'u-1',
      unitNo: 'A-2',
      kategori: UnitComplaintKategori.gurultu,
      durum: 'acik',
      createdAt: DateTime.utc(2026, 10, 1, 20),
      asilsiz: asilsiz,
      asilsizGerekce: asilsiz ? 'Kamerada olay yok' : null,
    );

Future<(_Adaptor, List<bool?>)> _ac(WidgetTester tester, UnitComplaint c) async {
  final adaptor = _Adaptor();
  final dio = Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = adaptor;
  final donus = <bool?>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [unitComplaintApiProvider.overrideWithValue(UnitComplaintApi(dio))],
    child: l10nApp(Builder(
      builder: (context) => TextButton(
        onPressed: () async => donus.add(await sikayetAyrintisiAc(context, c)),
        child: const Text('ac'),
      ),
    )),
  ));
  await tester.tap(find.text('ac'));
  await tester.pumpAndSettle();
  return (adaptor, donus);
}

void main() {
  testWidgets('ORUNTU: sayi + farkli daire + tek kaynak uyarisi (etiket YOK)',
      (tester) async {
    await _ac(tester, _c());
    expect(find.text('Son 30 günde 12 şikâyet, 2 farklı daireden'), findsOneWidget);
    expect(find.byKey(const Key('sikayet-tek-kaynak')), findsOneWidget);
    expect(find.text('1 asılsız işaretli'), findsOneWidget);
    expect(find.textContaining('Kaynak A'), findsNothing);
  });

  testWidgets('ASILSIZ: gerekce olmadan gonderilemez; gerekce GOVDEDE gider',
      (tester) async {
    final (adaptor, donus) = await _ac(tester, _c());
    await tester.tap(find.byKey(const Key('sikayet-asilsiz-ac')));
    await tester.pumpAndSettle();
    final onay = find.byKey(const Key('sikayet-asilsiz-onayla'));
    expect(tester.widget<FilledButton>(onay).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('sikayet-asilsiz-gerekce')), '  ab ');
    await tester.pump();
    expect(tester.widget<FilledButton>(onay).onPressed, isNull, reason: 'kirpilmis 2 karakter');
    await tester.enterText(find.byKey(const Key('sikayet-asilsiz-gerekce')), 'Kamerada olay yok');
    await tester.pump();
    await tester.tap(onay);
    await tester.pumpAndSettle();
    final post = adaptor.istekler.where((i) => i.$1 == 'POST').single;
    expect(post.$2, '/unit-complaints/c-1/asilsiz');
    expect(post.$3, {'gerekce': 'Kamerada olay yok'});
    expect(donus, [true]);
  });

  testWidgets('GERI AL: asilsiz kayitta DELETE gider', (tester) async {
    final (adaptor, donus) = await _ac(tester, _c(asilsiz: true));
    expect(find.text('Gerekçe: Kamerada olay yok'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sikayet-asilsiz-geri-al')));
    await tester.pumpAndSettle();
    expect(adaptor.istekler.where((i) => i.$1 == 'DELETE').single.$2,
        '/unit-complaints/c-1/asilsiz');
    expect(donus, [true]);
  });

  test('KAYNAK: mobil sikayet edenin kimligini OKUMAZ (alan yok)', () {
    final bulgu = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.contains('/l10n/')) continue;
      final s = f.readAsStringSync();
      if (RegExp(r"""['"]complainant""").hasMatch(s) || s.contains('complainantAd')) {
        bulgu.add(f.path);
      }
    }
    expect(bulgu, isEmpty);
  });
}
