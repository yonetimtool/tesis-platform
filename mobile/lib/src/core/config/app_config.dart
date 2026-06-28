/// Uygulama geneli yapilandirma (derleme zamani).
///
/// `API_BASE_URL` derleme zamani `--dart-define` ile gecilir; boylece dev/prod
/// (mock vs gercek backend) ayrimi tek bir kaynaktan yonetilir. Varsayilan
/// deger Android EMULATOR'undan Prism mock'una erisim icindir (host = 10.0.2.2).
///
/// Ornekler (detay: /mobile/README.md):
///   * Mock (Prism, emulator):  `--dart-define=API_BASE_URL=http://10.0.2.2:4010`
///   * Mock (gercek cihaz, USB): `--dart-define=API_BASE_URL=http://PC-LAN-IP:4010`
///   * Gercek backend (local):   `--dart-define=API_BASE_URL=http://10.0.2.2:8000/v0`
class AppConfig {
  const AppConfig._();

  /// REST API kok adresi. Sondaki `/` olmadan verilmelidir.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:4010',
  );
}
