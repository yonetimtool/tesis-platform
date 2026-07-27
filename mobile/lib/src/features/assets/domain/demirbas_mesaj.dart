/// Demirbas denetleyicisinin urettigi YERELLESTIRILEBILIR mesaj kimlikleri.
///
/// KIMLIK / METIN AYRIMI (README §15, `CameraUrlHatasi` emsali): denetleyicide
/// `BuildContext` yoktur, gorunen metin uretemez. Diger modullerde tek bir
/// `enum` + ayri `errorMessage` alani yetiyordu; demirbas mesajlarinin bir
/// kismi PARAMETRE tasidigi icin (okutulan UID, catisan demirbas adi) burada
/// SEALED sinif kullanilir: kimlik ve parametreleri birlikte tasir, ekran
/// `demirbasMesajMetni` ile cizim aninda cozer.
///
/// [DemirbasSunucuMetni] sunucu kanalidir: `ApiException.message` zaten
/// sunucuda yerellestirilmis gelir, oldugu gibi tasinir (ceviri denenmez).
library;

import '../../nfc/domain/nfc_hatasi.dart';

sealed class DemirbasMesaj {
  const DemirbasMesaj();
}

/// Parametresiz kimlikler.
enum DemirbasMesajKimlik {
  /// Siniflandirilamayan hata.
  beklenmeyen,

  /// Baglanti yok — zimmet ANLIK kayit oldugu icin offline islem yapilmaz.
  offline,

  /// NFC etiketi okunamadi (servis metin vermedi).
  etiketOkunamadi,

  /// 403 — rol demirbas listesine erisemiyor.
  listeYetkiYok,

  /// Ayni Idempotency-Key ile tekrar gonderim — cift kayit olusmadi.
  zatenZimmetinde,

  /// Zimmet acildi.
  zimmetineAlindi,

  /// Zimmet kapandi.
  birakildi,
}

final class DemirbasKimlikMesaji extends DemirbasMesaj {
  const DemirbasKimlikMesaji(this.kimlik);

  final DemirbasMesajKimlik kimlik;
}

/// Okutulan etiket hicbir demirbasa tanimli degil (UID gosterilir).
final class DemirbasEtiketEslesmiyor extends DemirbasMesaj {
  const DemirbasEtiketEslesmiyor(this.uid);

  final String uid;
}

/// 409 yarisi: sunucu mesaji + "karta tekrar bakin" yonlendirmesi.
final class DemirbasCakismaMesaji extends DemirbasMesaj {
  const DemirbasCakismaMesaji(this.sunucuMetni);

  final String sunucuMetni;
}

/// Listeden hizli birakmada 409: hangi demirbasta oldugunu ada bagla.
final class DemirbasAdliHata extends DemirbasMesaj {
  const DemirbasAdliHata({required this.ad, required this.sunucuMetni});

  final String ad;
  final String sunucuMetni;
}

/// NFC servisinin dondurdugu kimlik (tur 9: eskiden TR sabit metin gelirdi ve
/// yanlislikla SUNUCU kanalindan tasiniyordu).
final class DemirbasNfcHatasi extends DemirbasMesaj {
  const DemirbasNfcHatasi(this.kimlik, {this.detay});

  final NfcHatasi kimlik;
  final String? detay;
}

/// Sunucu metni (zaten yerellestirilmis) — oldugu gibi gosterilir.
final class DemirbasSunucuMetni extends DemirbasMesaj {
  const DemirbasSunucuMetni(this.metin);

  final String metin;
}
