// P36 — KVKK onay kapisi: KAYDIRMA KILIDI + surum + pazarlama izinleri.
//
// Kilidin anlami: kullanici metnin SONUNA gelmeden "Onaylıyorum" etkinlesmez.
// Bu bir UX susu degil — aydinlatmanin GERCEKTEN gosterildiginin tek
// istemci-tarafi kanitidir.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/kvkk/domain/kaydirma_kapisi.dart';
import 'package:mobile/src/features/kvkk/domain/kvkk_models.dart';

void main() {
  group('kaydirma kapisi (saf)', () {
    test('sona gelinmeden KAPALI', () {
      expect(
        kaydirmaKapisiAcik(kaydirmaKonumu: 0, enBuyukKonum: 4000),
        isFalse,
      );
      expect(
        kaydirmaKapisiAcik(kaydirmaKonumu: 3000, enBuyukKonum: 4000),
        isFalse,
      );
    });

    test('esik icinde ACIK — son piksel cihazlarda yakalanamaz', () {
      // TAM esitlik arayan bir kural, kesirli yukseklik/ust-asma efekti
      // yuzunden butonu HIC etkinlestirmezdi.
      expect(
        kaydirmaKapisiAcik(kaydirmaKonumu: 4000, enBuyukKonum: 4000),
        isTrue,
      );
      expect(
        kaydirmaKapisiAcik(
            kaydirmaKonumu: 4000 - kaydirmaEsigiPx, enBuyukKonum: 4000),
        isTrue,
      );
      expect(
        kaydirmaKapisiAcik(
            kaydirmaKonumu: 4000 - kaydirmaEsigiPx - 1, enBuyukKonum: 4000),
        isFalse,
      );
    });

    test('KAYDIRILAMAYAN icerikte kapi ZATEN ACIK', () {
      // Kisa metinli bir tesiste "sona kaydir" beklemek, butonu sonsuza dek
      // kapali birakirdi.
      expect(kaydirmaKapisiAcik(kaydirmaKonumu: 0, enBuyukKonum: 0), isTrue);
    });
  });

  group('durum modeli', () {
    test('metin yoksa kapi KURULMAZ', () {
      final d = KvkkDurum.fromJson({'metin_var': false, 'onay_gerekli': false});
      expect(d.metinVar, isFalse);
      expect(d.onayGerekli, isFalse);
    });

    test('onay gerekli + surum alanlari', () {
      final d = KvkkDurum.fromJson({
        'metin_var': true,
        'onay_gerekli': true,
        'guncel_surum': 3,
        'onayladigi_surum': null,
      });
      expect(d.onayGerekli, isTrue);
      expect(d.guncelSurum, 3);
      expect(d.onayladigiSurum, isNull);
    });

    test('HATA VARSAYILANI kapiyi ACMAZ', () {
      // Ters yon kullaniciyi, metni getiremeyen bir ekranda kilitlerdi:
      // okuyamadigi metni onaylayamaz ve uygulamaya hic giremezdi.
      expect(KvkkDurum.kapaliVarsayilan.onayGerekli, isFalse);
      expect(KvkkDurum.kapaliVarsayilan.metinVar, isFalse);
    });

    test('eksik alanlar GUVENLI cozulur (eski/bozuk yanit)', () {
      final d = KvkkDurum.fromJson(const {});
      expect(d.onayGerekli, isFalse);
      expect(d.guncelSurum, isNull);
    });
  });

  group('pazarlama tercihleri', () {
    test('VARSAYILAN hepsi KAPALI (riza ACIK olmali)', () {
      const t = PazarlamaTercihleri();
      expect(t.eposta, isFalse);
      expect(t.sms, isFalse);
      expect(t.arama, isFalse);
      expect(t.hepsiKapali, isTrue);
    });

    test('kanallar BAGIMSIZ degisir', () {
      const t = PazarlamaTercihleri();
      final e = t.copyWith(eposta: true);
      expect(e.eposta, isTrue);
      // Tek bayrak olsaydi burada SMS de acilirdi.
      expect(e.sms, isFalse);
      expect(e.copyWith(sms: true).eposta, isTrue);
    });

    test('json cift yonlu', () {
      const t = PazarlamaTercihleri(eposta: true, arama: true);
      final geri = PazarlamaTercihleri.fromJson(t.toJson());
      expect(geri.eposta, isTrue);
      expect(geri.sms, isFalse);
      expect(geri.arama, isTrue);
    });
  });

  testWidgets('BUTON kaydirilmadan KAPALI, sona gelince ACIK', (tester) async {
    // Ekranin kendisi ag ister; kilidin davranisi burada AYNI kuralla
    // kurulmus yalin bir iskelette olculur (widget agacina bagimli olmayan
    // saf kural yukarida ayrica test edildi).
    final kaydirma = ScrollController();
    var acik = false;

    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) {
          kaydirma.addListener(() {
            final yeni = kaydirmaKapisiAcik(
              kaydirmaKonumu: kaydirma.position.pixels,
              enBuyukKonum: kaydirma.position.maxScrollExtent,
            );
            if (yeni != acik) setState(() => acik = yeni);
          });
          return Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: kaydirma,
                    child: const SizedBox(height: 3000, child: Text('metin')),
                  ),
                ),
                FilledButton(
                  key: const Key('kvkk-onayla'),
                  onPressed: acik ? () {} : null,
                  child: const Text('Onayla'),
                ),
              ],
            ),
          );
        },
      ),
    ));

    FilledButton buton() =>
        tester.widget<FilledButton>(find.byKey(const Key('kvkk-onayla')));
    expect(buton().onPressed, isNull, reason: 'kaydirilmadan KAPALI');

    kaydirma.jumpTo(kaydirma.position.maxScrollExtent);
    await tester.pump();
    expect(buton().onPressed, isNotNull, reason: 'sona gelince ACIK');
  });
}
