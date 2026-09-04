import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/theme/home_tokens.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/presentation/widgets/home_shell.dart';
import 'package:mobile/src/features/profile/data/avatar_api.dart';
import 'helpers/l10n_test_app.dart';
import 'package:mobile/src/core/i18n/locale_controller.dart';

Widget _shell({
  UserRole role = UserRole.yonetici,
  int unread = 0,
  int currentIndex = 0,
  void Function(int)? onDestinationSelected,
  void Function(String)? onModul,
  VoidCallback? onBildir,
  VoidCallback? onProfile,
  VoidCallback? onLogout,
}) =>
    ProviderScope(
      // (P212 §2) App-bar avatari artik [myAvatarProvider]'i izler:
      // TEK `/me` cagrisiyla hem fotograf hem AD gelir (bas harf yedegi
      // icin ad gerekiyor). Gecersiz kilinmazsa test gercek bir istek
      // baslatir ve "A Timer is still pending" ile duser.
      overrides: [
        myAvatarProvider.overrideWith((ref) async => (url: null, ad: 'Ali Veli')),
      ],
      child: MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: supportedLocales,
      localizationsDelegates: testLocalizationsDelegates,
        home: HomeShell(
          role: role,
          unreadCount: unread,
          currentIndex: currentIndex,
          onDestinationSelected: onDestinationSelected ?? (_) {},
          onModul: onModul ?? (_) {},
          onBildir: onBildir ?? () {},
          onProfile: onProfile,
          onLogout: onLogout,
          body: const Text('GOVDE'),
        ),
      ),
    );

void main() {
  group('HomeShell — app-bar + govde + 5 yuvali alt-bar (referans)', () {
    testWidgets('govdeyi ve 4 sekme etiketini gosterir', (tester) async {
      await tester.pumpWidget(_shell());
      expect(find.text('GOVDE'), findsOneWidget);
      for (final label in [
        'Ana Sayfa',
        'Bildirimler',
        'Raporlar',
        'Ayarlar',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // (P154 / Asama 7.2) MERKEZ FAB'IN YAZISI KALDIRILDI (brief: "sadece
      // '+' kalsin"). Gorunen metin yok — ama ADI DURUYOR: asagidaki
      // erisilebilirlik testi onu olcer.
      expect(find.text('Olay Bildir'), findsNothing);
    });

    testWidgets('FAB YAZISIZ ama ADSIZ DEGIL (ekran okuyucu)', (tester) async {
      // Ciplak bir "+" ekran okuyucuya yalnizca "dugme" der; kullanici
      // neyi actigini bilemez. Gorsel sadelesmenin bedeli erisilebilirlik
      // OLMAMALI — ad `Semantics`e tasindi.
      final tanit = tester.ensureSemantics();
      await tester.pumpWidget(_shell());
      expect(
        find.bySemanticsLabel('Olay Bildir'),
        findsOneWidget,
        reason: 'FAB erisilebilir adini kaybetti',
      );
      tanit.dispose();
    });

    testWidgets('marka kilidi: kelime isareti + harf arali alt-baslik',
        (tester) async {
      await tester.pumpWidget(_shell());
      expect(find.text('Yönetiyor'), findsOneWidget);
      expect(find.text('GÜVENLİK & DANIŞMANLIK'), findsOneWidget);
    });

    testWidgets('resident merkez FAB adi "Talep / Bildir" (homeBildirLabel)',
        (tester) async {
      // Etiket role gore hâlâ DEGISIR; yalnizca gorunur olmaktan cikip
      // erisilebilir ada tasindi.
      final tanit = tester.ensureSemantics();
      await tester.pumpWidget(_shell(role: UserRole.resident));
      expect(find.bySemanticsLabel('Talep / Bildir'), findsOneWidget);
      tanit.dispose();
    });

    testWidgets('merkez FAB dokununca onBildir cagrilir', (tester) async {
      var bildir = 0;
      await tester.pumpWidget(_shell(onBildir: () => bildir++));
      await tester.tap(find.byKey(const Key('home-fab')));
      expect(bildir, 1);
    });

    testWidgets('merkez FAB 56px daire (referans olcusu)', (tester) async {
      await tester.pumpWidget(_shell());
      final daire = tester.getSize(find.descendant(
        of: find.byKey(const Key('home-fab')),
        matching: find.byType(Container),
      ));
      expect(daire.width, HomeTokens.fabSize);
      expect(daire.height, HomeTokens.fabSize);
    });

    testWidgets('aktif yuva DOLGU ikon + mavi; pasif yuva ince ikon',
        (tester) async {
      await tester.pumpWidget(_shell(currentIndex: 0));
      final aktif = tester.widget<Icon>(find.byIcon(Icons.home));
      expect(aktif.color, HomeTokens.primary);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget); // pasif
      expect(find.byIcon(Icons.settings), findsNothing);
    });

    testWidgets('"Raporlar" destinasyonu dokununca onDestinationSelected(3)',
        (tester) async {
      int? selected;
      await tester.pumpWidget(_shell(onDestinationSelected: (i) => selected = i));
      await tester.tap(find.text('Raporlar'));
      expect(selected, 3);
    });

    testWidgets(
        'okunmamis > 0: sayi HEM app-bar zilinde HEM Bildirimler sekmesinde '
        '(referans ikisini de rozetler); 0 iken hic sayi yok', (tester) async {
      await tester.pumpWidget(_shell(unread: 3));
      expect(find.text('3'), findsNWidgets(2));

      await tester.pumpWidget(_shell(unread: 0));
      expect(find.text('0'), findsNothing);
    });

    testWidgets('avatar dokununca hesap menusu acilir: Profil -> onProfile, '
        'Çıkış Yap -> onLogout (logout her rolde erisilir)', (tester) async {
      var profile = 0;
      var logout = 0;
      await tester.pumpWidget(_shell(
        onProfile: () => profile++,
        onLogout: () => logout++,
      ));

      await tester.tap(find.byKey(const Key('home-avatar')));
      await tester.pumpAndSettle();
      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('Çıkış Yap'), findsOneWidget);

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(profile, 1);

      await tester.tap(find.byKey(const Key('home-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çıkış Yap'));
      await tester.pumpAndSettle();
      expect(logout, 1);
    });

    testWidgets('hamburger cekmecesi rolun TUM modullerini listeler; secim '
        'rotayi geri verir (referans izgaradan cikan moduller kaybolmaz)',
        (tester) async {
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      String? rota;
      await tester.pumpWidget(_shell(
        role: UserRole.security,
        onModul: (r) => rota = r,
      ));

      // NOT: hamburger tooltip'i artik YERELLESTIRILMIS (tr: "Gezinme
      // menüsünü aç") — dile bagli metin yerine Scaffold uzerinden acilir.
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pumpAndSettle();

      // Referans hizli erisim seridinde OLMAYAN moduller cekmecede duruyor.
      //
      // (P154 / Asama 7.2) ARAMA CEKMECEYE DARALTILDI: saha rollerinin
      // alt-bar 4. yuvasi artik "Gorevlerim" ve ayni metin ekranda IKI
      // KEZ bulunuyor. Bu bir kopya DEGIL — biri sekme, oteki modul
      // girisi; testin daralmasi gereken sey sorgunun kapsami.
      Finder cekmecede(String metin) => find.descendant(
            of: find.byType(Drawer),
            matching: find.text(metin),
          );
      expect(cekmecede('Turlarım'), findsOneWidget);
      expect(cekmecede('Görevlerim'), findsOneWidget);
      expect(cekmecede('Demirbaş'), findsOneWidget);

      await tester.tap(cekmecede('Demirbaş'));
      await tester.pumpAndSettle();
      expect(rota, '/assets');
    });
  });
}
