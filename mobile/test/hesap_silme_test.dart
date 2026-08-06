/// P112 — SELF-SERVIS HESAP SILME (App Store 5.1.1(v)).
///
/// Apple'in kurali kesin: hesap acilabiliyorsa **uygulama icinden**
/// silinebilmeli. Reddedilme sebebi olan uc sey ayri ayri olculur:
///   1. giris NOKTASI Ayarlar'da GORUNUYOR mu (bulunamayan bir silme yok
///      sayilir),
///   2. onay penceresi NE SILINIP NE KALDIGINI yaziyor mu (aidat kaydinin
///      kaldigini sonradan ogrenen kullanici kandirildigini dusunur),
///   3. cagri gercekten gidiyor ve YENIDEN KIMLIK DOGRULAMA (parola)
///      isteniyor mu.
///
/// Ayrica `deleted=false` yolunun **basari** sayildigi kilitlenir: o deger
/// "silinemedi" degil, "yasal saklama geregi anonimlestirildi" demektir.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/settings/presentation/settings_screen.dart';
import 'package:mobile/src/features/tenant/data/tenant_api.dart';
import 'package:mobile/src/features/tenant/domain/tenant_models.dart';

import 'helpers/l10n_test_app.dart';

class _SahteTenantApi extends TenantApi {
  _SahteTenantApi() : super(Dio());
  @override
  Future<TenantSettings> getSettings() async =>
      const TenantSettings(tenantId: 't-1', ad: 'Acme Plaza');
}

class _SahteProfilApi extends ProfileApi {
  _SahteProfilApi({this.tamSilindi = true, this.hata}) : super(Dio());

  final bool tamSilindi;
  final Object? hata;

  /// Gonderilen parolalar — YENIDEN KIMLIK DOGRULAMANIN kaniti.
  final gonderilenParolalar = <String>[];

  int kodIstegi = 0;

  @override
  Future<void> hesapSilmeKoduIste() async => kodIstegi++;

  @override
  Future<bool> deleteAccount({String? currentPassword, String? kod}) async {
    // (P149) Parolasiz kullanicida `kod` gelir; hangisi geldiyse kaydet
    // ki testler "ne gonderildi"yi ayirt edebilsin.
    gonderilenParolalar.add(currentPassword ?? kod ?? '');
    if (hata != null) throw hata!;
    return tamSilindi;
  }
}

Widget _ayarlar({
  UserRole rol = UserRole.resident,
  ProfileApi? profil,
}) =>
    ProviderScope(
      overrides: [
        currentUserRoleProvider.overrideWith((ref) async => rol),
        tenantApiProvider.overrideWithValue(_SahteTenantApi()),
        if (profil != null) profileApiProvider.overrideWithValue(profil),
      ],
      child: l10nApp(const SettingsScreen(), locale: const Locale('tr')),
    );

/// Ayarlar listesini sona kadar kaydirip silme satirina dokunur.
///
/// `scrollUntilVisible` sonrasi OTURMA sarttir: kaydirma animasyonu
/// bitmeden dokunmak, ogeyi bulup dokunmayi BOSA gonderiyordu (yonetici
/// rolunde liste daha uzun oldugu icin yalniz orada dusuyordu — sessiz ve
/// role bagli bir olcum hatasi).
Future<void> _silmeyiAc(WidgetTester tester) async {
  final satir = find.text('Hesabımı sil');
  await tester.scrollUntilVisible(satir, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.ensureVisible(satir);
  await tester.pumpAndSettle();
  await tester.tap(satir);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('GIRIS NOKTASI: Ayarlar ekraninda silme satiri VAR',
      (tester) async {
    // Bulunamayan bir silme yolu, olmayan bir silme yoludur (5.1.1(v)).
    await tester.pumpWidget(_ayarlar());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Hesabımı sil'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Hesabımı sil'), findsOneWidget);
  });

  testWidgets('ONAY: pencere NE SILINIP NE KALDIGINI yaziyor', (tester) async {
    await tester.pumpWidget(_ayarlar());
    await tester.pumpAndSettle();
    await _silmeyiAc(tester);

    final metin = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    // SILINEN taraf.
    expect(metin, contains('cihaz kayıtlarınız silinir'));
    // KALAN taraf — bunu yazmamak, kullaniciyi yanlis bilgilendirmekti.
    expect(metin, contains('yasal saklama'));
    expect(metin, contains('anonim'));
  });

  testWidgets('DOKUNMA TEK BASINA SILMEZ: parola gerekiyor', (tester) async {
    final api = _SahteProfilApi();
    await tester.pumpWidget(_ayarlar(profil: api));
    await tester.pumpAndSettle();
    await _silmeyiAc(tester);

    // Parola BOSKEN onaya basmak istegi ATMAMALI.
    await tester.tap(find.text('Hesabımı kalıcı olarak sil'));
    await tester.pump();
    expect(api.gonderilenParolalar, isEmpty,
        reason: 'parola girilmeden silme istegi gitti');
    expect(find.text('Devam etmek için parolanızı girin.'), findsOneWidget);
  });

  testWidgets('BASARI: parola gonderilir ve SILINDI mesaji cizilir',
      (tester) async {
    final api = _SahteProfilApi(tamSilindi: true);
    await tester.pumpWidget(_ayarlar(profil: api));
    await tester.pumpAndSettle();
    await _silmeyiAc(tester);

    await tester.enterText(find.byType(TextField).last, 'Parolam123!');
    await tester.tap(find.text('Hesabımı kalıcı olarak sil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(api.gonderilenParolalar, ['Parolam123!']);
    expect(find.text('Hesabınız silindi.'), findsOneWidget);
  });

  testWidgets('ANONIMLESTIRME de BASARIDIR (deleted=false)', (tester) async {
    // `false` "silinemedi" DEGIL: gecmisi olan hesap yasal saklama geregi
    // anonimlestirildi demektir. Hata gibi gostermek, kullaniciya isinin
    // yapilmadigini soylemek olurdu.
    final api = _SahteProfilApi(tamSilindi: false);
    await tester.pumpWidget(_ayarlar(profil: api));
    await tester.pumpAndSettle();
    await _silmeyiAc(tester);

    await tester.enterText(find.byType(TextField).last, 'Parolam123!');
    await tester.tap(find.text('Hesabımı kalıcı olarak sil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final metin = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ');
    expect(metin, contains('anonim'));
  });

  testWidgets('SON YONETICI: sunucu metni AYNEN gosterilir, pencere KAPANMAZ',
      (tester) async {
    // 409'un metni NE YAPILACAGINI soyler ("once devredin"); istemcide
    // yeniden yazmak ayni cumleyi iki yerde tutmak olurdu.
    final api = _SahteProfilApi(
      hata: const ApiException(
        code: 'conflict',
        message: 'Bu tesisin tek yöneticisi sizsiniz. Hesabınızı silmeden '
            'önce başka bir yöneticiye yetki devredin.',
        statusCode: 409,
      ),
    );
    await tester.pumpWidget(_ayarlar(rol: UserRole.yonetici, profil: api));
    await tester.pumpAndSettle();
    await _silmeyiAc(tester);

    await tester.enterText(find.byType(TextField).last, 'Parolam123!');
    await tester.tap(find.text('Hesabımı kalıcı olarak sil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('yetki devredin'), findsOneWidget);
    // Pencere ACIK kalir: kullanici metni okuyup vazgecebilmeli.
    expect(find.text('Hesabımı kalıcı olarak sil'), findsOneWidget);
  });

  // (P149) PAROLASIZ KULLANICI DA HESABINI SILEBILMELI — Play'in "silme
  // yolu calismali" sartinin dogrudan karsiligi. Once ekran KOSULSUZ
  // parola istiyordu ve kendi kaydolan sakin burada TAKILIYORDU.
  testWidgets('PAROLASIZ: kod istenir ve PAROLA DEGIL KOD gonderilir',
      (tester) async {
    final api = _SahteProfilApi(tamSilindi: true);
    await tester.pumpWidget(_ayarlar(profil: api));
    await tester.pumpAndSettle();
    await _silmeyiAc(tester);

    await tester.tap(find.text('Parolam yok, kodla onayla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kod gönder'));
    await tester.pumpAndSettle();
    expect(api.kodIstegi, 1, reason: 'silme kodu SUNUCUDAN istenmeli');

    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.text('Hesabımı kalıcı olarak sil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.gonderilenParolalar, ['123456']);
  });
}
