// TUR 23 — EKRAN SURUSU: mevcut test kosumlarindaki ekranlari 7 dilde cizip
// GORUNEN metni tara. ARB denetimi sozlugu olcer; bu, EKRANI olcer:
// sozlukte olmayan (kaynakta unutulmus) sabitleri ancak bu yakalar.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/theme/app_theme.dart';

import 'gorsel_taklidi.dart';
import 'l10n_test_app.dart';
final _trHarf = RegExp('[ğışĞİŞ]');
/// Turkce DISI diller — surusun asil hedefi (tr'de sizinti kavrami yok).
const surusDilleri = ['en', 'ar', 'ru', 'de', 'fr', 'es'];

/// Cizili agactaki TUM Text/RichText metinlerini toplar.
List<String> gorunenMetinler(WidgetTester tester) {
  final out = <String>[];
  for (final w in tester.allWidgets) {
    if (w is Text && w.data != null) out.add(w.data!);
    if (w is RichText) {
      final s = w.text.toPlainText();
      if (s.isNotEmpty) out.add(s);
    }
  }
  return out;
}

/// Test kosumlarindaki SUNUCU/TENANT verisi — cevrilmemesi DOGRU olan
/// metinler. Surusun isi UI SABITLERINI yakalamak; veriyi "sizinti" saymak
/// yanlis alarm uretir ve taramayi zamanla susturur.
const surusVerisi = <String>{
  'Mehmet', '34 ABC 123', 'Ana Kapı', 'Havuz temizliği', 'Kazan dairesi',
  'Gece devriyesi', 'Temizlik', 'Asansör arızası', 'Bahçe Düzenlemesi',
  'Mng Kargo', 'Aras Kargo', 'Yurtiçi', 'Kerem', 'Ayşe', 'Acme Plaza',
  // Ana ekran kosumlarinin verisi (tur 32): profil adi + vardiya adi.
  'Çiğdem', 'Sabah Vardiyası',
};

/// Marka + kullanici VERISI disinda Turkce sabit var mi?
void trSizintisiYok(WidgetTester tester, String dil, {Set<String> veri = const {}}) {
  for (final m in gorunenMetinler(tester)) {
    if (veri.any(m.contains)) continue;           // sunucu/test VERISI
    // MARKA KILIDI (README §15): kelime isareti + logo alt basligi.
    if (m.contains('Yönetio') || m.contains('GÜVENLİK & DANIŞMANLIK')) continue;
    expect(_trHarf.hasMatch(m), isFalse, reason: '$dil ekraninda TR: "$m"');
  }
}

/// Ekrani ciz. [gorsel] ise cizim `runAsync` icinde yapilir: `Image.network`
/// yalniz GERCEK zamanda cozulur (kodek motora gider), sahte zamanda gorsel
/// SONSUZA DEK "yukleniyor" kalir ve fotografli duzen hic cizilmez (tur 34).
/// [hazirla] cizimden SONRA calisir: ekrani olculecek DURUMA getirir
/// (listeden detaya girmek, sekme acmak...). Surus her dilde yeniden
/// cizdigi icin bu adim da her dilde tekrarlanir; bu yuzden DILDEN BAGIMSIZ
/// bir bulucu kullanilmalidir (sunucu verisi, `Key`, ikon).
///
/// DIKKAT: fotografli suruste [hazirla] `pumpAndSettle` CAGIRMAMALIDIR.
/// Gorsel yuklenirken cizilen `CircularProgressIndicator` SONSUZ bir
/// animasyondur; oturma hicbir zaman gerceklesmez ("pumpAndSettle timed
/// out"). Bunun yerine `pump()` + rota gecisi kadar `pump(sure)` kullanin;
/// gorseller ardindan gercek zamanda yuklenir ve oturma o zaman yapilir.
Future<void> _ciz(
  WidgetTester tester,
  Widget w, {
  required bool gorsel,
  Future<void> Function(WidgetTester)? hazirla,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(w);
  if (gorsel) {
    // Gorsel yuklenmeden `pumpAndSettle` CAGRILMAZ: yuklenirken cizilen
    // `CircularProgressIndicator` sonsuz animasyondur, oturma gerceklesmez.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _gorselleriYukle(tester);
  } else {
    await tester.pumpAndSettle();
  }
  if (hazirla != null) {
    await hazirla(tester);
    // Hazirlik yeni bir ekran actiysa ONUN gorselleri de yuklenmeli.
    if (gorsel) await _gorselleriYukle(tester);
  }
}

/// Bekleyen `Image.network` isteklerini GERCEK zamanda tamamlat.
///
/// `pumpAndSettle` `runAsync` ICINDE KULLANILAMAZ (sahte zamanlayici devre
/// disidir, "pumpAndSettle timed out" ile duser). Bu yuzden gercek zamanda
/// yalnizca TEK kare cizilir + kisa bir bekleme yapilir (HTTP + kodek), sonra
/// sahte zamana donup normal sekilde oturtulur.
Future<void> _gorselleriYukle(WidgetTester tester) async {
  // SABIT bekleme YETMEZ: tam suit dort izolasyonu paralel kosuyor ve kodek
  // bazen 80 ms'i asiyor — tek basina gecen surus suitte "fotograf
  // CIZILMEDI" ile duserdi. Cozulene kadar (ya da ust sinira kadar) beklenir.
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() async {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    final resimler = tester.allWidgets.whereType<RawImage>();
    if (resimler.isEmpty || resimler.any((r) => r.image != null)) return;
  }
}

/// DAR EKRAN surusu (tur 26) — panelin `tools/dar-ekran-surusu.mjs`inin
/// mobil karsiligi.
///
/// Flutter'da tasma bir ISTISNA olarak raporlanir ("A RenderFlex overflowed
/// by N pixels"); `pumpAndSettle` sonrasi `takeException()` onu verir. 320 dp
/// bilincli olarak SERT bir esiktir: piyasadaki en dar telefonlar + en buyuk
/// yazi tipi olcegi. Turkce sigan bir kutu Rusca/Almanca'da tasabilir —
/// tur 24'te `bina_duzenleme` (ru/es) ve tur 25'te panelin rapor sekmeleri
/// (de) boyle bulundu.
Future<void> darEkranSurusu(
  WidgetTester tester,
  Widget Function(String dil) kur, {
  double genislik = 320,
  double yukseklik = 900,
  Set<String> veri = const {},
  bool gorsel = false,
  Future<void> Function(WidgetTester)? hazirla,
}) async {
  tester.view.physicalSize = Size(genislik, yukseklik);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  for (final dil in surusDilleri) {
    // `takeException()` yalniz istisnayi verir, HANGI WIDGET oldugunu degil.
    // Tanilama `FlutterErrorDetails` icindedir — surus boyunca yakalanir.
    final ayrinti = <String>[];
    final eskiOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      ayrinti.add('${d.exception}\n${d.context}');
      eskiOnError?.call(d);
    };
    await _ciz(tester, kur(dil), gorsel: gorsel, hazirla: hazirla);
    FlutterError.onError = eskiOnError;
    // Tasma ISTISNASI: hangi dilde oldugu mesajda gorunsun.
    final hata = tester.takeException();
    expect(hata, isNull,
        reason: '$dil ($genislik dp) tasti:\n'
            '${ayrinti.join("\n---\n")}');
    trSizintisiYok(tester, dil, veri: veri);
  }
}

/// YAZI TIPI OLCEGI surusu (tur 27) — erisilebilirlik x i18n kesisimi.
///
/// Android/iOS'ta kullanici yaziyi 2x'e kadar buyutebilir. Uzun ceviri
/// (Almanca/Rusca) + buyuk punto, dar ekrandan DAHA sert bir testtir:
/// metin buyur ama kutu buyumez. `TextScaler` MediaQuery'den gelir, bu
/// yuzden ekran kurucusunu SARARIZ (ekranlarin kendisi degismez).
Future<void> yaziOlcegiSurusu(
  WidgetTester tester,
  Widget Function(String dil) kur, {
  double olcek = 2.0,
  double genislik = 430,
  double yukseklik = 1600,
  Set<String> veri = const {},
  bool gorsel = false,
  Future<void> Function(WidgetTester)? hazirla,
}) async {
  tester.view.physicalSize = Size(genislik, yukseklik);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  for (final dil in surusDilleri) {
    final ayrinti = <String>[];
    final eskiOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      ayrinti.add('${d.exception}');
      eskiOnError?.call(d);
    };
    await _ciz(
      tester,
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(olcek)),
        child: kur(dil),
      ),
      gorsel: gorsel,
      hazirla: hazirla,
    );
    FlutterError.onError = eskiOnError;
    final hata = tester.takeException();
    expect(hata, isNull,
        reason: '$dil (olcek ${olcek}x) tasti:\n${ayrinti.join("\n---\n")}');
  }
}

/// Anlamsal (semantics) agactaki TUM etiketleri toplar.
///
/// `Text` taramasi EKRANDA GORUNEN metni olcer; ekran okuyucu ise
/// SEMANTICS agacini okur. Ikisi ayni degildir: `tooltip:`, `Semantics(label:)`,
/// `IconButton` ipuclari ve gorsel alternatif metinleri yalniz burada gorunur.
List<String> anlamsalEtiketler(WidgetTester tester) {
  final out = <String>[];
  void gez(SemanticsNode n) {
    final e = n.label.trim();
    if (e.isNotEmpty) out.add(e);
    final ipucu = n.tooltip.trim();
    if (ipucu.isNotEmpty) out.add(ipucu);
    n.visitChildren((c) {
      gez(c);
      return true;
    });
  }
  final kok = tester.binding.rootPipelineOwner.semanticsOwner?.rootSemanticsNode ??
      tester.binding.renderViews.first.debugSemantics;
  if (kok != null) gez(kok);
  return out;
}

/// EKRAN OKUYUCU surusu (tur 29).
///
/// Uc sey birden olculur:
///   1. dokunulabilir her ogenin ETIKETI var mi (etiketsiz dugme ekran
///      okuyucuda "dugme" diye okunur — ne yaptigi bilinmez),
///   2. dokunma hedefleri Android kilavuzunun 48x48 esigini tutuyor mu,
///   3. SEMANTICS etiketleri cevrilmis mi — gorunen metin cevrilip
///      `tooltip`/`Semantics(label:)` Turkce kalabilir; o zaman gormeyen
///      kullanici Arapca arayuzde Turkce duyar.
Future<void> ekranOkuyucuSurusu(
  WidgetTester tester,
  Widget Function(String dil) kur, {
  Set<String> veri = const {},
  bool dokunmaHedefi = true,
  bool gorsel = false,
  Future<void> Function(WidgetTester)? hazirla,
}) async {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final tutamac = tester.ensureSemantics();
  for (final dil in surusDilleri) {
    await _ciz(tester, kur(dil), gorsel: gorsel, hazirla: hazirla);

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    if (dokunmaHedefi) {
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    }
    for (final etiket in anlamsalEtiketler(tester)) {
      if (veri.any(etiket.contains)) continue;
      if (etiket.contains('Yönetio') ||
          etiket.contains('GÜVENLİK & DANIŞMANLIK')) {
        continue;
      }
      expect(_trHarf.hasMatch(etiket), isFalse,
          reason: '$dil ekran okuyucusunda TR: "$etiket"');
    }
  }
  tutamac.dispose();
}

/// KOYU TEMA surusu (tur 32) — panelin `TEMALAR` eksenine karsilik gelir.
///
/// Neden ayri bir eksen: RENK temaya, METIN uzunlugu dile gore degisir ve
/// ikisi kesisir. Onceki dort surus (dil / dar ekran / yazi olcegi / ekran
/// okuyucu) HEPSI acik temada kostu; koyu zeminde okunmayan bir metin
/// hicbirinde gorunmez.
///
/// Olculen:
///   1. KONTRAST — `textContrastGuideline` cizilen pikselleri orneklder ve
///      WCAG AA esigini uygular. SABIT renk kullanan (`Colors.white`,
///      `Colors.black87`, `Colors.grey[200]`) bir ekran koyu temada burada
///      duser: tema degisir, sabit renk degismez.
///   2. TASMA — koyu tema farkli kenarlik/yogunluk verir.
///   3. TR SIZINTISI — surusun degismeyen kilidi.
///
/// Tema [testTemasi] anahtariyla verilir; boylece mevcut surus kurucular
/// (kur(dil)) HIC DEGISMEDEN koyu temada surulur.
/// GUVENLI DEPO taklidi — YALNIZ koyu tema surusunde gerekir.
///
/// Kontrast kilavuzu ekrani PIKSEL olarak yakalar ve bunu `runAsync` icinde
/// yapar; sahte-zaman askiya alinir. Diger suruslerde sahte-zaman altinda
/// SESSIZCE bekleyen platform kanali cagrilari (`LocaleController._yukle`
/// gizli depodan dili okur) o an gercekten cozulur ve mock yoksa
/// `MissingPluginException` atar. Yani bu ekranin degil, olcum yonteminin
/// gereksinimi.
void _guvenliDepoTaklidi() {
  const kanal = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final kutu = <String, String>{};
  final ileti =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  ileti.setMockMethodCallHandler(kanal, (cagri) async {
    final a = (cagri.arguments as Map?) ?? const {};
    switch (cagri.method) {
      case 'read':
        return kutu[a['key'] as String? ?? ''];
      case 'readAll':
        return Map<String, String>.from(kutu);
      case 'write':
        kutu[a['key'] as String? ?? ''] = a['value'] as String? ?? '';
        return null;
      case 'delete':
        kutu.remove(a['key'] as String? ?? '');
        return null;
      case 'deleteAll':
        kutu.clear();
        return null;
      default:
        return null;
    }
  });
  addTearDown(() => ileti.setMockMethodCallHandler(kanal, null));
}

Future<void> koyuTemaSurusu(
  WidgetTester tester,
  Widget Function(String dil) kur, {
  Set<String> veri = const {},
  bool kontrast = true,
  bool gorsel = false,
  Future<void> Function(WidgetTester)? hazirla,
}) async {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  testTemasi = buildDarkTheme();
  addTearDown(() => testTemasi = null);
  _guvenliDepoTaklidi();
  // Turkce de sürülür: kontrast dilden bagimsizdir ve varsayilan dilin
  // koyu temada okunmasi en az cevirilerinki kadar onemlidir.
  for (final dil in ['tr', ...surusDilleri]) {
    await _ciz(tester, kur(dil), gorsel: gorsel, hazirla: hazirla);
    expect(tester.takeException(), isNull,
        reason: '$dil koyu temada tasti');
    // Surusun BOS KOSMADIGININ kaniti: ekran GERCEKTEN koyu temada cizildi.
    // Kurucu `l10nApp` disinda kendi `MaterialApp`ini kuruyorsa (temayi
    // sabitliyorsa) burada duser — sessizce acik temada surmekten iyidir.
    expect(Theme.of(tester.element(find.byType(Material).first)).brightness,
        Brightness.dark, reason: '$dil: koyu tema uygulanmadi');
    if (kontrast) {
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }
    if (dil != 'tr') trSizintisiYok(tester, dil, veri: veri);
  }
}

/// KLAVYE surusu (tur 33) — ODAK SIRASI ve ODAK TUZAGI.
///
/// Onceki alti surus EKRANI olctu (dil / dar ekran / yazi olcegi / ekran
/// okuyucu / koyu tema). Klavye baska bir sey olcer: mobilde de harici
/// klavye, katlanabilir cihaz klavyesi ve ANAHTAR ERISIMI (switch access)
/// ayni gezinti agacini kullanir. Dokunmayla calisan bir oge klavyeyle
/// ULASILAMAZ olabilir.
///
/// Olculen uc sey:
///   1. DOKUNMA-YALNIZ oge — `onTap` tasiyan ama odaklanamayan
///      `GestureDetector`. `InkWell`/`IconButton` kendi `Focus`unu kurar;
///      ciplak `GestureDetector` KURMAZ, dolayisiyla TAB ile secilemez.
///   2. TUZAK — TAB dongusu basa donuyor mu, yoksa bir alt kumede mi
///      kaliyor.
///   3. SIRA — odak yukari dogru geri ziplamalari (okuma sirasindan kopuk).
///
/// Dil ekseni: sira DOM/agac sirasidir, dile gore degismez; degisen RTL'de
/// GORSEL siradir. Bu yuzden tr (LTR) + ar (RTL) surulur.
Future<void> klavyeSurusu(
  WidgetTester tester,
  Widget Function(String dil) kur, {
  int azamiTab = 120,
  bool sira = true,
  bool gorsel = false,
  Future<void> Function(WidgetTester)? hazirla,
}) async {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  for (final dil in ['tr', 'ar']) {
    await _ciz(tester, kur(dil), gorsel: gorsel, hazirla: hazirla);

    // --- 1) DOKUNMA-YALNIZ ogeler ---------------------------------------
    final dokunmaYalniz = <String>[];
    for (final el in tester.elementList(find.byType(GestureDetector))) {
      final g = el.widget as GestureDetector;
      if (g.onTap == null) continue;
      // `InkWell`, `IconButton`, `ListTile`... ic yapilarinda GestureDetector
      // kullanir AMA once bir `Focus` kurar. Ust ataları tarayip Focus varsa
      // oge klavyeyle ulasilabilir demektir.
      var odaklanabilir = false;
      var derinlik = 0;
      el.visitAncestorElements((ata) {
        if (ata.widget is Focus || ata.widget is FocusableActionDetector) {
          odaklanabilir = true;
          return false;
        }
        return ++derinlik < 12;
      });
      if (!odaklanabilir) {
        dokunmaYalniz.add(el.debugGetCreatorChain(3).split(' ← ').first);
      }
    }
    expect(dokunmaYalniz, isEmpty,
        reason: '$dil: onTap tasiyan ama KLAVYEYLE ULASILAMAYAN '
            '${dokunmaYalniz.length} GestureDetector — dokunmayla calisir, '
            'TAB ile secilemez: ${dokunmaYalniz.take(3).join(", ")}');

    // --- 2) TAB dongusu --------------------------------------------------
    final sirali = <Rect>[];
    final gorulen = <FocusNode>{};
    for (var i = 0; i < azamiTab; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final f = FocusManager.instance.primaryFocus;
      if (f == null) break;
      if (gorulen.contains(f)) break;      // dongu basa dondu — DOGRU
      gorulen.add(f);
      final r = f.rect;
      if (r.isFinite) sirali.add(r);
    }
    expect(gorulen.length, lessThan(azamiTab),
        reason: '$dil: $azamiTab TAB sonrasi odak hala YENI ogelere gidiyor '
            '— dongu kapanmiyor (tuzak ya da sonsuz liste)');

    // --- 3) SIRA ---------------------------------------------------------
    if (sira) {
      var geri = 0;
      for (var i = 1; i < sirali.length; i++) {
        if (sirali[i].top < sirali[i - 1].top - 40) geri++;
      }
      expect(geri, lessThanOrEqualTo(1),
          reason: '$dil: odak $geri kez yukari geri zipladi — gezinti sirasi '
              'okuma sirasindan kopuk');
    }
  }
}

/// FOTOGRAFLI SURUS (tur 34) — tum eksenleri FOTOGRAFLI veriyle kosar.
///
/// Tur 33'un itirafi: fotograf tasiyan ogeler (kucuk resim izgarasi, yukleme
/// yuvasi, kaplamalar) yalniz fotografli veriyle cizilir; test kosumlarinda
/// fotograf olmadigi icin ALTI SURUS de bu kod yollarina hic ugramamisti.
/// Bu yardimci acigi kapatir: taklit ag gorseli kurar (bkz.
/// [gorselTaklidi]) ve ayni ekrani bes eksende surer.
///
/// [kur] FOTOGRAF ICEREN veriyle kurulmalidir — aksi halde bu surus normal
/// surusun kopyasidir ve hicbir sey eklemez.
Future<void> fotografliSurus(
  WidgetTester tester,
  Widget Function(String dil) kur, {
  Set<String> veri = const {},
  bool dokunmaHedefi = true,
  Future<void> Function(WidgetTester)? hazirla,
}) async {
  gorselTaklidi();
  // `runAsync` sahte zamani askiya alir; o an bekleyen platform kanali
  // cagrilari GERCEKTEN cozulur ve mock yoksa `MissingPluginException`
  // atarlar (tur 32'de ayni sebeple gerekmisti).
  _guvenliDepoTaklidi();
  // Once GORSELIN GERCEKTEN CIZILDIGINI dogrula: taklit calismazsa surus
  // sessizce "fotografsiz" kosar ve hicbir sey eklemez.
  await _ciz(tester, kur('tr'), gorsel: true, hazirla: hazirla);
  final cizilenler = tester.allWidgets.whereType<RawImage>();
  expect(cizilenler.any((r) => r.image != null), isTrue,
      reason: 'fotograf CIZILMEDI — taklit ag gorseli calismiyor ya da '
          'kurucu fotografsiz veri veriyor; bu surus bos kosardi');

  try {
    await darEkranSurusu(tester, kur,
        veri: veri, gorsel: true, hazirla: hazirla);
    await yaziOlcegiSurusu(tester, kur,
        veri: veri, gorsel: true, hazirla: hazirla);
    await ekranOkuyucuSurusu(tester, kur,
        veri: veri,
        dokunmaHedefi: dokunmaHedefi,
        gorsel: true,
        hazirla: hazirla);
    await koyuTemaSurusu(tester, kur,
        veri: veri, gorsel: true, hazirla: hazirla);
    await klavyeSurusu(tester, kur, gorsel: true, hazirla: hazirla);
  } finally {
    // Cerceve, TEST GOVDESI biter bitmez cizim hata ayiklama degiskenlerinin
    // sifirlandigini denetler; `addTearDown` bunun ICIN gec kalir.
    gorselTaklidiKapat();
  }
}

/// TUM EKSENLER (tur 37) — fotografsiz ekranlar icin tek cagri.
///
/// [fotografliSurus]un fotograf gerektirmeyen kardesi: dar ekran, yazi
/// olcegi, ekran okuyucu, koyu tema ve klavye eksenlerini sirayla kosar.
/// Tur 36 envanteri "hic surulmemis ekran" listesi cikarinca, o ekranlari
/// tek tek bes ayri testle eklemek yerine bu yardimci yazildi.
Future<void> tumEksenlerSurusu(
  WidgetTester tester,
  Widget Function(String dil) kur, {
  Set<String> veri = const {},
  bool dokunmaHedefi = true,
  bool kontrast = true,
  bool sira = true,
  Future<void> Function(WidgetTester)? hazirla,
}) async {
  // Bu ekranlarin cogu gizli depoya (dil/oturum) dokunur; koyu tema surusu
  // `runAsync` kullandigi icin taklit gerekir (tur 32 notu).
  _guvenliDepoTaklidi();
  await darEkranSurusu(tester, kur, veri: veri, hazirla: hazirla);
  await yaziOlcegiSurusu(tester, kur, veri: veri, hazirla: hazirla);
  await ekranOkuyucuSurusu(tester, kur,
      veri: veri, dokunmaHedefi: dokunmaHedefi, hazirla: hazirla);
  await koyuTemaSurusu(tester, kur,
      veri: veri, kontrast: kontrast, hazirla: hazirla);
  await klavyeSurusu(tester, kur, sira: sira, hazirla: hazirla);
}

/// FORM/ALT SAYFA ACICI (tur 38) — surus `hazirla` parametresi icin.
///
/// Uygulamadaki olusturma formlarinin HEPSI ayni deseni kullanir:
/// `FloatingActionButton` → `showModalBottomSheet`. Bu yardimci FAB'a
/// dokunup sayfanin acilmasini bekler; bulucu DILDEN BAGIMSIZDIR (tur widget
/// tipine bakar, metne degil).
///
/// `pumpAndSettle` KULLANILMAZ: alt sayfa acilirken donen gostergeler ya da
/// surekli animasyonlar oturmayi engelleyebilir (tur 34 notu).
Future<void> fabAc(WidgetTester tester) async {
  final fab = find.byType(FloatingActionButton);
  if (fab.evaluate().isEmpty) {
    throw StateError('Ekranda FloatingActionButton yok — form acilamadi. '
        'Rol kapisi FAB\'i gizliyor olabilir.');
  }
  await tester.tap(fab.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  // ACILDIGINI DOGRULA: dokunma bir sey acmadiysa surus sessizce LISTEYI
  // olcer ve "form temiz" raporu bos cikardi (tur 32/33'teki bos-surus
  // riskinin ayni sinifi).
  if (find.byType(BottomSheet).evaluate().isEmpty) {
    throw StateError('FAB\'a dokunuldu ama alt sayfa acilmadi.');
  }
}
