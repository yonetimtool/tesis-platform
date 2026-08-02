/// Uygulama geneli yapilandirma (derleme zamani).
///
/// API base URL'i derleme zamani `--dart-define` ile gecilir; boylece
/// mock / yerel backend / canli ayrimi tek bir kaynaktan, kod degismeden
/// yonetilir. Sondaki `/` olmadan verin.
///
/// Varsayilan, **Android emulatorden yerel (docker compose) backend'e** erisim
/// icindir: emulator host makineyi `10.0.2.2` uzerinden gorur (bkz. README §3).
/// Gercek backend, OpenAPI `servers`'taki `/v0`'in aksine kok altinda
/// (`/auth/login`) sunuldugu icin base URL'de `/v0` YOKTUR.
///
/// Ornekler (detay: /mobile/README.md §3):
///   * Yerel backend (emulator):  `--dart-define=API_BASE_URL=http://10.0.2.2:8000`
///   * Yerel backend (cihaz/Wi-Fi): `--dart-define=API_BASE_URL=http://192.168.1.20:8000`
///   * Mock (Prism, emulator):     `--dart-define=API_BASE_URL=http://10.0.2.2:4010`
///   * Canli / uzak sunucu:        `--dart-define=API_BASE_URL=https://api.example.com`
class AppConfig {
  const AppConfig._();

  /// REST API kok adresi. Sondaki `/` olmadan verilmelidir.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// (P113) Hukuki belgelerin yayinlandigi PUBLIC web kokü.
  ///
  /// NEDEN `apiBaseUrl`DAN AYRI: gizlilik politikasi ve kosullar API'de
  /// degil PANELIN public rotalarinda yayinlaniyor (`/gizlilik`,
  /// `/kosullar`) ve prod'da bunlar AYRI alt alanlardir
  /// (`api.yonetio.site` vs `yonetio.site`). API kokunu kullanmak,
  /// belgeyi acmaya calisan kullaniciyi 404'e goturur.
  ///
  /// Adresler SABITTIR: App Store Connect ve Google Play'e girilen URL'ler
  /// bunlar; degismemeleri gerekir.
  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://yonetio.site',
  );

  static String get gizlilikUrl => '$webBaseUrl/gizlilik';
  static String get kosullarUrl => '$webBaseUrl/kosullar';
}
