import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../auth/data/current_user_provider.dart';
import '../../auth/data/token_storage.dart';
import '../../auth/domain/user_role.dart';
import '../domain/home_izgara.dart';
import '../domain/home_menu.dart';

/// (P251 §11) IZGARA TERCIHI HESAPTA (`/me/ana-ekran-izgarasi`).
///
/// P139.3'te tercih CIHAZDAYDI (secure storage) ve bedeli yaziliydi: ayni
/// kullanici baska telefonda varsayilan izgarayi goruyordu. Surukle-birak
/// ile sira degistirmek "yeni sira hesaba kaydedilir" istiyor; tek kayit
/// artik sunucuda (`pano_tercihi.ana_ekran_izgarasi`) ve hem "Ana ekrani
/// duzenle" ekrani hem surukle-birak AYNI kaydi yazar — ikinci bir duzen
/// kaydi yok.
///
/// CIHAZ KAYDI YALNIZ GECIS VE CEVRIMDISI ICIN:
///   * hesapta kayit yok ama cihazda eski (P139) kayit varsa o hesaba
///     TASINIR ve cihazdan silinir — kimse duzenini kaybetmez;
///   * yazma basarisizsa (ag yok) secim cihaza yazilir, bir sonraki
///     acilista ayni gecis yolu onu hesaba tasir.
///
/// ANAHTAR ROLE GORE AYRI (cihaz tarafi): ayni cihazda rol degisirse
/// bekleyen kayitlar karismaz.
class AnaEkranIzgarasiApi {
  AnaEkranIzgarasiApi(this._dio);
  final Dio _dio;
  static const _uc = '/me/ana-ekran-izgarasi';

  /// Kayitli adlar; `null` = hesapta secim yok.
  Future<List<String>?> getir() async {
    final r = await _dio.get<Map<String, dynamic>>(_uc);
    final l = r.data?['secili'] as List?;
    return l?.cast<String>();
  }

  /// `null` = varsayilana don.
  Future<void> yaz(List<String>? adlar) async {
    await _dio.put<Map<String, dynamic>>(_uc, data: {'secili': adlar});
  }
}

final anaEkranIzgarasiApiProvider = Provider<AnaEkranIzgarasiApi>(
  (ref) => AnaEkranIzgarasiApi(ref.watch(dioProvider)),
);

/// DURUM HAM ADLAR (`List<String>`): menu girisi adi ya da `kart:<id>`
/// (menude karsiligi olmayan varsayilan kart; bkz. `kartlardanIzgara`).
/// Duzenleme ekrani yalniz girisleri gorur ([izgaraKarolariProvider]).
class IzgaraTercihiController extends Notifier<List<String>?> {
  static const _onEk = 'ui.home_izgara';

  String _anahtar(UserRole rol) => '$_onEk.${rol.name}';

  @override
  List<String>? build() {
    // Rol degisince tercih yeniden okunur.
    ref.watch(currentUserRoleProvider);
    _yukle();
    return null;
  }

  UserRole get _rol =>
      ref.read(currentUserRoleProvider).value ?? UserRole.unknown;

  Future<List<String>?> _cihazdan(UserRole rol) async {
    final ham = await ref.read(secureStorageProvider).read(key: _anahtar(rol));
    if (ham == null) return null;
    try {
      return (jsonDecode(ham) as List).cast<String>();
    } catch (_) {
      // BOZUK KAYIT URUNU KIRMAZ: tercih dusar, varsayilan izgara cizilir.
      return null;
    }
  }

  Future<void> _yukle() async {
    final rol = _rol;
    if (rol == UserRole.unknown) return;
    final api = ref.read(anaEkranIzgarasiApiProvider);
    final yerel = await _cihazdan(rol);
    List<String>? hesap;
    try {
      hesap = await api.getir();
    } catch (_) {
      // AG YOK: cihazdaki (bekleyen ya da eski) kayit cizilir.
      if (yerel != null) state = yerel;
      return;
    }
    if (yerel != null) {
      // Bekleyen/eski cihaz kaydi hesaba TASINIR (bkz. sinif notu).
      try {
        await api.yaz(yerel);
        await ref.read(secureStorageProvider).delete(key: _anahtar(rol));
      } catch (_) {}
      state = yerel;
      return;
    }
    if (hesap != null) state = hesap;
  }

  /// "Ana ekrani duzenle" ekraninin secimi (menu girisleri).
  Future<void> kaydet(List<HomeMenuEntry> secim) =>
      siraKaydet(izgarayiYaz(izgarayiCoz(_rol, secim)));

  /// (P251 §11) Surukle-birak / "Yukari-Asagi tasi" sonucu — AYNI kayit.
  /// UI aninda tepki verir; yazma arka planda.
  Future<void> siraKaydet(List<String> adlar) async {
    final rol = _rol;
    state = adlar;
    if (rol == UserRole.unknown) return;
    try {
      await ref.read(anaEkranIzgarasiApiProvider).yaz(adlar);
    } catch (_) {
      // Kaybolmasin: cihaza yazilir, sonraki acilista hesaba tasinir.
      await ref.read(secureStorageProvider).write(
            key: _anahtar(rol),
            value: jsonEncode(adlar),
          );
    }
  }

  /// Varsayilana don — kullanicinin cikisi olmayan bir duzenlemeye
  /// sikismamasi icin duzenleme ekraninda her zaman durur.
  Future<void> sifirla() async {
    final rol = _rol;
    state = null;
    if (rol == UserRole.unknown) return;
    await ref.read(secureStorageProvider).delete(key: _anahtar(rol));
    try {
      await ref.read(anaEkranIzgarasiApiProvider).yaz(null);
    } catch (_) {}
  }
}

final izgaraTercihiProvider =
    NotifierProvider<IzgaraTercihiController, List<String>?>(
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
  if (tercih != null) return izgarayiCoz(rol, izgarayiOku(tercih));
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
