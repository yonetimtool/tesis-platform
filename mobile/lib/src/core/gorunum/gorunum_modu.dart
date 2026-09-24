import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/jwt_claims.dart';
import '../../features/auth/data/token_storage.dart';
import '../startup/acilis_tercihleri.dart';
import 'gorunum_esitleme.dart';

/// (P230 §2) GORUNUM MODU — yasli kullanicilar icin TEK ayar.
///
/// =========================================================================
/// NEDEN TEK AYAR, BES AYAR DEGIL
/// =========================================================================
/// Istegin kendi cumlesi: "yasli kullanici bes ayri ayarla ugrasmasin".
/// Yazi boyutu, ikon boyutu, sutun sayisi ve karo sayisi AYRI AYRI
/// ayarlanabilir seyler; ama onlari ayri ayri sunmak, en cok yardima
/// ihtiyaci olan kullaniciya EN COK karar yukleyen tasarim olurdu.
///
/// =========================================================================
/// "AZ OGE" > "KUCUK OGE"
/// =========================================================================
/// Buyuk modda izgara 8 karodan 4'e duser ve 2 sutun olur. Sekiz karoyu
/// buyutup ekrana sigdirmaya calismak, her karoyu yeniden kuculturdu —
/// yani ayar HICBIR SEY yapmamis olurdu. Hangi dortlu kalir: kullanicinin
/// KENDI izgara sirasinin ilk dordu (`izgara_duzenle` ekraninda
/// duzenlediği sira). Yeni bir "buyuk mod icin ayri liste" kavrami
/// eklemek, kullaniciya IKINCI bir duzenleme ekrani ogretmek olurdu.
///
/// =========================================================================
/// CIHAZ-YEREL, HESAP-DUZEYINDE DEGIL
/// =========================================================================
/// Tema tercihiyle AYNI depo ve ayni desen (`ui.theme_mode` →
/// `ui.gorunum_modu`). Hesap duzeyine tasimak bir goc + uc + web paritesi
/// demekti; bedeli, kazandan (ayni kisinin ikinci cihazinda ayari tekrar
/// acmasi) buyuk. TAKAS ACIKCA KAYITLI: kullanici tablet ve telefonda
/// ayri ayri acmak zorunda.
///
/// =========================================================================
/// SISTEM OLCEGININ USTUNE CARPAR, ONU EZMEZ
/// =========================================================================
/// Uygulama sistem yazi olcegini ZATEN izliyor (`main.dart`te bir
/// `textScaler` gecersiz kilmasi YOK — olculdu). Buyuk mod onu
/// DEGISTIRMEZ, uzerine carpar: sistemde zaten 1.3 kullanan biri buyuk
/// modu acinca 1.3'e DUSMEZ.
enum GorunumModu {
  standart('standart'),
  buyuk('buyuk');

  const GorunumModu(this.kod);

  final String kod;

  /// Buyuk modda metin olcegi CARPANI.
  ///
  /// 1.3 secildi: 1.5 ve ustu, iki satirlik kart basliklarini 8 puntoya
  /// kadar kuculturdu (P229 §1'de olculen taban) — yani "buyut" ayari
  /// basliklari KUCULTURDU.
  double get metinCarpani => this == GorunumModu.buyuk ? 1.3 : 1.0;

  /// Buyuk modda ana ekran izgarasinda GOSTERILECEK karo sayisi.
  int? get izgaraKaroSiniri => this == GorunumModu.buyuk ? 4 : null;

  /// Buyuk modda izgara sutun sayisi (null → mevcut genislik kurali).
  int? get izgaraSutun => this == GorunumModu.buyuk ? 2 : null;
}

GorunumModu gorunumModuCoz(String? raw) => switch (raw) {
  'buyuk' => GorunumModu.buyuk,
  'standart' => GorunumModu.standart,
  _ => GorunumModu.standart,
};

/// Tema denetleyicisiyle AYNI desen: UI aninda tepki verir, yazma arka
/// planda.
///
/// (P247 §7) HESAPLA ESITLENIR — IKI KAYNAK TEK DOGRUYA BAGLANDI.
///
/// OLCULEN KUSUR: P230 bu ayari CIHAZ-YEREL yapti; P243 §4 web'e ayni
/// ayari "mobildeki ayarin AYNI kavrami" diye HESAPTA (`app_user.ui_gorunum`,
/// goc 0147) ekledi — ama mobil o alani HIC okumuyor, HIC yazmiyordu
/// (`ui_gorunum` / `/me/gorunum` mobilde sifir eslesme). Web'de "Buyuk"
/// secen kullanici telefonda sekizli izgarayi gormeye devam ediyordu;
/// uygulamayi silip yeniden kuran (Android depoyu siler) kullanicinin
/// secimi de kayboluyordu.
///
/// KURAL (kim kazanir):
///  * Yerel depo ILK KARENIN onbellegidir (acilista `runApp` oncesi okunur,
///    8 -> 4 sicramasi olmaz).
///  * Oturum acilinca HESAP kazanir — web'de ya da baska cihazda yapilan
///    secim buraya gelir.
///  * ISTISNA: bu cihazda yapilip sunucuya HENUZ ULASMAMIS bir secim
///    (cevrimdisi, ya da P247 oncesi surumde yapilmis ve hic gonderilmemis
///    secim) EZILMEZ; once sunucuya gonderilir. Aksi halde 1.6.0'da
///    "Buyuk" secmis her kullanici ilk esitlemede sunucunun varsayilani
///    "standart" ile geri kuculurdu — duzeltme bir gerileme uretirdi.
class GorunumModuController extends Notifier<GorunumModu> {
  static const anahtar = 'ui.gorunum_modu';

  /// Yerel secimin HESAPLA durumu: `esit` = sunucuyla ayni;
  /// `bekliyor:<kullanici>` = o kullanicinin bu cihazda yaptigi secim
  /// sunucuya henuz ulasmadi. Anahtar YOK + yerel deger VAR = P247
  /// oncesi surumden kalma, hic gonderilmemis secim (bekliyor sayilir).
  static const esitlikAnahtari = 'ui.gorunum_modu_esitlik';

  Future<void>? _yukleme;

  @override
  GorunumModu build() {
    // ILK KARE: tema/dil gibi `runApp` oncesi okunmus deger (varsa).
    final onOkuma = ref.read(acilisTercihleriProvider);
    if (onOkuma != null) return onOkuma.gorunum ?? GorunumModu.standart;
    _yukleme = _yukle();
    return GorunumModu.standart;
  }

  Future<void> _yukle() async {
    try {
      final ham = await ref.read(secureStorageProvider).read(key: anahtar);
      state = gorunumModuCoz(ham);
    } catch (_) {
      // DEPO HATASI ACILISI BLOKE ETMEZ (tema okumasiyla ayni kural):
      // Keystore sorunu olan bir cihazda uygulama ACILMALI.
    }
  }

  Future<void> ayarla(GorunumModu mod) async {
    state = mod;
    final depo = ref.read(secureStorageProvider);
    final kim = await _oturumdakiKullanici();
    try {
      await depo.write(key: anahtar, value: mod.kod);
      await depo.write(key: esitlikAnahtari, value: 'bekliyor:${kim ?? ''}');
    } catch (_) {}
    if (kim != null) await _gonder(mod);
  }

  /// Oturum acildiginda (giris ya da kayitli oturumla soguk acilis)
  /// cagrilir — bkz. [gorunumEsitlemeProvider].
  Future<void> sunucuylaEsitle() async {
    await _yukleme;
    final kim = await _oturumdakiKullanici();
    if (kim == null) return;
    final depo = ref.read(secureStorageProvider);
    String? esitlik;
    String? yerel;
    try {
      esitlik = await depo.read(key: esitlikAnahtari);
      yerel = await depo.read(key: anahtar);
    } catch (_) {}
    final bekleyen = esitlik == null
        ? yerel != null // P247 oncesi secim: hic gonderilmedi
        : esitlik == 'bekliyor:$kim';
    if (bekleyen) {
      await _gonder(state);
      return;
    }
    final sunucu = await ref.read(gorunumSunucuProvider).oku();
    if (sunucu == null) return; // ag hatasi: yerel deger kalir
    state = sunucu;
    try {
      await depo.write(key: anahtar, value: sunucu.kod);
      await depo.write(key: esitlikAnahtari, value: 'esit');
    } catch (_) {}
  }

  Future<void> _gonder(GorunumModu mod) async {
    final tamam = await ref.read(gorunumSunucuProvider).yaz(mod);
    // Basarisizsa `bekliyor` KALIR: bir sonraki oturum acilisinda
    // yeniden gonderilir, sunucunun eski degeri onu EZMEZ.
    if (!tamam) return;
    try {
      await ref
          .read(secureStorageProvider)
          .write(key: esitlikAnahtari, value: 'esit');
    } catch (_) {}
  }

  Future<String?> _oturumdakiKullanici() async {
    try {
      final jeton = await ref.read(tokenStorageProvider).readAccessToken();
      if (jeton == null) return null;
      return decodeJwtClaims(jeton)?['sub'] as String? ?? '';
    } catch (_) {
      return null;
    }
  }
}

final gorunumModuProvider =
    NotifierProvider<GorunumModuController, GorunumModu>(
  GorunumModuController.new,
);

/// (P230 §2) Buyuk modda metin olcegini CARPAN sarmal.
///
/// `MediaQuery.textScalerOf(context)` cihazin GERCEK ayarini verir;
/// carpim onu korur. Sabit bir olcek yazmak, sistem ayarini EZERDI ve
/// zaten buyuk yazi kullanan kullanici icin bir GERILEME olurdu.
class GorunumOlcegi extends ConsumerWidget {
  const GorunumOlcegi({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mod = ref.watch(gorunumModuProvider);
    if (mod == GorunumModu.standart) return child;
    final mevcut = MediaQuery.textScalerOf(context);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: _Carpan(mevcut, mod.metinCarpani),
      ),
      child: child,
    );
  }
}

/// Cihaz olcegini KORUYARAK carpan `TextScaler`.
class _Carpan extends TextScaler {
  const _Carpan(this._taban, this._carpan);

  final TextScaler _taban;
  final double _carpan;

  /// (E2E 2026-09) UST SINIR: carpim toplam olcegi en fazla 2.0'ye ceker
  /// — ama cihazin KENDI olcegi zaten daha buyukse ona DOKUNMAZ (buyuk
  /// mod hicbir zaman kucultmez). Onceden iOS erisilebilirlik boyutunda
  /// (~3.1x) sonuc ~4x oluyor ve sabit yukseklikli kartlar tasiyordu.
  static const tavan = 2.0;

  @override
  double scale(double fontSize) {
    final sistem = _taban.scale(fontSize);
    final carpim = sistem * _carpan;
    final sinir = fontSize * tavan;
    if (carpim <= sinir) return carpim;
    return sistem > sinir ? sistem : sinir;
  }

  // `textScaleFactor` KULLANIMDAN KALDIRILDI ama `TextScaler` onu hala
  // SOYUT uye olarak istiyor; tanimlamamak derleme hatasi, duz tanimlamak
  // analiz uyarisi. Ikisinin arasindan cikis: uyariyi BU SATIRDA,
  // gerekcesiyle bastirmak.
  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => scale(14) / 14;
}
