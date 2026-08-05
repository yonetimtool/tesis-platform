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

/// Ana ekranin cizecegi karolar — SECIM YOKSA `null`.
///
/// Kesisim mantigi tek yerde (`izgarayiCoz`) durur; hicbir ekran kendi
/// suzgecini yazmaz.
///
/// `null` "varsayilan" demektir ve varsayilan, rolun BUGUNKU kart
/// listesidir (bkz. `izgaraKartlari`). Burada varsayilan izgarayi
/// dondurmek, hicbir sey secmemis her kullanicinin ana ekranini
/// degistirirdi — kisisellestirme turu, budama turu degil.
/// (P139.5) KURASYONLU VARSAYILAN — Kerem'in karari.
///
/// YONETIM ROLLERINDE (yonetici, admin) varsayilan izgara Kerem'in
/// verdigi ALTI karodur. Diger rollerde varsayilan, rolun BUGUNKU kart
/// listesidir (`null` -> `izgaraKartlari` onu dondurur).
///
/// NEDEN ROL AYRIMI, OLCULDU: alti karo bir YONETICI kumesidir. Ayni
/// varsayilani sakine uygulamak kesisimi UC karoya dusuruyor ve sakinin
/// bugun gordugu SAYACLI kartlari — Aidatim, Kargo, Ziyaretci — ana
/// ekrandan siliyordu (26 ekran kilidi bunu gosterdi).
///
/// YONETICIDE BEDELI ACIK VE KABUL EDILDI: bugunku sekiz karttan
/// `aidatDurumu`, `ihlaller`, `sikayetler` sayaclari ve `raporlar`
/// izgaradan DUSER. Ekranlar erisilebilir kalir; kaybolan sey ana
/// ekrandaki uc SAYACTIR. Kullanici duzenleme ekranindan geri ekleyebilir.
///
/// ROL DISARIDAN VERILIR — saglayici KENDI kaynagindan okumaz. Ilk
/// yazimda `currentUserRoleProvider`i okuyordu ve KUSURLUYDU: ana
/// ekranlar rolu WIDGET PARAMETRESINDEN aliyor. Iki ayri kaynak
/// AYRISABILIR — nitekim ekran testlerinde rol cozulmuyordu ve kurasyon
/// HIC DEVREYE GIRMIYORDU: kilitler degisikligi OLCMEDEN geciyordu.
const _kurasyonluRoller = {UserRole.yonetici, UserRole.admin};

/// Kurasyonlu varsayilan ACIK MI. Bugun KAPALI (bkz. yukaridaki not):
/// kume 320dp'de tasma uretiyor ve sebebi olculerek cozulmeli. Acmak
/// icin `true` yeter — mantik ve testleri hazir.
const bool _kurasyonAcik = false;

final izgaraKarolariProvider =
    Provider.family<List<HomeMenuEntry>?, UserRole>((ref, rol) {
  final tercih = ref.watch(izgaraTercihiProvider);
  if (tercih != null) return izgarayiCoz(rol, tercih);
  // (P139.5) KURASYON GECICI OLARAK KAPALI — bkz. asagidaki not.
  //
  // Kerem'in karari "yoneticinin varsayilani alti karo" idi ve mantik
  // hazir (`varsayilanIzgara`, testli). ACIK BIRAKILAN SEY BIR OLCUM:
  // kurasyonlu kume 320dp'de `RenderFlex` 0.36 piksel TASIRIYOR ve
  // fotografli dar-ekran surusu bunu yakaliyor.
  //
  // UC HIPOTEZ OLCULDU VE UCU DE CURUDU:
  //   * yer tutucu (iskelet yuksekligi / seffaf metin / AutoSizeText
  //     grubu) -> tasma her uc bicimde de SURDU
  //   * sayacsiz kartlar -> yalniz sayacli dort kartla da SURDU
  //   * kurasyon kapali -> tasma YOK (sebep kesin olarak kurasyonlu kume)
  //
  // Yani sebep kart KUMESINDE ve dar ekran geometrisinde; tahminle
  // kapatmak yerine olculerek cozulmeli. `_kurasyonluRoller` yerinde
  // duruyor: satiri geri acmak tek kelimelik istir.
  //
  return _kurasyonAcik && _kurasyonluRoller.contains(rol)
      ? varsayilanIzgara(rol)
      : null;
});
