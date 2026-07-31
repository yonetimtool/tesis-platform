/// [UnitComplaintKategori] -> aktif dildeki gorunen ad.
///
/// KIMLIK / METIN AYRIMI (README §15): enum'daki `label` TR sabittir ve
/// YERELLESTIRILMIS ekranlarda kullanilmaz; `switch` cizim katmanindadir
/// (`CameraUrlHatasi` emsali). `default` dali YOKTUR — yeni kategori eklenince
/// derleyici ceviriyi zorlar. `label` henuz cevrilmemis `my_complaints`
/// ekraninda kullanildigi icin kaldirilmadi.
library;

import '../../../core/i18n/l10n.dart';
import '../domain/unit_complaint_models.dart';

String unitComplaintKategoriAdi(
  AppLocalizations l10n,
  UnitComplaintKategori k,
) =>
    switch (k) {
      UnitComplaintKategori.gurultu => l10n.kategoriGurultu,
      UnitComplaintKategori.kapiOnuAyakkabi => l10n.kategoriKapiOnuAyakkabi,
      UnitComplaintKategori.zararVerme => l10n.kategoriZararVerme,
      UnitComplaintKategori.goruntuKirliligi => l10n.kategoriGoruntuKirliligi,
      UnitComplaintKategori.diger => l10n.gorevKategoriDiger,
    };
