import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/oauth_repository.dart';
import '../domain/oauth_sonuc.dart';
import '../domain/phone_login_result.dart';
import 'auth_api.dart';
import 'oauth_tarayici.dart';
import 'token_storage.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this.api, required this.storage});

  final AuthApi api;
  final TokenStorage storage;

  @override
  Future<void> girisKoduIste(String telefon) => api.girisKoduIste(telefon);

  @override
  Future<void> girisKoduDogrula({
    required String telefon,
    required String kod,
    bool rememberMe = false,
  }) async {
    final tokens = await api.girisKoduDogrula(telefon: telefon, kod: kod);
    await storage.save(tokens);
    await storage.saveRememberMe(rememberMe);
  }

  @override
  Future<PhoneLoginResult> loginPhone({
    required String phone,
    required String password,
    bool rememberMe = false,
  }) async {
    final result = await api.loginPhone(phone: phone, password: password);
    // Gecici kodla ilk giriste oturum yok — saklanacak token da yok.
    if (result.tokens != null) {
      await storage.save(result.tokens!);
      await storage.saveRememberMe(rememberMe);
      // ON-DOLDURMA: isaretliyse telefon+parolayi sakla, degilse temizle.
      if (rememberMe) {
        await storage.saveCredentials(phone: phone, password: password);
      } else {
        await storage.clearCredentials();
      }
    }
    return result;
  }

  @override
  Future<void> setPassword({
    required String setupToken,
    required String newPassword,
    bool rememberMe = false,
    String? phone,
  }) async {
    final tokens = await api.setPassword(
      setupToken: setupToken,
      newPassword: newPassword,
    );
    await storage.save(tokens);
    await storage.saveRememberMe(rememberMe);
    // ON-DOLDURMA: ilk giris akisi — telefon biliniyorsa ve isaretliyse sakla.
    if (rememberMe && phone != null && phone.isNotEmpty) {
      await storage.saveCredentials(phone: phone, password: newPassword);
    } else {
      await storage.clearCredentials();
    }
  }

  @override
  Future<void> davetParola({
    required String jeton,
    String? ad,
    required String newPassword,
  }) async {
    final tokens = await api.davetParola(
      jeton: jeton, ad: ad, newPassword: newPassword,
    );
    await storage.save(tokens);
    // Davet yolunda "beni hatirla" akisi YOK: kullanici bir bagdan geldi,
    // parola on-doldurmasi burada anlamsiz.
    await storage.clearCredentials();
  }

  @override
  Future<void> davetSosyal({
    required String jeton,
    required String baglamaJetonu,
    String? ad,
  }) async {
    final tokens = await api.davetSosyal(
      jeton: jeton, baglamaJetonu: baglamaJetonu, ad: ad,
    );
    await storage.save(tokens);
    await storage.clearCredentials();
  }

  @override
  Future<({String tesisAd, String tesisKodu})> tesisOlustur({
    required String tesisAd,
    required String ad,
    required String telefon,
    String? parola,
    String? baglamaJetonu,
  }) async {
    final sonuc = await api.tesisOlustur(
      tesisAd: tesisAd, ad: ad, telefon: telefon,
      parola: parola, baglamaJetonu: baglamaJetonu,
    );
    await storage.save(sonuc.jetonlar);
    // "Beni hatirla" on-doldurmasi BURADA YAPILMIYOR ve davet yoluyla
    // ayni gerekce: kullanici hesabini AZ ONCE acti, oturumu zaten
    // acik ve bir sonraki girise kadar parolasini hatirlatmamiz
    // gerekmiyor. Saklamak, hic istenmemis bir veriyi cihazda
    // tutmak olurdu.
    await storage.clearCredentials();
    return (tesisAd: sonuc.tesisAd, tesisKodu: sonuc.tesisKodu);
  }

  @override
  Future<({String phone, String password})?> readSavedCredentials() =>
      storage.readCredentials();

  @override
  Future<bool> restoreSession() async {
    if (!await storage.readRememberMe()) {
      // "Hatirla"siz oturumun kalintilari sonraki acilista tasinmaz.
      await storage.clear();
      return false;
    }

    final refreshToken = await storage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final tokens = await api.refresh(refreshToken);
      await storage.save(tokens);
      return true;
    } on ApiException catch (e) {
      // Gecici ag hatasinda oturumu koru (sonraki acilis tekrar dener);
      // olu/iptal token'da (auth) kalici oturumu tamamen temizle.
      if (e.kind != ApiErrorKind.network) {
        await storage.clear();
      }
      return false;
    } catch (_) {
      // Beklenmeyen hata acilisi patlatmasin → login ekranina kibar dusus.
      return false;
    }
  }

  /// Cikis: oturum VE saklanan giris bilgileri silinir.
  ///
  /// (P170 §1) ONCEDEN on-doldurma bilgileri BIRAKILIYORDU ("cikis sonrasi
  /// login ekrani yine on-dolu gelsin" diye). Karar degisti ve gerekce
  /// guvenlik: cikis, ORTAK ya da odunc bir cihazda "benden sonrasi bana
  /// ait degil" demenin tek yoludur. Parolayi cihazda birakan bir cikis,
  /// bir sonraki kisiye tek dokunusluk giris birakirdi.
  ///
  /// BEDELI KABUL EDILDI: bilerek cikan kullanici bir dahaki sefere
  /// parolasini yeniden yazar. "Beni hatirla" boylece asil isini yapmaya
  /// devam eder — uygulama kapanip acildiginda ve oturum suresi
  /// dolduğunda on-doldurma calisir; kaybolan yalniz CIKIS SONRASI hali.
  @override
  Future<void> logout() async {
    await storage.clear();
    await storage.clearCredentials();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    api: ref.watch(authApiProvider),
    storage: ref.watch(tokenStorageProvider),
  );
});

/// (P154 / Asama 4) Sosyal giris deposu — gerekce `OauthRepository`de.
class OauthRepositoryImpl implements OauthRepository {
  OauthRepositoryImpl({
    required this.api,
    required this.storage,
    required this.tarayici,
  });

  final AuthApi api;
  final TokenStorage storage;
  final OauthTarayici tarayici;

  @override
  Future<List<String>> saglayicilar() => api.oauthSaglayicilar();

  @override
  Future<OauthSonuc?> akis(String saglayici) async {
    final adres = await api.oauthBaslat(saglayici);
    final sonucId = await tarayici.akisiCalistir(adres);
    // VAZGECME: kullanici tarayiciyi kapatti. Hata degil.
    if (sonucId == null) return null;
    final sonuc = await api.oauthSonuc(sonucId);
    if (sonuc.girisYapildi) {
      await storage.save(sonuc.jetonlar!);
    }
    return sonuc;
  }

  @override
  Future<void> tesisSec({
    required String secimJetonu,
    required String tenantId,
  }) async {
    final jetonlar = await api.oauthTesisSec(
      secimJetonu: secimJetonu, tenantId: tenantId);
    await storage.save(jetonlar);
  }

  @override
  Future<({String tesisAd, String telefonMaskeli})> baglanBasla({
    required String baglamaJetonu,
    required String tesisKodu,
    required String telefon,
  }) =>
      api.oauthBaglanBasla(
        baglamaJetonu: baglamaJetonu,
        tesisKodu: tesisKodu,
        telefon: telefon,
      );

  @override
  Future<void> baglanDogrula({
    required String baglamaJetonu,
    required String telefon,
    required String kod,
  }) async {
    final tokens = await api.oauthBaglanDogrula(
      baglamaJetonu: baglamaJetonu,
      telefon: telefon,
      kod: kod,
    );
    await storage.save(tokens);
  }

  @override
  Future<({String durum, String? tesisAd})> rolTamamla({
    required String baglamaJetonu,
    required String tesisKodu,
    String? rol,
  }) async {
    final r = await api.oauthRolTamamla(
      baglamaJetonu: baglamaJetonu,
      tesisKodu: tesisKodu,
      rol: rol,
    );
    // `giris` -> jetonlar geldi; oturumu ac. Oteki durumlar oturum ACMAZ.
    if (r.durum == 'giris' && r.jetonlar != null) {
      await storage.save(r.jetonlar!);
    }
    return (durum: r.durum, tesisAd: r.tesisAd);
  }

  @override
  Future<({String durum})> rolTamamlaDogrula({
    required String baglamaJetonu,
    required String tesisKodu,
    String? rol,
    required String kod,
  }) async {
    final r = await api.oauthRolTamamlaDogrula(
      baglamaJetonu: baglamaJetonu,
      tesisKodu: tesisKodu,
      rol: rol,
      kod: kod,
    );
    if (r.durum == 'giris' && r.jetonlar != null) {
      await storage.save(r.jetonlar!);
    }
    return (durum: r.durum);
  }
}

final oauthRepositoryProvider = Provider<OauthRepository>((ref) {
  return OauthRepositoryImpl(
    api: ref.watch(authApiProvider),
    storage: ref.watch(tokenStorageProvider),
    tarayici: ref.watch(oauthTarayiciProvider),
  );
});
