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

/// "₺1.250,00" — RTL dilde de soldan-saga okunacak sekilde izole edilir.
String tlIsaretli(int kurus) => ltrIzole('₺${tlTutar(kurus)}');

/// Yalniz TARIH: aktif dile gore ("25.07.2026" / "07/25/2026" / "٢٥‏/٧‏/٢٠٢٦").
String tarihBicimi(DateTime t, String dil) =>
    DateFormat.yMd(dil).format(t.toLocal());

/// Tarih + saat ("25.07.2026 09:47").
String tarihSaatBicimi(DateTime t, String dil) =>
    '${DateFormat.yMd(dil).format(t.toLocal())} '
    '${DateFormat.Hm(dil).format(t.toLocal())}';

/// Yalniz saat ("09:47").
String saatBicimi(DateTime t, String dil) =>
    DateFormat.Hm(dil).format(t.toLocal());

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
