import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
import 'package:mobile/src/features/auth/domain/auth_repository.dart';
import 'package:mobile/src/features/auth/domain/phone_login_result.dart';
import 'package:mobile/src/features/auth/domain/token_pair.dart';
import 'package:mobile/src/features/auth/presentation/login_screen.dart';

import 'helpers/l10n_test_app.dart';

import 'helpers/sosyal_kapali.dart';

const _tokens = TokenPair(
  accessToken: 'acc',
  refreshToken: 'ref',
  tokenType: 'Bearer',
  expiresIn: 900,
);

/// loginPhone cagrilarini kaydeden sahte auth deposu.
class _RecordingAuthRepository implements AuthRepository {
  // (P149) Parolasiz giris ucu — bu sahtelerin olcumu parola yolundadir;
  // kod yolu kendi testinde surulur.
  @override
  Future<void> girisKoduIste(String telefon) async {}

  @override
  Future<void> girisKoduDogrula({
    required String telefon,
    required String kod,
    bool rememberMe = false,
  }) async {}

  final phoneLogins =
      <({String phone, String password, bool rememberMe})>[];

  @override
  Future<bool> restoreSession() async => false;

  @override
  Future<PhoneLoginResult> loginPhone({
    required String phone,
    required String password,
    bool rememberMe = false,
  }) async {
    phoneLogins.add((phone: phone, password: password, rememberMe: rememberMe));
    return const PhoneLoginResult(passwordSetupRequired: false, tokens: _tokens);
  }

  @override
  Future<void> setPassword({
    required String setupToken,
    required String newPassword,
    bool rememberMe = false,
    String? phone,
  }) async {}

  @override
  Future<({String phone, String password})?> readSavedCredentials() async =>
      null;

  @override
  Future<void> davetParola({
    required String jeton,
    String? ad,
    required String newPassword,
  }) async {}

  @override
  Future<void> davetSosyal({
    required String jeton,
    required String baglamaJetonu,
    String? ad,
  }) async {}

  @override
  Future<({String tesisAd, String tesisKodu})> tesisOlustur({
    required String tesisAd,
    required String ad,
    required String telefon,
    String? parola,
    String? baglamaJetonu,
  }) async =>
      (tesisAd: tesisAd, tesisKodu: 'SINA-260101');

  @override
  Future<void> logout() async {}
}

void main() {
  late _RecordingAuthRepository repo;

  setUp(() => repo = _RecordingAuthRepository());

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...sosyalKapali, authRepositoryProvider.overrideWithValue(repo)],
        child: l10nApp(const LoginScreen()),
      ),
    );
    await tester.pump();
  }

  // (P205 §1) EKRAN TEK ALANA DUSTU: "Cep telefonu" / "E-posta" diye AYRI
  // alanlar YOK. Bu dosya once "e-posta alani gorunmemeli" diye kilitliyordu;
  // o kural ARTIK GECERSIZ — ayri alan olmadigi icin degil, e-posta ile
  // giris ARTIK DESTEKLENDIGI icin (telefonsuz kaydolmus yonetici mobile
  // hic giremiyordu).
  testWidgets('TEK kimlik alani + parola; ayri telefon/e-posta/mod alani yok',
      (tester) async {
    await pumpLogin(tester);

    expect(find.byKey(const Key('giris-kimlik')), findsOneWidget);
    expect(find.text('E-posta veya telefon numarası'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Parola veya geçici kod'),
      findsOneWidget,
    );
    // Eski iki-modlu akisin izleri kalmadi.
    expect(find.text('Personel'), findsNothing);
    expect(find.text('Sakin'), findsNothing);
    expect(
      find.widgetWithText(TextFormField, 'Tesis kodu (tenant)'),
      findsNothing,
    );
  });

  testWidgets('giris loginPhone\'a telefon + rememberMe ile gider',
      (tester) async {
    await pumpLogin(tester);

    await tester.enterText(
        find.byKey(const Key('giris-kimlik')), '05321112203');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Parola veya geçici kod'),
        'K7MR-2QWX');
    await tester.tap(find.byKey(const Key('remember_me_checkbox')));
    await tester.pump();

    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    final call = repo.phoneLogins.single;
    // (P123) SUNUCUYA NORMALLESTIRILMIS gider. Tel BICIMI degismedi —
    // `normalize_phone` hem `0532…` hem `+90532…` kabul eder — ama ayni
    // numaranin iki farkli yazimla gitmesi, telefon GLOBAL BENZERSIZ
    // oldugu icin ileride cakisma hatasina donusurdu. Ekranda kullanici
    // yine yerel bicimi gorur (asagida olculuyor).
    expect(call.phone, '+905321112203');
    expect(call.password, 'K7MR-2QWX');
    expect(call.rememberMe, isTrue);
    // (P205 §1) GRUPLAMA KALKTI: `TelefonBicimlendirici` rakam disini
    // YUTUYORDU — ayni alana e-posta yazilamazdi. Kullanici artik
    // yazdigini aynen gorur; normallestirme yalniz TASIMADA yapilir
    // (yukarida olculdu).
    expect(find.text('05321112203'), findsOneWidget);
  });

  testWidgets('bos alanlarla giris → dogrulama, cagri yapilmaz',
      (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();

    expect(repo.phoneLogins, isEmpty);
    // BICIM DENETIMI YOK, BOSLUK DENETIMI VAR: girdi telefon OLMAK
    // ZORUNDA degil, o yuzden "Telefon zorunludur" metni kalkti.
    expect(find.text('E-posta veya telefon numaranızı yazın'), findsOneWidget);
  });
}
