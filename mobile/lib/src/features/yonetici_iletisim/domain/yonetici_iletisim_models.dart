/// Yonetici iletisim dizini — `GET /yonetici-iletisim`.
library;

class YoneticiKart {
  const YoneticiKart({
    required this.userId,
    required this.adSoyad,
    this.telefon,
  });

  final String userId;
  final String adSoyad;

  /// Numara sunucudan ACIKCA doner (auth.md gizlilik istisnasi: yonetici
  /// hizmet rolüdür). C1a'daki gibi gizlenmez — kartta gosterilir.
  final String? telefon;

  factory YoneticiKart.fromJson(Map<String, dynamic> json) => YoneticiKart(
        userId: json['user_id'] as String,
        adSoyad: json['ad_soyad'] as String,
        telefon: json['telefon'] as String?,
      );
}

class YoneticiIletisim {
  const YoneticiIletisim({required this.yoneticiler, this.yonetimEmail});

  final List<YoneticiKart> yoneticiler;
  final String? yonetimEmail;

  factory YoneticiIletisim.fromJson(Map<String, dynamic> json) =>
      YoneticiIletisim(
        yoneticiler: ((json['yoneticiler'] as List<dynamic>?) ?? const [])
            .map((e) => YoneticiKart.fromJson(e as Map<String, dynamic>))
            .toList(),
        yonetimEmail: json['yonetim_email'] as String?,
      );
}
