/// [KatilimDurum] -> aktif dildeki gorunen ad (`default` dali YOK).
library;

import '../../../core/i18n/l10n.dart';
import '../domain/etkinlik_models.dart';

String katilimDurumAdi(AppLocalizations l10n, KatilimDurum d) => switch (d) {
  KatilimDurum.katiliyorum => l10n.etkKatiliyorum,
  KatilimDurum.katilmiyorum => l10n.etkKatilmiyorum,
};
