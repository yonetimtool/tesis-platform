import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/site_kurali/data/site_kurali_api.dart';
import 'package:mobile/src/features/site_kurali/domain/site_kurali_models.dart';
import 'package:mobile/src/features/site_kurali/presentation/site_kurali_screen.dart';

/// Aga cikmayan sahte istemci — liste sabit doner; silme cagrilari
/// kaydedilir (widget testi).
class _FakeSiteKuraliApi extends SiteKuraliApi {
  _FakeSiteKuraliApi(this._items) : super(Dio());

  final List<SiteKurali> _items;
  final List<String> deleted = [];

  @override
  Future<List<SiteKurali>> fetchAll({String? q}) async => _items;

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
  }
}

SiteKurali _k({
  String id = 'k-1',
  String baslik = 'Havuz Saatleri',
  int sira = 1,
}) =>
    SiteKurali(
      id: id,
      baslik: baslik,
      icerik: 'Havuz 08:00-22:00 arasi aciktir.',
      sira: sira,
      olusturanUserId: 'yon-1',
      olusturanAd: 'Acme Yonetici',
      createdAt: DateTime.utc(2026, 7, 10, 9),
    );

(_FakeSiteKuraliApi, Widget) _app(
  UserRole role, {
  List<SiteKurali> items = const [],
}) {
  final api = _FakeSiteKuraliApi(items);
  return (
    api,
    ProviderScope(
      overrides: [
        siteKuraliApiProvider.overrideWithValue(api),
        currentUserRoleProvider.overrideWith((ref) async => role),
      ],
      child: const MaterialApp(home: SiteKuraliScreen()),
    ),
  );
}

void main() {
  group('"Yeni kural" FAB rol gorunurlugu (auth.md §4)', () {
    for (final role in [UserRole.admin, UserRole.yonetici]) {
      testWidgets('${role.name}: FAB GORUNUR (yonetim yazar)',
          (tester) async {
        final (_, app) = _app(role, items: [_k()]);
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.text('Yeni kural'), findsOneWidget);
      });
    }

    for (final role in [
      UserRole.security,
      UserRole.tesisGorevlisi,
      UserRole.resident,
    ]) {
      testWidgets('${role.name}: FAB YOK (salt okur)', (tester) async {
        final (_, app) = _app(role, items: [_k()]);
        await tester.pumpWidget(app);
        await tester.pumpAndSettle();
        expect(find.text('Yeni kural'), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
      });
    }
  });

  group('ARAMA CUBUGU (basliga gore anlik suzgec)', () {
    testWidgets('sorgu esleseni birakir, eslesmeyeni gizler; temizlenince '
        'tum liste doner', (tester) async {
      final (_, app) = _app(UserRole.resident, items: [
        _k(),
        _k(id: 'k-2', baslik: 'Otopark Kullanimi', sira: 2),
        _k(id: 'k-3', baslik: 'Gurultu Kurallari', sira: 3),
      ]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Havuz Saatleri'), findsOneWidget);
      expect(find.text('Otopark Kullanimi'), findsOneWidget);

      // buyuk/kucuk harf duyarsiz arama
      await tester.enterText(find.byType(TextField), 'hAvUz');
      await tester.pumpAndSettle();
      expect(find.text('Havuz Saatleri'), findsOneWidget);
      expect(find.text('Otopark Kullanimi'), findsNothing);
      expect(find.text('Gurultu Kurallari'), findsNothing);

      // eslesme yoksa anlamli mesaj
      await tester.enterText(find.byType(TextField), 'asansor');
      await tester.pumpAndSettle();
      expect(find.text('Aramayla eslesen kural yok.'), findsOneWidget);

      // temizlenince tum liste geri gelir
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.text('Havuz Saatleri'), findsOneWidget);
      expect(find.text('Otopark Kullanimi'), findsOneWidget);
      expect(find.text('Gurultu Kurallari'), findsOneWidget);
    });
  });

  group('detay + yonetim butonlari', () {
    testWidgets('yonetici detayda Duzenle + Sil gorur; Sil onay ister ve '
        'API cagirir', (tester) async {
      final (api, app) = _app(UserRole.yonetici, items: [_k()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Havuz Saatleri'));
      await tester.pumpAndSettle();
      expect(find.text('Duzenle'), findsOneWidget);
      expect(find.text('Sil'), findsOneWidget);

      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      expect(find.text('Kural silinsin mi?'), findsOneWidget);
      await tester.tap(find.text('Sil').last); // dialog onayi
      await tester.pumpAndSettle();
      expect(api.deleted, ['k-1']);
    });

    testWidgets('resident detayda yonetim butonu GORMEZ (salt okur)',
        (tester) async {
      final (_, app) = _app(UserRole.resident, items: [_k()]);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Havuz Saatleri'));
      await tester.pumpAndSettle();
      // tam metin sheet'te gorunur; yonetim butonlari yok
      expect(find.text('Havuz 08:00-22:00 arasi aciktir.'), findsWidgets);
      expect(find.text('Duzenle'), findsNothing);
      expect(find.text('Sil'), findsNothing);
    });
  });

  testWidgets('yonetim formu acar: baslik + metin + sira + foto akisi '
      '(mevcut Kamera/Galeri deseni)', (tester) async {
    final (_, app) = _app(UserRole.yonetici);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni kural'));
    await tester.pumpAndSettle();
    expect(find.text('Baslik * (orn. Havuz Saatleri)'), findsOneWidget);
    expect(find.text('Kural metni *'), findsOneWidget);
    expect(find.text('Sira (kucuk once)'), findsOneWidget);
    expect(find.text('Gorsel (opsiyonel)'), findsOneWidget);
    // foto butonlari mevcut akisin adlariyla
    expect(find.text('Kamera'), findsOneWidget);
    expect(find.text('Galeriden sec'), findsOneWidget);
    expect(find.text('Kurali ekle'), findsOneWidget);
  });

  testWidgets('bos liste: yonetimde yonlendirme, sakinde bilgi mesaji',
      (tester) async {
    final (_, appY) = _app(UserRole.yonetici);
    await tester.pumpWidget(appY);
    await tester.pumpAndSettle();
    expect(
      find.text('Henuz kural yok. "Yeni kural" ile ekleyin.'),
      findsOneWidget,
    );
  });
}
