// TUR 23 — EKRAN SURUSU: mevcut test kosumlarindaki ekranlari 7 dilde cizip
// GORUNEN metni tara. ARB denetimi sozlugu olcer; bu, EKRANI olcer:
// sozlukte olmayan (kaynakta unutulmus) sabitleri ancak bu yakalar.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
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
