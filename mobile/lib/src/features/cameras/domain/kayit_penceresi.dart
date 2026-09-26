/// (P248 §1-kamera) Gecmis kayit penceresi — SAF kurallar (widget'siz).
library;

/// Sunucudaki `_KAYIT_PENCERE_AZAMI` ile AYNI deger (routers/cameras.py).
///
/// Istemcide de uygulanir cunku asimi sunucuya gondermek, NVR'a gitmeden
/// 422 alacak bir istegi kullaniciya "araniyor" diye bekletmek olurdu.
/// Sinirin ASIL sahibi sunucudur; bu kopya yalniz erken uyaridir.
const kayitPencereAzami = Duration(hours: 24);

enum KayitPencereHatasi {
  /// Bitis baslangictan once ya da esit.
  ters,

  /// 24 saatten genis.
  genis,

  /// Baslangic gelecekte — henuz kaydedilmemis bir ani aramak.
  gelecek,
}

/// Pencere gecerli mi? `null` = gecerli.
KayitPencereHatasi? kayitPenceresiDenetle(
  DateTime bas,
  DateTime bit, {
  DateTime? simdi,
}) {
  if (!bit.isAfter(bas)) return KayitPencereHatasi.ters;
  if (bit.difference(bas) > kayitPencereAzami) return KayitPencereHatasi.genis;
  if (bas.isAfter(simdi ?? DateTime.now())) return KayitPencereHatasi.gelecek;
  return null;
}

/// Seritteki bir parca: kayit VAR (`dolu`) ya da BOSLUK.
class KayitParcasi {
  const KayitParcasi(this.bas, this.bit, {required this.dolu});

  final DateTime bas;
  final DateTime bit;
  final bool dolu;
}

/// Arama penceresini, sunucunun dondurdugu kayitli araliklar ve
/// ARALARINDAKI BOSLUKLAR olarak parcalar.
///
/// BOSLUKLAR NEDEN GOSTERILIR: gecmis kayda bakan amirin sordugu soru
/// cogu zaman "su saatte kayit neden yok" sorusudur (kamera kapandi mi,
/// NVR mi durdu). Yalniz dolu araliklari listelemek, bosluklari okuyucunun
/// saatleri kafasinda cikarmasina birakirdi.
///
/// Araliklar pencereye KIRPILIR ve sirlanir; ust uste binenler
/// birlestirilir (NVR'lar ayni dosyayi iki kez dondurebiliyor).
List<KayitParcasi> kayitSeridi(
  DateTime pencereBas,
  DateTime pencereBit,
  List<({DateTime bas, DateTime bit})> araliklar,
) {
  final kirpik = <({DateTime bas, DateTime bit})>[];
  for (final a in araliklar) {
    final b = a.bas.isBefore(pencereBas) ? pencereBas : a.bas;
    final s = a.bit.isAfter(pencereBit) ? pencereBit : a.bit;
    if (s.isAfter(b)) kirpik.add((bas: b, bit: s));
  }
  kirpik.sort((x, y) => x.bas.compareTo(y.bas));
  final birlesik = <({DateTime bas, DateTime bit})>[];
  for (final a in kirpik) {
    if (birlesik.isNotEmpty && !a.bas.isAfter(birlesik.last.bit)) {
      final son = birlesik.removeLast();
      birlesik.add((
        bas: son.bas,
        bit: a.bit.isAfter(son.bit) ? a.bit : son.bit,
      ));
    } else {
      birlesik.add(a);
    }
  }
  final out = <KayitParcasi>[];
  var imlec = pencereBas;
  for (final a in birlesik) {
    if (a.bas.isAfter(imlec)) out.add(KayitParcasi(imlec, a.bas, dolu: false));
    out.add(KayitParcasi(a.bas, a.bit, dolu: true));
    imlec = a.bit;
  }
  if (pencereBit.isAfter(imlec)) {
    out.add(KayitParcasi(imlec, pencereBit, dolu: false));
  }
  return out;
}
