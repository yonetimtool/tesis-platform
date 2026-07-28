// TUR 23 — EKRAN SURUSU: mevcut test kosumlarindaki ekranlari 7 dilde cizip
// GORUNEN metni tara. ARB denetimi sozlugu olcer; bu, EKRANI olcer:
// sozlukte olmayan (kaynakta unutulmus) sabitleri ancak bu yakalar.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/theme/app_theme.dart';

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
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(kur(dil));
    await tester.pumpAndSettle();
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
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(olcek)),
        child: kur(dil),
      ),
    );
    await tester.pumpAndSettle();
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
}) async {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final tutamac = tester.ensureSemantics();
  for (final dil in surusDilleri) {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(kur(dil));
    await tester.pumpAndSettle();

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
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(kur(dil));
    await tester.pumpAndSettle();
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
}) async {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  for (final dil in ['tr', 'ar']) {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(kur(dil));
    await tester.pumpAndSettle();

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
