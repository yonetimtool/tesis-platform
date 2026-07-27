/// UYGULAMA DILI — 7 dil (tr varsayilan + en/ar/ru/de/fr/es).
///
/// COZUMLEME SIRASI (locale resolution):
///   1. KULLANICININ SECIMI (kalici; `ui.locale`),
///   2. CIHAZ dili — desteklenenler arasindaysa (yalniz dil kodu eslenir:
///      `en_US` → `en`, `ar_SA` → `ar`),
///   3. TURKCE (varsayilan + ceviri bosluklarinin geri dusus dili).
///
/// Kalicilik tema ile AYNI depoyu kullanir ([FlutterSecureStorage]) — ayrica
/// bir tercih deposu getirilmedi.
///
/// ILK KARE: secim `runApp`'ten ONCE okunur ve [acilisTercihleriProvider] ile
/// tohumlanir; boylece uygulama ilk kareyi ZATEN dogru dille boyar (eskiden
/// once varsayilan dille cizip sonra kendini yeniliyordu → METIN TITREMESI).
/// Tohum yoksa (widget testleri) eski asenkron yol calisir.
library;

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/token_storage.dart';
import '../startup/acilis_tercihleri.dart';

/// Desteklenen diller + KENDI DILINDEKI adi (dil secicide boyle gorunur).
enum AppDil {
  tr('tr', 'Türkçe'),
  en('en', 'English'),
  ar('ar', 'العربية'),
  ru('ru', 'Русский'),
  de('de', 'Deutsch'),
  fr('fr', 'Français'),
  es('es', 'Español');

  const AppDil(this.kod, this.adKendiDilinde);

  /// ISO 639-1 dil kodu (ARB dosya adiyla ayni).
  final String kod;

  /// Secicide gosterilen ad — HER ZAMAN kendi dilinde ("العربية", "Русский").
  final String adKendiDilinde;

  Locale get locale => Locale(kod);

  /// Sagdan sola yazilan dil mi (yalniz Arapca).
  bool get rtl => this == AppDil.ar;

  static AppDil? fromKod(String? kod) {
    if (kod == null) return null;
    for (final d in AppDil.values) {
      if (d.kod == kod) return d;
    }
    return null;
  }
}

/// `MaterialApp.supportedLocales` icin liste (sira = secicideki sira).
final supportedLocales = [for (final d in AppDil.values) d.locale];

/// Kullanicinin SECIMI: null → "secim yok" (cihaz dili, yoksa tr).
class LocaleController extends Notifier<AppDil?> {
  static const _key = 'ui.locale';

  @override
  AppDil? build() {
    // Acilis on-okumasi yapildiysa ILK deger dogrudan ondan gelir → ilk kare
    // dogru dilde boyanir, sonradan yenilenme (titreme) OLMAZ.
    final onOkuma = ref.read(acilisTercihleriProvider);
    if (onOkuma != null) return onOkuma.dil;
    _yukle();
    return null;
  }

  Future<void> _yukle() async {
    final raw = await ref.read(secureStorageProvider).read(key: _key);
    final dil = AppDil.fromKod(raw);
    if (dil != null) state = dil;
  }

  /// Dili degistir + kalici yaz. UI ANINDA tepki verir (MaterialApp.locale);
  /// yazma arka planda tamamlanir.
  Future<void> sec(AppDil dil) async {
    state = dil;
    await ref.read(secureStorageProvider).write(key: _key, value: dil.kod);
  }

  /// Secimi kaldir → cihaz dili (desteklenmiyorsa tr).
  Future<void> cihazDiliniKullan() async {
    state = null;
    await ref.read(secureStorageProvider).delete(key: _key);
  }
}

final localeControllerProvider =
    NotifierProvider<LocaleController, AppDil?>(LocaleController.new);

/// `MaterialApp.locale` degeri: secim varsa onun locale'i, yoksa null
/// (Flutter cihaz dilini [localeCozumle] ile cozer).
final aktifLocaleProvider = Provider<Locale?>((ref) {
  return ref.watch(localeControllerProvider)?.locale;
});

/// UYGULAMANIN O AN CIZDIGI dilin kodu (secim yoksa cihazdan cozulen).
///
/// `aktifLocaleProvider` secim yokken **null** doner (MaterialApp'in cihaz
/// dilini cozmesi icin); ag katmani ise somut bir kod ister — `Accept-Language`
/// basligi bu saglayiciyi kullanir (bkz. `core/network/dil_interceptor.dart`).
final aktifDilKoduProvider = Provider<String>((ref) {
  final secim = ref.watch(localeControllerProvider);
  if (secim != null) return secim.kod;
  return localeCozumle(
    PlatformDispatcher.instance.locale,
    supportedLocales,
  ).languageCode;
});

/// `MaterialApp.localeResolutionCallback` — cihaz dili desteklenenler
/// arasindaysa onu, degilse TURKCE'yi secer (ulke kodu YOK SAYILIR).
Locale localeCozumle(Locale? cihaz, Iterable<Locale> desteklenen) {
  if (cihaz != null) {
    for (final l in desteklenen) {
      if (l.languageCode == cihaz.languageCode) return l;
    }
  }
  return AppDil.tr.locale;
}
