/// BUTCE + DEMIRBAS + KARGO i18n (tur 6) — dil degistirme ornegi,
/// KIMLIK/METIN ayrimi, para bicimi ve RTL (Arapca) denetimi.
///
/// Kritik iddialar:
///   * `BudgetTip` ve `KargoDurum` `label` alanini KAYBETTI — gorunen ad
///     cizim aninda cozulur (`butceTipAdi` / `kargoDurumAdi`).
///   * Demirbas denetleyicisi metin degil MESAJ KIMLIGI dondurur; kimlikler
///     PARAMETRE tasiyabildigi icin sealed sinif kullanilir
///     ([DemirbasMesaj]), cozum `demirbasMesajMetni` ile cizimde yapilir.
///   * PARA KURALI: tutar UI dili ne olursa olsun Turkce gruplama + "TL"
///     ile gosterilir; Arapca'da yalnizca LTR IZOLASYONU eklenir.
///   * `tlSonEkli` PARA BICIMINI kilitler (tur 9'da domain ikizi
///     `formatKurusAsTl` kaldirildi; tek kaynak `tlTutar`).
///   * Cok-parametreli ARB anahtarlari MESAJ sirasinda uretilir (tur 5
///     bulgusu: `placeholders` metadata'si yoksa gen-l10n alfabetik siralar).
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/features/assets/data/asset_api.dart';
import 'package:mobile/src/features/assets/domain/asset_models.dart';
import 'package:mobile/src/features/assets/domain/demirbas_mesaj.dart';
import 'package:mobile/src/features/assets/presentation/assets_screen.dart';
import 'package:mobile/src/features/assets/presentation/demirbas_mesaj_metni.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/budget/data/budget_api.dart';
import 'package:mobile/src/features/budget/domain/budget_models.dart';
import 'package:mobile/src/features/budget/presentation/budget_screen.dart';
import 'package:mobile/src/features/budget/presentation/butce_tip_adi.dart';
import 'package:mobile/src/features/kargo/data/kargo_api.dart';
import 'package:mobile/src/features/kargo/domain/kargo_models.dart';
import 'package:mobile/src/features/kargo/presentation/kargo_durum_adi.dart';
import 'package:mobile/src/features/kargo/presentation/kargo_screen.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

// --------------------------------------------------------------------------
// Sahteler (ag YOK)
// --------------------------------------------------------------------------
class _FakeBudgetApi extends BudgetApi {
  _FakeBudgetApi({this.buyukTutar = false}) : super(Dio());

  /// true: milyonluk site butcesi (dar ekran tasma senaryosu).
  final bool buyukTutar;

  int get _kat => buyukTutar ? 245000000 : 245000;

  @override
  Future<BudgetSummary> fetchSummary({String? donem}) async => BudgetSummary(
        toplamGelirKurus: _kat,
        toplamGiderKurus: 75000,
        bakiyeKurus: 170000,
        kategoriler: [
          BudgetCategorySummaryItem(
            kategoriId: 'k-aidat',
            ad: 'Aidat',
            tip: BudgetTip.gelir,
            toplamKurus: _kat,
          ),
        ],
      );

  @override
  Future<List<BudgetEntry>> fetchEntries({
    BudgetTip? tip,
    String? kategoriId,
    String? donem,
  }) async =>
      [
        BudgetEntry(
          id: 'e-1',
          kategoriId: 'k-elektrik',
          tip: BudgetTip.gider,
          tutarKurus: buyukTutar ? 75000000 : 75000,
          tarih: DateTime.utc(2026, 7, 3),
          kaynak: 'aidat_odeme',
          kategoriAd: 'Elektrik',
        ),
      ];

  @override
  Future<List<BudgetCategory>> fetchCategories({BudgetTip? tip}) async =>
      const [
    BudgetCategory(
      id: 'k-elektrik',
      ad: 'Elektrik',
      tip: BudgetTip.gider,
      aktif: true,
    ),
    BudgetCategory(
      id: 'k-eski',
      ad: 'Eski',
      tip: BudgetTip.gelir,
      aktif: false,
    ),
  ];
}

class _FakeAssetApi extends AssetApi {
  _FakeAssetApi(this._mine) : super(Dio());
  final List<Asset> _mine;

  @override
  Future<List<Asset>> fetchMyAssets() async => _mine;
}

class _FakeKargoApi extends KargoApi {
  _FakeKargoApi(this._items) : super(Dio());
  final List<Kargo> _items;

  @override
  Future<List<Kargo>> fetchAll({String? unitId}) async => _items;
}

Asset _asset() => Asset(
  id: 'a-1',
  ad: 'Matkap',
  kategori: AssetKategori.alet,
  durum: AssetDurum.zimmetli,
  aktif: true,
  acikZimmet: AcikZimmet(
    alanUserId: 'u-1',
    alanUserAd: 'Ali Guard',
    // Sabit degil: "N saattir" parcasi GERCEK simdiye gore hesaplanir.
    alinmaZamani: DateTime.now().toUtc().subtract(const Duration(hours: 3)),
  ),
);

Kargo _kargo({bool bekliyor = true}) => Kargo(
  id: 'k-1',
  unitId: 'u-1',
  unitNo: 'A-12',
  firma: 'Aras Kargo',
  durum: bekliyor ? KargoDurum.bekliyor : KargoDurum.teslimAlindi,
  kaydedenUserId: 'g-1',
  createdAt: DateTime.utc(2026, 7, 20, 9, 30),
  teslimAlanAd: bekliyor ? null : 'Ayse Sakin',
  teslimZamani: bekliyor ? null : DateTime.utc(2026, 7, 20, 18, 5),
);

Widget _butceEkrani(Locale locale, {bool buyukTutar = false}) => ProviderScope(
  overrides: [
    budgetApiProvider.overrideWithValue(
      _FakeBudgetApi(buyukTutar: buyukTutar),
    ),
  ],
  child: l10nApp(const BudgetScreen(), locale: locale),
);

Widget _demirbasEkrani(Locale locale) => ProviderScope(
  overrides: [
    assetApiProvider.overrideWithValue(_FakeAssetApi([_asset()])),
    currentUserIdProvider.overrideWith((ref) async => 'u-1'),
  ],
  child: l10nApp(const AssetsScreen(), locale: locale),
);

Widget _kargoEkrani(Locale locale, {bool bekliyor = true}) => ProviderScope(
  overrides: [
    kargoApiProvider.overrideWithValue(
      _FakeKargoApi([_kargo(bekliyor: bekliyor)]),
    ),
    currentUserRoleProvider.overrideWith((ref) async => UserRole.security),
  ],
  child: l10nApp(KargoScreen(), locale: locale),
);

void _ekran(WidgetTester tester, {double g = 430, double h = 1400}) {
  tester.view.physicalSize = Size(g, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  // ================================ BUTCE ================================
  testWidgets(
    'BUTCE: tr → en → de dil degisimi (sekmeler + gelir/gider/kasa)',
    (tester) async {
      _ekran(tester);
      for (final (locale, ozet, gelir, kasa) in [
        (const Locale('tr'), 'Özet', 'Gelir', 'Kasa'),
        (const Locale('en'), 'Summary', 'Income', 'Balance'),
        (const Locale('de'), 'Übersicht', 'Einnahmen', 'Kasse'),
      ]) {
        await tester.pumpWidget(_butceEkrani(locale));
        await tester.pumpAndSettle();

        expect(find.text(ozet), findsOneWidget, reason: '$locale ozet sekmesi');
        expect(find.text(gelir), findsOneWidget, reason: '$locale gelir karti');
        expect(find.text(kasa), findsOneWidget, reason: '$locale kasa karti');
        // PARA: dil ne olursa olsun Turkce gruplama + TL (gelir karti +
        // kategori kirilimi satiri = 2 esleme).
        expect(
          find.text('2.450,00 TL'),
          findsNWidgets(2),
          reason: '$locale tutar bicimi site-yerel kalir',
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('BUTCE: kategori tipi enum degil CEVIRI ile cizilir', (
    tester,
  ) async {
    _ekran(tester);
    for (final (locale, gider, gelirPasif) in [
      (const Locale('tr'), 'Gider', 'Gelir · pasif (yeni kayıt kapalı)'),
      (
        const Locale('fr'),
        'Dépenses',
        'Recettes · inactive (aucune nouvelle écriture)',
      ),
    ]) {
      await tester.pumpWidget(_butceEkrani(locale));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Tab).last); // Kategoriler
      await tester.pumpAndSettle();

      // Aktif kategori: yalniz tip; pasif kategori: tip + pasif eki.
      expect(
        find.text(gider),
        findsOneWidget,
        reason: '$locale aktif kategori',
      );
      expect(
        find.text(gelirPasif),
        findsOneWidget,
        reason: '$locale pasif kategori',
      );
      expect(tester.takeException(), isNull);
    }
  });

  test('butceTipAdi: TR label yok, ceviri var (6 dil)', () async {
    for (final (kod, gelir, gider) in [
      ('tr', 'Gelir', 'Gider'),
      ('en', 'Income', 'Expense'),
      ('ar', 'الإيرادات', 'المصروفات'),
      ('ru', 'Доходы', 'Расходы'),
      ('de', 'Einnahmen', 'Ausgaben'),
      ('fr', 'Recettes', 'Dépenses'),
      ('es', 'Ingresos', 'Gastos'),
    ]) {
      final l10n = await AppLocalizations.delegate.load(Locale(kod));
      expect(butceTipAdi(l10n, BudgetTip.gelir), gelir, reason: kod);
      expect(butceTipAdi(l10n, BudgetTip.gider), gider, reason: kod);
    }
  });

  // =============================== DEMIRBAS ==============================
  testWidgets(
    'DEMIRBAS: tr → en → ru dil degisimi (sekmeler + uzerimdekiler)',
    (tester) async {
      _ekran(tester);
      for (final (locale, okut, uzerim) in [
        (const Locale('tr'), 'Etiket okut', 'Üzerimdekiler (1)'),
        (const Locale('en'), 'Scan tag', 'Assigned to me (1)'),
        (const Locale('ru'), 'Считать метку', 'На мне (1)'),
      ]) {
        await tester.pumpWidget(_demirbasEkrani(locale));
        await tester.pumpAndSettle();

        // Sekme + buyuk okut butonu ayni metni tasir (2 esleme).
        expect(find.text(okut), findsNWidgets(2), reason: '$locale okut');
        expect(find.text(uzerim), findsOneWidget, reason: '$locale sayac');
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('DEMIRBAS: "N saattir" parcasi EDATI tasir — cift edat yok', (
    tester,
  ) async {
    _ekran(tester);
    await tester.pumpWidget(_demirbasEkrani(const Locale('en')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assigned to me (1)'));
    await tester.pumpAndSettle();

    // "Taken: 20.07 12:00 (for 3 hours)" — parca "for", sablon degil.
    expect(find.textContaining('(for 3 hours)'), findsOneWidget);
    expect(find.textContaining('for for'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('demirbasMesajMetni: kimlik + PARAMETRE cozumu (6 dil)', () async {
    for (final (kod, offlineBasi, uidIcinde) in [
      ('tr', 'İnternet bağlantısı gerekli.', 'ABC123'),
      ('en', 'An internet connection is required.', 'ABC123'),
      ('ar', 'يلزم اتصال بالإنترنت.', 'ABC123'),
    ]) {
      final l10n = await AppLocalizations.delegate.load(Locale(kod));
      expect(
        demirbasMesajMetni(
          l10n,
          const DemirbasKimlikMesaji(DemirbasMesajKimlik.offline),
        ),
        startsWith(offlineBasi),
        reason: kod,
      );
      expect(
        demirbasMesajMetni(l10n, const DemirbasEtiketEslesmiyor('ABC123')),
        contains(uidIcinde),
        reason: kod,
      );
      // Sunucu kanali: metin OLDUGU GIBI gecer (ceviri denenmez).
      expect(
        demirbasMesajMetni(l10n, const DemirbasSunucuMetni('sunucu der ki')),
        'sunucu der ki',
        reason: kod,
      );
    }
  });

  // ================================ KARGO ================================
  testWidgets(
    'KARGO: tr → en → es dil degisimi (sekme sayaclari + durum cipi)',
    (tester) async {
      _ekran(tester);
      for (final (locale, bekleyen, durum) in [
        (const Locale('tr'), 'Bekleyen (1)', 'Bekliyor'),
        (const Locale('en'), 'Pending (1)', 'Pending'),
        (const Locale('es'), 'Pendientes (1)', 'Pendiente'),
      ]) {
        await tester.pumpWidget(_kargoEkrani(locale));
        await tester.pumpAndSettle();

        expect(find.text(bekleyen), findsOneWidget, reason: '$locale sekme');
        expect(find.text(durum), findsWidgets, reason: '$locale durum cipi');
        expect(tester.takeException(), isNull);
      }
    },
  );

  test('kargoDurumAdi: TR label yok, ceviri var (7 dil)', () async {
    for (final (kod, bekliyor) in [
      ('tr', 'Bekliyor'),
      ('en', 'Pending'),
      // NOT: 'Bekliyor' cevirisi devriye modulunden YENIDEN kullanilir
      // (`devriyeDurumBekliyor`) — sozluk tutarliligi icin kopyalanmadi.
      ('ar', 'بالانتظار'),
      ('ru', 'Ожидает'),
      ('de', 'Ausstehend'),
      ('fr', 'En attente'),
      ('es', 'Pendiente'),
    ]) {
      final l10n = await AppLocalizations.delegate.load(Locale(kod));
      expect(kargoDurumAdi(l10n, KargoDurum.bekliyor), bekliyor, reason: kod);
    }
  });

  // ============================ PARA + SIRALAMA ==========================
  test('tlSonEkli: TR gruplama bicimi (tek kaynak)', () {
    // Tur 9: domain ikizi `formatKurusAsTl` kaldirildi; bicim BURADA kilitli.
    expect(tlSonEkli(0, 'tr'), '0,00 TL');
    expect(tlSonEkli(5, 'tr'), '0,05 TL');
    expect(tlSonEkli(75000, 'tr'), '750,00 TL');
    expect(tlSonEkli(123456, 'tr'), '1.234,56 TL');
    expect(tlSonEkli(245000, 'tr'), '2.450,00 TL');
    expect(tlSonEkli(-50000, 'tr'), '-500,00 TL');
    expect(tlSonEkli(999999999, 'tr'), '9.999.999,99 TL');
  });

  test('tlSonEkli: Arapca LTR izolasyonu ekler, isaret tutardan kopmaz', () {
    expect(tlSonEkli(75000, 'tr', onEk: '-'), '-750,00 TL');
    final ar = tlSonEkli(75000, 'ar', onEk: '-');
    // U+2068 FSI … U+2069 PDI (kacis dizisi: kaynakta gorunmez isaret olmasin)
    expect(ar, '\u2068-750,00 TL\u2069');
  });

  test('cok-parametreli anahtarlar MESAJ sirasinda uretilir', () async {
    final tr = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(tr.butKategoriTip('Elektrik', 'Gider'), 'Elektrik (Gider)');
    expect(
      tr.karDaireTarih('A-12', '20.07.2026 · 09:30'),
      'Daire: A-12 · 20.07.2026 · 09:30',
    );
    expect(tr.demSende('3 saattir'), 'SENDE — 3 saattir üzerinde.');
    expect(
      tr.demBaskasinda('Ali', '3 saattir'),
      'Başkasında: Ali — 3 saattir üzerinde.',
    );
    expect(
      tr.demAldin('20.07 12:00', '3 saattir'),
      'Aldın: 20.07 12:00 (3 saattir)',
    );
    expect(
      tr.demAldiBirakti('Ali', '20.07 09:00', '20.07 12:00'),
      'Ali · 20.07 09:00 → 20.07 12:00',
    );
    expect(tr.demHataSatiri('Matkap', 'meşgul'), 'Matkap: meşgul');
  });

  // ================================= RTL =================================
  testWidgets('RTL: BUTCE Arapca (form-yogun) — hareket formu TASMAZ', (
    tester,
  ) async {
    _ekran(tester);
    await tester.pumpWidget(_butceEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.text('الملخص'))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);

    // Hareketler sekmesi + yeni hareket formu (kategori + tutar + tarih).
    await tester.tap(find.text('الحركات'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('المبلغ (ليرة)'), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'hareket formu Arapca metinlerle tasmamali',
    );
  });

  testWidgets('RTL: DEMIRBAS Arapca — durum karti + uzerimdekiler TASMAZ', (
    tester,
  ) async {
    _ekran(tester);
    await tester.pumpWidget(_demirbasEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.text('امسح الوسم').first)),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ما بحوزتي (1)'));
    await tester.pumpAndSettle();
    expect(find.text('إعادة'), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'uzerimdekiler satiri Arapca metinlerle tasmamali',
    );
  });

  testWidgets('RTL: KARGO Arapca (form-yogun) — yeni kargo formu TASMAZ', (
    tester,
  ) async {
    _ekran(tester);
    await tester.pumpWidget(_kargoEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.text('قيد الانتظار (1)'))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('شركة الشحن *'), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'kargo formu Arapca metinlerle tasmamali',
    );
  });

  // Dar ekran (320 dp) + 7 haneli tutar: tur 6 RTL taramasinin buldugu
  // TASMALARIN kilidi. Bulgular Turkce'de de olusuyordu (i18n kaynakli
  // degil), duzeltmeler her iki dili birlikte kurtarir.
  testWidgets('DAR EKRAN 320 dp: milyonluk butce + uzun etiketler TASMAZ', (
    tester,
  ) async {
    _ekran(tester, g: 320, h: 1800);
    await tester.pumpWidget(_butceEkrani(const Locale('ar'), buyukTutar: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'ozet 320');

    await tester.tap(find.byType(Tab).at(1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'hareketler 320');
  });

  testWidgets('DAR EKRAN 320 dp: kargo formu etiketleri TASMAZ', (
    tester,
  ) async {
    _ekran(tester, g: 320, h: 1800);
    // Turkce EN UZUN etiketleri tasir ("Paket fotografi (opsiyonel)").
    await tester.pumpWidget(_kargoEkrani(const Locale('tr')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'kargo formu 320');
  });

  testWidgets('RTL: KARGO detayi Arapca — teslim satiri TASMAZ', (
    tester,
  ) async {
    _ekran(tester);
    await tester.pumpWidget(_kargoEkrani(const Locale('ar'), bekliyor: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المستلمة (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aras Kargo').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Ayse Sakin'), findsWidgets);
    expect(
      tester.takeException(),
      isNull,
      reason: 'kargo detayi Arapca metinlerle tasmamali',
    );
  });

  // ---- TUR 24: EKRAN SURUSU (bkz. README — sozluk degil EKRAN olcumu) ----
  testWidgets('SURUS: butce ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_butceEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });

  testWidgets('SURUS: demirbas ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_demirbasEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });

  testWidgets('SURUS: kargo ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_kargoEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });



  // ---- TUR 26: DAR EKRAN SURUSU (320 dp x 6 dil) ----
  testWidgets('DAR 320dp: butce ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _butceEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('DAR 320dp: demirbas ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _demirbasEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('DAR 320dp: kargo ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _kargoEkrani(Locale(dil)),
        veri: surusVerisi);
  });

  // ---- TUR 27: YAZI OLCEGI SURUSU (2.0x x 6 dil) ----
  testWidgets('OLCEK 2x: butce ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _butceEkrani(Locale(dil)), veri: surusVerisi);
  });
  testWidgets('OLCEK 2x: demirbas ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _demirbasEkrani(Locale(dil)), veri: surusVerisi);
  });
  testWidgets('OLCEK 2x: kargo ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _kargoEkrani(Locale(dil)), veri: surusVerisi);
  });
}
