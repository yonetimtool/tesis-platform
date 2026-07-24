import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/home/domain/home_view_models.dart';
import 'package:mobile/src/features/home/presentation/home_mappers.dart';
import 'package:mobile/src/features/home/presentation/widgets/vardiya_seridi.dart';
import 'package:mobile/src/features/shifts/domain/shift_models.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

const _vardiyalar = [
  Shift(
      id: 'v1',
      ad: 'Sabah Vardiyası',
      baslangicSaat: '06:00',
      bitisSaat: '14:00',
      gunTipi: 'hafta_ici'),
  Shift(
      id: 'v2',
      ad: 'Gece Vardiyası',
      baslangicSaat: '22:00',
      bitisSaat: '06:00',
      gunTipi: null),
];

void main() {
  group('vardiyaKartlari — /shifts → vardiya kartlari (SAF)', () {
    test('now araliktakine aktif, digerine planlandi', () {
      final kartlar = vardiyaKartlari(
        vardiyalar: _vardiyalar,
        now: DateTime(2026, 7, 23, 9, 30), // sabah araliginda
      );
      expect(kartlar.map((k) => k.durum).toList(),
          [VardiyaDurum.aktif, VardiyaDurum.planlandi]);
      expect(kartlar.first.altBaslik, '06:00 - 14:00');
      expect(kartlar.first.altBilgi, 'Hafta içi'); // personel atanmamis
    });

    test('gece sarkmasi: gece yarisi sonrasi gece vardiyasi aktif', () {
      final kartlar = vardiyaKartlari(
        vardiyalar: _vardiyalar,
        now: DateTime(2026, 7, 23, 2, 0),
      );
      expect(kartlar.map((k) => k.durum).toList(),
          [VardiyaDurum.planlandi, VardiyaDurum.aktif]);
    });

    test('yoneticiAd verilince serinin SONUNA "Yönetici" karti eklenir', () {
      final kartlar = vardiyaKartlari(
        vardiyalar: _vardiyalar,
        now: DateTime(2026, 7, 23, 9, 30),
        yoneticiAd: 'Kerem Aşçı',
      );
      expect(kartlar.length, 3);
      expect(kartlar.last.baslik, 'Yönetici');
      expect(kartlar.last.altBaslik, 'Kerem Aşçı');
      expect(kartlar.last.durum, VardiyaDurum.yonetici);
      expect(kartlar.last.online, isTrue);
    });

    test('bos yoneticiAd: ek kart YOK', () {
      final kartlar = vardiyaKartlari(
        vardiyalar: _vardiyalar,
        now: DateTime(2026, 7, 23, 9, 30),
        yoneticiAd: '',
      );
      expect(kartlar.length, 2);
    });

    test('atanan personel varsa alt bilgi "N Görevli"', () {
      final kartlar = vardiyaKartlari(
        vardiyalar: const [
          Shift(
            id: 'v1',
            ad: 'Sabah Vardiyası',
            baslangicSaat: '06:00',
            bitisSaat: '14:00',
            personel: [
              ShiftPersonel(userId: 'u1', ad: 'A'),
              ShiftPersonel(userId: 'u2', ad: 'B'),
            ],
          ),
        ],
        now: DateTime(2026, 7, 23, 9, 30),
      );
      expect(kartlar.single.altBilgi, '2 Görevli');
    });
  });

  group('VardiyaSeridi — "Vardiya Durumu" bolumu (referans)', () {
    testWidgets('baslik + kartlar cizilir; "Tümünü Gör" cagirir',
        (tester) async {
      var tumu = 0;
      await tester.pumpWidget(_wrap(VardiyaSeridi(
        kartlar: vardiyaKartlari(
          vardiyalar: _vardiyalar,
          now: DateTime(2026, 7, 23, 9, 30),
        ),
        onSeeAll: () => tumu++,
      )));

      expect(find.text('Vardiya Durumu'), findsOneWidget);
      expect(find.text('Sabah Vardiyası'), findsOneWidget);
      expect(find.text('06:00 - 14:00'), findsOneWidget);
      expect(find.text('AKTİF'), findsOneWidget);
      expect(find.text('PLANLANDI'), findsOneWidget);

      await tester.tap(find.text('Tümünü Gör'));
      expect(tumu, 1);
    });

    testWidgets('bos liste: bolum HIC cizilmez (baslik dahil)', (tester) async {
      await tester.pumpWidget(_wrap(const VardiyaSeridi(kartlar: [])));
      expect(find.text('Vardiya Durumu'), findsNothing);
    });
  });
}
