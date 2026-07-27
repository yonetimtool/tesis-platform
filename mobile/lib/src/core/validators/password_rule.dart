/// Parola politikasi — backend ile AYNI kural: en az 8 karakter + en az bir
/// buyuk harf + rakam + sembol (Turkce harfler dahil). Form validator'larinda
/// kullanilir; gercek zorlama backend'de (422).
///
/// KIMLIK / METIN AYRIMI (README §15): kural KIMLIK dondurur
/// ([ParolaKuraliHatasi]), gorunen metni cizim aninda [parolaKuraliMetni]
/// cozer. Tur 7'de ertelenmisti cunku eski `passwordError` DORT ekranda
/// kullaniliyordu (auth, profile, staff, residents) ve ucu o turun kapsami
/// disindaydi; tur 8'de dorduyle birlikte tasindi.
library;

import '../i18n/l10n.dart';

enum ParolaKuraliHatasi {
  /// 8 karakterden kisa.
  kisa,

  /// Buyuk harf yok (Turkce harfler dahil).
  buyukHarfYok,

  /// Rakam yok.
  rakamYok,

  /// Sembol yok.
  sembolYok,
}

/// Parolanin hangi kurali ihlal ettigi — gecerliyse null.
ParolaKuraliHatasi? parolaKuraliHatasi(String? value) {
  final v = value ?? '';
  if (v.length < 8) return ParolaKuraliHatasi.kisa;
  if (!RegExp(r'[A-ZÇĞİÖŞÜ]').hasMatch(v)) {
    return ParolaKuraliHatasi.buyukHarfYok;
  }
  if (!RegExp(r'[0-9]').hasMatch(v)) return ParolaKuraliHatasi.rakamYok;
  if (!RegExp(r'[^0-9A-Za-zÇĞİÖŞÜçğıöşü\s]').hasMatch(v)) {
    return ParolaKuraliHatasi.sembolYok;
  }
  return null;
}

/// Kimlik -> aktif dildeki metin. `default` dali YOK: yeni kural eklenince
/// derleyici ceviriyi zorlar.
String parolaKuraliMetni(AppLocalizations l10n, ParolaKuraliHatasi hata) =>
    switch (hata) {
      ParolaKuraliHatasi.kisa => l10n.parolaKuraliKisa,
      ParolaKuraliHatasi.buyukHarfYok => l10n.parolaKuraliBuyukHarf,
      ParolaKuraliHatasi.rakamYok => l10n.parolaKuraliRakam,
      ParolaKuraliHatasi.sembolYok => l10n.parolaKuraliSembol,
    };

/// Form validator'lari icin hazir sarmalayici: gecersizse yerellestirilmis
/// metin, gecerliyse null.
String? parolaHataMetni(AppLocalizations l10n, String? value) {
  final hata = parolaKuraliHatasi(value);
  return hata == null ? null : parolaKuraliMetni(l10n, hata);
}
