/// Duyuru modulunun domain modelleri — `contracts/openapi.yaml`
/// Announcement / AnnouncementCreate / AnnouncementUpdate semalarina uyar.
///
/// RBAC (auth.md §4): OKUMA tum roller; olusturma/duzenleme/silme
/// admin + yonetici (yonetici panele girmedigi icin mobilden yonetir).
library;

class Announcement {
  const Announcement({
    required this.id,
    required this.baslik,
    required this.govde,
    required this.olusturanUserId,
    required this.createdAt,
    required this.updatedAt,
    this.olusturanAd,
  });

  final String id;
  final String baslik;
  final String govde;
  final String olusturanUserId;
  final String? olusturanAd;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Yayin sonrasi duzenlenmis mi ("duzenlendi" rozeti icin).
  bool get duzenlendi => updatedAt.isAfter(createdAt);

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: json['id'] as String? ?? '',
        baslik: json['baslik'] as String? ?? '',
        govde: json['govde'] as String? ?? '',
        olusturanUserId: json['olusturan_user_id'] as String? ?? '',
        olusturanAd: json['olusturan_ad'] as String?,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedAt:
            DateTime.tryParse(json['updated_at'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

/// `POST /announcements` (ve PATCH) govdesi. Sunucu siniri: baslik <= 200,
/// govde <= 5000 (bos deger 422) — form ayni sinirlari istemcide de uygular.
class AnnouncementDraft {
  const AnnouncementDraft({required this.baslik, required this.govde});

  final String baslik;
  final String govde;

  Map<String, dynamic> toJson() => {'baslik': baslik, 'govde': govde};
}
