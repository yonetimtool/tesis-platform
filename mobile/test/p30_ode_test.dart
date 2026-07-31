/// P30 — sakin "Öde" ekrani: havale kodu + IBAN + kart.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/dues/data/odeme_api.dart';
import 'package:mobile/src/features/dues/presentation/ode_screen.dart';

import 'helpers/l10n_test_app.dart';

Dio _dio(Map<String, dynamic> bilgi, {List<Map<String, dynamic>>? kartYanit}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
    if (o.path.contains('odeme-bilgileri')) {
      return h.resolve(
        Response(requestOptions: o, statusCode: 200, data: bilgi),
      );
    }
    return h.resolve(Response(
      requestOptions: o,
      statusCode: 201,
      data: kartYanit?.first ?? {'durum': 'basarili'},
    ));
  }));
  return dio;
}

Future<void> _ac(WidgetTester tester, Map<String, dynamic> bilgi) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dioProvider.overrideWithValue(_dio(bilgi))],
      child: l10nApp(const OdeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

const _tam = {
  'iban': 'TR330006100519786457841326',
  'banka_adi': 'Ziraat',
  'odeme_kodu': 'TS-A7K2M9',
  'borc_kurus': 125050,
  'kart_aktif': false,
};

void main() {
  group('P30 — model', () {
    test('IBAN null ise havale GIZLENIR sinyali', () {
      final b = OdemeBilgileri.fromJson(const {
        'odeme_kodu': 'TS-AAAAAA', 'borc_kurus': 0, 'kart_aktif': false,
      });
      expect(b.iban, isNull);
      expect(b.kartAktif, isFalse);
    });

    test('kart sonucu: yalniz "basarili" basarilidir', () {
      expect(KartOdemeSonuc.fromJson(const {'durum': 'basarili'}).basarili, isTrue);
      expect(KartOdemeSonuc.fromJson(const {'durum': 'beklemede'}).basarili, isFalse);
    });
  });

  group('P30 — Öde ekrani', () {
    testWidgets('IBAN + KOD + borc gorunur', (tester) async {
      await _ac(tester, _tam);
      expect(find.textContaining('TR33'), findsOneWidget);
      expect(find.text('TS-A7K2M9'), findsOneWidget);
      expect(find.textContaining('1.250,50'), findsWidgets);
      // Kod VURGULU: kullanici onu aciklamaya yazacak.
      final kod = tester.widget<SelectableText>(
        find.widgetWithText(SelectableText, 'TS-A7K2M9'),
      );
      expect(kod.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('KOD kopyalanabilir', (tester) async {
      final panoda = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            panoda.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      await _ac(tester, _tam);
      await tester.tap(find.text('Kopyala').last);
      await tester.pumpAndSettle();
      expect(panoda, contains('TS-A7K2M9'));
    });

    testWidgets('IBAN YOKSA havale hic CIZILMEZ, yerine aciklama', (tester) async {
      await _ac(tester, {..._tam, 'iban': null, 'banka_adi': null});
      expect(find.textContaining('TR33'), findsNothing);
      expect(find.text('TS-A7K2M9'), findsNothing);
      expect(
        find.textContaining('banka hesabı tanımlamamış'),
        findsOneWidget,
      );
    });

    testWidgets('kart KAPALIYKEN buton yok, aciklama var', (tester) async {
      await _ac(tester, _tam);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.textContaining('Kart ödemesi henüz açık değil'), findsOneWidget);
    });

    testWidgets('kart ACIKKEN buton var; borc YOKSA pasif', (tester) async {
      await _ac(tester, {..._tam, 'kart_aktif': true});
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull);

      await _ac(tester, {..._tam, 'kart_aktif': true, 'borc_kurus': 0});
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull, reason: 'borc yokken odeme baslatilmamali');
    });

    testWidgets('kopyala dokunma hedefi 48 dp', (tester) async {
      await _ac(tester, _tam);
      final boy = tester.getSize(find.byType(TextButton).first).height;
      expect(boy, greaterThanOrEqualTo(48.0));
    });
  });

  group('P30 — 7 dil', () {
    testWidgets('yeni metinler BOS DEGIL ve TR sizmaz', (tester) async {
      const trHarf = 'ğışĞİŞ';
      for (final dil in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
        late AppLocalizations l10n;
        await tester.pumpWidget(l10nApp(
          Builder(builder: (ctx) {
            l10n = ctx.l10n;
            return const SizedBox.shrink();
          }),
          locale: Locale(dil),
        ));
        await tester.pumpAndSettle();
        for (final m in [
          l10n.odeBaslik, l10n.odeBorcunuz, l10n.odeHavaleBaslik,
          l10n.odeHavaleAdim, l10n.odeKodBaslik, l10n.odeKopyala,
          l10n.odeKartBaslik, l10n.odeKartKapali, l10n.odeHavaleKapali,
          l10n.odeBorcYok, l10n.odeBasarili,
        ]) {
          expect(m.trim(), isNotEmpty, reason: dil);
          if (dil != 'tr') {
            expect(m.split('').any(trHarf.contains), isFalse,
                reason: '$dil TR harfi: $m');
          }
        }
      }
    });
  });
}
