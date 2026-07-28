/// ENTEGRASYON + ZIYARETCI + RAPOR i18n (tur 10) — dil degistirme ornegi,
/// KIMLIK/METIN ayrimi ve RTL (Arapca) denetimi.
///
/// Kritik iddialar:
///   * Rapor domain'i artik TR sabit AY DIZISI ve UCUNCU para bicimleyici
///     (`kurusToTl`) tasimaz; ikisi de `core/i18n` tek kaynagina tasindi.
///   * `KategoriSayi.kategoriAd` / `SonTamamlama.kategoriAd` NULL olabilir —
///     "Diğer" metni domain'de degil, cizimde (`gorevKategoriDiger`).
///   * Entegrasyon TEST yukunun metinleri (dis sisteme giden mesaj/baslik)
///     cizim katmaninda uretilip denetleyiciye gecirilir (NFC iOS emsali).
///   * ICU cogul: tahakkuk/tahsilat sayaclari.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/features/call/data/call_api.dart';
import 'package:mobile/src/features/call/domain/call_models.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/integrations/data/integration_api.dart';
import 'package:mobile/src/features/integrations/domain/integration_models.dart';
import 'package:mobile/src/features/integrations/presentation/integrations_screen.dart';
import 'package:mobile/src/features/reports/data/report_api.dart';
import 'package:mobile/src/features/reports/domain/report_models.dart';
import 'package:mobile/src/features/reports/presentation/reports_screen.dart';
import 'package:mobile/src/features/visitors/data/visitor_api.dart';
import 'package:mobile/src/features/visitors/domain/visitor_models.dart';
import 'package:mobile/src/features/visitors/presentation/visitors_screen.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

// --------------------------------------------------------------------------
// Sahteler (ag YOK)
// --------------------------------------------------------------------------
class _FakeEntegApi extends IntegrationApi {
  _FakeEntegApi(this._items) : super(Dio());
  final List<Integration> _items;

  /// Tetikte GELEN yuk — dil testinde metnin cizimden geldigi dogrulanir.
  String? sonMesaj;
  String? sonBaslik;

  @override
  Future<List<Integration>> fetchAll() async => _items;

  @override
  Future<List<IntegrationPreset>> fetchPresets() async => const [];

  @override
  Future<TriggerResult> trigger(String id,
      {String message = '', String title = ''}) async {
    sonMesaj = message;
    sonBaslik = title;
    return const TriggerResult(ok: true, status: 200);
  }
}

/// Sahte call API — ziyaretci detayindaki CallButton gercek aga CIKMASIN
/// (yoksa `pumpAndSettle` zaman asimina duser). ARANABILIR hedef doner ki
/// butonun YERELLESTIRILMIS etiketi cizilsin.
class _FakeCallApi extends CallApi {
  _FakeCallApi() : super(Dio());

  @override
  Future<CallTarget> resolve(String userId) async => CallTarget(
        userId: userId,
        ad: 'Hedef',
        role: 'resident',
        channel: 'phone',
        telefon: '+905550000000',
        telUri: 'tel:+905550000000',
      );
}

class _FakeZiyaretApi extends VisitorApi {
  _FakeZiyaretApi(this._items) : super(Dio());
  final List<Visitor> _items;

  @override
  Future<List<Visitor>> fetchAll({String? unitId}) async => _items;
}

class _FakeRaporApi extends ReportApi {
  _FakeRaporApi(this._rapor) : super(Dio());
  final AylikRapor _rapor;

  @override
  Future<AylikRapor> fetchMonthly(int yil, int ay) async => _rapor;
}

Integration _enteg() => const Integration(
      id: 'i-1',
      ad: 'Megafon',
      channelType: 'megaphone',
      endpointUrl: 'https://example.com/hook',
      httpMethod: 'POST',
      authType: 'bearer',
      authSecretSet: true,
      payloadTemplate: '{"announcement": "{{message}}"}',
      aktif: true,
    );

Visitor _ziyaretci() => Visitor(
      id: 'v-1',
      unitId: 'u-1',
      unitNo: 'A-12',
      ziyaretciAd: 'Ahmet Misafir',
      targetResidentUserId: 'r-1',
      targetResidentAd: 'Ayse Sakin',
      kaydedenUserId: 'g-1',
      kaydedenAd: 'Acme Guard',
      createdAt: DateTime.utc(2026, 7, 20, 14, 30),
    );

AylikRapor _rapor({int? tahakkukAdet, String? kategoriAd = 'Temizlik'}) =>
    AylikRapor(
      yil: 2026,
      ay: 7,
      devriyeToplam: 10,
      devriyeTamamlandi: 8,
      devriyeKacirildi: 2,
      gorev: GorevOzet(
        toplam: 6,
        kalemler: [KategoriSayi(kategoriAd: kategoriAd, sayi: 6)],
      ),
      sonTamamlamalar: [
        SonTamamlama(
          id: 't-1',
          kategoriAd: kategoriAd,
          tamamlanmaZamani: DateTime.utc(2026, 7, 18, 9),
        ),
      ],
      aidat: AidatOzet(
        tahakkukKurus: 120000,
        tahakkukAdet: tahakkukAdet ?? 3,
        tahsilatKurus: 60000,
        tahsilatAdet: 1,
      ),
    );

(_FakeEntegApi, Widget) _entegEkrani(Locale locale) {
  final api = _FakeEntegApi([_enteg()]);
  return (
    api,
    ProviderScope(
      overrides: [integrationApiProvider.overrideWithValue(api)],
      child: l10nApp(const IntegrationsScreen(), locale: locale),
    ),
  );
}

Widget _ziyaretEkrani(Locale locale, {UserRole role = UserRole.security}) =>
    ProviderScope(
      overrides: [
        visitorApiProvider.overrideWithValue(_FakeZiyaretApi([_ziyaretci()])),
        callApiProvider.overrideWithValue(_FakeCallApi()),
        currentUserRoleProvider.overrideWith((ref) async => role),
      ],
      child: l10nApp(VisitorsScreen(), locale: locale),
    );

Widget _raporEkrani(Locale locale, {AylikRapor? rapor}) => ProviderScope(
      overrides: [
        reportApiProvider.overrideWithValue(_FakeRaporApi(rapor ?? _rapor())),
      ],
      child: l10nApp(const ReportsScreen(), locale: locale),
    );

/// Ayni `ProviderScope` tipini ust uste pump etmek kabi yenilemez (tur 7 notu).
Future<void> _sifirla(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void _ekran(WidgetTester tester, {double g = 430, double h = 1800}) {
  tester.view.physicalSize = Size(g, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  // ============================= ENTEGRASYON ==============================
  testWidgets('ENTEG: tr → en → de dil degisimi (baslik + FAB + durum)',
      (tester) async {
    _ekran(tester);
    for (final (locale, baslik, yeni, aktif) in [
      (const Locale('tr'), 'ENTEGRASYONLAR', 'Yeni', 'aktif'),
      (const Locale('en'), 'INTEGRATIONS', 'New', 'active'),
      (const Locale('de'), 'INTEGRATIONEN', 'Neu', 'aktiv'),
    ]) {
      await _sifirla(tester);
      final (_, ekran) = _entegEkrani(locale);
      await tester.pumpWidget(ekran);
      await tester.pumpAndSettle();

      expect(find.text(baslik), findsOneWidget, reason: '$locale AppBar');
      expect(find.text(yeni), findsOneWidget, reason: '$locale FAB');
      expect(find.text(aktif), findsOneWidget, reason: '$locale durum');
      expect(find.text('Megafon'), findsOneWidget); // sunucu verisi
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('ENTEG: TEST yuku CIZIMDEN gelir (dis sisteme giden metin)',
      (tester) async {
    _ekran(tester);
    final (api, ekran) = _entegEkrani(const Locale('en'));
    await tester.pumpWidget(ekran);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test'));
    await tester.pumpAndSettle();
    expect(api.sonMesaj, 'Test message');
    expect(api.sonBaslik, 'Test');
    expect(find.textContaining('✓ Success'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ENTEG: silme onayi + form etiketleri cevrilir', (tester) async {
    _ekran(tester);
    final (_, ekran) = _entegEkrani(const Locale('en'));
    await tester.pumpWidget(ekran);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete it?'), findsOneWidget);
    expect(
      find.text('The "Megafon" integration will be deleted.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Channel type'), findsOneWidget);
    expect(find.text('Secret (bearer token / API key)'), findsOneWidget);
    // Teknik yer tutucular CEVRILMEZ, cumleye arguman olarak girer.
    expect(find.text('{{message}} / {{title}} placeholders'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // =============================== ZIYARETCI ==============================
  testWidgets('ZIYARET: tr → en → ru dil degisimi (baslik + FAB + sakin)',
      (tester) async {
    _ekran(tester);
    for (final (locale, baslik, yeni, sakin) in [
      (
        const Locale('tr'),
        'ZİYARETÇİLER',
        'Yeni ziyaretçi',
        'Bildirilen sakin: Ayse Sakin'
      ),
      (
        const Locale('en'),
        'VISITORS',
        'New visitor',
        'Notified resident: Ayse Sakin'
      ),
      (
        const Locale('ru'),
        'ПОСЕТИТЕЛИ',
        'Новый посетитель',
        'Уведомлённый житель: Ayse Sakin'
      ),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(_ziyaretEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(baslik), findsOneWidget, reason: '$locale AppBar');
      expect(find.text(yeni), findsOneWidget, reason: '$locale FAB');
      expect(find.text(sakin), findsOneWidget, reason: '$locale hedef sakin');
      expect(find.text('Ahmet Misafir'), findsOneWidget); // sunucu verisi
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('ZIYARET: form yardimci metni ROLE/MODA gore secilir',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_ziyaretEkrani(const Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Visitor name *'), findsOneWidget);
    expect(
      find.text(
        'The resident only gets a notification (no approval is requested).',
      ),
      findsOneWidget,
    );
    expect(find.text('Load residents'), findsOneWidget);
    expect(find.text('Save and notify the resident'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ZIYARET: bos liste metni ROLE gore secilir', (tester) async {
    _ekran(tester);
    for (final (role, beklenen) in [
      (UserRole.security, 'No visitor records yet.'),
      (UserRole.resident, 'No visitor records were shared with you.'),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitorApiProvider.overrideWithValue(_FakeZiyaretApi(const [])),
            callApiProvider.overrideWithValue(_FakeCallApi()),
            currentUserRoleProvider.overrideWith((ref) async => role),
          ],
          child: l10nApp(VisitorsScreen(), locale: const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(beklenen), findsOneWidget, reason: '$role');
      expect(tester.takeException(), isNull);
    }
  });

  // ================================ RAPOR =================================
  testWidgets('RAPOR: tr → en → fr dil degisimi (baslik + bolumler)',
      (tester) async {
    _ekran(tester);
    for (final (locale, baslik, bolum, ay) in [
      (const Locale('tr'), 'AYLIK RAPORLAR', 'Görev tamamlama', 'Temmuz 2026'),
      (const Locale('en'), 'MONTHLY REPORTS', 'Task completion', 'July 2026'),
      (
        const Locale('fr'),
        'RAPPORTS MENSUELS',
        'Achèvement des tâches',
        'juillet 2026'
      ),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(_raporEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(baslik), findsOneWidget, reason: '$locale AppBar');
      expect(find.text(bolum), findsOneWidget, reason: '$locale bolum');
      // AY ADI dile gore (TR sabit dizi kaldirildi).
      expect(find.text(ay), findsOneWidget, reason: '$locale ay basligi');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('RAPOR: ICU cogul sayaclari (1 vs 3)', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_raporEkrani(const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('Assessed (3 units)'), findsOneWidget);
    expect(find.text('Collected (1 payment)'), findsOneWidget);

    await _sifirla(tester);
    await tester.pumpWidget(
      _raporEkrani(const Locale('en'), rapor: _rapor(tahakkukAdet: 1)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Assessed (1 unit)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RAPOR: kategorisiz kalem "Diğer" cevirisine duser',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(
      _raporEkrani(const Locale('en'), rapor: _rapor(kategoriAd: null)),
    );
    await tester.pumpAndSettle();
    // Kirilim satiri + son tamamlama basligi ayni cozucuyu kullanir.
    expect(find.text('Other'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('RAPOR: PARA site-yerel kalir (dil ne olursa olsun)',
      (tester) async {
    _ekran(tester);
    for (final locale in [const Locale('tr'), const Locale('de')]) {
      await _sifirla(tester);
      await tester.pumpWidget(_raporEkrani(locale));
      await tester.pumpAndSettle();
      expect(find.text('1.200,00 TL'), findsOneWidget, reason: '$locale');
      expect(tester.takeException(), isNull);
    }
  });

  // ============================ SAF CEVIRI KILIDI =========================
  test('rapor domain: TR sabit ay dizisi ve kurusToTl KALDIRILDI', () {
    // Tarih/donem aritmetigi domain'de KALIR (dilden bagimsiz).
    expect(donemStr(2026, 7), '2026-07');
    expect(ayAralik(2026, 12).bitis, DateTime(2027, 1, 1).toUtc());
    // Ay adi + para TEK KAYNAKTAN.
    expect(ayAdi(7, 'tr'), 'Temmuz');
    expect(tlSonEkli(120000, 'tr'), '1.200,00 TL');
  });

  test('kategoriAd null gelebilir (domain TR sabit tasimaz)', () {
    final k = KategoriSayi.fromJson(const {'sayi': 4});
    expect(k.kategoriAd, isNull);
    expect(k.sayi, 4);
    final t = SonTamamlama.fromJson(const {'id': 'x'});
    expect(t.kategoriAd, isNull);
  });

  test('rapor cogul + yuzde anahtarlari 7 dilde var', () async {
    for (final kod in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
      final l10n = await AppLocalizations.delegate.load(Locale(kod));
      for (final n in [0, 1, 2, 5, 21]) {
        expect(l10n.raporTahakkukDaire(n).trim(), isNotEmpty,
            reason: '$kod/$n');
        expect(l10n.raporTahsilatOdeme(n).trim(), isNotEmpty,
            reason: '$kod/$n');
      }
      expect(l10n.raporTamamlanmaYuzde('80'), contains('80'), reason: kod);
      expect(l10n.raporAyBaslik('X', '2026'), contains('2026'), reason: kod);
    }
  });

  // ================================= RTL =================================
  testWidgets('RTL: ENTEG Arapca — kart + form TASMAZ', (tester) async {
    _ekran(tester);
    final (_, ekran) = _entegEkrani(const Locale('ar'));
    await tester.pumpWidget(ekran);
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('اختبار'))),
        TextDirection.rtl);
    expect(tester.takeException(), isNull, reason: 'enteg karti');

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('نوع القناة'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'enteg formu Arapca metinlerle tasmamali');
  });

  testWidgets('RTL: ZIYARET Arapca — liste + detay TASMAZ', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_ziyaretEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('زائر جديد'))),
        TextDirection.rtl);
    await tester.tap(find.text('Ahmet Misafir'));
    await tester.pumpAndSettle();
    expect(find.text('اتصل بالساكن'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'ziyaretci detayi Arapca metinlerle tasmamali');
  });

  testWidgets('RTL: RAPOR Arapca — uc kart TASMAZ', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_raporEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('الرسوم'))),
        TextDirection.rtl);
    expect(tester.takeException(), isNull,
        reason: 'rapor kartlari Arapca metinlerle tasmamali');
  });

  // Tur 10 taramasinin bulduklari (ikisi de DILDEN BAGIMSIZ, TR'de de):
  //   (a) entegrasyon formundaki 4 acilir menu uzun teknik degerlerde
  //       tasiyordu -> isExpanded (tur 9 ay secici emsali),
  //   (b) rapor bolum basligi uzun cevirilerde tasiyordu -> Expanded.
  testWidgets('DAR EKRAN 320 dp: enteg formu acilir menuleri TASMAZ',
      (tester) async {
    _ekran(tester, g: 320, h: 2400);
    final (_, ekran) = _entegEkrani(const Locale('tr'));
    await tester.pumpWidget(ekran);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'enteg formu 320');
  });

  testWidgets('RAPOR: uzun bolum basligi (fr) TASMAZ', (tester) async {
    _ekran(tester, g: 430, h: 1800);
    await tester.pumpWidget(_raporEkrani(const Locale('fr')));
    await tester.pumpAndSettle();
    expect(find.text('Achèvement des tâches'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'rapor bolum basligi');
  });

  // Dar ekran (320 dp): ICU cogul etiketleri + milyonluk tutarlar.
  testWidgets('DAR EKRAN 320 dp: uc ekran TASMAZ', (tester) async {
    _ekran(tester, g: 320, h: 2400);
    final (_, entegDar) = _entegEkrani(const Locale('de'));
    for (final (etiket, ekran) in [
      ('enteg', entegDar),
      ('ziyaret', _ziyaretEkrani(const Locale('ar'))),
      ('rapor', _raporEkrani(const Locale('de'))),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(ekran);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$etiket 320');
    }
  });

  // ---- TUR 24: EKRAN SURUSU ----
  testWidgets('SURUS: ziyaretci ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_ziyaretEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });
  testWidgets('SURUS: rapor ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_raporEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });

  // ---- TUR 26: DAR EKRAN SURUSU (320 dp x 6 dil) ----
  testWidgets('DAR 320dp: ziyaretci ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _ziyaretEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('DAR 320dp: rapor ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _raporEkrani(Locale(dil)),
        veri: surusVerisi);
  });

  // ---- TUR 27: YAZI OLCEGI SURUSU (2.0x x 6 dil) ----
  testWidgets('OLCEK 2x: ziyaret ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _ziyaretEkrani(Locale(dil)), veri: surusVerisi);
  });
  testWidgets('OLCEK 2x: rapor ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _raporEkrani(Locale(dil)), veri: surusVerisi);
  });

  // ---- TUR 29: EKRAN OKUYUCU SURUSU ----
  testWidgets('OKUYUCU: ziyaret ekrani (etiket + dokunma hedefi + dil)',
      (tester) async {
    await ekranOkuyucuSurusu(tester, (dil) => _ziyaretEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('OKUYUCU: rapor ekrani (etiket + dokunma hedefi + dil)',
      (tester) async {
    await ekranOkuyucuSurusu(tester, (dil) => _raporEkrani(Locale(dil)),
        veri: surusVerisi);
  });
}
