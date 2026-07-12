import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/rezervasyon/data/rezervasyon_api.dart';
import 'package:mobile/src/features/rezervasyon/domain/rezervasyon_models.dart';
import 'package:mobile/src/features/rezervasyon/presentation/rezervasyon_screen.dart';

/// Aga cikmayan sahte istemci — listeler sabit doner; karar/talep cagrilari
/// kaydedilir (widget testi).
class _FakeRezervasyonApi extends RezervasyonApi {
  _FakeRezervasyonApi(this._alanlar, this._items) : super(Dio());

  final List<OrtakAlan> _alanlar;
  final List<Rezervasyon> _items;
  final List<(String, bool)> decided = [];
  final List<RezervasyonDraft> requested = [];

  @override
  Future<List<OrtakAlan>> fetchAreas() async => _alanlar;

  @override
  Future<List<Rezervasyon>> fetchReservations() async => _items;

  @override
  Future<Rezervasyon> decide(String id, {required bool onayla}) async {
    decided.add((id, onayla));
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
  RezervasyonDurum durum = RezervasyonDurum.bekliyor,
  String? onaylayanAd,
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
      talepEdenUserId: 'res-1',
      talepEdenAd: 'Acme Sakin',
      onaylayanAd: onaylayanAd,
      kararZamani:
          onaylayanAd == null ? null : DateTime.utc(2026, 7, 11, 8),
      createdAt: DateTime.utc(2026, 7, 10, 9),
    );

(_FakeRezervasyonApi, Widget) _app(
  UserRole role, {
  List<OrtakAlan>? alanlar,
  List<Rezervasyon> items = const [],
  String? initialRezervasyonId,
}) {
  final api = _FakeRezervasyonApi(alanlar ?? [_alan()], items);
  return (
    api,
    ProviderScope(
      overrides: [
        rezervasyonApiProvider.overrideWithValue(api),
        currentUserRoleProvider.overrideWith((ref) async => role),
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
      testWidgets('${role.name}: "Yeni alan" GORUNUR (talep acamaz)',
          (tester) async {
        final (_, app) = _app(role, items: [_r()]);
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.text('Yeni alan'), findsOneWidget);
        expect(find.text('Yeni rezervasyon'), findsNothing);
      });
    }
  });

  group('Onayla/Reddet butonlari (yalniz yonetim + bekleyen talep)', () {
    testWidgets('yonetici bekleyen kartta butonlari gorur; Onayla API cagirir',
        (tester) async {
      final (api, app) = _app(UserRole.yonetici, items: [_r()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Onayla'), findsOneWidget);
      expect(find.text('Reddet'), findsOneWidget);

      await tester.tap(find.text('Onayla'));
      await tester.pumpAndSettle();
      expect(api.decided, [('r-1', true)]);
    });

    testWidgets('resident kendi bekleyen talebinde buton GORMEZ',
        (tester) async {
      final (_, app) = _app(UserRole.resident, items: [_r()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Onayla'), findsNothing);
      expect(find.text('Reddet'), findsNothing);
    });

    testWidgets('sonuclanan talepte buton YOK; karar bilgisi gorunur',
        (tester) async {
      final (_, app) = _app(
        UserRole.yonetici,
        items: [
          _r(durum: RezervasyonDurum.onaylandi, onaylayanAd: 'Acme Yonetici'),
        ],
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sonuçlanan (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Onayla'), findsNothing);
      expect(find.textContaining('Acme Yonetici'), findsOneWidget);
    });
  });

  group('sekmeler', () {
    testWidgets('bekleyen/sonuclanan/takvim sayaclari dogru', (tester) async {
      final (_, app) = _app(UserRole.yonetici, items: [
        _r(),
        _r(
          id: 'r-2',
          durum: RezervasyonDurum.onaylandi,
          onaylayanAd: 'Acme Yonetici',
        ),
        _r(id: 'r-3', durum: RezervasyonDurum.reddedildi,
            onaylayanAd: 'Acme Yonetici'),
      ]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Bekleyen (1)'), findsOneWidget);
      expect(find.text('Sonuçlanan (2)'), findsOneWidget);
      expect(find.text('Takvim (1)'), findsOneWidget); // yalniz onayli
      expect(find.text('Alanlar (1)'), findsOneWidget);
    });

    testWidgets('Takvim sekmesi onayli slotu gun basligiyla listeler',
        (tester) async {
      final (_, app) = _app(UserRole.yonetici, items: [
        _r(
          id: 'r-2',
          durum: RezervasyonDurum.onaylandi,
          onaylayanAd: 'Acme Yonetici',
          tarih: '2026-07-20',
        ),
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

  testWidgets('sakin talep formu: alan secimi + tarih/saat + kisi + not; '
      'gonderim API cagirir', (tester) async {
    final (api, app) = _app(UserRole.resident);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni rezervasyon'));
    await tester.pumpAndSettle();
    expect(find.text('Ortak alan'), findsOneWidget);
    expect(find.textContaining('Tarih: '), findsOneWidget);
    expect(find.textContaining('Başlangıç: 10:00'), findsOneWidget);
    expect(find.textContaining('Bitiş: 12:00'), findsOneWidget);
    expect(find.text('Kişi sayısı:'), findsOneWidget);
    expect(find.text('Not (opsiyonel)'), findsOneWidget);

    await tester.tap(find.text('Talep gönder'));
    await tester.pumpAndSettle();
    expect(api.requested, hasLength(1));
    expect(api.requested.single.alanId, 'a-1');
    expect(api.requested.single.baslangic, '10:00');
    expect(api.requested.single.bitis, '12:00');
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
      // Yonetim icin sheet'te de Onayla/Reddet (kart + sheet).
      expect(find.text('Onayla'), findsNWidgets(2));
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
