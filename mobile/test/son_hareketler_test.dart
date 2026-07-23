import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/dues/domain/dues_models.dart';
import 'package:mobile/src/features/home/domain/son_hareketler.dart';
import 'package:mobile/src/features/kargo/domain/kargo_models.dart';
import 'package:mobile/src/features/visitors/domain/visitor_models.dart';

void main() {
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

  group('residentHareketleri — kargo+ziyaretci+aidat birlesik akisi', () {
    Kargo kargo(String id, DateTime t,
            {KargoDurum durum = KargoDurum.bekliyor, DateTime? teslim}) =>
        Kargo(
          id: id,
          unitId: 'u1',
          unitNo: '12',
          firma: 'Mng',
          durum: durum,
          kaydedenUserId: 'g1',
          createdAt: t,
          teslimZamani: teslim,
        );

    Visitor ziyaretci(String id, DateTime t) => Visitor(
          id: id,
          unitId: 'u1',
          unitNo: '12',
          ziyaretciAd: 'Ahmet Yılmaz',
          kaydedenUserId: 'g1',
          targetResidentUserId: 'r1',
          createdAt: t,
        );

    MyDuesUnit daire(List<DuesPayment> payments) => MyDuesUnit(
          unitId: 'u1',
          no: '12',
          tahakkukKurus: 0,
          odenenKurus: 0,
          bakiyeKurus: 0,
          payments: payments,
        );

    test('kaynaklar eslesir, zamana gore DESC siralanir, en fazla 5', () {
      final h = residentHareketleri(
        kargolar: [
          kargo('k1', DateTime(2026, 7, 23, 9)), // bekliyor -> kaydedildi
          kargo('k2', DateTime(2026, 7, 20),
              durum: KargoDurum.teslimAlindi,
              teslim: DateTime(2026, 7, 23, 11)), // teslim zamani esas
        ],
        ziyaretciler: [ziyaretci('z1', DateTime(2026, 7, 23, 10))],
        duesUnits: [
          daire([
            DuesPayment(
                tutarKurus: 125000,
                odemeZamani: DateTime(2026, 7, 23, 8),
                yontem: 'havale',
                durum: 'basarili'),
            DuesPayment(
                tutarKurus: 99900,
                odemeZamani: DateTime(2026, 7, 23, 12),
                yontem: 'havale',
                durum: 'iptal'), // basarisiz -> AKISA GIRMEZ
          ]),
        ],
      );

      expect(h.map((e) => e.baslik).toList(), [
        'Kargo Teslim Edildi', // 11:00
        'Ziyaretçi Girişi', // 10:00
        'Kargo Kaydedildi', // 09:00
        'Aidat Ödemesi', // 08:00
      ]);
      expect(h[1].altBaslik, contains('Ahmet Yılmaz'));
      expect(h[3].altBaslik, contains('₺1.250,00'));
    });

    test('5\'ten fazla hareket: yalniz en yeni 5', () {
      final h = residentHareketleri(
        kargolar: [
          for (var i = 1; i <= 7; i++) kargo('k$i', DateTime(2026, 7, i)),
        ],
        ziyaretciler: const [],
        duesUnits: const [],
      );
      expect(h, hasLength(5));
      expect(h.first.zaman, DateTime(2026, 7, 7));
    });

    test('tum kaynaklar bos: bos liste', () {
      expect(
        residentHareketleri(
            kargolar: const [], ziyaretciler: const [], duesUnits: const []),
        isEmpty,
      );
    });
  });
}
