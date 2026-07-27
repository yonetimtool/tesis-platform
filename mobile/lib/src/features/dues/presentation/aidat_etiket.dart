/// Odeme YONTEMI / DURUMU tel degeri -> aktif dildeki gorunen ad.
///
/// KIMLIK / METIN AYRIMI (README §15): tur 11'de `dues_models.yontemLabel` ve
/// `durumLabel` (TR sabitleri) KALDIRILDI; domain sozlesme tel degerini tasir,
/// metin burada cozulur (`kargoDurumAdi` emsali).
///
/// Sozlesmede enum olmayan (ham String) alanlar oldugu icin `switch` bir
/// `default` dali TASIR: bilinmeyen tel degeri OLDUGU GIBI gosterilir —
/// backend yeni bir yontem eklerse ekran "elden" yerine ham degeri yazar,
/// bos kalmaz.
library;

import '../../../core/i18n/l10n.dart';

String odemeYontemiAdi(AppLocalizations l10n, String yontem) =>
    switch (yontem) {
      'elden' => l10n.aidatYontemElden,
      'havale' => l10n.aidatYontemHavale,
      'kart' => l10n.aidatYontemKart,
      'diger' => l10n.aidatYontemDiger,
      _ => yontem,
    };

String odemeDurumuAdi(AppLocalizations l10n, String durum) => switch (durum) {
      'basarili' => l10n.aidatDurumBasarili,
      'bekliyor' => l10n.kuyrukBekliyor,
      'iptal' => l10n.aidatDurumIptal,
      _ => durum,
    };
