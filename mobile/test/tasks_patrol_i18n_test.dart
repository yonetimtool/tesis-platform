/// GOREV + DEVRIYE i18n (tur 3) — dil degistirme ornegi, KIMLIK/METIN ayrimi
/// ve RTL (Arapca) denetimi.
///
/// Kritik iddia (kart-kimligi refactor'unun bu turdaki karsiligi):
///   * `taskKategoriStyle` GORUNEN METIN URETMEZ — kategorisiz gorevde `ad`
///     null doner, etiketi ekran cizim aninda cozer. Dil degisse de renk/ikon
///     (yani kimlik) AYNI kalir.
///   * Denetleyiciler `BuildContext`siz metin uretmez: hata KIMLIGI dondurur
///     (`GorevAkisHatasi` / `DevriyeAkisHatasi`), ekran ceviriyi yazar.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/features/checkpoints/data/checkpoint_api.dart';
import 'package:mobile/src/features/patrol/data/patrol_plan_api.dart';
import 'package:mobile/src/features/patrol/domain/patrol_hata.dart';
import 'package:mobile/src/features/patrol/presentation/devriye_hata_metni.dart';
import 'package:mobile/src/features/patrol/presentation/patrol_plans_screen.dart';
import 'package:mobile/src/features/tasks/data/task_api.dart';
import 'package:mobile/src/features/tasks/data/task_category_api.dart';
import 'package:mobile/src/features/tasks/domain/task_category_models.dart';
import 'package:mobile/src/features/tasks/domain/task_hata.dart';
import 'package:mobile/src/features/tasks/domain/task_models.dart';
import 'package:mobile/src/features/tasks/presentation/gorev_hata_metni.dart';
import 'package:mobile/src/features/tasks/presentation/task_tip_style.dart';
import 'package:mobile/src/features/tasks/presentation/tasks_controller.dart';
import 'package:mobile/src/features/tasks/presentation/tasks_screen.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

// --------------------------------------------------------------------------
// Sahte durumlar
// --------------------------------------------------------------------------
class _SabitTasks extends TasksController {
  _SabitTasks(this._durum);

  final TasksState _durum;

  @override
  TasksState build() => _durum;

  // Ekran initState'te kapsami set eder; gercek gerceklestirim AGA cikardi.
  @override
  Future<void> setSadeceBenim(bool value) async {}

  @override
  Future<void> refresh({bool silent = false}) async {}
}

/// `/users` icin SABIT yanit veren adapter.
///
/// Neden Dio seviyesinde: `fetchAssignableUsers` bir EXTENSION uyesidir
/// (`TaskManageApi on TaskApi`) ve extension'lar STATIK cozulur — alt sinifla
/// EZILEMEZ. Stub'lanacak tek nokta Dio'dur. (Stub olmazsa gercek istemci
/// asili kalir ve form sonsuza dek "yukleniyor" cizer.)
class _SabitUsersAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        jsonEncode({
          'items': [
            {
              'id': 'u1',
              'ad': 'Ali Veli',
              'role': 'security',
              'is_active': true,
            },
          ],
          'meta': {'total': 1},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

TaskApi _sabitTaskApi() =>
    TaskApi(Dio()..httpClientAdapter = _SabitUsersAdapter());

class _FakeKategoriApi extends TaskCategoryApi {
  _FakeKategoriApi() : super(Dio());

  @override
  Future<List<TaskCategory>> fetchAll() async =>
      const [TaskCategory(id: 'k1', ad: 'Temizlik', aktif: true)];
}

final _gorevler = [
  const Task(id: 't1', ad: 'Havuz temizliği', aktif: true, fotoZorunlu: true),
  // Kategorisiz gorev: etiketi "Diğer" DILDEN cozulur.
  const Task(id: 't2', ad: 'Kazan dairesi', aktif: true),
];

Widget _tasksEkrani(Locale locale, {TasksState? durum}) => ProviderScope(
      overrides: [
        tasksControllerProvider.overrideWith(
          () => _SabitTasks(durum ??
              TasksState(tasks: _gorevler, canManage: true, sadeceBenim: false)),
        ),
        taskCategoriesProvider.overrideWith((ref) async => const [
              TaskCategory(id: 'k1', ad: 'Temizlik', aktif: true),
            ]),
        taskApiProvider.overrideWithValue(_sabitTaskApi()),
        taskCategoryApiProvider.overrideWithValue(_FakeKategoriApi()),
        checkpointsProvider.overrideWith((ref) async => const [
              Checkpoint(
                  id: 'c1', ad: 'Ana Kapı', nfcTagUid: '04A2B3', aktif: true),
            ]),
      ],
      child: l10nApp(const TasksScreen(yonetimGorunumu: true), locale: locale),
    );

Widget _planlarEkrani(Locale locale) => ProviderScope(
      overrides: [
        patrolPlansProvider.overrideWith((ref) async => const [
              PatrolPlan(
                id: 'p1',
                ad: 'Gece devriyesi',
                baslangicSaat: '22:00:00',
                bitisSaat: '06:00:00',
                periyotDakika: 60,
                aktif: false,
              ),
            ]),
        checkpointsProvider.overrideWith((ref) async => const [
              Checkpoint(
                  id: 'c1', ad: 'Ana Kapı', nfcTagUid: '04A2B3', aktif: true),
            ]),
      ],
      child: l10nApp(const PatrolPlansScreen(), locale: locale),
    );

void main() {
  // ------------------------------------------------------------------ tasks
  testWidgets('GOREV listesi: tr → en → ru dil degisimi metinleri cevirir, '
      'duzeni korur', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final (locale, yeniGorev, digerKategori) in [
      (const Locale('tr'), 'Yeni görev', 'Diğer'),
      (const Locale('en'), 'New task', 'Other'),
      (const Locale('ru'), 'Новая задача', 'Другое'),
    ]) {
      await tester.pumpWidget(_tasksEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(yeniGorev), findsOneWidget, reason: '$locale FAB');
      // Kategorisiz gorevin etiketi + filtre cipi AYNI anahtardan gelir.
      expect(find.text(digerKategori), findsWidgets, reason: '$locale kategori');
      // Duzen dilden BAGIMSIZ: iki gorev satiri her dilde cizilir.
      expect(find.text('Havuz temizliği'), findsOneWidget);
      expect(find.text('Kazan dairesi'), findsOneWidget);
    }
  });

  testWidgets('GOREV: kategori KIMLIGI dilden bagimsiz (renk/ikon sabit)',
      (tester) async {
    // Ayni kategori adi -> ayni renk; kategorisiz -> ad null (metin YOK).
    final a = taskKategoriStyle('Temizlik');
    final b = taskKategoriStyle('Temizlik');
    final bos = taskKategoriStyle(null);
    expect(a.color, b.color);
    expect(a.ad, 'Temizlik');
    expect(bos.ad, isNull, reason: 'domain METIN uretmemeli');
    expect(bos.color, taskKategoriStyle('').color);
  });

  testWidgets('GOREV: denetleyici hata KIMLIGI ekranda cevrilir',
      (tester) async {
    await tester.pumpWidget(_tasksEkrani(
      const Locale('en'),
      durum: const TasksState(hataKimligi: GorevAkisHatasi.beklenmeyen),
    ));
    await tester.pumpAndSettle();
    // TR sabiti DEGIL, aktif dilin metni gorunur.
    expect(find.textContaining('Beklenmeyen'), findsNothing);
    expect(find.textContaining('unexpected error'), findsOneWidget);
  });

  // TUR 13: ag hatasi ARTIK `core`dan TR cumle olarak gelmiyor. Denetleyici
  // `e.agHatasi`yi modul kimligine cevirir, ekran onu aktif dilde cizer.
  testWidgets('GOREV: AG hatasi ekranda aktif dilde cikar (TR sizmaz)',
      (tester) async {
    for (final (locale, beklenen) in [
      (const Locale('en'), 'The server could not be reached'),
      (const Locale('de'), 'Der Server ist nicht erreichbar'),
    ]) {
      await tester.pumpWidget(_tasksEkrani(
        locale,
        // Sunucu METNI BOS — zarf hic gelmedi; metin yalniz kimlikten uretilir.
        durum: const TasksState(
          errorMessage: '',
          hataKimligi: GorevAkisHatasi.agUlasilamadi,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining(beklenen), findsOneWidget, reason: '$locale');
      expect(find.textContaining('ulaşılamadı'), findsNothing,
          reason: '$locale TR sizintisi');
    }
  });

  test('GOREV hata kimliklerinin HEPSI 7 dilde karsilik bulur', () async {
    for (final dil in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
      final l10n = await AppLocalizations.delegate.load(Locale(dil));
      for (final h in GorevAkisHatasi.values) {
        final metin = gorevHataMetni(l10n, h);
        expect(metin.trim(), isNotEmpty, reason: '$dil / $h');
      }
      for (final h in DevriyeAkisHatasi.values) {
        expect(devriyeHataMetni(l10n, h).trim(), isNotEmpty,
            reason: '$dil / $h');
      }
    }
  });

  // ----------------------------------------------------------------- patrol
  testWidgets('DEVRIYE planlari: tr → de → ar dil degisimi', (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final (locale, planEkle, pasif) in [
      (const Locale('tr'), 'Plan ekle', 'Pasif'),
      (const Locale('de'), 'Plan hinzufügen', 'Inaktiv'),
      (const Locale('ar'), 'إضافة خطة', 'غير نشط'),
    ]) {
      await tester.pumpWidget(_planlarEkrani(locale));
      await tester.pumpAndSettle();

      expect(find.text(planEkle), findsOneWidget, reason: '$locale FAB');
      expect(find.text(pasif), findsOneWidget, reason: '$locale durum cipi');
      // Plan adi SUNUCU verisidir — cevrilmez, her dilde aynidir.
      expect(find.text('Gece devriyesi'), findsOneWidget);
    }
  });

  testWidgets('DEVRIYE: ICU cogul (ru) okutma sayacinda dogru kategori',
      (tester) async {
    final ru = await AppLocalizations.delegate.load(const Locale('ru'));
    expect(ru.devriyeOkutmaBekliyor(1), contains('ожидает отправки'));
    expect(ru.devriyeOkutmaBekliyor(3), contains('ожидают отправки'));
    expect(ru.devriyeOkutmaBekliyor(11), contains('ожидают отправки'));

    final ar = await AppLocalizations.delegate.load(const Locale('ar'));
    // ar: zero/one/two ayri kategoriler.
    expect(ar.devriyeOkutmaBekliyor(0), isNot(contains('0')));
    expect(ar.devriyeOkutmaBekliyor(1), contains('واحدة'));
    expect(ar.devriyeOkutmaBekliyor(2), contains('عمليتا'));
  });

  // -------------------------------------------------------------------- RTL
  testWidgets('RTL: GOREV formu (form-yogun) Arapca yonde cizilir',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_tasksEkrani(const Locale('ar')));
    await tester.pumpAndSettle();
    // FAB'dan formu ac (form-yogun ekran).
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final yon = Directionality.of(
        tester.element(find.text('اسم المهمة')));
    expect(yon, TextDirection.rtl, reason: 'Arapca form RTL olmali');
    // Form alan etiketleri Arapca; tasma YOK.
    expect(find.text('نوع المهمة'), findsOneWidget);
    expect(find.text('الوصف (اختياري)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL: DEVRIYE plan formu (form-yogun) Arapca yonde cizilir',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_planlarEkrani(const Locale('ar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final yon = Directionality.of(tester.element(find.text('اسم الخطة')));
    expect(yon, TextDirection.rtl);
    expect(find.text('خطة دورية جديدة'), findsOneWidget);
    // UID gibi LTR diziler izolasyon isaretleriyle sarilir (ters gorunmez).
    expect(
      find.byWidgetPredicate((w) =>
          w is Text && (w.data ?? '').contains('\u2068') &&
          (w.data ?? '').contains('04A2B3')),
      findsOneWidget,
      reason: 'UID LTR izolasyonlu olmali',
    );
    expect(tester.takeException(), isNull);
  });

  // ---- TUR 24: EKRAN SURUSU (bkz. README — sozluk degil EKRAN olcumu) ----
  testWidgets('SURUS: gorevler ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_tasksEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });

  testWidgets('SURUS: devriye planlari ekrani 6 dilde TR sabit tasimaz', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    for (final dil in surusDilleri) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_planlarEkrani(Locale(dil)));
      await tester.pumpAndSettle();
      trSizintisiYok(tester, dil, veri: surusVerisi);
    }
  });



  // ---- TUR 26: DAR EKRAN SURUSU (320 dp x 6 dil) ----
  testWidgets('DAR 320dp: gorevler ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _tasksEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('DAR 320dp: devriye planlari ekrani 6 dilde TASMAZ', (tester) async {
    await darEkranSurusu(tester, (dil) => _planlarEkrani(Locale(dil)),
        veri: surusVerisi);
  });

  // ---- TUR 27: YAZI OLCEGI SURUSU (2.0x x 6 dil) ----
  testWidgets('OLCEK 2x: tasks ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _tasksEkrani(Locale(dil)), veri: surusVerisi);
  });
  testWidgets('OLCEK 2x: planlar ekrani 6 dilde TASMAZ', (tester) async {
    await yaziOlcegiSurusu(tester, (dil) => _planlarEkrani(Locale(dil)), veri: surusVerisi);
  });

  // ---- TUR 29: EKRAN OKUYUCU SURUSU ----
  testWidgets('OKUYUCU: tasks ekrani (etiket + dokunma hedefi + dil)',
      (tester) async {
    await ekranOkuyucuSurusu(tester, (dil) => _tasksEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('OKUYUCU: planlar ekrani (etiket + dokunma hedefi + dil)',
      (tester) async {
    await ekranOkuyucuSurusu(tester, (dil) => _planlarEkrani(Locale(dil)),
        veri: surusVerisi);
  });

  // ---- TUR 32: KOYU TEMA ----
  testWidgets('KOYU TEMA: tasksEkrani 7 dilde (kontrast + tasma)',
      (tester) async {
    await koyuTemaSurusu(tester, (dil) => _tasksEkrani(Locale(dil)),
        veri: surusVerisi);
  });
  testWidgets('KOYU TEMA: planlarEkrani 7 dilde (kontrast + tasma)',
      (tester) async {
    await koyuTemaSurusu(tester, (dil) => _planlarEkrani(Locale(dil)),
        veri: surusVerisi);
  });

  // ---- TUR 33: KLAVYE ----
  testWidgets('KLAVYE: tasksEkrani (odak sirasi + tuzak + dokunma-yalniz)',
      (tester) async {
    await klavyeSurusu(tester, (dil) => _tasksEkrani(Locale(dil)));
  });
  testWidgets('KLAVYE: planlarEkrani (odak sirasi + tuzak + dokunma-yalniz)',
      (tester) async {
    await klavyeSurusu(tester, (dil) => _planlarEkrani(Locale(dil)));
  });
}
