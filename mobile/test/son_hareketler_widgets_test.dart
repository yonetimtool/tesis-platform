import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/theme/home_tokens.dart';
import 'package:mobile/src/features/announcements/domain/announcement_models.dart';
import 'package:mobile/src/features/home/domain/son_hareketler.dart';
import 'package:mobile/src/features/home/presentation/home_mappers.dart';
import 'package:mobile/src/features/home/presentation/widgets/duyuru_karti.dart';
import 'package:mobile/src/features/home/presentation/widgets/son_hareketler_karti.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('SonHareketlerKarti — TEK kart + 1px ayracli satirlar (referans)', () {
    final hareketler = [
      Hareket(
          tip: HareketTip.kargoTeslim,
          baslik: 'Kargo Teslim Edildi',
          altBaslik: 'Mng - Daire 12',
          zaman: DateTime(2026, 7, 23, 9, 47)),
      Hareket(
          tip: HareketTip.aidatOdeme,
          baslik: 'Aidat Ödemesi',
          altBaslik: '₺1.250,00',
          zaman: DateTime(2026, 7, 22, 10, 0)),
    ];

    testWidgets('baslik + satirlar + zaman etiketleri (bugun HH:mm, dun Dün)',
        (tester) async {
      await tester.pumpWidget(_wrap(SonHareketlerKarti(
        satirlar: hareketSatirlari(hareketler, DateTime(2026, 7, 23, 14, 0)),
      )));
      expect(find.text('Son Hareketler'), findsOneWidget);
      expect(find.text('Kargo Teslim Edildi'), findsOneWidget);
      expect(find.text('09:47'), findsOneWidget);
      expect(find.text('Dün'), findsOneWidget);
      // N satir arasinda N-1 ayrac.
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('bos akis: bolum HIC cizilmez', (tester) async {
      await tester.pumpWidget(_wrap(const SonHareketlerKarti(satirlar: [])));
      expect(find.text('Son Hareketler'), findsNothing);
    });

    testWidgets('satir dokunmasi geri bildirilir', (tester) async {
      var secim = 0;
      await tester.pumpWidget(_wrap(SonHareketlerKarti(
        satirlar: hareketSatirlari(hareketler, DateTime(2026, 7, 23, 14, 0)),
        onSatir: (_) => secim++,
      )));
      await tester.tap(find.text('Kargo Teslim Edildi'));
      expect(secim, 1);
    });
  });

  group('hareketSatirlari — ikon rengi MODUL, nokta OLAY durumu', () {
    test('aidat odemesi: mavi cuzdan ikonu + yesil durum noktasi', () {
      final satir = hareketSatirlari([
        Hareket(
            tip: HareketTip.aidatOdeme,
            baslik: 'Aidat Ödemesi',
            altBaslik: 'Mayıs 2026',
            zaman: DateTime(2026, 5, 5)),
      ], DateTime(2026, 7, 23)).single;

      expect(satir.ikonAccent, HomeTokens.primary);
      expect(satir.noktaRengi, HomeTokens.green);
    });
  });

  group('DuyuruKarti', () {
    Announcement duyuru(DateTime t) => Announcement(
          id: 'd1',
          baslik: 'Bahçe Düzenlemesi',
          govde: 'Site bahçemizde peyzaj düzenlemesi yapılacaktır.',
          olusturanUserId: 'y1',
          createdAt: t,
          updatedAt: t,
        );

    testWidgets('son duyuru: baslik + govde ozeti; yeni (<=3 gun) "Yeni" cipi',
        (tester) async {
      var tumu = 0;
      await tester.pumpWidget(_wrap(DuyuruKarti(
        duyuru: duyuruOzeti(duyuru(DateTime(2026, 7, 22, 9, 0)),
            DateTime(2026, 7, 23)),
        onTumu: () => tumu++,
      )));
      expect(find.text('Duyurular'), findsOneWidget);
      expect(find.text('Bahçe Düzenlemesi'), findsOneWidget);
      expect(find.textContaining('peyzaj'), findsOneWidget);
      expect(find.text('Yeni'), findsOneWidget);

      await tester.tap(find.text('Tümünü Gör'));
      expect(tumu, 1);
    });

    testWidgets('eski duyuru (>3 gun): "Yeni" cipi YOK', (tester) async {
      await tester.pumpWidget(_wrap(DuyuruKarti(
        duyuru: duyuruOzeti(
            duyuru(DateTime(2026, 7, 10)), DateTime(2026, 7, 23)),
        onTumu: () {},
      )));
      expect(find.text('Yeni'), findsNothing);
    });

    testWidgets('foto YOKken gri yer tutucu cizilir (kart bozulmaz)',
        (tester) async {
      await tester.pumpWidget(_wrap(DuyuruKarti(
        duyuru: duyuruOzeti(
            duyuru(DateTime(2026, 7, 22)), DateTime(2026, 7, 23)),
        onTumu: () {},
      )));
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });
}
