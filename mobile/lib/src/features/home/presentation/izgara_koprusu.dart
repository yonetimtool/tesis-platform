import '../../auth/domain/user_role.dart';
import '../data/home_repository.dart';
import '../domain/home_kart_id.dart';
import '../domain/home_menu.dart';
import '../domain/home_varyant.dart';
import '../domain/home_view_models.dart';
import 'module_card_spec.dart';

// (P139.4) KOPRU — kullanicinin sectigi menu girisleri -> hizli erisim
// kartlari.
//
// NEDEN AYRI BIR DOSYA VE NEDEN "YENIDEN KULLAN": ana ekran izgarasi
// `HizliErisimKart` gorunum modellerinden besleniyor ve o model UC seyi
// birbirine bagliyor:
//   1. `HomeKartId` — uc rol ekranindaki SAYAC `switch`'leri buna gore
//      esleşiyor (`HomeKartId.gorevler => k.sayacla(...)`),
//   2. `altMetin` — `null` ise kart ISKELET cizer ("veri henuz yok"),
//   3. baslik — kimlikten cozuluyor.
// Kullanicinin sectigi karonun ucunde de karsiligi olmayabilir. Bunu
// gormeden baglamak iki hatadan birini uretirdi: YANLIS SAYAC ilistirmek
// ya da SONSUZA KADAR iskelet cizen karolar.
//
// COZUM — YENIDEN KUR DEGIL YENIDEN KULLAN: secilen giris, rolun MEVCUT
// kart listesinde ayni ROTAYA giden bir kartla eslesiyorsa O KART oldugu
// gibi kullanilir. Boylece kimlik korunur ve ekranlarin sayac `switch`'i
// hicbir degisiklik olmadan calismaya devam eder — 17 rota bu durumda
// (olculdu). Eslesme yoksa `sayacsiz` bir kart uretilir: sayac satiri
// bos kalir, iskelet CIZILMEZ.

/// Bir menu girisi icin hizli erisim karti.
///
/// [taban] rolun mevcut kart listesidir; eslesme ROTA uzerinden yapilir
/// cunku iki sistemin ortak dili odur (kimlikleri farkli enum'lar).
HizliErisimKart izgaraKartiUret(
  HomeMenuEntry giris,
  List<HizliErisimKart> taban,
) {
  final spec = moduleCardSpec(giris);
  for (final k in taban) {
    if (k.rota != null && k.rota == spec.route) return k;
  }
  return HizliErisimKart(
    ikon: spec.icon,
    // Kimlik ALAN OLARAK zorunlu; eslesme olmadigi icin ekranlarin sayac
    // `switch`'inde KARSILIGI OLMAYAN bir deger secilir ve `_ => k` dalina
    // duser. Baslik `modulGirisi`nden cozulur, bu kimlikten DEGIL.
    id: HomeKartId.gonderimKuyrugu,
    modulGirisi: giris,
    accent: spec.accent,
    altMetin: null,
    sayacsiz: true,
    rota: spec.route,
  );
}

/// (P143) `auth.md` §4a'nin AMIRE KAPATTIGI ekranlari ana ekrandan ELE.
///
/// SORUN: `guvenlik_amiri` ana ekran duzenini `security` ile PAYLASIYOR
/// (`HomeVaryant.gorevli`), yani KART LISTESI ortak. Ama izinleri ayni
/// degil: kural amire kargo ve ziyaretciyi KVKK gerekcesiyle KAPATIYOR
/// ("dis bir sirketin personeline sakin kisisel verisi acmak
/// savunulamaz"). Paylasilan liste yuzunden o iki ekran amirin ana
/// ekraninda GORUNUYORDU.
///
/// NEDEN "MENUDE YOKSA ELE" DEGIL: once genel bir suzgec yazdim —
/// rotasi bir menu girisine karsilik gelip O ROLUN menusunde olmayan
/// karti eler. OLCTUM VE FAZLA GENISTI: admin 3 kart (`gorev yonetimi`,
/// `finansal ozet`, `raporlar`), guvenlik 1 (`arac gecisi`), sakin 1
/// (`sikayetlerim`) kaybediyordu. Sebep: bir rota BILEREK menusuz
/// olabilir (`sikayetlerim`, `nfc` — enum notlarinda yazili) ve menude
/// yokluk YASAK anlamina gelmiyor.
///
/// Bu yuzden kural, `auth.md`nin ACIKCA KAPATTIGI listeden turuyor —
/// cikarimla degil, YAZILI karardan.
const _amireKapali = <String>{
  '/kargo',
  '/visitors',
};

List<HizliErisimKart> rolunKartlari(
  List<HizliErisimKart> kartlar,
  UserRole rol,
) {
  if (rol != UserRole.guvenlikAmiri) return kartlar;
  return [
    for (final k in kartlar)
      if (k.rota == null || !_amireKapali.contains(k.rota)) k,
  ];
}

/// Kullanicinin izgarasi — sirali kart listesi.
///
/// [girisler] `null` ise KULLANICI HENUZ SECIM YAPMAMISTIR ve rolun BUGUNKU
/// kart listesi oldugu gibi donulur.
///
/// NEDEN VARSAYILAN "BUGUNKU LISTE": Kerem'in verdigi alti karo
/// (Duyurular · Sikayetler · Otopark · Gorev takibi · Vardiya ·
/// Rezervasyon) YONETICI kumesidir. Sakine uygulandiginda kesisim UC
/// karoya duser ve sakinin bugun gordugu SAYACLI kartlar — Aidatim
/// ("Borc Yok"), Kargo, Ziyaretci — ana ekrandan KAYBOLUR. Bu bir
/// kisisellestirme turuydu, sakinin ana ekranini budama turu degil;
/// olcum bunu gosterdi (26 ekran kilidi dustu) ve varsayilan
/// GERILEME URETMEYECEK sekilde secildi.
///
/// Yani: hicbir rol bugun gordugunu KAYBETMEZ, herkes isterse degistirir.
/// Yoneticinin varsayilanini alti karoya cekmek AYRI ve BILINCLI bir
/// kurasyon adimidir (bkz. P139 notu) — Kerem'in onayina birakildi.
List<HizliErisimKart> izgaraKartlari(
  List<HomeMenuEntry>? girisler,
  HomeVaryant varyant,
  HomeRepository taban,
) {
  final mevcut = taban.hizliErisim(varyant);
  if (girisler == null) return mevcut;
  return [for (final g in girisler) izgaraKartiUret(g, mevcut)];
}
