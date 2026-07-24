/// Platform destek bileti (WP1) — POST/GET /support (yonetici).
library;

class SupportTicket {
  const SupportTicket({
    required this.id,
    this.konu = '',
    this.aciklama = '',
    this.durum = 'acik',
    this.adminCevap,
    this.createdAt,
  });

  final String id;
  final String konu;
  final String aciklama;

  /// acik | cozuldu.
  final String durum;
  final String? adminCevap;
  final DateTime? createdAt;

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: json['id'] as String? ?? '',
        konu: json['konu'] as String? ?? '',
        aciklama: json['aciklama'] as String? ?? '',
        durum: json['durum'] as String? ?? 'acik',
        adminCevap: json['admin_cevap'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      );
}
