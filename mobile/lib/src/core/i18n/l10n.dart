/// i18n ergonomisi + BICIMLENDIRME KURALLARI (tek dogruluk kaynagi).
///
/// Kullanim: `context.l10n.ortakKaydet`.
///
/// PARA BIRIMI KURALI (bilincli): tutarlar UI dili NE OLURSA OLSUN Turk
/// Lirasi (₺) ve TURKCE sayi gruplamasiyla gosterilir ("₺1.250,00") — para
/// site-yereldir (aidat TL toplanir, dekontta TL yazar). Yalnizca TARIH/SAAT
/// ve ay/gun adlari aktif dile gore bicimlenir.
///
/// RTL (Arapca): sayi/plaka/telefon/tutar gibi LTR diziler RTL metin icinde
/// ters gorunebilir; bu yuzden [ltrIzole] ile Unicode izolasyonu (U+2068 FSI
/// … U+2069 PDI) uygulanir.
library;

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../l10n/gen/app_localizations.dart';
import 'locale_controller.dart';

export '../../../l10n/gen/app_localizations.dart' show AppLocalizations;

extension L10nContext on BuildContext {
  /// Aktif dilin metinleri (ARB'den uretilir).
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Aktif dilin BCP-47 etiketi (`DateFormat` icin).
  String get dilKodu => Localizations.localeOf(this).languageCode;
}

/// Metni LTR olarak IZOLE eder: RTL (Arapca) govde icinde plaka/telefon/
/// tutar/sayi dizilerinin sirasi bozulmaz. Latin dillerde etkisi yoktur
/// (goruntude fark olusturmaz, yalnizca iki gorunmez isaret ekler).
String ltrIzole(String metin) => '\u2068$metin\u2069';

/// Turkce sayi gruplamasiyla kurus → "1.250,00" (para birimi simgesi HARIC).
/// Bkz. dosya basligindaki para kurali.
String tlTutar(int kurus) =>
    NumberFormat('#,##0.00', 'tr_TR').format(kurus / 100);

/// "₺1.250,00" — para birimi simgesiyle.
///
/// [dil] RTL (Arapca) ise LTR IZOLASYONU uygulanir (tutar ters gorunmesin);
/// LTR dillerde metin OLDUGU GIBI doner — gorunmez isaretler eklenmez, boylece
/// metin karsilastirmalari (test/analitik) beklenmedik karakter gormez.
String tlIsaretli(int kurus, [String dil = 'tr']) {
  final metin = '₺${tlTutar(kurus)}';
  return rtlMi(dil) ? ltrIzole(metin) : metin;
}

/// "1.250,00 TL" — TL SON EKLI varyant (butce/finans ekranlari bu bicimi
/// kullanir; [tlIsaretli] ise ₺ ON EKLI olani).
///
/// Gruplama TEK KAYNAKTAN gelir ([tlTutar]); `budget_models.formatKurusAsTl`
/// bunun i18n-oncesi ikizidir ve henuz yerellestirilmemis ekranlarda
/// (orn. seffaflik panosu) durur — cikti ayni olmak zorundadir, tur 6 testi
/// bunu dogrular.
///
/// [onEk] hareket satirlarindaki isaret icindir ('+' / '-'); izolasyon
/// isaretle BIRLIKTE uygulanir ki Arapca'da isaret tutardan kopmasin.
String tlSonEkli(int kurus, String dil, {String onEk = ''}) {
  final metin = '$onEk${tlTutar(kurus)} TL';
  return rtlMi(dil) ? ltrIzole(metin) : metin;
}

/// Yalniz TARIH: aktif dile gore ("25.07.2026" / "07/25/2026" / "٢٥‏/٧‏/٢٠٢٦").
String tarihBicimi(DateTime t, String dil) =>
    DateFormat.yMd(dil).format(t.toLocal());

/// Tarih + saat, referans gorsellerdeki AYIRICI ile ("25.07.2026 · 09:47").
/// [ayirici] cagrilan yerin gorsel dilini korur (duyuru karti "–" kullanir).
String tarihSaatBicimi(DateTime t, String dil, {String ayirici = '·'}) =>
    '${DateFormat.yMd(dil).format(t.toLocal())} $ayirici '
    '${DateFormat.Hm(dil).format(t.toLocal())}';

/// Yalniz saat ("09:47").
String saatBicimi(DateTime t, String dil) =>
    DateFormat.Hm(dil).format(t.toLocal());

/// GUN.AY — akis satirlarinin kisa tarihi.
///
/// TR'de "01.07" (sifir dolgulu, nokta ayirici) GORSEL OLARAK KORUNUR —
/// intl'in tr `Md` deseni "1/7" verir ve Turkce yazim aliskanligina uymaz.
/// Diger dillerde locale deseni kullanilir ("7/25", "25.7", "٢٥‏/٧").
String gunAyBicimi(DateTime t, String dil) => dil == 'tr'
    ? DateFormat('dd.MM').format(t.toLocal())
    : DateFormat.Md(dil).format(t.toLocal());

/// Uzun tarih (ay adi dile gore): "25 Temmuz 2026" / "July 25, 2026".
String uzunTarihBicimi(DateTime t, String dil) =>
    DateFormat.yMMMMd(dil).format(t.toLocal());

/// Gun adi ("Cumartesi" / "Saturday" / "السبت").
String gunAdi(DateTime t, String dil) => DateFormat.EEEE(dil).format(t.toLocal());

/// Ekran basliklarinin BUYUK HARF kurali — dile duyarli.
///
/// * tr: 'i' → 'İ', 'ı' → 'I' (Dart'in varsayilani yanlis cevirir),
/// * ar: Arapcada BUYUK HARF YOKTUR → metin aynen doner,
/// * digerleri: standart `toUpperCase()`.
String baslikBuyuk(String s, String dil) => switch (dil) {
      'tr' => s.replaceAll('ı', 'I').replaceAll('i', 'İ').toUpperCase(),
      'ar' => s,
      _ => s.toUpperCase(),
    };

/// Aktif dilin RTL olup olmadigi (yalniz Arapca) — widget testleri ve
/// yon-duyarli ozel cizimler icin.
bool rtlMi(String dil) => AppDil.fromKod(dil)?.rtl ?? false;
