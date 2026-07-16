/// Tesis (tenant) domain modelleri — `contracts/openapi.yaml` TenantSettings
/// semasina uyar.
library;

/// `GET /tenant/settings` yaniti. Mobil `ad`i ana ekran basliginda gosterir;
/// `kurulum_tamamlandi=false` ise BIRINCIL yonetici tesisi adlandirmalidir.
class TenantSettings {
  const TenantSettings({
    required this.tenantId,
    required this.ad,
    this.kurulumTamamlandi = true,
  });

  final String tenantId;
  final String ad;

  /// false ise BIRINCIL yonetici ILK GIRISTE tesisi adlandirmali (home gate).
  /// Eski/adlandirilmis tesislerde true.
  final bool kurulumTamamlandi;

  factory TenantSettings.fromJson(Map<String, dynamic> json) => TenantSettings(
        tenantId: json['tenant_id'] as String,
        ad: json['ad'] as String? ?? '',
        kurulumTamamlandi: json['kurulum_tamamlandi'] as bool? ?? true,
      );
}
