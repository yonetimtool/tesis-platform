/// Parola politikasi — backend ile AYNI kural: en az 8 karakter + en az bir
/// buyuk harf + rakam + sembol (Turkce harfler dahil). Form validator'larinda
/// kullanilir; gercek zorlama backend'de (422).
///
/// Donus: hata mesaji (gecersizse) ya da null (gecerli).
String? passwordError(String? value) {
  final v = value ?? '';
  if (v.length < 8) return 'En az 8 karakter olmalı';
  if (!RegExp(r'[A-ZÇĞİÖŞÜ]').hasMatch(v)) return 'En az bir büyük harf içermeli';
  if (!RegExp(r'[0-9]').hasMatch(v)) return 'En az bir rakam içermeli';
  if (!RegExp(r'[^0-9A-Za-zÇĞİÖŞÜçğıöşü\s]').hasMatch(v)) {
    return 'En az bir sembol içermeli (! ? @ # . -)';
  }
  return null;
}
