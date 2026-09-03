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
    this.secimJetonu,
    this.tesisler = const [],
  });

  /// `giris` | `baglama_gerekli` | `tesis_secimi` | `kayit`
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

  /// (P211 §1) COK TESISLI YONETICI: hangi tesise girecegi SORULUR.
  /// Jeton TEK KULLANIMLIK ve hicbir tesise yetki VERMEZ; yalnizca
  /// "bu dogrulanmis adres su tesislerde yonetici" bilgisini tasir.
  final String? secimJetonu;
  final List<OauthTesisSecenegi> tesisler;

  bool get girisYapildi => durum == 'giris' && jetonlar != null;

  /// Tesis secimi gerekiyor mu (jeton VE liste dolu olmali — birinin
  /// eksikligi secim ekranini bos cizmek olurdu).
  bool get tesisSecimiGerekli =>
      durum == 'tesis_secimi' && secimJetonu != null && tesisler.isNotEmpty;

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
      secimJetonu: json['secim_jetonu'] as String?,
      tesisler: ((json['tesisler'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => OauthTesisSecenegi.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

/// (P211 §1) SSO secim ekranindaki tek tesis.
class OauthTesisSecenegi {
  const OauthTesisSecenegi({
    required this.tenantId,
    required this.ad,
    required this.slug,
  });

  final String tenantId;
  final String ad;
  final String slug;

  factory OauthTesisSecenegi.fromJson(Map<String, dynamic> j) =>
      OauthTesisSecenegi(
        tenantId: j['tenant_id'] as String,
        ad: (j['ad'] as String?) ?? '',
        slug: (j['slug'] as String?) ?? '',
      );
}
