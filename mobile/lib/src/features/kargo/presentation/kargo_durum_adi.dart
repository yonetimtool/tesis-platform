/// [KargoDurum] -> aktif dildeki gorunen ad.
///
/// KIMLIK / METIN AYRIMI (README §15): `label` alani TR sabittir ve
/// YERELLESTIRILMIS ekranlarda kullanilmaz. Bu cozucu tur 5'te eklendi cunku
/// `unit_access` kayit ekrani (kapsam ICI) kargo durumunu cizer; `kargo`
/// modulunun kendi ekranlari henuz cevrilmedigi icin `label` korundu.
library;

import '../../../core/i18n/l10n.dart';
import '../domain/kargo_models.dart';

String kargoDurumAdi(AppLocalizations l10n, KargoDurum d) => switch (d) {
      KargoDurum.bekliyor => l10n.devriyeDurumBekliyor,
      KargoDurum.teslimAlindi => l10n.kargoDurumTeslimAlindi,
      KargoDurum.unknown => l10n.devriyeDurumBilinmiyor,
    };
