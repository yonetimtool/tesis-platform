/// ACILIS ON-OKUMASI — ilk kare ZATEN dogru dil/tema ile boyansin diye.
///
/// SORUN (duzeltildi): dil ve tema tercihleri [FlutterSecureStorage]'dan
/// ASENKRON okunuyordu; denetleyiciler once varsayilani ("secim yok" → cihaz
/// dili/sistem temasi) dondurup deger gelince `state`'i degistiriyordu. Sonuc:
/// uygulama ilk kareyi YANLIS dille boyayip hemen ardindan yeniden ciziyordu —
/// kullanicinin gordugu METIN TITREMESI buydu (ozellikle cihaz dili != secilen
/// dil oldugunda: once Ingilizce, sonra Turkce).
///
/// COZUM: `runApp`'ten ONCE oku, sonucu [acilisTercihleriProvider] ile
/// denetleyicilere TOHUMLA. Bekleme suresi (tek depo okumasi) platformun
/// KENDI acilis ekraninda gecer — yeni bir splash EKLENMEZ.
///
/// Testler bu provider'i override ETMEZ → `null` kalir ve denetleyiciler eski
/// async yola duser (widget testleri depo tohumlamasi kurmak zorunda degil).
library;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/locale_controller.dart';

/// Acilistan once okunmus tercihler. Alanlarin `null` olmasi "KULLANICI SECIMI
/// YOK" demektir (dil → cihaz dili, tema → sistem) — okumanin yapilmadigi
/// durumdan farklidir; onu [acilisTercihleriProvider]'in kendisi `null`
/// olarak ifade eder.
@immutable
class AcilisTercihleri {
  const AcilisTercihleri({this.dil, this.temaModu});

  final AppDil? dil;
  final ThemeMode? temaModu;
}

/// `null` → ON-OKUMA YAPILMADI (testler): denetleyiciler async yolu kullanir.
/// Dolu → `runApp` oncesi okundu; denetleyiciler ILK degerlerini bundan alir.
final acilisTercihleriProvider = Provider<AcilisTercihleri?>((ref) => null);

const _dilKey = 'ui.locale';
const _temaKey = 'ui.theme_mode';

/// Depodan dil + tema tercihini okur. Depo hata verirse (ilk kurulum, Keystore
/// sorunu) varsayilanlarla doner — ACILIS ASLA BLOKE OLMAZ.
Future<AcilisTercihleri> acilisTercihleriniOku([
  FlutterSecureStorage depo = const FlutterSecureStorage(),
]) async {
  try {
    final dil = AppDil.fromKod(await depo.read(key: _dilKey));
    final tema = temaModuCoz(await depo.read(key: _temaKey));
    return AcilisTercihleri(dil: dil, temaModu: tema);
  } catch (_) {
    return const AcilisTercihleri();
  }
}

/// Depodaki metni [ThemeMode]'a cevirir (bilinmeyen → null = secim yok).
ThemeMode? temaModuCoz(String? raw) => switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };
