/// Para OLMAYAN sayilar (P57) — koordinat, olcu, adet.
///
/// NEDEN AYRI: `core/para.dart` KURUS tam sayisi uretir; koordinat gibi
/// alanlar `double` ister ve iki basamak kisiti yoktur. Ama AYIRICI KURALI
/// AYNIDIR — kullanici ayni yazimi her alanda kullanabilmeli.
///
/// UC DURUM AYRI: bos girdi ile ayristirilamayan girdi AYNI SEY DEGILDIR.
/// `double.tryParse` ikisine de `null` doner ve cagiran ikisini de "alani
/// temizle" diye yorumlarsa, gecersiz yazan kullanici alani SESSIZCE
/// sildirir. Panelde bu sinif alti yerde bulundu (P56).
library;

enum SayiTuru { sayi, bos, gecersiz }

class SayiSonuc {
  const SayiSonuc(this.tur, [this.deger]);
  final SayiTuru tur;
  final double? deger;

  bool get gecerli => tur != SayiTuru.gecersiz;
}

/// "41,0082" / "41.0082" / "1.250" -> sayi. Bos -> [SayiTuru.bos].
///
/// AYIRICI KURALI (`core/para.dart` ile AYNI):
///   * Virgul VARSA: virgul ONDALIK, nokta BINLIK.
///   * Virgul YOKSA ve TEK nokta + en fazla iki hane: nokta ONDALIK.
///   * Aksi halde nokta BINLIK.
///
/// Nokta ondaligi da kabul edilir cunku Turkce klavyede ondalik tusu
/// VIRGUL, ingilizce klavyede NOKTA'dir; kullaniciya klavyesini
/// degistirtmek bir cozum degildir.
SayiSonuc sayiCoz(String girdi) {
  final s = girdi.trim();
  if (s.isEmpty) return const SayiSonuc(SayiTuru.bos);
  if (RegExp(r'\s').hasMatch(s)) return const SayiSonuc(SayiTuru.gecersiz);

  final negatif = s.startsWith('-');
  final govde = negatif ? s.substring(1) : s;

  String tamKisim;
  String ondalik = '';
  if (govde.contains(',')) {
    final parcalar = govde.split(',');
    if (parcalar.length != 2 || parcalar[0].isEmpty || parcalar[1].isEmpty) {
      return const SayiSonuc(SayiTuru.gecersiz); // `41,` ya da `,5`
    }
    tamKisim = parcalar[0].replaceAll('.', '');
    ondalik = parcalar[1];
  } else {
    final nokta = govde.lastIndexOf('.');
    if (nokta == govde.length - 1 && nokta != -1) {
      return const SayiSonuc(SayiTuru.gecersiz); // `41.`
    }
    if (nokta == 0) return const SayiSonuc(SayiTuru.gecersiz); // `.5`
    if (nokta != -1 &&
        govde.indexOf('.') == nokta &&
        govde.length - nokta - 1 <= 2) {
      tamKisim = govde.substring(0, nokta);
      ondalik = govde.substring(nokta + 1);
    } else {
      tamKisim = govde.replaceAll('.', '');
    }
  }

  if (!RegExp(r'^\d+$').hasMatch(tamKisim)) {
    return const SayiSonuc(SayiTuru.gecersiz);
  }
  if (ondalik.isNotEmpty && !RegExp(r'^\d+$').hasMatch(ondalik)) {
    return const SayiSonuc(SayiTuru.gecersiz);
  }
  final deger = double.tryParse('$tamKisim.${ondalik.isEmpty ? '0' : ondalik}');
  if (deger == null) return const SayiSonuc(SayiTuru.gecersiz);
  return SayiSonuc(SayiTuru.sayi, negatif ? -deger : deger);
}
