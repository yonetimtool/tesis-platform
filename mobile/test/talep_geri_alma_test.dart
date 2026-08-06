// (P146) GERI ALMA — sakinin kendi talebini geri cekmesi.
//
// Iki kusur sinifi olculuyor:
//   1. TEL ESLEME: `geri_alindi` sessizce `unknown`a dusmemeli. Dusseydi
//      kayit "Açık" sekmesinde kalirdi ve sakin geri aldigini SANMAZDI.
//   2. KURAL: geri alma ACANIN hakki ve YALNIZ `acik` talepte. Kural
//      `talepGeriAlinabilir` icinde TEK YERDE duruyor ve ekran onu
//      cagiriyor — yani buradaki bir mutasyon arayuzu de bozar.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/complaints/domain/complaint_models.dart';

void main() {
  group('tel esleme', () {
    test('`geri_alindi` KENDI durumuna cozulur — unknown DEGIL', () {
      expect(talepDurumFromWire('geri_alindi'), TalepDurum.geriAlindi);
      expect(TalepDurum.geriAlindi.wire, 'geri_alindi');
    });

    test('bilinmeyen tel hala unknown — ileriye uyum korunuyor', () {
      expect(talepDurumFromWire('bir_gun_eklenecek'), TalepDurum.unknown);
    });
  });

  group('geri alma kurali', () {
    test('ACAN + acik -> gorunur', () {
      expect(
        talepGeriAlinabilir(yonetimMi: false, durum: TalepDurum.acik),
        isTrue,
      );
    });

    test('YONETIM gormez — onun yolu reddet', () {
      expect(
        talepGeriAlinabilir(yonetimMi: true, durum: TalepDurum.acik),
        isFalse,
      );
    });

    test('is emrine donusmus talep geri alinamaz (sahada is baslamis olabilir)',
        () {
      expect(
        talepGeriAlinabilir(yonetimMi: false, durum: TalepDurum.isEmri),
        isFalse,
      );
    });

    test('terminal durumlarin HICBIRINDE gorunmez', () {
      for (final d in [
        TalepDurum.cozuldu,
        TalepDurum.reddedildi,
        TalepDurum.geriAlindi,
      ]) {
        expect(
          talepGeriAlinabilir(yonetimMi: false, durum: d),
          isFalse,
          reason: d.name,
        );
      }
    });
  });
}
