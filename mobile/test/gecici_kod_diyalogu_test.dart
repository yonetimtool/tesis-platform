/// TUR 79 (P3 — KAPSAMA SERISININ KAPANISI) — GECICI KOD DIYALOGUNU SUR.
///
/// `docs/OLCULMEYEN-DURUMLAR-2.md` A blogu bu diyalogu adiyla listeliyordu
/// ("personeli pasiflestirme, gecici kod diyalogu") ama B envanteri kapandiktan
/// sonra bile `core/ui/temp_code_dialog.dart` **0 / 25 satir** kapsamla
/// duruyordu: seride HIC cizilmemis son dosya buydu.
///
/// Neden onemli: bu diyalog SAKIN ve PERSONEL yasam donusunun kritik
/// noktasidir — hesap acilisinda ve parola sifirlamada gosterilen gecici kod
/// yalniz burada gorunur. Kod yanlis cizilirse (tasma, kopyalanamama, koyu
/// temada okunamama) kullanici sisteme HIC giremez ve bunun sessiz bir yedegi
/// yoktur.
///
/// Surulen iki hal: acilis (kod gorunur, "Kopyala") ve KOPYALANDI
/// (panoya yazildi, ikon/etiket degisti). Ikisi de bes eksende surulur.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/ui/temp_code_dialog.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

/// Panoya yazilanlari TUTAN taklit — `Clipboard.setData` platform kanalina
/// gider; kanal kurulmazsa kopyalama dali sessizce yutulur ve testin
/// "kopyalandi" dogrulamasi bos kosar.
List<String> _panoTaklidi() {
  final yazilanlar = <String>[];
  final ileti =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  ileti.setMockMethodCallHandler(SystemChannels.platform, (cagri) async {
    if (cagri.method == 'Clipboard.setData') {
      yazilanlar.add((cagri.arguments as Map)['text'] as String);
    }
    if (cagri.method == 'Clipboard.getData') {
      return <String, dynamic>{'text': yazilanlar.lastOrNull};
    }
    return null;
  });
  addTearDown(
    () => ileti.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return yazilanlar;
}

const _kod = 'A7K4-92QX';
const _mesaj = 'Bu kod tek kullanimliktir.';

/// Diyalogu ACAN kabuk: `showDialog` bir `BuildContext` ister, dolayisiyla
/// diyalog dogrudan `pumpWidget` edilemez. Kabuk cizilir cizilmez diyalogu
/// acar; boylece surus yardimcilari ekrani normal bir ekran gibi surer.
class _Kabuk extends StatefulWidget {
  const _Kabuk();

  @override
  State<_Kabuk> createState() => _KabukState();
}

class _KabukState extends State<_Kabuk> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showTempCodeDialog(context, code: _kod, message: _mesaj);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

Widget _ekran(String dil) => l10nApp(const _Kabuk(), locale: Locale(dil));

/// Kopyala dugmesine bas → ikon/etiket "kopyalandi" haline gecer.
Future<void> _kopyala(WidgetTester tester) async {
  final dugme = find.byType(TextButton);
  expect(dugme, findsWidgets, reason: 'Kopyala dugmesi bulunamadi');
  await tester.tap(dugme.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  // GECIS GERCEKTEN OLDU MU: onay ikonu cizilmediyse surus bos kosardi.
  expect(
    find.byIcon(Icons.check),
    findsOneWidget,
    reason: 'kopyalama sonrasi onay ikonu cizilmedi',
  );
}

void main() {
  testWidgets('DEDEKTOR: kod cizilir ve panoya AYNEN yazilir', (tester) async {
    final pano = _panoTaklidi();
    await tester.pumpWidget(_ekran('tr'));
    await tester.pumpAndSettle();

    // Kod SelectableText olarak cizilir (secilip elle kopyalanabilsin diye).
    expect(find.text(_kod), findsOneWidget);
    expect(find.text(_mesaj), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);

    await _kopyala(tester);
    expect(pano, [_kod], reason: 'panoya yazilan kod ekrandakiyle ayni degil');
  });

  testWidgets('DEDEKTOR: Tamam diyalogu KAPATIR', (tester) async {
    _panoTaklidi();
    await tester.pumpWidget(_ekran('tr'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('KOD: acilis hali (bes eksen)', (tester) async {
    _panoTaklidi();
    await tumEksenlerSurusu(tester, _ekran, veri: const {_kod, _mesaj});
  });

  testWidgets('KOD: KOPYALANDI hali (bes eksen)', (tester) async {
    _panoTaklidi();
    await tumEksenlerSurusu(
      tester,
      _ekran,
      veri: const {_kod, _mesaj},
      hazirla: _kopyala,
    );
  });

  testWidgets('KOD: eksen kombinasyonlari', (tester) async {
    _panoTaklidi();
    await eksenKombinasyonSurusu(tester, _ekran, veri: const {_kod, _mesaj});
  });

  testWidgets('KOD: ekran okuyucu sirasi', (tester) async {
    _panoTaklidi();
    await okumaSirasiSurusu(tester, _ekran);
  });
}
