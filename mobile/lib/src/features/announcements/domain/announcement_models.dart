/// Duyuru modulunun domain modelleri — `contracts/openapi.yaml`
/// Announcement / AnnouncementCreate / AnnouncementUpdate semalarina uyar.
///
/// RBAC (auth.md §4): OKUMA tum roller; olusturma/duzenleme/silme
/// admin + yonetici (yonetici panele girmedigi icin mobilden yonetir).
library;

import '../../../core/i18n/icerik_ceviri.dart';

class Announcement {
  const Announcement({
    required this.id,
    required this.baslik,
    required this.govde,
    required this.olusturanUserId,
    required this.createdAt,
    required this.updatedAt,
    this.olusturanAd,
    this.fotoKey,
    this.fotoUrl,
    this.ceviri,
    this.hedefRoller = const [],
    this.hedefSakinTipi,
    this.hedefBloklar = const [],
  });

  final String id;
  final String baslik;
  final String govde;
  final String olusturanUserId;
  final String? olusturanAd;

  /// Opsiyonel gorsel — MinIO obje anahtari (varligi "foto var" demektir).
  final String? fotoKey;

  /// Goruntuleme icin kisa omurlu presigned GET URL (sunucu okumada uretir).
  final String? fotoUrl;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Ceviri ustverisi (`CeviriAlanlari`). Sunucu gondermezse null — ekran
  /// hicbir not gostermez.
  final IcerikCeviri? ceviri;

  /// (E2E 2026-09, BILDIRIM-12) HEDEF KITLE — bos = herkes. Sakin tipi ve
  /// blok yalniz sakinlere uygulanir. Sunucu hedef disindaki kullaniciya
  /// duyuruyu HIC dondurmez; bu alanlar yonetimin "kime gitti" rozeti icin.
  final List<String> hedefRoller;
  final String? hedefSakinTipi;
  final List<String> hedefBloklar;

  /// Hedefli mi (en az bir suzgec var mi)?
  bool get hedefli =>
      hedefRoller.isNotEmpty || hedefSakinTipi != null || hedefBloklar.isNotEmpty;

  /// Yayin sonrasi duzenlenmis mi ("duzenlendi" rozeti icin).
  bool get duzenlendi => updatedAt.isAfter(createdAt);

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: json['id'] as String? ?? '',
    baslik: json['baslik'] as String? ?? '',
    govde: json['govde'] as String? ?? '',
    olusturanUserId: json['olusturan_user_id'] as String? ?? '',
    olusturanAd: json['olusturan_ad'] as String?,
    fotoKey: json['foto_key'] as String?,
    fotoUrl: json['foto_url'] as String?,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updatedAt:
        DateTime.tryParse(json['updated_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    ceviri: IcerikCeviri.fromJson(json),
    hedefRoller: _metinListesi(json['hedef_roller']),
    hedefSakinTipi: json['hedef_sakin_tipi'] as String?,
    hedefBloklar: _metinListesi(json['hedef_bloklar']),
  );
}

List<String> _metinListesi(Object? ham) => ham is List
    ? ham.whereType<String>().toList(growable: false)
    : const [];

/// `POST /announcements` (ve PATCH) govdesi. Sunucu siniri: baslik <= 200,
/// govde <= 5000 (bos deger 422) — form ayni sinirlari istemcide de uygular.
/// [fotoKey] opsiyonel gorsel; null ise JSON'a HIC yazilmaz (PATCH'te mevcut
/// gorsel korunur — sunucu yalniz gonderilen alanlara dokunur).
///
/// (E2E 2026-09, BILDIRIM-12) [hedef] YALNIZ OLUSTURMADA verilir; null ise
/// hedef alanlari JSON'a yazilmaz (duzenlemede hedef DEGISTIRILEMEZ —
/// sunucu PATCH'te tasimaz).
class AnnouncementDraft {
  const AnnouncementDraft({
    required this.baslik,
    required this.govde,
    this.fotoKey,
    this.hedef,
  });

  final String baslik;
  final String govde;
  final String? fotoKey;
  final DuyuruHedef? hedef;

  Map<String, dynamic> toJson() => {
    'baslik': baslik,
    'govde': govde,
    if (fotoKey != null) 'foto_key': fotoKey,
    ...?hedef?.toJson(),
  };
}

/// (E2E 2026-09, BILDIRIM-12) Duyurunun hedef kitlesi — anketteki desen
/// (`ANKET_HEDEF_ROLLER`, malik/kiraci) + BLOK. Bos = herkes.
///
/// SAKIN SUZGECI ANLAMSIZSA TEMIZLENIR: roller secilmis ve `resident`
/// aralarinda degilse sakin tipi ve blok GOVDEYE GIRMEZ — gizlenmis bir
/// suzgecin sessizce uygulanmasi anket formunda olculmus bir kusurdu.
class DuyuruHedef {
  const DuyuruHedef({
    this.roller = const [],
    this.sakinTipi,
    this.bloklar = const [],
  });

  final List<String> roller;
  final String? sakinTipi;
  final List<String> bloklar;

  static bool sakinSuzgeciAnlamli(Iterable<String> roller) =>
      roller.isEmpty || roller.contains('resident');

  Map<String, dynamic> toJson() {
    final sakinli = sakinSuzgeciAnlamli(roller);
    return {
      'hedef_roller': roller,
      'hedef_sakin_tipi': sakinli ? sakinTipi : null,
      'hedef_bloklar': sakinli ? bloklar : const <String>[],
    };
  }
}
