/// (P250 §4) KURULUM VİDEOLARI — mobil tam ekran sayfa + ana sayfa kartı.
///
/// Oynatıcı SAHTE kurucuyla değiştirilir (testte WebView yok): `ENDED` ve
/// oynatıcı hatası elle tetiklenir. Ölçülen: tel üzerindeki istek
/// (`izlendi`), düğmenin vurgulanması, kaydırma, "yakında", uyarı metni.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/egitim/presentation/egitim_oynatici.dart';
import 'package:mobile/src/features/egitim/presentation/kurulum_videolari_karti.dart';
import 'package:mobile/src/features/egitim/presentation/kurulum_videolari_screen.dart';

import 'helpers/l10n_test_app.dart';

Map<String, dynamic> _liste({bool tamam = false}) => {
      'set_kodu': 'yonetici',
      'toplam': 2,
      'izlenen': 1,
      'kurulum_tamam': tamam,
      'adimlar': [
        {'adim_kodu': 'blok', 'izlendi': true,
         'video': {'youtube_id': 'AbCdEfGhIj1', 'baslik': 'Bloklar', 'aciklama': 'Blok ekleme'}},
        {'adim_kodu': 'daire', 'izlendi': false,
         'video': {'youtube_id': 'ZyXwVuTsRq2', 'baslik': 'Daireler', 'aciklama': null}},
        {'adim_kodu': 'daire_tipi', 'izlendi': false, 'video': null},
      ],
    };

class _Tel implements HttpClientAdapter {
  _Tel(this.liste);
  final Map<String, dynamic> liste;
  final istekler = <({String yol, String metot})>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? r, Future<void>? c) async {
    istekler.add((yol: o.path, metot: o.method));
    final govde = o.path.endsWith('/izlendi') ? <String, dynamic>{} : liste;
    return ResponseBody.fromString(jsonEncode(govde), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

class _SahteOynatici {
  String? videoId;
  VoidCallback? onBitti;
  void Function(String)? onHata;
}

Future<(_Tel, _SahteOynatici)> _sur(WidgetTester tester, Widget ekran,
    {bool tamam = false}) async {
  final tel = _Tel(_liste(tamam: tamam));
  final oyn = _SahteOynatici();
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  final kap = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    egitimOynaticiProvider.overrideWithValue(
      ({required videoId, required onBitti, required onHata}) {
        oyn
          ..videoId = videoId
          ..onBitti = onBitti
          ..onHata = onHata;
        return Container(key: Key('sahte-oynatici-$videoId'));
      },
    ),
  ]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: kap, child: l10nApp(ekran)));
  await tester.pumpAndSettle();
  return (tel, oyn);
}

void main() {
  testWidgets('ilk izlenmemis adimda acilir; liste numara/baslik/izlendi', (tester) async {
    final (_, oyn) = await _sur(tester, const KurulumVideolariScreen());
    expect(oyn.videoId, 'ZyXwVuTsRq2');
    expect(find.text('Bloklar'), findsOneWidget);
    expect(find.text('Daireler'), findsWidgets);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('video BITINCE izlendi gider ve "Simdi bu adimi yap" vurgulanir', (tester) async {
    final (tel, oyn) = await _sur(tester, const KurulumVideolariScreen());
    expect(find.byType(OutlinedButton), findsOneWidget);
    oyn.onBitti!();
    await tester.pumpAndSettle();
    expect(tel.istekler.any((i) => i.yol == '/egitim-videolari/daire/izlendi' && i.metot == 'POST'), isTrue);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('egitim-simdi-yap'))).onPressed,
      isNotNull,
    );
  });

  testWidgets('saga kaydirinca sonraki adim; videosuz adim "yakinda"', (tester) async {
    await _sur(tester, const KurulumVideolariScreen());
    await tester.fling(find.byKey(const Key('egitim-sayfalar')), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('egitim-yakinda')), findsOneWidget);
  });

  testWidgets('gizli / yerlestirmesi kapali video: anlasilir uyari', (tester) async {
    final (_, oyn) = await _sur(tester, const KurulumVideolariScreen(baslangic: 'blok'));
    expect(oyn.videoId, 'AbCdEfGhIj1');
    oyn.onHata!('kapali');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('egitim-hata')), findsOneWidget);
    expect(find.textContaining('yerleştirmeye izin verilmemiş'), findsOneWidget);
  });

  testWidgets('ana sayfa karti: ilerleme; kurulum bitince KUCUK ama var', (tester) async {
    await _sur(tester, const Scaffold(body: KurulumVideolariKarti()));
    expect(find.text('1/2 izlendi'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('ana sayfa karti: kurulum tamam -> ilerleme cubugu yok', (tester) async {
    await _sur(tester, const Scaffold(body: KurulumVideolariKarti()), tamam: true);
    expect(find.byKey(const Key('kurulum-videolari-karti')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
