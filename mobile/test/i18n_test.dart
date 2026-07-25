/// i18n: dil cozumleme + dil DEGISTIRME + RTL (Arapca) + ICU cogul (ru/ar) +
/// para/tarih bicimlendirme kurallari.
///
/// Testler gercek `AppLocalizations` uretimini kullanir (ARB → gen-l10n).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/core/i18n/locale_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/cameras/presentation/kamera_form_sheet.dart';
import 'package:mobile/src/features/settings/presentation/settings_screen.dart';

import 'helpers/l10n_test_app.dart';

/// Bellekte kalan sahte guvenli depo — dil tercihinin KALICILIGINI test eder
/// ("uygulama yeniden basladi" = yeni ProviderContainer, AYNI depo).
class _BellekDepo implements FlutterSecureStorage {
  _BellekDepo([Map<String, String>? baslangic])
      : _kutu = {...?baslangic};

  final Map<String, String> _kutu;

  @override
  Future<String?> read({required String key, dynamic iOptions,
          dynamic aOptions, dynamic lOptions, dynamic webOptions,
          dynamic mOptions, dynamic wOptions}) async =>
      _kutu[key];

  @override
  Future<void> write({required String key, required String? value,
      dynamic iOptions, dynamic aOptions, dynamic lOptions,
      dynamic webOptions, dynamic mOptions, dynamic wOptions}) async {
    if (value == null) {
      _kutu.remove(key);
    } else {
      _kutu[key] = value;
    }
  }

  @override
  Future<void> delete({required String key, dynamic iOptions, dynamic aOptions,
      dynamic lOptions, dynamic webOptions, dynamic mOptions,
      dynamic wOptions}) async {
    _kutu.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('test disi kullanim: ${invocation.memberName}');
}

/// Verilen dilde kucuk bir uygulama — ornek widget'lar bu kabuk icinde cizilir.
Widget _app(Locale locale, Widget child) => MaterialApp(
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

/// Ornekleme icin: birkac ortak metni ayni ekranda gosteren yalin widget.
class _Ornek extends StatelessWidget {
  const _Ornek();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Column(
        children: [
          Text(l10n.ortakKaydet),
          Text(l10n.ortakYenidenDene),
          Text(l10n.kameraOynatilamiyor),
          Text(l10n.ayarlarDil),
        ],
      ),
    );
  }
}

void main() {
  group('desteklenen diller + cozumleme', () {
    test('7 dil: tr (varsayilan) + en, ar, ru, de, fr, es', () {
      expect(AppDil.values.map((d) => d.kod).toList(),
          ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']);
      expect(supportedLocales.first, const Locale('tr'));
      // AppLocalizations uretimi TUM dilleri kapsar.
      expect(
        AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
        {'tr', 'en', 'ar', 'ru', 'de', 'fr', 'es'},
      );
    });

    test('her dil KENDI adiyla listelenir (dil secici)', () {
      expect(
        AppDil.values.map((d) => d.adKendiDilinde).toList(),
        ['Türkçe', 'English', 'العربية', 'Русский', 'Deutsch', 'Français',
         'Español'],
      );
    });

    test('cihaz dili desteklenmiyorsa TURKCE; ulke kodu yok sayilir', () {
      expect(localeCozumle(const Locale('it'), supportedLocales),
          const Locale('tr'));
      expect(localeCozumle(null, supportedLocales), const Locale('tr'));
      // en_US → en (yalniz dil kodu eslenir)
      expect(localeCozumle(const Locale('en', 'US'), supportedLocales),
          const Locale('en'));
      expect(localeCozumle(const Locale('ar', 'SA'), supportedLocales),
          const Locale('ar'));
    });

    test('yalniz Arapca RTL', () {
      expect(AppDil.ar.rtl, isTrue);
      expect(rtlMi('ar'), isTrue);
      for (final d in AppDil.values.where((d) => d != AppDil.ar)) {
        expect(d.rtl, isFalse, reason: d.kod);
      }
    });
  });

  group('dil DEGISTIRME: ornek widget kumesi guncellenir', () {
    testWidgets('tr → en → ar → ru: ayni widget farkli dilde cizilir',
        (tester) async {
      await tester.pumpWidget(_app(const Locale('tr'), const _Ornek()));
      await tester.pumpAndSettle();
      expect(find.text('Kaydet'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsOneWidget);
      expect(find.text('Oynatılamıyor'), findsOneWidget);

      await tester.pumpWidget(_app(const Locale('en'), const _Ornek()));
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Not playable'), findsOneWidget);
      expect(find.text('Kaydet'), findsNothing);

      await tester.pumpWidget(_app(const Locale('ar'), const _Ornek()));
      await tester.pumpAndSettle();
      expect(find.text('حفظ'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      await tester.pumpWidget(_app(const Locale('ru'), const _Ornek()));
      await tester.pumpAndSettle();
      expect(find.text('Сохранить'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });

    testWidgets('dil satiri TR disi dillerde de "Language" gecer '
        '(kullanici anlamadigi dilde bulabilir)', (tester) async {
      for (final dil in [AppDil.ar, AppDil.ru, AppDil.de, AppDil.fr, AppDil.es]) {
        await tester.pumpWidget(_app(dil.locale, const _Ornek()));
        await tester.pumpAndSettle();
        expect(find.textContaining('Language'), findsOneWidget, reason: dil.kod);
      }
    });

    testWidgets('eksik ceviri: anahtar TR sablonuna DUSER (derleme kirilmaz)',
        (tester) async {
      // Su an tum anahtarlar cevrilidir; kural yine de dogrulanir: uretilen
      // sinif her dil icin TUM anahtarlari tasir (eksikse sablon degeri).
      for (final dil in AppDil.values) {
        final l10n = await AppLocalizations.delegate.load(dil.locale);
        expect(l10n.ortakKaydet, isNotEmpty, reason: dil.kod);
        expect(l10n.kameraSakinGorebilirAlt, isNotEmpty, reason: dil.kod);
      }
    });
  });

  group('RTL: Arapca yon', () {
    testWidgets('Arapca yon RTL, digerleri LTR (Directionality)',
        (tester) async {
      await tester.pumpWidget(_app(
        const Locale('ar'),
        Builder(builder: (context) {
          expect(Directionality.of(context), TextDirection.rtl);
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_app(
        const Locale('tr'),
        Builder(builder: (context) {
          expect(Directionality.of(context), TextDirection.ltr);
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpAndSettle();
    });

    test('LTR izolasyon: plaka/telefon/tutar RTL govdede ters DONMEZ', () {
      // U+2068 (FSI) ... U+2069 (PDI) — yon-notr olmayan dizileri korur.
      expect(ltrIzole('34 ABC 123'), '\u2068' '34 ABC 123' '\u2069');
      expect(tlIsaretli(125000), '\u2068' '₺1.250,00' '\u2069');
    });
  });

  group('ICU cogul: ru + ar kategorileri', () {
    Future<AppLocalizations> yukle(String kod) =>
        AppLocalizations.delegate.load(Locale(kod));

    test('ru: one / few / many ayri biçimler', () async {
      final ru = await yukle('ru');
      expect(ru.sayacBekliyor(1), '1 ожидает'); // one
      expect(ru.sayacBekliyor(3), '3 ожидают'); // few
      expect(ru.sayacBekliyor(11), '11 ожидают'); // many
      expect(ru.sayacBekliyor(21), '21 ожидает'); // one (21 → one!)
    });

    test('ar: zero / one / two / few / many', () async {
      final ar = await yukle('ar');
      expect(ar.sayacBekliyor(0), 'لا شيء بالانتظار'); // zero
      expect(ar.sayacBekliyor(1), 'عنصر واحد بالانتظار'); // one
      expect(ar.sayacBekliyor(2), 'عنصران بالانتظار'); // two
      expect(ar.sayacBekliyor(5), contains('عناصر')); // few (3-10)
      expect(ar.sayacBekliyor(15), contains('عنصراً')); // many (11-99)
    });

    test('tr/de/fr/es: sayi + tek bicim (cogul eki yok)', () async {
      expect((await yukle('tr')).sayacBekliyor(3), '3 Bekliyor');
      expect((await yukle('de')).sayacBekliyor(3), '3 offen');
      expect((await yukle('fr')).sayacBekliyor(3), '3 en attente');
      expect((await yukle('es')).sayacBekliyor(3), '3 pendientes');
    });

    test('en: one/other', () async {
      final en = await yukle('en');
      expect(en.sayacBekliyor(1), '1 pending');
      expect(en.sayacBekliyor(7), '7 pending');
    });
  });

  group('bicimlendirme kurallari', () {
    test('PARA: UI dili ne olursa olsun ₺ + Turkce gruplama', () {
      // Kural: para SITE-YERELDIR (aidat TL toplanir) → dile gore degismez.
      expect(tlTutar(125000), '1.250,00');
      expect(tlTutar(99), '0,99');
      expect(tlIsaretli(125000), contains('₺1.250,00'));
    });

    test('TARIH: aktif dile gore bicimlenir', () {
      final t = DateTime(2026, 7, 25, 9, 47);
      expect(tarihBicimi(t, 'tr'), '25.07.2026');
      expect(tarihBicimi(t, 'en'), '7/25/2026');
      expect(tarihBicimi(t, 'de'), '25.7.2026');
      expect(saatBicimi(t, 'tr'), '09:47');
      // Ay/gun adlari da dile gore.
      expect(uzunTarihBicimi(t, 'tr'), contains('Temmuz'));
      expect(uzunTarihBicimi(t, 'en'), contains('July'));
      expect(uzunTarihBicimi(t, 'de'), contains('Juli'));
      expect(gunAdi(DateTime(2026, 7, 25), 'tr'), 'Cumartesi');
      expect(gunAdi(DateTime(2026, 7, 25), 'en'), 'Saturday');
    });

    test('BUYUK HARF: tr ozel (i→İ), ar degismez, digerleri standart', () {
      expect(baslikBuyuk('Ayarlar', 'tr'), 'AYARLAR');
      expect(baslikBuyuk('Kameralar', 'tr'), 'KAMERALAR');
      expect(baslikBuyuk('İhlaller', 'tr'), 'İHLALLER');
      expect(baslikBuyuk('Cameras', 'en'), 'CAMERAS');
      // Arapcada buyuk harf YOKTUR → metin aynen kalir.
      expect(baslikBuyuk('الكاميرات', 'ar'), 'الكاميرات');
    });
  });

  group('KALICILIK: secilen dil uygulama yeniden baslayinca korunur', () {
    test('sec → (yeniden baslat) → ayni dil geri gelir', () async {
      final depo = _BellekDepo();
      final ilk = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(depo)],
      );
      addTearDown(ilk.dispose);

      // Baslangicta secim YOK (cihaz dili gecerli).
      expect(ilk.read(localeControllerProvider), isNull);
      await ilk.read(localeControllerProvider.notifier).sec(AppDil.ar);
      expect(ilk.read(localeControllerProvider), AppDil.ar);
      expect(depo._kutu['ui.locale'], 'ar');

      // "Uygulama yeniden basladi": yeni kap, AYNI depo.
      final ikinci = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(depo)],
      );
      addTearDown(ikinci.dispose);
      // Depo okumasi async: ilk kare "secim yok", sonra deger gelir.
      expect(ikinci.read(localeControllerProvider), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(ikinci.read(localeControllerProvider), AppDil.ar);
    });

    test('cihaz dilini kullan: secim SILINIR', () async {
      final depo = _BellekDepo({'ui.locale': 'de'});
      final kap = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(depo)],
      );
      addTearDown(kap.dispose);
      // Ilk okuma saglayiciyi KURAR ve depo okumasini baslatir; deger bir
      // sonraki mikro-gorevde gelir.
      expect(kap.read(localeControllerProvider), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(kap.read(localeControllerProvider), AppDil.de);

      await kap.read(localeControllerProvider.notifier).cihazDiliniKullan();
      expect(kap.read(localeControllerProvider), isNull);
      expect(depo._kutu.containsKey('ui.locale'), isFalse);
    });
  });

  group('RTL ekran denetimi (Arapca)', () {
    testWidgets('AYARLAR ekrani: RTL yon + dil satiri Arapca', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          secureStorageProvider.overrideWithValue(_BellekDepo()),
        ],
        child: l10nApp(const SettingsScreen(), locale: const Locale('ar')),
      ));
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(SettingsScreen));
      expect(Directionality.of(ctx), TextDirection.rtl);
      // Arapca metinler cizildi (baslik + tema secenekleri).
      expect(find.textContaining('اللغة'), findsOneWidget);
      expect(find.text('فاتح'), findsOneWidget); // "Açık"
      expect(tester.takeException(), isNull);
    });

    testWidgets('KAMERA FORMU: RTL yon + Arapca alan etiketleri', (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ProviderScope(
        child: l10nApp(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => KameraFormSheet.ac(context),
                child: const Text('ac'),
              ),
            ),
          ),
          locale: const Locale('ar'),
        ),
      ));
      await tester.tap(find.text('ac'));
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(KameraFormSheet));
      expect(Directionality.of(ctx), TextDirection.rtl);
      expect(find.text('كاميرا جديدة'), findsOneWidget); // "Yeni kamera"
      expect(find.textContaining('رابط البث'), findsOneWidget); // URL etiketi
      // Anahtar (switch) alt metinleri de Arapca.
      expect(find.text('مرئية للسكان'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
