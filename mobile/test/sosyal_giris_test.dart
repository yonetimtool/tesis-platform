/// (P154 / Asama 4) SOSYAL GIRIS — mobil akis.
///
/// OLCULEN DORT SEY, dordu de "yanlisi kullaniciyi cikmaza sokar" sinifi:
///
///   1. YAPILANDIRILMAMISSA HIC CIZILMEZ. Calismayacak bir dugme
///      gostermek, kullaniciyi kesin basarisiz bir yola sokmak olurdu ve
///      brief'in sarti "tikanirsa Asama 3 tek basina calissin".
///
///   2. VAZGECME HATA DEGILDIR. Kullanici tarayiciyi kapatinca akis
///      `null` doner; ekranda kirmizi bir kutu cikmamali — bilincli bir
///      eylemi arizaya benzetirdi.
///
///   3. ESLESME ADIMI ZORUNLU. Sosyal hesap dogrulanmis olsa bile
///      oturum ACILMAZ; tesis kodu + telefon + SMS gerekir. Brief'in
///      merkez kurali: "sosyal hesap kimlik dogrulama YONTEMIDIR,
///      eslesme anahtari degil".
///
///   4. SMS DOGRULANINCA OTURUM ACILIR.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/auth_repository_impl.dart';
import 'package:mobile/src/features/auth/data/oauth_tarayici.dart';
import 'package:mobile/src/features/auth/domain/oauth_repository.dart';
import 'package:mobile/src/features/auth/domain/oauth_sonuc.dart';
import 'package:mobile/src/features/auth/domain/token_pair.dart';
import 'package:mobile/src/features/auth/presentation/auth_controller.dart';
import 'package:mobile/src/features/auth/presentation/sosyal_giris.dart';

import 'helpers/l10n_test_app.dart';

class _SahteOauth implements OauthRepository {

  /// (P211 §1) Cok tesisli yonetici secimi — bu testin olctugu akista
  /// cagrilmaz; arayuz uyesi oldugu icin uygulanir.
  @override
  Future<void> tesisSec({
    required String secimJetonu,
    required String tenantId,
  }) async {}
  _SahteOauth({this.liste = const [], this.sonuc});

  final List<String> liste;

  /// `null` = KULLANICI VAZGECTI (arayuzun sozlesmesi).
  final OauthSonuc? sonuc;

  final baglananlar = <({String tesis, String telefon})>[];
  final dogrulananlar = <String>[];

  @override
  Future<List<String>> saglayicilar() async => liste;

  @override
  Future<OauthSonuc?> akis(String saglayici) async => sonuc;

  @override
  Future<({String tesisAd, String telefonMaskeli})> baglanBasla({
    required String baglamaJetonu,
    required String tesisKodu,
    required String telefon,
  }) async {
    baglananlar.add((tesis: tesisKodu, telefon: telefon));
    return (tesisAd: 'Oltu Sitesi', telefonMaskeli: '+9053***201');
  }

  @override
  Future<void> baglanDogrula({
    required String baglamaJetonu,
    required String telefon,
    required String kod,
  }) async {
    dogrulananlar.add(kod);
  }

  @override
  Future<({String durum, String? tesisAd})> rolTamamla({
    required String baglamaJetonu,
    required String tesisKodu,
    String? rol,
  }) async {
    // (P194) GIRIS akisi rol GONDERMEZ; kayit alani '<yok>' olur.
    baglananlar.add((tesis: tesisKodu, telefon: rol ?? '<yok>'));
    return (durum: 'giris', tesisAd: 'Oltu Sitesi');
  }

  @override
  Future<({String durum})> rolTamamlaDogrula({
    required String baglamaJetonu,
    required String tesisKodu,
    String? rol,
    required String kod,
  }) async {
    dogrulananlar.add(kod);
    return (durum: 'giris');
  }
}

ProviderContainer _kap(_SahteOauth sahte) {
  final c = ProviderContainer(
    overrides: [oauthRepositoryProvider.overrideWithValue(sahte)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('YAPILANDIRILMAMISSA hicbir dugme cizilmez', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          oauthRepositoryProvider.overrideWithValue(_SahteOauth()),
        ],
        child: l10nApp(const Scaffold(body: SosyalGirisDugmeleri())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('ACIK saglayicilar dugme olur', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          oauthRepositoryProvider.overrideWithValue(
            _SahteOauth(liste: const ['google', 'apple']),
          ),
        ],
        child: l10nApp(const Scaffold(body: SosyalGirisDugmeleri())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sosyal-google')), findsOneWidget);
    expect(find.byKey(const Key('sosyal-apple')), findsOneWidget);
    expect(find.byKey(const Key('sosyal-microsoft')), findsNothing);
    // Marka adi CEVRILMEZ; cevrilen sey onu saran cumledir.
    expect(find.textContaining('Google'), findsOneWidget);
  });

  test('VAZGECME hata uretmez ve oturum acmaz', () async {
    // `akis` null doner: kullanici tarayiciyi kapatti.
    final c = _kap(_SahteOauth(liste: const ['google']));
    await c.read(authControllerProvider.notifier).oauthAkisi('google');
    final s = c.read(authControllerProvider);
    expect(s.errorMessage, isNull);
    expect(s.hataKimligi, isNull);
    expect(s.status, isNot(AuthStatus.authenticated));
  });

  test('ESLESME GEREKIYORSA oturum ACILMAZ, baglama jetonu tasinir', () async {
    final c = _kap(
      _SahteOauth(
        liste: const ['google'],
        sonuc: const OauthSonuc(
          durum: 'baglama_gerekli',
          saglayici: 'google',
          baglamaJetonu: 'jeton-1',
          relay: true,
        ),
      ),
    );
    await c.read(authControllerProvider.notifier).oauthAkisi('google');
    final s = c.read(authControllerProvider);
    expect(s.status, isNot(AuthStatus.authenticated),
        reason: 'sosyal hesap TEK BASINA oturum acmamali');
    expect(s.oauthBaglamaJetonu, 'jeton-1');
    expect(s.oauthSaglayici, 'google');
    // Apple private relay bayragi ARAYUZE tasinir: kullanici o adrese
    // posta gonderilemeyecegini bilmeli.
    expect(s.oauthRelay, isTrue);
  });

  test('SMS DOGRULANINCA oturum acilir', () async {
    final sahte = _SahteOauth(
      liste: const ['google'],
      sonuc: const OauthSonuc(
        durum: 'baglama_gerekli',
        saglayici: 'google',
        baglamaJetonu: 'jeton-1',
      ),
    );
    final c = _kap(sahte);
    final n = c.read(authControllerProvider.notifier);
    await n.oauthAkisi('google');

    await n.oauthBaglanBasla(tesisKodu: 'OLTU-260715', telefon: '+905321112201');
    expect(sahte.baglananlar.single.tesis, 'OLTU-260715');
    expect(c.read(authControllerProvider).kodBekleniyor, isTrue);

    await n.oauthBaglanDogrula(telefon: '+905321112201', kod: '424242');
    expect(sahte.dogrulananlar, ['424242']);
    expect(c.read(authControllerProvider).status, AuthStatus.authenticated);
    // Baglama jetonu TUKETILIR: ekran giris moduna geri doner.
    expect(c.read(authControllerProvider).oauthBaglamaJetonu, isNull);
  });

  test('KIMLIK ZATEN BAGLIYSA oturum dogrudan acilir', () async {
    final c = _kap(
      _SahteOauth(
        liste: const ['google'],
        sonuc: OauthSonuc(
          durum: 'giris',
          jetonlar: TokenPair(
            accessToken: 'a',
            refreshToken: 'r',
            tokenType: 'Bearer',
            expiresIn: 900,
          ),
        ),
      ),
    );
    await c.read(authControllerProvider.notifier).oauthAkisi('google');
    expect(c.read(authControllerProvider).status, AuthStatus.authenticated);
  });

  test('VAZGEC baglama durumunu temizler', () async {
    final c = _kap(
      _SahteOauth(
        liste: const ['google'],
        sonuc: const OauthSonuc(
          durum: 'baglama_gerekli',
          saglayici: 'google',
          baglamaJetonu: 'jeton-1',
        ),
      ),
    );
    final n = c.read(authControllerProvider.notifier);
    await n.oauthAkisi('google');
    n.oauthIptal();
    expect(c.read(authControllerProvider).oauthBaglamaJetonu, isNull);
    expect(c.read(authControllerProvider).oauthSaglayici, isNull);
  });

  test('OZEL SEMA arka uctaki `oauth_mobil_donus` ile AYNI', () {
    // Ikisi ayrisirsa tarayici oturumu HIC kapanmaz ve kullanici bos bir
    // sayfada kalir. Deger AndroidManifest'teki intent-filter'da da
    // yaziyor; uc yerin uclusu tutmali.
    expect(kOauthSemasi, 'com.app.yonetiyor');
  });
}
