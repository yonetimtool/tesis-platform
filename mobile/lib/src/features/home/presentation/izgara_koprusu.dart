import '../../auth/domain/user_role.dart';
import '../data/home_repository.dart';
import '../domain/home_izgara.dart';
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
///
/// (E2E 2026-09) `/visitors` CIKARILDI: P231 §3 amire ziyaretci kayitlarini
/// OKUMA olarak acti ve menude de var (backend 200). Kart kapali, menu acik
/// kalmisti — ayni ekran iki yerde farkli davraniyordu.
const _amireKapali = <String>{
  '/kargo',
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

/// (P251 §11) Menude karsiligi olmayan kartin kayit oneki.
const izgaraKartOneki = 'kart:';

/// (P251 §11) CIZILEN KART SIRASI -> KAYDEDILECEK ADLAR.
///
/// Surukle-birak ekrandaki KARTLARI tasir; kayit ise ad tutar. Kart uc
/// yoldan ada baglanir, sirayla:
///   1. kullanicinin sectigi karoda `modulGirisi` dolu,
///   2. rolun bugunku (varsayilan) kartinda ROTA ile menu girisi bulunur
///      (kopru [izgaraKartiUret] de ayni dili konusuyor),
///   3. menude karsiligi YOKSA `kart:<kimlik>` — OLCULDU: varsayilan
///      izgarada bes rolde menusuz kart var (sakinde "Sikayetlerim",
///      guvenlikte "Arac plaka", amirde "Demirbas", adminde uc kart).
///      Ucuncu yol olmasaydi bu kullanicilar ilk surukleyiste o kartlari
///      SESSIZCE kaybederdi.
List<String> kartlardanIzgara(List<HizliErisimKart> kartlar, UserRole rol) {
  final secenekler = izgaraSecenekleri(rol);
  final sonuc = <String>[];
  for (final k in kartlar) {
    final ad = (k.modulGirisi ?? _rotadanGiris(k.rota, secenekler))?.name ??
        '$izgaraKartOneki${k.id.name}';
    if (!sonuc.contains(ad)) sonuc.add(ad);
  }
  return sonuc;
}

/// (P251 §11) KAYITLI ADLAR -> CIZILECEK KARTLAR.
///
/// [adlar] `null` ise [kurasyon] (bugun kapali, bkz. `izgaraKarolariProvider`)
/// ya da rolun bugunku listesi. Rolun goremedigi giris ve rolde artik
/// olmayan kart CIZILMEZ; ust sinir [izgaraEnCokKaro]. Hicbiri cozulmezse
/// rolun bugunku listesi — kullanici bos bir ana ekranla kalmaz.
List<HizliErisimKart> izgaraKartlariKayittan(
  List<String>? adlar,
  List<HomeMenuEntry>? kurasyon,
  UserRole rol,
  HomeVaryant varyant,
  HomeRepository taban,
) {
  final mevcut = rolunKartlari(taban.hizliErisim(varyant), rol);
  if (adlar == null) {
    return kurasyon == null
        ? mevcut
        : rolunKartlari(izgaraKartlari(kurasyon, varyant, taban), rol);
  }
  final izinli = izgaraSecenekleri(rol).toSet();
  final girisler = HomeMenuEntry.values.asNameMap();
  final sonuc = <HizliErisimKart>[];
  void ekle(HizliErisimKart k) {
    if (!sonuc.any((x) => x.id == k.id && x.rota == k.rota)) sonuc.add(k);
  }

  for (final ad in adlar) {
    if (ad.startsWith(izgaraKartOneki)) {
      final id = ad.substring(izgaraKartOneki.length);
      for (final k in mevcut) {
        if (k.id.name == id) {
          ekle(k);
          break;
        }
      }
      continue;
    }
    final g = girisler[ad];
    if (g != null && izinli.contains(g)) ekle(izgaraKartiUret(g, mevcut));
  }
  if (sonuc.isEmpty) return mevcut;
  return rolunKartlari(sonuc.take(izgaraEnCokKaro).toList(), rol);
}

HomeMenuEntry? _rotadanGiris(String? rota, List<HomeMenuEntry> secenekler) {
  if (rota == null) return null;
  for (final e in secenekler) {
    if (moduleCardSpec(e).route == rota) return e;
  }
  return null;
}
