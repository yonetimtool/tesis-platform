/// "Aidatim" domain modelleri — `GET /me/dues` (MeDuesResponse /
/// UnitDuesStatus / DuesAssessmentOut / DuesPaymentOut semalari).
///
/// RBAC (auth.md §4): uc YALNIZ resident'a aciktir; sakin yalniz KENDI
/// dairelerinin borcunu gorur (baska daire sizamaz — sunucu suzer).
/// Odeme yapilamaz; odeme durumu yalnizca webhook/saglayicidan degisir.
library;

class DuesAssessment {
  const DuesAssessment({
    required this.donem,
    required this.tutarKurus,
    this.sonOdemeTarihi,
    this.aciklama,
  });

  final String donem;
  final int tutarKurus;
  final DateTime? sonOdemeTarihi;
  final String? aciklama;

  factory DuesAssessment.fromJson(Map<String, dynamic> json) =>
      DuesAssessment(
        donem: json['donem'] as String? ?? '',
        tutarKurus: (json['tutar_kurus'] as num?)?.toInt() ?? 0,
        sonOdemeTarihi: json['son_odeme_tarihi'] == null
            ? null
            : DateTime.tryParse(json['son_odeme_tarihi'] as String),
        aciklama: json['aciklama'] as String?,
      );
}

class DuesPayment {
  const DuesPayment({
    required this.tutarKurus,
    required this.odemeZamani,
    required this.yontem,
    required this.durum,
    this.donem,
    this.makbuzNo,
  });

  final int tutarKurus;
  final DateTime odemeZamani;
  final String yontem;

  /// basarili | bekliyor | iptal — yalniz 'basarili' bakiyeden duser
  /// (hesap SUNUCUDA; istemci yeniden hesaplamaz).
  final String durum;
  final String? donem;
  final String? makbuzNo;

  factory DuesPayment.fromJson(Map<String, dynamic> json) => DuesPayment(
        tutarKurus: (json['tutar_kurus'] as num?)?.toInt() ?? 0,
        odemeZamani:
            DateTime.tryParse(json['odeme_zamani'] as String? ?? '')?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        yontem: json['yontem'] as String? ?? '',
        durum: json['durum'] as String? ?? '',
        donem: json['donem'] as String?,
        makbuzNo: json['makbuz_no'] as String?,
      );
}

/// Sakinin bir dairesinin borc durumu (`UnitDuesStatus`).
class MyDuesUnit {
  const MyDuesUnit({
    required this.unitId,
    required this.no,
    required this.tahakkukKurus,
    required this.odenenKurus,
    required this.bakiyeKurus,
    this.assessments = const [],
    this.payments = const [],
  });

  final String unitId;
  final String no;

  /// Toplamlar SUNUCU hesabi (bakiye = tahakkuk - basarili odemeler).
  final int tahakkukKurus;
  final int odenenKurus;
  final int bakiyeKurus;

  final List<DuesAssessment> assessments;
  final List<DuesPayment> payments;

  bool get borcVar => bakiyeKurus > 0;

  factory MyDuesUnit.fromJson(Map<String, dynamic> json) => MyDuesUnit(
        unitId: json['unit_id'] as String? ?? '',
        no: json['no'] as String? ?? '',
        tahakkukKurus: (json['toplam_tahakkuk_kurus'] as num?)?.toInt() ?? 0,
        odenenKurus: (json['toplam_odenen_kurus'] as num?)?.toInt() ?? 0,
        bakiyeKurus: (json['bakiye_kurus'] as num?)?.toInt() ?? 0,
        assessments: [
          for (final item
              in json['assessments'] is List ? json['assessments'] as List : const [])
            if (item is Map)
              DuesAssessment.fromJson(Map<String, dynamic>.from(item)),
        ],
        payments: [
          for (final item
              in json['payments'] is List ? json['payments'] as List : const [])
            if (item is Map)
              DuesPayment.fromJson(Map<String, dynamic>.from(item)),
        ],
      );
}

/// Odeme yontemi / durumu TR etiketleri (sozlesme enum'lari).
String yontemLabel(String yontem) => switch (yontem) {
      'elden' => 'Elden',
      'havale' => 'Havale/EFT',
      'kart' => 'Kart',
      'diger' => 'Diğer',
      _ => yontem,
    };

String durumLabel(String durum) => switch (durum) {
      'basarili' => 'Başarılı',
      'bekliyor' => 'Bekliyor',
      'iptal' => 'İptal',
      _ => durum,
    };
