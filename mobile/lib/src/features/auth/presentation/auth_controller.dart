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
    this.oauthAd,
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

  /// (P155r2 §2) Saglayicinin bildirdigi ad soyad — kayit formu bunu
  /// ON-DOLDURUR ve kullanici duzeltebilir. Apple'da BOS gelir.
  final String? oauthAd;

  /// (P200 §2) `hataKimligi` OBJECT ALIR ama YALNIZ [GirisAkisHatasi]
  /// KABUL EDER — String verilirse asagidaki cast CALISMA ANINDA patlar.
  ///
  /// OLCULDU: on cagri yerinde `e.code` (String) geciliyordu. Sonuc bir
  /// "hata mesaji yanlis" degil, YAKALANMAMIS BIR ISTISNA idi: `catch`
  /// blogunun ICINDE atiliyor, metottan disari sizip ekranin bekleme
  /// bayragini acik birakiyordu — kullanici sonsuza kadar donen bir
  /// dugme goruyor, hicbir hata metni gormuyordu. Yani sunucu bir hata
  /// dondurdugunde akis SESSIZCE KILITLENIYORDU.
  ///
  /// Dogru donusturucu (`girisAgHatasi`) tur 13'te yazilmisti ama yalniz
  /// iki cagri yerinde kullaniliyordu.
  AuthState copyWith({
    bool? kodBekleniyor,
    Object? oauthBaglamaJetonu = _sentinel,
    Object? oauthAd = _sentinel,
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
      oauthAd: oauthAd == _sentinel ? this.oauthAd : oauthAd as String?,
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
        submitting: false, errorMessage: e.message, hataKimligi: girisAgHatasi(e));
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
        submitting: false, errorMessage: e.message, hataKimligi: girisAgHatasi(e));
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
        submitting: false, errorMessage: e.message, hataKimligi: girisAgHatasi(e));
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
        submitting: false, errorMessage: e.message, hataKimligi: girisAgHatasi(e));
    }
  }

  /// (P155r2 §3) Yonetici tesisini acar → OTURUM ACILIR.
  ///
  /// Basarida `(tesisAd, tesisKodu)` doner ki ekran kodu gosterip
  /// kopyalatabilsin; basarisizlikta `null` doner ve hata `state`e
  /// yazilir (ekran onu okur). Depodaki oteki akislarla ayni desen.
  ///
  /// SOSYAL YOLDA baglama jetonu `state`ten alinir — cagiran onu
  /// tasimaz; jetonun tek sahibi denetleyicidir ve iki yerde tutmak
  /// onu ayristirirdi.
  Future<({String tesisAd, String tesisKodu})?> tesisOlustur({
    required String tesisAd,
    required String ad,
    required String telefon,
    String? parola,
    bool sosyal = false,
  }) async {
    final baglama = sosyal ? state.oauthBaglamaJetonu : null;
    if (sosyal && baglama == null) return null;
    state = state.copyWith(
      submitting: true, errorMessage: null, hataKimligi: null);
    try {
      final sonuc = await ref.read(authRepositoryProvider).tesisOlustur(
            tesisAd: tesisAd,
            ad: ad,
            telefon: telefon,
            parola: parola,
            baglamaJetonu: baglama,
          );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        submitting: false,
        oauthBaglamaJetonu: null,
        oauthAd: null,
      );
      return sonuc;
    } on ApiException catch (e) {
      state = state.copyWith(
        submitting: false, errorMessage: e.message, hataKimligi: girisAgHatasi(e));
      return null;
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
        oauthAd: sonuc.ad,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        submitting: false, errorMessage: e.message, hataKimligi: girisAgHatasi(e));
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
        submitting: false, errorMessage: e.message, hataKimligi: girisAgHatasi(e));
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
        submitting: false, errorMessage: e.message, hataKimligi: girisAgHatasi(e));
    }
  }

  /// (P184) SSO TAMAMLAMA — rol + Tesis ID (SMS'siz). Jeton state'ten alinir.
  ///
  /// Doner `durum`: `giris` (oturum acilir) · `otp_gerekli` (e-postaya kod
  /// gitti, `tesisAd` dolu — jeton KORUNUR, 2. adim [oauthRolTamamlaDogrula])
  /// · `onay_bekliyor` (hesap acilmaz, kullaniciya soylenir). Hata olursa
  /// `null` doner ve mesaj state'e yazilir.
  /// (P194) `rol` OPSIYONEL: GIRIS akisi rol BEYAN ETMEZ (sunucu rolu
  /// hesaptan okur). Yalniz KAYIT akisi beyan eder.
  Future<({String durum, String? tesisAd})?> oauthRolTamamla({
    required String tesisKodu,
    String? rol,
  }) async {
    final jeton = state.oauthBaglamaJetonu;
    if (jeton == null) return null;
    state = state.copyWith(
      submitting: true, errorMessage: null, hataKimligi: null);
    try {
      final r = await ref.read(oauthRepositoryProvider).rolTamamla(
            baglamaJetonu: jeton, tesisKodu: tesisKodu, rol: rol);
      if (r.durum == 'giris') {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          submitting: false,
          oauthBaglamaJetonu: null,
        );
      } else {
        // otp_gerekli/onay_bekliyor: jeton KORUNUR (2. adim gerekebilir).
        state = state.copyWith(submitting: false);
      }
      return r;
    } on ApiException catch (e) {
      state = state.copyWith(
        submitting: false, errorMessage: e.message, hataKimligi: girisAgHatasi(e));
      return null;
    }
  }

  /// (P184) SSO tamamlama 2. adim — email_verified=false yolu: e-posta OTP.
  /// Doner `durum`: `giris` (oturum) · `onay_bekliyor`. Hata -> `null`.
  Future<String?> oauthRolTamamlaDogrula({
    required String tesisKodu,
    String? rol,
    required String kod,
  }) async {
    final jeton = state.oauthBaglamaJetonu;
    if (jeton == null) return null;
    state = state.copyWith(
      submitting: true, errorMessage: null, hataKimligi: null);
    try {
      final r = await ref.read(oauthRepositoryProvider).rolTamamlaDogrula(
            baglamaJetonu: jeton, tesisKodu: tesisKodu, rol: rol, kod: kod);
      if (r.durum == 'giris') {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          submitting: false,
          oauthBaglamaJetonu: null,
        );
      } else {
        state = state.copyWith(submitting: false);
      }
      return r.durum;
    } on ApiException catch (e) {
      state = state.copyWith(
        submitting: false, errorMessage: e.message, hataKimligi: girisAgHatasi(e));
      return null;
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
