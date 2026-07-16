/// Self-servis profil modeli — `GET /me/profile` / `PATCH /me/contact`
/// yanitinin istemci aynasi (contracts: MeProfileOut). password_hash tasimaz.
class Profile {
  const Profile({
    required this.ad,
    this.email,
    required this.role,
    this.telefon,
    required this.aranabilir,
    this.birincil = false,
  });

  final String ad;
  final String? email;
  final String role;
  final String? telefon;
  final bool aranabilir;

  /// Tenant'in birincil yoneticisi mi? Tesisi ilk giriste adlandirma kapisi
  /// yalniz buna acilir (yonetici disi rollerde daima false).
  final bool birincil;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        ad: json['ad'] as String,
        email: json['email'] as String?,
        role: json['role'] as String,
        telefon: json['telefon'] as String?,
        aranabilir: (json['aranabilir'] as bool?) ?? false,
        birincil: json['birincil'] as bool? ?? false,
      );
}
