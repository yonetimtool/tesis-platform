/// (P239 §7) ANKET SECENEKLERI — AYRI KUTULAR, "+" ILE EKLE, TEK TEK SIL.
///
/// =========================================================================
/// OLCULEN KUSUR
/// =========================================================================
/// Secenekler TEK cok-satirli metin alanindaydi ("satir basina bir
/// madde"). Kullanici kac secenek yazdigini goremiyor, bos satir sessizce
/// yutuluyor, bir secenegi silmek satiri isaretlemeyi gerektiriyordu.
/// Mobil klavyede satir sonu koymak zaten fazladan bir dokunus — eski
/// gerekce ("ayri alan acmak isi uc dokunusa cikarir") olcumde tutmadi.
///
/// GONDERILEN TASLAK DEGISMEDI: madde METINLERI listesi. Son test tam
/// olarak onu olcer — arka uc ve MEVCUT ANKETLER etkilenmesin diye.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/anket/data/anket_api.dart';
import 'package:mobile/src/features/anket/domain/anket_models.dart';
import 'package:mobile/src/features/anket/presentation/anket_form.dart';

import 'helpers/l10n_test_app.dart';

class _SahteAnketApi implements AnketApi {
  AnketTaslak? gonderilen;

  @override
  Future<List<Anket>> liste() async => const [];

  @override
  Future<Anket> olustur(AnketTaslak taslak) async {
    gonderilen = taslak;
    return _bos();
  }

  @override
  Future<Anket> kapat(String anketId) async => _bos();

  @override
  Future<List<AnketOyKim>> oyDokumu(String anketId) async => const [];

  @override
  Future<Anket> oyVer(String anketId, String secenekId) async => _bos();
}

Anket _bos() => Anket(
      id: 'a1',
      baslik: 'x',
      acik: true,
      anonim: false,
      secenekler: const [],
    );

Widget _form(_SahteAnketApi api) => ProviderScope(
      overrides: [anketApiProvider.overrideWithValue(api)],
      child: l10nApp(const Scaffold(body: AnketFormSayfasi())),
    );

/// Silme dugmesinin ETKIN olup olmadigi — `onPressed == null` KAPALI.
bool silmeAcik(WidgetTester tester, int i) =>
    tester
        .widget<IconButton>(find.byKey(Key('anket-madde-sil-$i')))
        .onPressed !=
    null;

void main() {
  testWidgets('IKI KUTU ACIK BASLAR, ucuncu YOK', (tester) async {
    await tester.pumpWidget(_form(_SahteAnketApi()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('anket-madde-0')), findsOneWidget);
    expect(find.byKey(const Key('anket-madde-1')), findsOneWidget);
    expect(find.byKey(const Key('anket-madde-2')), findsNothing);
  });

  testWidgets('"+" HER BASISTA BIR KUTU EKLER', (tester) async {
    await tester.pumpWidget(_form(_SahteAnketApi()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('anket-madde-ekle')));
    await tester.tap(find.byKey(const Key('anket-madde-ekle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('anket-madde-2')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('anket-madde-ekle')));
    await tester.tap(find.byKey(const Key('anket-madde-ekle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('anket-madde-3')), findsOneWidget);
  });

  testWidgets('IKI KUTUDA SILME KAPALI — gizli DEGIL, KAPALI', (tester) async {
    // Gizlenen dugme "neden yok" sorusunu dogurur; KAPALI dugme, ipucu
    // metniyle KURALI soyler.
    await tester.pumpWidget(_form(_SahteAnketApi()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('anket-madde-sil-0')), findsOneWidget);
    expect(silmeAcik(tester, 0), isFalse);
    expect(silmeAcik(tester, 1), isFalse);
  });

  testWidgets('UC KUTUDA SILME ACILIR ve DOGRU kutuyu siler', (tester) async {
    await tester.pumpWidget(_form(_SahteAnketApi()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('anket-madde-ekle')));
    await tester.tap(find.byKey(const Key('anket-madde-ekle')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('anket-madde-0')), 'A');
    await tester.enterText(find.byKey(const Key('anket-madde-1')), 'B');
    await tester.enterText(find.byKey(const Key('anket-madde-2')), 'C');
    await tester.pumpAndSettle();

    expect(silmeAcik(tester, 1), isTrue);
    await tester.ensureVisible(find.byKey(const Key('anket-madde-sil-1')));
    await tester.tap(find.byKey(const Key('anket-madde-sil-1')));
    await tester.pumpAndSettle();

    // ORTADAKI gitti: kalanlar A ve C — ve silme YENIDEN kapandi.
    expect(find.byKey(const Key('anket-madde-2')), findsNothing);
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('anket-madde-1')))
            .controller!
            .text,
        'C');
    expect(silmeAcik(tester, 0), isFalse);
  });

  testWidgets('TASLAK DEGISMEDI: metin listesi, BOS kutular ATILIR',
      (tester) async {
    final api = _SahteAnketApi();
    await tester.pumpWidget(_form(api));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('anket-baslik')), 'Otopark');
    await tester.ensureVisible(find.byKey(const Key('anket-madde-ekle')));
    await tester.tap(find.byKey(const Key('anket-madde-ekle')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('anket-madde-0')), 'Evet');
    // 1 BOS BIRAKILIR — bosluk taslaga GIRMEMELI.
    await tester.enterText(find.byKey(const Key('anket-madde-2')), 'Hayır');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('anket-kaydet')));
    await tester.tap(find.byKey(const Key('anket-kaydet')));
    await tester.pumpAndSettle();

    expect(api.gonderilen?.maddeler, ['Evet', 'Hayır']);
  });
}
