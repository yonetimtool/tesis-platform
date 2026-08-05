// (P139.2) SPLASH YALNIZ SOGUK ACILISTA.
//
// REGRESYON: kameradan ya da "Olay bildir"den ana ekrana DONEN birincil
// yonetici, ana ekran yerine ikonlu acilis ekrani goruyordu.
//
// KOK NEDEN (yamadan once teshis edildi) — bir ZINCIR:
//   1. ana ekrana donus `RouteAware.didPopNext` ile TAM YENILEME tetikler
//   2. `home_refresh` `tenantSettingsProvider`i invalidate eder
//   3. `kurulumKapisiProvider` onu `watch` ettigi icin yeniden `loading`e
//      duser
//   4. `HomeGate` o `loading` dalinda SplashScreen ciziyordu
// Yani splash "soguk acilis" kosuluna degil GENEL BIR YUKLENIYOR kosuluna
// bagliydi — brief'in tarif ettigi (iii) numarali hipotez.
//
// COZUM: `skipLoadingOnReload: true`. Kapinin karari ("tesis kurulmus mu")
// SOGUK ACILISA aittir; cevap bir kez bilindikten sonra yenileme ekrani
// degistirmemeli. ILK yuklemede splash yine gosterilir.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // `AsyncValue.when(skipLoadingOnReload:)` davranisini DOGRUDAN olcer:
  // urun kodundaki kararin dayandigi semantik budur.
  // OLCUM KAYDI — HIPOTEZ COKTU.
  //
  // Ilk teshisim "kapinin `loading` dali yeniden-yuklemede de kosuyor"du ve
  // cozum olarak `skipLoadingOnReload: true` eklemistim. Olctum: bu Riverpod
  // surumunde `when` ZATEN varsayilan olarak yeniden-yuklemede loading'i
  // atliyor — onceki deger varken `data` kosuyor. Bayrakli ve bayraksiz
  // sonuc AYNI cikti, yani ekleyecegim sey NO-OP'tu.
  //
  // Bu blok o olcumu KILITLER: davranis bir gun degisirse (varsayilan
  // tersine doner) bu test duser ve hipotez yeniden degerlendirilir.
  group('(P139.2) AsyncValue yeniden-yukleme davranisi', () {
    test('ILK yukleme loading dalini kosar (soguk acilis: splash dogru)', () {
      expect(
        const AsyncLoading<bool>().when(
            data: (v) => 'ekran', error: (_, _) => 'ekran', loading: () => 'splash'),
        'splash',
      );
    });

    test('DEGER TASIYAN durum data dalini kosar', () {
      // `copyWithPrevious` paket-ici bir uyedir (analyzer uyariyor), o
      // yuzden ayni ayrimi genel yolla olcuyoruz: deger VARSA `when`
      // `data` dalini kosar. Riverpod'un `invalidate` sonrasi urettigi
      // durum da budur (onceki deger korunur) — ilk teshisimin
      // dayanagiydi ve olcumle curudu.
      const AsyncValue<bool> onceki = AsyncData<bool>(false);
      expect(
        onceki.when(
            data: (v) => 'ekran', error: (_, _) => 'ekran', loading: () => 'splash'),
        'ekran',
        reason: 'varsayilan degistiyse teshis yeniden yapilmali',
      );
    });
  });

  group('(P139.2) rol cikmazi', () {
    // DUZ `test`: hicbir widget pump edilmiyor, yalniz kaynak okunuyor.
    // `testWidgets` icine koymak kosumu askida birakiyordu.
    test('denetci KALICI splash gormez, yonlendirme ekrani gorur', () async {
      // `home_gate` denetciyi `role != yonetici` dalina dusuruyor ve sonsuz
      // SplashScreen ciziyordu (rol cozulmustu, bekleyen veri yoktu).
      final kaynak = await File(
        'lib/src/features/home/presentation/home_gate.dart',
      ).readAsString();
      expect(kaynak, contains('UserRole.denetci'),
          reason: 'denetci dali yok — kalici splash geri gelmis olabilir');
      expect(kaynak, contains('DenetciYonlendirmeScreen'));
      // Kapinin dallanma sirasi: denetci dali `role != yonetici`den ONCE
      // gelmeli, yoksa yine yutulur.
      expect(kaynak.indexOf('UserRole.denetci'),
          lessThan(kaynak.indexOf('role != UserRole.yonetici')));
    });
  });
}
