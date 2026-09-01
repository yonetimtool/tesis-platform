/// (P194) MOBILDE YONETICI SSO ILE GIRIS YAPABILMELI.
///
/// ===========================================================================
/// OLCULEN KUSUR
/// ===========================================================================
/// Web'de kaydolmus bir YONETICI, mobil giris ekraninda "Google ile devam"
/// dedigi anda cikmaza dusuyordu:
///
///   1. Kimlik henuz bagli degilse ekran BAGLAMA FORMUNA gecer,
///   2. o formda bir ROL ACILIR LISTESI vardi ve liste `KayitRolu`ydan
///      besleniyordu — yani KAYIT ekraninin listesinden,
///   3. yonetici mobilden KAYDOLAMADIGI icin o listede yonetici YOK,
///   4. kullanici mecburen "Sakin" seciyor,
///   5. sunucu `_liste_kontrolu` ile "rol_uyusmuyor" deyip
///      `onay_bekliyor` donuyor — hesabi VARKEN giris yapamiyordu.
///
/// SUNUCUDA OLCULDU (dev API, gercek yonetici + dogrulanmis Google kimligi,
/// ayni Tesis ID):
///     rol="resident" gonderildi -> durum="onay_bekliyor", jeton YOK
///     rol GONDERILMEDI          -> durum="giris",         jeton VAR
///
/// Yani sunucu (P191 §1) ZATEN hazirdi: rol beyani yoksa rol HESAPTAN
/// okunur ve `_TAMAMLA_ROLLERI` yoneticiyi de kapsar. Eksik olan tek sey,
/// istemcinin beyani birakmasiydi.
///
/// KURAL: GIRIS kimlik sorar, ROL SORMAZ. Rol secimi yalnizca KAYIT
/// ekraninda anlamlidir ve orada DURUYOR (`kayit_rol_secimi_test.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
import 'package:mobile/src/features/auth/domain/oauth_repository.dart';
import 'package:mobile/src/features/auth/domain/oauth_sonuc.dart';
import 'package:mobile/src/features/auth/presentation/auth_controller.dart';
import 'package:mobile/src/features/auth/presentation/login_screen.dart';

import 'helpers/l10n_test_app.dart';

/// Kimligi HENUZ BAGLI OLMAYAN bir SSO donusunu taklit eder.
class _SahteOauth implements OauthRepository {
  _SahteOauth({this.tamamlaDurum = 'giris'});

  final String tamamlaDurum;

  /// `rol-tamamla` cagrilari — `rol` alani `null` ise GONDERILMEDI demektir.
  final tamamlaCagrilari = <({String tesisKodu, String? rol})>[];
  final dogrulaCagrilari = <({String tesisKodu, String? rol, String kod})>[];

  @override
  Future<List<String>> saglayicilar() async => const [
        'google',
        'microsoft',
        'apple',
      ];

  @override
  Future<OauthSonuc?> akis(String saglayici) async => OauthSonuc(
        durum: 'baglama_gerekli',
        saglayici: saglayici,
        baglamaJetonu: 'baglama-1',
        ad: 'Acme Yonetici',
      );

  @override
  Future<({String tesisAd, String telefonMaskeli})> baglanBasla({
    required String baglamaJetonu,
    required String tesisKodu,
    required String telefon,
  }) async =>
      (tesisAd: 'Acme Plaza', telefonMaskeli: '+9053***200');

  @override
  Future<void> baglanDogrula({
    required String baglamaJetonu,
    required String telefon,
    required String kod,
  }) async {}

  @override
  Future<({String durum, String? tesisAd})> rolTamamla({
    required String baglamaJetonu,
    required String tesisKodu,
    String? rol,
  }) async {
    tamamlaCagrilari.add((tesisKodu: tesisKodu, rol: rol));
    return (
      durum: tamamlaDurum,
      tesisAd: tamamlaDurum == 'otp_gerekli' ? 'Acme Plaza' : null,
    );
  }

  @override
  Future<({String durum})> rolTamamlaDogrula({
    required String baglamaJetonu,
    required String tesisKodu,
    String? rol,
    required String kod,
  }) async {
    dogrulaCagrilari.add((tesisKodu: tesisKodu, rol: rol, kod: kod));
    return (durum: 'giris');
  }
}

/// Dugmeler KAYDIRILABILIR alanda: once gorunur kilinir.
///
/// `tester.tap` ekran disindaki bir dugmede SESSIZCE isabetsiz kalir
/// (yalniz uyari basar) — olculdu: `akis` hic cagrilmadi ve test daha
/// sonraki bir satirda, yaniltici bir yerde dustu.
Future<void> _sagayiciyaBas(WidgetTester tester, String saglayici) async {
  final dugme = find.byKey(Key('sosyal-$saglayici'));
  await tester.ensureVisible(dugme);
  await tester.pumpAndSettle();
  await tester.tap(dugme);
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _sur(WidgetTester tester, _SahteOauth oauth) async {
  final kap = ProviderContainer(
    overrides: [oauthRepositoryProvider.overrideWithValue(oauth)],
  );
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: kap,
      child: l10nApp(const LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return kap;
}

void main() {
  testWidgets('UC SAGLAYICI da giris ekraninda cizilir', (tester) async {
    await _sur(tester, _SahteOauth());
    for (final s in ['google', 'microsoft', 'apple']) {
      expect(find.byKey(Key('sosyal-$s')), findsOneWidget,
          reason: '$s dugmesi yok — yonetici o saglayiciyla giremez');
    }
  });

  testWidgets('SSO donusunde ROL SECIMI YOK (giris rol sormaz)',
      (tester) async {
    final oauth = _SahteOauth();
    final kap = await _sur(tester, oauth);

    await _sagayiciyaBas(tester, 'google');
    // ignore: avoid_print
    // Baglama formu acildi...
    expect(find.byKey(const Key('sosyal-tesis-kodu')), findsOneWidget);
    // ...ama ROL ACILIR LISTESI YOK. Bu listenin varligi, yoneticiyi
    // kendi rolunu SECEMEDIGI bir formda birakiyordu.
    expect(find.byKey(const Key('sosyal-rol')), findsNothing,
        reason: 'giris ekraninda rol secimi olmamali');
  });

  testWidgets('TESIS ID ile tamamlama ROL GONDERMEDEN yapilir -> oturum',
      (tester) async {
    final oauth = _SahteOauth(tamamlaDurum: 'giris');
    final kap = await _sur(tester, oauth);

    await _sagayiciyaBas(tester, 'google');
    await tester.enterText(
        find.byKey(const Key('sosyal-tesis-kodu')), 'ACME-260901');
    await tester.tap(find.byKey(const Key('sosyal-ilerle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // ROL GONDERILMEDI: sunucu rolu hesaptan okur ve yoneticiyi de kabul
    // eder. `rol` dolu gitseydi sunucu "onay_bekliyor" donerdi (olculdu).
    expect(oauth.tamamlaCagrilari.single.rol, isNull,
        reason: 'giris akisi rol BEYAN ETMEMELI');
    expect(oauth.tamamlaCagrilari.single.tesisKodu, 'ACME-260901');
    expect(kap.read(authControllerProvider).status, AuthStatus.authenticated);
  });

  testWidgets('OTP yolunda da ROL GONDERILMEZ', (tester) async {
    final oauth = _SahteOauth(tamamlaDurum: 'otp_gerekli');
    final kap = await _sur(tester, oauth);

    await _sagayiciyaBas(tester, 'google');
    await tester.enterText(
        find.byKey(const Key('sosyal-tesis-kodu')), 'ACME-260901');
    await tester.tap(find.byKey(const Key('sosyal-ilerle')));
    await tester.pumpAndSettle();

    // Ikinci adim (e-posta OTP) — burada da rol beyan edilmemeli; aksi
    // halde OTP yolundaki yonetici yine cikmaza duserdi.
    await tester.enterText(find.byKey(const Key('sosyal-kod')), '123456');
    await tester.tap(find.byKey(const Key('sosyal-ilerle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(oauth.dogrulaCagrilari.single.rol, isNull);
    expect(kap.read(authControllerProvider).status, AuthStatus.authenticated);
  });
}
