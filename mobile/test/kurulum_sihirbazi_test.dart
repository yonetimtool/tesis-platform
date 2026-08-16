/// (P166 §8.2) KURULUM SIHIRBAZI — MOBIL.
///
/// Olculen sey WEB ILE ESITLIK ve CIKMAZ YOKLUGU:
///   * sekiz adim cizilir, ilerleme sunucudan gelen sayilardan okunur,
///   * tamamlanan/atlanan/bekleyen uc durum AYIRT EDILIR,
///   * atlama sunucuya GIDER ve geri alinabilir,
///   * ekrani OLMAYAN adimda (aidat) calismayacak bir dugme CIZILMEZ —
///     yerine nedeni yazilir. Bu turun ana kurali buydu.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/kurulum/data/kurulum_api.dart';
import 'package:mobile/src/features/kurulum/domain/kurulum_models.dart';
import 'package:mobile/src/features/kurulum/presentation/kurulum_screen.dart';

import 'helpers/l10n_test_app.dart';

/// Sunucunun dondugu sekiz adim — kodlar `routers/kurulum.py` ile AYNI.
const _kodlar = [
  'blok',
  'daire',
  'daire_tipi',
  'sakin',
  'personel',
  'gorev_alani',
  'nfc_noktasi',
  'aidat',
];

KurulumDurum _durum({
  Set<String> tamam = const {},
  Set<String> atlanan = const {},
}) {
  final adimlar = [
    for (final k in _kodlar)
      KurulumAdim(
        kod: k,
        sayi: tamam.contains(k) ? 3 : 0,
        tamam: tamam.contains(k),
        atlandi: atlanan.contains(k),
      ),
  ];
  return KurulumDurum(
    adimlar: adimlar,
    toplam: adimlar.length,
    gecilen: adimlar.where((a) => a.tamam || a.atlandi).length,
  );
}

class _SahteApi extends KurulumApi {
  _SahteApi({KurulumDurum? baslangic, this.hata})
    : _durumu = baslangic ?? _durum(),
      super(Dio());

  KurulumDurum _durumu;
  final Object? hata;
  final atlananlar = <({String kod, bool atla})>[];

  @override
  Future<KurulumDurum> durum() async => _durumu;

  @override
  Future<KurulumDurum> atla(String kod, {required bool atla}) async {
    atlananlar.add((kod: kod, atla: atla));
    if (hata != null) throw hata!;
    _durumu = _durum(atlanan: atla ? {kod} : const {});
    return _durumu;
  }
}

Widget _ekran(_SahteApi api) => ProviderScope(
  overrides: [kurulumApiProvider.overrideWithValue(api)],
  child: l10nApp(const KurulumScreen(), locale: const Locale('tr')),
);

/// UZUN EKRAN: `ListView` tembel cizer ve varsayilan 800px'lik test
/// tuvalinde sekiz adimin yalnizca bir kismi AGACA GIRER. "Alti dugme
/// var mi" gibi bir olcum o durumda kodu degil TUVALI olcerdi.
void _uzunEkran(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('(P166 §8.2) sihirbaz cizimi', () {
    testWidgets('SEKIZ ADIM da cizilir', (tester) async {
      _uzunEkran(tester);
      await tester.pumpWidget(_ekran(_SahteApi()));
      await tester.pumpAndSettle();
      // Adim basliklarindan birkacini ornekle: hepsi ayni desenle cizilir.
      for (final baslik in ['Bloklar', 'Daireler', 'Personel', 'NFC noktaları']) {
        expect(find.text(baslik), findsOneWidget, reason: baslik);
      }
      expect(find.byType(Card), findsNWidgets(_kodlar.length + 1)); // +ilerleme
    });

    testWidgets('ILERLEME SUNUCUDAN OKUNUR (istemci saymaz)', (tester) async {
      _uzunEkran(tester);
      await tester.pumpWidget(
        _ekran(_SahteApi(baslangic: _durum(tamam: {'blok', 'daire'}))),
      );
      await tester.pumpAndSettle();
      expect(find.text('2/8 adım'), findsOneWidget);
    });

    testWidgets('UC DURUM AYIRT EDILIR: tamam / atlandi / bekliyor', (
      tester,
    ) async {
      _uzunEkran(tester);
      await tester.pumpWidget(
        _ekran(
          _SahteApi(baslangic: _durum(tamam: {'blok'}, atlanan: {'personel'})),
        ),
      );
      await tester.pumpAndSettle();
      // Tamamlanan adim SAYIYI gosterir ("bitti" demekten cok sey soyler).
      expect(find.text('3 kayıt'), findsOneWidget);
      expect(find.text('Atlandı'), findsOneWidget);
      expect(find.text('Bekliyor'), findsWidgets);
    });
  });

  group('(P166 §8.2) CIKMAZ YOK', () {
    testWidgets('EKRANI OLMAYAN adimda dugme YOK, NEDEN yazili', (
      tester,
    ) async {
      _uzunEkran(tester);
      await tester.pumpWidget(_ekran(_SahteApi()));
      await tester.pumpAndSettle();
      // `aidat` adimi: mobilde ekran yok + uc admin'e kilitli.
      expect(
        find.textContaining('yalnızca web panelinden'),
        findsOneWidget,
        reason: 'neden yazilmali',
      );
      // Yedi adim gidilebilir, sekizincisi degil.
      expect(find.widgetWithText(FilledButton, 'Git'), findsNWidgets(7));
    });

    testWidgets('TAMAMLANAN adimda "Görüntüle", atlama dugmesi YOK', (
      tester,
    ) async {
      _uzunEkran(tester);
      await tester.pumpWidget(
        _ekran(_SahteApi(baslangic: _durum(tamam: {'blok'}))),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Görüntüle'), findsOneWidget);
      // Atlama YALNIZ bitmemis adimda: biten bir adimi atlamak kullaniciya
      // hicbir sey kazandirmaz.
      expect(find.widgetWithText(TextButton, 'Atla'), findsNWidgets(6));
    });
  });

  group('(P166 §8.2) atlama', () {
    testWidgets('ATLAMA SUNUCUYA GIDER ve GERI ALINABILIR', (tester) async {
      _uzunEkran(tester);
      final api = _SahteApi();
      await tester.pumpWidget(_ekran(api));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Atla').first);
      await tester.pumpAndSettle();
      expect(api.atlananlar, [(kod: 'blok', atla: true)]);
      // Sunucunun yeni durumu cizildi: satir artik "Atlamayı geri al" der.
      expect(find.widgetWithText(TextButton, 'Atlamayı geri al'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Atlamayı geri al'));
      await tester.pumpAndSettle();
      expect(api.atlananlar.last, (kod: 'blok', atla: false));
    });

    testWidgets('HATA SESSIZ KALMAZ — ekranda kalir', (tester) async {
      _uzunEkran(tester);
      final api = _SahteApi(
        hata: const ApiException(code: 'server_error', message: 'Sunucu hatası', statusCode: 500),
      );
      await tester.pumpWidget(_ekran(api));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Atla').first);
      await tester.pumpAndSettle();
      expect(find.text('Sunucu hatası'), findsOneWidget);
    });
  });
}
