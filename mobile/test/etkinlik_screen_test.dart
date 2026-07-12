import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/etkinlik/data/etkinlik_api.dart';
import 'package:mobile/src/features/etkinlik/domain/etkinlik_models.dart';
import 'package:mobile/src/features/etkinlik/presentation/etkinlik_screen.dart';

/// Aga cikmayan sahte istemci — liste sabit doner; RSVP cagrilari kaydedilir
/// (widget testi).
class _FakeEtkinlikApi extends EtkinlikApi {
  _FakeEtkinlikApi(this._items) : super(Dio());

  final List<Etkinlik> _items;
  final List<(String, KatilimDurum)> rsvps = [];

  @override
  Future<List<Etkinlik>> fetchAll() async => _items;

  @override
  Future<Etkinlik> rsvp(String id, KatilimDurum durum) async {
    rsvps.add((id, durum));
    return _items.first;
  }
}

Etkinlik _e({
  String id = 'e-1',
  DateTime? tarih,
  int katiliyor = 5,
  int katilmiyor = 2,
  KatilimDurum? benimDurumum,
}) =>
    Etkinlik(
      id: id,
      baslik: 'Mac izleme aksami',
      aciklama: 'Buyuk ekranda milli mac.',
      tarih: tarih ?? DateTime.now().add(const Duration(days: 5)),
      konum: 'Sosyal tesis salonu',
      olusturanUserId: 'yon-1',
      olusturanAd: 'Acme Yonetici',
      katiliyorumSayisi: katiliyor,
      katilmiyorumSayisi: katilmiyor,
      benimDurumum: benimDurumum,
      createdAt: DateTime.utc(2026, 7, 10, 9),
    );

(_FakeEtkinlikApi, Widget) _app(
  UserRole role, {
  List<Etkinlik> items = const [],
  String? initialEtkinlikId,
}) {
  final api = _FakeEtkinlikApi(items);
  return (
    api,
    ProviderScope(
      overrides: [
        etkinlikApiProvider.overrideWithValue(api),
        currentUserRoleProvider.overrideWith((ref) async => role),
      ],
      child: MaterialApp(
        home: EtkinlikScreen(initialEtkinlikId: initialEtkinlikId),
      ),
    ),
  );
}

void main() {
  group('"Yeni etkinlik" FAB rol gorunurlugu (auth.md §4)', () {
    for (final role in [UserRole.admin, UserRole.yonetici]) {
      testWidgets('${role.name}: FAB GORUNUR (yonetim duyurur)',
          (tester) async {
        final (_, app) = _app(role, items: [_e()]);
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.text('Yeni etkinlik'), findsOneWidget);
      });
    }

    for (final role in [
      UserRole.security,
      UserRole.tesisGorevlisi,
      UserRole.resident,
    ]) {
      testWidgets('${role.name}: FAB YOK (olusturma yalniz yonetim)',
          (tester) async {
        final (_, app) = _app(role, items: [_e()]);
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.text('Yeni etkinlik'), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
      });
    }
  });

  group('SEFFAF sayilar (herkes gorur)', () {
    for (final role in [
      UserRole.admin,
      UserRole.yonetici,
      UserRole.security,
      UserRole.tesisGorevlisi,
      UserRole.resident,
    ]) {
      testWidgets('${role.name}: kartta katiliyor/katilmiyor sayilari var',
          (tester) async {
        final (_, app) = _app(role, items: [_e()]);
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.text('5 katılıyor'), findsOneWidget);
        expect(find.text('2 katılmıyor'), findsOneWidget);
      });
    }
  });

  group('RSVP butonlari (yalniz sakin + yaklasan etkinlik)', () {
    testWidgets('resident beyan butonlarini gorur; Katiliyorum API cagirir',
        (tester) async {
      final (api, app) = _app(UserRole.resident, items: [_e()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Katılıyorum'), findsOneWidget);
      expect(find.text('Katılmıyorum'), findsOneWidget);

      await tester.tap(find.text('Katılıyorum'));
      await tester.pumpAndSettle();
      expect(api.rsvps, [('e-1', KatilimDurum.katiliyorum)]);
    });

    testWidgets('beyan degistirilebilir: Katilmiyorum da API cagirir',
        (tester) async {
      final (api, app) = _app(
        UserRole.resident,
        items: [_e(benimDurumum: KatilimDurum.katiliyorum)],
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      // mevcut secim rozet olarak da gorunur
      await tester.tap(find.text('Katılmıyorum').first);
      await tester.pumpAndSettle();
      expect(api.rsvps, [('e-1', KatilimDurum.katilmiyorum)]);
    });

    for (final role in [
      UserRole.admin,
      UserRole.yonetici,
      UserRole.security,
      UserRole.tesisGorevlisi,
    ]) {
      testWidgets('${role.name}: beyan butonu YOK (RSVP yalniz sakin)',
          (tester) async {
        final (_, app) = _app(role, items: [_e()]);
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.text('Katılıyorum'), findsNothing);
        expect(find.text('Katılmıyorum'), findsNothing);
      });
    }

    testWidgets('gecmis etkinlikte beyan butonu YOK', (tester) async {
      final (_, app) = _app(
        UserRole.resident,
        items: [_e(tarih: DateTime(2020, 1, 1, 10))],
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Geçmiş (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Mac izleme aksami'), findsOneWidget);
      expect(find.text('Katılıyorum'), findsNothing);
    });
  });

  group('Yaklasan / Gecmis sekmeleri', () {
    testWidgets('etkinlikler tarihe gore dogru sekmede', (tester) async {
      final (_, app) = _app(UserRole.resident, items: [
        _e(),
        _e(id: 'e-2', tarih: DateTime(2020, 1, 1, 10)),
      ]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Yaklaşan (1)'), findsOneWidget);
      expect(find.text('Geçmiş (1)'), findsOneWidget);
    });

    testWidgets('bos sekmeler anlamli mesaj gosterir', (tester) async {
      final (_, app) = _app(UserRole.resident);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Yaklaşan etkinlik yok.'), findsOneWidget);
      await tester.tap(find.text('Geçmiş (0)'));
      await tester.pumpAndSettle();
      expect(find.text('Geçmiş etkinlik yok.'), findsOneWidget);
    });
  });

  testWidgets('yonetim formu acar: baslik + aciklama + zaman + yer',
      (tester) async {
    final (_, app) = _app(UserRole.yonetici);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni etkinlik'));
    await tester.pumpAndSettle();
    expect(find.text('Başlık * (örn. Maç izleme akşamı)'), findsOneWidget);
    expect(find.text('Açıklama *'), findsOneWidget);
    expect(find.textContaining('Zaman: '), findsOneWidget);
    expect(find.text('Yer (opsiyonel)'), findsOneWidget);
    expect(find.text('Duyur ve sakinlere bildir'), findsOneWidget);
  });

  testWidgets('yonetim detayda Duzenle + Sil gorur', (tester) async {
    final (_, app) = _app(UserRole.yonetici, items: [_e()]);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mac izleme aksami'));
    await tester.pumpAndSettle();
    expect(find.text('Düzenle'), findsOneWidget);
    expect(find.text('Sil'), findsOneWidget);
  });

  group('push tiklamasi (initialEtkinlikId)', () {
    testWidgets('liste yuklenince ilgili etkinligin detayi OTOMATIK acilir',
        (tester) async {
      final (_, app) = _app(
        UserRole.resident,
        items: [_e()],
        initialEtkinlikId: 'e-1',
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      // Detay sheet'e ozgu satirlar: duyuran + tam aciklama gorunur.
      expect(find.textContaining('Duyuran: Acme Yonetici'), findsOneWidget);
      // Sakin icin sheet'te de beyan butonlari (kart + sheet).
      expect(find.text('Katılıyorum'), findsNWidgets(2));
    });

    testWidgets('kayit listede yoksa sessizce listede kalinir (cokme yok)',
        (tester) async {
      final (_, app) = _app(
        UserRole.resident,
        items: [_e()],
        initialEtkinlikId: 'olmayan-id',
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Mac izleme aksami'), findsOneWidget); // liste ekrani
      expect(tester.takeException(), isNull);
    });
  });
}
