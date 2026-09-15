/// (P237 §4) MOBIL ANKET EKRANLARI — dort eksik alan.
///
/// =========================================================================
/// NE OLCULUYOR
/// =========================================================================
/// P237 §3'te model ve API katmani tamamlanmis, MOBIL FORM/EKRAN alanlari
/// eksik birakilmisti (kararlarda "yapilmadi" olarak yazildi). Burada o
/// dort sey olculuyor:
///   1. tarih araligi (baslangic/bitis) — secilebiliyor, temizlenebiliyor,
///      ters aralik ISTEK ATILMADAN reddediliyor,
///   2. malik/kiraci ayrimi — YALNIZ sakin hedeflendiginde ciziliyor ve
///      gizlendiginde govdeye GIRMIYOR,
///   3. sonuc grafigi — yalniz sunucu sayilari verdiyse ciziliyor,
///   4. oy dokumu ekrani — anonim ankette ISTEK ATILMIYOR.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/grafik/grafik_karti.dart';
import 'package:mobile/src/features/anket/data/anket_api.dart';
import 'package:mobile/src/features/anket/domain/anket_models.dart';
import 'package:mobile/src/features/anket/presentation/anket_form.dart';
import 'package:mobile/src/features/anket/presentation/anket_oy_dokumu_screen.dart';
import 'package:mobile/src/features/anket/presentation/anket_screen.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';

import 'helpers/l10n_test_app.dart';

/// Taklit API — GONDERILEN TASLAGI saklar.
///
/// Dikis yeri BURADA degil `p237_anket_test.dart`te (taklit HTTP adapter);
/// bu dosya EKRANIN ne GONDERDIGINI olcer, gonderdigi seyin telde nasil
/// gorundugunu degil.
class _SahteAnketApi implements AnketApi {
  _SahteAnketApi({this.anketler = const [], this.dokum = const [], this.hata});

  final List<Anket> anketler;
  final List<AnketOyKim> dokum;
  final Object? hata;
  AnketTaslak? gonderilen;
  int dokumCagrisi = 0;

  @override
  Future<List<Anket>> liste() async => anketler;

  @override
  Future<Anket> olustur(AnketTaslak taslak) async {
    gonderilen = taslak;
    return _anket();
  }

  @override
  Future<Anket> kapat(String anketId) async => _anket();

  @override
  Future<List<AnketOyKim>> oyDokumu(String anketId) async {
    dokumCagrisi++;
    if (hata != null) throw hata!;
    return dokum;
  }

  @override
  Future<Anket> oyVer(String anketId, String secenekId) async => _anket();
}

Anket _anket({
  bool anonim = false,
  bool sonucVar = true,
  List<int?> oylar = const [7, 3],
}) =>
    Anket(
      id: 'a1',
      baslik: 'Otopark düzeni',
      acik: true,
      anonim: anonim,
      toplamOy: sonucVar ? 10 : null,
      secenekler: [
        AnketSecenek(id: 's1', metin: 'Evet', oy: oylar[0]),
        AnketSecenek(id: 's2', metin: 'Hayır', oy: oylar[1]),
      ],
    );

void main() {
  group('1) TARIH ARALIGI', () {
    testWidgets('BASLANGIC ve BITIS secilebilir ve TEMIZLENEBILIR',
        (tester) async {
      await tester.pumpWidget(_form(_SahteAnketApi()));
      await tester.pumpAndSettle();

      // Baslangicta HICBIR TARIH YOK: "hemen acik, suresiz" en sik hal.
      expect(find.byKey(const Key('anket-baslangic-temizle')), findsNothing);
      expect(find.byKey(const Key('anket-bitis-temizle')), findsNothing);

      await tester.tap(find.byKey(const Key('anket-baslangic')));
      await tester.pumpAndSettle();
      // ONAY DUGMESI METINLE HEDEFLENMEZ: Material takvim/saat
      // diyaloglarinin onay etiketi Flutter surumune ve dile gore
      // degisiyor ('TAMAM'/'Tamam'/'OK'); ilk yazim 'TAMAM' arayip
      // sifir widget buldu. `TextButton`larin SONUNCUSU onaydir.
      await tester.tap(find.byType(TextButton).last);  // gun
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextButton).last);  // saat
      await tester.pumpAndSettle();

      // Secildi -> TEMIZLE dugmesi belirdi.
      expect(find.byKey(const Key('anket-baslangic-temizle')), findsOneWidget);

      await tester.tap(find.byKey(const Key('anket-baslangic-temizle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('anket-baslangic-temizle')), findsNothing);
    });

    testWidgets('TERS ARALIK: istek ATILMADAN reddedilir', (tester) async {
      // Sunucu 422 veriyor ama yapilabilecek bir uyariyi aga havale
      // etmek, kullaniciyi bekletip sonra reddetmek olurdu.
      final api = _SahteAnketApi();
      await tester.pumpWidget(_form(api));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('anket-baslik')), 'Otopark');
      await tester.enterText(
          find.byKey(const Key('anket-maddeler')), 'Evet\nHayır');

      // Iki tarih de AYNI ana kurulur (ikisinde de varsayilan "simdi"
      // onaylanir) -> bitis baslangictan SONRA DEGIL.
      for (final anahtar in ['anket-baslangic', 'anket-bitis']) {
        await tester.tap(find.byKey(Key(anahtar)));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(TextButton).last);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(TextButton).last);
        await tester.pumpAndSettle();
      }

      // GORUNUR HALE GETIR: form uzun ve kaydet dugmesi katlamanin
      // altinda kaliyor; dogrudan `tap` "hit test warning" verip
      // dokunmuyordu — testi sahte-yesil birakan bir tuzak.
      await tester.ensureVisible(find.byKey(const Key('anket-kaydet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('anket-kaydet')));
      await tester.pumpAndSettle();

      expect(api.gonderilen, isNull, reason: 'istek ATILMAMALIYDI');
      expect(find.textContaining('başlangıçtan sonra'), findsOneWidget);
    });
  });

  group('2) MALIK/KIRACI AYRIMI', () {
    testWidgets('HEDEF BOSKEN (herkes) ayrim CIZILIR', (tester) async {
      await tester.pumpWidget(_form(_SahteAnketApi()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('anket-sakin-tipi')), findsOneWidget);
    });

    testWidgets('YALNIZ GUVENLIK hedeflenince ayrim CIZILMEZ',
        (tester) async {
      await tester.pumpWidget(_form(_SahteAnketApi()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('anket-hedef-security')));
      await tester.pumpAndSettle();
      // "yalniz guvenlik ekibi" + "yalniz malikler" birlikte anlamsiz;
      // sunucu da ayrimi personele UYGULAMAZ.
      expect(find.byKey(const Key('anket-sakin-tipi')), findsNothing);

      // SAKIN de eklenince GERI GELIR.
      await tester.tap(find.byKey(const Key('anket-hedef-resident')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('anket-sakin-tipi')), findsOneWidget);
    });
  });

  group('3) SONUC GRAFIGI', () {
    testWidgets('SAYILAR GELDIYSE grafik cizilir', (tester) async {
      final api = _SahteAnketApi(anketler: [_anket()]);
      await tester.pumpWidget(_ekran(api));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('anket-grafik')), findsOneWidget);
      expect(find.byType(GrafikKarti), findsOneWidget);
      // RENK TEK BASINA ANLAM TASIMAZ (P223): sayi cubugun yaninda yazar.
      expect(find.textContaining('7'), findsWidgets);
    });

    testWidgets('ACIK ANKETTE sayilar NULL — grafik CIZILMEZ',
        (tester) async {
      // Surusel etki: acik ankette sunucu `oy`u null doner. Sifirlarla
      // grafik cizmek "kimse oy vermedi" gibi YANLIS bir dunya olurdu.
      final api = _SahteAnketApi(
        anketler: [_anket(sonucVar: false, oylar: const [null, null])],
      );
      await tester.pumpWidget(_ekran(api));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('anket-grafik')), findsNothing);
    });
  });

  group('4) OY DOKUMU EKRANI', () {
    testWidgets('ADLI ankette YONETICIYE giris cizilir', (tester) async {
      final api = _SahteAnketApi(anketler: [_anket()]);
      await tester.pumpWidget(_ekran(api));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('anket-dokum-a1')), findsOneWidget);
    });

    testWidgets('ANONIM ankette giris HIC CIZILMEZ', (tester) async {
      final api = _SahteAnketApi(anketler: [_anket(anonim: true)]);
      await tester.pumpWidget(_ekran(api));
      await tester.pumpAndSettle();
      // Yapilamayacak seyi hic teklif etmiyoruz (oy dugmesiyle ayni kural).
      expect(find.byKey(const Key('anket-dokum-a1')), findsNothing);
    });

    testWidgets('ANONIM ankette ekran acilsa bile ISTEK ATILMAZ',
        (tester) async {
      final api = _SahteAnketApi(anketler: const []);
      await tester.pumpWidget(_dokumEkrani(api, _anket(anonim: true)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('anket-dokum-anonim')), findsOneWidget);
      // ISTEK ATILMADI: 409 hatasi gostermek "bir sey ters gitti"
      // izlenimi verirdi; oysa veri BILEREK tutulmuyor.
      expect(api.dokumCagrisi, 0);
    });

    testWidgets('ADLI ankette DOKUM cizilir: kim, ne zaman, neye',
        (tester) async {
      final api = _SahteAnketApi(dokum: [
        AnketOyKim(
          userId: 'u1',
          ad: 'Ali Veli',
          secenekId: 's1',
          secenekMetin: 'Evet',
          createdAt: DateTime.utc(2026, 9, 2, 10),
        ),
      ]);
      await tester.pumpWidget(_dokumEkrani(api, _anket()));
      await tester.pumpAndSettle();

      expect(api.dokumCagrisi, 1);
      expect(find.text('Ali Veli'), findsOneWidget);
      expect(find.text('Evet'), findsOneWidget);
    });

    testWidgets('HATA halinde BOS LISTE gosterilmez', (tester) async {
      // Bos liste "kimse oy vermedi" demekti — YANLIS bilgi.
      final api = _SahteAnketApi(hata: Exception('ag'));
      await tester.pumpWidget(_dokumEkrani(api, _anket()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('anket-dokum-hata')), findsOneWidget);
      expect(find.byKey(const Key('anket-dokum-bos')), findsNothing);
    });
  });
}

Widget _form(_SahteAnketApi api) => ProviderScope(
      overrides: [anketApiProvider.overrideWithValue(api)],
      child: l10nApp(const Scaffold(body: AnketFormSayfasi())),
    );

Widget _ekran(_SahteAnketApi api) => ProviderScope(
      overrides: [
        anketApiProvider.overrideWithValue(api),
        anketlerProvider.overrideWith((ref) async => api.anketler),
        currentUserRoleProvider.overrideWith((ref) async => UserRole.yonetici),
      ],
      child: l10nApp(const AnketScreen()),
    );

Widget _dokumEkrani(_SahteAnketApi api, Anket anket) => ProviderScope(
      overrides: [anketApiProvider.overrideWithValue(api)],
      child: l10nApp(AnketOyDokumuScreen(anket: anket)),
    );
