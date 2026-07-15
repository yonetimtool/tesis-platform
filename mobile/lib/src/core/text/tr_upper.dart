/// Turkce-dogru buyuk harf. Dart'in `toUpperCase()`'i 'i' -> 'I' cevirir; biz
/// 'i' -> 'İ' ve 'ı' -> 'I' isteriz. Diger harfleri (ç/ğ/ö/ş/ü) `toUpperCase`
/// zaten dogru cevirir. Once 'ı' donusturulur ki sonraki adimda dokunulmasin.
///
/// Uygulama genelinde ekran (AppBar) basliklari ve ana ekran menu kutucuklari
/// BUYUK HARF gosterilir; bu tek dogruluk kaynagidir.
String trUpper(String s) =>
    s.replaceAll('ı', 'I').replaceAll('i', 'İ').toUpperCase();
