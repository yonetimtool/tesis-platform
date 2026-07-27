/// DIS HIZMET + NFC + SEFFAFLIK i18n (tur 9) — dil degistirme ornegi,
/// KIMLIK/METIN ayrimi ve RTL (Arapca) denetimi.
///
/// Kritik iddialar:
///   * `NfcService` (VERI katmani) artik METIN URETMEZ: hatalar [NfcHatasi]
///     kimligi olarak doner. Tersine, iOS'un SISTEM sayfasinin metinleri
///     [NfcIosMetinleri] ile cizim katmanindan servise GECIRILIR.
///   * Bu ayrim gorev + demirbas modullerindeki eski "surucu metni" yolunu da
///     kapatti (o modullerde NFC hatasi TR sabit geliyordu).
///   * Ay adlari artik dile duyarli (`ayAdi`) — TR sabit dizi kaldirildi.
///   * Para: domain ikizi `formatKurusAsTl` KALDIRILDI; seffaflik panosu da
///     `tlSonEkli` kullaniyor (tek kaynak `tlTutar`).
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/dis_hizmet/data/dis_hizmet_api.dart';
import 'package:mobile/src/features/dis_hizmet/presentation/dis_hizmet_screen.dart';
import 'package:mobile/src/features/nfc/domain/nfc_hatasi.dart';
import 'package:mobile/src/features/nfc/domain/nfc_read_result.dart';
import 'package:mobile/src/features/nfc/presentation/nfc_hata_metni.dart';
import 'package:mobile/src/features/transparency/data/transparency_api.dart';
import 'package:mobile/src/features/transparency/domain/seffaflik_hatasi.dart';
import 'package:mobile/src/features/transparency/domain/transparency_models.dart';
import 'package:mobile/src/features/transparency/presentation/transparency_screen.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

// --------------------------------------------------------------------------
// Sahteler (ag YOK)
// --------------------------------------------------------------------------
class _FakeDisApi extends DisHizmetApi {
  _FakeDisApi(this._liste, {this.not}) : super(Dio());
  final List<DisHizmet> _liste;
  final String? not;

  @override
  Future<DisHizmetList> fetch() async =>
      DisHizmetList(items: _liste, note: not);
}

class _FakeSeffaflikApi extends TransparencyApi {
  _FakeSeffaflikApi({this.aylar = const [], this.board}) : super(Dio());
  final List<TransparencyAyOzet> aylar;
  final TransparencyBoard? board;

  @override
  Future<List<TransparencyAyOzet>> fetchMonths() async => aylar;

  @override
  Future<TransparencyBoard> fetchBoard(String ay) async => board!;
}

DisHizmet _hizmet() => const DisHizmet(
      id: 'd-1',
      tur: 'Çilingir',
      ad: 'Ali',
      soyad: 'Usta',
      telefon: '0532 111 22 33',
    );

TransparencyBoard _board({bool yayinlandi = true, bool buyukTutar = false}) =>
    TransparencyBoard(
      ay: buyukTutar ? '2026-09' : '2026-07',
      yayinlandi: yayinlandi,
      toplamGelirKurus: buyukTutar ? 245000000 : 100000,
      toplamGiderKurus: buyukTutar ? 375000000 : 40000,
      netKurus: buyukTutar ? -130000000 : 60000,
      oncekiAyNetKurus: buyukTutar ? -98000000 : 25000,
      giderDagilimi: [
        TransparencyKategori(
          ad: buyukTutar ? 'Elektrik, su ve dogalgaz giderleri' : 'Elektrik',
          toplamKurus: buyukTutar ? 200000000 : 40000,
          yuzde: buyukTutar ? 53 : 100,
        ),
      ],
      aidat: const TransparencyAidat(
        tahakkukKurus: 120000,
        tahsilatKurus: 60000,
        odeyenDaire: 3,
        toplamDaire: 6,
        gecikenDaireSayisi: 3,
        tutarOraniYuzde: 50,
        daireOraniYuzde: 50,
      ),
    );

Widget _disEkrani(Locale locale, {List<DisHizmet>? liste, String? not}) =>
    ProviderScope(
      overrides: [
        disHizmetApiProvider
            .overrideWithValue(_FakeDisApi(liste ?? [_hizmet()], not: not)),
        currentUserRoleProvider.overrideWith((ref) async => UserRole.yonetici),
      ],
      child: l10nApp(const DisHizmetScreen(), locale: locale),
    );

Widget _seffaflikEkrani(
  Locale locale, {
  bool bosAylar = false,
  bool yayinlandi = true,
  bool buyukTutar = false,
  UserRole role = UserRole.yonetici,
}) =>
    ProviderScope(
      overrides: [
        transparencyApiProvider.overrideWithValue(
          _FakeSeffaflikApi(
            aylar: bosAylar
                ? const []
                : [
                    TransparencyAyOzet(
                      ay: buyukTutar ? '2026-09' : '2026-07',
                      yayinlandi: yayinlandi,
                      netKurus: 60000,
                    ),
                  ],
            board: _board(yayinlandi: yayinlandi, buyukTutar: buyukTutar),
          ),
        ),
        currentUserRoleProvider.overrideWith((ref) async => role),
      ],
      child: l10nApp(const TransparencyScreen(), locale: locale),
    );

/// Ayni `ProviderScope` tipini ust uste pump etmek kabi yenilemez (tur 7 notu).
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
  // ============================== DIS HIZMET ==============================
  testWidgets('DIS HIZMET: tr → en → ru dil degisimi (baslik + FAB + not)',
      (tester) async {
    _ekran(tester);
    for (final (locale, baslik, ekle, not) in [
      (
        const Locale('tr'),
        'DIŞ HİZMETLER',
        'Kişi ekle',
        'Not ekleyin (yalnızca yönetici düzenler).'
      ),
      (
        const Locale('en'),
        'EXTERNAL SERVICES',
        'Add contact',
        'Add a note (only management can edit).'
      ),
      (
        const Locale('ru'),
        'ВНЕШНИЕ УСЛУГИ',
        'Добавить контакт',
        'Добавьте примечание (изменять может только управление).'
      ),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(_disEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(baslik), findsOneWidget, reason: '$locale AppBar');
      expect(find.text(ekle), findsOneWidget, reason: '$locale FAB');
      expect(find.text(not), findsOneWidget, reason: '$locale not yer tutucu');
      // Sunucu verisi cevrilmez.
      expect(find.textContaining('Ali Usta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('DIS HIZMET: silme onayi kullanici verisini PLACEHOLDER ile kurar',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_disEkrani(const Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Delete this entry?'), findsOneWidget);
    expect(find.text('"Ali Usta" will be deleted.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DIS HIZMET: bolum notu DOLU ise sunucu metni cevrilmez',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(
      _disEkrani(const Locale('en'), not: 'Yillardir guvendigimiz esnaflar'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Yillardir guvendigimiz esnaflar'), findsOneWidget);
    // Yer tutucu metin GORUNMEZ (not dolu).
    expect(find.text('Add a note (only management can edit).'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DIS HIZMET: bos liste + form etiketleri cevrilir',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_disEkrani(const Locale('de'), liste: const []));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Noch keine Einträge.'),
      findsOneWidget,
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Art der Dienstleistung'), findsOneWidget);
    expect(find.text('Vorname'), findsOneWidget);
    expect(find.text('Nachname'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ================================= NFC ==================================
  test('NfcReadResult.failure: METIN degil KIMLIK tasir', () {
    final r = NfcReadResult.failure(NfcHatasi.kapali);
    expect(r.hata, NfcHatasi.kapali);
    expect(r.hataDetay, isNull);
    expect(r.isSuccess, isFalse);

    final d = NfcReadResult.failure(NfcHatasi.cozumlenemedi, detay: 'boom');
    expect(d.hata, NfcHatasi.cozumlenemedi);
    expect(d.hataDetay, 'boom');
  });

  test('nfcHataMetni: 7 kimlik x 7 dil + detay yerlestirme', () async {
    for (final kod in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
      final l10n = await AppLocalizations.delegate.load(Locale(kod));
      for (final h in NfcHatasi.values) {
        final metin = nfcHataMetni(l10n, h, detay: 'X-99');
        expect(metin.trim(), isNotEmpty, reason: '$kod/$h');
      }
      // Parametreli kimlikler detayi GERCEKTEN yerlestirir.
      expect(nfcHataMetni(l10n, NfcHatasi.cozumlenemedi, detay: 'X-99'),
          contains('X-99'),
          reason: kod);
      expect(nfcHataMetni(l10n, NfcHatasi.oturumBaslatilamadi, detay: 'X-99'),
          contains('X-99'),
          reason: kod);
      // Detay bos gelirse sozlesme bozulmaz ('-' yazar).
      expect(nfcHataMetni(l10n, NfcHatasi.okumaIptal), contains('-'),
          reason: kod);
    }
    final tr = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(nfcHataMetni(tr, NfcHatasi.kapali),
        'NFC kapalı. Lütfen cihaz ayarlarından NFC\'yi açın.');
  });

  test('nfcIosMetinleri: SISTEM sayfasinin 4 metni cizimden gelir', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final m = nfcIosMetinleri(en);
    expect(m.yaklastir, 'Hold the tag against the back of the phone.');
    expect(m.okundu, 'Read');
    expect(m.okunamadi, 'Could not be read');
    expect(m.iptal, 'Cancelled');

    final ar = nfcIosMetinleri(
      await AppLocalizations.delegate.load(const Locale('ar')),
    );
    for (final metin in [ar.yaklastir, ar.okundu, ar.okunamadi, ar.iptal]) {
      expect(metin.trim(), isNotEmpty);
    }
  });

  // ============================== SEFFAFLIK ===============================
  testWidgets('SEFFAFLIK: tr → en → fr dil degisimi (baslik + kart adlari)',
      (tester) async {
    _ekran(tester);
    for (final (locale, baslik, gelir, aidat) in [
      (
        const Locale('tr'),
        'ŞEFFAFLIK',
        'Toplam gelir',
        'Aidat toplama',
      ),
      (
        const Locale('en'),
        'TRANSPARENCY',
        'Total income',
        'Dues collection',
      ),
      (
        const Locale('fr'),
        'TRANSPARENCE',
        'Recettes totales',
        'Recouvrement des charges',
      ),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(_seffaflikEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(baslik), findsOneWidget, reason: '$locale AppBar');
      expect(find.text(gelir), findsOneWidget, reason: '$locale gelir');
      expect(find.text(aidat), findsOneWidget, reason: '$locale aidat');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('SEFFAFLIK: AY ADI dile gore yazilir (TR sabit dizi yok)',
      (tester) async {
    _ekran(tester);
    for (final (locale, ozet) in [
      (const Locale('tr'), 'Temmuz 2026 — Özet'),
      (const Locale('en'), 'July 2026 — Summary'),
      (const Locale('de'), 'Juli 2026 — Übersicht'),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(_seffaflikEkrani(locale));
      await tester.pumpAndSettle();
      expect(find.text(ozet), findsOneWidget, reason: '$locale ay adi');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('SEFFAFLIK: taslak eki + yayin anahtari cevrilir',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(
      _seffaflikEkrani(const Locale('en'), yayinlandi: false),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('• draft'), findsOneWidget);
    expect(find.text('Publish this month'), findsOneWidget);
    expect(find.text('Only management can see it (preview).'), findsOneWidget);
    expect(find.text('Preview — not published yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SEFFAFLIK: PARA site-yerel kalir (dil ne olursa olsun)',
      (tester) async {
    _ekran(tester);
    for (final locale in [const Locale('tr'), const Locale('en')]) {
      await _sifirla(tester);
      await tester.pumpWidget(_seffaflikEkrani(locale));
      await tester.pumpAndSettle();
      expect(find.text('1.000,00 TL'), findsOneWidget, reason: '$locale gelir');
      expect(find.text('600,00 TL'), findsOneWidget, reason: '$locale net');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('SEFFAFLIK: bos durum ROLE gore secilir ve cevrilir',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(
      _seffaflikEkrani(const Locale('en'), bosAylar: true),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No financial data yet.'), findsOneWidget);

    await _sifirla(tester);
    await tester.pumpWidget(_seffaflikEkrani(
      const Locale('en'),
      bosAylar: true,
      role: UserRole.resident,
    ));
    await tester.pumpAndSettle();
    expect(
      find.text('Management has not published a summary yet.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('seffaflikHatasiCoz: kimlik ONCE, sonra sunucu metni', () async {
    final tr = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(
      seffaflikHatasiCoz(tr, SeffaflikHatasi.yuklenemedi, 'sunucu'),
      'Yüklenemedi. Lütfen tekrar deneyin.',
    );
    expect(seffaflikHatasiCoz(tr, null, 'sunucu'), 'sunucu');
    expect(seffaflikHatasiCoz(tr, null, null), isNull);
  });

  test('ayAdi: 7 dilde + gecersiz ayda BOS (cagiran ham degeri yazar)',
      () async {
    expect(ayAdi(7, 'tr'), 'Temmuz');
    expect(ayAdi(7, 'en'), 'July');
    expect(ayAdi(1, 'de'), 'Januar');
    expect(ayAdi(12, 'fr'), 'décembre');
    expect(ayAdi(0, 'tr'), '');
    expect(ayAdi(13, 'tr'), '');
    for (final kod in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
      for (var ay = 1; ay <= 12; ay++) {
        expect(ayAdi(ay, kod).trim(), isNotEmpty, reason: '$kod/$ay');
      }
    }
  });

  // ================================= RTL =================================
  testWidgets('RTL: DIS HIZMET Arapca — liste + form TASMAZ', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_disEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('إضافة جهة اتصال'))),
        TextDirection.rtl);
    expect(tester.takeException(), isNull, reason: 'dis hizmet listesi');

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('نوع الخدمة'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'dis hizmet formu Arapca metinlerle tasmamali');
  });

  testWidgets('RTL: SEFFAFLIK Arapca — uc kart TASMAZ', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_seffaflikEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('تحصيل الرسوم'))),
        TextDirection.rtl);
    // Tutar RTL govdede LTR IZOLE edilir (U+2068 … U+2069 kacis dizisi).
    expect(find.text('\u20681.000,00 TL\u2069'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'seffaflik kartlari Arapca metinlerle tasmamali');
  });

  // Tur 9 taramasinin bulduklari: (a) ay secici uzun cevirilerde tasiyordu
  // (isExpanded), (b) gider dagilimi satirinda 9 haneli tutar tasiyordu
  // (Flexible + FittedBox — tur 6 emsali). Ikisi de TR'de de olusuyordu.
  testWidgets('DAR EKRAN 320/360 dp: milyonluk pano + uzun ay adi TASMAZ',
      (tester) async {
    for (final (g, locale) in [
      (320.0, const Locale('tr')),
      (360.0, const Locale('de')), // "September 2026 • Entwurf" en uzun
    ]) {
      _ekran(tester, g: g, h: 2400);
      await _sifirla(tester);
      await tester.pumpWidget(
        _seffaflikEkrani(locale, yayinlandi: false, buyukTutar: true),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'pano $locale $g');
    }
  });

  // Dar ekran (320 dp): en uzun ceviriler + iki satirli yardimci metinler.
  testWidgets('DAR EKRAN 320 dp: dis hizmet + seffaflik TASMAZ',
      (tester) async {
    _ekran(tester, g: 320, h: 2200);
    for (final (etiket, ekran) in [
      ('dis', _disEkrani(const Locale('ar'))),
      ('seffaflik', _seffaflikEkrani(const Locale('ar'))),
      ('seffaflik-de', _seffaflikEkrani(const Locale('de'))),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(ekran);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$etiket 320');
    }
  });

  // ---- TUR 24: EKRAN SURUSU ----
  testWidgets('SURUS: dis hizmet ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_disEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });
  testWidgets('SURUS: seffaflik ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_seffaflikEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });
}
