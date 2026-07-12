/// Gorev kategorisi domain modeli (A6) — `contracts/openapi.yaml`
/// TaskCategory semasinin istemci aynasi. Yonetici-tanimli, tenant'a ozel;
/// DELETE soft-delete'tir (aktif=false), pasif kategoriye yeni gorev yazilamaz.
library;

class TaskCategory {
  const TaskCategory({
    required this.id,
    required this.ad,
    required this.aktif,
  });

  factory TaskCategory.fromJson(Map<String, dynamic> json) => TaskCategory(
        id: (json['id'] as String?) ?? '',
        ad: (json['ad'] as String?) ?? '',
        aktif: (json['aktif'] as bool?) ?? true,
      );

  final String id;
  final String ad;
  final bool aktif;
}
