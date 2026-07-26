/// `GET /parking/occupancy` — otopark dolulugu (agregat, tum kimlikli roller).
///
/// `dolu` ACIK arac gecisi sayimidir (ayri sayac yok) ve HER ZAMAN gercektir.
/// `kapasite` tenant ayari (`otopark_kapasite`); TANIMSIZ/0 ise sunucu `oran`i
/// da null doner — istemci UYDURMA YUZDE URETMEZ (kart '—' gosterir).
library;

class ParkingOccupancy {
  const ParkingOccupancy({required this.dolu, this.kapasite, this.oran});

  /// Su an iceride olan arac sayisi (acik gecis).
  final int dolu;

  /// Tenant ayari; null = tanimsiz.
  final int? kapasite;

  /// Yuzde (0-100); kapasite null/0 ise null.
  final int? oran;

  factory ParkingOccupancy.fromJson(Map<String, dynamic> json) =>
      ParkingOccupancy(
        dolu: (json['dolu'] as num?)?.toInt() ?? 0,
        kapasite: (json['kapasite'] as num?)?.toInt(),
        oran: (json['oran'] as num?)?.toInt(),
      );

  // GORUNUM METNI YOK (i18n): "3 / 120" ve "%2" gibi metinler ekran
  // katmaninda aktif dilden uretilir (l10n.otoparkDoluKapasite / yuzdeDeger);
  // domain katmani dil bilmez — CameraUrlHatasi ile ayni ilke.
}
