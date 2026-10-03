/// (P253 Asama 1) KISILER + GOREV + EK + GUNLUK KUCUKLER — mobil akislar.
///
/// Taklit HTTP ADAPTORUNDE: istegi kuran katman (API sinifi + ekran) da
/// olculur; yalniz yanit taklit.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/ekler/presentation/ek_listesi.dart';
import 'package:mobile/src/features/ekler/presentation/ek_sil.dart';
import 'package:mobile/src/features/kisiler/data/kisi_api.dart';
import 'package:mobile/src/features/kisiler/presentation/kisi_islemleri.dart';
import 'package:mobile/src/features/kisiler/presentation/kisi_suzgec.dart';
import 'package:mobile/src/features/patrol/data/patrol_api.dart';
import 'package:mobile/src/features/tasks/data/task_api.dart';
import 'package:mobile/src/features/visitors/data/visitor_api.dart';

import 'helpers/l10n_test_app.dart';

class _Istek {
  _Istek(this.metot, this.yol, this.sorgu, this.govde);
  final String metot;
  final String yol;
  final Map<String, dynamic> sorgu;
  final Object? govde;
}

class _Adaptor implements HttpClientAdapter {
  _Adaptor(this.yanitlar);

  /// 'METOT /yol' -> (durum, govde)
  final Map<String, (int, Object?)> yanitlar;
  final List<_Istek> istekler = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add(_Istek(o.method, o.path, o.queryParameters, o.data));
    final (kod, govde) = yanitlar['${o.method} ${o.path}'] ?? (200, <String, dynamic>{});
    return ResponseBody.fromString(
      govde == null ? '' : jsonEncode(govde),
      kod,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Adaptor a) => Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = a;

Map<String, dynamic> _kisi({bool aranabilir = false}) => {
      'id': 'u1',
      'ad': 'Ayşe YILMAZ',
      'role': 'security',
      'is_active': true,
      'email': 'ayse@ornek.com',
      'aranabilir': aranabilir,
      'kayit_tamamlandi': true,
      'eposta_dogrulandi': false,
      'bildirim_eposta': true,
      'bildirim_sms': false,
      'bildirim_mobil': true,
      'mobil_cihaz_sayisi': 0,
      'odeme_kodu': 'K-42',
    };

/// Tek dugmeli kabuk: [eylem] dokunulunca calisir.
Future<void> _kur(
  WidgetTester tester,
  _Adaptor a,
  Future<void> Function(BuildContext, WidgetRef) eylem, {
  UserRole rol = UserRole.yonetici,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(_dio(a)),
      currentUserRoleProvider.overrideWith((ref) async => rol),
    ],
    child: l10nApp(Consumer(
      builder: (context, ref, _) => Scaffold(
        body: TextButton(onPressed: () => eylem(context, ref), child: const Text('ac')),
      ),
    )),
  ));
  await tester.tap(find.text('ac'));
  await tester.pumpAndSettle();
}

void main() {
  group('Kisi tanilama karti', () {
    testWidgets('GET /users/{id}: tanilama + cihazsiz uyarisi + aranabilir PATCH', (t) async {
      final a = _Adaptor({'GET /users/u1': (200, _kisi())});
      await _kur(t, a, (c, r) => kisiKartiAc(c, id: 'u1'));
      expect(find.byKey(const Key('kisi-karti')), findsOneWidget);
      expect(find.text('Ayşe YILMAZ'), findsOneWidget);
      expect(find.text('K-42'), findsOneWidget);
      expect(find.byKey(const Key('kisi-cihazsiz')), findsOneWidget,
          reason: 'mobil acik + cihaz 0: bildirim gitmez uyarisi');
      await t.ensureVisible(find.byKey(const Key('kisi-aranabilir')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('kisi-aranabilir')));
      await t.pumpAndSettle();
      final patch = a.istekler.where((i) => i.metot == 'PATCH').single;
      expect(patch.yol, '/users/u1');
      expect(patch.govde, {'aranabilir': true});
    });
  });

  group('Kisi sil / pasiflestir', () {
    testWidgets('sil: onayda KISI ADI; DELETE /users/{id}; anonimlestirme bildirilir', (t) async {
      final a = _Adaptor({'DELETE /users/u1': (200, {'deleted': false})});
      await _kur(t, a, (c, r) => kisiSilOnayli(c, r, id: 'u1', ad: 'Ayşe YILMAZ'));
      expect(find.textContaining('Ayşe YILMAZ'), findsOneWidget);
      expect(a.istekler, isEmpty, reason: 'onaydan once istek yok');
      await t.tap(find.byKey(const Key('kisi-sil-onay')));
      await t.pumpAndSettle();
      expect(a.istekler.single.metot, 'DELETE');
      expect(a.istekler.single.yol, '/users/u1');
      expect(find.textContaining('anonimleştirildi'), findsOneWidget);
    });

    testWidgets('pasiflestir: onay (ad yazili) -> PATCH is_active=false; vazgec istek atmaz', (t) async {
      final a = _Adaptor({});
      await _kur(t, a, (c, r) => kisiAktiflikDegistir(c, r, id: 'u1', ad: 'Ali KAYA', aktif: false));
      expect(find.textContaining('Ali KAYA'), findsOneWidget);
      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();
      expect(a.istekler, isEmpty);
      await t.tap(find.text('ac'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('kisi-pasif-onay')));
      await t.pumpAndSettle();
      expect(a.istekler.single.govde, {'is_active': false});
    });

    testWidgets('aktiflestir onay SORMAZ (geri donus)', (t) async {
      final a = _Adaptor({});
      await _kur(t, a, (c, r) => kisiAktiflikDegistir(c, r, id: 'u1', ad: 'Ali', aktif: true));
      expect(a.istekler.single.govde, {'is_active': true});
    });

    test('acilabilir roller sunucudan', () async {
      final a = _Adaptor({
        'GET /users/acilabilir-roller': (200, {
          'roller': ['security', 'tesis_gorevlisi']
        }),
      });
      expect(await KisiApi(_dio(a)).acilabilirRoller(), {'security', 'tesis_gorevlisi'});
    });
  });

  group('Ek sil (her yuzey)', () {
    testWidgets('ekSilOnayli: ekin ADI onayda; DELETE /ekler/{id}', (t) async {
      final a = _Adaptor({'DELETE /ekler/e1': (204, null)});
      await _kur(t, a, (c, r) async {
        await ekSilOnayli(c, r, ekId: 'e1', ad: 'Fatura.pdf');
      });
      expect(find.textContaining('Fatura.pdf'), findsOneWidget);
      await t.tap(find.byKey(const Key('ek-sil-onay')));
      await t.pumpAndSettle();
      expect(a.istekler.single.metot, 'DELETE');
      expect(a.istekler.single.yol, '/ekler/e1');
    });

    Future<_Adaptor> liste(WidgetTester t, UserRole rol) async {
      final a = _Adaptor({
        'GET /ekler': (200, {
          'items': [
            {'id': 'e1', 'tur': 'not', 'metin': 'Kapı boyandı', 'olusturan_ad': 'Yönetici'},
          ]
        }),
      });
      await t.pumpWidget(ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(_dio(a)),
          currentUserRoleProvider.overrideWith((ref) async => rol),
        ],
        child: l10nApp(const Scaffold(
          body: SingleChildScrollView(child: EkListesi(varlikTipi: 'task', varlikId: 't1')),
        )),
      ));
      await t.pumpAndSettle();
      return a;
    }

    testWidgets('gorev ekleri: yonetim siler ve not ekler', (t) async {
      final a = await liste(t, UserRole.yonetici);
      expect(a.istekler.first.sorgu, {'varlik_tipi': 'task', 'varlik_id': 't1'});
      expect(find.text('Kapı boyandı'), findsOneWidget);
      expect(find.byKey(const Key('ek-sil-e1')), findsOneWidget);
      await t.enterText(find.byKey(const Key('ek-not-metin')), 'Yeni not');
      await t.tap(find.byKey(const Key('ek-not-ekle')));
      await t.pumpAndSettle();
      final post = a.istekler.where((i) => i.metot == 'POST').single;
      expect(post.govde, {'varlik_tipi': 'task', 'varlik_id': 't1', 'tur': 'not', 'metin': 'Yeni not'});
    });

    testWidgets('gorev ekleri: saha OKUR, silme/ekleme cizilmez', (t) async {
      await liste(t, UserRole.security);
      expect(find.text('Kapı boyandı'), findsOneWidget);
      expect(find.byKey(const Key('ek-sil-e1')), findsNothing);
      expect(find.byKey(const Key('ek-not-metin')), findsNothing);
    });
  });

  group('Gorev', () {
    test('GET /tasks/{id} ve adim PATCH yalniz DEGISEN alanla', () async {
      final a = _Adaptor({
        'GET /tasks/t1': (200, {'id': 't1', 'ad': 'Kazan', 'aktif': true}),
        'PATCH /tasks/t1/adimlar/s1': (200, {'id': 's1', 'task_id': 't1', 'ad': 'Yeni', 'sira': 0}),
      });
      final api = TaskApi(_dio(a));
      expect((await api.getTask('t1')).id, 't1');
      await api.updateStep('t1', 's1', ad: 'Yeni');
      final patch = a.istekler.last;
      expect(patch.metot, 'PATCH');
      expect(patch.govde, {'ad': 'Yeni'});
    });

    test('durum suzgeci SUNUCUYA gider', () async {
      final a = _Adaptor({'GET /tasks': (200, {'items': []})});
      await TaskApi(_dio(a)).fetchTasks(durum: 'gecikti');
      expect(a.istekler.single.sorgu['durum'], 'gecikti');
    });
  });

  group('Gunluk kucukler', () {
    test('ziyaretci "yalniz iceridekiler" -> ?icerde=true', () async {
      final a = _Adaptor({'GET /visitors': (200, {'items': []})});
      await VisitorApi(_dio(a)).fetchAll(icerde: true);
      expect(a.istekler.single.sorgu['icerde'], true);
    });

    test('devriye tarih araligi -> baslangic + bitis', () async {
      final a = _Adaptor({'GET /patrol-windows': (200, {'items': [], 'meta': {'total': 0}})});
      await PatrolApi(_dio(a)).fetchWindowHistory(
        baslangicAfter: DateTime(2026, 9, 1),
        bitisBefore: DateTime(2026, 9, 8),
      );
      final s = a.istekler.single.sorgu;
      expect(s['baslangic'], DateTime(2026, 9, 1).toUtc().toIso8601String());
      expect(s['bitis'], DateTime(2026, 9, 8).toUtc().toIso8601String());
    });

    test('kisi arama: Turkce buyuk/kucuk harf + durum', () {
      final l = [('IŞIK Ali', true), ('Veli', false)];
      expect(
        kisiSuz(l, 'ışık', KisiDurumSuzgeci.tumu, ad: (k) => k.$1, aktif: (k) => k.$2),
        [l[0]],
      );
      expect(
        kisiSuz(l, '', KisiDurumSuzgeci.pasif, ad: (k) => k.$1, aktif: (k) => k.$2),
        [l[1]],
      );
    });
  });

  test('ekSilebilir: tablo rolleriyle ayni', () {
    expect(
      {for (final r in UserRole.values) if (ekSilebilir(r)) r},
      {UserRole.admin, UserRole.yonetici, UserRole.guvenlikAmiri},
    );
  });
}
