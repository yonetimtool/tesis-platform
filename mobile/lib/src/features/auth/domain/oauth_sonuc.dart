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
    this.ad,
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

  /// (P155r2 §2) Saglayicinin bildirdigi ad soyad — kayit formunu
  /// ON-DOLDURMAK icin; kullanici duzeltebilir. Apple'da BOS gelir
  /// (adi `id_token`da vermez) ve bu akisi kirmaz.
  ///
  /// TELEFON YOK: hicbir saglayici `id_token`da telefon vermiyor;
  /// sartname de bunu varsayiyor. Telefon alani bos acilir.
  final String? ad;
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
      ad: json['ad'] as String?,
      baglamaJetonu: json['baglama_jetonu'] as String?,
    );
  }
}
