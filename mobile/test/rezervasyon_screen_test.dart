import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/rezervasyon/data/rezervasyon_api.dart';
import 'package:mobile/src/features/rezervasyon/domain/rezervasyon_models.dart';
import 'package:mobile/src/features/rezervasyon/presentation/rezervasyon_controller.dart';
import 'package:mobile/src/features/rezervasyon/presentation/rezervasyon_screen.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// Aga cikmayan sahte istemci — listeler + slotlar sabit doner; iptal/rezerve
/// cagrilari kaydedilir. ONAY AKISI YOK: karar yerine iptal (yalniz sakin).
class _FakeRezervasyonApi extends RezervasyonApi {
  _FakeRezervasyonApi(this._alanlar, this._items, {List<Slot>? slots})
      : _slots = slots ?? const [],
        super(Dio());

  final List<OrtakAlan> _alanlar;
  final List<Rezervasyon> _items;
  final List<Slot> _slots;
  final List<String> cancelled = [];
  final List<RezervasyonDraft> requested = [];
  final List<OrtakAlanDraft> createdAreas = [];
  final List<({String id, Map<String, dynamic> patch})> patchedAreas = [];

  @override
  Future<List<Slot>> fetchSlots(String alanId, String date) async => _slots;

  @override
  Future<OrtakAlan> createArea(OrtakAlanDraft draft) async {
    createdAreas.add(draft);
    return _alanlar.isEmpty ? _alan() : _alanlar.first;
  }

  @override
  Future<OrtakAlan> updateArea(String id, Map<String, dynamic> patch) async {
    patchedAreas.add((id: id, patch: patch));
    return _alanlar.firstWhere((a) => a.id == id, orElse: () => _alan());
  }

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

/// Uzak-gelecek tarihli (iptal edilebilir: >10 dk) onayli rezervasyon.
Rezervasyon _r({
  String id = 'r-1',
  RezervasyonDurum durum = RezervasyonDurum.onaylandi,
  String talepEdenUserId = 'res-1',
  String? iptalEdenAd,
  String tarih = '2026-12-31',
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
  List<Slot>? slots,
  String? initialRezervasyonId,
  String userId = 'res-1',
}) {
  final api = _FakeRezervasyonApi(alanlar ?? [_alan()], items, slots: slots);
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
  group('FAB rol gorunurlugu — rezervasyon ALANLAR-ONCE (ayri FAB yok)', () {
    testWidgets('resident: "Yeni rezervasyon" FAB YOK (alanlar-once akis)',
        (tester) async {
      final (_, app) = _app(UserRole.resident, items: [_r()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Yeni rezervasyon'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    for (final role in [UserRole.admin, UserRole.yonetici]) {
      testWidgets('${role.name}: yalniz "Yeni alan" FAB', (tester) async {
        final (_, app) = _app(role, items: [_r()]);
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.text('Yeni alan'), findsOneWidget);
      });
    }
  });

  group('sekmeler', () {
    testWidgets('YALNIZ Rezervasyonlar + Alanlar (Takvim sekmesi KALDIRILDI)',
        (tester) async {
      // Yonetimde "Rezervasyonlar" sayisi alan sayisidir (icerik alan tile'lari
      // — slot izleme); 1 alan → "Rezervasyonlar (1)".
      final (_, app) = _app(UserRole.yonetici, items: [
        _r(),
        _r(id: 'r-2', durum: RezervasyonDurum.iptal, iptalEdenAd: 'Acme Sakin'),
      ]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Rezervasyonlar (1)'), findsOneWidget);
      expect(find.text('Alanlar (1)'), findsOneWidget);
      expect(find.textContaining('Takvim'), findsNothing);
    });

    testWidgets('resident: "Rezervasyonlar" sayisi KENDI kayit sayisi (DEGISMEDI)',
        (tester) async {
      final (_, app) = _app(UserRole.resident, items: [_r()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Rezervasyonlar (1)'), findsOneWidget);
      expect(find.text('Alanlar (1)'), findsOneWidget);
    });
  });

  group('İptal kurallari (yalniz rezerve eden sakin; yonetim iptal etmez)', () {
    testWidgets('resident KENDI onayli rezervasyonunda İptal gorur; onaylayinca '
        'API cagirir', (tester) async {
      final (api, app) = _app(UserRole.resident,
          items: [_r(talepEdenUserId: 'res-1')], userId: 'res-1');
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('İptal et'), findsOneWidget);
      await tester.tap(find.text('İptal et'));
      await tester.pumpAndSettle();
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

    testWidgets('yonetici iptal EDEMEZ (İptal butonu YOK — yalniz izler)',
        (tester) async {
      final (_, app) = _app(UserRole.yonetici,
          items: [_r(talepEdenUserId: 'res-9')]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('İptal et'), findsNothing);
    });

    testWidgets('zaten iptal edilmis rezervasyonda İptal YOK; iptal bilgisi var',
        (tester) async {
      // Rezervasyon KART listesi (iptal bilgisiyle) resident'in "Rezervasyonlar"
      // sekmesindedir; yonetim rezervasyonlari slot izgarasindan izler.
      final (_, app) = _app(
        UserRole.resident,
        items: [_r(durum: RezervasyonDurum.iptal, iptalEdenAd: 'Acme Sakin')],
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('İptal et'), findsNothing);
      expect(find.textContaining('İptal edildi'), findsOneWidget);
    });
  });

  group('RezervasyonState.canCancel (10 dk kurali — saf mantik)', () {
    RezervasyonState st({bool canRequest = true, String? userId = 'res-1'}) =>
        RezervasyonState(canRequest: canRequest, currentUserId: userId);

    Rezervasyon at(Duration fromNow,
        {RezervasyonDurum durum = RezervasyonDurum.onaylandi,
        String owner = 'res-1'}) {
      final s = DateTime.now().add(fromNow);
      return Rezervasyon(
        id: 'x',
        alanId: 'a-1',
        unitId: 'u-1',
        tarih: '${s.year}-${_two(s.month)}-${_two(s.day)}',
        baslangic: '${_two(s.hour)}:${_two(s.minute)}',
        bitis: '${_two(s.hour)}:${_two(s.minute)}',
        kisiSayisi: 2,
        durum: durum,
        talepEdenUserId: owner,
        createdAt: DateTime.utc(2026, 7),
      );
    }

    test('kendi + onayli + >10 dk kala -> iptal edilebilir', () {
      expect(st().canCancel(at(const Duration(hours: 2))), isTrue);
    });
    test('kendi + onayli + <10 dk kala -> iptal EDILEMEZ', () {
      expect(st().canCancel(at(const Duration(minutes: 5))), isFalse);
    });
    test('baskasinin rezervasyonu -> iptal edilemez', () {
      expect(st().canCancel(at(const Duration(hours: 2), owner: 'res-2')),
          isFalse);
    });
    test('yonetim (canRequest=false) -> iptal edilemez', () {
      expect(st(canRequest: false).canCancel(at(const Duration(hours: 2))),
          isFalse);
    });
    test('iptal edilmis -> iptal edilemez', () {
      expect(
          st().canCancel(
              at(const Duration(hours: 2), durum: RezervasyonDurum.iptal)),
          isFalse);
    });
  });

  group('ALANLAR-ONCE: alana dokun → gunun slotlari (rol-farkinda gorunurluk)',
      () {
    List<Slot> slots({String? busyUnit, int? busyKisi}) => [
          const Slot(
              baslangic: '10:00',
              bitis: '11:00',
              dolu: false,
              rezerveEdilebilir: true),
          Slot(
              baslangic: '11:00',
              bitis: '12:00',
              dolu: true,
              rezerveEdilebilir: false,
              sebep: 'dolu',
              unitNo: busyUnit,
              kisiSayisi: busyKisi),
        ];

    testWidgets('resident: dolu slot yalniz "Dolu" (kimlik/kisi GIZLI); '
        'bos slot "Seç" ile rezerve edilir', (tester) async {
      // resident gorunumunde sunucu unit_no/kisi_sayisi=null doner.
      final (_, app) = _app(UserRole.resident, slots: slots());
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alanlar (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Havuz'));
      await tester.pumpAndSettle();
      // dolu slot etiketi yalniz "Dolu"; daire/kisi bilgisi YOK.
      expect(find.text('Dolu'), findsOneWidget);
      expect(find.textContaining('Daire'), findsNothing);
      // bos + rezerve edilebilir slotta "Seç" butonu var.
      expect(find.text('Seç'), findsOneWidget);
    });

    testWidgets('yonetici: slot izleme REZERVASYONLAR sekmesinde — dolu slotta '
        'rezerve eden DAIRE + kisi; "Seç" YOK (rezerve etmez)', (tester) async {
      // REORG: yonetici slot izleme "Rezervasyonlar" (ilk/varsayilan) sekmesinde;
      // "Alanlar" sekmesine GECMEDEN alana dokunup izgarayi acar.
      final (_, app) = _app(UserRole.yonetici,
          slots: slots(busyUnit: 'A-12', busyKisi: 4));
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Havuz')); // Rezervasyonlar sekmesindeki tile
      await tester.pumpAndSettle();
      expect(find.textContaining('Daire A-12'), findsOneWidget);
      expect(find.textContaining('4 kişi'), findsOneWidget);
      // Yonetim rezerve etmez: "Seç" butonu yok.
      expect(find.text('Seç'), findsNothing);
    });

    testWidgets('resident bos slotu ayirtir: Seç → kisi sayisi + Rezerve et → '
        'API secili slot + kisi ile cagrilir', (tester) async {
      final (api, app) = _app(UserRole.resident, slots: slots());
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alanlar (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Havuz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seç'));
      await tester.pumpAndSettle();
      // Rezerve formu: kisi sayisi + not.
      expect(find.text('Kişi sayısı:'), findsOneWidget);
      expect(find.text('Not (opsiyonel)'), findsOneWidget);
      // kisi sayisini artir (2 -> 3).
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Rezerve et'));
      await tester.tap(find.widgetWithText(FilledButton, 'Rezerve et'));
      await tester.pumpAndSettle();
      expect(api.requested, hasLength(1));
      expect(api.requested.single.alanId, 'a-1');
      expect(api.requested.single.baslangic, '10:00');
      expect(api.requested.single.bitis, '11:00');
      expect(api.requested.single.kisiSayisi, 3);
    });

    testWidgets('resident KENDI dolu slotunu gorur: aktif "Rezervasyonunuz" + '
        'gecmis "(geçti)"; BASKASININKI anonim "Dolu"', (tester) async {
      // Sunucu resident'a benim=true doner (kendi rezervasyonu). Aktif/gecmis
      // ayrimini istemci bitis+simdi ile yapar; gunun sonu (23:59) aktif,
      // basi (00:30) gecmis kabul edilir (test ortami gun-ici saatte kosar).
      final ownSlots = <Slot>[
        const Slot(
            baslangic: '23:00',
            bitis: '23:59',
            dolu: true,
            benim: true), // aktif -> yesil "Rezervasyonunuz"
        const Slot(
            baslangic: '00:00',
            bitis: '00:30',
            dolu: true,
            benim: true), // gecmis -> kirmizi "Rezervasyonunuz (geçti)"
        const Slot(
            baslangic: '12:00',
            bitis: '13:00',
            dolu: true,
            benim: false), // baskasi -> anonim "Dolu"
      ];
      final (_, app) = _app(UserRole.resident, slots: ownSlots);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alanlar (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Havuz'));
      await tester.pumpAndSettle();
      // Kendi rezervasyonu isaretli (kimlik degil — yalniz "sizin").
      expect(find.text('Rezervasyonunuz'), findsOneWidget);
      expect(find.text('Rezervasyonunuz (geçti)'), findsOneWidget);
      // Baskasinin dolu slotu anonim "Dolu" (kimlik/kisi YOK).
      expect(find.text('Dolu'), findsOneWidget);
      expect(find.textContaining('Daire'), findsNothing);
    });
  });

  group('Alanlar sekmesi aktiflik anahtari', () {
    testWidgets('yonetim aktiflik anahtari gorur', (tester) async {
      final (_, app) = _app(UserRole.yonetici);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alanlar (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Havuz'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('sakin aktiflik anahtari GORMEZ (chevron ile alan detayina gider)',
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

  group('YONETICI sekme reorg (slot izleme → Rezervasyonlar; yonetim → Alanlar)',
      () {
    testWidgets('Rezervasyonlar sekmesi: alan tile\'lari (rezervasyon KARTI DEGIL)',
        (tester) async {
      // Ilk sekme yonetici icin alan tile listesi; duz rezervasyon kart listesi
      // DEGIL (o slot izgarasina tasindi).
      final (_, app) = _app(UserRole.yonetici, items: [_r()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.textContaining('dokunup slotları gör'), findsOneWidget);
      // Rezervasyon kartina ozgu icerik (not) ILK sekmede YOK.
      expect(find.text('Aile yuzme saati'), findsNothing);
    });

    testWidgets('Alanlar sekmesi: alana dokun → DUZENLE formu (slot izgarasi YOK)',
        (tester) async {
      final (_, app) = _app(
        UserRole.yonetici,
        alanlar: [_alan(ad: 'Havuz')],
        slots: const [
          Slot(
              baslangic: '10:00',
              bitis: '11:00',
              dolu: false,
              rezerveEdilebilir: true),
        ],
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alanlar (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Havuz'));
      await tester.pumpAndSettle();
      // Yonetim Alanlar sekmesinde alana dokununca DUZENLE formu acilir.
      expect(find.text('Alanı düzenle'), findsOneWidget);
      expect(find.text('Kaydet'), findsOneWidget);
      // Slot izgarasi BURADA acilmaz (Boş/Seç yok).
      expect(find.text('Boş'), findsNothing);
      expect(find.text('Seç'), findsNothing);
    });

    testWidgets('Alanlar duzenle: Kaydet → updateArea alan id ile (aktiflik HARIC)',
        (tester) async {
      final (api, app) =
          _app(UserRole.yonetici, alanlar: [_alan(ad: 'Havuz')]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alanlar (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Havuz'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.pumpAndSettle();
      expect(api.patchedAreas, hasLength(1));
      expect(api.patchedAreas.single.id, 'a-1');
      expect(api.patchedAreas.single.patch['ad'], 'Havuz');
      // Aktiflik ayri anahtarla yonetilir — duzenleme PATCH'i onu tasimaz.
      expect(api.patchedAreas.single.patch.containsKey('aktif'), isFalse);
    });

    testWidgets('yonetim "Yeni alan" FAB: create formu (slot izgarasi degil)',
        (tester) async {
      final (_, app) = _app(UserRole.yonetici);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yeni alan'));
      await tester.pumpAndSettle();
      expect(find.text('Yeni ortak alan'), findsOneWidget);
      expect(find.text('Alanı ekle'), findsOneWidget);
    });
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
        UserRole.resident,
        items: [_r(talepEdenUserId: 'res-1')],
        initialRezervasyonId: 'r-1',
        userId: 'res-1',
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.textContaining('Acme Sakin'), findsOneWidget);
      expect(find.textContaining('Kişi sayısı: 4'), findsOneWidget);
      // Sakin kendi kaydinda sheet'te de İptal (kart + sheet).
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
      expect(find.text('Havuz'), findsWidgets); // liste ekrani
      expect(tester.takeException(), isNull);
    });
  });
}
