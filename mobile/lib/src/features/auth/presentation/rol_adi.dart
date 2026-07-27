/// [UserRole] -> aktif dildeki gorunen ad.
///
/// Tur 4'te tasks/presentation'dan BURAYA tasindi: ikinci tuketici (complaints)
/// cikti ve rolun sahibi auth modulu.
///
/// KIMLIK / METIN AYRIMI (README §15): enum domain'de METIN TASIMAZ — eski
/// `UserRole.label` tur 8'de kaldirildi, gorunen ad ARTIK YALNIZ buradan
/// gelir. `switch` cizim katmanindadir (`CameraUrlHatasi` emsali) ve `default`
/// dali YOKTUR: yeni rol eklenince derleyici ceviriyi zorlar.
///
/// TR SOZCUK BIRLIGI: `label` doneminde admin/yonetici icin IKI ayri metin
/// dolasiyordu ("Platform Admin"/"Yönetici" enum'da, "Platform Admini"/"Site
/// Yöneticisi" burada). Tur 8'de tek kaynak burasi oldu.
library;

import '../../../core/i18n/l10n.dart';
import '../domain/user_role.dart';

String rolAdi(AppLocalizations l10n, UserRole rol) => switch (rol) {
      UserRole.admin => l10n.rolAdmin,
      UserRole.yonetici => l10n.rolYonetici,
      UserRole.security => l10n.rolGuvenlik,
      UserRole.tesisGorevlisi => l10n.rolTesisGorevlisi,
      UserRole.resident => l10n.rolSakin,
      UserRole.unknown => l10n.rolBilinmeyen,
    };
