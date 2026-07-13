/// Rol-bazli arama hedefi (C1a) — `contracts/openapi.yaml` CallTarget aynasi.
/// Numara YALNIZ /call-target yaniti dondugunde (yetki+riza kapisi gecince)
/// gelir; istemci onu ekranda GOSTERMEZ, dogrudan tel: ile ceviriciye verir.
library;

class CallTarget {
  const CallTarget({
    required this.userId,
    required this.ad,
    required this.role,
    required this.channel,
    required this.telefon,
    required this.telUri,
  });

  final String userId;
  final String ad;
  final String role;

  /// Kanal — C1a hep 'phone'; C1b baska kanallar ekleyecek.
  final String channel;
  final String telefon;

  /// Cihaz ceviricisi icin hazir 'tel:' URI.
  final String telUri;

  factory CallTarget.fromJson(Map<String, dynamic> json) => CallTarget(
        userId: json['user_id'] as String? ?? '',
        ad: json['ad'] as String? ?? '',
        role: json['role'] as String? ?? '',
        channel: json['channel'] as String? ?? 'phone',
        telefon: json['telefon'] as String? ?? '',
        telUri: json['tel_uri'] as String? ?? '',
      );
}
