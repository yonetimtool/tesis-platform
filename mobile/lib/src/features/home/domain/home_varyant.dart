/// Ana ekran VARYANTI — referans gorsellerin uc duzeni. Rol → varyant esleme
/// TEK yerde; ekran secimi (HomeGate) ve mock veri secimi ayni fonksiyonu
/// kullanir.
library;

import '../../auth/domain/user_role.dart';

/// Referans duzenler. gorevli.jpeg iki role hizmet eder ve KART SETI
/// farklidir (KVKK: tesis gorevlisi ziyaretci/kargo/plaka/ihlal GORMEZ), bu
/// yuzden ayri varyant: duzen ayni (4'lu izgara), icerik farkli.
enum HomeVaryant {
  /// Guvenlik: 4'lu izgara (8 kart) + vardiya + son hareketler + kamera.
  gorevli,

  /// Tesis gorevlisi: 4'lu izgara (kendi is kartlari) + vardiya + hareketler
  /// + kamera (sunucu yalniz sakine acik kameralari doner).
  tesisGorevlisi,

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
      UserRole.security => HomeVaryant.gorevli,
      // (P35) Amirin isi GUVENLIK OPERASYONUDUR: yonetici duzenine (finans
      // ozeti, odeme) koymak, dis sirket personeline site yonetimi ekrani
      // vermek olurdu. Gorevli duzeni + amir menusu dogru esleme.
      UserRole.guvenlikAmiri => HomeVaryant.gorevli,
      UserRole.tesisGorevlisi => HomeVaryant.tesisGorevlisi,
      UserRole.unknown => HomeVaryant.gorevli,
    };
