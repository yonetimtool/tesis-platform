import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../auth/data/token_storage.dart';
import '../../auth/domain/jwt_claims.dart';

/// (DUKKAN F7 §2) DUKKAN JETONUNUN KALICI DEPOSU.
///
/// ===========================================================================
/// NEDEN KALICI OLMAK ZORUNDA
/// ===========================================================================
/// F7'ye kadar Dukkan jetonu YALNIZ BELLEKTEYDI ve her açılışta SSO
/// köprüsünden yeniden alınıyordu. Bu, telefonu olan kullanıcı için
/// çalışıyor — köprü ona jeton veriyor.
///
/// **Telefonu olmayan %27 için çalışmıyor.** Köprü onlara her seferinde
/// 409 `telefon_gerekli` dönüyor. OTP ile jeton alsalar bile, uygulamayı
/// kapattıklarında jeton kayboluyor ve ERTESI GUN YENIDEN OTP gerekiyordu
/// — yani her açılışta bir SMS. Bu, akışı kullanılamaz yapardı.
///
/// OTP akışının işe yaraması, jetonun **cihazda kalmasına** bağlı.
///
/// ===========================================================================
/// JETON YONETIYOR KULLANICISINA BAGLI — VE BU ZORUNLU
/// ===========================================================================
/// Sadece "jetonu sakla" demek bir sızıntı açardı: A çıkış yapmadan
/// uygulamayı öldürür, aynı telefonda B giriş yapar, B Dukkan'ı açar ve
/// **A'nın kimliğiyle** pazar yerine girer. F6-ek'te bellekte olan aynı
/// kusurun kalıcı hâli olurdu.
///
/// Bu yüzden jeton, alındığı andaki **Yönetiyor kullanıcı kimliğiyle
/// birlikte** saklanıyor ve okuma o kimlik eşleşmezse `null` dönüyor.
/// Çıkışta silmek de yapılıyor (`DukkanOturum.temizle`) ama tek başına
/// yetmez: çıkış yapılmadan öldürülen uygulama o yolu hiç çalıştırmaz.
///
/// ===========================================================================
/// SURESI DOLMUS JETON YOK SAYILIR
/// ===========================================================================
/// Dukkan jetonu 30 gün yaşıyor. Süresi dolmuşu döndürmek, kullanıcıyı
/// her ekranda 401 alan bir akışa sokardı; oysa doğru davranış köprüyü
/// (ya da OTP'yi) yeniden denemek. `exp` istemcide **yalnızca bu amaçla**
/// okunuyor — yetki kararı değil, "boşuna deneme" kararı.
class DukkanJetonDeposu {
  DukkanJetonDeposu(this._depo, this._yonetiyorDepo);

  final FlutterSecureStorage _depo;
  final TokenStorage _yonetiyorDepo;

  static const _kJeton = 'dukkan.jeton';
  static const _kSahip = 'dukkan.jeton.sahip';

  /// Şu anki Yönetiyor oturumunun kullanıcı kimliği (`sub`).
  ///
  /// Jetondan okunuyor çünkü `AuthState` kullanıcı kimliği taşımıyor ve
  /// `authControllerProvider`ı buradan okumak iki yönlü bir provider
  /// bağı kurardı (`AuthController` zaten `DukkanOturum`u okuyor).
  Future<String?> yonetiyorSahibi() async {
    final jeton = await _yonetiyorDepo.readAccessToken();
    if (jeton == null) return null;
    final claims = decodeJwtClaims(jeton);
    final sub = claims?['sub'];
    return sub is String && sub.isNotEmpty ? sub : null;
  }

  /// Saklı jeton — YALNIZCA sahibi şu anki kullanıcıysa ve süresi
  /// dolmamışsa. Aksi hâlde `null` (ve kayıt temizlenir).
  Future<String?> oku() async {
    final sahip = await yonetiyorSahibi();
    if (sahip == null) return null;
    final kayitliSahip = await _depo.read(key: _kSahip);
    if (kayitliSahip != sahip) {
      // BASKA KULLANICININ JETONU: sil. Bırakmak, o kullanıcı tekrar
      // giriş yaptığında sürprizle karşılaşması demek değil — asıl
      // sorun, arada bu cihazı kullanan kişinin onu okuyabilmesi.
      await sil();
      return null;
    }
    final jeton = await _depo.read(key: _kJeton);
    if (jeton == null) return null;
    if (_suresiDoldu(jeton)) {
      await sil();
      return null;
    }
    return jeton;
  }

  Future<void> yaz(String jeton) async {
    final sahip = await yonetiyorSahibi();
    if (sahip == null) return; // Yönetiyor oturumu yoksa saklamanın anlamı yok
    await _depo.write(key: _kJeton, value: jeton);
    await _depo.write(key: _kSahip, value: sahip);
  }

  Future<void> sil() async {
    await _depo.delete(key: _kJeton);
    await _depo.delete(key: _kSahip);
  }

  static bool _suresiDoldu(String jeton) {
    final exp = decodeJwtClaims(jeton)?['exp'];
    if (exp is! num) return false; // okunamıyorsa sunucu karar versin
    final an = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
    // 1 DAKIKALIK PAY: tam sınırda bir jetonu kullanıp anında 401 almak
    // yerine baştan yenilemek daha az adım.
    return an.isBefore(DateTime.now().add(const Duration(minutes: 1)));
  }
}

final dukkanJetonDeposuProvider = Provider<DukkanJetonDeposu>(
  (ref) => DukkanJetonDeposu(
    ref.watch(secureStorageProvider),
    ref.watch(tokenStorageProvider),
  ),
);
