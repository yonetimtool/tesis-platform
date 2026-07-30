/// P8 — ARAC GECISI (G1) + IHLAL (G2) + OTOPARK (G4) ekranlari.
///
/// Uclerinin de UCU vardi ama EKRANI yoktu: ana ekran kartlari "Bu bölüm
/// yakında" diyordu. Olculenler:
///
///   1. MODEL — cozumleme + `acik` (cikis_zamani null => arac iceride) +
///      durum/kaynak enum'lari + gecis kurallari (kapatma yalniz admin,
///      terminal durumdan cikis yok).
///   2. ROL — kim listeyi gorur, kim eylem yapar (auth.md §4 aynasi).
///   3. EKRAN — 403 hata bandi DEGIL aciklayici bos durum cizer; yetkisiz
///      rolde eylem dugmesi HIC cizilmez; cikis/durum eylemleri UCU cagirir.
///   4. Bes eksen surusu (tasma / kontrast / ekran okuyucu / klavye).
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/domain/parking_occupancy.dart';
import 'package:mobile/src/features/vehicle_pass/data/vehicle_pass_api.dart';
import 'package:mobile/src/features/vehicle_pass/domain/vehicle_pass_models.dart';
import 'package:mobile/src/features/vehicle_pass/presentation/parking_screen.dart';
import 'package:mobile/src/features/vehicle_pass/presentation/vehicle_pass_screen.dart';
import 'package:mobile/src/features/violations/data/violation_api.dart';
import 'package:mobile/src/features/violations/domain/violation_models.dart';
import 'package:mobile/src/features/violations/presentation/violations_screen.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

// --------------------------------------------------------------------------
// Sahte uclar
// --------------------------------------------------------------------------

class _SahteAracApi extends VehiclePassApi {
  _SahteAracApi({
    this.items = const [],
    this.doluluk = const ParkingOccupancy(dolu: 3, kapasite: 10, oran: 30),
    this.listeHatasi,
  }) : super(Dio());

  final List<VehiclePass> items;
  final ParkingOccupancy doluluk;
  final ApiException? listeHatasi;

  final cikisVerilen = <String>[];
  final olusturulan = <VehiclePassDraft>[];
  ApiException? cikisHatasi;

  @override
  Future<List<VehiclePass>> fetchAll({
    GecisSuzgeci suzgec = GecisSuzgeci.tumu,
    String? plaka,
  }) async {
    if (listeHatasi != null) throw listeHatasi!;
    return items
        .where((v) => suzgec.acik == null || v.acik == suzgec.acik)
        .toList();
  }

  @override
  Future<ParkingOccupancy> occupancy() async => doluluk;

  @override
  Future<VehiclePass> checkout(String id) async {
    if (cikisHatasi != null) throw cikisHatasi!;
    cikisVerilen.add(id);
    return items.firstWhere((v) => v.id == id);
  }

  @override
  Future<VehiclePass> create(VehiclePassDraft draft) async {
    olusturulan.add(draft);
    return _gecis(id: 'yeni', plaka: draft.plaka);
  }
}

class _SahteIhlalApi extends ViolationApi {
  _SahteIhlalApi({this.items = const [], this.listeHatasi}) : super(Dio());

  final List<Ihlal> items;
  final ApiException? listeHatasi;
  final degisen = <(String, IhlalDurum)>[];
  ApiException? degistirHatasi;

  @override
  Future<List<Ihlal>> fetchAll({IhlalDurum? durum}) async {
    if (listeHatasi != null) throw listeHatasi!;
    return items.where((i) => durum == null || i.durum == durum).toList();
  }

  @override
  Future<Ihlal> durumDegistir(String id, IhlalDurum durum) async {
    if (degistirHatasi != null) throw degistirHatasi!;
    degisen.add((id, durum));
    return items.firstWhere((i) => i.id == id);
  }
}

VehiclePass _gecis({
  String id = 'g1',
  String plaka = '34ABC123',
  bool acik = true,
  String? unitNo,
  bool ziyaretci = false,
}) => VehiclePass(
  id: id,
  plaka: plaka,
  girisZamani: DateTime.utc(2026, 7, 8, 10),
  cikisZamani: acik ? null : DateTime.utc(2026, 7, 8, 12),
  ziyaretciMi: ziyaretci,
  unitNo: unitNo,
  kaydedenUserId: 'u1',
  kaydedenAd: 'Mehmet',
  createdAt: DateTime.utc(2026, 7, 8, 10),
);

Ihlal _ihlal({
  String id = 'i1',
  IhlalDurum durum = IhlalDurum.yeni,
  String baslik = 'Hatali park',
}) => Ihlal(
  id: id,
  baslik: baslik,
  aciklama: 'Otopark girisi kapatilmis',
  kaynak: IhlalKaynak.devriye,
  konum: 'Ana Kapı',
  durum: durum,
  olusturanUserId: 'u1',
  olusturanAd: 'Mehmet',
  createdAt: DateTime.utc(2026, 7, 8, 10),
  updatedAt: DateTime.utc(2026, 7, 8, 10),
);

const _403 = ApiException(code: 'forbidden', message: '', statusCode: 403);
const _409 = ApiException(code: 'conflict', message: '', statusCode: 409);

Widget _aracEkrani(
  UserRole rol,
  _SahteAracApi api, {
  Locale locale = const Locale('tr'),
}) => ProviderScope(
  overrides: [
    vehiclePassApiProvider.overrideWithValue(api),
    currentUserRoleProvider.overrideWith((ref) async => rol),
  ],
  child: l10nApp(const VehiclePassScreen(), locale: locale),
);

Widget _ihlalEkrani(
  UserRole rol,
  _SahteIhlalApi api, {
  Locale locale = const Locale('tr'),
}) => ProviderScope(
  overrides: [
    violationApiProvider.overrideWithValue(api),
    currentUserRoleProvider.overrideWith((ref) async => rol),
  ],
  child: l10nApp(const ViolationsScreen(), locale: locale),
);

Widget _otoparkEkrani(
  UserRole rol,
  _SahteAracApi api, {
  Locale locale = const Locale('tr'),
}) => ProviderScope(
  overrides: [
    vehiclePassApiProvider.overrideWithValue(api),
    currentUserRoleProvider.overrideWith((ref) async => rol),
  ],
  child: l10nApp(const ParkingScreen(), locale: locale),
);

void main() {
  group('MODEL — arac gecisi', () {
    test('cikis_zamani null => arac ICERIDE', () {
      final acik = VehiclePass.fromJson({
        'id': 'g1',
        'plaka': '34ABC123',
        'giris_zamani': '2026-07-08T10:00:00Z',
        'ziyaretci_mi': false,
        'kaydeden_user_id': 'u1',
        'created_at': '2026-07-08T10:00:00Z',
      });
      expect(acik.acik, isTrue);
      expect(acik.cikisZamani, isNull);

      final kapali = VehiclePass.fromJson({
        'id': 'g2',
        'plaka': '34ABC123',
        'giris_zamani': '2026-07-08T10:00:00Z',
        'cikis_zamani': '2026-07-08T12:00:00Z',
        'ziyaretci_mi': true,
        'kaydeden_user_id': 'u1',
        'created_at': '2026-07-08T10:00:00Z',
      });
      expect(kapali.acik, isFalse);
      expect(kapali.ziyaretciMi, isTrue);
    });

    test('suzgec `?acik=` degeri: tumu -> parametre YOK', () {
      expect(GecisSuzgeci.tumu.acik, isNull);
      expect(GecisSuzgeci.iceride.acik, isTrue);
      expect(GecisSuzgeci.cikmis.acik, isFalse);
    });

    test('draft: bos alanlar govdeye HIC yazilmaz', () {
      const d = VehiclePassDraft(plaka: '34 abc 123', aracTanim: '', unitNo: '');
      expect(d.toJson(), {'plaka': '34 abc 123', 'ziyaretci_mi': false});
      // unit_id GONDERILMEZ: sozlesme unit_id VE unit_no birlikte gelirse 422.
      expect(d.toJson().containsKey('unit_id'), isFalse);
    });
  });

  group('MODEL — ihlal', () {
    test('durum/kaynak cozumlemesi + bilinmeyen deger savunmasi', () {
      expect(IhlalDurum.fromWire('inceleniyor'), IhlalDurum.inceleniyor);
      expect(IhlalDurum.fromWire('kapatildi'), IhlalDurum.kapatildi);
      expect(IhlalDurum.fromWire('bilinmeyen'), IhlalDurum.yeni);
      expect(IhlalKaynak.fromWire('kamera'), IhlalKaynak.kamera);
      expect(IhlalKaynak.fromWire(null), IhlalKaynak.manuel);
    });

    test('GECIS KURALLARI: kapatma yalniz admin, terminal cikissiz', () {
      // security: yeni -> inceleniyor (kapatamaz)
      expect(ihlalSonrakiDurumlar(IhlalDurum.yeni, adminMi: false), [
        IhlalDurum.inceleniyor,
      ]);
      expect(
        ihlalSonrakiDurumlar(IhlalDurum.inceleniyor, adminMi: false),
        isEmpty,
      );
      // admin: her iki adim
      expect(ihlalSonrakiDurumlar(IhlalDurum.yeni, adminMi: true), [
        IhlalDurum.inceleniyor,
        IhlalDurum.kapatildi,
      ]);
      expect(ihlalSonrakiDurumlar(IhlalDurum.inceleniyor, adminMi: true), [
        IhlalDurum.kapatildi,
      ]);
      // TERMINAL: kapaliya hicbir rol dokunamaz
      expect(ihlalSonrakiDurumlar(IhlalDurum.kapatildi, adminMi: true), isEmpty);
    });
  });

  group('ROL (auth.md §4 aynasi)', () {
    test('arac gecisi listesi: YALNIZ admin + security', () {
      expect(UserRole.admin.canViewVehiclePasses, isTrue);
      expect(UserRole.security.canViewVehiclePasses, isTrue);
      for (final r in [
        UserRole.yonetici,
        UserRole.resident,
        UserRole.tesisGorevlisi,
        UserRole.unknown,
      ]) {
        expect(r.canViewVehiclePasses, isFalse, reason: r.name);
      }
    });

    test('otopark AGREGATI: bilinen tum roller', () {
      for (final r in UserRole.values.where((r) => r != UserRole.unknown)) {
        expect(r.canViewParking, isTrue, reason: r.name);
      }
      expect(UserRole.unknown.canViewParking, isFalse);
    });

    test('ihlal: yonetici OKUR ama yonetmez; kapatma yalniz admin', () {
      expect(UserRole.yonetici.canViewViolations, isTrue);
      expect(UserRole.yonetici.canManageViolations, isFalse);
      expect(UserRole.security.canManageViolations, isTrue);
      expect(UserRole.security.canCloseViolations, isFalse);
      expect(UserRole.admin.canCloseViolations, isTrue);
      expect(UserRole.resident.canViewViolations, isFalse);
      expect(UserRole.tesisGorevlisi.canViewViolations, isFalse);
    });
  });

  group('EKRAN — arac gecisleri', () {
    testWidgets('security: liste + CIKIS dugmesi (yalniz ACIK gecislerde)', (
      tester,
    ) async {
      final api = _SahteAracApi(
        items: [
          _gecis(id: 'g1', plaka: '34ABC123', unitNo: 'A-1'),
          _gecis(id: 'g2', plaka: '06XYZ99', acik: false),
        ],
      );
      await tester.pumpWidget(_aracEkrani(UserRole.security, api));
      await tester.pumpAndSettle();

      expect(find.text('34ABC123'), findsOneWidget);
      expect(find.text('06XYZ99'), findsOneWidget);
      // Yalniz ACIK gecis cikis dugmesi tasir.
      expect(find.text('Çıkış ver'), findsOneWidget);
      expect(find.text('Daire A-1'), findsOneWidget);
    });

    testWidgets('CIKIS: onay -> uc cagrilir', (tester) async {
      final api = _SahteAracApi(items: [_gecis(id: 'g1')]);
      await tester.pumpWidget(_aracEkrani(UserRole.security, api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Çıkış ver'));
      await tester.pumpAndSettle();
      expect(find.text('Çıkış verilsin mi?'), findsOneWidget);
      // Diyalogdaki onay dugmesi (FilledButton) — ayni etiketli iki oge var.
      await tester.tap(find.widgetWithText(FilledButton, 'Çıkış ver'));
      await tester.pumpAndSettle();
      expect(api.cikisVerilen, ['g1']);
    });

    testWidgets('CIKIS 409: "zaten kapatilmis" gosterilir', (tester) async {
      final api = _SahteAracApi(items: [_gecis(id: 'g1')])
        ..cikisHatasi = _409;
      await tester.pumpWidget(_aracEkrani(UserRole.security, api));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çıkış ver'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Çıkış ver'));
      await tester.pumpAndSettle();
      expect(find.text('Bu geçiş zaten kapatılmış'), findsOneWidget);
    });

    testWidgets('403: hata bandi DEGIL aciklayici bos durum', (tester) async {
      final api = _SahteAracApi(listeHatasi: _403);
      await tester.pumpWidget(_aracEkrani(UserRole.yonetici, api));
      await tester.pumpAndSettle();
      expect(
        find.text('Araç geçiş listesi yalnız yönetim ve güvenlik içindir'),
        findsOneWidget,
      );
      // Yetki yokken FAB ve suzgec cizilmez.
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('İçeride'), findsNothing);
    });

    testWidgets('bos liste: arama varken FARKLI metin', (tester) async {
      final api = _SahteAracApi();
      await tester.pumpWidget(_aracEkrani(UserRole.security, api));
      await tester.pumpAndSettle();
      expect(find.text('Kayıtlı araç geçişi yok'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '99ZZZ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Bu plakayla eşleşen geçiş yok'), findsOneWidget);
    });
  });

  group('EKRAN — ihlaller', () {
    testWidgets('security: "İncelemeye al" VAR, "Kaydı kapat" YOK', (
      tester,
    ) async {
      final api = _SahteIhlalApi(items: [_ihlal()]);
      await tester.pumpWidget(_ihlalEkrani(UserRole.security, api));
      await tester.pumpAndSettle();
      expect(find.text('İncelemeye al'), findsOneWidget);
      expect(find.text('Kaydı kapat'), findsNothing);
    });

    testWidgets('admin: kapatma onay ister ve uc cagrilir', (tester) async {
      final api = _SahteIhlalApi(
        items: [_ihlal(durum: IhlalDurum.inceleniyor)],
      );
      await tester.pumpWidget(_ihlalEkrani(UserRole.admin, api));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydı kapat'));
      await tester.pumpAndSettle();
      expect(
        find.text('Kayıt kapatılsın mı? Kapatılan ihlal yeniden açılamaz.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydı kapat'));
      await tester.pumpAndSettle();
      expect(api.degisen, [('i1', IhlalDurum.kapatildi)]);
    });

    testWidgets('yonetici: OKUR ama hicbir eylem dugmesi yok', (tester) async {
      final api = _SahteIhlalApi(items: [_ihlal()]);
      await tester.pumpWidget(_ihlalEkrani(UserRole.yonetici, api));
      await tester.pumpAndSettle();
      expect(find.text('Hatali park'), findsOneWidget);
      expect(find.text('İncelemeye al'), findsNothing);
      expect(find.text('Kaydı kapat'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('KAPALI kayit: hicbir gecis dugmesi cizilmez', (tester) async {
      final api = _SahteIhlalApi(items: [_ihlal(durum: IhlalDurum.kapatildi)]);
      await tester.pumpWidget(_ihlalEkrani(UserRole.admin, api));
      await tester.pumpAndSettle();
      expect(find.text('Kapatıldı'), findsWidgets);
      expect(find.text('İncelemeye al'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Kaydı kapat'), findsNothing);
    });

    testWidgets('403: aciklayici bos durum', (tester) async {
      final api = _SahteIhlalApi(listeHatasi: _403);
      await tester.pumpWidget(_ihlalEkrani(UserRole.resident, api));
      await tester.pumpAndSettle();
      expect(
        find.text('İhlal kayıtları yalnız yönetim ve güvenlik içindir'),
        findsOneWidget,
      );
    });
  });

  group('EKRAN — otopark', () {
    testWidgets('kapasite VAR: dolu/kapasite + yuzde + bos', (tester) async {
      final api = _SahteAracApi(
        doluluk: const ParkingOccupancy(dolu: 3, kapasite: 10, oran: 30),
      );
      await tester.pumpWidget(_otoparkEkrani(UserRole.yonetici, api));
      await tester.pumpAndSettle();
      expect(find.text('3 / 10'), findsOneWidget);
      expect(find.text('%30'), findsOneWidget);
      expect(find.text('Boş'), findsOneWidget);
      expect(find.text('7'), findsOneWidget); // 10 - 3
    });

    testWidgets('kapasite YOK: UYDURMA yuzde uretilmez', (tester) async {
      final api = _SahteAracApi(
        doluluk: const ParkingOccupancy(dolu: 3),
      );
      await tester.pumpWidget(_otoparkEkrani(UserRole.yonetici, api));
      await tester.pumpAndSettle();
      expect(find.text('3 araç'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('—'), findsOneWidget);
      expect(
        find.text(
          'Kapasite tanımlı değil — yalnız içerideki araç sayısı gösterilir',
        ),
        findsOneWidget,
      );
    });

    testWidgets('gecis listesi baglantisi YALNIZ yetkili rolde', (
      tester,
    ) async {
      final api = _SahteAracApi();
      await tester.pumpWidget(_otoparkEkrani(UserRole.security, api));
      await tester.pumpAndSettle();
      expect(find.text('Araç geçişlerini aç'), findsOneWidget);

      // AGACI TAMAMEN SOK: ayni tipteki ikinci `pumpWidget` elemanı yeniden
      // kullanir ve eski rolun AsyncValue verisi tazelenene dek yasar —
      // olcum sessizce ONCEKI role bakardi.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_otoparkEkrani(UserRole.resident, api));
      await tester.pumpAndSettle();
      expect(find.text('Araç geçişlerini aç'), findsNothing);
    });
  });

  group('BES EKSEN', () {
    testWidgets('arac gecisleri (bes eksen)', (tester) async {
      final api = _SahteAracApi(
        items: [
          _gecis(unitNo: 'A-1', ziyaretci: true),
          _gecis(id: 'g2', plaka: '06XYZ99', acik: false),
        ],
      );
      await tumEksenlerSurusu(
        tester,
        (dil) => _aracEkrani(UserRole.security, api, locale: Locale(dil)),
        veri: const {'34ABC123', '06XYZ99', 'A-1', 'Mehmet'},
      );
    });

    testWidgets('ihlaller (bes eksen)', (tester) async {
      final api = _SahteIhlalApi(
        items: [
          _ihlal(),
          _ihlal(id: 'i2', durum: IhlalDurum.kapatildi, baslik: 'Gurultu'),
        ],
      );
      await tumEksenlerSurusu(
        tester,
        (dil) => _ihlalEkrani(UserRole.admin, api, locale: Locale(dil)),
        veri: const {
          'Hatali park',
          'Gurultu',
          'Otopark girisi kapatilmis',
          'Ana Kapı',
          'Mehmet',
        },
      );
    });

    testWidgets('otopark (bes eksen)', (tester) async {
      final api = _SahteAracApi();
      await tumEksenlerSurusu(
        tester,
        (dil) => _otoparkEkrani(UserRole.yonetici, api, locale: Locale(dil)),
      );
    });
  });
}
