// (P164) DAIRE ARALIK IFADESI — "3,5,7-12".
//
// BU DOSYA WEBDEKI `admin-web/tests/aralik.test.ts` ILE AYNI SENARYOLARI
// KOSAR ve bu bilincli: iki yuzeyin ayni ifadeye AYNI cevabi vermesi
// sarttir. Kullanici webde "7-12" yazip alti daire seciyorsa mobilde de
// alti secmeli; ayrisirlarsa toplu islem YANLIS DAIRELERE gider ve geri
// alinmasi zordur.
//
// Yanlisi PAHALI oldugu icin senaryolar davranis davranis kopyalandi,
// "calisiyor mu" testi yazilmadi.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/building_map/domain/daire_araligi.dart';

const _satirlar = <AralikSatiri>[
  AralikSatiri(id: 'i1', no: 'A-1'),
  AralikSatiri(id: 'i3', no: 'A-3'),
  AralikSatiri(id: 'i5', no: 'A-5'),
  AralikSatiri(id: 'i7', no: 'A-7'),
  AralikSatiri(id: 'i8', no: 'A-8'),
  AralikSatiri(id: 'i12', no: 'A-12'),
];

void main() {
  group('sayisal kuyruk', () {
    test('onekli numaradan sayiyi cikarir', () {
      expect(sayisalKuyruk('A-7'), 7);
      expect(sayisalKuyruk('12'), 12);
      expect(sayisalKuyruk('B-101 '), 101);
    });

    test('sayisal kuyrugu OLMAYAN numara null doner', () {
      expect(sayisalKuyruk('zemin'), isNull);
    });
  });

  group('aralik cozumu — web ile AYNI', () {
    test('tekil + aralik birlikte calisir (brief ornegi)', () {
      final s = aralikCoz('3,5,7-12', _satirlar);
      expect(s.idler, ['i3', 'i5', 'i7', 'i8', 'i12']);
      expect(s.bulunamayan, isEmpty);
    });

    test('TAM NUMARA da yazilabilir', () {
      expect(aralikCoz('A-5', _satirlar).idler, ['i5']);
    });

    test('TERS ARALIK calisir — niyet belli', () {
      // "gecersiz" demek, duzeltilecek bir sey olmayan bir hata olurdu.
      expect(aralikCoz('12-7', _satirlar).idler, ['i7', 'i8', 'i12']);
    });

    test('ESLESMEYEN parca SESSIZCE DUSMEZ', () {
      // "12 daire sectim" deyip 9'unu islemek en kotu sonuctur.
      final s = aralikCoz('3,99,200-300', _satirlar);
      expect(s.idler, ['i3']);
      expect(s.bulunamayan, ['99', '200-300']);
    });

    test('AYNI KUYRUK birden fazla satira denk gelirse IKISI de secilir', () {
      // Suzgec daraltilmadiysa kullanici ikisini de goruyordur.
      final cok = [..._satirlar, const AralikSatiri(id: 'b7', no: 'B-7')];
      final idler = aralikCoz('7', cok).idler..sort();
      expect(idler, ['b7', 'i7']);
    });

    test('KOPYA uretmez', () {
      expect(aralikCoz('7,7,7-8', _satirlar).idler, ['i7', 'i8']);
    });

    test('BOS ifade gecersizdir', () {
      expect(aralikCoz('   ', _satirlar).gecersiz, isTrue);
      expect(aralikCoz('', _satirlar).idler, isEmpty);
    });

    test('TEK DEGER once SAYI olarak denenir (web sirasi)', () {
      // Sirayi ters cevirmek iki yuzeyi ayirirdi: "7" yazan kullanici
      // webde hem `7` hem `A-7` secerken mobilde yalniz `7` secmis olurdu.
      final karisik = [
        const AralikSatiri(id: 'duz7', no: '7'),
        const AralikSatiri(id: 'a7', no: 'A-7'),
      ];
      final idler = aralikCoz('7', karisik).idler..sort();
      expect(idler, ['a7', 'duz7']);
    });
  });
}
