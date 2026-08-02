import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    kurTeshisKanali(engineBridge.pluginRegistry)
  }

  /// (P119) TESHIS KANALI — "kaynakta ne yaziyor" degil, PAKETTE ne var.
  ///
  /// NEDEN: `Info.plist`in DEPODA dogru olmasi, o anahtarin yapiya
  /// GIRDIGINI kanitlamaz (yanlis `INFOPLIST_FILE`, `GENERATE_INFOPLIST_FILE`,
  /// hedef karismasi, eski bir TestFlight yapimi...). Iki iOS hatasi
  /// (kamera ATS, NFC yetkilendirme) tam bu belirsizlikte iki tur
  /// KORLEMESINE dolasti. Burasi CALISAN paketin kendi sozlugunu okur.
  ///
  /// YENI CERCEVE EKLENMEDI: yalniz `Bundle.main`. `CoreNFC` ya da
  /// `Security` (SecTask) ithal etmek, Mac'siz duzenlenen bir projede
  /// derlemeyi riske atardi; imza tarafini Kerem zaten `codesign` ile
  /// olcebiliyor — olcemedigi sey `Info.plist`ti.
  private func kurTeshisKanali(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "YonetioTeshis") else { return }
    let kanal = FlutterMethodChannel(
      name: "site.yonetio.app/teshis",
      binaryMessenger: registrar.messenger()
    )
    kanal.setMethodCallHandler { cagri, sonuc in
      guard cagri.method == "paketGercekleri" else {
        sonuc(FlutterMethodNotImplemented)
        return
      }
      sonuc(AppDelegate.paketGercekleri())
    }
  }

  private static func paketGercekleri() -> [String: Any] {
    let info = Bundle.main.infoDictionary ?? [:]
    let ats = info["NSAppTransportSecurity"] as? [String: Any]
    var cikti: [String: Any] = [:]
    // `nil` degerler SOZLUGE KONMAZ: Dart tarafi eksik anahtari "YOK" diye
    // yazar. `NSNull` gondermek ayni bilgiyi tasir ama iki farkli "yok"
    // hali uretirdi.
    func koy(_ anahtar: String, _ deger: Any?) {
      if let deger = deger { cikti[anahtar] = deger }
    }
    koy("paket", Bundle.main.bundleIdentifier)
    koy("surum", info["CFBundleShortVersionString"])
    koy("yapim", info["CFBundleVersion"])
    koy("atsVar", ats != nil)
    koy("atsMedya", ats?["NSAllowsArbitraryLoadsForMedia"])
    koy("atsKeyfi", ats?["NSAllowsArbitraryLoads"])
    koy("nfcAciklama", info["NFCReaderUsageDescription"] != nil)
    koy("nfcAid", info["com.apple.developer.nfc.readersession.iso7816.select-identifiers"])
    koy("nfcFelica", info["com.apple.developer.nfc.readersession.felica.systemcodes"])
    return cikti
  }
}
