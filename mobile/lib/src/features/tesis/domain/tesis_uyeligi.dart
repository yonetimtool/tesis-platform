/// (P203 §2) Bir kisinin TEK bir tesisteki uyeligi.
library;

class TesisUyeligi {
  const TesisUyeligi({
    required this.tenantId,
    required this.slug,
    required this.ad,
    required this.rol,
  });

  final String tenantId;
  final String slug;
  final String ad;

  /// BU TESISTEKI rol. Ayni kisi bir tesiste yonetici, otekinde sakin
  /// olabilir — rol UYELIGE aittir, kisiye degil.
  final String rol;

  factory TesisUyeligi.fromJson(Map<String, dynamic> j) => TesisUyeligi(
        tenantId: j['tenant_id'] as String,
        slug: (j['slug'] as String?) ?? '',
        ad: (j['ad'] as String?) ?? '',
        rol: (j['rol'] as String?) ?? '',
      );
}
