/// `GET /parking/occupancy` — otopark dolulugu (agregat, tum kimlikli roller).
///
/// `dolu` ACIK arac gecisi sayimidir (ayri sayac yok) ve HER ZAMAN gercektir.
/// `kapasite` tenant ayari (`otopark_kapasite`); TANIMSIZ/0 ise sunucu `oran`i
/// da null doner — istemci UYDURMA YUZDE URETMEZ (bkz. [oranMetni]).
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

  /// Kart sayaci: kapasite biliniyorsa "3 / 120", bilinmiyorsa "3 araç".
  /// Kapasite yoksa payda UYDURULMAZ.
  String get doluMetni => kapasite == null ? '$dolu araç' : '$dolu / $kapasite';

  /// "Hızlı Özet" kutusu: "%2"; kapasite tanimsizsa oran da yok → '—'.
  String get oranMetni => oran == null ? '—' : '%$oran';
}
