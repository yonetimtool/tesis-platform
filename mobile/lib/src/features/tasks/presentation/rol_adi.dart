/// [UserRole] -> aktif dildeki gorunen ad.
///
/// KIMLIK / METIN AYRIMI (README §15): enum domain'de METIN TASIMAZ
/// (`UserRole.label` henuz cevrilmemis modullerin TR sabitidir); `switch`
/// cizim katmanindadir — `CameraUrlHatasi` emsali. `default` dali YOKTUR:
/// yeni rol eklenince derleyici ceviriyi zorlar.
library;

import '../../../core/i18n/l10n.dart';
import '../../auth/domain/user_role.dart';

String rolAdi(AppLocalizations l10n, UserRole rol) => switch (rol) {
      UserRole.admin => l10n.rolAdmin,
      UserRole.yonetici => l10n.rolYonetici,
      UserRole.security => l10n.rolGuvenlik,
      UserRole.tesisGorevlisi => l10n.rolTesisGorevlisi,
      UserRole.resident => l10n.rolSakin,
      UserRole.unknown => l10n.rolBilinmeyen,
    };
