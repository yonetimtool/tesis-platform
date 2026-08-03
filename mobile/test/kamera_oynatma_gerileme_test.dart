/// (P124) OYNATMA GERİLEME KİLİDİ — canlı karo, oynatıcıyı ASLA bozmasın.
///
/// GERÇEK OLAY: kamera oynatma sahada çalışıyordu; ızgaraya canlı karo
/// eklendikten sonra "artık oynatmıyor" bildirimi geldi. Oynatma
/// **gönderilmiş** özelliktir, canlı karo **eklentidir**; çakışırlarsa
/// oynatma kazanır.
///
/// Bu dosya o önceliği KODA BAĞLAR. Ölçtüğü üç şey, karo işinin oynatıcıyı
/// bozabileceği üç yoldur:
///   1. Karoya dokunmak oynatıcıyı GERÇEKTEN açıyor mu (dokunma hedefi
///      karo katmanları arasında kaybolmuş olabilir);
///   2. Oynatıcı, kameranın KENDİ adresiyle mi kuruluyor (kare adresi
///      yayın adresini yutmuş olabilir);
///   3. Karo tazeleme sayacı, oynatıcı açıkken onu ÖNCELEMİYOR ya da
///      atmıyor mu (paylaşılan yaşam döngüsü).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';
import 'package:mobile/src/features/cameras/presentation/camera_player_screen.dart';
import 'package:mobile/src/features/cameras/presentation/kamera_karti.dart';
import 'package:mobile/src/features/cameras/presentation/kare_tazeleme.dart';

import 'helpers/l10n_test_app.dart';
import 'yardimci/video_sahte.dart';

const _yayin = 'https://devstreaming-cdn.apple.com/videos/streaming/examples/'
    'img_bipbop_adv_example_fmp4/master.m3u8';
const _kare = 'http://frigate.local:5000/api/kapi/latest.jpg';

Camera _kamera({String? snapshot}) => Camera(
      id: 'k1',
      ad: 'Ana Kapı',
      streamUrl: _yayin,
      snapshotUrl: snapshot,
      oynatilabilir: true,
    );

void main() {
  testWidgets('KAROYA DOKUNMAK oynaticiyi acar (kare adresi VARKEN de)',
      (t) async {
    // Kare katmani dokunma hedefinin ustune gelirse kullanici karoya
    // dokunur ve HICBIR SEY olmaz — bildirilen belirti tam olarak budur.
    var acilan = 0;
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      home: Scaffold(
        body: KareTazeleme(
          rotaGozlemcisi: RouteObserver<ModalRoute<void>>(),
          etkin: true,
          aralik: const Duration(milliseconds: 50),
          builder: (context, nesil) => SizedBox(
            width: 200,
            height: 200,
            child: KameraKarti(
              kamera: _kamera(snapshot: _kare),
              nesil: nesil,
              onTap: () => acilan++,
              gorselYapici: (adres) => const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.byType(KameraKarti));
    await t.pump();
    expect(acilan, 1, reason: 'karo dokunmayi YUTUYOR — oynatici acilmiyor');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('OYNATICI kameranin KENDI yayin adresiyle kurulur', (t) async {
    // "Kare adresi yayin adresini yutmus olabilir" senaryosu: oynatici
    // `snapshot_url`i degil `oynatilacakUrl`i kullanmali.
    final kurulanlar = <String>[];
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      home: CameraPlayerScreen(
        kamera: _kamera(snapshot: _kare),
        controllerYapici: (k) {
          kurulanlar.add(k.oynatilacakUrl);
          return SahteVideoController();
        },
      ),
    ));
    await t.pumpAndSettle();
    expect(kurulanlar, [_yayin]);
    expect(kurulanlar.single, isNot(contains('latest.jpg')));
  });

  testWidgets('OYNATICI OYNAR duruma gelir (taklit platform)', (t) async {
    late SahteVideoController c;
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      home: CameraPlayerScreen(
        kamera: _kamera(snapshot: _kare),
        controllerYapici: (_) => c = SahteVideoController(),
      ),
    ));
    await t.pumpAndSettle();
    expect(c.hazirlandi, isTrue, reason: 'initialize() cagrilmadi');
    expect(c.value.isPlaying, isTrue, reason: 'play() cagrilmadi/oynamadi');
    expect(c.atildi, isFalse, reason: 'oynatici acilir acilmaz ATILDI');
  });

  testWidgets('KARO TAZELEME sayaci oynaticiyi ONCELEMEZ/ATMAZ', (t) async {
    // Paylasilan yasam dongusu riski: sayac tik atarken oynatici
    // yeniden kurulmamali ya da atilmamali.
    late SahteVideoController c;
    var kurulum = 0;
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      home: Scaffold(
        body: KareTazeleme(
          rotaGozlemcisi: RouteObserver<ModalRoute<void>>(),
          etkin: true,
          aralik: const Duration(milliseconds: 30),
          builder: (context, nesil) => CameraPlayerScreen(
            kamera: _kamera(snapshot: _kare),
            controllerYapici: (_) {
              kurulum++;
              return c = SahteVideoController();
            },
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();
    expect(kurulum, 1);
    // Sayac birkac kez tiklasin.
    await t.pump(const Duration(milliseconds: 35));
    await t.pump(const Duration(milliseconds: 35));
    await t.pump(const Duration(milliseconds: 35));
    expect(kurulum, 1, reason: 'tazeleme oynaticiyi YENIDEN KURDU');
    expect(c.atildi, isFalse, reason: 'tazeleme oynaticiyi ATTI');
    expect(c.value.isPlaying, isTrue, reason: 'oynatma DURDU');
    await t.pumpWidget(const SizedBox());
  });
}
