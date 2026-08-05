// (P139.1) AVATAR EN-BOY ORANI — regresyon kilidi.
//
// SORUN: `sinirliGorsel` iki boyutu birden veren bir `ResizeImage`
// donuyordu ve varsayilan `ResizeImagePolicy.exact` orani YOK SAYAR:
// 4:3 bir fotograf kareye sikistirilarak cozuluyordu ("basik" avatar).
// `CircleAvatar`in `BoxFit.cover`i kurtarmiyordu cunku cover ZATEN
// BOZULMUS bitmap uzerinde calisir.
//
// NE OLCULUR: cozme SAGLAYICISININ ilkesi. Piksel karsilastirmasi
// yapmiyoruz (bu depoda goruntu karsilastirma altyapisi yok); olculen sey
// bozulmayi ureten AYARIN geri gelmemesidir.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/ui/gorsel_cozme.dart';

void main() {
  testWidgets('avatar cozmesi ORANI KORUR (exact DEGIL fit)', (tester) async {
    late ImageProvider saglayici;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 3),
        child: Builder(
          builder: (context) {
            saglayici = sinirliGorsel(
              context,
              const NetworkImage('https://ornek/foto.jpg'),
              40,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(saglayici, isA<ResizeImage>());
    final r = saglayici as ResizeImage;
    // ORANI BOZAN AYAR: `exact`. Geri gelirse bu satir duser.
    expect(r.policy, ResizeImagePolicy.fit,
        reason: 'exact politikasi en-boy oranini yok sayar (basik avatar)');
    // Bellek korumasi (tur 61) AYNEN durur: 40dp x 3 = 120px sinir.
    expect(r.width, 120);
    expect(r.height, 120);
  });

  testWidgets('olcu verilmezse sarmalanmaz (sinir yok)', (tester) async {
    late ImageProvider saglayici;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 2),
        child: Builder(
          builder: (context) {
            saglayici = sinirliGorsel(
              context, const NetworkImage('https://ornek/x.jpg'), 0);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(saglayici, isA<NetworkImage>());
  });
}
