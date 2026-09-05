/// ANA EKRAN i18n — dil degistirme (ornek widget kumesi), RTL (Arapca)
/// yon denetimi ve KIMLIK/METIN ayriminin dogrulanmasi.
///
/// Kritik iddia (kart-kimligi refactor'u): kartlarin kimligi DILDEN BAGIMSIZ
/// sabittir; ekranda gorunen baslik aktif dilden cozulur. Dil degisince
/// duzen/rota/sayac eslemeleri AYNEN calisir, yalniz metin degisir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/features/announcements/data/announcement_api.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/cameras/data/cameras_api.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';
import 'package:mobile/src/features/complaints/data/complaint_api.dart';
import 'package:mobile/src/features/home/data/activity_api.dart';
import 'package:mobile/src/features/home/data/home_api.dart';
import 'package:mobile/src/features/home/data/home_repository.dart';
import 'package:mobile/src/features/home/domain/activity_models.dart';
import 'package:mobile/src/features/home/domain/home_kart_id.dart';
import 'package:mobile/src/features/home/domain/home_varyant.dart';
import 'package:mobile/src/features/home/presentation/saha_home_screen.dart';
import 'package:mobile/src/features/home/presentation/widgets/hizli_erisim.dart';
import 'package:mobile/src/features/kargo/data/kargo_api.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/scan/data/scan_outbox.dart';
import 'package:mobile/src/features/shifts/data/shifts_api.dart';
import 'package:mobile/src/features/tenant/data/tenant_api.dart';
import 'package:mobile/src/features/weather/data/weather_api.dart';
import 'package:mobile/src/features/yonetici_iletisim/data/yonetici_iletisim_api.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

class _FakeOutbox extends ScanOutbox {
  @override
  ScanOutboxState build() => const ScanOutboxState(loaded: true);
}

/// Plakali bir akis satiri: RTL'de LTR kalmasi gereken dizi.
final _plakaliAkis = [
  ActivityItem(
    id: 'arac_giris:1',
    tur: ActivityTur.aracGiris,
    // TUR 15: baslik KIMLIKTEN cozulur; plaka VERI'dir ve LTR dizidir.
    baslikKimlik: AkisBaslik.aracGiris,
    veri: const {'plaka': '34 ABC 123'},
    zaman: DateTime(2026, 7, 25, 9, 47),
    kaynakId: '1',
  ),
];

Widget _saha(UserRole role, Locale locale, {List<ActivityItem>? akis}) =>
    ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) async =>
            Profile(ad: 'Mehmet', role: role.wire, aranabilir: false)),
        scanOutboxProvider.overrideWith(_FakeOutbox.new),
        unreadNotificationCountProvider.overrideWith((ref) async => 0),
        weatherProvider.overrideWith((ref) async => throw Exception('offline')),
        tenantSettingsProvider
            .overrideWith((ref) async => throw Exception('offline')),
        yoneticiIletisimProvider
            .overrideWith((ref) async => throw Exception('offline')),
        shiftsProvider.overrideWith((ref) async => const []),
        kargoListProvider.overrideWith((ref) async => const []),
        sonDuyurularProvider.overrideWith((ref) async => const []),
        sonHareketlerProvider.overrideWith((ref) async => akis ?? const []),
        anaEkranKameralariProvider.overrideWith((ref) async => const [
              Camera(
                id: 'c1',
                ad: 'Ana Kapı',
                konum: 'Ana Kapı - Giriş',
                streamUrl: 'https://x/y.m3u8',
                sakinGorebilir: true,
              ),
            ]),
        icerdekiZiyaretciSayisiProvider.overrideWith((ref) async => 1),
        bugunkuAracGirisSayisiProvider.overrideWith((ref) async => 4),
        yeniIhlalSayisiProvider.overrideWith((ref) async => 2),
        aktifGorevSayisiProvider.overrideWith((ref) async => 6),
        uzerimdekiZimmetSayisiProvider.overrideWith((ref) async => 3),
        acikSikayetSayisiProvider.overrideWith((ref) async => 5),
        yaklasanEtkinlikSayisiProvider.overrideWith((ref) async => 2),
      ],
      child: l10nApp(SahaHomeScreen(role: role), locale: locale),
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('kart KIMLIGI dilden bagimsiz, BASLIK dile bagli', () {
    test('taban kartlar metin TASIMAZ: yalniz kimlik + (varsa) etiket kimligi',
        () {
      const mock = MockHomeRepository();
      for (final varyant in HomeVaryant.values) {
        for (final k in mock.hizliErisim(varyant)) {
          // Sayac metni yalniz ekran katmaninda doldurulur.
          expect(k.altMetin, isNull, reason: '${varyant.name}/${k.id.name}');
        }
      }
    });

    test('ayni kimlik 7 dilde FARKLI metin verir (tr/en/ar ornegi)', () async {
      final tr = await AppLocalizations.delegate.load(const Locale('tr'));
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final ar = await AppLocalizations.delegate.load(const Locale('ar'));
      expect(kartBasligi(tr, HomeKartId.gorevlerim), 'Görevlerim');
      expect(kartBasligi(en, HomeKartId.gorevlerim), 'My tasks');
      expect(kartBasligi(ar, HomeKartId.gorevlerim), 'مهامي');
      // Ozet kutulari + sabit etiketler de kimlikten cozulur.
      expect(ozetEtiketi(en, OzetKutuId.toplamDaire), 'Total units');
      expect(kartEtiketi(en, HomeKartEtiketId.aylikOzet), 'Monthly summary');
    });
  });

  group('ana ekran dil degistirme (gorevli izgarasi)', () {
    testWidgets('tr → en → ru: kart basliklari ve SAYAC metinleri degisir, '
        'duzen AYNI kalir', (tester) async {
      _tall(tester);

      await tester.pumpWidget(_saha(UserRole.security, const Locale('tr')));
      await tester.pumpAndSettle();
      expect(find.text('Görevlerim'), findsWidgets);
      expect(find.text('6 Bekliyor'), findsOneWidget);
      expect(find.text('1 İçeride'), findsOneWidget);
      expect(find.byType(HizliErisimIzgarasi), findsOneWidget);

      await tester.pumpWidget(_saha(UserRole.security, const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text('My tasks'), findsWidgets);
      expect(find.text('6 pending'), findsOneWidget);
      expect(find.text('1 inside'), findsOneWidget);
      expect(find.text('Görevlerim'), findsNothing);
      // Duzen degismedi: ayni izgara, ayni kart sayisi.
      expect(find.byType(HizliErisimIzgarasi), findsOneWidget);

      await tester.pumpWidget(_saha(UserRole.security, const Locale('ru')));
      await tester.pumpAndSettle();
      expect(find.text('Мои задачи'), findsWidgets);
      // ru cogul: 6 → "many" kategorisi.
      expect(find.text('6 ожидают'), findsOneWidget);
    });

    testWidgets('bolum basliklari + kamera seridi de dile uyar (en)',
        (tester) async {
      _tall(tester);
      await tester.pumpWidget(_saha(UserRole.security, const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text('Live camera'), findsOneWidget);
      expect(find.text('Recent activity'), findsNothing); // akis bos → bolum yok
      expect(find.text('Live'), findsOneWidget); // kamera karti durumu
    });
  });

  group('RTL: Arapca ana ekran', () {
    testWidgets('yon RTL; izgara + akis satirlari cizilir; PLAKA dizisi LTR '
        'izolasyonlu kalir', (tester) async {
      _tall(tester);
      await tester.pumpWidget(
        _saha(UserRole.security, const Locale('ar'), akis: _plakaliAkis),
      );
      await tester.pumpAndSettle();

      // 1) Yon
      final ctx = tester.element(find.byType(SahaHomeScreen));
      expect(Directionality.of(ctx), TextDirection.rtl);

      // 2) Izgara Arapca basliklarla cizildi
      expect(find.byType(HizliErisimIzgarasi), findsOneWidget);
      expect(find.text('مهامي'), findsWidgets); // Görevlerim
      expect(find.text('المركبات'), findsWidgets); // Araç Plaka

      // 3) Akis satiri: baslik ARAPCA (tur 15 — eskiden sunucudan TR gelir
      //    ve Arapca ekranda "Araç Girişi" yazardi), plaka LTR dizi olarak
      //    OLDUGU GIBI kalir (VERI cevrilmez).
      expect(find.text('دخول مركبة'), findsOneWidget);
      expect(find.text('Araç Girişi'), findsNothing);
      expect(find.text('34 ABC 123'), findsOneWidget);

      // 4) Plaka gibi diziler icin izolasyon yardimcisi RTL'de sarar
      expect(ltrIzole('34 ABC 123').codeUnits.first, 0x2068);
      expect(tlIsaretli(125000, 'ar').codeUnits.first, 0x2068);

      expect(tester.takeException(), isNull);
    });

    // ---- TUR 23: EKRAN SURUSU ----
  // Panelde (tur 21) paneli calistirip URETILEN ciktiya bakmak, statik
  // taramanin goremedigi metinleri bulmustu. Mobilde karsiligi bu: ekrani
  // 6 dilde cizip GORUNEN her Text'i tara. Sozlukte olmayan (kaynakta
  // unutulmus) bir sabit ancak boyle yakalanir.
  for (final rol in [UserRole.security, UserRole.tesisGorevlisi]) {
    testWidgets('SURUS: ${rol.wire} ana ekrani 6 dilde TR sabit tasimaz',
        (tester) async {
      _tall(tester);
      for (final dil in surusDilleri) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(_saha(rol, Locale(dil)));
        await tester.pumpAndSettle();
        // VERI (cevrilmez): profil adi, plaka, kontrol noktasi adi —
        // ucu de sunucudan/tenant'tan gelir. Surusun isi UI SABITLERINI
        // yakalamak; veriyi cevirmek zaten YANLIS olurdu.
        trSizintisiYok(tester, dil,
            veri: const {'Mehmet', '34 ABC 123', 'Ana Kapı'});
      }
    });
  }

  testWidgets('RTL: kart izgarasi TASMAZ (Arapca metinler daha uzun)',
        (tester) async {
      _tall(tester);
      await tester.pumpWidget(_saha(UserRole.tesisGorevlisi, const Locale('ar')));
      await tester.pumpAndSettle();
      // RenderFlex overflow olsaydi takeException yakalardi.
      expect(tester.takeException(), isNull);
      expect(find.byType(HizliErisimIzgarasi), findsOneWidget);
    });
  });
}
