// (P144) Karo adi = gittigi ekranin basligi -> serit karti artik
// "Vardiyalar" (/vardiyalar). BOLUM BASLIGI hala "Vardiya Durumu";
// bolum basligi karo degil, P144 kapsami disinda. Ikisi AYRI olcusun.
// (P144) KANONIK AD = EKRANIN KENDI BASLIGI (Kerem'in karari): ayni
// ekrana giden butun karolar o ekranin AppBar basligini tasir.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/cameras/data/cameras_api.dart';
import 'package:mobile/src/features/cameras/domain/camera_models.dart';
import 'package:mobile/src/features/home/data/home_api.dart';
import 'package:mobile/src/features/home/data/activity_api.dart';
import 'package:mobile/src/features/home/domain/activity_models.dart';
import 'package:mobile/src/features/home/presentation/saha_home_screen.dart';
import 'package:mobile/src/features/home/presentation/widgets/home_states.dart';
import 'package:mobile/src/features/kargo/data/kargo_api.dart';
import 'package:mobile/src/features/kargo/domain/kargo_models.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';
import 'package:mobile/src/features/scan/data/scan_outbox.dart';
import 'package:mobile/src/features/scan/domain/outbox_entry.dart';
import 'package:mobile/src/features/shifts/data/shifts_api.dart';
import 'package:mobile/src/features/shifts/domain/shift_models.dart';
import 'package:mobile/src/features/tenant/data/tenant_api.dart';
import 'package:mobile/src/features/tenant/domain/tenant_models.dart';
import 'package:mobile/src/features/weather/data/weather_api.dart';
import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

/// Depoya dokunmayan sahte kuyruk (path_provider yok) — bekleyen sayisi
/// kadar 'bekliyor' kaydi tasir.
class _FakeOutbox extends ScanOutbox {
  _FakeOutbox(this._pending);
  final int _pending;

  @override
  ScanOutboxState build() => ScanOutboxState(
        loaded: true,
        entries: [
          for (var i = 0; i < _pending; i++)
            OutboxEntry(
              idempotencyKey: 'k$i',
              nfcTagUid: 'uid',
              okutmaZamani: DateTime(2026, 1, 1),
              enqueuedAt: DateTime(2026, 1, 1),
            ),
        ],
      );
}

Widget _app(
  UserRole role, {
  Locale dil = const Locale('tr'),
  int pending = 0,
  int unread = 0,
  List<Shift> vardiyalar = const [
    Shift(
        id: 'v1',
        ad: 'Sabah Vardiyası',
        baslangicSaat: '06:00',
        bitisSaat: '14:00',
        gunTipi: 'hafta_ici'),
  ],
  String? tesisAd,
  List<Kargo> kargolar = const [],
  int icerdeZiyaretci = 0,
  int aracGiris = 0,
  int yeniIhlal = 0,
  List<ActivityItem> hareketler = const [],
  Object? hareketHata,
}) =>
    ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) async =>
            Profile(ad: 'Mehmet', role: role.wire, aranabilir: false)),
        scanOutboxProvider.overrideWith(() => _FakeOutbox(pending)),
        unreadNotificationCountProvider.overrideWith((ref) async => unread),
        // Hava/tesis uclari testte aga cikmasin.
        weatherProvider.overrideWith((ref) async => throw Exception('offline')),
        tenantSettingsProvider.overrideWith((ref) async => tesisAd == null
            ? throw Exception('offline')
            : TenantSettings(tenantId: 't1', ad: tesisAd)),
        shiftsProvider.overrideWith((ref) async => vardiyalar),
        kargoListProvider.overrideWith((ref) async => kargolar),
        // G1/G2/G3 sayaclari: hepsi ?limit=1 -> meta.total (liste tasinmaz).
        icerdekiZiyaretciSayisiProvider
            .overrideWith((ref) async => icerdeZiyaretci),
        bugunkuAracGirisSayisiProvider.overrideWith((ref) async => aracGiris),
        yeniIhlalSayisiProvider.overrideWith((ref) async => yeniIhlal),
        sonHareketlerProvider.overrideWith((ref) async {
          if (hareketHata != null) throw hareketHata;
          return hareketler;
        }),
        camerasProvider.overrideWith((ref) async => const [
              Camera(id: 'c1', ad: 'Ana Kapı', streamUrl: 'https://x/s.m3u8'),
            ]),
      ],
      child: l10nApp(SahaHomeScreen(role: role), locale: dil),
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('SahaHomeScreen — gorevli.jpeg (guvenlik + tesis gorevlisi)', () {
    testWidgets('security: karsilama + tesis secici + serit + GERCEK vardiya '
        '+ Son Hareketler + Canlı Kamera', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(
        UserRole.security,
        tesisAd: 'Mavi Sitesi',
        hareketler: [
          ActivityItem(
            id: 'ziyaretci_giris:z1',
            tur: ActivityTur.ziyaretciGiris,
            baslikKimlik: AkisBaslik.ziyaretciGiris,
            sunucuBaslik: 'Ziyaretçi Girişi',
            sunucuAltMetin: 'Ahmet Yılmaz — Daire 12',
            zaman: DateTime(2026, 7, 23, 10),
            kaynakId: 'z1',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Merhaba, Mehmet'), findsOneWidget);
      // Tesis secici: gercek tenant adi + asagi ok.
      expect(find.text('Mavi Sitesi'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      // Hava ucu hatali → uydurma 24°C YOK.
      expect(find.text('24°C'), findsNothing);

      // Referans serit kartlari.
      expect(find.text('Vardiyalar'), findsOneWidget);
      expect(find.text('Kargo'), findsOneWidget);
      expect(find.text('Ziyaretçiler'), findsOneWidget);

      // Vardiya bolumu GERCEK /shifts verisinden.
      expect(find.text('Vardiya Durumu'), findsOneWidget);
      expect(find.text('Sabah Vardiyası'), findsOneWidget);
      expect(find.text('06:00 - 14:00'), findsOneWidget);

      // Son Hareketler GERCEK akistan + Canlı Kamera (gercek kamera).
      expect(find.text('Son Hareketler'), findsOneWidget);
      expect(find.text('Ziyaretçi Girişi'), findsOneWidget);
      expect(find.text('Canlı Kamera'), findsOneWidget);
      expect(find.text('Ana Kapı'), findsOneWidget);
      // Referans (uydurma) satirlar ARTIK YOK.
      expect(find.text('Kamera İhlal Tespiti'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('tesis adi YOKKEN alt satir HIC cizilmez (uydurma tesis adi '
        'yok)', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.security));
      await tester.pumpAndSettle();
      expect(find.text('Mavi Residence'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    });

    testWidgets('serit sayaclarinin TAMAMI gercek uctan: kargo bekleyen + '
        'ziyaretci ICERIDE + arac girisi + yeni ihlal ("Yakında" KALMADI)',
        (tester) async {
      _tall(tester);
      final now = DateTime.now();
      await tester.pumpWidget(_app(
        UserRole.security,
        tesisAd: 'Mavi Sitesi',
        kargolar: [
          Kargo(
            id: 'k1',
            unitId: 'u1',
            unitNo: '12',
            firma: 'Aras',
            durum: KargoDurum.bekliyor,
            kaydedenUserId: 'g1',
            createdAt: now,
          ),
        ],
        icerdeZiyaretci: 1,
        aracGiris: 4,
        yeniIhlal: 2,
      ));
      await tester.pumpAndSettle();

      expect(find.text('1 Bekliyor'), findsOneWidget); // Kargo
      // G3: "bugunku kayit" degil, halen ICERIDE olanlar (sunucu suzgeci).
      expect(find.text('1 İçeride'), findsOneWidget);
      expect(find.text('1 Bugün'), findsNothing);
      // Serit yatay kaydirilir; plaka + ihlal kartlari sonda.
      await tester.drag(find.text('Kargo'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('4 Giriş'), findsOneWidget); // G1 Araç Plaka
      expect(find.text('2 Yeni'), findsOneWidget); // G2 İhlaller
      expect(find.text('Yakında'), findsNothing);
    });

    testWidgets('tesisGorevlisi: KVKK — Kargo/Ziyaretçi/Araç Plaka/İhlaller '
        'kartlari YOK; vardiya + son hareketler + KENDI is kartlari VAR',
        (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(
        UserRole.tesisGorevlisi,
        hareketler: [
          ActivityItem(
            id: 'gorev_tamamlama:c1',
            tur: ActivityTur.gorevTamamlama,
            baslikKimlik: AkisBaslik.gorevTamamlama,
            sunucuBaslik: 'Görev Tamamlandı',
            sunucuAltMetin: 'Merdiven — Temizlik',
            zaman: DateTime(2026, 7, 23, 10),
            renk: ActivityRenk.olumlu,
            kaynakId: 'c1',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Kargo'), findsNothing);
      expect(find.text('Ziyaretçiler'), findsNothing);
      expect(find.text('Araç Plaka'), findsNothing);
      // /violations tesis_gorevlisine 403 — kart cizilmez ('—' de gostermez).
      expect(find.text('İhlaller'), findsNothing);
      // Kamera bolumu ARTIK bu rolde de var: sunucu yalniz sakine acilmis
      // kameralari doner (suzgec SUNUCUDA — istemci ek suzgec uygulamaz).
      expect(find.text('Canlı Kamera'), findsOneWidget);
      // Rolun KENDI is kartlari izgarada.
      for (final baslik in ['Demirbaş', 'Site Kuralları']) {
        expect(find.text(baslik), findsOneWidget, reason: baslik);
      }
      // (P154 / Asama 7.2) "Görevlerim" ARTIK IKI YERDE: izgara karti +
      // saha rollerinin alt-bar 4. yuvasi (brief: "guvenlik + tesis
      // gorevlisi -> Gorevlerim"). Kopya DEGIL; biri modul karti, oteki
      // sekme.
      expect(find.text('Görevlerim'), findsNWidgets(2));

      expect(find.text('Vardiyalar'), findsOneWidget); // serit karti
      expect(find.text('Vardiya Durumu'), findsOneWidget); // bolum basligi
      expect(find.text('Son Hareketler'), findsOneWidget);
      expect(find.text('Görev Tamamlandı'), findsOneWidget);
    });

    testWidgets('vardiya YOKKEN bolum HIC cizilmez (uydurma vardiya yok)',
        (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.security, vardiyalar: const []));
      await tester.pumpAndSettle();

      expect(find.text('Vardiya Durumu'), findsNothing); // bolum basligi yok
      expect(find.text('Öğle Vardiyası'), findsNothing);
      expect(find.text('Kerem Aşçı'), findsNothing); // mock yonetici karti yok
      expect(find.text('Vardiyalar'), findsOneWidget); // serit karti durur
    });

    testWidgets('Son Hareketler HATASI: "Yüklenemedi" + yeniden dene',
        (tester) async {
      _tall(tester);
      await tester.pumpWidget(
          _app(UserRole.security, hareketHata: Exception('500')));
      await tester.pumpAndSettle();

      expect(find.byType(HomeBolumHatasi), findsOneWidget);
      expect(find.text('Yeniden dene'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('security: okunmamis bildirim rozeti zil + sekmede gorunur '
        '(RBAC izinli rol)', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.security, unread: 7));
      await tester.pumpAndSettle();
      expect(find.text('7'), findsNWidgets(2));
    });

    testWidgets('tesisGorevlisi: /notifications RBAC DISI — rozet HIC '
        'gorunmez (401 uretecek istek de atilmaz)', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.tesisGorevlisi, unread: 7));
      await tester.pumpAndSettle();
      expect(find.text('7'), findsNothing);
    });

    testWidgets('outbox bekleyen > 0: seride "Gönderim Kuyruğu" karti girer '
        '(cevrimdisi saha kaniti gorunur kalir)', (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.tesisGorevlisi, pending: 3));
      await tester.pumpAndSettle();
      expect(find.text('Gönderim Kuyruğu'), findsOneWidget);
      expect(find.text('3 bekleyen'), findsOneWidget);
    });

    testWidgets('outbox bos: serit referans duzeninde kalir (ek kart YOK)',
        (tester) async {
      _tall(tester);
      await tester.pumpWidget(_app(UserRole.tesisGorevlisi));
      await tester.pumpAndSettle();
      expect(find.text('Gönderim Kuyruğu'), findsNothing);
    });
  });

  // ---- TUR 32: KOYU TEMA ----
  testWidgets('KOYU TEMA: saha ana ekrani 7 dilde (kontrast + tasma)',
      (tester) async {
    _tall(tester);
    await koyuTemaSurusu(
        tester, (dil) => _app(UserRole.security, dil: Locale(dil)),
        veri: surusVerisi);
  });

  // ---- TUR 33: KLAVYE ----
  testWidgets('KLAVYE: ana ekran (odak sirasi + tuzak + dokunma-yalniz)',
      (tester) async {
    _tall(tester);
    await klavyeSurusu(tester, (dil) => _app(UserRole.security, dil: Locale(dil)));
  });

  // ---- TUR 34: FOTOGRAFLI VERI (avatar ucu + kart gorselleri) ----
  testWidgets('FOTOGRAFLI: ana ekran (bes eksen birden)', (tester) async {
    _tall(tester);
    await fotografliSurus(tester, (dil) => _app(UserRole.security, dil: Locale(dil)), veri: surusVerisi);
  });
}
