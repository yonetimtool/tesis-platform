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

import '../../features/auth/data/token_storage.dart' show secureStorageProvider;
import '../i18n/locale_controller.dart';

/// Acilistan once okunmus tercihler. Alanlarin `null` olmasi "KULLANICI SECIMI
/// YOK" demektir (dil → cihaz dili, tema → sistem) — okumanin yapilmadigi
/// durumdan farklidir; onu [acilisTercihleriProvider]'in kendisi `null`
/// olarak ifade eder.
@immutable
class AcilisTercihleri {
  const AcilisTercihleri({
    this.dil,
    this.temaModu,
    this.rolSecimiGosterildi = true,
  });

  final AppDil? dil;
  final ThemeMode? temaModu;

  /// (P154 / Asama 2) Rol listesi bu cihazda DAHA ONCE gosterildi mi?
  ///
  /// Brief: "Kullanici uygulamayi indirip ILK ACTIGINDA ekranda 'Size uygun
  /// olanı seçiniz' yazar ve rol listesi cikar." Yani rol listesi ilk
  /// acilisin ekranidir, her acilisin degil — ikincisi, hesabi olan
  /// kullaniciya her seferinde kaydolmasini teklif etmek olurdu.
  ///
  /// `false` = henuz gosterilmedi (ilk acilis) → acilis rol listesine duser.
  ///
  /// VARSAYILAN `true` VE BU BILINCLI: "ilk acilis" iddiasi ancak depo
  /// GERCEKTEN OKUNUP anahtar bulunamayinca yapilabilir — onu yalniz
  /// [acilisTercihleriniOku] yapar. Elle kurulan her `AcilisTercihleri`
  /// (depo hatasindaki `const AcilisTercihleri()` fallback'i ve dil/tema
  /// tohumlayan testler dahil) "gosterildi" sayilir.
  ///
  /// Varsayilan `false` OLSAYDI: okunamayan bir depo, hesabi olan
  /// kullaniciyi her acilista kayit ekranina dusururdu. Ters yondeki
  /// zarar kucuktur — giris ekraninda zaten `login-kayit-baglantisi` var.
  final bool rolSecimiGosterildi;
}

/// `null` → ON-OKUMA YAPILMADI (testler): denetleyiciler async yolu kullanir.
/// Dolu → `runApp` oncesi okundu; denetleyiciler ILK degerlerini bundan alir.
final acilisTercihleriProvider = Provider<AcilisTercihleri?>((ref) => null);

const _dilKey = 'ui.locale';
const _temaKey = 'ui.theme_mode';
/// Yazan taraf [RolSecimiBekliyor.gosterildi], okuyan taraf
/// [acilisTercihleriniOku] — ayni anahtar, tek sabit.
const rolSecimiKey = 'ui.rol_secimi_gosterildi';

/// (P154) Rol listesi HENUZ gosterilmedi mi? `true` → acilis rol listesine
/// duser.
///
/// ON-OKUMA YOKSA `false`: `acilisTercihleriProvider` null iken (widget
/// testleri) yonlendirme HIC devreye girmez. Testler beklemedikleri bir
/// ekrana dusmez, cunku bu yonlendirme ACILISA aittir, ekranlara degil.
class RolSecimiBekliyor extends Notifier<bool> {
  @override
  bool build() {
    final tercih = ref.watch(acilisTercihleriProvider);
    return tercih != null && !tercih.rolSecimiGosterildi;
  }

  /// Rol listesi gosterildi: bu acilista bir daha yonlendirme yapilmaz ve
  /// karar depoya yazilir.
  ///
  /// YAZMA HATASI YUTULUR: isaretleyemezsek kullanici bir sonraki acilista
  /// rol listesini bir kez daha gorur — acilisi bir depo hatasi yuzunden
  /// kirmaktan iyidir.
  Future<void> gosterildi() async {
    if (!state) return;
    state = false;
    try {
      await ref.read(secureStorageProvider).write(key: rolSecimiKey, value: '1');
    } catch (_) {}
  }
}

final rolSecimiBekliyorProvider =
    NotifierProvider<RolSecimiBekliyor, bool>(RolSecimiBekliyor.new);

/// Depodan dil + tema tercihini okur. Depo hata verirse (ilk kurulum, Keystore
/// sorunu) varsayilanlarla doner — ACILIS ASLA BLOKE OLMAZ.
Future<AcilisTercihleri> acilisTercihleriniOku([
  FlutterSecureStorage depo = const FlutterSecureStorage(),
]) async {
  try {
    final dil = AppDil.fromKod(await depo.read(key: _dilKey));
    final tema = temaModuCoz(await depo.read(key: _temaKey));
    final rol = await depo.read(key: rolSecimiKey);
    return AcilisTercihleri(
      dil: dil,
      temaModu: tema,
      rolSecimiGosterildi: rol == '1',
    );
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
