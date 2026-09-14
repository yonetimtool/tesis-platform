/// (P230 §4) GOREV TAKIBI — mobil yuzey.
///
/// Sunucu DORT durumu TURETIR; istemci onlari YENIDEN HESAPLAMAZ. Iki
/// istemcinin ayni gorevi farkli durumda gostermesi, "gecikti" uyarisini
/// guvenilmez yapardi.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/tasks/data/task_api.dart';
import 'package:mobile/src/features/tasks/domain/task_models.dart';
import 'package:mobile/src/features/tasks/presentation/durum_rozeti.dart';

import 'helpers/l10n_test_app.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body);
  final Map<String, dynamic> body;
  final List<(String, Uri)> istekler = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add((options.method, options.uri));
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _gorev({
  String durum = 'atandi',
  String? sonTarih,
  String? baslama,
  int? gecikme,
}) => {
  'id': 't1',
  'ad': 'Cop toplama',
  'aktif': true,
  'foto_zorunlu': false,
  'durum': durum,
  'son_tarih': sonTarih,
  'baslama_zamani': baslama,
  'gecikme_gun': gecikme,
  'olusturan_ad': 'Ayse Yonetici',
  'atanan_ad': 'Mehmet Guvenlik',
};

void main() {
  group('model', () {
    test('TAKIP ALANLARI cozulur', () {
      final t = Task.fromJson(_gorev(
        durum: 'gecikti',
        sonTarih: '2026-03-01T08:00:00Z',
        baslama: '2026-03-02T09:00:00Z',
        gecikme: 4,
      ));
      expect(t.durum, TaskDurum.gecikti);
      expect(t.gecikmeGun, 4);
      expect(t.sonTarih!.toUtc().day, 1);
      expect(t.baslamaZamani!.toUtc().day, 2);
      expect(t.olusturanAd, 'Ayse Yonetici');
      expect(t.atananAd, 'Mehmet Guvenlik');
    });

    test('SON TARIH YOKSA gecikme null — SIFIR DEGIL', () {
      // Sifir "bugun son gun" demektir; "olcusu yok" ile karistirilamaz.
      expect(Task.fromJson(_gorev()).gecikmeGun, isNull);
    });

    test('BILINMEYEN DURUM `atandi`YA DUSER, HATA ATMAZ', () {
      // Sunucu ileride yeni bir durum eklerse eski istemci listeyi
      // cizemez hale GELMEMELI.
      expect(Task.fromJson(_gorev(durum: 'yepyeni')).durum, TaskDurum.atandi);
    });

    test('ESKI YANIT (alanlar yok) DUSMEZ', () {
      final t = Task.fromJson({'id': 't1', 'ad': 'x', 'aktif': true});
      expect(t.durum, TaskDurum.atandi);
      expect(t.sonTarih, isNull);
    });
  });

  group('POST /tasks/{id}/basla', () {
    test('dogru uca gider ve GUNCEL gorevi doner', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
      final adapter = _FakeAdapter(
        _gorev(durum: 'baslandi', baslama: '2026-03-02T09:00:00Z'),
      );
      dio.httpClientAdapter = adapter;
      final t = await TaskApi(dio).basla('t1');
      final (metot, uri) = adapter.istekler.single;
      expect(metot, 'POST');
      expect(uri.path, '/tasks/t1/basla');
      expect(t.durum, TaskDurum.baslandi);
    });
  });

  group('durum rozeti', () {
    testWidgets('RENK TEK BASINA YETMEZ — metin de yazilir', (tester) async {
      // Yalniz renkle ayrilan bir rozet, renk korlugu olan kullanicida ve
      // ekran okuyucuda HICBIR SEY soylemez.
      await tester.pumpWidget(l10nScaffold(
        const DurumRozeti(durum: TaskDurum.gecikti, gecikmeGun: 3),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Gecikti'), findsOneWidget);
      expect(find.textContaining('3'), findsOneWidget);
    });

    testWidgets('KONTRAST: dort durum da WCAG AA karsilar', (tester) async {
      // (P230 §2-e) Yasli goz dusuk kontrasti zor secer. Rozet RENKLI
      // metin + %12 saydam zemin kullaniyor; bu birlesim kolayca
      // esigin altina duser. Flutter'in kendi WCAG denetimi surulur.
      // HER IKI TEMA: ilk duzeltmede yalniz ACIK tema olculmustu ve
      // `shade900` koyu zeminde 1.65 veriyordu — beş eksen surusu
      // (koyu tema ekseni) onu yakaladi.
      final handle = tester.ensureSemantics();
      for (final koyu in [false, true]) {
        for (final durum in TaskDurum.values) {
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(
              brightness: koyu ? Brightness.dark : Brightness.light,
            ),
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: const [Locale('tr')],
            home: Scaffold(body: DurumRozeti(durum: durum)),
          ));
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }
      }
      handle.dispose();
    });

    testWidgets('DORT DURUM da cizilir, 7 dilde', (tester) async {
      for (final d in ['tr', 'en', 'de', 'fr', 'es', 'ru', 'ar']) {
        for (final durum in TaskDurum.values) {
          await tester.pumpWidget(l10nScaffold(
            DurumRozeti(durum: durum),
            locale: Locale(d),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$d/$durum');
          expect(find.byKey(Key('gorev-durum-${durum.wire}')), findsOneWidget,
              reason: '$d/$durum');
        }
      }
    });
  });
}
