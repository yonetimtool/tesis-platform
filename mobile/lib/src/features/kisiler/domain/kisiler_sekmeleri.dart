/// (P251 §8) KISILER — TEK GIRIS, SEKMELER (web `/kisiler` ile ayni).
///
/// Rol basina sekmeler:
///   * yonetici, admin: Sakinler · Personel · Yoneticiler ve denetciler ·
///     Davetler
///   * guvenlik amiri: YALNIZ Personel (ve sunucu P231 suzgeciyle yalniz
///     guvenlik personeli)
///   * digerleri: hic (menude Kisiler girisi de yok)
library;

import '../../auth/domain/user_role.dart';

enum KisilerSekmesi { sakinler, personel, yoneticiler, davetler }

List<KisilerSekmesi> kisilerSekmeleri(UserRole rol) => switch (rol) {
      UserRole.yonetici || UserRole.admin => KisilerSekmesi.values,
      UserRole.guvenlikAmiri => const [KisilerSekmesi.personel],
      _ => const [],
    };

/// Adresten (`?sekme=personel`) gelen ad -> sekme; tanimsizsa null.
KisilerSekmesi? kisilerSekmesiCoz(String? ad) {
  for (final s in KisilerSekmesi.values) {
    if (s.name == ad) return s;
  }
  return null;
}
