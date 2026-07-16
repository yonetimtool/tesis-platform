/// `tel:` URI uretimi — cihaz ceviricisine verilecek tek bicim. Arama
/// mantiginin TEK yeri (CallLauncher ile birlikte); kopyalanmaz.
library;

/// Telefon numarasini `tel:` URI'sine cevirir. Gorsel ayraclar (bosluk,
/// tire, parantez, nokta) atilir; `+` ve rakamlar kalir. Aranabilir icerik
/// yoksa null — arama butonu hic gosterilmez.
Uri? telUri(String phone) {
  final cleaned = phone.replaceAll(RegExp(r'[\s\-().]'), '');
  if (!RegExp(r'^\+?\d+$').hasMatch(cleaned)) return null;
  return Uri(scheme: 'tel', path: cleaned);
}
