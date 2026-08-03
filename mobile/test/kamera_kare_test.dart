/// (P121) IZGARADA CANLI KARO — tazeleme KAPSAMI ve rozetin DÜRÜSTLÜĞÜ.
///
/// İki şey ölçülür ve ikisi de "sessizce yanlış olabilecek" cinstendir:
///
/// 1. **KAPSAM.** Sayaç yalnız ızgara görünürken çalışmalı. Bozulursa
///    hiçbir test düşmez, hiçbir ekran bozulmaz — yalnız kullanıcı başka
///    ekrandayken ve uygulama arka plandayken dakikada onlarca istek gider.
///    "Canlı" görünen bir ekranın en sessiz pil hatası budur; ancak bir
///    ölçüm yakalayabilir.
/// 2. **ROZET.** "CANLI", ekranda GERÇEKTEN o anın karesi varken
///    yazılmalı. Bayat bir karenin üstünde "canlı" demek, güvenlik
///    görevlisi için "şu an böyle" ile "en son böyleydi" arasındaki farkı
///    siler — bu ekranın tek işi o fark.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';
import 'package:mobile/src/features/cameras/presentation/kamera_karesi.dart';
import 'package:mobile/src/features/cameras/presentation/kare_tazeleme.dart';

const _kare = 'http://frigate.local:5000/api/kapi/latest.jpg';

Camera _kamera({String? snapshot = _kare, String id = 'k1'}) => Camera(
      id: id,
      ad: 'Ana Kapı',
      streamUrl: 'https://o/x.m3u8',
      snapshotUrl: snapshot,
      oynatilabilir: true,
    );

/// Sayaç durumunu okumak için: ağaçtaki [KareTazelemeState].
/// `skipOffstage: false` ZORUNLU: ustune tam ekran bir rota acilinca alttaki
/// agac OFFSTAGE olur ve varsayilan `find` onu ATLAR — testin olcmek
/// istedigi durum tam olarak o an.
KareTazelemeState _durum(WidgetTester t) => t.state<KareTazelemeState>(
    find.byType(KareTazeleme, skipOffstage: false));

Widget _ekran({
  required RouteObserver<ModalRoute<void>> gozlemci,
  bool etkin = true,
  Duration aralik = const Duration(milliseconds: 40),
  List<String>? gunluk,
}) {
  return MaterialApp(
    navigatorObservers: [gozlemci],
    home: Builder(
      builder: (context) => Scaffold(
        body: KareTazeleme(
          rotaGozlemcisi: gozlemci,
          etkin: etkin,
          aralik: aralik,
          builder: (context, nesil) => Column(
            children: [
              Text('nesil=$nesil'),
              SizedBox(
                height: 80,
                width: 120,
                child: KameraKaresi(
                  kamera: _kamera(),
                  nesil: nesil,
                  yerTutucu: const Text('YER-TUTUCU'),
                  gorselYapici: (adres) {
                    gunluk?.add(adres);
                    return Text('KARE:$adres');
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('USTTEKI')),
                  ),
                ),
                child: const Text('ac'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('kareAdresi', () {
    test('SORGUSUZ adrese `?` ile eklenir', () {
      expect(kareAdresi('http://a/b.jpg', 3), 'http://a/b.jpg?_k=3');
    });

    test('SORGULU adrese `&` ile eklenir — var olan sorgu KORUNUR', () {
      // Frigate benzeri gecitlerde adres zaten `?h=480` tasiyabilir;
      // korlemesine `?` eklemek adresi BOZARDI.
      expect(kareAdresi('http://a/b.jpg?h=480', 2), 'http://a/b.jpg?h=480&_k=2');
    });

    test('HER NESIL FARKLI adres uretir (onbellek kirilir)', () {
      // Ayni adres tekrar edilseydi Flutter onbellekten AYNI kareyi verir
      // ve karo "canli" gorunup HIC degismezdi.
      expect(kareAdresi('http://a/b.jpg', 1),
          isNot(kareAdresi('http://a/b.jpg', 2)));
    });
  });

  group('tazeleme KAPSAMI', () {
    testWidgets('izgara gorunurken sayac ILERLER', (t) async {
      final g = RouteObserver<ModalRoute<void>>();
      await t.pumpWidget(_ekran(gozlemci: g));
      expect(find.text('nesil=0'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 45));
      expect(find.text('nesil=1'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 45));
      expect(find.text('nesil=2'), findsOneWidget);
      // Zamanlayiciyi kapat (pending timer uyarisi).
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('USTUNE EKRAN ACILINCA sayac DURUR, donunce devam eder',
        (t) async {
      final g = RouteObserver<ModalRoute<void>>();
      await t.pumpWidget(_ekran(gozlemci: g));
      expect(_durum(t).calisiyor, isTrue);

      await t.tap(find.text('ac'));
      await t.pumpAndSettle();
      expect(find.text('USTTEKI'), findsOneWidget);
      expect(_durum(t).calisiyor, isFalse,
          reason: 'izgara gorunmuyorken istek atilmamali');

      final durduguNesil = _durum(t).nesil;
      await t.pump(const Duration(milliseconds: 200));
      expect(_durum(t).nesil, durduguNesil,
          reason: 'durmus sayac ILERLEMEMELI');

      // `element` da OFFSTAGE'i atlar; pop icin ustteki rotanin context'i
      // kullanilir (o gorunur durumda).
      final ctx = t.element(find.text('USTTEKI'));
      Navigator.of(ctx).pop();
      // `pumpAndSettle` KULLANILAMAZ: donuste periyodik sayac yeniden
      // baslar ve kare istemeye devam eder, yani agac hicbir zaman
      // "durulmaz" — pumpAndSettle zaman asimina ugrar (olculdu). Gecis
      // animasyonu icin sabit sureli pump yeterli.
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(_durum(t).calisiyor, isTrue, reason: 'donunce devam etmeli');
      // Donuste HEMEN tazelenir (8 sn'ye kadar bayat kareye bakilmasin).
      expect(_durum(t).nesil, greaterThan(durduguNesil));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('ARKA PLANDA sayac DURUR, on planda geri gelir', (t) async {
      final g = RouteObserver<ModalRoute<void>>();
      await t.pumpWidget(_ekran(gozlemci: g));
      expect(_durum(t).calisiyor, isTrue);

      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      expect(_durum(t).calisiyor, isFalse, reason: 'arka planda pil/veri');

      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(_durum(t).calisiyor, isTrue);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('KARE CEKEBILEN KAMERA YOKSA zamanlayici HIC kurulmaz',
        (t) async {
      // Bugunku durum: `snapshot_url` bos. Bos bir izgara icin zamanlayici
      // calistirmak saf israftir.
      final g = RouteObserver<ModalRoute<void>>();
      await t.pumpWidget(_ekran(gozlemci: g, etkin: false));
      expect(_durum(t).calisiyor, isFalse);
      await t.pump(const Duration(milliseconds: 200));
      expect(_durum(t).nesil, 0);
    });

    testWidgets('dispose sonrasi zamanlayici KALMAZ', (t) async {
      final g = RouteObserver<ModalRoute<void>>();
      await t.pumpWidget(_ekran(gozlemci: g));
      await t.pumpWidget(const SizedBox());
      // Bekleyen zamanlayici kalsaydi flutter_test burada patlardi.
      await t.pump(const Duration(milliseconds: 200));
    });
  });

  group('KameraKaresi', () {
    testWidgets('kare adresi YOKSA yer tutucu cizilir (davranis degismez)',
        (t) async {
      await t.pumpWidget(MaterialApp(
        home: KameraKaresi(
          kamera: _kamera(snapshot: null),
          nesil: 0,
          yerTutucu: const Text('YER-TUTUCU'),
          gorselYapici: (a) => Text('KARE:$a'),
        ),
      ));
      expect(find.text('YER-TUTUCU'), findsOneWidget);
    });

    testWidgets('her nesilde YENI adres cekilir', (t) async {
      final g = RouteObserver<ModalRoute<void>>();
      final gunluk = <String>[];
      await t.pumpWidget(_ekran(gozlemci: g, gunluk: gunluk));
      await t.pump(const Duration(milliseconds: 45));
      await t.pump(const Duration(milliseconds: 45));
      await t.pumpWidget(const SizedBox());
      final farkli = gunluk.toSet();
      expect(farkli.length, greaterThanOrEqualTo(3),
          reason: 'nesil basina AYRI adres bekleniyor: $gunluk');
      expect(gunluk.first, contains('_k=0'));
    });

    testWidgets('KAMERA DEGISINCE karo YENI kameranin adresini ceker',
        (t) async {
      Widget kur(String id, String kare) => MaterialApp(
            home: KameraKaresi(
              kamera: Camera(
                id: id,
                ad: 'K',
                streamUrl: 'https://o/x.m3u8',
                snapshotUrl: kare,
                oynatilabilir: true,
              ),
              nesil: 0,
              yerTutucu: const Text('YER-TUTUCU'),
              gorselYapici: (a) => Text('KARE:$a'),
            ),
          );
      await t.pumpWidget(kur('k1', 'http://a/1.jpg'));
      await t.pump();
      expect(find.textContaining('http://a/1.jpg'), findsOneWidget);

      await t.pumpWidget(kur('k2', 'http://a/2.jpg'));
      await t.pump();
      expect(find.textContaining('http://a/2.jpg'), findsOneWidget);
      expect(find.textContaining('http://a/1.jpg'), findsNothing,
          reason: 'onceki kameranin karesi ekranda KALMAMALI');
    });

    testWidgets('KAMERA DEGISINCE "kare var" bayragi SIFIRLANIR', (t) async {
      // Liste yeniden siralanirsa, ONCEKI kameranin karesi `gaplessPlayback`
      // sayesinde ekranda KALIR ve rozet "CANLI" demeye devam ederdi — yani
      // bir kameranin goruntusu baska bir kameranin adiyla, "su an" diye
      // gosterilirdi. Guvenlik ekraninda kabul edilemez.
      //
      // Bu testin ILK hali bu mutasyonu KACIRDI: sahte gorsel yolu kareyi
      // kendiliginden "geldi" sayiyordu. Sahte yol artik BEKLEMEDE birakiyor
      // ve "geldi" sinyalini test kendisi veriyor.
      Widget kur(String id) => MaterialApp(
            home: KameraKaresi(
              kamera: _kamera(id: id),
              nesil: 0,
              yerTutucu: const Text('YER-TUTUCU'),
              gorselYapici: (a) => Text('KARE:$a'),
            ),
          );
      await t.pumpWidget(kur('k1'));
      final durum =
          t.state<KameraKaresiState>(find.byType(KameraKaresi));
      expect(durum.kareVar, isFalse, reason: 'baslangicta kare YOK');

      durum.kareGeldiTest();
      await t.pump();
      expect(durum.kareVar, isTrue, reason: 'kare geldi olarak isaretlendi');

      await t.pumpWidget(kur('k2'));
      await t.pump();
      expect(durum.kareVar, isFalse,
          reason: 'kamera degisti — YENI kare gelene kadar "kare var" DEMEZ');
    });
  });
}
