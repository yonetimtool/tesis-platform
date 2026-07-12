/// Rezervasyon modulunun domain modelleri — `contracts/openapi.yaml`
/// OrtakAlan / Rezervasyon / *Create / *Update semalarina uyar.
///
/// Akis (urun sahibi sabit): yonetici ortak alan tanimlar -> sakin slot
/// talep eder (alan + tarih + saat araligi + kisi) -> yonetici onaylar/
/// reddeder. CAKISMA ENGELI DB'de: ayni alanin ONAYLI iki rezervasyonu
/// kesisemez — es zamanli iki cakisan onaydan yalniz biri basarir (409).
/// RBAC (auth.md §4): alan yonetimi admin+yonetici; talep yalniz resident;
/// karar yalniz yonetim; okuma yonetim tumu / sakin kendi dairesi;
/// saha rolleri erisemez.
library;

/// `rezervasyon_durum` enum'unun istemci aynasi.
enum RezervasyonDurum {
  bekliyor('bekliyor', 'Bekliyor'),
  onaylandi('onaylandi', 'Onaylandı'),
  reddedildi('reddedildi', 'Reddedildi'),
  unknown('unknown', 'Bilinmeyen');

  const RezervasyonDurum(this.wire, this.label);

  /// Backend enum degeri.
  final String wire;

  /// TR gorunen ad.
  final String label;

  static RezervasyonDurum fromWire(String? value) =>
      RezervasyonDurum.values.firstWhere(
        (d) => d.wire == value,
        orElse: () => RezervasyonDurum.unknown,
      );
}

/// Rezerve edilebilir ortak alan (havuz/teras/toplanti odasi).
class OrtakAlan {
  const OrtakAlan({
    required this.id,
    required this.ad,
    required this.aktif,
    required this.createdAt,
    this.aciklama,
  });

  final String id;
  final String ad;
  final String? aciklama;

  /// false = kaldirilmis (soft-delete; rezerve edilemez — yalniz yonetim gorur).
  final bool aktif;

  final DateTime createdAt;

  factory OrtakAlan.fromJson(Map<String, dynamic> json) => OrtakAlan(
        id: json['id'] as String? ?? '',
        ad: json['ad'] as String? ?? '',
        aciklama: json['aciklama'] as String?,
        aktif: json['aktif'] as bool? ?? true,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

class Rezervasyon {
  const Rezervasyon({
    required this.id,
    required this.alanId,
    required this.unitId,
    required this.tarih,
    required this.baslangic,
    required this.bitis,
    required this.kisiSayisi,
    required this.durum,
    required this.talepEdenUserId,
    required this.createdAt,
    this.alanAd,
    this.unitNo,
    this.notlar,
    this.talepEdenAd,
    this.onaylayanUserId,
    this.onaylayanAd,
    this.kararZamani,
  });

  final String id;
  final String alanId;

  /// Alan adi (sunucu join ile doldurur).
  final String? alanAd;

  final String unitId;
  final String? unitNo;

  /// "YYYY-MM-DD".
  final String tarih;

  /// "HH:MM".
  final String baslangic;

  /// "HH:MM" — baslangictan sonra.
  final String bitis;

  final int kisiSayisi;
  final String? notlar;
  final RezervasyonDurum durum;

  final String talepEdenUserId;
  final String? talepEdenAd;

  /// Karari veren yonetici (karar verilmediyse null).
  final String? onaylayanUserId;
  final String? onaylayanAd;
  final DateTime? kararZamani;

  final DateTime createdAt;

  bool get bekliyor => durum == RezervasyonDurum.bekliyor;

  factory Rezervasyon.fromJson(Map<String, dynamic> json) => Rezervasyon(
        id: json['id'] as String? ?? '',
        alanId: json['alan_id'] as String? ?? '',
        alanAd: json['alan_ad'] as String?,
        unitId: json['unit_id'] as String? ?? '',
        unitNo: json['unit_no'] as String?,
        tarih: json['tarih'] as String? ?? '',
        baslangic: json['baslangic'] as String? ?? '',
        bitis: json['bitis'] as String? ?? '',
        kisiSayisi: (json['kisi_sayisi'] as num?)?.toInt() ?? 0,
        notlar: json['notlar'] as String?,
        durum: RezervasyonDurum.fromWire(json['durum'] as String?),
        talepEdenUserId: json['talep_eden_user_id'] as String? ?? '',
        talepEdenAd: json['talep_eden_ad'] as String?,
        onaylayanUserId: json['onaylayan_user_id'] as String?,
        onaylayanAd: json['onaylayan_ad'] as String?,
        kararZamani: json['karar_zamani'] == null
            ? null
            : DateTime.tryParse(json['karar_zamani'] as String? ?? ''),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

/// `POST /reservations` govdesi (yalniz sakin). Daire sunucuda kimlikten
/// turetilir (coklu dairede unitId ile secim yapilabilir).
class RezervasyonDraft {
  const RezervasyonDraft({
    required this.alanId,
    required this.tarih,
    required this.baslangic,
    required this.bitis,
    required this.kisiSayisi,
    this.notlar,
  });

  final String alanId;

  /// "YYYY-MM-DD".
  final String tarih;

  /// "HH:MM".
  final String baslangic;
  final String bitis;
  final int kisiSayisi;

  /// Opsiyonel not; bos/null ise JSON'a HIC yazilmaz (sunucu minLength 1).
  final String? notlar;

  Map<String, dynamic> toJson() => {
        'alan_id': alanId,
        'tarih': tarih,
        'baslangic': baslangic,
        'bitis': bitis,
        'kisi_sayisi': kisiSayisi,
        if (notlar != null && notlar!.isNotEmpty) 'notlar': notlar,
      };
}

/// `POST /common-areas` / `PATCH /common-areas/{id}` govdesi (yonetim).
class OrtakAlanDraft {
  const OrtakAlanDraft({required this.ad, this.aciklama, this.aktif});

  final String ad;
  final String? aciklama;

  /// Yalniz PATCH'te anlamli (soft-delete/aktive); null ise gonderilmez.
  final bool? aktif;

  Map<String, dynamic> toJson() => {
        'ad': ad,
        if (aciklama != null && aciklama!.isNotEmpty) 'aciklama': aciklama,
        if (aktif != null) 'aktif': aktif,
      };
}
