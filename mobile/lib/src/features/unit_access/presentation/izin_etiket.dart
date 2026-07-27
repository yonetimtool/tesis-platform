/// [AccessRequestDurum] -> aktif dildeki gorunen ad (`default` dali YOK).
library;

import '../../../core/i18n/l10n.dart';
import '../domain/unit_access_models.dart';

String erisimDurumAdi(AppLocalizations l10n, AccessRequestDurum d) =>
    switch (d) {
      AccessRequestDurum.bekliyor => l10n.devriyeDurumBekliyor,
      AccessRequestDurum.onaylandi => l10n.izinDurumOnaylandi,
      AccessRequestDurum.reddedildi => l10n.talepDurumReddedildi,
      AccessRequestDurum.unknown => l10n.devriyeDurumBilinmiyor,
    };
