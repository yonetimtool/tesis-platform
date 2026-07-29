import 'package:flutter/material.dart';

/// Gorev tipinin (yonetici-tanimli KATEGORI) liste/detayda ortak gorunumu.
/// Sabit tip enum'u kaldirildi; renk kategori ADINDAN deterministik turer
/// (ayni kategori hep ayni renk).
///
/// KIMLIK / METIN AYRIMI (README §15): bu yardimci GORUNEN METIN URETMEZ.
/// Kategorisiz gorevde `ad` **null** doner ve ekran metni cizim aninda
/// `l10n.gorevKategoriDiger` ile cozer. Eskiden TR sabiti hem etiketti hem de
/// esitlik KARSILASTIRMASININ anahtariydi; dil degisse kategorisiz gorev
/// yanlis kola duserdi (`CameraUrlHatasi` / `HomeKartId` emsali).
///
/// Renk: kategori adi SUNUCU verisidir (cevrilmez), bu yuzden hash'ten tureyen
/// renk dilden BAGIMSIZ olarak sabit kalir.
({Color color, IconData icon, String? ad}) taskKategoriStyle(
  String? kategoriAd,
) {
  if (kategoriAd == null || kategoriAd.isEmpty) {
    return (
      color: Colors.blueGrey,
      icon: Icons.task_alt_outlined,
      ad: null, // kategorisiz -> ekran l10n.gorevKategoriDiger yazar
    );
  }
  final hue = (kategoriAd.hashCode & 0x7fffffff) % 360;
  return (
    color: HSLColor.fromAHSL(1, hue.toDouble(), 0.5, 0.45).toColor(),
    icon: Icons.label_outline,
    ad: kategoriAd,
  );
}

/// Oncelik (dusuk|orta|yuksek) KIMLIGI — wire degeri teknik sabittir, gorunen
/// metin degil. Bilinmeyen/null -> [TaskOncelik.yok] (notr rozet).
enum TaskOncelik { dusuk, orta, yuksek, yok }

/// Wire degeri -> kimlik. Karsilastirma ASCII sabitler uzerinedir (dilden
/// bagimsiz); etiket `oncelikEtiketi` ile cizim aninda cozulur.
TaskOncelik taskOncelikKimligi(String? wire) => switch (wire) {
  'dusuk' => TaskOncelik.dusuk,
  'orta' => TaskOncelik.orta,
  'yuksek' => TaskOncelik.yuksek,
  _ => TaskOncelik.yok,
};

/// Oncelik rengi — complaints paletiyle uyumlu (yesil/amber/kirmizi).
Color taskOncelikRengi(TaskOncelik o) => switch (o) {
  TaskOncelik.dusuk => Colors.green,
  TaskOncelik.orta => Colors.amber.shade800,
  TaskOncelik.yuksek => Colors.red,
  TaskOncelik.yok => Colors.blueGrey,
};
