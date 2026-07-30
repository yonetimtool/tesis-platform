/// TUR 65 — AYARLAR + GOREV KATEGORILERI: EYLEM ZINCIRLERI.
///
/// Ucuncu envanterin A maddesi, ekran kismi. Iki ekran surusluyordu ama yalniz
/// CIZIM olarak:
///   * `settings_screen` (%36): dil secim alt sayfasi hic ACILMIYORDU, tema
///     segmenti hic DEGISTIRILMIYORDU, tesis adi kaydetme (basari + iki hata
///     dali) hic KOSMUYORDU, ve ROL KAPILARI (tesis adi yalniz yoneticide,
///     kamera yonetimi admin/yonetici) tek rolle olculuyordu.
///   * `task_categories_screen` (%49): ekle/sil diyaloglari acilmiyordu; iptal
///     dali, bos ad dali ve API hatasi dali karanliktaydi.
///
/// Bu testler EYLEMI yurutur ve SONUCU olcer: hangi API cagrildi, hangi mesaj
/// cizildi, liste tazelendi mi.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/core/i18n/locale_controller.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/settings/presentation/settings_screen.dart';
import 'package:mobile/src/features/tasks/data/task_category_api.dart';
import 'package:mobile/src/features/tasks/domain/task_category_models.dart';
import 'package:mobile/src/features/tasks/presentation/task_categories_screen.dart';
import 'package:mobile/src/features/tenant/data/tenant_api.dart';
import 'package:mobile/src/features/tenant/domain/tenant_models.dart';

import 'helpers/l10n_test_app.dart';

class _SahteTenantApi extends TenantApi {
  _SahteTenantApi({this.hata}) : super(Dio());
  final Object? hata;
  final gonderilenAdlar = <String>[];

  @override
  Future<TenantSettings> getSettings() async =>
      const TenantSettings(tenantId: 't-1', ad: 'Acme Plaza');

  @override
  Future<TenantSettings> updateAd(String ad) async {
    gonderilenAdlar.add(ad);
    if (hata != null) throw hata!;
    return TenantSettings(tenantId: 't-1', ad: ad);
  }
}

class _SahteKategoriApi extends TaskCategoryApi {
  _SahteKategoriApi({this.items = const [], this.hata}) : super(Dio());
  List<TaskCategory> items;
  final Object? hata;

  final eklenen = <String>[];
  final silinen = <String>[];
  int listeCagrisi = 0;

  @override
  Future<List<TaskCategory>> fetchAll() async {
    listeCagrisi++;
    return items;
  }

  @override
  Future<TaskCategory> create(String ad) async {
    eklenen.add(ad);
    if (hata != null) throw hata!;
    return TaskCategory(id: 'yeni', ad: ad, aktif: true);
  }

  @override
  Future<void> delete(String id) async {
    silinen.add(id);
    if (hata != null) throw hata!;
  }
}

Widget _ayarlar({
  UserRole rol = UserRole.yonetici,
  _SahteTenantApi? tenant,
}) => ProviderScope(
  overrides: [
    currentUserRoleProvider.overrideWith((ref) async => rol),
    tenantApiProvider.overrideWithValue(tenant ?? _SahteTenantApi()),
  ],
  child: l10nApp(const SettingsScreen(), locale: const Locale('tr')),
);

Widget _kategoriler(_SahteKategoriApi api) => ProviderScope(
  overrides: [taskCategoryApiProvider.overrideWithValue(api)],
  child: l10nApp(const TaskCategoriesScreen(), locale: const Locale('tr')),
);

void main() {
  group('Ayarlar — rol kapilari', () {
    testWidgets('YONETICI: tesis adi karti ve kamera yonetimi GORUNUR', (
      tester,
    ) async {
      await tester.pumpWidget(_ayarlar(rol: UserRole.yonetici));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsWidgets, reason: 'tesis adi alani');
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    });

    testWidgets('SAKIN: tesis adi ve kamera yonetimi GIZLI', (tester) async {
      await tester.pumpWidget(_ayarlar(rol: UserRole.resident));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.videocam_outlined), findsNothing,
          reason: 'kamera yonetimi yalniz admin/yonetici');
      expect(find.byType(TextField), findsNothing,
          reason: 'tesis adini yalniz yonetici degistirir');
    });

    testWidgets('ADMIN: kamera yonetimi VAR, tesis adi YOK', (tester) async {
      await tester.pumpWidget(_ayarlar(rol: UserRole.admin));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('Ayarlar — dil ve tema', () {
    testWidgets('DIL ALT SAYFASI aciliyor ve secim UYGULANIYOR', (tester) async {
      await tester.pumpWidget(_ayarlar());
      await tester.pumpAndSettle();
      // Dil satirina dokun — alt sayfa acilir.
      await tester.tap(find.byIcon(Icons.translate_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(RadioListTile<AppDil>), findsNWidgets(AppDil.values.length),
          reason: 'her dil bir satir');
      // Almanca'yi sec: alt sayfa kapanir ve secim kalir.
      await tester.tap(find.text(AppDil.de.adKendiDilinde));
      await tester.pumpAndSettle();
      expect(find.byType(RadioListTile<AppDil>), findsNothing,
          reason: 'secimden sonra alt sayfa kapanmali');
    });

    testWidgets('TEMA segmenti: koyu secilince mod degisir', (tester) async {
      // Tema karti listenin ALTINDA; varsayilan 800x600 goruntude `ListView`
      // onu hic kurmuyor (tembel liste). Goruntu buyutulur.
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_ayarlar());
      await tester.pumpAndSettle();
      final segment = find.byType(SegmentedButton<ThemeMode>);
      expect(segment, findsOneWidget);
      await tester.tap(find.byIcon(Icons.dark_mode_outlined));
      await tester.pumpAndSettle();
      final secili = tester
          .widget<SegmentedButton<ThemeMode>>(segment)
          .selected;
      expect(secili, {ThemeMode.dark});
    });
  });

  group('Ayarlar — tesis adi kaydetme', () {
    testWidgets('BASARI: ad gonderilir ve onay mesaji cizilir', (tester) async {
      final api = _SahteTenantApi();
      await tester.pumpWidget(_ayarlar(tenant: api));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Yeni Tesis');
      await tester.pump();
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();
      expect(api.gonderilenAdlar, ['Yeni Tesis']);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('BOS AD: istek ATILMAZ', (tester) async {
      final api = _SahteTenantApi();
      await tester.pumpWidget(_ayarlar(tenant: api));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.pump();
      final dugme = find.byType(FilledButton).first;
      if (tester.widget<FilledButton>(dugme).onPressed != null) {
        await tester.tap(dugme);
        await tester.pumpAndSettle();
      }
      expect(api.gonderilenAdlar, isEmpty, reason: 'bos ad gonderilmemeli');
    });

    testWidgets('API HATASI: sunucu metni SnackBar ile gosterilir', (
      tester,
    ) async {
      final api = _SahteTenantApi(
        hata: const ApiException(
          code: 'validation_error',
          message: 'Ad cok kisa',
          statusCode: 422,
        ),
      );
      await tester.pumpWidget(_ayarlar(tenant: api));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Ab');
      await tester.pump();
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();
      expect(find.text('Ad cok kisa'), findsOneWidget);
    });

    testWidgets('BEKLENMEYEN hata: genel mesaj, cokme YOK', (tester) async {
      final api = _SahteTenantApi(hata: StateError('bozuk'));
      await tester.pumpWidget(_ayarlar(tenant: api));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Bir Ad');
      await tester.pump();
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Gorev kategorileri — eylem zincirleri', () {
    testWidgets('EKLE: diyalog acilir, ad gonderilir, liste TAZELENIR', (
      tester,
    ) async {
      final api = _SahteKategoriApi(
        items: const [TaskCategory(id: 'k1', ad: 'Temizlik', aktif: true)],
      );
      await tester.pumpWidget(_kategoriler(api));
      await tester.pumpAndSettle();
      final ilkListe = api.listeCagrisi;

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Peyzaj');
      await tester.tap(find.text('Ekle'));
      await tester.pumpAndSettle();

      expect(api.eklenen, ['Peyzaj']);
      expect(api.listeCagrisi, greaterThan(ilkListe),
          reason: 'ekleme sonrasi liste tazelenmeli');
    });

    testWidgets('EKLE - VAZGEC: istek ATILMAZ', (tester) async {
      final api = _SahteKategoriApi();
      await tester.pumpWidget(_kategoriler(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Yazilmadi');
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(api.eklenen, isEmpty);
    });

    testWidgets('EKLE - BOS AD: istek ATILMAZ', (tester) async {
      final api = _SahteKategoriApi();
      await tester.pumpWidget(_kategoriler(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '   ');
      await tester.tap(find.text('Ekle'));
      await tester.pumpAndSettle();
      expect(api.eklenen, isEmpty, reason: 'bos ad gonderilmemeli');
    });

    testWidgets('EKLE - API HATASI: hata mesaji cizilir', (tester) async {
      final api = _SahteKategoriApi(
        hata: const ApiException(
          code: 'conflict',
          message: 'Bu ad zaten var',
          statusCode: 409,
        ),
      );
      await tester.pumpWidget(_kategoriler(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Temizlik');
      await tester.tap(find.text('Ekle'));
      await tester.pumpAndSettle();
      expect(api.eklenen, ['Temizlik']);
      expect(find.textContaining('Bu ad zaten var'), findsWidgets);
    });

    testWidgets('SIL: onay diyalogu + silme istegi', (tester) async {
      final api = _SahteKategoriApi(
        items: const [TaskCategory(id: 'k1', ad: 'Temizlik', aktif: true)],
      );
      await tester.pumpWidget(_kategoriler(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      expect(api.silinen, ['k1']);
    });

    testWidgets('SIL - VAZGEC: silme istegi ATILMAZ', (tester) async {
      final api = _SahteKategoriApi(
        items: const [TaskCategory(id: 'k1', ad: 'Temizlik', aktif: true)],
      );
      await tester.pumpWidget(_kategoriler(api));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(api.silinen, isEmpty);
    });
  });
}
