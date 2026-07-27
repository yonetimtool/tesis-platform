/// AIDAT + KONTROL NOKTASI + GONDERIM KUYRUGU i18n (tur 11) — dil degistirme
/// ornegi, KIMLIK/METIN ayrimi ve RTL (Arapca) denetimi.
///
/// Kritik iddialar:
///   * `dues_models.yontemLabel` / `durumLabel` (TR sabit uretici fonksiyonlar)
///     KALDIRILDI; cozucu `aidat_etiket.dart` icinde ve BILINMEYEN tel degeri
///     oldugu gibi doner (ileri uyumluluk).
///   * `OutboxEntry` DISKE yazilir: artik TR cumle degil hata KODU tasir
///     (`hataKodu`), metin cizimde cozulur. Eski kayitlar (kod yok) sunucu
///     metnine duser.
///   * Kontrol noktasi formu artik SUNUCU METNINDE 'zaten' aramaz — hata
///     KODU'na bakar.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/features/checkpoints/data/checkpoint_api.dart';
import 'package:mobile/src/features/checkpoints/presentation/checkpoints_screen.dart';
import 'package:mobile/src/features/dues/data/dues_api.dart';
import 'package:mobile/src/features/dues/domain/dues_models.dart';
import 'package:mobile/src/features/dues/presentation/aidat_etiket.dart';
import 'package:mobile/src/features/dues/presentation/my_dues_screen.dart';
import 'package:mobile/src/features/scan/presentation/okutma_hata_metni.dart';

import 'helpers/l10n_test_app.dart';

// --------------------------------------------------------------------------
// Sahteler (ag YOK)
// --------------------------------------------------------------------------
class _FakeDuesApi extends DuesApi {
  _FakeDuesApi(this._units) : super(Dio());
  final List<MyDuesUnit> _units;

  @override
  Future<List<MyDuesUnit>> fetchMyDues() async => _units;
}

class _FakeCheckpointApi extends CheckpointApi {
  _FakeCheckpointApi(this._items) : super(Dio());
  final List<Checkpoint> _items;

  @override
  Future<List<Checkpoint>> list() async => _items;
}

MyDuesUnit _daire() => MyDuesUnit(
      unitId: 'u-1',
      no: 'A-12',
      tahakkukKurus: 120000,
      odenenKurus: 60000,
      bakiyeKurus: 60000,
      assessments: [
        DuesAssessment(
          donem: '2026-07',
          tutarKurus: 120000,
          sonOdemeTarihi: DateTime.utc(2026, 7, 15),
        ),
      ],
      payments: [
        DuesPayment(
          tutarKurus: 60000,
          yontem: 'havale',
          durum: 'basarili',
          odemeZamani: DateTime.utc(2026, 7, 5, 10, 30),
          makbuzNo: 'MK-1',
        ),
      ],
    );

Checkpoint _nokta({bool aktif = true}) => Checkpoint(
      id: 'c-1',
      ad: 'Giris Kapisi',
      nfcTagUid: '04:A2:B3:C4',
      aktif: aktif,
    );

Widget _aidatEkrani(Locale locale, {List<MyDuesUnit>? daireler}) => ProviderScope(
      overrides: [
        duesApiProvider.overrideWithValue(_FakeDuesApi(daireler ?? [_daire()])),
      ],
      child: l10nApp(const MyDuesScreen(), locale: locale),
    );

Widget _noktaEkrani(Locale locale, {List<Checkpoint>? items}) => ProviderScope(
      overrides: [
        checkpointApiProvider
            .overrideWithValue(_FakeCheckpointApi(items ?? [_nokta()])),
      ],
      child: l10nApp(const CheckpointsScreen(), locale: locale),
    );

/// Ayni `ProviderScope` tipini ust uste pump etmek kabi yenilemez (tur 7 notu).
Future<void> _sifirla(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void _ekran(WidgetTester tester, {double g = 430, double h = 2000}) {
  tester.view.physicalSize = Size(g, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  // ================================ AIDAT =================================
  testWidgets('AIDAT: tr → en → ru dil degisimi (baslik + satirlar + cip)',
      (tester) async {
    _ekran(tester);
    for (final (locale, baslik, tahakkuk, borc) in [
      (const Locale('tr'), 'AİDATIM', 'Toplam tahakkuk', 'Borç var'),
      (const Locale('en'), 'MY DUES', 'Total assessed', 'Balance due'),
      (const Locale('ru'), 'МОИ ВЗНОСЫ', 'Всего начислено', 'Есть долг'),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(_aidatEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(baslik), findsOneWidget, reason: '$locale AppBar');
      expect(find.text(tahakkuk), findsOneWidget, reason: '$locale tahakkuk');
      expect(find.text(borc), findsOneWidget, reason: '$locale borc cipi');
      // PARA: dil ne olursa olsun site-yerel.
      expect(find.text('1.200,00 TL'), findsWidgets, reason: '$locale tutar');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('AIDAT: ICU cogul sayaclari + odeme yontemi/durumu cevrilir',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_aidatEkrani(const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Assessment (1)'), findsOneWidget);
    expect(find.text('Payment (1)'), findsOneWidget);

    // Odeme satirini gormek icin listeyi ac.
    await tester.tap(find.text('Payment (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bank transfer'), findsOneWidget);
    expect(find.text('Successful'), findsOneWidget);
    expect(find.text('Receipt: MK-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AIDAT: daire yoksa cevrilmis bos durum', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_aidatEkrani(const Locale('de'), daireler: const []));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Auf Sie ist keine Wohnung registriert.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('odemeYontemiAdi / odemeDurumuAdi: 7 dil + BILINMEYEN tel degeri',
      () async {
    for (final (kod, havale, basarili) in [
      ('tr', 'Havale/EFT', 'Başarılı'),
      ('en', 'Bank transfer', 'Successful'),
      ('de', 'Banküberweisung', 'Erfolgreich'),
    ]) {
      final l10n = await AppLocalizations.delegate.load(Locale(kod));
      expect(odemeYontemiAdi(l10n, 'havale'), havale, reason: kod);
      expect(odemeDurumuAdi(l10n, 'basarili'), basarili, reason: kod);
    }
    final tr = await AppLocalizations.delegate.load(const Locale('tr'));
    // Sozlesmede olmayan deger OLDUGU GIBI doner (ileri uyumluluk).
    expect(odemeYontemiAdi(tr, 'kripto'), 'kripto');
    expect(odemeDurumuAdi(tr, 'acayip'), 'acayip');
    // 'bekliyor' kuyruk anahtarini YENIDEN kullanir (ayni sozcuk).
    expect(odemeDurumuAdi(tr, 'bekliyor'), 'Bekliyor');
    for (final kod in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
      final l10n = await AppLocalizations.delegate.load(Locale(kod));
      for (final y in ['elden', 'havale', 'kart', 'diger']) {
        expect(odemeYontemiAdi(l10n, y).trim(), isNotEmpty, reason: '$kod/$y');
      }
      for (final d in ['basarili', 'bekliyor', 'iptal']) {
        expect(odemeDurumuAdi(l10n, d).trim(), isNotEmpty, reason: '$kod/$d');
      }
    }
  });

  // ============================ KONTROL NOKTASI ===========================
  testWidgets('NOKTA: tr → en → fr dil degisimi (baslik + FAB + pasif cip)',
      (tester) async {
    _ekran(tester);
    for (final (locale, baslik, ekle, pasif) in [
      (const Locale('tr'), 'KONTROL NOKTALARI', 'Nokta ekle', 'Pasif'),
      (const Locale('en'), 'CHECKPOINTS', 'Add checkpoint', 'Inactive'),
      (
        const Locale('fr'),
        'POINTS DE CONTRÔLE',
        'Ajouter un point',
        'Inactif'
      ),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(_noktaEkrani(locale, items: [_nokta(aktif: false)]));
      await tester.pumpAndSettle();

      expect(find.text(baslik), findsOneWidget, reason: '$locale AppBar');
      expect(find.text(ekle), findsOneWidget, reason: '$locale FAB');
      expect(find.text(pasif), findsOneWidget, reason: '$locale pasif cip');
      expect(find.text('Giris Kapisi'), findsOneWidget); // sunucu verisi
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('NOKTA: silme onayi + form etiketleri cevrilir', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_noktaEkrani(const Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(find.text('Delete this checkpoint?'), findsOneWidget);
    expect(
      find.text('The "Giris Kapisi" checkpoint will be deleted.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('NFC tag UID'), findsOneWidget);
    expect(find.text("The tag's unique identifier (hex)."), findsOneWidget);
    expect(find.text('Latitude (opt.)'), findsOneWidget);
    expect(
      find.text('An inactive checkpoint will not match a scan'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('NOKTA: bos liste metni cevrilir', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_noktaEkrani(const Locale('en'), items: const []));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No checkpoints yet.\nAdd an NFC checkpoint from the bottom right.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  // ================================ KUYRUK ================================
  test('okutmaHataMetni: KOD cozulur, eski kayit sunucu metnine duser',
      () async {
    for (final kod in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
      final l10n = await AppLocalizations.delegate.load(Locale(kod));
      // Sozlesme kodlari -> ozel metin.
      expect(
        okutmaHataMetni(l10n, kod: 'invalid_signature', sunucuMetni: 'x'),
        isNot('x'),
        reason: kod,
      );
      expect(
        okutmaHataMetni(l10n, kod: 'replay_detected', sunucuMetni: 'x'),
        isNot('x'),
        reason: kod,
      );
      // Istemci kodu: teknik detay cumleye girer.
      expect(
        okutmaHataMetni(l10n, kod: okutmaBeklenmeyenKod, sunucuMetni: 'boom'),
        contains('boom'),
        reason: kod,
      );
      // ESKI KAYIT (kod yok) -> sunucu metni OLDUGU GIBI.
      expect(
        okutmaHataMetni(l10n, sunucuMetni: 'eski TR cumle'),
        'eski TR cumle',
        reason: kod,
      );
      // Ne kod ne metin -> genel karsilik.
      expect(okutmaHataMetni(l10n).trim(), isNotEmpty, reason: kod);
    }
    final tr = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(okutmaHataMetni(tr, kod: 'invalid_signature'),
        'Etiket imzası doğrulanamadı — sahte veya yanlış etiket olabilir.');
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(okutmaHataMetni(en, kod: 'replay_detected'),
        'This scan was already processed.');
  });

  test('kuyruk metinleri 7 dilde var (ozet + durum satirlari)', () async {
    for (final kod in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
      final l10n = await AppLocalizations.delegate.load(Locale(kod));
      for (final metin in [
        l10n.kuyrukBos,
        l10n.kuyrukSenkronla,
        l10n.kuyrukBekliyor,
        l10n.kuyrukGonderiliyor,
        l10n.kuyrukGonderildiYeni,
        l10n.kuyrukGonderildiZatenVar,
        l10n.kuyrukHatalariTemizle,
      ]) {
        expect(metin.trim(), isNotEmpty, reason: kod);
      }
      expect(l10n.kuyrukOzet('3', '1'), contains('3'), reason: kod);
      expect(l10n.kuyrukBekliyorDeneme('2'), contains('2'), reason: kod);
    }
  });

  // ================================= RTL =================================
  testWidgets('RTL: AIDAT Arapca — daire karti TASMAZ', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_aidatEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('إجمالي المستحق'))),
        TextDirection.rtl);
    // Tutar RTL govdede LTR IZOLE edilir.
    // U+2068 FSI … U+2069 PDI (kacis dizisi)
    expect(find.text('\u20681.200,00 TL\u2069'), findsWidgets);
    expect(tester.takeException(), isNull,
        reason: 'aidat karti Arapca metinlerle tasmamali');
  });

  testWidgets('RTL: NOKTA Arapca — liste + form TASMAZ', (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_noktaEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('إضافة نقطة'))),
        TextDirection.rtl);
    expect(tester.takeException(), isNull, reason: 'nokta listesi');

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('معرّف وسم NFC'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'nokta formu Arapca metinlerle tasmamali');
  });

  // Dar ekran (320 dp): uzun yardimci metinler + ICU cogul etiketleri.
  testWidgets('DAR EKRAN 320 dp: aidat + nokta formu TASMAZ', (tester) async {
    _ekran(tester, g: 320, h: 2400);
    for (final (etiket, ekran) in [
      ('aidat', _aidatEkrani(const Locale('de'))),
      ('nokta', _noktaEkrani(const Locale('ar'))),
    ]) {
      await _sifirla(tester);
      await tester.pumpWidget(ekran);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$etiket 320');
    }

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'nokta formu 320');
  });
}
