/// (P253 Asama 2) TESIS AYARLARI (operasyon) + BUTCE HEDEFLERI — mobil.
///
/// Taklit HTTP ADAPTORUNDE: govdeyi kuran katman da olculur.
///   * ayarlar: YALNIZ degisen alanlar PATCH govdesinde; aralik disi sayi
///     kaydi kapatir; web tablosundaki her ayar mobil tabloda da var.
///   * butce: hedef yaz POST govdesi, sil onayi + DELETE yolu, denetci
///     yazma dugmesi gormez.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/budget/presentation/butce_hedefleri_screen.dart';
import 'package:mobile/src/features/tenant/domain/tesis_ayar_alanlari.dart';
import 'package:mobile/src/features/tenant/presentation/tesis_ayarlari_screen.dart';

import 'helpers/l10n_test_app.dart';

class _Tel implements HttpClientAdapter {
  final istekler = <({String yol, String metot, Object? govde})>[];
  final hedefler = <Map<String, dynamic>>[
    {'id': 'h1', 'yil': DateTime.now().year, 'donem': null, 'kategori_id': 'c1', 'tutar_kurus': 1200000},
  ];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    istekler.add((yol: o.path, metot: o.method, govde: o.data));
    final Object? govde = switch ((o.method, o.path)) {
      ('GET', '/tenant/settings') || ('PATCH', '/tenant/settings') => {
          'tenant_id': 't-1',
          'ad': 'Deneme Sitesi',
          'tur_gecikme_toleransi_dk': 15,
          'tur_alarm_tekrar_sayisi': 2,
          'tur_baslangic_foto_zorunlu': false,
          'vardiya_hatirlatma_dk': '30',
          'vardiya_baslamadi_dk': 10,
          'okutma_mesafe_esigi_m': 50,
          'otopark_kapasite': null,
          'rezervasyon_gecmis_ay': 12,
          'varsayilan_hedef_kurali': 'kiraci_oncelikli',
          'gurultu_esigi': 3,
          'gurultu_uyari_metni': null,
          'gurultu_pencere_gun': 30,
          'gurultu_susma_gun': 2,
          'gurultu_eskalasyon_esigi': 2,
          'sikayet_harita_saat': 24,
          'gurultu_sakin_uyarisi': true,
        },
      ('GET', '/budget/hedefler') => {'items': hedefler},
      ('POST', '/budget/hedefler') => {
          'id': 'h2', ...(o.data as Map<String, dynamic>), 'created_at': '2026-10-01T00:00:00Z'},
      ('DELETE', '/budget/hedefler/h1') => null,
      ('GET', '/budget/karsilastirma') => {
          'yil': DateTime.now().year,
          'items': [
            {'kategori_id': 'c1', 'ad': 'Elektrik', 'tip': 'gider', 'hedef_kurus': 1200000,
             'gerceklesen_kurus': 1500000, 'sapma_kurus': 300000, 'sapma_yuzde': 25},
          ],
          'hedef_gelir_kurus': 0, 'hedef_gider_kurus': 1200000,
          'gerceklesen_gelir_kurus': 0, 'gerceklesen_gider_kurus': 1500000,
        },
      ('GET', '/budget/categories') => {
          'items': [
            {'id': 'c1', 'ad': 'Elektrik', 'tip': 'gider', 'aktif': true},
            {'id': 'c2', 'ad': 'Aidat', 'tip': 'gelir', 'aktif': true},
          ],
        },
      _ => <String, dynamic>{},
    };
    if (govde == null) return ResponseBody.fromString('', 204);
    return ResponseBody.fromString(jsonEncode(govde), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<_Tel> _ac(WidgetTester tester, Widget ekran, {UserRole rol = UserRole.yonetici}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  final tel = _Tel();
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      currentUserRoleProvider.overrideWith((ref) async => rol),
    ],
    child: l10nApp(ekran),
  ));
  await tester.pumpAndSettle();
  return tel;
}

/// Uzun listede tembel cizilen kaydet dugmesi: once gorunur yap.
Future<FilledButton> _kaydet(WidgetTester tester) async {
  final f = find.byKey(const Key('tesis-ayar-kaydet'));
  await tester.scrollUntilVisible(f, 400, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  return tester.widget<FilledButton>(f);
}

Future<void> _dokun(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  test('mobil ayar tablosu web OPERASYON tablosuyla AYNI anahtarlar (adminOnly haric)', () {
    final web = File('../admin-web/lib/tesis-ayar-alanlari.ts').readAsStringSync();
    final govde = web.substring(web.indexOf('export const OPERASYON'));
    final ogeler = govde.split(RegExp(r'\n  \{'));
    final webAnahtarlar = <String>{
      for (final o in ogeler)
        if (!o.contains('adminOnly: true'))
          for (final m in RegExp(r'anahtar: "([a-z_]+)"').allMatches(o)) m.group(1)!,
    };
    expect(tesisAyarlari.map((a) => a.anahtar).toSet(), webAnahtarlar);
  });

  testWidgets('AYARLAR: yalniz degisen alanlar PATCH govdesinde', (tester) async {
    final tel = await _ac(tester, const TesisAyarlariScreen());
    expect((await _kaydet(tester)).onPressed, isNull);
    await tester.scrollUntilVisible(find.byKey(const Key('tesis-ayar-otopark_kapasite')), -400,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byKey(const Key('tesis-ayar-otopark_kapasite')), '120');
    await _dokun(tester, find.byKey(const Key('tesis-ayar-gurultu_sakin_uyarisi')));
    await _dokun(tester, find.byKey(const Key('tesis-ayar-varsayilan_hedef_kurali')));
    await tester.tap(find.text('Malik öder').last);
    await tester.pumpAndSettle();
    await _dokun(tester, find.byKey(const Key('tesis-ayar-kaydet')));
    final patch = tel.istekler.singleWhere((i) => i.metot == 'PATCH');
    expect(patch.govde, {
      'otopark_kapasite': 120,
      'gurultu_sakin_uyarisi': false,
      'varsayilan_hedef_kurali': 'malik',
    });
  });

  testWidgets('AYARLAR: aralik disi sayi kaydi kapatir ve hata gosterir', (tester) async {
    final tel = await _ac(tester, const TesisAyarlariScreen());
    await tester.scrollUntilVisible(find.byKey(const Key('tesis-ayar-gurultu_esigi')), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byKey(const Key('tesis-ayar-gurultu_esigi')), '99');
    await tester.pumpAndSettle();
    expect(find.textContaining('1 ile 50 arasında'), findsOneWidget);
    expect((await _kaydet(tester)).onPressed, isNull);
    expect(tel.istekler.where((i) => i.metot == 'PATCH'), isEmpty);
  });

  testWidgets('BUTCE: hedef yaz POST govdesi (aylik)', (tester) async {
    final tel = await _ac(tester, const ButceHedefleriScreen());
    expect(find.text('Elektrik'), findsWidgets);
    await _dokun(tester, find.byKey(const Key('bth-yeni')));
    await _dokun(tester, find.byKey(const Key('bth-tur')));
    await tester.tap(find.text('Aidat').last);
    await tester.pumpAndSettle();
    await _dokun(tester, find.byKey(const Key('bth-donem')));
    final yil = DateTime.now().year;
    await tester.tap(find.text('$yil-03').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bth-tutar')), '2.500,50');
    await tester.pumpAndSettle();
    await _dokun(tester, find.byKey(const Key('bth-kaydet')));
    final post = tel.istekler.singleWhere((i) => i.metot == 'POST');
    expect(post.govde, {
      'yil': yil,
      'kategori_id': 'c2',
      'tutar_kurus': 250050,
      'donem': '$yil-03',
    });
  });

  testWidgets('BUTCE: sil -> onay (tur + tutar yazili) -> DELETE', (tester) async {
    final tel = await _ac(tester, const ButceHedefleriScreen());
    await _dokun(tester, find.byKey(const Key('bth-sil-h1')));
    expect(find.textContaining('Elektrik'), findsWidgets);
    expect(find.textContaining('12.000,00'), findsWidgets);
    await _dokun(tester, find.byKey(const Key('bth-sil-onay')));
    expect(tel.istekler.where((i) => i.metot == 'DELETE').single.yol, '/budget/hedefler/h1');
  });

  testWidgets('BUTCE: denetci salt okur (yazma dugmesi yok)', (tester) async {
    await _ac(tester, const ButceHedefleriScreen(), rol: UserRole.denetci);
    expect(find.text('Elektrik'), findsWidgets);
    expect(find.byKey(const Key('bth-yeni')), findsNothing);
    expect(find.byKey(const Key('bth-sil-h1')), findsNothing);
  });
}
