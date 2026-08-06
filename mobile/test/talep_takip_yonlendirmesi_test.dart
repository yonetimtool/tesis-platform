// (P146) SAKININ TALEP/ARIZA YUZEYI: BILDIRME ile TAKIP ayri kapilar.
//
// Kerem'in gozlemi: "talep/ariza'ya basinca direkt yeni talep tusuna
// basilmis gibi aciyor". Bu test ikisini AYRI AYRI olcer ki hangisinin
// hangi kapiyi actigi bir daha tahmine kalmasin:
//   * izgara karosu  -> /complaints           (TAKIP: liste acilir, form YOK)
//   * "Bildir" menusu -> /complaints?bildir=1 (BILDIRME: form acilir)
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/home/data/home_repository.dart';
import 'package:mobile/src/features/home/domain/home_kart_id.dart';
import 'package:mobile/src/features/home/domain/home_varyant.dart';
import 'package:mobile/src/routing/app_router.dart';

void main() {
  final sakin = MockHomeRepository().hizliErisim(HomeVaryant.sakin);

  test('TAKIP: sakinin talep karosu FORMU ACMAZ — `bildir` tasimaz', () {
    final kart = sakin.firstWhere((k) => k.id == HomeKartId.geriBildirim);
    expect(kart.rota, AppRoutes.complaints);
    // Kilidin asil olctugu sey: sorgu parametresi YOK. `?bildir=1` eklenirse
    // karo takip degil BILDIRME kapisina donusur — bu test duser.
    expect(kart.rota, isNot(contains('bildir')));
  });

  test('SILINDI: gurultu sikayeti karosu sakinin izgarasinda YOK', () {
    // (P145) `/complaints`e giden ikinci karoydu; takibi Sikayet
    // Haritasi'ndan yapiliyor.
    expect(
      sakin.map((k) => k.rota).where((r) => r == AppRoutes.complaints).length,
      1,
      reason: '/complaints e giden TEK karo kalmali',
    );
  });
}
