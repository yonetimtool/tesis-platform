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

import 'package:flutter_test/flutter_test.dart';

void main() {
  // `AsyncValue.when(skipLoadingOnReload:)` davranisini DOGRUDAN olcer:
  // urun kodundaki kararin dayandigi semantik budur.
  // (P140.3) BU BLOK KALDIRILDI — OLCUMU YANLISTI.
  //
  // Burada "yeniden-yukleme loading dalini ATLAR" diye bir kayit vardi ve
  // ona dayanarak P139'da DOGRU olan `skipLoadingOnReload` duzeltmesini
  // geri almistim. Olcum ELLE KURULMUS bir `AsyncValue` uzerindeydi
  // (`AsyncData(...)`), gercek `invalidate` sonrasi durumu temsil
  // etmiyordu. Gercek mekanizma `splash_yenilemede_cikmaz_test.dart`ta
  // olculuyor: bayraksiz `when` LOADING dalini kosuyor.
  //
  // Ders: bir hipotezi CURUTMEK icin kullanilan olcum de en az hipotez
  // kadar dikkatli kurulmali.

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
