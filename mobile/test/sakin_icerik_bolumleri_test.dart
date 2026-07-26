/// Sakin ana ekraninin ICERIK bolumleri — "Site Kuralları" + "Etkinlikler".
///
/// Iddialar: duyuru kartiyla ayni desen; gorsel VARSA yuklenir, YOKSA yer
/// tutucu (kart bozulmaz); bolum bos ise HIC cizilmez; "Tümünü Gör" ve satir
/// dokunmasi ayri hedefler verir; etkinlik cipi suren/yaklasan ayrimini
/// SUNUCU verisinden turer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/gen/app_localizations.dart';
import 'package:mobile/src/core/theme/home_tokens.dart';
import 'package:mobile/src/features/etkinlik/domain/etkinlik_models.dart';
import 'package:mobile/src/features/home/domain/home_view_models.dart';
import 'package:mobile/src/features/home/presentation/home_mappers.dart';
import 'package:mobile/src/features/home/presentation/widgets/icerik_bolumu.dart';
import 'package:mobile/src/features/site_kurali/domain/site_kurali_models.dart';
import 'helpers/l10n_test_app.dart';


SiteKurali _kural(String baslik, {String? fotoUrl}) => SiteKurali(
      id: 'k-$baslik',
      baslik: baslik,
      icerik: 'Kural metni: $baslik',
      sira: 1,
      olusturanUserId: 'y1',
      createdAt: DateTime(2026, 7, 1),
      fotoKey: fotoUrl == null ? null : 'tenant/seed/x.png',
      fotoUrl: fotoUrl,
    );

Etkinlik _etkinlik({
  required String baslik,
  required DateTime tarih,
  DateTime? bitis,
  String? fotoUrl,
  String? konum,
}) =>
    Etkinlik(
      id: 'e-$baslik',
      baslik: baslik,
      aciklama: 'Etkinlik açıklaması',
      tarih: tarih,
      bitisZamani: bitis,
      konum: konum,
      fotoUrl: fotoUrl,
      olusturanUserId: 'y1',
      katiliyorumSayisi: 0,
      katilmiyorumSayisi: 0,
      createdAt: DateTime(2026, 7, 1),
    );

late AppLocalizations trL10n;

void main() {
  setUpAll(() async {
    // Testler TR'ye sabit (mevcut metin beklentileri korunur).
    trL10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  group('IcerikBolumu — duyuru kartiyla ayni desen', () {
    testWidgets('kurallar: baslik + icerik + yer tutucu (gorsel YOK)',
        (tester) async {
      await tester.pumpWidget(l10nScaffold(IcerikBolumu(
        baslik: 'Site Kuralları',
        satirlar: kuralOzetleri([_kural('Otopark Kullanımı')]),
        onTumu: () {},
      )));

      expect(find.text('Site Kuralları'), findsOneWidget);
      expect(find.text('Otopark Kullanımı'), findsOneWidget);
      expect(find.text('Kural metni: Otopark Kullanımı'), findsOneWidget);
      // Gorsel yok → yer tutucu ikonu (kural ikonu), Image widget'i YOK.
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('kurallar: gorsel VARSA Image cizilir', (tester) async {
      await tester.pumpWidget(l10nScaffold(IcerikBolumu(
        baslik: 'Site Kuralları',
        satirlar: kuralOzetleri([
          _kural('Otopark Kullanımı', fotoUrl: 'https://x/y.png'),
        ]),
        onTumu: () {},
      )));
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsNothing);
    });

    testWidgets('bos liste: bolum HIC cizilmez', (tester) async {
      await tester.pumpWidget(l10nScaffold(IcerikBolumu(
        baslik: 'Etkinlikler',
        satirlar: const <IcerikOzeti>[],
        onTumu: () {},
      )));
      expect(find.text('Etkinlikler'), findsNothing);
    });

    testWidgets('"Tümünü Gör" ve SATIR dokunmasi ayri hedeflere gider',
        (tester) async {
      var tumu = 0;
      IcerikOzeti? secilen;
      await tester.pumpWidget(l10nScaffold(IcerikBolumu(
        baslik: 'Site Kuralları',
        satirlar: kuralOzetleri([_kural('Havuz Saatleri')]),
        onTumu: () => tumu++,
        onSec: (o) => secilen = o,
      )));

      await tester.tap(find.text('Tümünü Gör'));
      expect(tumu, 1);
      await tester.tap(find.text('Havuz Saatleri'));
      expect(secilen?.baslik, 'Havuz Saatleri');
    });

    testWidgets('3 kayit: bolum 3 kart cizer (ana ekran sinirli)',
        (tester) async {
      await tester.pumpWidget(l10nScaffold(IcerikBolumu(
        baslik: 'Site Kuralları',
        satirlar: kuralOzetleri([
          _kural('Bir'),
          _kural('İki'),
          _kural('Üç'),
        ]),
        onTumu: () {},
      )));
      for (final b in ['Bir', 'İki', 'Üç']) {
        expect(find.text(b), findsOneWidget, reason: b);
      }
    });
  });

  group('etkinlikOzetleri — cip + tarih SUNUCU verisinden', () {
    test('yaklasan etkinlik: "Yaklaşan" cipi (mavi) + tarih/saat', () {
      final ileri = DateTime.now().add(const Duration(days: 2));
      final o = etkinlikOzetleri(trL10n, 'tr', [
        _etkinlik(baslik: 'Bahar şenliği', tarih: ileri, konum: 'Bahçe'),
      ]).single;

      expect(o.cip, 'Yaklaşan');
      expect(o.cipAccent, HomeTokens.primary);
      expect(o.altMetin, startsWith('Bahçe · '));
      expect(o.tarih, contains('·')); // "gg.aa.yyyy · ss:dd"
      expect(o.ikon, Icons.event_available_outlined);
    });

    test('SUREN etkinlik (basladi, bitmedi): "Sürüyor" cipi (yesil)', () {
      final o = etkinlikOzetleri(trL10n, 'tr', [
        _etkinlik(
          baslik: 'Maç',
          tarih: DateTime.now().subtract(const Duration(hours: 1)),
          bitis: DateTime.now().add(const Duration(hours: 2)),
        ),
      ]).single;

      expect(o.cip, 'Sürüyor');
      expect(o.cipAccent, HomeTokens.green);
    });

    test('bitis alani: gecmis/suruyor kararini COALESCE gibi verir', () {
      final suren = _etkinlik(
        baslik: 'S',
        tarih: DateTime.now().subtract(const Duration(hours: 1)),
        bitis: DateTime.now().add(const Duration(hours: 1)),
      );
      final anlikGecmis = _etkinlik(
        baslik: 'A',
        tarih: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(suren.gecmis, isFalse);
      expect(suren.suruyor, isTrue);
      expect(anlikGecmis.gecmis, isTrue);
      expect(anlikGecmis.bitis, anlikGecmis.tarih);
    });

    test('gorsel: foto_url dogrudan tasinir (presigned GET)', () {
      final o = etkinlikOzetleri(trL10n, 'tr', [
        _etkinlik(
          baslik: 'G',
          tarih: DateTime.now().add(const Duration(days: 1)),
          fotoUrl: 'https://minio/x.png?X-Amz-Signature=abc',
        ),
      ]).single;
      expect(o.fotoUrl, contains('X-Amz-Signature'));
    });
  });
}
