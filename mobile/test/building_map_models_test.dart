import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/building_map/domain/building_map_models.dart';

void main() {
  group('DensityRenk.fromWire', () {
    test('bilinen renkler eslesir', () {
      expect(DensityRenk.fromWire('yesil'), DensityRenk.yesil);
      expect(DensityRenk.fromWire('sari'), DensityRenk.sari);
      expect(DensityRenk.fromWire('kirmizi'), DensityRenk.kirmizi);
    });

    test('null/bilinmeyen deger unknown (ileri surum COKMEZ)', () {
      expect(DensityRenk.fromWire(null), DensityRenk.unknown);
      expect(DensityRenk.fromWire('mor'), DensityRenk.unknown);
    });
  });

  group('BuildingMap.fromJson', () {
    test('yonetim (shows_density=true): yapi + unplaced + sayim/renk okunur', () {
      final map = BuildingMap.fromJson(const {
        'shows_density': true,
        'bloklar': [
          {
            'blok': 'A',
            'katlar': [
              {
                'kat': 1,
                'units': [
                  {
                    'unit_id': 'u-1',
                    'unit_no': 'A-12',
                    'blok': 'A',
                    'kat': 1,
                    'sira': 2,
                    'complaint_count': 3,
                    'color': 'sari',
                  },
                ],
              },
            ],
          },
        ],
        'unplaced': [
          {
            'unit_id': 'u-2',
            'unit_no': 'C-9',
            'blok': null,
            'kat': null,
            'sira': null,
            'complaint_count': 0,
            'color': 'yesil',
          },
        ],
      });

      expect(map.showsDensity, isTrue);
      expect(map.bos, isFalse);
      final u1 = map.bloklar.single.katlar.single.units.single;
      expect(u1.unitNo, 'A-12');
      expect(u1.blok, 'A');
      expect(u1.kat, 1);
      expect(u1.sira, 2);
      expect(u1.complaintCount, 3);
      expect(u1.color, DensityRenk.sari);
      expect(u1.yerlesik, isTrue);

      final unp = map.unplaced.single;
      expect(unp.unitNo, 'C-9');
      expect(unp.yerlesik, isFalse); // blok/kat yok
      expect(unp.color, DensityRenk.yesil);
    });

    test('yapi gorunumu (shows_density=false): sayim/renk NULL (Rev-1)', () {
      final map = BuildingMap.fromJson(const {
        'shows_density': false,
        'bloklar': [
          {
            'blok': 'A',
            'katlar': [
              {
                'kat': 1,
                'units': [
                  {
                    'unit_id': 'u-1',
                    'unit_no': 'A-1',
                    'blok': 'A',
                    'kat': 1,
                    'sira': 1,
                    'complaint_count': null,
                    'color': null,
                  },
                ],
              },
            ],
          },
        ],
        'unplaced': [],
      });
      expect(map.showsDensity, isFalse);
      final u = map.bloklar.single.katlar.single.units.single;
      // resident/saha hangi dairenin kac sikayeti oldugunu BILEMEZ.
      expect(u.complaintCount, isNull);
      expect(u.color, isNull);
    });

    test('bos yanit -> bos harita, showsDensity false (COKMEZ)', () {
      final m = BuildingMap.fromJson(const {});
      expect(m.bos, isTrue);
      expect(m.showsDensity, isFalse);
    });
  });

  group('UnitLayoutDraft.toJson', () {
    test('girilen alanlar gonderilir', () {
      final j = const UnitLayoutDraft(blok: 'B', kat: 0, sira: 2).toJson();
      expect(j, {'blok': 'B', 'kat': 0, 'sira': 2});
    });

    test('temizle bayraklari acikca null gonderir (yerlesimden cikar)', () {
      final j = const UnitLayoutDraft(
        clearBlok: true,
        clearKat: true,
        clearSira: true,
      ).toJson();
      expect(j, {'blok': null, 'kat': null, 'sira': null});
    });

    test('bos taslak (hicbir alan) bos kabul edilir', () {
      expect(const UnitLayoutDraft().bos, isTrue);
      expect(const UnitLayoutDraft(kat: 1).bos, isFalse);
    });
  });
}
