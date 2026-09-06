/// (P217) PUSH TIKLAMA YONLENDIRMESI — ROLE GORE.
///
/// ===========================================================================
/// OLCULEN KUSUR
/// ===========================================================================
/// Devriye alarmi (`uzak_okutma`, `gecikmis_okutma`) backend'de HEM
/// gorevliye KISI olarak HEM de yonetim rollerine (`admin`, `yonetici`,
/// `guvenlik_amiri`) gidiyor (bkz. `app/uzak_okutma.py: ALARM_ROLLERI`).
/// Mobil ise ikisini de "Turlarim"a (`/patrol`) yolluyordu — o ekran
/// yoneticinin menusunde YOK ve acilinca "yetkiniz yok" cikiyordu.
///
/// Yani bildirim DOGRU kisiye gidiyordu, YONLENDIRME yanlisti.
///
/// ===========================================================================
/// KARAR: HEDEFI ROL BELIRLER, VE HEDEF DOGRULANIR
/// ===========================================================================
/// Iki katman:
///   1. TIP + ROL -> hedef (asagidaki tablo; docs/P217-push-yonlendirme.md
///      ile ayni icerik).
///   2. ERISIM SUZGECI: hedef, o rolun ana ekran menusunden turetilen
///      erisilebilir rotalar kumesinde DEGILSE yonlendirme YAPILMAZ
///      (null). "Yetkisiz sayfaya atip hata gostermektense hic
///      gitmemek" — istegin acik sarti.
///
/// Ikinci katman bir EMNIYET KEMERIDIR: birinci katmanda unutulan ya da
/// ileride eklenen bir tip yanlis yere goturemez. Tek basina yetmez
/// (dogru hedefi bilmez), ama yanlis hedefi HER ZAMAN keser.
library;

import '../features/auth/domain/user_role.dart';
import '../features/home/domain/home_menu.dart';
import '../features/home/presentation/module_card_spec.dart';
import 'app_router.dart';

/// Rolun ana ekran menusunden turetilen ERISILEBILIR rotalar.
///
/// NEDEN MENUDEN TURETILIYOR: "hangi rol neyi gorur" karari zaten
/// `homeMenuForRole`da ve `auth.md` §4'un aynasi. Ikinci bir liste
/// yazmak, iki gercek kaynak demekti — ve ayrismalari SESSIZ olurdu
/// (menu daralir, yonlendirme eski hedefe gitmeye devam eder).
Set<String> erisilebilirRotalar(UserRole role) {
  final rotalar = <String>{};
  for (final entry in homeMenuForRole(role)) {
    // Sorgu parametresi hedefi degistirmez (`/tasks?gorunum=yonetim`
    // ile `/tasks` ayni ekran); karsilastirma YOL uzerinden yapilir.
    rotalar.add(moduleCardSpec(entry).route.split('?').first);
  }
  // ===================================================================
  // MENUDE YOKLUK "YASAK" DEMEK DEGIL — P169'da OLCULMUS bir ders
  // ===================================================================
  // `izgara_koprusu.dart` ayni tuzagi daha once yasadi: "menude yoksa
  // ele" suzgeci olculdugunde FAZLA GENIS cikti (sakin `sikayetlerim`i,
  // guvenlik `arac gecisi`ni, admin uc karti kaybediyordu). Sebep: bir
  // rota BILEREK menusuz olabilir — enum notlarinda yazili.
  //
  // Bu yuzden asagidaki kume `homeMenuForRole`un TAMAMLAYICISIDIR ve
  // her satirin gerekcesi var. Cikarimla degil, YAZILI kararla.
  rotalar.addAll(_menusuzAmaAcik(role));
  return rotalar;
}

/// Menude YER ALMAYAN ama rolun GERCEKTEN erisebildigi rotalar.
Set<String> _menusuzAmaAcik(UserRole role) => {
      // Bildirim listesi ve profil bir modul karti degil, KABUGUN
      // parcasidir: her rolde vardir.
      AppRoutes.notifications,
      AppRoutes.profile,
      // "Sikayetlerim" BILEREK menusuzdur (enum notu) ama sakinin ana
      // ekran kartlarindadir ve kendi taleplerinin tek girisidir.
      if (role == UserRole.resident) AppRoutes.sikayetlerim,
      // NFC okutma ekrani da bilerek menusuz: "Turlarim" ve
      // "Gorevlerim" icinden acilir, ama saha rolleri erisir.
      if (role == UserRole.security || role == UserRole.tesisGorevlisi)
        AppRoutes.nfc,
    };

/// Bu rol bu hedefe gidebilir mi? (sorgu parametreleri yok sayilir)
bool rotaErisilebilir(String rota, UserRole role) =>
    erisilebilirRotalar(role).contains(rota.split('?').first);

/// (P217) DEVRIYE alarmlarinin rol basina hedefi.
///
/// Saha (gorevli) icin dogru yer AKTIF TUR ekranidir: alarmi uretenin
/// duzeltebilecegi sey oradadir. Yonetim icin dogru yer DEVRIYE TAKIBI:
/// bugunun pencereleri + gecmis, salt izleme. Ikisi ayni olay hakkinda
/// ama AYRI SORULARI yanitliyor ("ne yapmaliyim" / "ne oldu").
String? _devriyeHedefi(UserRole role) => switch (role) {
      UserRole.security || UserRole.tesisGorevlisi => AppRoutes.patrol,
      // (P35) Amir sahanin basindadir ve `patrol` onun menusunde VAR;
      // ekibinin okutmasini oradan gorur.
      UserRole.guvenlikAmiri => AppRoutes.patrol,
      UserRole.yonetici => AppRoutes.patrolTracking,
      // admin yonetici duzenini gorur ama menusunde `patrolTracking`
      // YOK, `patrol` VAR — erisim suzgeci zaten bunu dogrular.
      UserRole.admin => AppRoutes.patrol,
      UserRole.resident => null,
      UserRole.denetci => null,
      // Taninmayan rol: HICBIR YERE gitme. "Bilmiyorsak deneyelim"
      // demek, tam da duzeltilen davranistir.
      UserRole.unknown => null,
    };

/// Push data'sindan ROLE UYGUN hedef rota. Bilinmeyen tip, uygun hedefi
/// olmayan rol ya da ERISILEMEYEN hedef -> `null` (yonlendirme yok).
String? pushHedefi(Map<String, String> data, UserRole? role) {
  final ham = _hamHedef(data, role);
  if (ham == null) return null;
  if (role == null) {
    // Rol bilinmiyorsa (henuz yuklenmemis oturum) yonlendirme YAPILMAZ.
    // "Bilmiyorsak deneyelim" demek, yoneticiyi yetkisiz ekrana atan
    // davranisin ta kendisiydi.
    return null;
  }
  return rotaErisilebilir(ham, role) ? ham : null;
}

String? _hamHedef(Map<String, String> data, UserRole? role) {
  final tip = data['tip'];
  switch (tip) {
    // ---------------- DEVRIYE: ROLE GORE AYRISIR --------------------- #
    case 'gecikmis_okutma':
    case 'uzak_okutma':
      return role == null ? null : _devriyeHedefi(role);
    // Kacirilan tur ROL OLARAK yonetime gider; sahaya gitmez. Yine de
    // rol basina dogru ekran ayni ayrimla belirlenir.
    case 'kacirilan_tur':
    case 'eksik_checkpoint':
      return role == null
          ? null
          : (role == UserRole.yonetici
              ? AppRoutes.patrolTracking
              : _devriyeHedefi(role));
    // ---------------- DIGER TIPLER ----------------------------------- #
    case 'talep':
    case 'talep_yanit':
    case 'talep_is_emri':
    case 'talep_cozuldu':
    case 'talep_reddedildi':
    case 'sikayet_cozuldu':
    case 'is_emri_atandi':
      // (P217 OLCUM) SAKININ GIRISI FARKLI EKRAN. Matris cikarilinca
      // gorundu: sakin `talep_cozuldu` / `talep_reddedildi` bildirimi
      // ALIYOR ama `/complaints` onun menusunde YOK — yani bildirime
      // dokundugunda HICBIR YERE gitmiyordu. Kendi taleplerinin girisi
      // "Sikayetlerim".
      final sakin = role == UserRole.resident;
      final taban = sakin ? AppRoutes.sikayetlerim : AppRoutes.complaints;
      final id = data['complaint_id'];
      return id == null || id.isEmpty ? taban : '$taban?complaint_id=$id';
    case 'ziyaretci':
      final id = data['visitor_id'];
      return id == null || id.isEmpty
          ? AppRoutes.visitors
          : '${AppRoutes.visitors}?visitor_id=$id';
    case 'kargo':
      final id = data['kargo_id'];
      return id == null || id.isEmpty
          ? AppRoutes.kargo
          : '${AppRoutes.kargo}?kargo_id=$id';
    case 'erisim_talebi':
    case 'erisim_sonuc':
      return AppRoutes.unitAccess;
    case 'rezervasyon':
    case 'rezervasyon_karar':
      final id = data['rezervasyon_id'];
      return id == null || id.isEmpty
          ? AppRoutes.rezervasyon
          : '${AppRoutes.rezervasyon}?rezervasyon_id=$id';
    case 'etkinlik':
      final id = data['etkinlik_id'];
      return id == null || id.isEmpty
          ? AppRoutes.etkinlik
          : '${AppRoutes.etkinlik}?etkinlik_id=$id';
    case 'duyuru':
      return AppRoutes.announcements;
    // Vardiya: hatirlatma/baslamadi GOREVLIYE, ozet YONETIME gider —
    // ucu de ayni ekrani acar (`vardiyalar`) ve o ekran her iki tarafta
    // da menude VAR.
    case 'vardiya_ozeti':
    case 'vardiya_hatirlatma':
    case 'vardiya_baslamadi':
      return AppRoutes.vardiyalar;
    // Gorev atama SAHAYA gider -> "Gorevlerim". Yoneticiye ayni tipten
    // push GITMIYOR; gitseydi erisim suzgeci `/tasks`i onun menusunde
    // de bulur ve dogru calisirdi.
    case 'gorev_atandi':
      return AppRoutes.tasks;
    case 'aidat_borc':
    case 'aidat_odendi':
    case 'aidat_hatirlatma':
      return AppRoutes.myDues;
    // (P208/P212) GURULTU — dort ayri tip, UC AYRI muhatap:
    //   sakine uyari      -> kendi talepleri
    //   guvenlige eskalasyon / yonetime bilgi -> talep kaydi
    // Hepsi `complaints` ailesinde; ekran her rolde menude var.
    case 'gurultu_uyari_sakin':
      return AppRoutes.sikayetlerim;
    case 'gurultu_uyarisi':
    case 'gurultu_esik_yonetim':
    case 'gurultu_eskalasyon_guvenlik':
    case 'gurultu_eskalasyon_yonetim':
      // Gurultu akisi da sikayet kaydidir; sakin tarafi ayni ayrimi
      // izler (yukaridaki gerekce).
      final taban = role == UserRole.resident
          ? AppRoutes.sikayetlerim
          : AppRoutes.complaints;
      final id = data['complaint_id'];
      return id == null || id.isEmpty ? taban : '$taban?complaint_id=$id';
    // (P206) FINANS bildirimleri sakine gider: tahsilat/iade/iptal...
    // hepsinin muhatabi kendi aidat kaydidir.
    case 'tahsilat':
    case 'tahsilat_toplu':
    case 'iade':
    case 'iptal':
    case 'virman':
    case 'acilis':
      return AppRoutes.myDues;
    // `dogrulama` (token saglik yoklamasi) ve `test` (push teshisi)
    // KULLANICIYA GORUNMEZ bir yere gitmeli: yonlendirme YOK.
    case 'dogrulama':
    case 'test':
      return null;
    default:
      return null;
  }
}
