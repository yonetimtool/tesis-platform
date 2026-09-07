/// (DUKKAN F6-ek) DUKKAN PUSH TIKLAMA YONLENDIRMESI.
///
/// ===========================================================================
/// NEDEN AYRI BIR HARITA — VE NEDEN `push_yonlendirme.dart`A EKLENMEDI
/// ===========================================================================
/// Yonetiyor'un haritasi hedefi ROLE gore secer ve sonra ROLUN MENUSUNDEN
/// turetilen bir erisim suzgecinden gecirir. Dukkan'da o iki dayanak da
/// YOK:
///
///   * Dukkan'in ROLU yoktur. Ayni kisi ayni anda hem talep sahibi hem
///     isletme sahibidir; hedefi belirleyen sey kim OLDUGU degil, olayin
///     KIME dair oldugudur. Bunu zaten `tip` soyluyor.
///   * Dukkan ekranlari rol menusunde DEGIL; `yerelIsletmeler` girdisi
///     tum rollerde tek bir karttir. Menuden turetilen suzgec burada
///     hicbir sey olcmezdi.
///
/// Iki dunyayi tek fonksiyona sikistirmak, ikisinin de kuralini
/// bulaniklastirirdi. Ayrik tutuluyorlar; birlesme noktasi TEK: push
/// govdesindeki `tip` alani `dukkan_` onekliyse buraya, degilse
/// Yonetiyor haritasina gider (bkz. `pushHedefiBirlesik`).
///
/// ===========================================================================
/// P211/P217 DERSI: SUNUCUNUN `yol`U DOGRUDAN KULLANILMAZ
/// ===========================================================================
/// Sunucu her bildirime bir `yol` koyuyor ama o yol WEB yoludur
/// (`/panel/{isletme_id}`, `/taleplerim/{talep_id}`). Mobilde o yollar
/// YOK. `yol`u dogrudan `context.go`ya vermek, tam olarak P211'de
/// olculen kusuru uretirdi: bildirim dogru kisiye gider, dokunma bos
/// ekrana ya da hicbir yere goturur.
///
/// Bu yuzden ceviri `tip` UZERINDEN yapiliyor, `yol` uzerinden DEGIL:
/// sunucu yarin web yolunu degistirse mobil kirilmaz.
///
/// ===========================================================================
/// HEDEFI OLMAYAN TIP `null` DONER — VE BU BIR BOSLUK DEGIL
/// ===========================================================================
/// Bilinmeyen bir tip icin "en yakin ekrana goturelim" demek, kullaniciya
/// ilgisiz bir liste acmaktir. `null` donunce cagiran YONLENDIRME YAPMAZ;
/// bildirim yine de listede durur ve okunur. Kilit testi her sunucu
/// tipinin BURADA karsiligi oldugunu olcuyor, boylece "null" bir unutma
/// degil ancak BILINCLI bir karar olabilir.
library;

import '../../../routing/app_router.dart';

/// Sunucudaki `TIPLER` sozlugunun (backend/app/dukkan/bildirim.py) mobil
/// karsiligi. Sunucu yeni bir tip eklerse ve buraya eklenmezse
/// `dukkan_push_yonlendirme_test.dart` DUSER.
String? dukkanPushHedefi(Map<String, String> veri) {
  final tip = veri['tip'];
  switch (tip) {
    // ----------------------- TALEP SAHIBI TARAFI ---------------------- #
    // "Teklif geldi" -> kendi taleplerim. Talep kimligi varsa detay
    // dogrudan acilsin: kullanicinin ustune 12 talepli bir liste acip
    // "hangisiydi" dedirtmek, bildirimin isini yarim birakmaktir.
    case 'dukkan_teklif_geldi':
      final id = veri['talep_id'];
      return id == null || id.isEmpty
          ? AppRoutes.dukkanTaleplerim
          : AppRoutes.dukkanTalepDetay.replaceFirst(':talepId', id);

    // ----------------------- ISLETME SAHIBI TARAFI -------------------- #
    // Bu dort tipin web hedefi `/panel/{isletme_id}`. Mobilde karsiligi
    // F6-ek'te acilan ISLETME PANELIDIR. Panel olmasaydi bu tipler
    // `null` donerdi ve "yeni talep var" bildirimi DOKUNULAMAZ olurdu —
    // pazar yerinin arz tarafi bildirimsiz kalirdi.
    case 'dukkan_yeni_talep':
    case 'dukkan_is_verildi':
    case 'dukkan_isletme_onaylandi':
    case 'dukkan_isletme_reddedildi':
    case 'dukkan_isletme_askiya_alindi':
      final id = veri['isletme_id'];
      return id == null || id.isEmpty
          ? AppRoutes.dukkanPanel
          : '${AppRoutes.dukkanPanel}?isletme_id=$id';

    // "Yorumun yayinlandi" -> KAMU PROFILI. Yorumu yazan da isletme
    // sahibi de ayni sayfayi gormeli: yayinlanan sey odur.
    case 'dukkan_yorum_yayinlandi':
      final slug = veri['isletme_slug'];
      if (slug == null || slug.isEmpty) return null;
      return AppRoutes.dukkanIsletme.replaceFirst(':slug', slug);

    default:
      return null;
  }
}

/// Bir push govdesi DUKKAN'a mi ait?
///
/// ONEKE BAKIYOR, LISTEYE DEGIL: sunucu tarafinda kanal secimi de ayni
/// oneke bakiyor (`push_kanal.DUKKAN_ONEK`). Iki tarafta ayni kural
/// olunca, yeni bir tip eklendiginde birinin unutulmasi mumkun degil.
bool dukkanBildirimiMi(Map<String, String> veri) =>
    (veri['tip'] ?? '').startsWith('dukkan_');
