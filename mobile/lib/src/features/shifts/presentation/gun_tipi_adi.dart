/// `gun_tipi` tel degeri -> aktif dildeki gorunen ad.
///
/// KIMLIK / METIN AYRIMI (README §15): tur 12'de `shift_models.gunTipiLabel`
/// (TR sabitleri) KALDIRILDI. null = KISITSIZ → "her gün".
///
/// `default` dali BILINCLI: sozlesmeye yeni bir gun tipi eklenirse ekran ham
/// tel degerini yazar (bos kalmaz) — `odemeYontemiAdi` emsali (tur 11).
library;

import '../../../core/i18n/l10n.dart';

String gunTipiAdi(AppLocalizations l10n, String? gunTipi) => switch (gunTipi) {
      'hafta_ici' => l10n.gunTipiHaftaIci,
      'hafta_sonu' => l10n.gunTipiHaftaSonu,
      'resmi_tatil' => l10n.gunTipiResmiTatil,
      'her_gun' || null => l10n.gunTipiHerGun,
      final diger => diger,
    };
