/// (P154 / Asama 7.1) MENU BOLUMLEME — asil olculen sey HICBIR MODULUN
/// KAYBOLMAMASI.
///
/// Bolumleme bir SUZGEC DEGILDIR: 17 satiri bes bolume dagitir. Ama bir
/// giris hicbir gruba yazilmazsa cekmeceden duser ve KIMSE FARK ETMEZ —
/// hata cikmaz, sadece modul gorunmez olur. Ilk test tam olarak budur ve
/// iki yonlu kilitler (ne eksilir ne eklenir).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';

void main() {
  group('(P154/7.1) hicbir modul KAYBOLMADI', () {
    test('bolumleme, rolun menusunu AYNEN tasir (eksiltmez, eklemez)', () {
      for (final rol in UserRole.values) {
        final duz = homeMenuForRole(rol);
        final bolumlu =
            homeMenuGruplariForRole(rol).values.expand((x) => x).toList();
        expect(
          bolumlu.toSet(),
          duz.toSet(),
          reason: '$rol: bolumleme kumeyi degistirdi',
        );
        expect(bolumlu.length, duz.length, reason: '$rol: kopya giris');
      }
    });

    test('HER giris bir gruba dusuyor', () {
      // `homeMenuGrubu` switch'i EKSIKSIZ oldugu icin derleyici zaten
      // zorluyor; bu test o guvenceyi CALISMA ANINDA da dogrular (enum
      // degeri yansimayla eklenirse derleyici goremez).
      for (final e in HomeMenuEntry.values) {
        expect(HomeMenuGrup.values, contains(homeMenuGrubu(e)));
      }
    });
  });

  group('(P154/7.1) bolumleme', () {
    test('BOS bolum donmez', () {
      // Tesis gorevlisi dort modul goruyor; bes baslik altinda dort satir
      // gostermek, menuyu kisaltmak icin yapilan isi tersine cevirirdi.
      for (final rol in UserRole.values) {
        for (final girdi in homeMenuGruplariForRole(rol).entries) {
          expect(girdi.value, isNotEmpty, reason: '$rol/${girdi.key}');
        }
      }
    });

    test('DENETCI icin bolum de YOK (mobil yuzeyi yok)', () {
      // (P128/P129) Denetcinin mobil menusu bilerek bos; bolumleme buna
      // "bes bos baslik" eklememeli.
      expect(homeMenuGruplariForRole(UserRole.denetci), isEmpty);
    });

    test('YONETICIDE bolum sayisi menuyu GERCEKTEN kisaltiyor', () {
      // Olcum bosa dusmesin: bolumleme ancak birden fazla bolum varsa ve
      // en kalabalik bolum duz listeden kisaysa is goruyor.
      final gruplar = homeMenuGruplariForRole(UserRole.yonetici);
      final duz = homeMenuForRole(UserRole.yonetici).length;
      expect(gruplar.length, greaterThan(1));
      final enBuyuk = gruplar.values.map((v) => v.length).reduce(
            (a, b) => a > b ? a : b,
          );
      expect(enBuyuk, lessThan(duz));
    });
  });
}
