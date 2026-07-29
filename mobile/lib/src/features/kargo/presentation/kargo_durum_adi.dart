/// [KargoDurum] -> aktif dildeki gorunen ad.
///
/// KIMLIK / METIN AYRIMI (README §15). Bu cozucu tur 5'te eklendi cunku
/// `unit_access` kayit ekrani (o turun kapsami) kargo durumunu ciziyordu;
/// `kargo` modulunun kendi ekranlari henuz cevrilmedigi icin enum'daki TR
/// `label` alani o turda korunmustu. Tur 6'da `kargo` cevrildi ve `label`
/// KALDIRILDI — gorunen ad artik YALNIZ buradan gelir.
library;

import '../../../core/i18n/l10n.dart';
import '../domain/kargo_models.dart';

String kargoDurumAdi(AppLocalizations l10n, KargoDurum d) => switch (d) {
  KargoDurum.bekliyor => l10n.devriyeDurumBekliyor,
  KargoDurum.teslimAlindi => l10n.kargoDurumTeslimAlindi,
  KargoDurum.unknown => l10n.devriyeDurumBilinmiyor,
};
