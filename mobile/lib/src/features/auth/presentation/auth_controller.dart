import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../push/presentation/push_registrar.dart';
import '../data/auth_repository_impl.dart';
import '../domain/giris_hatasi.dart';
import 'giris_hata_metni.dart';

enum AuthStatus {
  /// Acilista saklanan oturum henuz kontrol edilmedi.
  unknown,

  /// Gecerli oturum yok → login ekrani.
  unauthenticated,

  /// Oturum acik → ana ekran.
  authenticated,
}

/// Auth ekraninin tum durumunu tasiyan immutable model.
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.submitting = false,
    this.errorMessage,
    this.hataKimligi,
    this.setupToken,
    this.kodBekleniyor = false,
    this.oauthBaglamaJetonu,
    this.oauthSaglayici,
    this.oauthRelay = false,
  });

  final AuthStatus status;

  /// Login istegi devam ediyor mu (buton spinner'i icin).
  final bool submitting;

  /// Hata KANALI ikilidir (README §15): [errorMessage] sozlesme hata
  /// zarfindan gelen SUNUCU metnini, [hataKimligi] yerellestirilebilir
  /// kimligi tasir (denetleyicide `BuildContext` yok).
  final String? errorMessage;
  final GirisAkisHatasi? hataKimligi;

  /// (P149) Parolasiz akista kod GONDERILDI — ekran kod alanina gecer.
  final bool kodBekleniyor;

  /// Sakinin gecici kodla ILK girisinde donen kisa omurlu parola-kurulum
  /// token'i. Dolu ise router parola belirleme ekranina yonlendirir.
  final String? setupToken;

  /// (P154 / Asama 4) Sosyal hesap DOGRULANDI ama bir kullaniciya BAGLI
  /// DEGIL. Dolu ise ekran tesis kodu + telefon adimina gecer — brief'in
  /// merkez kurali: sosyal hesap kimlik dogrulama YONTEMIDIR, eslesme
  /// anahtari degil.
  final String? oauthBaglamaJetonu;
  final String? oauthSaglayici;

  /// Apple "e-postami gizle" dediyse true; kullaniciya soylenir.
  final bool oauthRelay;

  AuthState copyWith({
    bool? kodBekleniyor,
    Object? oauthBaglamaJetonu = _sentinel,
    Object? oauthSaglayici = _sentinel,
    bool? oauthRelay,
    AuthStatus? status,
    bool? submitting,
    Object? errorMessage = _sentinel,
    Object? hataKimligi = _sentinel,
    Object? setupToken = _sentinel,
  }) {
    return AuthState(
      status: status ?? this.status,
      kodBekleniyor: kodBekleniyor ?? this.kodBekleniyor,
      submitting: submitting ?? this.submitting,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      hataKimligi: hataKimligi == _sentinel
          ? this.hataKimligi
          : hataKimligi as GirisAkisHatasi?,
      setupToken:
          setupToken == _sentinel ? this.setupToken : setupToken as String?,
      oauthBaglamaJetonu: oauthBaglamaJetonu == _sentinel
          ? this.oauthBaglamaJetonu
          : oauthBaglamaJetonu as String?,
      oauthSaglayici: oauthSaglayici == _sentinel
          ? this.oauthSaglayici
          : oauthSaglayici as String?,
      oauthRelay: oauthRelay ?? this.oauthRelay,
    );
  }

  static const Object _sentinel = Object();
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // WP2.3 — SOGUK ACILIS her zaman LOGIN'e duser: sessiz auto-login
    // (restoreSession + refresh) BILEREK kaldirildi. "Beni hatirla"
    // isaretliyse login ekrani alanlari on-doldurur (telefon+parola+kutu)
    // ve kullanici Giris'e basar. Oturum-ICI davranis degismez (bu build
    // yalniz uygulama acilisinda kosar; interceptor'in refresh akisi ve
    // arka plan donusleri ayni kalir). Mikro-gorevle isaretle: senkron
    // build icinde state yazilamaz.
    Future.microtask(
      () => state = state.copyWith(status: AuthStatus.unauthenticated),
    );
    return const AuthState();
  }

  /// Mobil giris (cep telefonu + kod|parola). Kalici parolayla giriste
  /// dogrudan authenticated olur; GECICI kodla ilk giriste [AuthState.setupToken]
  /// dolar ve parola belirleme ekranina gecilir (oturum henuz yoktur).
  /// [rememberMe] tercihi kurulum akisi boyunca korunur.
  /// (P149) PAROLASIZ GIRIS — 1. adim: numaraya kod iste.
  ///
  /// Basari/basarisizlik AYIRT ETTIRILMEZ: sunucu kayitli olmayan numara
  /// icin de ayni yaniti doner ve istemci de "numara yok" DEMEZ — aksi
  /// halde ekran bir numara sorgulama araci olurdu.
  Future<void> girisKoduIste(String telefon) async {
    state = state.copyWith(
      submitting: true, errorMessage: null, hataKimligi: null);
    try {
      await ref.read(authRepositoryProvider).girisKoduIste(telefon);
      state = state.copyWith(submitting: false, kodBekleniyor: true);
    } on ApiException catch (e) {
      state = state.copyWith(
        submitting: false, errorMessage: e.message, hataKimligi: e.code);
    }
  }

  /// (P149) PAROLASIZ GIRIS — 2. adim: kodu dogrula ve oturumu ac.
  Future<void> girisKoduDogrula({
    required String telefon,
    required String kod,
    bool rememberMe = false,
  }) async {
    state = state.copyWith(
      submitting: true, errorMessage: null, hataKimligi: null);
    try {
      await ref.read(authRepositoryProvider).girisKoduDogrula(
            telefon: telefon, kod: kod, rememberMe: rememberMe);
      state = state.copyWith(
        status: AuthStatus.authenticated, submitting: false);
    } on ApiException catch (e) {
      state = state.copyWith(
        submitting: false, errorMessage: e.message, hataKimligi: e.code);
    }
  }

  // ==================== (P155 §7) DAVET TAMAMLAMA ==================== #

  /// Davetle gelen kullanici PAROLA belirledi → oturum acilir (SMS YOK).
  Future<void> davetParolaTamamla({
    required String jeton,
    String? ad,
    required String newPassword,
  }) async {
    state = state.copyWith(
      submitting: true, errorMessage: null, hataKimligi: null);
    try {
      await ref.read(authRepositoryProvider).davetParola(
            jeton: jeton, ad: ad, newPassword: newPassword);
      state = state.copyWith(
        status: AuthStatus.authenticated, submitting: false);
    } on ApiException catch (e) {
      state = state.copyWith(
        submitting: false, errorMessage: e.message, hataKimligi: e.code);
    }
  }

  /// Davetle gelen kullanici SOSYAL hesabini bagladi → oturum acilir.
  ///
  /// IKI ASAMA: once tarayici akisi ([oauthAkisi]) baglama jetonu uretir,
  /// sonra bu metot onu davetle birlestirir. SMS YOK.
  Future<void> davetSosyalTamamla({
    required String jeton,
    String? ad,
  }) async {
    final baglama = state.oauthBaglamaJetonu;
    if (baglama == null) return;
    state = state.copyWith(
      submitting: true, errorMessage: null, hataKimligi: null);
    try {
      await ref.read(authRepositoryProvider).davetSosyal(
            jeton: jeton, baglamaJetonu: baglama, ad: ad);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        submitting: false,
        oauthBaglamaJetonu: null,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        submitting: false, errorMessage: e.message, hataKimligi: e.code);
    }
  }

  Future<void> loginPhone({
    required String phone,
    required String password,
    bool rememberMe = false,
  }) async {
    state = state.copyWith(
      submitting: true,
      errorMessage: null,
      hataKimligi: null,
    );
    try {
      final result = await ref.read(authRepositoryProvider).loginPhone(
            phone: phone,
            password: password,
            rememberMe: rememberMe,
          );
      if (result.passwordSetupRequired) {
        _pendingRememberMe = rememberMe;
        _pendingPhone = phone;
        state = state.copyWith(
          submitting: false,
          setupToken: result.setupToken,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          submitting: false,
        );
      }
    } on ApiException catch (e) {
      state = state.copyWith(
        submitting: false,
        errorMessage: e.message,
        hataKimligi: girisAgHatasi(e),
      );
    } catch (_) {
      state = state.copyWith(
        submitting: false,
        errorMessage: null,
        hataKimligi: GirisAkisHatasi.beklenmeyen,
      );
    }
  }

  /// (P154 / Asama 3) Rol secimli kayit, kod dogrulandiktan SONRA cagrilir.
  ///
  /// NEDEN AYRI BIR PAROLA EKRANI YAZILMADI: `setupToken` dolunca router
  /// zaten `/set-password`e goturuyor (bkz. app_router redirect) ve o ekran
  /// parola kuralini, gosterme/gizlemeyi ve 401'de kurulumu iptal etmeyi
  /// coktan cozmus. Kayit akisina ikinci bir parola ekrani yazmak, ayni
  /// kurallari iki yerde tutmak olurdu.
  ///
  /// `rememberMe`/`phone` BURADA SET EDILMEZ: kayit bir GIRIS degildir ve
  /// "beni hatirla" tercihi kullaniciya SORULMADI; varsaymak, secmedigi
  /// bir tercihi onun adina isaretlemek olurdu.
  void kayitKodunuOnayla(String setupToken) {
    state = state.copyWith(
      setupToken: setupToken,
      errorMessage: null,
      hataKimligi: null,
      submitting: false,
    );
  }

  /// Ilk giristeki zorunlu kalici parola belirleme. Basarida oturum acilir;
  /// setup token'i olmusse (401) kurulum iptal edilip login'e donulur.
  Future<void> submitNewPassword(String newPassword) async {
    final setupToken = state.setupToken;
    if (setupToken == null) return;
    state = state.copyWith(
      submitting: true,
      errorMessage: null,
      hataKimligi: null,
    );
    try {
      await ref.read(authRepositoryProvider).setPassword(
            setupToken: setupToken,
            newPassword: newPassword,
            rememberMe: _pendingRememberMe,
            phone: _pendingPhone,
          );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        submitting: false,
        setupToken: null,
      );
    } on ApiException catch (e) {
      // Setup token tek kullanimlik/kisa omurlu: 401'de kurulum kurtarilamaz,
      // sakin login'e kibarca doner ve yeniden kodla girer.
      final dead = e.statusCode == 401;
      state = state.copyWith(
        submitting: false,
        errorMessage: e.message,
        hataKimligi: girisAgHatasi(e),
        setupToken: dead ? null : setupToken,
      );
    } catch (_) {
      state = state.copyWith(
        submitting: false,
        errorMessage: null,
        hataKimligi: GirisAkisHatasi.beklenmeyen,
      );
    }
  }

  /// Parola kurulumundan vazgec (login'e don).
  void cancelPasswordSetup() {
    state = state.copyWith(
      setupToken: null,
      errorMessage: null,
      hataKimligi: null,
    );
  }

  /// Ilk giristeki "beni hatirla" tercihi; parola kurulumu tamamlaninca
  /// [submitNewPassword] icinde uygulanir.
  bool _pendingRememberMe = false;

  /// Ilk giriste girilen telefon; parola kurulumu sonrasi ON-DOLDURMA kaydinda
  /// (telefon + yeni parola) kullanilir.
  String? _pendingPhone;

  // ================= (P154 / Asama 4) SOSYAL GIRIS ================= #

  /// Tarayici akisini kosar.
  ///
  /// UC SONUC: oturum acildi · eslesme gerekiyor · KULLANICI VAZGECTI.
  /// Ucuncusu HATA DEGILDIR ve ekranda kirmizi bir kutu gostermez —
  /// tarayiciyi kapatmak bilincli bir eylemdir.
  Future<void> oauthAkisi(String saglayici) async {
    state = state.copyWith(
      submitting: true, errorMessage: null, hataKimligi: null);
    try {
      final sonuc = await ref.read(oauthRepositoryProvider).akis(saglayici);
      // `null` YALNIZ VAZGECME: kullanici tarayiciyi kapatti. Durum
      // degismez, hata da gosterilmez.
      if (sonuc == null) {
        state = state.copyWith(submitting: false);
        return;
      }
      // Kimlik ZATEN BAGLIYSA jetonlar depoya yazilmistir.
      if (sonuc.girisYapildi) {
        state = state.copyWith(
          submitting: false, status: AuthStatus.authenticated);
        return;
      }
      state = state.copyWith(
        submitting: false,
        oauthBaglamaJetonu: sonuc.baglamaJetonu,
        oauthSaglayici: sonuc.saglayici,
        oauthRelay: sonuc.relay,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        submitting: false, errorMessage: e.message, hataKimligi: e.code);
    }
  }

  /// Sosyal baglama — 1. adim: tesis kodu + telefon, eslesirse SMS.
  ///
  /// ESLESME SONUCU AYIRT ETTIRILMEZ (`girisKoduIste` ile ayni ilke).
  Future<({String tesisAd, String telefonMaskeli})?> oauthBaglanBasla({
    required String tesisKodu,
    required String telefon,
  }) async {
    final jeton = state.oauthBaglamaJetonu;
    if (jeton == null) return null;
    state = state.copyWith(
      submitting: true, errorMessage: null, hataKimligi: null);
    try {
      final r = await ref.read(oauthRepositoryProvider).baglanBasla(
            baglamaJetonu: jeton, tesisKodu: tesisKodu, telefon: telefon);
      state = state.copyWith(submitting: false, kodBekleniyor: true);
      return r;
    } on ApiException catch (e) {
      state = state.copyWith(
        submitting: false, errorMessage: e.message, hataKimligi: e.code);
      return null;
    }
  }

  /// Sosyal baglama — 2. adim: SMS kodu dogruysa BAGLAR ve oturum acar.
  Future<void> oauthBaglanDogrula({
    required String telefon,
    required String kod,
  }) async {
    final jeton = state.oauthBaglamaJetonu;
    if (jeton == null) return;
    state = state.copyWith(
      submitting: true, errorMessage: null, hataKimligi: null);
    try {
      await ref.read(oauthRepositoryProvider).baglanDogrula(
            baglamaJetonu: jeton, telefon: telefon, kod: kod);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        submitting: false,
        kodBekleniyor: false,
        oauthBaglamaJetonu: null,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        submitting: false, errorMessage: e.message, hataKimligi: e.code);
    }
  }

  /// Baglama akisindan cikis — kullanici vazgecti.
  void oauthIptal() {
    state = state.copyWith(
      oauthBaglamaJetonu: null,
      oauthSaglayici: null,
      kodBekleniyor: false,
      errorMessage: null,
      hataKimligi: null,
    );
  }

  Future<void> logout() async {
    // Push cihaz kaydini auth token'lar HENUZ gecerliyken pasiflestir
    // (DELETE /devices auth ister). Hatalari kendi icinde yutar — push
    // sorunu logout'u engellemez.
    await ref.read(pushRegistrarProvider.notifier).onLogout();
    await ref.read(authRepositoryProvider).logout();
    state = state.copyWith(status: AuthStatus.unauthenticated);
  }

  /// [AuthInterceptor] refresh'i kurtaramadiginda cagrilir (token'lar zaten
  /// silinmistir). Auth state'i `unauthenticated` yapar → router login'e doner.
  void onSessionExpired() {
    if (state.status == AuthStatus.unauthenticated) return;
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      submitting: false,
      errorMessage: null,
      hataKimligi: GirisAkisHatasi.oturumSonaErdi,
    );
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
