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

  /// (P211 §1) Cok tesisli yonetici secimi — bu testin olctugu akista
  /// cagrilmaz; arayuz uyesi oldugu icin uygulanir.
  @override
  Future<void> tesisSec({
    required String secimJetonu,
    required String tenantId,
  }) async {}
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

  // (P211-ek3) BU BLOK YENIDEN YAZILDI — GIRIS EKRANINDA ARTIK
  // TAMAMLAMA FORMU YOK.
  //
  // P194'un kilitledigi kural "giris rol SORMAZ"di ve o kural artik
  // YAPISAL olarak sagl aniyor: giris ekrani bagli olmayan bir kimlige
  // ne rol ne Tesis ID sorar — kullaniciyi kayda yonlendirir. Rol
  // gonderilmemesi gereken uc (`rol-tamamla`) sunucu tarafinda
  // kilitlidir (backend `test_p194_mobil_yonetici_sso.py`) ve kayit
  // ekraninda rol BILEREK gonderilir (orasi bir KAYIT akisidir).
  testWidgets('BAGLI OLMAYAN KIMLIK: giris ekrani NE ROL NE TESIS ID sorar',
      (tester) async {
    await _sur(tester, _SahteOauth());
    await _sagayiciyaBas(tester, 'google');

    // Eski cikmazin iki parcasi da YOK.
    expect(find.byKey(const Key('sosyal-rol')), findsNothing,
        reason: 'giris ekraninda rol secimi olmamali');
    expect(find.byKey(const Key('sosyal-tesis-kodu')), findsNothing,
        reason: 'Tesis ID YALNIZ kayit akisinda sorulur');
    // Yerine ACIK bir yol gosterilir.
    expect(find.byKey(const Key('sso-hesap-bagli-degil')), findsOneWidget);
    expect(find.byKey(const Key('sso-kayda-git')), findsOneWidget);
  });

  testWidgets('GIRIS EKRANI hicbir TAMAMLAMA istegi GONDERMEZ', (tester) async {
    // P194'te olculen kusur, giris ekraninin rol beyan ederek tamamlama
    // cagirmasiydi. Artik o cagri BU EKRANDAN HIC yapilmiyor.
    final oauth = _SahteOauth(tamamlaDurum: 'giris');
    await _sur(tester, oauth);
    await _sagayiciyaBas(tester, 'google');
    expect(oauth.tamamlaCagrilari, isEmpty);
    expect(oauth.dogrulaCagrilari, isEmpty);
  });
}
