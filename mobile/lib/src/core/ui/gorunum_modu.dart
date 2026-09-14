import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/token_storage.dart';

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
class GorunumModuController extends Notifier<GorunumModu> {
  static const anahtar = 'ui.gorunum_modu';

  @override
  GorunumModu build() {
    _yukle();
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
    await ref
        .read(secureStorageProvider)
        .write(key: anahtar, value: mod.kod);
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

  @override
  double scale(double fontSize) => _taban.scale(fontSize) * _carpan;

  // `textScaleFactor` KULLANIMDAN KALDIRILDI ama `TextScaler` onu hala
  // SOYUT uye olarak istiyor; tanimlamamak derleme hatasi, duz tanimlamak
  // analiz uyarisi. Ikisinin arasindan cikis: uyariyi BU SATIRDA,
  // gerekcesiyle bastirmak.
  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => _taban.textScaleFactor * _carpan;
}
