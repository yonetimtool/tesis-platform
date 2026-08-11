import 'token_pair.dart';

/// (P154 / Asama 4) `POST /auth/oauth/sonuc` yaniti.
///
/// IKI DURUM TEK MODELDE: cagiran `durum`a bakar. Iki ayri model, arayuzde
/// iki ayri hata yolu demekti.
class OauthSonuc {
  const OauthSonuc({
    required this.durum,
    this.jetonlar,
    this.saglayici,
    this.eposta,
    this.relay = false,
    this.baglamaJetonu,
  });

  /// `giris` | `baglama_gerekli`
  final String durum;
  final TokenPair? jetonlar;
  final String? saglayici;

  /// YALNIZ GORUNTULEME — eslesmede kullanilmaz (goc 0048).
  final String? eposta;

  /// Apple "e-postami gizle" dediyse true. Kullaniciya SOYLENIR: o adrese
  /// posta gonderilemeyecegini bilmeli.
  final bool relay;
  final String? baglamaJetonu;

  bool get girisYapildi => durum == 'giris' && jetonlar != null;

  factory OauthSonuc.fromJson(Map<String, dynamic> json) {
    final j = json['jetonlar'];
    return OauthSonuc(
      durum: json['durum'] as String? ?? '',
      jetonlar: j is Map<String, dynamic> ? TokenPair.fromJson(j) : null,
      saglayici: json['saglayici'] as String?,
      eposta: json['eposta'] as String?,
      relay: json['relay'] as bool? ?? false,
      baglamaJetonu: json['baglama_jetonu'] as String?,
    );
  }
}
