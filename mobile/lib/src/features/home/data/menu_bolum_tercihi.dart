import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/current_user_provider.dart';
import '../../auth/data/token_storage.dart';
import '../../auth/domain/user_role.dart';
import '../domain/home_menu.dart';

/// (P154 / Asama 7.1) CEKMECE BOLUMLERININ ACIK/KAPALI DURUMU — KALICI.
///
/// Brief: "MENU MIMARISI (web + mobil, kategorize, katlanabilir, **tercih
/// kalici**)". Katlama tercihi kalici olmasaydi kullanici her acilista
/// ayni uc bolumu yeniden acardi ve katlama bir kolaylik degil bir engel
/// olurdu.
///
/// DEPO `izgara_tercihi.dart` ILE AYNI: `FlutterSecureStorage`, rol basina
/// ayri anahtar. Yeni bir saklama yolu icat etmek, ayni sorunun ikinci bir
/// cozumu olurdu. Bedeli de aynidir ve durustce yaziliyor: tercih CIHAZ
/// BASINADIR, baska telefonda varsayilan gorunum acilir.
///
/// NEDEN "KAPALI OLANLAR" SAKLANIYOR (acik olanlar degil): yeni bir bolum
/// eklendiginde ACIK gelmeli — kullanicinin hic gormedigi bir bolum,
/// eskiden kaydedilmis bir listede olmadigi icin kapali baslamamali.
/// Kapalilari saklamak bu varsayilani kendiliginden dogru yapar.
class MenuBolumTercihiController extends Notifier<Set<HomeMenuGrup>> {
  static const _onEk = 'ui.menu_bolum_kapali';

  String _anahtar(UserRole rol) => '$_onEk.${rol.name}';

  @override
  Set<HomeMenuGrup> build() {
    ref.watch(currentUserRoleProvider);
    _yukle();
    return const {};
  }

  UserRole get _rol =>
      ref.read(currentUserRoleProvider).value ?? UserRole.unknown;

  Future<void> _yukle() async {
    final rol = _rol;
    if (rol == UserRole.unknown) return;
    final ham = await ref.read(secureStorageProvider).read(key: _anahtar(rol));
    if (ham == null) return;
    try {
      final adlar = (jsonDecode(ham) as List).cast<String>().toSet();
      state = HomeMenuGrup.values.where((g) => adlar.contains(g.name)).toSet();
    } catch (_) {
      // BOZUK KAYIT URUNU KIRMAZ: tercih dusar, tum bolumler acik gelir.
      state = const {};
    }
  }

  /// Bir bolumu ac/kapa ve karari sakla.
  Future<void> cevir(HomeMenuGrup g) async {
    final yeni = {...state};
    if (!yeni.remove(g)) yeni.add(g);
    state = yeni;
    final rol = _rol;
    if (rol == UserRole.unknown) return;
    await ref
        .read(secureStorageProvider)
        .write(
          key: _anahtar(rol),
          value: jsonEncode(yeni.map((x) => x.name).toList()),
        );
  }
}

final menuBolumTercihiProvider =
    NotifierProvider<MenuBolumTercihiController, Set<HomeMenuGrup>>(
      MenuBolumTercihiController.new,
    );
