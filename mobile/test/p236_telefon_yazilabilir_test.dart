/// (P236) TELEFON ALANI GERÇEKTEN YAZILABİLİR Mİ — genişlik dahil.
///
/// =========================================================================
/// NEDEN BU TEST VAR
/// =========================================================================
/// Web'de ölçülen kusur: ülke seçici bileşenine `w-32` sınıfı geçilmişti
/// ama bileşen kendi içinde `w-full` taşıyor. Tailwind çıktısında
/// `.w-full` sonra geldiği için O kazandı; seçici %100 genişlik aldı,
/// `shrink-0` yüzünden küçülmedi ve **numara alanı sıfır genişliğe indi**.
/// Kullanıcı ülkeyi seçebiliyor ama numarayı yazamıyordu.
///
/// Web'de bu kusuru DOM testleri göremedi: jsdom düzen hesaplamaz.
/// **Flutter hesaplar** — bu yüzden mobilde aynı sınıf kusuru DAVRANIŞLA
/// kilitlenebilir ve burada öyle yapılıyor: alan yazılabiliyor mu VE
/// ekranda anlamlı bir genişliği var mı.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/core/ui/telefon_alani.dart';
import 'package:mobile/src/core/ui/telefon_alani_widget.dart';

Widget _sar(TextEditingController k) => MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TelefonAlani(
            ktrl: k,
            etiket: 'Telefon',
            alanAnahtari: const Key('tel-numara'),
            ulkeAnahtari: const Key('tel-ulke'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('NUMARA ALANI SIFIR GENISLIKTE DEGIL', (t) async {
    // Web'deki kusurun mobil karsiligi tam olarak bu olurdu: secici tum
    // satiri kaplar ve numara kutusu goze gorunmez bir seride sikisir.
    final k = TextEditingController();
    await t.pumpWidget(_sar(k));

    final numaraEni = t.getSize(find.byKey(const Key('tel-numara'))).width;
    final ulkeEni = t.getSize(find.byKey(const Key('tel-ulke'))).width;

    expect(numaraEni, greaterThan(100),
        reason: 'numara alani $numaraEni dp — yazacak yer yok');
    // Secici numaradan GENIS OLMAMALI: ekran onun degil numaranin.
    expect(ulkeEni, lessThan(numaraEni),
        reason: 'ulke secici ($ulkeEni dp) numaradan ($numaraEni dp) genis');
  });

  testWidgets('ULKE SECILDIKTEN SONRA NUMARA YAZILABILIYOR', (t) async {
    final k = TextEditingController();
    await t.pumpWidget(_sar(k));

    await t.tap(find.byKey(const Key('tel-ulke')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('telefon-ulke-TR')));
    await t.pumpAndSettle();

    // Secim sonrasi alan HALA yazilabilir olmali (odak/etkinlik kaybi yok).
    final alan = t.widget<TextFormField>(find.byKey(const Key('tel-numara')));
    expect(alan.enabled, isNot(false));

    await t.enterText(find.byKey(const Key('tel-numara')), '5419222388');
    await t.pump();

    expect(find.text('541 922 23 88'), findsOneWidget);
    expect(telefonNormalle(k.text), '+905419222388');
  });

  testWidgets('ULKE SECMEDEN DE YAZILABILIYOR (alan kilitli degil)', (t) async {
    // Onemli ayrim: ulke SECILMEDEN numara GECERSIZDIR (P233) ama alan
    // YAZILABILIR olmali. Ikisini karistirip alani kilitlemek, kullaniciyi
    // "once ulke sec" diye bir sirayla zorlamak olurdu.
    final k = TextEditingController();
    await t.pumpWidget(_sar(k));
    await t.enterText(find.byKey(const Key('tel-numara')), '5419222388');
    await t.pump();
    expect(find.text('541 922 23 88'), findsOneWidget);
  });

  testWidgets('DAR EKRANDA da numara alani kullanilabilir', (t) async {
    // 320 dp — deponun dar ekran esigi. Secici sabit 132 dp; numaraya
    // kalan yer olculur.
    t.view.physicalSize = const Size(320, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    final k = TextEditingController();
    await t.pumpWidget(_sar(k));
    final numaraEni = t.getSize(find.byKey(const Key('tel-numara'))).width;
    expect(numaraEni, greaterThan(80),
        reason: 'dar ekranda numara alani $numaraEni dp');
    expect(t.takeException(), isNull);
  });
}
