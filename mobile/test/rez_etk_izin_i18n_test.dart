/// REZERVASYON + ETKINLIK + IZIN i18n (tur 5) — dil degistirme ornegi,
/// KIMLIK/METIN ayrimi ve RTL (Arapca) denetimi.
///
/// Kritik iddialar:
///   * Uc alan enum'u (`RezervasyonDurum`, `KatilimDurum`, `AccessRequestDurum`)
///     `label` alanini KAYBETTI — etiket cizim aninda cozulur.
///   * `OrtakAlan.musaitlikOzeti` ve `Slot.sebepEtiketi` gibi METIN URETEN
///     domain uyeleri kaldirildi (`ParkingOccupancy.doluMetni` emsali);
///     yerine kimlik (`SlotSebep`) + cizim katmani cozucusu geldi.
///   * Denetleyiciler hata KIMLIGI dondurur (`AkisHatasi`).
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/etkinlik/data/etkinlik_api.dart';
import 'package:mobile/src/features/etkinlik/domain/etkinlik_models.dart';
import 'package:mobile/src/features/etkinlik/presentation/etk_etiket.dart';
import 'package:mobile/src/features/etkinlik/presentation/etkinlik_screen.dart';
import 'package:mobile/src/features/rezervasyon/data/rezervasyon_api.dart';
import 'package:mobile/src/features/rezervasyon/domain/rezervasyon_models.dart';
import 'package:mobile/src/features/rezervasyon/presentation/rez_etiket.dart';
import 'package:mobile/src/features/rezervasyon/presentation/rezervasyon_screen.dart';
import 'package:mobile/src/features/unit_access/data/unit_access_api.dart';
import 'package:mobile/src/features/unit_access/domain/unit_access_models.dart';
import 'package:mobile/src/features/unit_access/presentation/izin_etiket.dart';
import 'package:mobile/src/features/unit_access/presentation/unit_access_screen.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

// --------------------------------------------------------------------------
// Sahteler (ag YOK)
// --------------------------------------------------------------------------
class _FakeRezApi extends RezervasyonApi {
  _FakeRezApi(this._alanlar, this._items, this._slots) : super(Dio());
  final List<OrtakAlan> _alanlar;
  final List<Rezervasyon> _items;
  final List<Slot> _slots;

  @override
  Future<List<OrtakAlan>> fetchAreas() async => _alanlar;

  @override
  Future<List<Rezervasyon>> fetchReservations() async => _items;

  @override
  Future<List<Slot>> fetchSlots(String alanId, String date) async => _slots;
}

class _FakeEtkApi extends EtkinlikApi {
  _FakeEtkApi(this._items) : super(Dio());
  final List<Etkinlik> _items;

  @override
  Future<List<Etkinlik>> fetchAll() async => _items;
}

class _FakeIzinApi extends UnitAccessApi {
  _FakeIzinApi(this._items) : super(Dio());
  final List<UnitAccessRequest> _items;

  @override
  Future<List<UnitAccessRequest>> fetchAll() async => _items;
}

OrtakAlan _alan() => OrtakAlan(
      id: 'a-1',
      ad: 'Havuz',
      aktif: true,
      createdAt: DateTime.utc(2026, 7),
    );

Rezervasyon _rez() => Rezervasyon(
      id: 'r-1',
      alanId: 'a-1',
      unitId: 'u-1',
      alanAd: 'Havuz',
      tarih: '2026-12-31',
      baslangic: '10:00',
      bitis: '11:00',
      kisiSayisi: 4,
      durum: RezervasyonDurum.onaylandi,
      talepEdenUserId: 'res-1',
      createdAt: DateTime.utc(2026, 7, 10, 9),
    );

Etkinlik _etk() => Etkinlik(
      id: 'e-1',
      baslik: 'Mac izleme aksami',
      aciklama: 'Buyuk ekranda milli mac.',
      tarih: DateTime.now().add(const Duration(days: 5)),
      konum: 'Sosyal tesis salonu',
      olusturanUserId: 'yon-1',
      olusturanAd: 'Acme Yonetici',
      katiliyorumSayisi: 5,
      katilmiyorumSayisi: 2,
      createdAt: DateTime.utc(2026, 7, 10, 9),
    );

UnitAccessRequest _izin({
  AccessRequestDurum durum = AccessRequestDurum.bekliyor,
}) =>
    UnitAccessRequest(
      id: 'q-1',
      unitId: 'u-1',
      unitNo: 'A-12',
      grantedToYoneticiUserId: 'y-1',
      yoneticiAd: 'Acme Yonetici',
      durum: durum,
      used: false,
      requestedAt: DateTime.utc(2026, 7, 12, 9),
    );

Widget _rezEkrani(Locale locale, {UserRole role = UserRole.resident}) =>
    ProviderScope(
      overrides: [
        rezervasyonApiProvider
            .overrideWithValue(_FakeRezApi([_alan()], [_rez()], const [])),
        currentUserRoleProvider.overrideWith((ref) async => role),
        currentUserIdProvider.overrideWith((ref) async => 'res-1'),
      ],
      child: l10nApp(const RezervasyonScreen(), locale: locale),
    );

Widget _etkEkrani(Locale locale, {UserRole role = UserRole.yonetici}) =>
    ProviderScope(
      overrides: [
        etkinlikApiProvider.overrideWithValue(_FakeEtkApi([_etk()])),
        currentUserRoleProvider.overrideWith((ref) async => role),
      ],
      child: l10nApp(const EtkinlikScreen(), locale: locale),
    );

Widget _izinEkrani(Locale locale, {UserRole role = UserRole.yonetici}) =>
    ProviderScope(
      overrides: [
        unitAccessApiProvider.overrideWithValue(_FakeIzinApi([_izin()])),
        currentUserRoleProvider.overrideWith((ref) async => role),
      ],
      child: l10nApp(const UnitAccessScreen(), locale: locale),
    );

void _ekran(WidgetTester tester, {double h = 1400}) {
  tester.view.physicalSize = Size(430, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  // ============================ REZERVASYON =============================
  testWidgets('REZERVASYON: tr → en → ru dil degisimi (sekme + durum rozeti)',
      (tester) async {
    _ekran(tester);
    for (final (locale, sekme, durum) in [
      (const Locale('tr'), 'Rezervasyonlar (1)', 'Onaylı'),
      (const Locale('en'), 'Reservations (1)', 'Confirmed'),
      (const Locale('ru'), 'Брони (1)', 'Подтверждено'),
    ]) {
      await tester.pumpWidget(_rezEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(sekme), findsOneWidget, reason: '$locale sekme');
      expect(find.text(durum), findsWidgets, reason: '$locale durum rozeti');
      // Alan adi SUNUCU verisi — cevrilmez.
      expect(find.text('Havuz'), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });

  test('REZERVASYON: domain METIN URETMEZ (musaitlik + slot sebebi)', () async {
    final tr = await AppLocalizations.delegate.load(const Locale('tr'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    // musaitlikOzeti domain'den TASINDI -> cizim katmani kurar.
    final alan = OrtakAlan(
      id: 'a',
      ad: 'Havuz',
      aktif: true,
      acilis: '08:00',
      kapanis: '22:00',
      slotDakika: 60,
      createdAt: DateTime.utc(2026, 7),
    );
    expect(musaitlikOzeti(tr, alan), '08:00–22:00 · 60 dk slot');
    expect(musaitlikOzeti(en, alan), '08:00–22:00 · 60 min slots');

    // Slot KIMLIK dondurur; metin dilden cozulur.
    final slot = Slot.fromJson(const {
      'baslangic': '10:00',
      'bitis': '11:00',
      'dolu': false,
      'rezerve_edilebilir': false,
      'sebep': 'cok_erken',
    });
    expect(slot.sebepKimligi, SlotSebep.cokErken);
    expect(slotSebepAdi(tr, SlotSebep.cokErken), '24s içinde açılır');
    expect(slotSebepAdi(en, SlotSebep.cokErken), 'opens within 24h');
  });

  // ============================== ETKINLIK ==============================
  testWidgets('ETKINLIK: tr → de dil degisimi + ICU cogul sayaclari',
      (tester) async {
    _ekran(tester);
    for (final (locale, sekme, katiliyor) in [
      (const Locale('tr'), 'Yaklaşan (1)', '5 katılıyor'),
      (const Locale('de'), 'Bevorstehend (1)', '5 nehmen teil'),
    ]) {
      await tester.pumpWidget(_etkEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(sekme), findsOneWidget, reason: '$locale sekme');
      expect(find.text(katiliyor), findsOneWidget, reason: '$locale sayac');
      // Etkinlik basligi SUNUCU verisi — cevrilmez.
      expect(find.text('Mac izleme aksami'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  test('ETKINLIK: ICU cogul (ru/ar) katilim sayaclari', () async {
    final ru = await AppLocalizations.delegate.load(const Locale('ru'));
    expect(ru.etkKatiliyorSayisi(1), contains('придёт'));
    expect(ru.etkKatiliyorSayisi(3), contains('придут'));
    final ar = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(ar.etkKatiliyorSayisi(0), contains('لا أحد'));
    expect(ar.etkKatiliyorSayisi(2), contains('شخصان'));
  });

  // ================================ IZIN ================================
  testWidgets('IZIN: tr → fr dil degisimi (durum rozeti + eylemler)',
      (tester) async {
    _ekran(tester);
    for (final (locale, baslik, bekliyor) in [
      (const Locale('tr'), 'GÖRÜNTÜLEME İZNİ', 'Bekliyor'),
      (const Locale('fr'), 'AUTORISATION DE CONSULTATION', 'En attente'),
    ]) {
      await tester.pumpWidget(_izinEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(baslik), findsOneWidget, reason: '$locale baslik');
      expect(find.text(bekliyor), findsWidgets, reason: '$locale durum');
      // Daire no SUNUCU verisi.
      expect(find.textContaining('A-12'), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });

  test('KIMLIK: uc enum METIN TASIMAZ, cozucu 7 dilde doludur', () async {
    for (final dil in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
      final l10n = await AppLocalizations.delegate.load(Locale(dil));
      for (final d in RezervasyonDurum.values) {
        expect(rezDurumAdi(l10n, d).trim(), isNotEmpty, reason: '$dil/$d');
      }
      for (final d in KatilimDurum.values) {
        expect(katilimDurumAdi(l10n, d).trim(), isNotEmpty, reason: '$dil/$d');
      }
      for (final d in AccessRequestDurum.values) {
        expect(erisimDurumAdi(l10n, d).trim(), isNotEmpty, reason: '$dil/$d');
      }
      for (final s in SlotSebep.values) {
        expect(slotSebepAdi(l10n, s).trim(), isNotEmpty, reason: '$dil/$s');
      }
    }
  });

  // ==================== PLACEHOLDER SIRASI (regresyon) ==================
  //
  // gen-l10n, ARB'de `placeholders` metadata'si YOKSA parametreleri ALFABETIK
  // siralar. Cagri yerleri mesajin OKUMA sirasini varsayarsa metin sessizce
  // yanlis kurulur (test etmeden gorunmez!). Tur 5 denetiminde 6 anahtarda
  // bulundu — 1'i tur 3'ten (`sureSaatDakika`), 2'si tur 4'ten
  // (`binaTopluOnizleme`, `binaDaireEklendi`) SIZMIS durumdaydi. Cozum: tum
  // cok-placeholder'li anahtarlara MESAJ SIRASINDA metadata. Bu test sirayi
  // KILITLER.
  test('COK-PLACEHOLDER anahtarlarda parametre sirasi MESAJ sirasidir',
      () async {
    final tr = await AppLocalizations.delegate.load(const Locale('tr'));

    // tur 5
    expect(tr.rezMusaitOzeti('08:00', '22:00', '60'),
        '08:00–22:00 · 60 dk slot');
    expect(tr.rezSatirOzet('2026-12-31', '10:00', '11:00', '4'),
        '2026-12-31 · 10:00-11:00 · 4 kişi');
    expect(tr.rezDetayTarih('2026-12-31', '10:00', '11:00'),
        'Tarih: 2026-12-31 · 10:00-11:00');
    expect(tr.izinTopluGonderildi('7', ' (2 zaten açık)'),
        '7 daire için istek gönderildi (2 zaten açık) — sakin onayları bekleniyor');
    // tur 3 (sizmis hata)
    expect(tr.sureSaatDakika('1', '30'), '1 sa 30 dk');
    expect(tr.devriyeNoktaSayaci('3', '8'), '3/8 nokta');
    // tur 4 (sizmis hatalar)
    expect(tr.binaDaireEklendi('12', ' (2 zaten vardı, atlandı)'),
        '12 daire eklendi ✓ (2 zaten vardı, atlandı)');
    expect(tr.binaTopluOnizleme('101', '140', '40', '4', '10'),
        '101 … 140  (40 daire, 4 kat × 10)');
  });

  // ================================= RTL ================================
  testWidgets('RTL: REZERVASYON Arapca (form-yogun) — alan formu TASMAZ',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(
        _rezEkrani(const Locale('ar'), role: UserRole.yonetici));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('الحجوزات (1)'))),
        TextDirection.rtl);
    expect(tester.takeException(), isNull);

    // "Yeni alan" formu: ad + aciklama + saatler + slot uzunlugu (form-yogun).
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('التوفر (كل يوم)'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'alan formu Arapca metinlerle tasmamali');
  });

  testWidgets('RTL: ETKINLIK Arapca (form-yogun) — etkinlik formu TASMAZ',
      (tester) async {
    _ekran(tester, h: 1600);
    await tester.pumpWidget(_etkEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.text('قادمة (1)'))),
        TextDirection.rtl);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('الوصف *'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'etkinlik formu Arapca metinlerle tasmamali');
  });

  testWidgets('RTL: IZIN Arapca — istek karti + eylemler TASMAZ',
      (tester) async {
    _ekran(tester);
    await tester.pumpWidget(_izinEkrani(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.textContaining('A-12').first)),
        TextDirection.rtl);
    expect(tester.takeException(), isNull,
        reason: 'izin karti Arapca metinlerle tasmamali');
  });

  // ---- TUR 24: EKRAN SURUSU (bkz. README — sozluk degil EKRAN olcumu) ----
  testWidgets('SURUS: rezervasyon ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_rezEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });

  testWidgets('SURUS: etkinlik ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_etkEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });

  testWidgets('SURUS: goruntuleme izni ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_izinEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });



  // ---- TUR 26: DAR EKRAN SURUSU (320 dp x 6 dil) ----
  testWidgets('DAR 320dp: rezervasyon ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _rezEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('DAR 320dp: etkinlik ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _etkEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('DAR 320dp: izin ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _izinEkrani(Locale(dil)),
        veri: surusVerisi);
  });

  // ---- TUR 27: YAZI OLCEGI SURUSU (2.0x x 6 dil) ----
  testWidgets('OLCEK 2x: rez ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _rezEkrani(Locale(dil)), veri: surusVerisi);
  });
  testWidgets('OLCEK 2x: etk ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _etkEkrani(Locale(dil)), veri: surusVerisi);
  });
  testWidgets('OLCEK 2x: izin ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _izinEkrani(Locale(dil)), veri: surusVerisi);
  });

  // ---- TUR 29: EKRAN OKUYUCU SURUSU ----
  testWidgets('OKUYUCU: rez ekrani (etiket + dokunma hedefi + dil)',
      (tester) async {
    await ekranOkuyucuSurusu(tester, (dil) => _rezEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('OKUYUCU: etk ekrani (etiket + dokunma hedefi + dil)',
      (tester) async {
    await ekranOkuyucuSurusu(tester, (dil) => _etkEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('OKUYUCU: izin ekrani (etiket + dokunma hedefi + dil)',
      (tester) async {
    await ekranOkuyucuSurusu(tester, (dil) => _izinEkrani(Locale(dil)),
        veri: surusVerisi);
  });

  // ---- TUR 32: KOYU TEMA ----
  testWidgets('KOYU TEMA: rezEkrani 7 dilde (kontrast + tasma)',
      (tester) async {
    await koyuTemaSurusu(tester, (dil) => _rezEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('KOYU TEMA: etkEkrani 7 dilde (kontrast + tasma)',
      (tester) async {
    await koyuTemaSurusu(tester, (dil) => _etkEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('KOYU TEMA: izinEkrani 7 dilde (kontrast + tasma)',
      (tester) async {
    await koyuTemaSurusu(tester, (dil) => _izinEkrani(Locale(dil)),
        veri: surusVerisi);
  });

  // ---- TUR 33: KLAVYE ----
  testWidgets('KLAVYE: rezEkrani (odak sirasi + tuzak + dokunma-yalniz)',
      (tester) async {
    await klavyeSurusu(tester, (dil) => _rezEkrani(Locale(dil)));
  });
  testWidgets('KLAVYE: etkEkrani (odak sirasi + tuzak + dokunma-yalniz)',
      (tester) async {
    await klavyeSurusu(tester, (dil) => _etkEkrani(Locale(dil)));
  });
  testWidgets('KLAVYE: izinEkrani (odak sirasi + tuzak + dokunma-yalniz)',
      (tester) async {
    await klavyeSurusu(tester, (dil) => _izinEkrani(Locale(dil)));
  });
}
