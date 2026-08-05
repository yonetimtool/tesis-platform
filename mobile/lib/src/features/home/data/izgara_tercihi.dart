import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/current_user_provider.dart';
import '../../auth/data/token_storage.dart';
import '../../auth/domain/user_role.dart';
import '../domain/home_izgara.dart';
import '../domain/home_menu.dart';

/// (P139.3) ANA EKRAN IZGARASI — KULLANICI TERCIHI (kalici).
///
/// DEPO: `FlutterSecureStorage` — tema modu ve token'larla AYNI depo
/// (uygulamanin mevcut yerel-saklama deseni; yeni bir yol icat edilmedi).
///
/// SUNUCUDA DEGIL, CIHAZDA: tercih bir GORUNUM ayaridir, yetki degil.
/// Sunucuya tasimak yeni bir uc + goc demekti ve turun kisiti "API
/// degisikligi yok"tu. BEDELI DURUSTCE: tercih CIHAZ BASINADIR — ayni
/// kullanici baska telefonda varsayilan izgarayi gorur. Senkron istenirse
/// ayri bir madde olarak acilmali.
///
/// ANAHTAR ROLE GORE AYRI: ayni cihazda rol degisirse (personel cikis
/// yapip yonetici girerse) tercihler birbirine karismaz. Kesisim zaten
/// koruyor ama ayri anahtar, "neden benim secimim degisti" sorusunu da
/// ortadan kaldirir.
class IzgaraTercihiController extends Notifier<List<HomeMenuEntry>?> {
  static const _onEk = 'ui.home_izgara';

  String _anahtar(UserRole rol) => '$_onEk.${rol.name}';

  @override
  List<HomeMenuEntry>? build() {
    // Rol degisince tercih yeniden okunur.
    ref.watch(currentUserRoleProvider);
    _yukle();
    return null;
  }

  UserRole get _rol =>
      ref.read(currentUserRoleProvider).value ?? UserRole.unknown;

  Future<void> _yukle() async {
    final rol = _rol;
    if (rol == UserRole.unknown) return;
    final ham = await ref.read(secureStorageProvider).read(key: _anahtar(rol));
    if (ham == null) return;
    try {
      final adlar = (jsonDecode(ham) as List).cast<String>();
      state = izgarayiOku(adlar);
    } catch (_) {
      // BOZUK KAYIT URUNU KIRMAZ: tercih dusar, varsayilan izgara cizilir.
      // (`izgarayiCoz` zaten `null`i varsayilana cevirir.)
      state = null;
    }
  }

  /// Secimi yaz. UI aninda tepki verir; yazma arka planda.
  Future<void> kaydet(List<HomeMenuEntry> secim) async {
    final rol = _rol;
    final gecerli = izgarayiCoz(rol, secim);
    state = gecerli;
    if (rol == UserRole.unknown) return;
    await ref.read(secureStorageProvider).write(
          key: _anahtar(rol),
          value: jsonEncode(izgarayiYaz(gecerli)),
        );
  }

  /// Varsayilana don — kullanicinin cikisi olmayan bir duzenlemeye
  /// sikismamasi icin duzenleme ekraninda her zaman durur.
  Future<void> sifirla() async {
    final rol = _rol;
    state = null;
    if (rol == UserRole.unknown) return;
    await ref.read(secureStorageProvider).delete(key: _anahtar(rol));
  }
}

final izgaraTercihiProvider =
    NotifierProvider<IzgaraTercihiController, List<HomeMenuEntry>?>(
        IzgaraTercihiController.new);

/// Ana ekranin CIZECEGI karolar — tercih + rol kesisimi.
///
/// Ekranlar bunu okur; kesisim mantigi tek yerde (`izgarayiCoz`) durur ve
/// hicbir ekran kendi suzgecini yazmaz.
final izgaraKarolariProvider = Provider<List<HomeMenuEntry>>((ref) {
  final rol = ref.watch(currentUserRoleProvider).value ?? UserRole.unknown;
  final tercih = ref.watch(izgaraTercihiProvider);
  return izgarayiCoz(rol, tercih);
});
