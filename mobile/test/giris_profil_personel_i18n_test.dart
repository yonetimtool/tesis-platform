/// GIRIS + PROFIL + PERSONEL i18n (tur 8) — dil degistirme ornegi,
/// KIMLIK/METIN ayrimi ve RTL (Arapca) denetimi.
///
/// Kritik iddialar:
///   * `UserRole.label` KALDIRILDI — rol adi ARTIK yalniz `rolAdi(l10n, rol)`
///     ile cozulur. Bu ayrimin bir yan urunu: `home` modulunde (tur 2'de
///     "bitti" sayilan) IKI cagri yeri TR sabit yaziyordu; ikisi de duzeldi.
///   * Parola kurali metin degil KIMLIK dondurur
///     ([ParolaKuraliHatasi]); dort ekran ayni cozucuyu kullanir.
///   * Giris denetleyicisi hata KIMLIGI dondurur (`GirisAkisHatasi`) —
///     "oturum sona erdi" artik cevrilir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/core/validators/password_rule.dart';
import 'package:mobile/src/features/auth/domain/giris_hatasi.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/auth/presentation/giris_hata_metni.dart';
import 'package:mobile/src/features/auth/presentation/login_screen.dart';
import 'package:mobile/src/features/auth/presentation/rol_adi.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/profile/presentation/profile_screen.dart';
import 'package:mobile/src/features/staff/data/staff_api.dart';
import 'package:mobile/src/features/staff/presentation/staff_screen.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

// --------------------------------------------------------------------------
// Sahteler (ag YOK)
// --------------------------------------------------------------------------
Profile _profil({String role = 'yonetici', String? telefon}) => Profile(
      ad: 'Mehmet Yilmaz',
      role: role,
      telefon: telefon,
      aranabilir: true,
    );

StaffMember _personel({bool aktif = true, String role = 'security'}) =>
    StaffMember(id: 's-1', ad: 'Guard A', role: role, isActive: aktif);

Widget _girisEkrani(Locale locale) => ProviderScope(
      child: l10nApp(const LoginScreen(), locale: locale),
    );

Widget _profilEkrani(Locale locale, {Profile? profil}) => ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) async => profil ?? _profil()),
      ],
      child: l10nApp(const ProfileScreen(), locale: locale),
    );

Widget _personelEkrani(Locale locale, {List<StaffMember>? items}) =>
    ProviderScope(
      overrides: [
        fieldStaffProvider.overrideWith((ref) async => items ?? [_personel()]),
      ],
      child: l10nApp(const StaffScreen(), locale: locale),
    );

/// Ayni `ProviderScope` tipini ust uste pump etmek kabi yenilemez (tur 7
/// notu) — senaryolar arasinda bos agac cizilir.
Future<void> _sifirla(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void _ekran(WidgetTester tester, {double g = 430, double h = 1600}) {
  tester.view.physicalSize = Size(g, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  // ================================= GIRIS ================================
  testWidgets('GIRIS: tr → en → ru dil degisimi (alanlar + buton + onay kutusu)',
      (tester) async {
    _ekran(tester);
    for (final (locale, telefon, parola, buton, hatirla) in [
      (
        const Locale('tr'),
        'Cep telefonu',
        'Parola veya geçici kod',
        'Giriş yap',
        'Beni hatırla'
      ),
      (
        const Locale('en'),
        'Mobile number',
        'Password or temporary code',
        'Sign in',
        'Remember me'
      ),
      (
        const Locale('ru'),
        'Мобильный номер',
        'Пароль или временный код',
        'Войти',
        'Запомнить меня'
      ),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(_girisEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(telefon), findsOneWidget, reason: '$locale telefon');
      expect(find.text(parola), findsOneWidget, reason: '$locale parola');
      expect(find.text(buton), findsOneWidget, reason: '$locale buton');
      expect(find.text(hatirla), findsOneWidget, reason: '$locale hatirla');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('GIRIS: bos form dogrulamasi aktif dilde yazar', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_girisEkrani(const Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Phone number is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('girisHataMetni: oturum sona erdi 7 dilde cevrilir', () async {
    for (final (kod, beklenen) in [
      ('tr', 'Oturumunuz sona erdi. Lütfen tekrar giriş yapın.'),
      ('en', 'Your session has expired. Please sign in again.'),
      ('de', 'Ihre Sitzung ist abgelaufen. Bitte melden Sie sich erneut an.'),
    ]) {
      final l10n = await AppLocalizations.delegate.load(Locale(kod));
      expect(
        girisHataMetni(l10n, GirisAkisHatasi.oturumSonaErdi),
        beklenen,
        reason: kod,
      );
      // Kimlik ONCE: sunucu metni varsa bile kimlik kazanir.
      expect(
        girisHatasiCoz(l10n, GirisAkisHatasi.oturumSonaErdi, 'sunucu'),
        beklenen,
        reason: kod,
      );
      // Kimlik yoksa sunucu metni oldugu gibi.
      expect(girisHatasiCoz(l10n, null, 'sunucu'), 'sunucu', reason: kod);
    }
  });

  // ============================= PAROLA KURALI ============================
  test('parolaKuraliHatasi: KIMLIK dondurur (metin degil)', () {
    expect(parolaKuraliHatasi('kisa'), ParolaKuraliHatasi.kisa);
    expect(parolaKuraliHatasi('abcdefgh1!'), ParolaKuraliHatasi.buyukHarfYok);
    expect(parolaKuraliHatasi('Abcdefgh!'), ParolaKuraliHatasi.rakamYok);
    expect(parolaKuraliHatasi('Abcdefgh1'), ParolaKuraliHatasi.sembolYok);
    expect(parolaKuraliHatasi('Abcdefg1!'), isNull);
    // Turkce buyuk harf de gecerli sayilir (regex Turkce harfleri tanir).
    expect(parolaKuraliHatasi('Ğüzelparola1!'), isNull);
  });

  test('parolaHataMetni: dort kural 7 dilde cevrilir', () async {
    for (final kod in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
      final l10n = await AppLocalizations.delegate.load(Locale(kod));
      for (final hata in ParolaKuraliHatasi.values) {
        expect(parolaKuraliMetni(l10n, hata).trim(), isNotEmpty, reason: kod);
      }
      expect(parolaHataMetni(l10n, 'Abcdefg1!'), isNull, reason: kod);
      expect(parolaHataMetni(l10n, 'kisa'), isNotNull, reason: kod);
    }
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(parolaHataMetni(en, 'kisa'), 'Must be at least 8 characters');
  });

  // ============================== ROL ADLARI ==============================
  test('rolAdi: enum label YOK, ceviri TEK KAYNAK (7 dil)', () async {
    for (final (kod, guvenlik, sakin) in [
      ('tr', 'Güvenlik', 'Site Sakini'),
      ('en', 'Security', 'Resident'),
      ('ar', 'الأمن', 'ساكن'),
      ('ru', 'Охрана', 'Житель'),
      ('de', 'Sicherheit', 'Bewohner'),
      ('fr', 'Sécurité', 'Résident'),
      ('es', 'Seguridad', 'Residente'),
    ]) {
      final l10n = await AppLocalizations.delegate.load(Locale(kod));
      expect(rolAdi(l10n, UserRole.security), guvenlik, reason: kod);
      expect(rolAdi(l10n, UserRole.resident), sakin, reason: kod);
      // Her rolun karsiligi VAR (bos ceviri yok).
      for (final rol in UserRole.values) {
        expect(rolAdi(l10n, rol).trim(), isNotEmpty, reason: '$kod/$rol');
      }
    }
  });

  // ================================ PROFIL ================================
  testWidgets('PROFIL: tr → en → fr dil degisimi (baslik + kartlar + rol)',
      (tester) async {
    _ekran(tester);
    for (final (locale, baslik, parolaKart, rol) in [
      (const Locale('tr'), 'PROFİL', 'Parola değiştir', 'Site Yöneticisi'),
      (const Locale('en'), 'PROFILE', 'Change password', 'Site Manager'),
      (
        const Locale('fr'),
        'PROFIL',
        'Changer le mot de passe',
        'Gestionnaire du site'
      ),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(_profilEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(baslik), findsOneWidget, reason: '$locale AppBar');
      expect(find.text(parolaKart), findsOneWidget, reason: '$locale parola');
      expect(find.text(rol), findsOneWidget, reason: '$locale rol adi');
      expect(find.text('Mehmet Yilmaz'), findsOneWidget); // sunucu verisi
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('PROFIL: telefon bos ise cevrilmis yer tutucu', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_profilEkrani(const Locale('de')));
    await tester.pumpAndSettle();
    expect(find.text('Keine Nummer angegeben'), findsOneWidget);

    await _sifirla(tester);
    await tester.pumpWidget(
      _profilEkrani(const Locale('de'), profil: _profil(telefon: '+9055511')),
    );
    await tester.pumpAndSettle();
    // Iki yerde gorunur: baslik satiri + iletisim kartinin on-dolu alani.
    expect(find.text('+9055511'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('PROFIL: parola alanlari kural metnini aktif dilde gosterir',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_profilEkrani(const Locale('en')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), 'kisa');
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    expect(find.text('Must be at least 8 characters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // =============================== PERSONEL ===============================
  testWidgets('PERSONEL: tr → en → es dil degisimi (baslik + FAB + rol)',
      (tester) async {
    _ekran(tester);
    for (final (locale, baslik, ekle, rol) in [
      (const Locale('tr'), 'SAHA PERSONELİ', 'Personel ekle', 'Güvenlik'),
      (const Locale('en'), 'FIELD STAFF', 'Add staff', 'Security'),
      (
        const Locale('es'),
        'PERSONAL DE CAMPO',
        'Añadir personal',
        'Seguridad'
      ),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(_personelEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(baslik), findsOneWidget, reason: '$locale AppBar');
      expect(find.text(ekle), findsOneWidget, reason: '$locale FAB');
      expect(find.text(rol), findsOneWidget, reason: '$locale rol adi');
      expect(find.text('Guard A'), findsOneWidget); // sunucu verisi
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('PERSONEL: pasif cipi + menude aktifles/pasifles cevrilir',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(
      _personelEkrani(const Locale('en'), items: [_personel(aktif: false)]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Inactive'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Activate'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PERSONEL: rol segmentleri rolAdi ile cizilir (tek kaynak)',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_personelEkrani(const Locale('de')));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Sicherheit'), findsWidgets);
    expect(find.text('Haustechniker'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PERSONEL: bos liste metni cevrilir', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(
      _personelEkrani(const Locale('en'), items: const []),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No field staff yet.\nAdd one from the bottom right.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  // ================================= RTL =================================
  testWidgets('RTL: GIRIS Arapca — form TASMAZ', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_girisEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('تسجيل الدخول'))),
        TextDirection.rtl);
    expect(find.text('كلمة المرور أو الرمز المؤقت'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'giris formu Arapca metinlerle tasmamali');
  });

  testWidgets('RTL: PROFIL Arapca — uc kart TASMAZ', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_profilEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('تغيير كلمة المرور'))),
        TextDirection.rtl);
    expect(tester.takeException(), isNull,
        reason: 'profil kartlari Arapca metinlerle tasmamali');
  });

  testWidgets('RTL: PERSONEL Arapca — liste + ekleme formu TASMAZ',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_personelEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('إضافة موظف'))),
        TextDirection.rtl);
    expect(tester.takeException(), isNull, reason: 'personel listesi');

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('رقم الجوال'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'personel formu Arapca metinlerle tasmamali');
  });

  // Dar ekran (320 dp): uzun yardimci metinler + iki satirli helper'lar.
  testWidgets('DAR EKRAN 320 dp: giris + profil + personel formu TASMAZ',
      (tester) async {
    _ekran(tester, g: 320, h: 2000);
    for (final (etiket, ekran) in [
      ('giris', _girisEkrani(const Locale('tr'))),
      ('profil', _profilEkrani(const Locale('tr'))),
      ('personel', _personelEkrani(const Locale('tr'))),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(ekran);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$etiket 320');
    }

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'personel formu 320');
  });

  // ---- TUR 24: EKRAN SURUSU ----
  testWidgets('SURUS: giris ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_girisEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });

  // ---- TUR 26: DAR EKRAN SURUSU (320 dp x 6 dil) ----
  testWidgets('DAR 320dp: giris ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _girisEkrani(Locale(dil)),
        veri: surusVerisi);
  });

  // ---- TUR 27: YAZI OLCEGI SURUSU (2.0x x 6 dil) ----
  testWidgets('OLCEK 2x: giris ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _girisEkrani(Locale(dil)), veri: surusVerisi);
  });
  testWidgets('OLCEK 2x: profil ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _profilEkrani(Locale(dil)), veri: surusVerisi);
  });
  testWidgets('OLCEK 2x: personel ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _personelEkrani(Locale(dil)), veri: surusVerisi);
  });

  // ---- TUR 29: EKRAN OKUYUCU SURUSU ----
  testWidgets('OKUYUCU: giris ekrani (etiket + dokunma hedefi + dil)',
      (tester) async {
    await ekranOkuyucuSurusu(tester, (dil) => _girisEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('OKUYUCU: profil ekrani (etiket + dokunma hedefi + dil)',
      (tester) async {
    await ekranOkuyucuSurusu(tester, (dil) => _profilEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('OKUYUCU: personel ekrani (etiket + dokunma hedefi + dil)',
      (tester) async {
    await ekranOkuyucuSurusu(tester, (dil) => _personelEkrani(Locale(dil)),
        veri: surusVerisi);
  });

  // ---- TUR 32: KOYU TEMA ----
  testWidgets('KOYU TEMA: girisEkrani 7 dilde (kontrast + tasma)',
      (tester) async {
    await koyuTemaSurusu(tester, (dil) => _girisEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('KOYU TEMA: profilEkrani 7 dilde (kontrast + tasma)',
      (tester) async {
    await koyuTemaSurusu(tester, (dil) => _profilEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('KOYU TEMA: personelEkrani 7 dilde (kontrast + tasma)',
      (tester) async {
    await koyuTemaSurusu(tester, (dil) => _personelEkrani(Locale(dil)),
        veri: surusVerisi);
  });
}
