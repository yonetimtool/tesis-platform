import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/rezervasyon/data/rezervasyon_api.dart';
import 'package:mobile/src/features/rezervasyon/domain/rezervasyon_models.dart';
import 'package:mobile/src/features/rezervasyon/presentation/rezervasyon_screen.dart';

/// Aga cikmayan sahte istemci — listeler sabit doner; iptal/rezerve cagrilari
/// kaydedilir (widget testi). ONAY AKISI YOK: karar yerine iptal.
class _FakeRezervasyonApi extends RezervasyonApi {
  _FakeRezervasyonApi(this._alanlar, this._items) : super(Dio());

  final List<OrtakAlan> _alanlar;
  final List<Rezervasyon> _items;
  final List<String> cancelled = [];
  final List<RezervasyonDraft> requested = [];

  /// Sabit slot izgarasi: 10-11 rezerve edilebilir, 11-12 DOLU (secilemez),
  /// 12-13 rezerve edilebilir (talep formu testi).
  final List<Slot> slots = const [
    Slot(baslangic: '10:00', bitis: '11:00', dolu: false,
        rezerveEdilebilir: true),
    Slot(baslangic: '11:00', bitis: '12:00', dolu: true,
        rezerveEdilebilir: false, sebep: 'dolu'),
    Slot(baslangic: '12:00', bitis: '13:00', dolu: false,
        rezerveEdilebilir: true),
  ];

  @override
  Future<List<Slot>> fetchSlots(String alanId, String date) async => slots;

  @override
  Future<List<OrtakAlan>> fetchAreas() async => _alanlar;

  @override
  Future<List<Rezervasyon>> fetchReservations() async => _items;

  @override
  Future<Rezervasyon> cancel(String id) async {
    cancelled.add(id);
    return _items.first;
  }

  @override
  Future<Rezervasyon> createReservation(RezervasyonDraft draft) async {
    requested.add(draft);
    return _items.isEmpty
        ? Rezervasyon.fromJson(const {'id': 'yeni'})
        : _items.first;
  }
}

OrtakAlan _alan({String id = 'a-1', String ad = 'Havuz', bool aktif = true}) =>
    OrtakAlan(id: id, ad: ad, aktif: aktif, createdAt: DateTime.utc(2026, 7));

Rezervasyon _r({
  String id = 'r-1',
  RezervasyonDurum durum = RezervasyonDurum.onaylandi,
  String talepEdenUserId = 'res-1',
  String? iptalEdenAd,
  String tarih = '2026-07-15',
}) =>
    Rezervasyon(
      id: id,
      alanId: 'a-1',
      alanAd: 'Havuz',
      unitId: 'u-1',
      unitNo: 'A-12',
      tarih: tarih,
      baslangic: '10:00',
      bitis: '12:00',
      kisiSayisi: 4,
      notlar: 'Aile yuzme saati',
      durum: durum,
      talepEdenUserId: talepEdenUserId,
      talepEdenAd: 'Acme Sakin',
      iptalEdenAd: iptalEdenAd,
      iptalZamani: iptalEdenAd == null ? null : DateTime.utc(2026, 7, 11, 8),
      createdAt: DateTime.utc(2026, 7, 10, 9),
    );

(_FakeRezervasyonApi, Widget) _app(
  UserRole role, {
  List<OrtakAlan>? alanlar,
  List<Rezervasyon> items = const [],
  String? initialRezervasyonId,
  String userId = 'res-1',
}) {
  final api = _FakeRezervasyonApi(alanlar ?? [_alan()], items);
  return (
    api,
    ProviderScope(
      overrides: [
        rezervasyonApiProvider.overrideWithValue(api),
        currentUserRoleProvider.overrideWith((ref) async => role),
        currentUserIdProvider.overrideWith((ref) async => userId),
      ],
      child: MaterialApp(
        home: RezervasyonScreen(initialRezervasyonId: initialRezervasyonId),
      ),
    ),
  );
}

void main() {
  group('FAB rol gorunurlugu (auth.md §4 kesin kurali)', () {
    testWidgets('resident: "Yeni rezervasyon" GORUNUR', (tester) async {
      final (_, app) = _app(UserRole.resident, items: [_r()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Yeni rezervasyon'), findsOneWidget);
      expect(find.text('Yeni alan'), findsNothing);
    });

    for (final role in [UserRole.admin, UserRole.yonetici]) {
      testWidgets('${role.name}: "Yeni alan" GORUNUR (rezerve edemez)',
          (tester) async {
        final (_, app) = _app(role, items: [_r()]);
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.text('Yeni alan'), findsOneWidget);
        expect(find.text('Yeni rezervasyon'), findsNothing);
      });
    }
  });

  group('Onay akisi YOK: karar butonlari hicbir rolde YOK', () {
    for (final role in [
      UserRole.yonetici,
      UserRole.admin,
      UserRole.resident,
    ]) {
      testWidgets('${role.name}: Onayla/Reddet YOK (aninda onaylandi)',
          (tester) async {
        final (_, app) = _app(role, items: [_r()]);
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.text('Onayla'), findsNothing);
        expect(find.text('Reddet'), findsNothing);
      });
    }
  });

  group('İptal butonu (rezerve eden sakin + yonetim)', () {
    testWidgets('resident KENDI onayli rezervasyonunda İptal gorur; onaylayinca '
        'API cagirir', (tester) async {
      final (api, app) = _app(UserRole.resident,
          items: [_r(talepEdenUserId: 'res-1')], userId: 'res-1');
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('İptal et'), findsOneWidget);

      await tester.tap(find.text('İptal et'));
      await tester.pumpAndSettle();
      // onay dialogu -> Evet
      await tester.tap(find.text('Evet, iptal et'));
      await tester.pumpAndSettle();
      expect(api.cancelled, ['r-1']);
    });

    testWidgets('resident BASKASININ rezervasyonunda İptal GORMEZ',
        (tester) async {
      final (_, app) = _app(UserRole.resident,
          items: [_r(talepEdenUserId: 'res-2')], userId: 'res-1');
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('İptal et'), findsNothing);
    });

    testWidgets('yonetici herhangi onayli rezervasyonu iptal edebilir',
        (tester) async {
      final (_, app) = _app(UserRole.yonetici,
          items: [_r(talepEdenUserId: 'res-9')]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('İptal et'), findsOneWidget);
    });

    testWidgets('zaten iptal edilmis rezervasyonda İptal YOK; iptal bilgisi var',
        (tester) async {
      final (_, app) = _app(
        UserRole.yonetici,
        items: [_r(durum: RezervasyonDurum.iptal, iptalEdenAd: 'Acme Sakin')],
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('İptal et'), findsNothing);
      expect(find.textContaining('İptal edildi'), findsOneWidget);
    });
  });

  group('sekmeler', () {
    testWidgets('Rezervasyonlar/Takvim/Alanlar sayaclari dogru', (tester) async {
      final (_, app) = _app(UserRole.yonetici, items: [
        _r(),
        _r(id: 'r-2', durum: RezervasyonDurum.iptal, iptalEdenAd: 'Acme Sakin'),
      ]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Rezervasyonlar (2)'), findsOneWidget);
      expect(find.text('Takvim (1)'), findsOneWidget); // yalniz onayli
      expect(find.text('Alanlar (1)'), findsOneWidget);
    });

    testWidgets('Takvim sekmesi onayli slotu gun basligiyla listeler',
        (tester) async {
      final (_, app) = _app(UserRole.yonetici, items: [
        _r(id: 'r-2', tarih: '2026-07-20'),
      ]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Takvim (1)'));
      await tester.pumpAndSettle();
      expect(find.text('2026-07-20'), findsWidgets); // gun basligi
      expect(find.textContaining('10:00-12:00'), findsOneWidget);
    });

    testWidgets('Alanlar sekmesi: yonetim aktiflik anahtari gorur',
        (tester) async {
      final (_, app) = _app(UserRole.yonetici);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alanlar (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Havuz'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('Alanlar sekmesi: sakin aktiflik anahtari GORMEZ',
        (tester) async {
      final (_, app) = _app(UserRole.resident);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alanlar (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Havuz'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
    });
  });

  testWidgets('sakin rezerve formu: alan + tarih + slot secimi + kisi; '
      'gonderim secili slotu API\'ye tasir', (tester) async {
    final (api, app) = _app(UserRole.resident);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni rezervasyon'));
    await tester.pumpAndSettle();
    expect(find.text('Ortak alan'), findsOneWidget);
    expect(find.textContaining('Tarih: '), findsOneWidget);
    expect(find.text('Slot seç'), findsOneWidget);
    expect(find.text('Kişi sayısı:'), findsOneWidget);
    expect(find.text('Not (opsiyonel)'), findsOneWidget);
    // Slot chip'leri: rezerve edilebilir secilebilir, DOLU olan "· dolu" etiketli.
    expect(find.text('10:00–11:00'), findsOneWidget);
    expect(find.text('11:00–12:00 · dolu'), findsOneWidget);

    // Slot secmeden gonderim engelli (buton pasif) -> API cagrilmaz.
    await tester.tap(find.text('Talep gönder'));
    await tester.pumpAndSettle();
    expect(api.requested, isEmpty);

    // Rezerve edilebilir slot secilince gonderim o slotu tasir.
    await tester.tap(find.text('12:00–13:00'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Talep gönder'));
    await tester.tap(find.text('Talep gönder'));
    await tester.pumpAndSettle();
    expect(api.requested, hasLength(1));
    expect(api.requested.single.alanId, 'a-1');
    expect(api.requested.single.baslangic, '12:00');
    expect(api.requested.single.bitis, '13:00');
    expect(api.requested.single.kisiSayisi, 2);
  });

  testWidgets('yonetim alan formu acar: ad + aciklama', (tester) async {
    final (_, app) = _app(UserRole.yonetici);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni alan'));
    await tester.pumpAndSettle();
    expect(find.text('Alan adı * (örn. Havuz)'), findsOneWidget);
    expect(find.text('Açıklama (opsiyonel)'), findsOneWidget);
    expect(find.text('Alanı ekle'), findsOneWidget);
  });

  group('push tiklamasi (initialRezervasyonId)', () {
    testWidgets('liste yuklenince ilgili kaydin detayi OTOMATIK acilir',
        (tester) async {
      final (_, app) = _app(
        UserRole.yonetici,
        items: [_r()],
        initialRezervasyonId: 'r-1',
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      // Detay sheet'e ozgu satirlar: talep eden + kisi sayisi detayi.
      expect(find.textContaining('Acme Sakin'), findsOneWidget);
      expect(find.textContaining('Kişi sayısı: 4'), findsOneWidget);
      // Yonetim icin sheet'te de İptal (kart + sheet).
      expect(find.text('İptal et'), findsNWidgets(2));
    });

    testWidgets('kayit listede yoksa sessizce listede kalinir (cokme yok)',
        (tester) async {
      final (_, app) = _app(
        UserRole.resident,
        items: [_r()],
        initialRezervasyonId: 'olmayan-id',
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Havuz'), findsOneWidget); // liste ekrani
      expect(tester.takeException(), isNull);
    });
  });
}
