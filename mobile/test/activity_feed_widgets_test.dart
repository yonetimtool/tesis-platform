import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/theme/home_tokens.dart';
import 'package:mobile/src/features/announcements/domain/announcement_models.dart';
import 'package:mobile/src/features/home/domain/activity_models.dart';
import 'package:mobile/src/features/home/domain/home_view_models.dart';
import 'package:mobile/src/features/home/presentation/home_mappers.dart';
import 'package:mobile/src/features/home/presentation/widgets/duyuru_karti.dart';
import 'package:mobile/src/features/home/presentation/widgets/son_hareketler_karti.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('SonHareketlerKarti — TEK kart + 1px ayracli satirlar (referans)', () {
    final hareketler = [
      ActivityItem(
          id: 'kargo_teslim:k1',
          tur: ActivityTur.kargoTeslim,
          baslik: 'Kargo Teslim Edildi',
          altMetin: 'Mng — Daire 12',
          zaman: DateTime(2026, 7, 23, 9, 47),
          renk: ActivityRenk.olumlu,
          kaynakId: 'k1'),
      ActivityItem(
          id: 'aidat_odeme:o1',
          tur: ActivityTur.aidatOdeme,
          baslik: 'Aidat Ödemesi',
          altMetin: '₺1.250,00',
          zaman: DateTime(2026, 7, 22, 10, 0),
          renk: ActivityRenk.olumlu,
          kaynakId: 'o1'),
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

  group('hareketSatirlari — ikon rengi MODUL, nokta SUNUCU renk_ipucu', () {
    HareketSatiri satir(ActivityTur tur, ActivityRenk renk) =>
        hareketSatirlari([
          ActivityItem(
              id: '1',
              tur: tur,
              baslik: 'Olay',
              altMetin: 'detay',
              zaman: DateTime(2026, 5, 5),
              renk: renk,
              kaynakId: '1'),
        ], DateTime(2026, 7, 23)).single;

    test('aidat odemesi: mavi cuzdan ikonu + olumlu yesil nokta', () {
      final s = satir(ActivityTur.aidatOdeme, ActivityRenk.olumlu);
      expect(s.ikon, Icons.account_balance_wallet);
      expect(s.ikonAccent, HomeTokens.primary);
      expect(s.noktaRengi, HomeTokens.green);
    });

    test('ihlal: kirmizi arac/hata ikonu + alarm noktasi', () {
      final s = satir(ActivityTur.ihlal, ActivityRenk.alarm);
      expect(s.ikonAccent, HomeTokens.red);
      expect(s.noktaRengi, HomeTokens.red);
    });

    test('nokta rengi SUNUCUDAN gelir: ayni tur, farkli renk ipucu', () {
      expect(satir(ActivityTur.ihlal, ActivityRenk.uyari).noktaRengi,
          HomeTokens.orange);
      expect(satir(ActivityTur.ihlal, ActivityRenk.notr).noktaRengi,
          HomeTokens.primary);
    });

    test('taninmayan tur: notr zil ikonu (satir DUSMEZ)', () {
      final s = satir(ActivityTur.bilinmeyen, ActivityRenk.notr);
      expect(s.ikon, Icons.notifications_outlined);
      expect(s.baslik, 'Olay');
    });

    test('alt_metin null: satir bos alt yaziyla cizilir', () {
      final s = hareketSatirlari([
        ActivityItem(
            id: '1',
            tur: ActivityTur.aracGiris,
            baslik: 'Araç Girişi',
            zaman: DateTime(2026, 5, 5),
            kaynakId: '1'),
      ], DateTime(2026, 7, 23)).single;
      expect(s.altBaslik, '');
      expect(s.ikon, Icons.directions_car);
    });
  });

  group('hareketZamanEtiketi — deterministik (now disaridan)', () {
    final now = DateTime(2026, 7, 23, 14, 0);

    test('ayni gun: HH:mm', () {
      expect(hareketZamanEtiketi(DateTime(2026, 7, 23, 9, 5), now), '09:05');
    });
    test('dun: "Dün"', () {
      expect(hareketZamanEtiketi(DateTime(2026, 7, 22, 23, 0), now), 'Dün');
    });
    test('daha eski: dd.MM', () {
      expect(hareketZamanEtiketi(DateTime(2026, 7, 1, 8, 0), now), '01.07');
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
