/// Rezervasyon alan tiplerinin KIMLIKLERINDEN aktif dildeki metinler.
///
/// `default` dali YOKTUR: yeni durum/sebep eklenince derleyici ceviriyi zorlar.
library;

import '../../../core/i18n/l10n.dart';
import '../domain/rezervasyon_models.dart';

String rezDurumAdi(AppLocalizations l10n, RezervasyonDurum d) => switch (d) {
      RezervasyonDurum.onaylandi => l10n.rezDurumOnayli,
      RezervasyonDurum.iptal => l10n.ortakIptal,
      RezervasyonDurum.unknown => l10n.devriyeDurumBilinmiyor,
    };

String slotSebepAdi(AppLocalizations l10n, SlotSebep s) => switch (s) {
      SlotSebep.dolu => l10n.rezSebepDolu,
      SlotSebep.gecti => l10n.rezSebepGecti,
      SlotSebep.cokErken => l10n.rezSebepCokErken,
      SlotSebep.gunluk => l10n.rezSebepGunluk,
    };

/// Alan musaitlik ozeti — domain'den TASINDI (metin cizim aninda kurulur).
String musaitlikOzeti(AppLocalizations l10n, OrtakAlan alan) =>
    l10n.rezMusaitOzeti(alan.acilis, alan.kapanis, '${alan.slotDakika}');
