import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/transparency/domain/transparency_models.dart';

void main() {
  group('TransparencyBoard.fromJson', () {
    test('tum alanlar eslenir (agregat)', () {
      final b = TransparencyBoard.fromJson({
        'ay': '2026-06',
        'yayinlandi': true,
        'toplam_gelir_kurus': 300000,
        'toplam_gider_kurus': 200000,
        'net_kurus': 100000,
        'onceki_ay_net_kurus': 50000,
        'gider_dagilimi': [
          {'ad': 'Elektrik', 'toplam_kurus': 150000, 'yuzde': 75},
          {'ad': 'Diğer', 'toplam_kurus': 50000, 'yuzde': 25},
        ],
        'aidat': {
          'tahakkuk_kurus': 150000,
          'tahsilat_kurus': 75000,
          'tutar_orani_yuzde': 50,
          'toplam_daire': 2,
          'odeyen_daire': 1,
          'daire_orani_yuzde': 50,
          'geciken_daire_sayisi': 1,
        },
      });
      expect(b.ay, '2026-06');
      expect(b.yayinlandi, isTrue);
      expect(b.toplamGelirKurus, 300000);
      expect(b.netKurus, 100000);
      expect(b.oncekiAyNetKurus, 50000);
      expect(b.giderDagilimi.length, 2);
      expect(b.giderDagilimi.first.ad, 'Elektrik');
      expect(b.giderDagilimi.first.yuzde, 75);
      expect(b.aidat.toplamDaire, 2);
      expect(b.aidat.odeyenDaire, 1);
      expect(b.aidat.daireOraniYuzde, 50);
      expect(b.aidat.gecikenDaireSayisi, 1);
    });

    test('bos ay: sifirlar + null oranlar (crash yok)', () {
      final b = TransparencyBoard.fromJson({
        'ay': '2020-01',
        'yayinlandi': false,
        'toplam_gelir_kurus': 0,
        'toplam_gider_kurus': 0,
        'net_kurus': 0,
        'onceki_ay_net_kurus': null,
        'gider_dagilimi': [],
        'aidat': {
          'tahakkuk_kurus': 0,
          'tahsilat_kurus': 0,
          'tutar_orani_yuzde': null,
          'toplam_daire': 0,
          'odeyen_daire': 0,
          'daire_orani_yuzde': null,
          'geciken_daire_sayisi': 0,
        },
      });
      expect(b.giderDagilimi, isEmpty);
      expect(b.oncekiAyNetKurus, isNull);
      expect(b.aidat.daireOraniYuzde, isNull);
      expect(b.aidat.tutarOraniYuzde, isNull);
      expect(b.aidat.gecikenDaireSayisi, 0);
    });
  });

  test('TransparencyAyOzet.fromJson', () {
    final m = TransparencyAyOzet.fromJson(
        {'ay': '2026-06', 'yayinlandi': true, 'net_kurus': 100000});
    expect(m.ay, '2026-06');
    expect(m.yayinlandi, isTrue);
    expect(m.netKurus, 100000);
  });
}
