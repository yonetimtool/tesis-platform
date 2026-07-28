/// BINA (harita/duzenleme) + TALEP i18n (tur 4) — dil degistirme ornegi,
/// KIMLIK/METIN ayrimi ve RTL (Arapca) denetimi.
///
/// Kritik iddialar:
///   * `DensityRenk` ve `UnitComplaintKategori` gibi alan tipleri GORUNEN METIN
///     TASIMAZ; etiket cizim aninda cozulur (`CameraUrlHatasi` emsali).
///   * Denetleyiciler `BuildContext`siz metin uretmez: hata KIMLIGI dondurur
///     (`AkisHatasi` / `TalepAkisHatasi`), ekran ceviriyi yazar.
///   * BINA ekranlari YERLESIM-YOGUNDUR (blok kutucugu 104x104, kat satirlari):
///     uzun Arapca/Almanca cevirilerde TASMA olmamali.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/akis_hatasi.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/building_map/data/bina_duzenleme_api.dart';
import 'package:mobile/src/features/building_map/data/building_map_api.dart';
import 'package:mobile/src/features/building_map/domain/bina_duzenleme_models.dart';
import 'package:mobile/src/features/building_map/domain/building_map_models.dart';
import 'package:mobile/src/features/building_map/presentation/bina_duzenleme_screen.dart';
import 'package:mobile/src/features/building_map/presentation/building_schematic_screen.dart';
import 'package:mobile/src/features/complaints/data/complaint_api.dart';
import 'package:mobile/src/features/complaints/domain/complaint_models.dart';
import 'package:mobile/src/features/complaints/domain/talep_hata.dart';
import 'package:mobile/src/features/complaints/presentation/complaints_screen.dart';
import 'package:mobile/src/features/complaints/presentation/talep_hata_metni.dart';
import 'package:mobile/src/features/tasks/data/task_category_api.dart';
import 'package:mobile/src/features/tasks/domain/task_category_models.dart';
import 'package:mobile/src/features/unit_complaints/data/unit_complaint_api.dart';
import 'package:mobile/src/features/unit_complaints/domain/unit_complaint_models.dart';
import 'package:mobile/src/features/unit_complaints/presentation/kategori_adi.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

// --------------------------------------------------------------------------
// Sahteler (ag YOK)
// --------------------------------------------------------------------------
class _FakeMapApi extends BuildingMapApi {
  _FakeMapApi(this._map) : super(Dio());
  final BuildingMap _map;

  @override
  Future<BuildingMap> fetchMap() async => _map;
}

class _FakeBinaApi extends BinaDuzenlemeApi {
  _FakeBinaApi() : super(Dio());

  @override
  Future<List<BuildingBlock>> listBlocks() async => const [
        BuildingBlock(id: 'b1', ad: 'A'),
      ];

  @override
  Future<List<EditorUnit>> listUnits() async => const [
        EditorUnit(id: 'u1', no: 'A-1', blok: 'A', kat: 1, sira: 1),
        EditorUnit(id: 'u2', no: 'A-2', blok: 'A', kat: 1, sira: 2),
      ];
}

/// Daire detay sayfasi sikayet listesi ceker — ag YOK.
class _FakeSikayetApi extends UnitComplaintApi {
  _FakeSikayetApi() : super(Dio());

  @override
  Future<List<UnitComplaint>> fetchForUnit(String unitId,
          {bool acikOnly = true}) async =>
      const [];

  @override
  Future<List<UnitComplaint>> fetchMine() async => const [];
}

class _FakeTalepApi extends ComplaintApi {
  _FakeTalepApi(this._items) : super(Dio(), TaskCategoryApi(Dio()));

  final List<Complaint> _items;

  @override
  Future<List<Complaint>> fetchAll({TalepDurum? durum}) async => _items;

  @override
  Future<List<TaskCategory>> listTaskCategories() async => const [];
}

Complaint _talep({TalepDurum durum = TalepDurum.acik}) => Complaint(
      id: 'c-1',
      acanUserId: 'u-1',
      acanAd: 'Acme Sakin',
      baslik: 'Asansor arizali',
      mesaj: 'A blok asansoru durdu.',
      durum: durum,
      fotograflar: const [],
      gecmis: const [],
      createdAt: DateTime.utc(2026, 7, 9, 10),
      updatedAt: DateTime.utc(2026, 7, 9, 10),
    );

Widget _talepEkrani(Locale locale, {UserRole role = UserRole.yonetici}) =>
    ProviderScope(
      overrides: [
        complaintApiProvider.overrideWithValue(_FakeTalepApi([_talep()])),
        currentUserRoleProvider.overrideWith((ref) async => role),
      ],
      child: l10nApp(const ComplaintsScreen(), locale: locale),
    );

BuildingMap _yonetimHaritasi() => BuildingMap(
      showsDensity: true,
      bloklar: [
        BuildingMapBlok(blok: 'A', katlar: [
          BuildingMapKat(kat: 1, units: [
            const BuildingMapUnit(
              unitId: 'id-A-2',
              unitNo: 'A-2',
              blok: 'A',
              kat: 1,
              sira: 1,
              complaintCount: 6,
              color: DensityRenk.kirmizi,
            ),
          ]),
        ]),
      ],
      unplaced: const [],
    );

Widget _semaEkrani(Locale locale, {UserRole role = UserRole.yonetici}) =>
    ProviderScope(
      overrides: [
        buildingMapApiProvider.overrideWithValue(_FakeMapApi(_yonetimHaritasi())),
        unitComplaintApiProvider.overrideWithValue(_FakeSikayetApi()),
        currentUserRoleProvider.overrideWith((ref) async => role),
      ],
      child: l10nApp(const BuildingSchematicScreen(), locale: locale),
    );

Widget _duzenlemeEkrani(Locale locale, {UserRole role = UserRole.yonetici}) =>
    ProviderScope(
      overrides: [
        binaDuzenlemeApiProvider.overrideWithValue(_FakeBinaApi()),
        currentUserRoleProvider.overrideWith((ref) async => role),
      ],
      child: l10nApp(const BinaDuzenlemeScreen(), locale: locale),
    );

void _ekran(WidgetTester tester, {double h = 1400}) {
  tester.view.physicalSize = Size(430, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  // ============================== BINA ==================================
  testWidgets('SEMA: tr → en → ru dil degisimi metinleri cevirir, duzeni korur',
      (tester) async {
    _ekran(tester);
    for (final (locale, yogunluk, sikayet) in [
      (const Locale('tr'), 'Yoğunluk:', '6 açık şikayet'),
      (const Locale('en'), 'Density:', '6 open complaints'),
      (const Locale('ru'), 'Плотность:', '6 открытых жалоб'),
    ]) {
      await tester.pumpWidget(_semaEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(yogunluk), findsOneWidget, reason: '$locale gosterge');
      // Esik ETIKETLERI sayidir — her dilde ayni (bilincli).
      expect(find.text('0–2'), findsOneWidget);
      expect(find.text('5+'), findsOneWidget);
      // Daire no SUNUCU verisi — cevrilmez.
      expect(find.text('A-2'), findsWidgets);
      // ICU cogul: sayac metni dile gore.
      await tester.tap(find.text('A-2').first);
      await tester.pumpAndSettle();
      expect(find.text(sikayet), findsOneWidget, reason: '$locale sayac');
      Navigator.of(tester.element(find.text(sikayet))).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('BINA DUZENLEME: tr → de dil degisimi (yerlesim korunur)',
      (tester) async {
    _ekran(tester);
    for (final (locale, blokEkle, daire) in [
      (const Locale('tr'), 'Blok', '2 daire'),
      (const Locale('de'), 'Block', '2 Wohnungen'),
    ]) {
      await tester.pumpWidget(_duzenlemeEkrani(locale));
      await tester.pumpAndSettle();

      // "+ Blok" kutucugu + blok kutucugundaki daire sayaci (ICU cogul).
      expect(find.text(blokEkle), findsWidgets, reason: '$locale kutucuk');
      expect(find.text(daire), findsOneWidget, reason: '$locale sayac');
      expect(tester.takeException(), isNull);
    }
  });

  test('KIMLIK: DensityRenk ve kategori enum\'lari METIN TASIMAZ', () async {
    // DensityRenk yalniz wire tasir (label alani KALDIRILDI — olu TR metindi).
    expect(DensityRenk.values.map((r) => r.wire).toList(),
        ['yesil', 'sari', 'kirmizi', 'unknown']);
    expect(DensityRenk.fromWire('sari'), DensityRenk.sari);

    // Kategori adi DILDEN cozulur (enum'un `label` alani cevrilmez sabittir).
    final tr = await AppLocalizations.delegate.load(const Locale('tr'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(unitComplaintKategoriAdi(tr, UnitComplaintKategori.gurultu),
        'Gürültü');
    expect(unitComplaintKategoriAdi(en, UnitComplaintKategori.gurultu),
        'Noise');
    expect(unitComplaintKategoriAdi(en, UnitComplaintKategori.zararVerme),
        'Damage');
  });

  test('KIMLIK: hata kimliklerinin HEPSI 7 dilde karsilik bulur', () async {
    for (final dil in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
      final l10n = await AppLocalizations.delegate.load(Locale(dil));
      for (final h in AkisHatasi.values) {
        expect(akisHataMetni(l10n, h).trim(), isNotEmpty, reason: '$dil/$h');
      }
      for (final h in TalepAkisHatasi.values) {
        expect(talepHataMetni(l10n, h, 'x').trim(), isNotEmpty,
            reason: '$dil/$h');
      }
    }
  });

  testWidgets('SEMA: denetleyici hata KIMLIGI ekranda cevrilir',
      (tester) async {
    _ekran(tester, h: 600);
    // Harita ucu patlar -> denetleyici AkisHatasi.beklenmeyen uretir.
    await tester.pumpWidget(ProviderScope(
      overrides: [
        buildingMapApiProvider.overrideWithValue(_PatlayanMapApi()),
        unitComplaintApiProvider.overrideWithValue(_FakeSikayetApi()),
        currentUserRoleProvider
            .overrideWith((ref) async => UserRole.yonetici),
      ],
      child: l10nApp(const BuildingSchematicScreen(),
          locale: const Locale('en')),
    ));
    await tester.pumpAndSettle();
    // TR sabiti DEGIL, aktif dilin metni.
    expect(find.textContaining('Beklenmeyen'), findsNothing);
    expect(find.textContaining('unexpected error'), findsOneWidget);
  });

  // ============================== TALEP =================================
  testWidgets('TALEP: tr → en → fr dil degisimi (sekme sayaclari + durum)',
      (tester) async {
    _ekran(tester);
    for (final (locale, acikSekme, durum) in [
      (const Locale('tr'), 'Açık (1)', 'Açık'),
      (const Locale('en'), 'Open (1)', 'Open'),
      (const Locale('fr'), 'Ouverts (1)', 'Ouvert'),
    ]) {
      await tester.pumpWidget(_talepEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(acikSekme), findsOneWidget, reason: '$locale sekme');
      // Durum rozeti enum'dan cozulur (metin kontrol akisinda kullanilmaz).
      expect(find.text(durum), findsWidgets, reason: '$locale durum rozeti');
      // Talep basligi SUNUCU verisi — cevrilmez.
      expect(find.text('Asansor arizali'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  // ============================== RTL ===================================
  testWidgets('RTL: TALEP Arapca (form-yogun) — yeni talep formu TASMAZ',
      (tester) async {
    _ekran(tester);
    // "Yeni talep" FAB'i YALNIZ talep ACAN rollerde (yonetici yanitlar) —
    // form denetimi bu yuzden resident ile yapilir (auth.md §4).
    await tester.pumpWidget(
        _talepEkrani(const Locale('ar'), role: UserRole.resident));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('مفتوح (1)'))),
        TextDirection.rtl);
    expect(tester.takeException(), isNull);

    // "Yeni talep" formu (form-yogun): baslik + aciklama + kategori + gorseller.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('العنوان'), findsOneWidget);
    expect(find.text('الوصف'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'yeni talep formu Arapca metinlerle tasmamali');
  });

  testWidgets('RTL: SEMA Arapca — yon rtl, yerlesim TASMAZ', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_semaEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('الكثافة:'))),
        TextDirection.rtl);
    // Yerlesim-yogun ekran: hicbir RenderFlex tasmasi olmamali.
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL: BINA DUZENLEME Arapca (form-yogun) — kutucuk TASMAZ',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_duzenlemeEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('مبنى').first)),
        TextDirection.rtl);
    expect(tester.takeException(), isNull);

    // Blok kutucuguna dokun -> kat/daire yerlesimi (uzun Arapca yardim metni).
    // NOT: blok etiketi Arapca'da belirlilik takisi alir ("المبنى A"); ekleme
    // kutucugu ise yalin ("مبنى").
    await tester.tap(find.text('المبنى A'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: 'blok ici yerlesim Arapca metinlerle tasmamali');

    // TOPLU DAIRE formunu ac (form-yogun; etiketli dugme -> deterministik):
    // uc sayi alani + uzun Arapca aciklama ayni ekranda.
    await tester.tap(find.text('إضافة وحدات بالجملة'));
    await tester.pumpAndSettle();
    expect(find.text('عدد الطوابق'), findsOneWidget);
    expect(find.text('رقم البداية'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'toplu daire formu Arapca metinlerle tasmamali');
  });

  // ---- TUR 24: EKRAN SURUSU ----
  testWidgets('SURUS: talep ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_talepEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });
  testWidgets('SURUS: bina semasi ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_semaEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });
  // Her dil AYRI test: bir dilin tasmasi digerlerini maskelemesin ve
  // rapor "hangi dil" sorusunu dogrudan yanitlasin.
  for (final dil in surusDilleri) {
    testWidgets('SURUS: bina duzenleme ekrani ($dil) TR sabit tasimaz',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_duzenlemeEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    });
  }

  // ---- TUR 26: DAR EKRAN SURUSU (320 dp x 6 dil) ----
  testWidgets('DAR 320dp: talep ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _talepEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('DAR 320dp: bina semasi ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _semaEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('DAR 320dp: bina duzenleme ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _duzenlemeEkrani(Locale(dil)),
        veri: surusVerisi);
  });

  // ---- TUR 27: YAZI OLCEGI SURUSU (2.0x x 6 dil) ----
  testWidgets('OLCEK 2x: talep ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _talepEkrani(Locale(dil)), veri: surusVerisi);
  });
  testWidgets('OLCEK 2x: sema ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _semaEkrani(Locale(dil)), veri: surusVerisi);
  });
  testWidgets('OLCEK 2x: duzenleme ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _duzenlemeEkrani(Locale(dil)), veri: surusVerisi);
  });

  // ---- TUR 29: EKRAN OKUYUCU SURUSU ----
  testWidgets('OKUYUCU: talep ekrani (etiket + dokunma hedefi + dil)',
      (tester) async {
    await ekranOkuyucuSurusu(tester, (dil) => _talepEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('OKUYUCU: sema ekrani (etiket + dokunma hedefi + dil)',
      (tester) async {
    await ekranOkuyucuSurusu(tester, (dil) => _semaEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('OKUYUCU: duzenleme ekrani (etiket + dokunma hedefi + dil)',
      (tester) async {
    await ekranOkuyucuSurusu(tester, (dil) => _duzenlemeEkrani(Locale(dil)),
        veri: surusVerisi);
  });
}

class _PatlayanMapApi extends BuildingMapApi {
  _PatlayanMapApi() : super(Dio());

  @override
  Future<BuildingMap> fetchMap() async => throw StateError('bozuk');
}
