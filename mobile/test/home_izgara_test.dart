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
    test('YONETICI: istenen alti karo', () {
      // Istenen liste yediydi; "Sikayetler" ve "Oneriler" AYNI ekran
      // (complaints) oldugu icin alti kaldi.
      expect(varsayilanIzgara(UserRole.yonetici), [
        HomeMenuEntry.announcements,
        HomeMenuEntry.complaints,
        HomeMenuEntry.otopark,
        HomeMenuEntry.taskTracking,
        HomeMenuEntry.vardiyalar,
        HomeMenuEntry.rezervasyon,
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
}
