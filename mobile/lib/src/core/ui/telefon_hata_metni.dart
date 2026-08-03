/// (P123) [TelefonHatasi] -> aktif dildeki cümle.
///
/// KİMLİK / METİN AYRIMI (README §15): `telefon_alani.dart` domain
/// katmanıdır, `BuildContext` görmez ve cümle üretemez. Çeviri burada
/// çözülür; `default` dalı YOKTUR — yeni bir hata kimliği eklenince
/// derleyici bu dosyayı gösterir ve çeviriyi zorlar.
library;

import '../i18n/l10n.dart';
import 'telefon_alani.dart';

/// Form doğrulayıcılarının doğrudan verebileceği metin; `null` = geçerli.
String? telefonHataMetni(
  AppLocalizations l10n,
  String ham, {
  bool zorunlu = true,
}) {
  return switch (telefonHatasi(ham, zorunlu: zorunlu)) {
    null => null,
    TelefonHatasi.bos => l10n.ortakTelefonZorunlu,
    TelefonHatasi.eksik => l10n.telefonHataEksik,
    TelefonHatasi.gecersizOnEk => l10n.telefonHataOnEk,
  };
}
