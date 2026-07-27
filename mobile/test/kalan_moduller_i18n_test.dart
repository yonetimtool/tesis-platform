/// KALAN MODULLER — SUPURME TURU i18n (tur 12).
///
/// Kapsam: destek, tesis kurulumu/ayarlari, sikayetlerim, vardiyalar,
/// yonetici iletisim, bildirimler, arama butonu, push.
///
/// Kritik iddialar:
///   * `shift_models.gunTipiLabel` ve `UnitComplaintKategori.label` (TR sabit
///     uretici uyeler) KALDIRILDI; cozucu cizim katmaninda.
///   * `PushMessageEvent.displayText` artik VARSAYILAN METIN URETMEZ (bos
///     doner); "Yeni bildirim" cizimde yazilir.
///   * Kalan 11 string BILINCLI ISTISNA ya da yazili I18N BORCU'dur; bu test
///     onlarin listesini de kilitler.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/core/i18n/locale_controller.dart';
import 'package:mobile/src/features/push/domain/push_models.dart';
import 'package:mobile/src/features/shifts/data/shifts_api.dart';
import 'package:mobile/src/features/shifts/domain/shift_models.dart';
import 'package:mobile/src/features/shifts/presentation/gun_tipi_adi.dart';
import 'package:mobile/src/features/shifts/presentation/vardiyalar_screen.dart';
import 'package:mobile/src/features/support/data/support_api.dart';
import 'package:mobile/src/features/support/domain/support_models.dart';
import 'package:mobile/src/features/support/presentation/destek_screen.dart';
import 'package:mobile/src/features/tenant/presentation/setup_tenant_screen.dart';
import 'package:mobile/src/features/unit_complaints/domain/unit_complaint_models.dart';
import 'package:mobile/src/features/unit_complaints/presentation/kategori_adi.dart';
import 'package:mobile/src/features/yonetici_iletisim/data/yonetici_iletisim_api.dart';
import 'package:mobile/src/features/yonetici_iletisim/domain/yonetici_iletisim_models.dart';
import 'package:mobile/src/features/yonetici_iletisim/presentation/yonetici_iletisim_screen.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

// --------------------------------------------------------------------------
// Sahteler (ag YOK)
// --------------------------------------------------------------------------
class _FakeDestekApi extends SupportApi {
  _FakeDestekApi(this._items) : super(Dio());
  final List<SupportTicket> _items;

  @override
  Future<List<SupportTicket>> fetchMine({int limit = 50}) async => _items;
}

class _FakeVardiyaApi extends ShiftsApi {
  _FakeVardiyaApi(this._items) : super(Dio());
  final List<Shift> _items;

  @override
  Future<List<Shift>> fetch({int limit = 50}) async => _items;
}

class _FakeYoneticiApi extends YoneticiIletisimApi {
  _FakeYoneticiApi(this._veri) : super(Dio());
  final YoneticiIletisim _veri;

  @override
  Future<YoneticiIletisim> getir() async => _veri;
}

Widget _destekEkrani(Locale locale, {List<SupportTicket>? items}) =>
    ProviderScope(
      overrides: [
        supportApiProvider.overrideWithValue(_FakeDestekApi(items ?? const [])),
      ],
      child: l10nApp(const DestekScreen(), locale: locale),
    );

Widget _tesisEkrani(Locale locale) => ProviderScope(
      child: l10nApp(const SetupTenantScreen(), locale: locale),
    );

Widget _vardiyaEkrani(Locale locale, {List<Shift>? items}) => ProviderScope(
      overrides: [
        shiftsApiProvider.overrideWithValue(_FakeVardiyaApi(items ?? const [])),
      ],
      child: l10nApp(const VardiyalarScreen(), locale: locale),
    );

Widget _yoneticiEkrani(Locale locale, {YoneticiIletisim? veri}) =>
    ProviderScope(
      overrides: [
        yoneticiIletisimApiProvider.overrideWithValue(
          _FakeYoneticiApi(
            veri ?? const YoneticiIletisim(yoneticiler: [], yonetimEmail: null),
          ),
        ),
      ],
      child: l10nApp(const YoneticiIletisimScreen(), locale: locale),
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
  // ================================ DESTEK ================================
  testWidgets('DESTEK: tr → en → de dil degisimi (baslik + FAB + bos durum)',
      (tester) async {
    _ekran(tester);
    for (final (locale, baslik, yeni, bos) in [
      (
        const Locale('tr'),
        'Destek',
        'Yeni Talep',
        'Henüz destek talebiniz yok'
      ),
      (
        const Locale('en'),
        'Support',
        'New request',
        'You have no support requests yet'
      ),
      (
        const Locale('de'),
        'Support',
        'Neue Anfrage',
        'Sie haben noch keine Support-Anfragen'
      ),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(_destekEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(baslik), findsOneWidget, reason: '$locale AppBar');
      expect(find.text(yeni), findsOneWidget, reason: '$locale FAB');
      expect(find.text(bos), findsOneWidget, reason: '$locale bos durum');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('DESTEK: yeni talep formu etiketleri cevrilir', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_destekEkrani(const Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('New support request'), findsOneWidget);
    expect(find.text('Subject'), findsOneWidget);
    expect(find.text('Add image'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ============================ TESIS KURULUMU ============================
  testWidgets('TESIS: tr → en → fr dil degisimi (baslik + alan + buton)',
      (tester) async {
    _ekran(tester);
    for (final (locale, baslik, alan, buton) in [
      (
        const Locale('tr'),
        'Tesisinizi tanımlayın',
        'Tesis adı',
        'Tesisi oluştur'
      ),
      (const Locale('en'), 'Set up your site', 'Facility name', 'Create site'),
      (
        const Locale('fr'),
        'Configurez votre site',
        'Nom du site',
        'Créer le site'
      ),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(_tesisEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(baslik), findsOneWidget, reason: '$locale baslik');
      expect(find.text(alan), findsOneWidget, reason: '$locale alan');
      expect(find.text(buton), findsOneWidget, reason: '$locale buton');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('TESIS: kisa ad dogrulamasi aktif dilde yazar', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_tesisEkrani(const Locale('en')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'A');
    await tester.tap(find.text('Create site'));
    await tester.pumpAndSettle();
    expect(
      find.text('The site name must be at least 2 characters'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  // ============================== VARDIYALAR ==============================
  testWidgets('VARDIYA: tr → en → ru dil degisimi (baslik + bos durum)',
      (tester) async {
    _ekran(tester);
    for (final (locale, baslik, bos) in [
      (const Locale('tr'), 'VARDİYALAR', 'Vardiya tanımı yok'),
      (const Locale('en'), 'SHIFTS', 'No shifts defined'),
      (const Locale('ru'), 'СМЕНЫ', 'Смены не заданы'),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(_vardiyaEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(baslik), findsOneWidget, reason: '$locale AppBar');
      expect(find.text(bos), findsOneWidget, reason: '$locale bos durum');
      expect(tester.takeException(), isNull);
    }
  });

  test('gunTipiAdi: 7 dil + null (kisitsiz) + BILINMEYEN tel degeri',
      () async {
    for (final (kod, haftaIci, herGun) in [
      ('tr', 'Hafta içi', 'Her gün'),
      ('en', 'Weekdays', 'Every day'),
      ('de', 'Wochentags', 'Täglich'),
    ]) {
      final l10n = await AppLocalizations.delegate.load(Locale(kod));
      expect(gunTipiAdi(l10n, 'hafta_ici'), haftaIci, reason: kod);
      // null = KISITSIZ -> "her gün"
      expect(gunTipiAdi(l10n, null), herGun, reason: kod);
      expect(gunTipiAdi(l10n, 'her_gun'), herGun, reason: kod);
    }
    final tr = await AppLocalizations.delegate.load(const Locale('tr'));
    // Sozlesmeye yeni tip eklenirse ekran ham degeri yazar (bos kalmaz).
    expect(gunTipiAdi(tr, 'yilbasi'), 'yilbasi');
    for (final kod in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
      final l10n = await AppLocalizations.delegate.load(Locale(kod));
      for (final g in ['hafta_ici', 'hafta_sonu', 'resmi_tatil', 'her_gun']) {
        expect(gunTipiAdi(l10n, g).trim(), isNotEmpty, reason: '$kod/$g');
      }
    }
  });

  // ============================== SIKAYETLERIM ============================
  test('UnitComplaintKategori: enum label YOK, cozucu 7 dilde', () async {
    for (final (kod, gurultu) in [
      ('tr', 'Gürültü'),
      ('en', 'Noise'),
      ('de', 'Lärm'),
    ]) {
      final l10n = await AppLocalizations.delegate.load(Locale(kod));
      expect(
        unitComplaintKategoriAdi(l10n, UnitComplaintKategori.gurultu),
        gurultu,
        reason: kod,
      );
    }
    for (final kod in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
      final l10n = await AppLocalizations.delegate.load(Locale(kod));
      for (final k in UnitComplaintKategori.values) {
        expect(unitComplaintKategoriAdi(l10n, k).trim(), isNotEmpty,
            reason: '$kod/$k');
      }
    }
  });

  // =========================== YONETICI ILETISIM ==========================
  testWidgets('YONETICI: tr → en dil degisimi (baslik + bos durum + buton)',
      (tester) async {
    _ekran(tester);
    for (final (locale, baslik, bos) in [
      (
        const Locale('tr'),
        'YÖNETİCİ İLETİŞİM',
        'Yönetici iletişim bilgisi tanımlı değil.'
      ),
      (
        const Locale('en'),
        'MANAGEMENT CONTACTS',
        'No management contact details are defined.'
      ),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(_yoneticiEkrani(locale));
      await tester.pumpAndSettle();
      expect(find.text(baslik), findsOneWidget, reason: '$locale AppBar');
      expect(find.text(bos), findsOneWidget, reason: '$locale bos durum');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('YONETICI: arama butonu + yonetim maili cevrilir',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_yoneticiEkrani(
      const Locale('en'),
      veri: const YoneticiIletisim(
        yoneticiler: [
          YoneticiKart(
            userId: 'y-1',
            adSoyad: 'Mehmet Yilmaz',
            telefon: '+905550000000',
          ),
        ],
        yonetimEmail: 'yonetim@example.com',
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Call the manager'), findsOneWidget);
    expect(find.text('Management email'), findsOneWidget);
    expect(find.text('Mehmet Yilmaz'), findsOneWidget); // sunucu verisi
    expect(tester.takeException(), isNull);
  });

  // ================================= PUSH =================================
  test('PushMessageEvent.displayText: VARSAYILAN METIN URETMEZ', () {
    const bos = PushMessageEvent();
    expect(bos.displayText, isEmpty); // eskiden 'Yeni bildirim' donuyordu
    const dolu = PushMessageEvent(title: 'Duyuru', body: 'Su kesintisi');
    expect(dolu.displayText, 'Duyuru — Su kesintisi');
  });

  test('bildirimYeniPush: varsayilan metin 7 dilde ARB\'de', () async {
    for (final kod in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
      final l10n = await AppLocalizations.delegate.load(Locale(kod));
      expect(l10n.bildirimYeniPush.trim(), isNotEmpty, reason: kod);
    }
    final tr = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(tr.bildirimYeniPush, 'Yeni bildirim');
  });

  // ======================= BILINCLI ISTISNALAR (KILIT) ====================
  test('dil adlari KENDI dilinde kalir (cevrilmez)', () {
    // Dil secicide her dil kendi adiyla gorunur; ARB'ye TASINMAZ.
    expect(AppDil.tr.adKendiDilinde, 'Türkçe');
    expect(AppDil.en.adKendiDilinde, 'English');
    expect(AppDil.ar.adKendiDilinde, 'العربية');
    expect(AppDil.fr.adKendiDilinde, 'Français');
    for (final d in AppDil.values) {
      expect(d.adKendiDilinde.trim(), isNotEmpty);
    }
  });

  // ================================= RTL =================================
  testWidgets('RTL: DESTEK Arapca — liste + form TASMAZ', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_destekEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('طلب جديد'))),
        TextDirection.rtl);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('الموضوع'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'destek formu Arapca metinlerle tasmamali');
  });

  testWidgets('RTL: TESIS + VARDIYA + YONETICI Arapca TASMAZ', (tester) async {
    _ekran(tester);
    for (final (etiket, ekran) in [
      ('tesis', _tesisEkrani(const Locale('ar'))),
      ('vardiya', _vardiyaEkrani(const Locale('ar'))),
      ('yonetici', _yoneticiEkrani(const Locale('ar'))),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(ekran);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$etiket ar');
    }
  });

  // Dar ekran (320 dp): uzun yardimci metinler.
  testWidgets('DAR EKRAN 320 dp: tesis + destek TASMAZ', (tester) async {
    _ekran(tester, g: 320, h: 2200);
    for (final (etiket, ekran) in [
      ('tesis', _tesisEkrani(const Locale('de'))),
      ('destek', _destekEkrani(const Locale('de'))),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(ekran);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$etiket 320');
    }
  });

  // ---- TUR 24: EKRAN SURUSU ----
  testWidgets('SURUS: destek ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_destekEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });
  testWidgets('SURUS: tesis kurulumu ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_tesisEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });
  testWidgets('SURUS: vardiyalar ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_vardiyaEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });
  testWidgets('SURUS: yonetici iletisim ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_yoneticiEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });

  // ---- TUR 26: DAR EKRAN SURUSU (320 dp x 6 dil) ----
  testWidgets('DAR 320dp: destek ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _destekEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('DAR 320dp: tesis kurulumu ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _tesisEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('DAR 320dp: vardiyalar ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _vardiyaEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('DAR 320dp: yonetici iletisim ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _yoneticiEkrani(Locale(dil)),
        veri: surusVerisi);
  });

  // ---- TUR 27: YAZI OLCEGI SURUSU (2.0x x 6 dil) ----
  testWidgets('OLCEK 2x: destek ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _destekEkrani(Locale(dil)), veri: surusVerisi);
  });
  testWidgets('OLCEK 2x: tesis ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _tesisEkrani(Locale(dil)), veri: surusVerisi);
  });
  testWidgets('OLCEK 2x: vardiya ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _vardiyaEkrani(Locale(dil)), veri: surusVerisi);
  });
  testWidgets('OLCEK 2x: yonetici ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _yoneticiEkrani(Locale(dil)), veri: surusVerisi);
  });
}
