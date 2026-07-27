/// [BudgetTip] -> aktif dildeki gorunen ad.
///
/// KIMLIK / METIN AYRIMI (README §15): tur 6'da `BudgetTip.label` kaldirildi;
/// gorunen ad burada, cizim aninda cozulur. `default` dali YOK — yeni bir tip
/// eklenirse derleyici ceviriyi zorlar.
library;

import '../../../core/i18n/l10n.dart';
import '../domain/budget_models.dart';

String butceTipAdi(AppLocalizations l10n, BudgetTip tip) => switch (tip) {
      BudgetTip.gelir => l10n.butGelir,
      BudgetTip.gider => l10n.butGider,
    };
