import Flutter
import UIKit
import UserNotifications

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
    kurRozetKanali(engineBridge.pluginRegistry)
  }

  /// (P247 §5) UYGULAMA SIMGESI ROZETI — okunmamis bildirim sayisi.
  ///
  /// Sunucu push'ta `aps.badge` gonderir (bildirim geldiginde dogru sayi);
  /// uygulama acilip bildirimler okundukca sayi burada GERCEK degere
  /// cekilir — yoksa rozet bir sonraki push'a kadar eski sayida kalirdi.
  /// Yeni cerceve/pod YOK: yalniz UIKit + UserNotifications.
  private func kurRozetKanali(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "YonetioRozet") else { return }
    let kanal = FlutterMethodChannel(
      name: "site.yonetio.app/rozet",
      binaryMessenger: registrar.messenger()
    )
    kanal.setMethodCallHandler { cagri, sonuc in
      guard cagri.method == "ayarla", let sayi = cagri.arguments as? Int else {
        sonuc(FlutterMethodNotImplemented)
        return
      }
      if #available(iOS 16.0, *) {
        UNUserNotificationCenter.current().setBadgeCount(max(0, sayi)) { _ in }
      } else {
        UIApplication.shared.applicationIconBadgeNumber = max(0, sayi)
      }
      sonuc(nil)
    }
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
