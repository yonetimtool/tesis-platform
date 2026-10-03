/// (P253 §B) Mobil ortak bilesenler: ListeEkrani, coklu secim, olustur-paylas.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/ui/coklu_secim.dart';
import 'package:mobile/src/core/ui/liste_ekrani.dart';
import 'package:mobile/src/core/ui/olustur_paylas.dart';
import 'package:share_plus/share_plus.dart';

import 'helpers/l10n_test_app.dart';

class _Kayit {
  const _Kayit(this.id, this.ad);
  final int id;
  final String ad;
}

/// 70 kayitlik sahte sunucu: arama + `durum` suzgeci + siralama.
class _Sunucu {
  final sorgular = <ListeSorgusu>[];
  bool hata = false;

  Future<ListeSayfasi<_Kayit>> yukle(ListeSorgusu s) async {
    sorgular.add(s);
    if (hata) throw Exception('dustu');
    var hepsi = [for (var i = 0; i < 70; i++) _Kayit(i, 'Kayit $i')];
    if (s.arama.isNotEmpty) hepsi = hepsi.where((k) => k.ad.contains(s.arama)).toList();
    if (s.suzgec['durum'] == 'cift') hepsi = hepsi.where((k) => k.id.isEven).toList();
    if (s.siralama == 'azalan') hepsi = hepsi.reversed.toList();
    final dilim = hepsi.skip(s.offset).take(s.limit).toList();
    return ListeSayfasi(dilim, toplam: hepsi.length);
  }
}

Widget _ekran(_Sunucu sunucu, {List<TopluEylem<_Kayit>> eylemler = const []}) => l10nApp(
      ListeEkrani<_Kayit>(
        baslik: 'Liste',
        yukle: sunucu.yukle,
        kimlik: (k) => k.id,
        aramaVar: true,
        suzgecler: [
          SuzgecTanimi(
            ad: 'durum',
            etiket: (_) => 'Durum',
            secenekler: [SuzgecSecenegi('cift', (_) => 'Çift')],
          ),
        ],
        siralamalar: [
          SiralamaTanimi('artan', (_) => 'Artan'),
          SiralamaTanimi('azalan', (_) => 'Azalan'),
        ],
        varsayilanSiralama: 'artan',
        topluEylemler: eylemler,
        kart: (c, k, secili) => Card(
          child: ListTile(
            title: Text(k.ad),
            trailing: secili ? const Icon(Icons.check_circle) : null,
          ),
        ),
      ),
    );

void main() {
  testWidgets('LISTE: ilk sayfa, kaydirinca SONRAKI sayfa (offset), sonda durur', (tester) async {
    final s = _Sunucu();
    await tester.pumpWidget(_ekran(s));
    await tester.pumpAndSettle();
    expect(s.sorgular.single.offset, 0);
    expect(s.sorgular.single.limit, 30);
    await tester.fling(find.byKey(const Key('liste-ogeler')), const Offset(0, -6000), 3000);
    await tester.pumpAndSettle();
    expect(s.sorgular.map((q) => q.offset), containsAllInOrder([0, 30]));
    await tester.fling(find.byKey(const Key('liste-ogeler')), const Offset(0, -9000), 3000);
    await tester.pumpAndSettle();
    await tester.fling(find.byKey(const Key('liste-ogeler')), const Offset(0, -9000), 3000);
    await tester.pumpAndSettle();
    expect(s.sorgular.last.offset, 60);
    expect(find.text('Kayit 69'), findsOneWidget);
    final once = s.sorgular.length;
    await tester.fling(find.byKey(const Key('liste-ogeler')), const Offset(0, -9000), 3000);
    await tester.pumpAndSettle();
    expect(s.sorgular.length, once, reason: 'toplam geldi; yeni istek yok');
  });

  testWidgets('ARAMA beklemeli gider, liste bastan', (tester) async {
    final s = _Sunucu();
    await tester.pumpWidget(_ekran(s));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('liste-ara')), 'Kayit 6');
    await tester.pump(const Duration(milliseconds: 100));
    expect(s.sorgular.length, 1, reason: 'yazarken her tusta istek yok');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(s.sorgular.last.arama, 'Kayit 6');
    expect(s.sorgular.last.offset, 0);
    final liste = find.byKey(const Key('liste-ogeler'));
    expect(find.descendant(of: liste, matching: find.text('Kayit 6')), findsOneWidget);
    expect(find.descendant(of: liste, matching: find.text('Kayit 7')), findsNothing);
  });

  testWidgets('SIRALA / SUZ: secim cip olur, cip silinince suzgec kalkar', (tester) async {
    final s = _Sunucu();
    await tester.pumpWidget(_ekran(s));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('liste-sirala-suz')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('liste-suzgec-durum-cift')));
    await tester.tap(find.byKey(const Key('liste-siralama-azalan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('liste-uygula')));
    await tester.pumpAndSettle();
    expect(s.sorgular.last.suzgec, {'durum': 'cift'});
    expect(s.sorgular.last.siralama, 'azalan');
    expect(find.text('Kayit 68'), findsOneWidget);
    expect(find.text('Durum: Çift'), findsOneWidget);
    // Erisilebilir ad da olculur: "Durum suzgecini kaldir".
    await tester.tap(find.byTooltip('Durum süzgecini kaldır'));
    await tester.pumpAndSettle();
    expect(s.sorgular.last.suzgec, isEmpty);
    expect(find.byKey(const Key('liste-cip-durum')), findsNothing);
  });

  testWidgets('BOS ve HATA durumlari; Tekrar dene yeniden ister', (tester) async {
    final s = _Sunucu()..hata = true;
    await tester.pumpWidget(_ekran(s));
    await tester.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsOneWidget);
    s.hata = false;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text('Kayit 0'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('liste-ara')), 'yokyok');
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('liste-bos')), findsOneWidget);
  });

  testWidgets('COKLU SECIM: uzun bas, sec, toplu eylem SECILILERI alir; geri tusu kipi kapatir',
      (tester) async {
    final s = _Sunucu();
    List<int>? alinan;
    await tester.pumpWidget(_ekran(s, eylemler: [
      TopluEylem(
        etiket: (_) => 'Sil',
        ikon: Icons.delete_outline,
        tehlikeli: true,
        calistir: (c, secili) async => alinan = secili.map((k) => k.id).toList(),
      ),
    ]));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const Key('liste-oge-1')));
    await tester.pumpAndSettle();
    expect(find.text('1 seçili'), findsOneWidget);
    await tester.tap(find.byKey(const Key('liste-oge-3')));
    await tester.pumpAndSettle();
    expect(find.text('2 seçili'), findsOneWidget);
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(alinan, [1, 3]);
    expect(find.byKey(const Key('coklu-secim-ust')), findsNothing, reason: 'eylemden sonra kip kapanir');

    await tester.longPress(find.byKey(const Key('liste-oge-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coklu-secim-tumu')));
    await tester.pumpAndSettle();
    expect(find.text('30 seçili'), findsOneWidget);
    final geri = tester.state<NavigatorState>(find.byType(Navigator).first);
    await geri.maybePop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coklu-secim-ust')), findsNothing);
    expect(find.text('Liste'), findsOneWidget, reason: 'geri tusu ekrani KAPATMADI, secimi kapatti');
  });

  test('CokluSecim: son secim kalkinca kip kapanir', () {
    final c = CokluSecim<int>()..baslat(1);
    expect(c.acik, isTrue);
    c.degistir(1);
    expect(c.acik, isFalse);
    expect(c.sayi, 0);
  });

  testWidgets('OLUSTUR-PAYLAS: dosya gecici dizine yazilir, ad TEMIZLENIR, paylas acilir',
      (tester) async {
    final dizin = Directory.systemTemp.createTempSync('p253');
    addTearDown(() => dizin.deleteSync(recursive: true));
    XFile? paylasilan;
    late BuildContext ctx;
    await tester.pumpWidget(l10nApp(Scaffold(body: Builder(builder: (c) {
      ctx = c;
      return const SizedBox.expand();
    }))));
    late bool sonuc;
    await tester.runAsync(() async {
      sonuc = await olusturVePaylas(
        ctx,
        olustur: () async => PaylasimDosyasi(
          baytlar: Uint8List.fromList([1, 2, 3]),
          dosyaAdi: '../makbuz/2026-10.pdf',
          mimeTuru: 'application/pdf',
        ),
        geciciDizin: () async => dizin,
        paylasici: (d, konu, konum) async => paylasilan = d,
      );
    });
    await tester.pumpAndSettle();
    expect(sonuc, isTrue);
    expect(paylasilan!.name, '__makbuz_2026-10.pdf');
    expect(paylasilan!.path.startsWith(dizin.path), isTrue, reason: 'dizin disina yazilmaz');
    expect(File(paylasilan!.path).readAsBytesSync(), [1, 2, 3]);
    expect(paylasilan!.mimeType, 'application/pdf');
    expect(find.byKey(const Key('paylas-hazirlaniyor')), findsNothing);
  });

  testWidgets('OLUSTUR-PAYLAS: olusturma duserse HATA cumlesi, paylas ACILMAZ', (tester) async {
    var cagrildi = false;
    late BuildContext ctx;
    await tester.pumpWidget(l10nApp(Scaffold(body: Builder(builder: (c) {
      ctx = c;
      return const SizedBox.expand();
    }))));
    late bool sonuc;
    await tester.runAsync(() async {
      sonuc = await olusturVePaylas(
        ctx,
        olustur: () async => throw Exception('500'),
        geciciDizin: () async => Directory.systemTemp,
        paylasici: (d, k, o) async => cagrildi = true,
      );
    });
    await tester.pumpAndSettle();
    expect(sonuc, isFalse);
    expect(cagrildi, isFalse);
    expect(find.text('Dosya oluşturulamadı.'), findsOneWidget);
  });
}
