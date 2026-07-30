// TUR 23 — EKRAN SURUSU: mevcut test kosumlarindaki ekranlari 7 dilde cizip
// GORUNEN metni tara. ARB denetimi sozlugu olcer; bu, EKRANI olcer:
// sozlukte olmayan (kaynakta unutulmus) sabitleri ancak bu yakalar.
import 'dart:io';
import 'dart:math' as math;

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
void trSizintisiYok(
  WidgetTester tester,
  String dil, {
  Set<String> veri = const {},
}) {
  for (final m in gorunenMetinler(tester)) {
    if (veri.any(m.contains)) continue; // sunucu/test VERISI
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
  bool bekleyen = false,
  Future<void> Function(WidgetTester)? hazirla,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(w);
  if (bekleyen) {
    // YUKLENIYOR hali: donen gosterge SONSUZ animasyondur, `pumpAndSettle`
    // asla donmez. Sabit kare pompalanir (tur 44).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    if (hazirla != null) await hazirla(tester);
    return;
  }
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
  bool bekleyen = false,
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
    await _ciz(
      tester,
      kur(dil),
      gorsel: gorsel,
      bekleyen: bekleyen,
      hazirla: hazirla,
    );
    FlutterError.onError = eskiOnError;
    // Tasma ISTISNASI: hangi dilde oldugu mesajda gorunsun.
    final hata = tester.takeException();
    expect(
      hata,
      isNull,
      reason:
          '$dil ($genislik dp) tasti:\n'
          '${ayrinti.join("\n---\n")}',
    );
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
  bool bekleyen = false,
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
      bekleyen: bekleyen,
      hazirla: hazirla,
    );
    FlutterError.onError = eskiOnError;
    final hata = tester.takeException();
    expect(
      hata,
      isNull,
      reason: '$dil (olcek ${olcek}x) tasti:\n${ayrinti.join("\n---\n")}',
    );
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

  final kok =
      tester.binding.rootPipelineOwner.semanticsOwner?.rootSemanticsNode ??
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
  bool bekleyen = false,
  Future<void> Function(WidgetTester)? hazirla,
}) async {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final tutamac = tester.ensureSemantics();
  for (final dil in surusDilleri) {
    await _ciz(
      tester,
      kur(dil),
      gorsel: gorsel,
      bekleyen: bekleyen,
      hazirla: hazirla,
    );

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
      expect(
        _trHarf.hasMatch(etiket),
        isFalse,
        reason: '$dil ekran okuyucusunda TR: "$etiket"',
      );
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
  bool bekleyen = false,
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
    await _ciz(
      tester,
      kur(dil),
      gorsel: gorsel,
      bekleyen: bekleyen,
      hazirla: hazirla,
    );
    expect(tester.takeException(), isNull, reason: '$dil koyu temada tasti');
    // Surusun BOS KOSMADIGININ kaniti: ekran GERCEKTEN koyu temada cizildi.
    // Kurucu `l10nApp` disinda kendi `MaterialApp`ini kuruyorsa (temayi
    // sabitliyorsa) burada duser — sessizce acik temada surmekten iyidir.
    expect(
      Theme.of(tester.element(find.byType(Material).first)).brightness,
      Brightness.dark,
      reason: '$dil: koyu tema uygulanmadi',
    );
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
  bool bekleyen = false,
  Future<void> Function(WidgetTester)? hazirla,
}) async {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  for (final dil in ['tr', 'ar']) {
    await _ciz(
      tester,
      kur(dil),
      gorsel: gorsel,
      bekleyen: bekleyen,
      hazirla: hazirla,
    );

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
    expect(
      dokunmaYalniz,
      isEmpty,
      reason:
          '$dil: onTap tasiyan ama KLAVYEYLE ULASILAMAYAN '
          '${dokunmaYalniz.length} GestureDetector — dokunmayla calisir, '
          'TAB ile secilemez: ${dokunmaYalniz.take(3).join(", ")}',
    );

    // --- 2) TAB dongusu --------------------------------------------------
    final sirali = <Rect>[];
    final gorulen = <FocusNode>{};
    for (var i = 0; i < azamiTab; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final f = FocusManager.instance.primaryFocus;
      if (f == null) break;
      if (gorulen.contains(f)) break; // dongu basa dondu — DOGRU
      gorulen.add(f);
      final r = f.rect;
      if (r.isFinite) sirali.add(r);
    }
    expect(
      gorulen.length,
      lessThan(azamiTab),
      reason:
          '$dil: $azamiTab TAB sonrasi odak hala YENI ogelere gidiyor '
          '— dongu kapanmiyor (tuzak ya da sonsuz liste)',
    );

    // --- 3) SIRA ---------------------------------------------------------
    if (sira) {
      var geri = 0;
      for (var i = 1; i < sirali.length; i++) {
        if (sirali[i].top < sirali[i - 1].top - 40) geri++;
      }
      expect(
        geri,
        lessThanOrEqualTo(1),
        reason:
            '$dil: odak $geri kez yukari geri zipladi — gezinti sirasi '
            'okuma sirasindan kopuk',
      );
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
  expect(
    cizilenler.any((r) => r.image != null),
    isTrue,
    reason:
        'fotograf CIZILMEDI — taklit ag gorseli calismiyor ya da '
        'kurucu fotografsiz veri veriyor; bu surus bos kosardi',
  );

  try {
    await darEkranSurusu(
      tester,
      kur,
      veri: veri,
      gorsel: true,
      hazirla: hazirla,
    );
    await yaziOlcegiSurusu(
      tester,
      kur,
      veri: veri,
      gorsel: true,
      hazirla: hazirla,
    );
    await ekranOkuyucuSurusu(
      tester,
      kur,
      veri: veri,
      dokunmaHedefi: dokunmaHedefi,
      gorsel: true,
      hazirla: hazirla,
    );
    await koyuTemaSurusu(
      tester,
      kur,
      veri: veri,
      gorsel: true,
      hazirla: hazirla,
    );
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
  bool bekleyen = false,
  Future<void> Function(WidgetTester)? hazirla,
}) async {
  // Bu ekranlarin cogu gizli depoya (dil/oturum) dokunur; koyu tema surusu
  // `runAsync` kullandigi icin taklit gerekir (tur 32 notu).
  _guvenliDepoTaklidi();
  await darEkranSurusu(
    tester,
    kur,
    veri: veri,
    bekleyen: bekleyen,
    hazirla: hazirla,
  );
  await yaziOlcegiSurusu(
    tester,
    kur,
    veri: veri,
    bekleyen: bekleyen,
    hazirla: hazirla,
  );
  await ekranOkuyucuSurusu(
    tester,
    kur,
    veri: veri,
    dokunmaHedefi: dokunmaHedefi,
    bekleyen: bekleyen,
    hazirla: hazirla,
  );
  await koyuTemaSurusu(
    tester,
    kur,
    veri: veri,
    kontrast: kontrast,
    bekleyen: bekleyen,
    hazirla: hazirla,
  );
  await klavyeSurusu(
    tester,
    kur,
    sira: sira,
    bekleyen: bekleyen,
    hazirla: hazirla,
  );
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
    throw StateError(
      'Ekranda FloatingActionButton yok — form acilamadi. '
      'Rol kapisi FAB\'i gizliyor olabilir.',
    );
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

/// ONAY DIYALOGU ACICI (tur 40).
///
/// Silme onaylari iki desende tetiklenir: (a) satir sonundaki `PopupMenuButton`
/// icindeki "Sil" ogesi, (b) dogrudan bir `Icons.delete_outline` dugmesi.
/// Bu yardimci ikisini de dener ve diyalogun ACILDIGINI dogrular — dokunma
/// bos giderse surus sessizce LISTEYI olcerdi.
///
/// Bulucular DILDEN BAGIMSIZDIR: menu ogesi metne gore degil, menudeki
/// SIRAYA/ikona gore secilir.
Future<void> silmeOnayiAc(WidgetTester tester) async {
  final menu = find.byType(PopupMenuButton<String>);
  if (menu.evaluate().isNotEmpty) {
    await tester.tap(menu.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Menudeki SON oge "Sil"dir (duzenle, sil sirasi tum ekranlarda ayni).
    final ogeler = find.byType(PopupMenuItem<String>);
    if (ogeler.evaluate().isNotEmpty) {
      await tester.tap(ogeler.last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  } else {
    final sil = find.byIcon(Icons.delete_outline);
    if (sil.evaluate().isEmpty) {
      throw StateError('Silme tetigi yok: ne PopupMenuButton ne delete ikonu.');
    }
    await tester.tap(sil.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
  if (find.byType(AlertDialog).evaluate().isEmpty) {
    throw StateError('Silme dokunuldu ama ONAY DIYALOGU acilmadi.');
  }
}

/// SATIR MENUSU EYLEMI (tur 50) — `hazirla` icin.
///
/// Listelerdeki uc-nokta menusu (`PopupMenuButton`) acilir ve [sira]
/// numarali oge secilir; ardindan acilan alt sayfa/diyalog cizilir.
/// Bulucu DILDEN BAGIMSIZDIR: metne degil menudeki SIRAYA bakar.
///
/// Acildigi DOGRULANIR: dokunma bosa giderse surus sessizce LISTEYI olcer ve
/// "eylem hali temiz" raporu bos cikardi (tur 39/45'te tam bu oldu).
Future<void> Function(WidgetTester) menuEylemi(
  int sira, {
  bool sonucBekle = true,
}) => (tester) async {
  final menu = find.byType(PopupMenuButton<String>);
  expect(menu, findsWidgets, reason: 'satir menusu bulunamadi');
  await tester.tap(menu.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  final ogeler = find.byType(PopupMenuItem<String>);
  expect(
    ogeler.evaluate().length,
    greaterThan(sira),
    reason: 'menude $sira numarali oge yok',
  );
  await tester.tap(ogeler.at(sira));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  if (sonucBekle) {
    final acildi =
        find.byType(BottomSheet).evaluate().isNotEmpty ||
        find.byType(AlertDialog).evaluate().isNotEmpty ||
        find.byType(Dialog).evaluate().isNotEmpty ||
        find.byType(SnackBar).evaluate().isNotEmpty;
    if (!acildi) {
      throw StateError(
        'menu ogesi secildi ama hicbir sonuc cizilmedi '
        '(alt sayfa / diyalog / bildirim yok).',
      );
    }
  }
};

/// EKSEN KOMBINASYONLARI (tur 59).
///
/// Suruslerin eksen DEGERLERI bugune kadar sabitti ve tur 49 envanteri bunu
/// kor nokta olarak yazdi:
///   * hareket: her sey `pumpAndSettle` SONRASI olculuyordu — animasyon
///     SURERKEN hicbir sey olculmedi (tur 30'da panel tarafinda tam bu
///     yanlis alarm vermisti; mobilde ise hic bakilmadi),
///   * yon: yalniz dikey; TABLET/YATAY yerlesim hic cizilmedi,
///   * yazi olcegi: yalniz 1.0 ve 2.0 — 0.85 (kucultme) ve 1.3 (yaygin ara
///     deger) atlandi,
///   * yogunluk: `devicePixelRatio` sabit 1.0 — gercek cihazlar 2.0/3.0,
///   * sistem ayari: KALIN YAZI (`boldText`) hic denenmedi.
///
/// Bu yardimci hepsini tek cagrida surer. Her kombinasyon TASMA ve TR
/// sizintisi icin denetlenir.
Future<void> eksenKombinasyonSurusu(
  WidgetTester tester,
  Widget Function(String dil) kur, {
  Set<String> veri = const {},
  Future<void> Function(WidgetTester)? hazirla,
  bool bekleyen = false,
}) async {
  _guvenliDepoTaklidi();
  addTearDown(tester.view.reset);

  // (ad, genislik, yukseklik, olcek, dpr, kalinYazi)
  const kombinasyonlar = <(String, double, double, double, double, bool)>[
    ('kucuk yazi 0.85x', 430, 900, 0.85, 1.0, false),
    ('ara olcek 1.3x', 430, 900, 1.3, 1.0, false),
    ('tablet dikey 768', 768, 1024, 1.0, 2.0, false),
    ('tablet YATAY 1024', 1024, 768, 1.0, 2.0, false),
    ('telefon YATAY 800', 800, 400, 1.0, 3.0, false),
    ('KALIN YAZI', 430, 900, 1.0, 1.0, true),
    ('kalin + 1.3x + dar', 320, 800, 1.3, 3.0, true),
  ];

  for (final (ad, g, y, olcek, dpr, kalin) in kombinasyonlar) {
    tester.view.physicalSize = Size(g * dpr, y * dpr);
    tester.view.devicePixelRatio = dpr;
    for (final dil in ['tr', 'de', 'ar']) {
      final ayrinti = <String>[];
      final eskiOnError = FlutterError.onError;
      FlutterError.onError = (d) {
        ayrinti.add('${d.exception}');
        eskiOnError?.call(d);
      };
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: Size(g, y),
            devicePixelRatio: dpr,
            textScaler: TextScaler.linear(olcek),
            boldText: kalin,
          ),
          child: kur(dil),
        ),
      );
      if (bekleyen) {
        // Sonsuz animasyon (spinner) varsa `pumpAndSettle` asla donmez.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      } else {
        await tester.pumpAndSettle();
      }
      // Ekrani ACAN adim (FAB, menu, diyalog) bu eksende de kosmali:
      // tasma cogunlukla FORMDA olur, listede degil.
      if (hazirla != null) await hazirla(tester);
      FlutterError.onError = eskiOnError;
      expect(
        tester.takeException(),
        isNull,
        reason: '$ad / $dil tasti:\n${ayrinti.join("\n---\n")}',
      );
      if (dil != 'tr') trSizintisiYok(tester, dil, veri: veri);
    }
  }
}

/// ANIMASYON SURERKEN olcum (tur 59).
///
/// Butun surusler `pumpAndSettle` sonrasi olcuyordu; giris animasyonunun
/// ORTASI hic gorulmedi. Yari yolda kalan bir yerlesim tasabilir ya da
/// gecici olarak okunmaz olabilir. Burada kare kare ilerlenir ve HER KARE
/// tasma icin denetlenir.
Future<void> animasyonSurusu(
  WidgetTester tester,
  Widget Function(String dil) kur, {
  int kare = 8,
  Duration adim = const Duration(milliseconds: 40),
  bool bekleyen = false,
}) async {
  _guvenliDepoTaklidi();
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  for (final dil in ['tr', 'de']) {
    final ayrinti = <String>[];
    final eskiOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      ayrinti.add('${d.exception}');
      eskiOnError?.call(d);
    };
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(kur(dil));
    for (var i = 0; i < kare; i++) {
      await tester.pump(adim);
      final hata = tester.takeException();
      expect(
        hata,
        isNull,
        reason:
            '$dil: animasyonun ${i + 1}. karesinde tasma:\n'
            '${ayrinti.join("\n---\n")}',
      );
    }
    // SONSUZ animasyonlu ekranda (spinner, `repeat()`) `pumpAndSettle`
    // ZAMAN ASIMINA DUSER. Kendi dedektorumuz (tur 59, DEDEKTOR 5) tam bunu
    // yakaladi: son oturma denetimi, surusun kapsamak icin var oldugu ekran
    // sinifinda surusun kendisini dusuruyordu. Bu yuzden `bekleyen` ekranda
    // oturma beklenmez, yalnizca birkac kare daha pompalanir.
    if (bekleyen) {
      for (var i = 0; i < 5; i++) {
        await tester.pump(adim);
      }
    } else {
      await tester.pumpAndSettle();
    }
    FlutterError.onError = eskiOnError;
    expect(tester.takeException(), isNull, reason: '$dil: oturma sonrasi');
  }
}

/// ---- TUR 60: ANLAMSAL OKUMA SIRASI ----
///
/// Tur 29/30 etiketlerin VARLIGINI olctu, SIRASINI degil. Ekran okuyucu
/// gezinme sirasini `SemanticsNode` agacinin TRAVERSAL siralamasindan alir;
/// Flutter bunu cogu zaman geometriden dogru hesaplar ama `sortKey`,
/// `MergeSemantics`, `Semantics(container:)` gruplari, `Stack`/`Overlay`
/// katmanlari ve ayri kaydirma alanlari bu sirayi bozabilir. Bozulunca ekran
/// GORSEL olarak kusursuz kalir — hicbir tasma/kontrast olcumu bunu gormez.
///
/// Bu surus gezinme sirasini GERCEK API'den okur
/// (`debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)`) ve
/// GERIYE ATLAMA arar: bir dugum, kendisinden gorunur bicimde ASAGIDA olan bir
/// dugumden SONRA okunuyorsa ihlal vardir. Ayni bantta da yon denetlenir
/// (LTR'de sola, RTL'de saga geri gitmek ihlal).
class OkunanDugum {
  OkunanDugum(this.etiket, this.kutu);
  final String etiket;
  final Rect kutu;
  @override
  String toString() =>
      '"$etiket" @(${kutu.left.round()},${kutu.top.round()})'
      '-(${kutu.right.round()},${kutu.bottom.round()})';
}

/// Yalniz YAPRAK dugumler toplanir: birlestirilmis (merged) semantik dugum
/// zaten yapraktir, kapsayici dugumlerin kutusu ise bircok bandi kesip
/// yanlis alarm uretir.
List<OkunanDugum> gezinmeSirasi(WidgetTester tester) {
  final out = <OkunanDugum>[];
  final kok = _kokSemantik(tester);
  if (kok == null) return out;

  // `SemanticsNode.rect` EBEVEYN koordinatlarindadir; `transform` de dugumden
  // ebeveyne gecisi verir. Genel (ekran) kutusu icin zincir carpilir.
  void yuru(SemanticsNode n, Matrix4 ust) {
    final m = ust.clone();
    if (n.transform != null) m.multiply(n.transform!);
    final cocuklar = n.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    );
    if (cocuklar.isEmpty) {
      final d = n.getSemanticsData();
      // MODAL PERDESI (tur 79 dedektor duzeltmesi). `showDialog` diyalogun
      // ALTINA tum ekrani kaplayan, "Kapat" etiketli ve `dismiss` eylemi
      // tasiyan bir `ModalBarrier` koyar. Gezinme sirasinda EN SONA gelir ve
      // kutusu her seyi kestigi icin dedektor onu "yukari geri atlama" sayip
      // her diyalog surusunde YANLIS ALARM veriyordu. Perde okuma akisinin
      // parcasi degildir (ekran okuyucu icin "geri/kapat" jesti); disarida
      // birakilir.
      final ekran = tester.binding.renderViews.first.size;
      final perde =
          d.hasAction(SemanticsAction.dismiss) &&
          MatrixUtils.transformRect(m, n.rect).size.width >=
              ekran.width * 0.95 &&
          MatrixUtils.transformRect(m, n.rect).size.height >=
              ekran.height * 0.95;
      if (perde) return;
      final etiket = d.label.trim().isNotEmpty
          ? d.label.trim()
          : d.value.trim().isNotEmpty
          ? d.value.trim()
          : d.tooltip.trim();
      if (etiket.isNotEmpty && !n.rect.isEmpty) {
        out.add(
          OkunanDugum(
            etiket.replaceAll('\n', ' '),
            MatrixUtils.transformRect(m, n.rect),
          ),
        );
      }
      return;
    }
    for (final c in cocuklar) {
      yuru(c, m);
    }
  }

  yuru(kok, Matrix4.identity());
  return out;
}

/// Semantik agacin KOKU: herhangi bir dugumden ebeveyn zinciriyle yukari cik.
SemanticsNode? _kokSemantik(WidgetTester tester) {
  for (final ro in tester.allRenderObjects) {
    var n = ro.debugSemantics;
    if (n == null) continue;
    while (n!.parent != null) {
      n = n.parent;
    }
    return n;
  }
  return null;
}

/// Gezinme sirasindaki GERIYE ATLAMALARI dondurur (bos liste = sira dogru).
///
/// [esik]: bir bandin icinde sayilmak icin izin verilen ortusme payi. Satir
/// icindeki ogeler (baslik + rozet + saat) birbirini dikey olarak keser;
/// bunlar AYNI bant kabul edilir ve aralarinda yalniz YON denetlenir.
List<String> okumaSirasiIhlalleri(
  List<OkunanDugum> dizi, {
  bool rtl = false,
  double esik = 4,
}) {
  final ihlal = <String>[];
  for (var i = 1; i < dizi.length; i++) {
    final a = dizi[i - 1], b = dizi[i];
    // Dikey ORTUSME: iki dugum ayni "bantta" mi (satir icindeki baslik+rozet
    // gibi) yoksa ayri satirlarda mi?
    //
    // ILK SURUM YANLISTI: "b tamamen a'nin ustunde" (b.bottom < a.top) kosulu
    // ARAYA BOSLUK olmasini gerektiriyordu. Bitisik satirlarda (b.bottom ==
    // a.top) ters okuma YAKALANMIYORDU — dedektorun kendi testi (tur 60,
    // DEDEKTOR 2) tam bunu gosterdi.
    final ortusme =
        math.min(a.kutu.bottom, b.kutu.bottom) -
        math.max(a.kutu.top, b.kutu.top);
    // AYNI KOLON mu? Cok kolonlu kart izgarasinda okuyucu bir karti BITIRIP
    // sonraki kartin basina doner; bu DOGRU davranistir. Ayni satirin sag
    // ucundaki zaman damgasi da boyle. Panel tarafinda ayni kural once bu
    // ayrimi yapmiyordu ve panonun dort KPI kartinda yanlis alarm verdi.
    final yatayOrtusme =
        math.min(a.kutu.right, b.kutu.right) -
        math.max(a.kutu.left, b.kutu.left);
    if (ortusme <= esik) {
      if (b.kutu.top < a.kutu.top - esik && yatayOrtusme > esik) {
        ihlal.add('DIKEY GERI: $a  ->  $b');
      }
      continue;
    }
    // Ayni bant: yon denetimi (LTR'de sola, RTL'de saga gitmek geri gitmektir).
    final geri = rtl
        ? b.kutu.right > a.kutu.right + esik
        : b.kutu.left < a.kutu.left - esik;
    if (geri) ihlal.add('YATAY GERI (${rtl ? "rtl" : "ltr"}): $a  ->  $b');
  }
  return ihlal;
}

/// Ekrani kur, gezinme sirasini oku, ihlal varsa DUS.
Future<void> okumaSirasiSurusu(
  WidgetTester tester,
  Widget Function(String dil) kur, {
  List<String> diller = const ['tr', 'ar'],
  Future<void> Function(WidgetTester)? hazirla,
  bool bekleyen = false,
  int enAz = 3,
}) async {
  _guvenliDepoTaklidi();
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // Tutamak GOVDE icinde kapatilir: `addTearDown` cerceve dogrulamasindan
  // sonra kosuyor ve "SemanticsHandle was active at the end of the test"
  // hatasi veriyor (tur 34'teki `gorselTaklidiKapat` dersinin aynisi).
  final tutamak = tester.ensureSemantics();

  for (final dil in diller) {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(kur(dil));
    if (bekleyen) {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    } else {
      await tester.pumpAndSettle();
    }
    if (hazirla != null) await hazirla(tester);

    final dizi = gezinmeSirasi(tester);
    // OLCUM BOS KOSMASIN: etiketli dugum yoksa surus hicbir sey denetlemez.
    expect(
      dizi.length,
      greaterThanOrEqualTo(enAz),
      reason:
          '$dil: gezinme sirasinda yalniz ${dizi.length} etiketli dugum '
          'bulundu — surus bos kosuyor olabilir',
    );
    if (const bool.fromEnvironment('SIRA_SAY')) {
      debugPrint('SIRA_SAY $dil: ${dizi.length} etiketli dugum');
    }
    final ihlal = okumaSirasiIhlalleri(dizi, rtl: dil == 'ar');
    if (ihlal.isNotEmpty) tutamak.dispose();
    expect(
      ihlal,
      isEmpty,
      reason:
          '$dil: ekran okuyucu sirasi gorsel siradan sapiyor:\n'
          '${ihlal.join("\n")}',
    );
  }
  tutamak.dispose();
}

/// ---- TUR 60: YERLESIM KILIDI (gorsel regresyonun metin karsiligi) ----
///
/// Envanterin E maddesi: "47 ekranin 1'i golden ile kilitli". PIKSEL golden'i
/// bilincli olarak regresyon testi yapilmadi (`test/tools/home_referans_golden_test`
/// dosya basindaki nota bakin): font/Skia surumune duyarli ve diff'i
/// okunamiyor. Buradaki kilit ayni isi METIN olarak yapar: her gorunur yazinin
/// KONUMU + OLCUSU + icerigi siralanip dosyaya yazilir.
///
/// * Diff okunabilir: "su yazi 12 px asagi kaydi" dogrudan gorulur.
/// * Yerlesim degisikligi (padding, siralama, sarma) yakalanir.
/// * Renk/golge degisikligi yakalanmaz — onu kontrast surusleri olcuyor.
///
/// Kilit dosyalari degistiginde BILINCLI guncellenir:
/// `flutter test --dart-define=KILIT_GUNCELLE=true`
const bool kilitGuncelle = bool.fromEnvironment('KILIT_GUNCELLE');

/// Gorunur yazilarin (ikonlar dahil) konum/olcu dokumu, y sonra x sirasiyla.
List<String> yerlesimDokumu(WidgetTester tester) {
  final kayitlar = <(double, double, String)>[];
  // `allRenderObjects` ELEMENT agacini gezer; birden fazla element ayni render
  // nesnesini paylastigi icin AYNI `RenderParagraph` birkac kez gelir (basit
  // bir `Text` icin alti kez). Kimlige gore tekillestirilmezse kilit dosyasi
  // ayni satiri tekrarlar ve diff okunmaz olur.
  final gorulen = <RenderParagraph>{};
  for (final ro in tester.allRenderObjects) {
    if (ro is! RenderParagraph) continue;
    if (!gorulen.add(ro)) continue;
    if (!ro.attached || !ro.hasSize) continue;
    var metin = ro.text.toPlainText().replaceAll('\n', ' ').trim();
    if (metin.isEmpty) continue;
    // Ikonlar ozel-kullanim kod noktalaridir; okunur bicime cevir.
    metin = metin.runes
        .map(
          (r) => r >= 0xE000 && r <= 0xF8FF
              ? 'U+${r.toRadixString(16).toUpperCase()}'
              : String.fromCharCode(r),
        )
        .join();
    metin = _zamanMaskesi(metin);
    final p = ro.localToGlobal(Offset.zero);
    kayitlar.add((
      p.dy,
      p.dx,
      '${ro.size.width.round()}x${ro.size.height.round()}  $metin',
    ));
  }
  kayitlar.sort((a, b) {
    final dy = a.$1.compareTo(b.$1);
    return dy != 0 ? dy : a.$2.compareTo(b.$2);
  });
  return [
    for (final (y, x, govde) in kayitlar)
      '${y.round().toString().padLeft(4)},'
          '${x.round().toString().padLeft(4)}  $govde',
  ];
}

/// SAAT/TARIH maskesi.
///
/// Fikstur verisi bilincli olarak "simdi"ye GORELIDIR (tur 55: sabit tarihli
/// seed bayatliyor). Bunun bedeli: ekranda "04.08.2026 00:46" gibi bir yazi
/// varsa kilit HER DAKIKA saptigini soyler. Ilk kosumda tam bunu yasadi
/// (etkinlik ve Turlarim ekranlari). Cozum: KONUM ve OLCU aynen korunur —
/// yerlesim duyarliligi kaybolmaz — yalniz yazinin saat/tarih PARCASI
/// maskelenir.
String _zamanMaskesi(String s) => s
    .replaceAll(RegExp(r'\d{2}\.\d{2}\.\d{4}'), 'GG.AA.YYYY')
    .replaceAll(RegExp(r'\d{4}-\d{2}-\d{2}'), 'YYYY-AA-GG')
    .replaceAll(RegExp(r'\b\d{2}:\d{2}\b'), 'SS:DD');

/// Ekranin yerlesimini `test/yerlesim/<ad>.txt` ile karsilastir.
Future<void> yerlesimKilidi(
  WidgetTester tester,
  String ad,
  Widget Function(String dil) kur, {
  String dil = 'tr',
  Future<void> Function(WidgetTester)? hazirla,
  int enAz = 5,
}) async {
  _guvenliDepoTaklidi();
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(kur(dil));
  await tester.pumpAndSettle();
  if (hazirla != null) await hazirla(tester);

  final dokum = yerlesimDokumu(tester);
  // OLCUM BOS KOSMASIN: bes satirdan az dokum, ekranin cizilmedigini gosterir.
  expect(
    dokum.length,
    greaterThanOrEqualTo(enAz),
    reason:
        '$ad: yalniz ${dokum.length} yazi bulundu — ekran cizilmemis '
        'olabilir (kilit bos kosuyor)',
  );

  final dosya = File('test/yerlesim/$ad.txt');
  final govde = '${dokum.join('\n')}\n';
  if (kilitGuncelle) {
    dosya.parent.createSync(recursive: true);
    dosya.writeAsStringSync(govde);
    return;
  }
  if (!dosya.existsSync()) {
    fail(
      '$ad: kilit dosyasi yok. Uretmek icin:\n'
      'flutter test --dart-define=KILIT_GUNCELLE=true',
    );
  }
  final beklenen = dosya.readAsStringSync();
  if (beklenen == govde) return;
  // Ilk farkli satiri gostererek dus: tam dokum cok uzun olabilir.
  final b = beklenen.trimRight().split('\n'), y = dokum;
  final fark = <String>[];
  for (var i = 0; i < math.max(b.length, y.length); i++) {
    final eski = i < b.length ? b[i] : '(yok)';
    final yeni = i < y.length ? y[i] : '(yok)';
    if (eski != yeni) {
      fark.add('satir ${i + 1}:\n  kilit: $eski\n  simdi: $yeni');
    }
    if (fark.length >= 5) break;
  }
  fail(
    '$ad: yerlesim kilitten sapti (${b.length} -> ${y.length} yazi).\n'
    '${fark.join("\n")}\n'
    'Degisiklik BILINCLI ise: flutter test --dart-define=KILIT_GUNCELLE=true',
  );
}
