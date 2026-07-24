/// Vardiya modelleri — GET /shifts (/contracts/openapi.yaml).
/// RBAC: GET admin + yonetici + security + tesis_gorevlisi (yonetici okuma
/// auth.md §4 genislemesiyle eklendi — panel "Vardiya Durumu" bolumu).
/// Yazma (POST/PATCH/DELETE) yalniz admin — mobil salt okur.
library;

/// Vardiyaya atanan personel (WP-E) — GET /shifts personel[] elemani.
class ShiftPersonel {
  const ShiftPersonel({required this.userId, required this.ad, this.avatarUrl});

  final String userId;
  final String ad;
  final String? avatarUrl;

  factory ShiftPersonel.fromJson(Map<String, dynamic> json) => ShiftPersonel(
        userId: json['user_id'] as String? ?? '',
        ad: json['ad'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
      );
}

/// Tek vardiya tanimi (ShiftOut). Saatler "HH:MM" metni (sunucu boyle doner).
class Shift {
  const Shift({
    required this.id,
    required this.ad,
    required this.baslangicSaat,
    required this.bitisSaat,
    this.gunTipi,
    this.personel = const [],
  });

  final String id;
  final String ad;
  final String baslangicSaat;
  final String bitisSaat;

  /// her_gun | hafta_ici | hafta_sonu | resmi_tatil | null (kisitsiz).
  final String? gunTipi;

  /// Atanan saha personeli (WP-E) — eski sunucu alani vermezse bos liste.
  final List<ShiftPersonel> personel;

  factory Shift.fromJson(Map<String, dynamic> json) => Shift(
        id: json['id'] as String? ?? '',
        ad: json['ad'] as String? ?? '',
        baslangicSaat: json['baslangic_saat'] as String? ?? '',
        bitisSaat: json['bitis_saat'] as String? ?? '',
        gunTipi: json['gun_tipi'] as String?,
        personel: [
          for (final p in (json['personel'] as List?) ?? const [])
            if (p is Map) ShiftPersonel.fromJson(Map<String, dynamic>.from(p)),
        ],
      );

  /// [now] su an bu vardiyanin saat araliginda mi? SAF hesap — `now` DISARIDAN
  /// verilir (testler deterministik; saat-flake yok). baslangic dahil, bitis
  /// haric. baslangic > bitis gece sarkmasidir (or. 22:00-06:00). Bozuk saat
  /// metni aktif SAYILMAZ (yanlis "AKTİF" rozeti yakmamak icin).
  bool aktifMi(DateTime now) {
    final bas = _dakika(baslangicSaat);
    final bit = _dakika(bitisSaat);
    if (bas == null || bit == null) return false;
    final simdi = now.hour * 60 + now.minute;
    if (bas < bit) return simdi >= bas && simdi < bit;
    if (bas > bit) return simdi >= bas || simdi < bit; // gece sarkmasi
    return false; // bas == bit: bos aralik
  }

  static int? _dakika(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }
}

/// gun_tipi TR etiketi; null kisitsizdir → "Her gün".
String gunTipiLabel(String? gunTipi) => switch (gunTipi) {
      'hafta_ici' => 'Hafta içi',
      'hafta_sonu' => 'Hafta sonu',
      'resmi_tatil' => 'Resmî tatil',
      'her_gun' || null => 'Her gün',
      final diger => diger,
    };
