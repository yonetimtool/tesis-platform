/// Ana ekran VARYANTI — referans gorsellerin uc duzeni. Rol → varyant esleme
/// TEK yerde; ekran secimi (HomeGate) ve mock veri secimi ayni fonksiyonu
/// kullanir.
library;

import '../../auth/domain/user_role.dart';

/// Uc referans duzen: gorevli.jpeg / site-sakini.jpeg / yonetici.jpeg.
enum HomeVaryant {
  /// Yatay hizli erisim seridi + vardiya + son hareketler + canli kamera.
  gorevli,

  /// 4x2 izgara + odeme karti + son hareketler + duyurular.
  sakin,

  /// 4x2 izgara + vardiya + hizli ozet + son hareketler.
  yonetici,
}

/// Rolun ana ekran varyanti. Eslesmeyen/eksik rol (unknown) icin GUVENLI
/// varsayilan gorevli duzenidir (brief: "eşleşmeyen/eksik rol → görevli").
HomeVaryant homeVaryantForRole(UserRole role) => switch (role) {
      UserRole.resident => HomeVaryant.sakin,
      // Platform admini yonetim duzenini gorur (brief: admin→yönetici).
      UserRole.admin || UserRole.yonetici => HomeVaryant.yonetici,
      UserRole.security || UserRole.tesisGorevlisi => HomeVaryant.gorevli,
      UserRole.unknown => HomeVaryant.gorevli,
    };
