// (P140.3) YENILEMEDE SPLASH CIKMAZ — GERCEK MEKANIZMAYLA.
//
// SIKAYET: "Olay bildir" pop-up'inin disina dokununca ana sayfaya
// donerken ekranin ortasinda uygulama ikonu + bekleme animasyonu
// beliriyor. Ayni sey kamera cikisi, NFC, gorsel goruntuleyici ve tam
// ekran haritadan donuste de oluyordu.
//
// KOK NEDEN (olculdu): ana ekrana donus `RouteAware.didPopNext` ile TAM
// YENILEME tetikler -> `home_refresh` `tenantSettings`i invalidate eder ->
// `kurulumKapisiProvider` onu `watch` ettigi icin yeniden yuklenir ->
// `HomeGate`in `when` cagrisi LOADING dalini kosar -> SplashScreen.
//
// NEDEN BU TEST BOYLE YAZILDI: P139'da ayni hipotezi ELLE KURULMUS bir
// `AsyncValue` ile "curutmus" ve dogru duzeltmeyi geri almistim. Elle
// kurulan deger gercek yeniden-yukleme durumunu temsil etmiyordu. Bu test
// gercek `ProviderContainer` + gercek `invalidate` kullanir.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// `kurulumKapisiProvider` deseni: bir bagimliligi `watch` eden turev.
  (FutureProvider<int>, FutureProvider<bool>) kur() {
    final kaynak = FutureProvider<int>((ref) async => 1);
    final turev = FutureProvider<bool>(
        (ref) async => (await ref.watch(kaynak.future)) > 0);
    return (kaynak, turev);
  }

  test('YENILEME sonrasi durum: yukleniyor AMA onceki deger DURUYOR', () async {
    final (kaynak, turev) = kur();
    final kap = ProviderContainer();
    addTearDown(kap.dispose);
    await kap.read(turev.future);

    kap.invalidate(kaynak); // ana ekrana donus = tam yenileme
    final d = kap.read(turev);
    expect(d.isLoading, isTrue);
    expect(d.hasValue, isTrue,
        reason: 'onceki deger kaybolursa splash kacinilmaz olurdu');
  });

  test('BAYRAKSIZ `when` LOADING dalini kosar (hatanin ta kendisi)', () async {
    final (kaynak, turev) = kur();
    final kap = ProviderContainer();
    addTearDown(kap.dispose);
    await kap.read(turev.future);
    kap.invalidate(kaynak);

    final dal = kap.read(turev).when(
        data: (_) => 'ekran', error: (_, _) => 'ekran', loading: () => 'splash');
    expect(dal, 'splash',
        reason: 'bu satir bozulursa teshis yeniden yapilmali');
  });

  test('skipLoadingOnReload ile DATA dali kosar (duzeltme)', () async {
    final (kaynak, turev) = kur();
    final kap = ProviderContainer();
    addTearDown(kap.dispose);
    await kap.read(turev.future);
    kap.invalidate(kaynak);

    final dal = kap.read(turev).when(
        skipLoadingOnReload: true,
        data: (_) => 'ekran',
        error: (_, _) => 'ekran',
        loading: () => 'splash');
    expect(dal, 'ekran');
  });

  test('KAPI kaynaginda bayrak DURUYOR (geri alinmasin)', () {
    // Urun kodunun kendisi olculur: bayrak silinirse donus-splash geri
    // gelir ve bu test duser.
    final kaynak = File('lib/src/features/home/presentation/home_gate.dart')
        .readAsStringSync();
    expect(kaynak, contains('skipLoadingOnReload: true'));
  });
}
