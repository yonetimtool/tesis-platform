// (P139.4) KOPRU — menu girisi -> hizli erisim karti.
//
// KOPRUYU YAZMADAN ONCE OLCULEN ENGEL: `HizliErisimKart` uc seyi
// birbirine bagliyor — `HomeKartId` (ekranlarin sayac `switch`'i buna
// gore esler), `altMetin`in `null`=iskelet semantigi, ve baslik cozumu.
// Kullanicinin sectigi karonun ucunde de karsiligi olmayabilir.
//
// BU DOSYA IKI TUZAGI OLCER:
//   1. YANLIS SAYAC — eslesen kart yeniden kullanilmali ki kimlik
//      korunsun; uydurma bir kimlik yanlis sayaci ilistirirdi.
//   2. KALICI ISKELET — eslesmeyen karo `sayacsiz` olmali; olmazsa kart
//      sonsuza kadar iskelet cizerdi.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/domain/home_kart_id.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/home/domain/home_varyant.dart';
import 'package:mobile/src/features/home/data/home_repository.dart';
import 'package:mobile/src/features/home/presentation/izgara_koprusu.dart';
import 'package:mobile/src/features/home/presentation/module_card_spec.dart';

void main() {
  final taban = MockHomeRepository();

  group('(P139.4) eslesen karo YENIDEN KULLANILIR', () {
    test('eslesen giris MEVCUT kartin TA KENDISI olur', () {
      final mevcut = taban.hizliErisim(HomeVaryant.yonetici);
      // Hangi girisin karsiligi oldugunu VARSAYMIYORUZ, OLCUYORUZ:
      // eslesme rol listesine gore degisir (yoneticide `duyurular` karti
      // yok, `geriBildirim` var — ilk yazimda bunu varsayip dusmustum).
      final giris = homeMenuForRole(UserRole.yonetici).firstWhere(
        (g) => mevcut.any((k) => k.rota == moduleCardSpec(g).route),
      );
      final kart = izgaraKartiUret(giris, mevcut);
      final eslesen =
          mevcut.firstWhere((k) => k.rota == moduleCardSpec(giris).route);
      // AYNI NESNE: kimlik, sayac alanlari ve etiket oldugu gibi korunur.
      expect(identical(kart, eslesen), isTrue,
          reason: 'yeniden kurulursa ekranlarin sayac switch i kopar');
      expect(kart.sayacsiz, isFalse);
    });

    test('yeniden kullanilan kartin kimligi UYDURULMAZ', () {
      final mevcut = taban.hizliErisim(HomeVaryant.yonetici);
      for (final giris in homeMenuForRole(UserRole.yonetici)) {
        final spec = moduleCardSpec(giris);
        final varMi = mevcut.any((k) => k.rota == spec.route);
        final kart = izgaraKartiUret(giris, mevcut);
        if (varMi) {
          expect(kart.rota, spec.route);
          expect(kart.sayacsiz, isFalse, reason: '$giris eslesti ama sayacsiz');
        }
      }
    });
  });

  group('(P139.4) eslesmeyen karo SAYACSIZ (kalici iskelet YOK)', () {
    test('kart karsiligi olmayan giris sayacsiz uretilir', () {
      final mevcut = taban.hizliErisim(HomeVaryant.yonetici);
      // `siteKurallari` menude var ama sayacli kart listesinde YOK.
      final kart = izgaraKartiUret(HomeMenuEntry.siteKurallari, mevcut);
      expect(kart.sayacsiz, isTrue,
          reason: 'sayacsiz degilse kart SONSUZA KADAR iskelet cizer');
      expect(kart.altMetin, isNull);
      expect(kart.modulGirisi, HomeMenuEntry.siteKurallari);
      expect(kart.rota, moduleCardSpec(HomeMenuEntry.siteKurallari).route);
    });

    test('uretilen kartin kimligi sayac switch inde KARSILIGI OLMAYAN deger', () {
      // Ekranlarin `switch (k.id)` bloklari bu kimlikleri sayacliyor:
      const sayaclananlar = {
        HomeKartId.vardiyaDurumu, HomeKartId.gorevler, HomeKartId.aidatDurumu,
        HomeKartId.otoparkKullanimi, HomeKartId.ihlaller,
        HomeKartId.geriBildirim, HomeKartId.sikayetler,
      };
      final mevcut = taban.hizliErisim(HomeVaryant.yonetici);
      final kart = izgaraKartiUret(HomeMenuEntry.siteKurallari, mevcut);
      expect(sayaclananlar.contains(kart.id), isFalse,
          reason: 'uretilen kimlik YANLIS SAYAC ilistirir');
    });
  });

  group('(P139.4) izgara listesi', () {
    test('sira KORUNUR ve her giris bir kart uretir', () {
      const secim = [
        HomeMenuEntry.announcements,
        HomeMenuEntry.siteKurallari,
        HomeMenuEntry.complaints,
      ];
      final kartlar = izgaraKartlari(secim, HomeVaryant.yonetici, taban);
      expect(kartlar.length, secim.length);
      for (var i = 0; i < secim.length; i++) {
        expect(kartlar[i].rota, moduleCardSpec(secim[i]).route);
      }
    });

    test('BOS secim bos liste uretir (cagiran varsayilana duser)', () {
      expect(izgaraKartlari(const [], HomeVaryant.yonetici, taban), isEmpty);
    });
  });
}
