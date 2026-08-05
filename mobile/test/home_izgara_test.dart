// (P139.3) ANA EKRAN IZGARASI — varsayilan kume + kullanici tercihi.
//
// UC SORU OLCULUR:
//   1. Varsayilan kume DOGRU mu (Kerem'in listesi, roller icin uyarlanmis)?
//   2. Kullanici tercihi IZIN KATMANIYLA sinirli mi? (izin hatasina
//      goturen karo olmamali — sartin kendisi bu)
//   3. Bozuk/eskimis tercih uygulamayi BOS EKRANA dusuruyor mu? (dusurmemeli)
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/domain/home_izgara.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';

void main() {
  group('(P139.3) varsayilan izgara', () {
    test('YONETICI: varsayilan set (P140.1 ile SEKIZ)', () {
      // Kerem'in ilk listesi yediydi; "Sikayetler" ve "Oneriler" AYNI
      // ekran (complaints) oldugu icin alti kalmisti. (P140.1) sinir 8
      // olunca set de sekize cikti: eklenen iki kalem KEYFI DEGIL —
      // `financialSummary` ve `ihlaller` yoneticinin BUGUNKU sekizliginde
      // olan ve kurasyonun dusurdugu sayacli kartlardi.
      expect(varsayilanIzgara(UserRole.yonetici), [
        HomeMenuEntry.announcements,
        HomeMenuEntry.complaints,
        HomeMenuEntry.otopark,
        HomeMenuEntry.taskTracking,
        HomeMenuEntry.vardiyalar,
        HomeMenuEntry.rezervasyon,
        HomeMenuEntry.financialSummary,
        HomeMenuEntry.ihlaller,
      ]);
    });

    test('SAHA rolu gorev karosunda YONETIM gorunumu GORMEZ', () {
      // `taskTracking` gorev olusturma/atamadir ve yalniz yoneticidedir;
      // saha "Gorevlerim"i kullanir. Ayni karoyu birakmak, izin hatasi
      // ureten bir karo gostermek olurdu.
      final saha = varsayilanIzgara(UserRole.security);
      expect(saha, isNot(contains(HomeMenuEntry.taskTracking)));
      expect(saha, contains(HomeMenuEntry.tasks));
    });

    test('hicbir rolde IZINSIZ karo yok', () {
      for (final rol in UserRole.values) {
        final izinli = izgaraSecenekleri(rol).toSet();
        for (final k in varsayilanIzgara(rol)) {
          expect(izinli, contains(k), reason: '$rol -> $k izinsiz');
        }
      }
    });

    test('hicbir rolde BOS izgara yok (izinli kume varsa)', () {
      for (final rol in UserRole.values) {
        if (izgaraSecenekleri(rol).isEmpty) continue; // denetci: mobil yuzeyi degil
        expect(varsayilanIzgara(rol), isNotEmpty, reason: '$rol bos izgara');
      }
    });

    test('DENETCI mobilde izgara GORMEZ (urun karari)', () {
      // P128/P129 + Kerem'in onayi: denetimin yuzeyi web. Bos izgara bir
      // eksiklik degil KARARDIR; ekran yerine yonlendirme gosterilir.
      expect(izgaraSecenekleri(UserRole.denetci), isEmpty);
    });
  });

  group('(P139.3) kullanici tercihi', () {
    test('tercih YOKSA varsayilan cizilir', () {
      expect(izgarayiCoz(UserRole.yonetici, null),
          varsayilanIzgara(UserRole.yonetici));
    });

    test('IZINSIZ secim DUSER (rol degismis ya da ekran kaldirilmis)', () {
      // Sakin, yoneticinin personel ekranini secmis gibi davranalim.
      final cozulen = izgarayiCoz(
        UserRole.resident,
        [HomeMenuEntry.announcements, HomeMenuEntry.personel],
      );
      expect(cozulen, [HomeMenuEntry.announcements]);
    });

    test('YINELENEN secim tek karo olur', () {
      // Ayni hedefe iki karo, duzeltilmek istenen sikayetin ta kendisiydi.
      expect(
        izgarayiCoz(UserRole.yonetici,
            [HomeMenuEntry.announcements, HomeMenuEntry.announcements]),
        [HomeMenuEntry.announcements],
      );
    });

    test('TAMAMEN gecersiz tercih varsayilana DUSER (bos ekran yok)', () {
      expect(izgarayiCoz(UserRole.resident, [HomeMenuEntry.personel]),
          varsayilanIzgara(UserRole.resident));
      expect(izgarayiCoz(UserRole.yonetici, const []),
          varsayilanIzgara(UserRole.yonetici));
    });

    test('SINIR asilmaz', () {
      final cok = izgaraSecenekleri(UserRole.yonetici);
      expect(cok.length, greaterThan(izgaraEnCokKaro));
      expect(izgarayiCoz(UserRole.yonetici, cok).length, izgaraEnCokKaro);
    });
  });

  group('(P139.3) depolama bicimi', () {
    test('AD ile yazilir, indeksle DEGIL', () {
      // Indeks yazmak, enum'a ortadan giris eklendiginde kayitli tercihleri
      // sessizce baska ekranlara kaydirirdi.
      final yazilan = izgarayiYaz([HomeMenuEntry.otopark, HomeMenuEntry.complaints]);
      expect(yazilan, ['otopark', 'complaints']);
      expect(izgarayiOku(yazilan), [HomeMenuEntry.otopark, HomeMenuEntry.complaints]);
    });

    test('TANINMAYAN ad duser (surum geriye gitmis olabilir)', () {
      expect(izgarayiOku(['otopark', 'boyle_bir_ekran_yok']),
          [HomeMenuEntry.otopark]);
    });
  });

  group('(P139.5) KURASYONLU varsayilan — yonetim rolleri', () {
    // Kerem'in karari: yoneticinin varsayilan izgarasi ALTI karo.
    //
    // BEDELI OLCULDU VE KABUL EDILDI: bugunku sekiz karttan `aidatDurumu`,
    // `ihlaller`, `sikayetler` sayaclari ve `raporlar` izgaradan duser.
    // Ekranlar erisilebilir kalir; kaybolan sey ana ekrandaki uc SAYACTIR.
    test('yonetici varsayilani TAM SEKIZ karo (P140.1)', () {
      // Kerem'in ilk listesi alti kalemdi; (P140.1) sinir 8 olunca set de
      // sekize cikti. Alti kalemin HEPSI duruyor, ustune iki sayacli kart
      // geri geldi (`financialSummary`, `ihlaller`).
      final v = varsayilanIzgara(UserRole.yonetici);
      expect(v.length, 8);
      expect(v, containsAll([
        HomeMenuEntry.announcements,
        HomeMenuEntry.complaints,
        HomeMenuEntry.otopark,
        HomeMenuEntry.taskTracking,
        HomeMenuEntry.vardiyalar,
        HomeMenuEntry.rezervasyon,
        HomeMenuEntry.financialSummary,
        HomeMenuEntry.ihlaller,
      ]));
    });

    test('SAKIN kurasyona TABI DEGIL — bugunku kartlarini korur', () {
      // Ayni varsayilani sakine uygulamak kesisimi uc karoya dusuruyor ve
      // Aidatim/Kargo/Ziyaretci sayaclarini ana ekrandan siliyordu.
      // Sakinin varsayilani "bugunku kartlar"dir; bunu `izgaraKarolariProvider`
      // `null` dondurerek soyler (bkz. izgara_tercihi.dart).
      final sakin = varsayilanIzgara(UserRole.resident);
      // Kurasyonlu kume sakinde UCE duserdi — kanit:
      expect(sakin.length, lessThan(6));
    });
  });

  group('(P140.1) TAVAN 8 ve rol basina daralma', () {
    test('sabit 8 ve TEK YERDE', () {
      expect(izgaraEnCokKaro, 8);
    });

    test('varsayilan set SEKIZ karo (yonetici)', () {
      expect(varsayilanIzgara(UserRole.yonetici).length, 8);
    });

    test('8 USTU secim ENGELLENIR', () {
      final cok = izgaraSecenekleri(UserRole.yonetici);
      expect(cok.length, greaterThan(izgaraEnCokKaro));
      expect(izgarayiCoz(UserRole.yonetici, cok).length, izgaraEnCokKaro);
    });

    test('ROL KUMESI 8DEN AZSA tavan kume kadar (guvenlik amiri)', () {
      // Olculdu: amir yalniz alti karo gorebiliyor. Ona 8 tavani
      // gostermek, ulasamayacagi bir sayiyi soylemek olurdu.
      final n = izgaraSecenekleri(UserRole.guvenlikAmiri).length;
      expect(n, lessThan(izgaraEnCokKaro));
      expect(izgaraTavani(UserRole.guvenlikAmiri), n);
      // Ve cozulen izgara o sayiyi ASMAZ (bos yer tutucu yok).
      expect(
        izgarayiCoz(UserRole.guvenlikAmiri,
            izgaraSecenekleri(UserRole.guvenlikAmiri)).length,
        n,
      );
    });

    test('DENETCIDE tavan 0 (mobil yuzeyi yok)', () {
      expect(izgaraTavani(UserRole.denetci), 0);
    });

    test('KAYITLI 6LIK TERCIH KORUNUR — otomatik 8e TAMAMLANMAZ', () {
      // Sinir 8e cikinca, alti karo secmis bir kullanicinin secimi
      // buyutulmez: acikca kaldirdigi karolari geri koymak olurdu.
      final alti = izgaraSecenekleri(UserRole.yonetici).take(6).toList();
      expect(izgarayiCoz(UserRole.yonetici, alti).length, 6);
      expect(izgarayiCoz(UserRole.yonetici, alti), alti);
    });

    test('hicbir rolde tavan kumeyi ASMAZ', () {
      for (final rol in UserRole.values) {
        expect(izgaraTavani(rol),
            lessThanOrEqualTo(izgaraSecenekleri(rol).length), reason: '$rol');
        expect(izgaraTavani(rol), lessThanOrEqualTo(izgaraEnCokKaro));
      }
    });
  });
}
