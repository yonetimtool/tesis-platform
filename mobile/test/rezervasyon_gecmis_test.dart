// (P165 §3) MOBIL: AKTIF / GECMIS AYRIMI.
//
// Uc iddia kilitlenir:
//
//  1. AYRIM SUNUCUDA. Istemci `?gecmis=` sorar, kendi saatiyle SUZMEZ:
//     cihaz saati yanlis kurulu olabilir ve `tarih + bitis` ancak TESISIN
//     saat diliminde bir ANA donusur.
//  2. GECMISTE "IPTAL ET" YOK. Bildirilen kusur buydu — saati gecmis
//     kaydin altinda calismayacak bir dugme duruyordu. Yerine salt-okunur
//     durum ("Tamamlandi" / "Iptal edildi") cikar.
//  3. GECMIS TEMBEL YUKLENIR. Sekme acilmadan istek atilmaz; her
//     tazelemede iki istek atmak, gecmise hic bakmayan kullanicida da
//     trafigi ikiye katlardi (web de yalniz ACIK sekmeyi ceker).
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/rezervasyon/data/rezervasyon_api.dart';
import 'package:mobile/src/features/rezervasyon/domain/rezervasyon_models.dart';
import 'package:mobile/src/features/rezervasyon/presentation/rezervasyon_controller.dart';
import 'package:mobile/src/features/rezervasyon/presentation/rezervasyon_screen.dart';

import 'helpers/l10n_test_app.dart';

/// Suzgece GORE farkli liste donen sahte istemci; her cagrinin `gecmis`
/// degerini kaydeder.
class _FakeApi extends RezervasyonApi {
  _FakeApi({required this.aktif, required this.gecmisler}) : super(Dio());

  final List<Rezervasyon> aktif;
  final List<Rezervasyon> gecmisler;

  /// Her `fetchReservations` cagrisinin suzgeci — SIRAYLA.
  final List<bool?> cagrilar = [];

  /// Doluysa `gecmis: true` istegi bu mesajla PATLAR (aktif liste saglam
  /// kalir) — hatanin gecmis sekmesinde gorunup gorunmedigini olcmek icin.
  String? gecmisHatasi;

  @override
  Future<List<OrtakAlan>> fetchAreas() async => [
        OrtakAlan(
            id: 'a-1', ad: 'Havuz', aktif: true, createdAt: DateTime.utc(2026)),
      ];

  @override
  Future<List<Slot>> fetchSlots(String alanId, String date) async => const [];

  @override
  Future<List<Rezervasyon>> fetchReservations({bool? gecmis}) async {
    cagrilar.add(gecmis);
    if (gecmis == true && gecmisHatasi != null) {
      throw ApiException(code: 'server_error', message: gecmisHatasi!);
    }
    return gecmis == true ? gecmisler : aktif;
  }
}

Rezervasyon _r({
  required String id,
  required bool gecmis,
  RezervasyonDurum durum = RezervasyonDurum.onaylandi,
  String alanAd = 'Havuz',
}) =>
    Rezervasyon(
      id: id,
      alanId: 'a-1',
      alanAd: alanAd,
      unitId: 'u-1',
      unitNo: 'A-12',
      tarih: '2026-12-31',
      baslangic: '10:00',
      bitis: '12:00',
      kisiSayisi: 2,
      durum: durum,
      talepEdenUserId: 'res-1',
      talepEdenAd: 'Acme Sakin',
      iptalEdenAd: durum == RezervasyonDurum.iptal ? 'Acme Sakin' : null,
      createdAt: DateTime.utc(2026, 7, 10),
      gecmis: gecmis,
    );

(_FakeApi, Widget) _app({
  List<Rezervasyon> aktif = const [],
  List<Rezervasyon> gecmisler = const [],
}) {
  final api = _FakeApi(aktif: aktif, gecmisler: gecmisler);
  return (
    api,
    ProviderScope(
      overrides: [
        rezervasyonApiProvider.overrideWithValue(api),
        currentUserRoleProvider.overrideWith((ref) async => UserRole.resident),
        currentUserIdProvider.overrideWith((ref) async => 'res-1'),
      ],
      child: l10nApp(const RezervasyonScreen()),
    ),
  );
}

Future<void> _gecmiseGec(WidgetTester tester) async {
  await tester.tap(find.text('Geçmiş'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ILK YUKLEME: yalniz `gecmis: false` sorulur (tembel)',
      (tester) async {
    final (api, app) = _app(aktif: [_r(id: 'r-1', gecmis: false)]);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    // Gecmis sekmesine bakmayan kullanici icin IKINCI ISTEK YOK.
    expect(api.cagrilar, [false]);
  });

  testWidgets('SEKME ACILINCA `gecmis: true` sorulur', (tester) async {
    final (api, app) = _app(
      aktif: [_r(id: 'r-1', gecmis: false)],
      gecmisler: [_r(id: 'r-9', gecmis: true, alanAd: 'Spor salonu')],
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await _gecmiseGec(tester);
    expect(api.cagrilar, [false, true]);
    expect(find.text('Spor salonu'), findsOneWidget);
  });

  testWidgets('SEKMELER ARASI GIDIP GELMEK yeni istek URETMEZ',
      (tester) async {
    final (api, app) = _app(
      aktif: [_r(id: 'r-1', gecmis: false)],
      gecmisler: [_r(id: 'r-9', gecmis: true)],
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await _gecmiseGec(tester);
    await tester.tap(find.textContaining('Rezervasyonlar'));
    await tester.pumpAndSettle();
    await _gecmiseGec(tester);
    expect(api.cagrilar, [false, true]);
  });

  testWidgets('AKTIF kayitta "İptal et" VAR', (tester) async {
    final (_, app) = _app(aktif: [_r(id: 'r-1', gecmis: false)]);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('İptal et'), findsOneWidget);
  });

  testWidgets('GECMIS kayitta "İptal et" YOK — yerine "Tamamlandı"',
      (tester) async {
    final (_, app) = _app(gecmisler: [_r(id: 'r-9', gecmis: true)]);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await _gecmiseGec(tester);
    expect(find.text('İptal et'), findsNothing);
    expect(find.text('Tamamlandı'), findsOneWidget);
    // "Onaylandı" YAZMAZ: kullanim bitti, onay artik bir sey ifade etmiyor.
    expect(find.text('Onaylandı'), findsNothing);
  });

  testWidgets('GECMIS + IPTAL kayitta "İptal edildi" korunur', (tester) async {
    final (_, app) = _app(gecmisler: [
      _r(id: 'r-9', gecmis: true, durum: RezervasyonDurum.iptal),
    ]);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await _gecmiseGec(tester);
    expect(find.text('Tamamlandı'), findsNothing);
    expect(find.text('İptal edildi'), findsWidgets);
  });

  testWidgets(
      'BAYRAK SEKMEDEN BAGIMSIZ: aktif listede gecmise dusen kayitta dugme yok',
      (tester) async {
    // Ekran acikken bitis saati gecebilir; kosul sekme DEGIL, sunucunun
    // her kayit icin dondugu `gecmis` bayragi.
    final (_, app) = _app(aktif: [_r(id: 'r-1', gecmis: true)]);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('İptal et'), findsNothing);
  });

  testWidgets('GECMIS ISTEGI HATA VERIRSE hata GORUNUR — "kayit yok" DEMEZ',
      (tester) async {
    // Olculen kusur: liste bileseninin yukleme/hata kapilari `state.items`e
    // (AKTIF liste) bakiyordu. Aktif listede TEK kayit varsa gecmis
    // istegindeki hata hic gorunmuyor, ekran "Gecmis rezervasyon yok."
    // diyordu — basarisiz istegi BOS SONUC gibi gostermek.
    final api = _FakeApi(
      aktif: [_r(id: 'r-1', gecmis: false)],
      gecmisler: const [],
    )..gecmisHatasi = 'Sunucuya ulasilamadi';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rezervasyonApiProvider.overrideWithValue(api),
          currentUserRoleProvider.overrideWith((ref) async => UserRole.resident),
          currentUserIdProvider.overrideWith((ref) async => 'res-1'),
        ],
        child: l10nApp(const RezervasyonScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await _gecmiseGec(tester);
    expect(find.text('Sunucuya ulasilamadi'), findsOneWidget);
    expect(find.text('Geçmiş rezervasyon yok.'), findsNothing);
  });

  testWidgets('canCancel: gecmis kayda YANLIS izin vermez', (tester) async {
    const st = RezervasyonState(canRequest: true, currentUserId: 'res-1');
    expect(st.canCancel(_r(id: 'a', gecmis: false)), isTrue);
    expect(st.canCancel(_r(id: 'b', gecmis: true)), isFalse);
  });
}
