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
    kurAlarmKanali(engineBridge.pluginRegistry)
  }

  /// (P249 §1c) SOS ALARM KOPRUSU — Android'deki `site.yonetio.app/alarm`
  /// ile AYNI ad ve yontemler. iOS'ta ses bildirimle bir kez calar (30 sn
  /// sinir, dongu YOK); "Gordum"/"Guvendeyim" denince o alarmin teslim
  /// edilmis bildirimleri merkezden KALDIRILIR.
  ///
  /// iOS'ta tam ekran yoktur (CallKit disinda) ve Rahatsiz Etmeyin'i yalniz
  /// Critical Alerts deler — `izinDurumu` bunu Dart'a olduğu gibi bildirir.
  private func kurAlarmKanali(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "YonetioAlarm") else { return }
    let kanal = FlutterMethodChannel(
      name: "site.yonetio.app/alarm",
      binaryMessenger: registrar.messenger()
    )
    kanal.setMethodCallHandler { cagri, sonuc in
      switch cagri.method {
      case "sustur":
        let argumanlar = cagri.arguments as? [String: Any]
        guard let panikId = argumanlar?["panikId"] as? String, !panikId.isEmpty else {
          sonuc(nil)
          return
        }
        let merkez = UNUserNotificationCenter.current()
        merkez.getDeliveredNotifications { teslimler in
          let kimlikler = teslimler
            .filter { ($0.request.content.userInfo["panik_id"] as? String) == panikId }
            .map { $0.request.identifier }
          merkez.removeDeliveredNotifications(withIdentifiers: kimlikler)
          DispatchQueue.main.async { sonuc(nil) }
        }
      case "acilisAlarmi":
        // iOS'ta dokunus FCM `getInitialMessage` ile gelir; ayri iz yok.
        sonuc(nil)
      case "izinDurumu":
        UNUserNotificationCenter.current().getNotificationSettings { ayar in
          var kritik = false
          if #available(iOS 12.0, *) {
            kritik = ayar.criticalAlertSetting == .enabled
          }
          var zamanHassas = false
          if #available(iOS 15.0, *) {
            zamanHassas = ayar.timeSensitiveSetting == .enabled
          }
          let durum: [String: Any] = [
            "platform": "ios",
            "bildirimAcik": ayar.authorizationStatus == .authorized,
            "kritikUyari": kritik,
            "zamanHassas": zamanHassas,
          ]
          DispatchQueue.main.async { sonuc(durum) }
        }
      default:
        sonuc(FlutterMethodNotImplemented)
      }
    }
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
