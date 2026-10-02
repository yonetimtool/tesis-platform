/// (P250 §1) AD + SOYAD — Türkçe harf kuralıyla biçim, mobil.
///
/// (1) Kural: sunucudaki `kisi_adi.py` ve web `kisi-adi.ts` ile AYNI
///     örnekler.
/// (2) Personel ekleme: iki ayrı zorunlu alan, YAZARKEN biçimlenir, TEL
///     ÜZERİNDEKİ gövdede `ad` ve `soyad` ayrı ve biçimli (taklit HTTP
///     adapter'ında — P200 deseni).
/// (3) Düzenleme: P250 öncesi kayıtta (soyad null) son kelime soyad
///     ÖNERİLİR.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/kisi_adi.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/staff/presentation/staff_screen.dart';

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
    istekler.add((
      yol: options.path,
      metot: options.method,
      govde: ham is Map<String, dynamic> ? Map.of(ham) : <String, dynamic>{},
    ));
    final Object govde = switch ((options.method, options.path)) {
      ('GET', '/users') => {
          'items': [
            {'id': 'g1', 'ad': 'Ali Veli', 'role': 'security', 'is_active': true},
          ],
          'meta': {'total': 1},
        },
      ('POST', '/users') => {'id': 'yeni-1'},
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

Future<_Tel> _sur(WidgetTester tester) async {
  final tel = _Tel();
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = tel;
  final kap = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    secureStorageProvider.overrideWithValue(BellekDepo({
      'auth.access_token': sahteJwt({'role': 'yonetici', 'tenant_id': 't-1'}),
    })),
  ]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: kap, child: l10nApp(const StaffScreen())));
  await tester.pumpAndSettle();
  return tel;
}

String _metin(WidgetTester tester, String anahtar) =>
    tester.widget<TextFormField>(find.byKey(Key(anahtar))).controller!.text;

void main() {
  group('kural (sunucu ve web ikizi)', () {
    const adlar = {
      'mehmet ali': 'Mehmet Ali',
      'ışıl': 'Işıl',
      'ilker': 'İlker',
      'çiğdem': 'Çiğdem',
      'İLKER': 'İlker',
      'IŞIL': 'Işıl',
      '  ayşe   nur  ': 'Ayşe Nur',
      'ayşe-nur': 'Ayşe-Nur',
      'ÖMER FARUK': 'Ömer Faruk',
      'şükrü': 'Şükrü',
    };
    const soyadlar = {
      'yılmaz': 'YILMAZ',
      'öztürk': 'ÖZTÜRK',
      'işçi': 'İŞÇİ',
      'çiftçi': 'ÇİFTÇİ',
      '  kara   kaya ': 'KARA KAYA',
    };
    test('ad', () {
      adlar.forEach((g, b) => expect(adBicimle(g), b, reason: g));
    });
    test('soyad', () {
      soyadlar.forEach((g, b) => expect(soyadBicimle(g), b, reason: g));
    });
    test('varsayilan donusum YANLIS, Turkce dogru', () {
      expect('ilker'.toUpperCase(), 'ILKER');
      expect(trBuyuk('ilker'), 'İLKER');
      expect(trKucuk('I'), 'ı');
      expect(trKucuk('İ'), 'i');
    });
    test('yazarken bosluk silinmez', () {
      expect(adBicimle('mehmet ', yazarken: true), 'Mehmet ');
    });
    test('tam ad ve ayirma', () {
      expect(tamAd('Mehmet Ali', 'YILMAZ'), 'Mehmet Ali YILMAZ');
      final a = adAyir('Mehmet Ali YILMAZ', 'YILMAZ');
      expect((a.ad, a.soyad), ('Mehmet Ali', 'YILMAZ'));
      final b = adAyir('Ali Veli', null);
      expect((b.ad, b.soyad), ('Ali', 'Veli'));
      final c = adAyir('Tekad', null);
      expect((c.ad, c.soyad), ('Tekad', ''));
    });
  });

  testWidgets('personel ekleme: yazarken bicim, govdede ad + soyad ayri',
      (tester) async {
    final tel = await _sur(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('personel-ad')), 'mehmet ali');
    await tester.enterText(find.byKey(const Key('personel-soyad')), 'yılmaz');
    await tester.pumpAndSettle();
    expect(_metin(tester, 'personel-ad'), 'Mehmet Ali');
    expect(_metin(tester, 'personel-soyad'), 'YILMAZ');
    await tester.enterText(
        find.byKey(const Key('personel-eposta')), 'm@ornek.com');
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    final post =
        tel.istekler.singleWhere((i) => i.yol == '/users' && i.metot == 'POST');
    expect(post.govde['ad'], 'Mehmet Ali');
    expect(post.govde['soyad'], 'YILMAZ');
  });

  testWidgets('soyad bos: kayit ENGELLENIR', (tester) async {
    final tel = await _sur(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('personel-ad')), 'ilker');
    await tester.enterText(
        find.byKey(const Key('personel-eposta')), 'i@ornek.com');
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    expect(find.text('Ad ve soyad zorunludur.'), findsWidgets);
    expect(tel.istekler.where((i) => i.metot == 'POST'), isEmpty);
  });

  testWidgets('duzenleme: eski kayitta son kelime soyad onerilir',
      (tester) async {
    final tel = await _sur(tester);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Düzenle').last);
    await tester.pumpAndSettle();
    expect(_metin(tester, 'personel-ad'), 'Ali');
    expect(_metin(tester, 'personel-soyad'), 'Veli');
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    final patch = tel.istekler
        .singleWhere((i) => i.yol == '/users/g1' && i.metot == 'PATCH');
    expect(patch.govde['ad'], 'Ali');
    expect(patch.govde['soyad'], 'VELİ');
  });
}
