/// TUR 37 — SAHA AKISINI SUR.
///
/// Tur 36 envanteri en buyuk kor noktayi olctu: guvenlik/gorevli rolunun
/// GUNLUK IS AKISI — devriye ("Turlarim"), NFC okutma, gorev detayi/tamamlama,
/// cevrimdisi kuyruk — YEDI SURUS EKSENININ HICBIRINDE cizilmemisti
/// (`task_detail_screen` 0/249, `patrol_screen` 3/242, `nfc_screen` 1/189,
/// `outbox_screen` 1/65 satir kapsam). Yani bu ekranlarin cevirisi, dar
/// ekranda tasmasi, buyuk yazi tipi davranisi, koyu tema kontrasti, klavye
/// erisimi ve ekran okuyucu etiketleri hakkinda ELIMIZDE HICBIR OLCUM YOKTU.
///
/// Bu dosya o ekranlari bes eksende surer (`tumEksenlerSurusu`).
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/checkpoints/data/checkpoint_api.dart';
import 'package:mobile/src/features/kargo/data/kargo_api.dart';
import 'package:mobile/src/features/kargo/domain/kargo_models.dart';
import 'package:mobile/src/features/nfc/presentation/nfc_screen.dart';
import 'package:mobile/src/features/patrol/data/patrol_api.dart';
import 'package:mobile/src/features/patrol/domain/patrol_models.dart';
import 'package:mobile/src/features/patrol/presentation/patrol_screen.dart';
import 'package:mobile/src/features/patrol/presentation/patrol_tracking_screen.dart';
import 'package:mobile/src/features/scan/data/scan_outbox.dart';
import 'package:mobile/src/features/scan/domain/outbox_entry.dart';
import 'package:mobile/src/features/scan/presentation/outbox_screen.dart';
import 'package:mobile/src/features/tasks/data/task_category_api.dart';
import 'package:mobile/src/features/tasks/domain/task_category_models.dart';
import 'package:mobile/src/features/tasks/domain/task_models.dart';
import 'package:mobile/src/features/tasks/presentation/task_categories_screen.dart';
import 'package:mobile/src/features/tasks/presentation/task_detail_screen.dart';
import 'package:mobile/src/features/unit_access/presentation/unit_access_records_screen.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

// --------------------------------------------------------------------------
// Sahteler (ag YOK)
// --------------------------------------------------------------------------

/// Kalici depoya gitmeyen outbox: `loaded: true` ile gelir, kayitlar testten.
class _FakeOutbox extends ScanOutbox {
  _FakeOutbox(this._entries);
  final List<OutboxEntry> _entries;

  @override
  ScanOutboxState build() => ScanOutboxState(entries: _entries, loaded: true);

  @override
  Future<void> syncNow() async {}

  @override
  Future<void> pump() async {}

  @override
  Future<void> clearFailed() async {}
}

class _FakePatrolApi extends PatrolApi {
  _FakePatrolApi({
    required this.me,
    this.gecmis = const PatrolWindowHistoryPage(
      items: [],
      ozet: PatrolWindowOzet(),
    ),
  }) : super(Dio());

  final MePatrolWindowResponse me;
  final PatrolWindowHistoryPage gecmis;

  @override
  Future<MePatrolWindowResponse> fetchMyPatrolWindow() async => me;

  // Siradaki pencere karti bilgi amaclidir; surusde bos birakilir.
  @override
  Future<List<ActivePatrolWindow>> fetchLiveWindows() async => const [];

  @override
  Future<List<PlanCheckpoint>> fetchPlanCheckpoints(String planId) async =>
      const [];

  @override
  Future<PatrolWindowHistoryPage> fetchWindowHistory({
    int limit = 50,
    int offset = 0,
    PatrolWindowDurum? durum,
    DateTime? bitisBefore,
  }) async =>
      gecmis;
}

class _FakeCheckpointApi extends CheckpointApi {
  _FakeCheckpointApi(this._items) : super(Dio());
  final List<Checkpoint> _items;

  @override
  Future<List<Checkpoint>> list() async => _items;
}

class _FakeKargoApi extends KargoApi {
  _FakeKargoApi(this._items) : super(Dio());
  final List<Kargo> _items;

  @override
  Future<List<Kargo>> fetchAll({String? unitId, String? durum}) async => _items;
}

class _FakeTaskCategoryApi extends TaskCategoryApi {
  _FakeTaskCategoryApi(this._kategoriler) : super(Dio());
  final List<TaskCategory> _kategoriler;

  @override
  Future<List<TaskCategory>> fetchAll() async => _kategoriler;
}

// --------------------------------------------------------------------------
// Veri (SUNUCU verisi — cevrilmez, `surusVerisi` ile ayni mantik)
// --------------------------------------------------------------------------

final _simdi = DateTime.utc(2026, 7, 20, 10);

MePatrolWindowResponse _pencere({bool eksikOkutma = true}) {
  final cps = [
    MePatrolCheckpoint(
      checkpointId: 'c1',
      ad: 'Ana Kapı',
      sira: 1,
      okutuldu: true,
      okutmaZamani: _simdi.subtract(const Duration(minutes: 12)),
    ),
    MePatrolCheckpoint(
      checkpointId: 'c2',
      ad: 'Otopark',
      sira: 2,
      okutuldu: !eksikOkutma,
    ),
    const MePatrolCheckpoint(
      checkpointId: 'c3',
      ad: 'Havuz',
      sira: 3,
      okutuldu: false,
    ),
  ];
  final item = MePatrolWindowItem(
    id: 'w1',
    patrolPlanId: 'p1',
    planAdi: 'Gece devriyesi',
    pencereBaslangic: _simdi.subtract(const Duration(minutes: 30)),
    pencereBitis: _simdi.add(const Duration(minutes: 30)),
    durum: PatrolWindowDurum.bekliyor,
    checkpoints: cps,
  );
  return MePatrolWindowResponse(
    generatedAt: _simdi,
    window: item,
    windows: [item],
  );
}

final _gecmisSayfa = PatrolWindowHistoryPage(
  items: [
    PatrolWindowHistoryItem(
      id: 'h1',
      patrolPlanId: 'p1',
      planAdi: 'Gece devriyesi',
      pencereBaslangic: _simdi.subtract(const Duration(days: 1, hours: 8)),
      pencereBitis: _simdi.subtract(const Duration(days: 1, hours: 7)),
      durum: PatrolWindowDurum.tamamlandi,
      beklenenCheckpointSayisi: 3,
      okutulanCheckpointSayisi: 3,
    ),
    PatrolWindowHistoryItem(
      id: 'h2',
      patrolPlanId: 'p1',
      planAdi: 'Gece devriyesi',
      pencereBaslangic: _simdi.subtract(const Duration(days: 2, hours: 8)),
      pencereBitis: _simdi.subtract(const Duration(days: 2, hours: 7)),
      durum: PatrolWindowDurum.kacirildi,
      beklenenCheckpointSayisi: 3,
      okutulanCheckpointSayisi: 1,
    ),
  ],
  ozet: const PatrolWindowOzet(toplam: 2, tamamlandi: 1, kacirildi: 1),
  total: 2,
);

final _kuyruk = <OutboxEntry>[
  OutboxEntry(
    idempotencyKey: 'k1',
    nfcTagUid: '04A2B3C4D5',
    okutmaZamani: _simdi.subtract(const Duration(minutes: 3)),
    enqueuedAt: _simdi.subtract(const Duration(minutes: 3)),
    checkpointId: 'c2',
  ),
  OutboxEntry(
    idempotencyKey: 'k2',
    nfcTagUid: '04FFEE1122',
    okutmaZamani: _simdi.subtract(const Duration(minutes: 20)),
    enqueuedAt: _simdi.subtract(const Duration(minutes: 20)),
    checkpointId: 'c3',
    status: OutboxStatus.kaliciHata,
    attemptCount: 3,
    lastError: 'network',
  ),
];

const _gorev = Task(
  id: 't1',
  ad: 'Havuz temizliği',
  aktif: true,
  aciklama: 'Havuz filtresi temizlenecek.',
  atananUserId: 'u-saha',
  kategoriId: 'kat-1',
  oncelik: 'yuksek',
  fotoZorunlu: true,
);

// --------------------------------------------------------------------------
// Ekran kuruculari
// --------------------------------------------------------------------------

Widget _turlarimEkrani(Locale locale, {List<OutboxEntry> kuyruk = const []}) =>
    ProviderScope(
      overrides: [
        patrolApiProvider.overrideWithValue(
          _FakePatrolApi(me: _pencere(), gecmis: _gecmisSayfa),
        ),
        scanOutboxProvider.overrideWith(() => _FakeOutbox(kuyruk)),
        currentUserRoleProvider.overrideWith((ref) async => UserRole.security),
      ],
      child: l10nApp(const PatrolScreen(), locale: locale),
    );

Widget _nfcEkrani(Locale locale) => ProviderScope(
      overrides: [
        scanOutboxProvider.overrideWith(() => _FakeOutbox(const [])),
        checkpointApiProvider.overrideWithValue(
          _FakeCheckpointApi(const [
            Checkpoint(
                id: 'c1', ad: 'Ana Kapı', nfcTagUid: '04A2B3C4D5', aktif: true),
          ]),
        ),
        currentUserRoleProvider.overrideWith((ref) async => UserRole.security),
      ],
      child: l10nApp(const NfcScreen(), locale: locale),
    );

Widget _kuyrukEkrani(Locale locale) => ProviderScope(
      overrides: [
        scanOutboxProvider.overrideWith(() => _FakeOutbox(_kuyruk)),
      ],
      child: l10nApp(const OutboxScreen(), locale: locale),
    );

Widget _gorevDetayEkrani(Locale locale, {UserRole role = UserRole.security}) =>
    ProviderScope(
      overrides: [
        taskCategoryApiProvider.overrideWithValue(
          _FakeTaskCategoryApi(
              const [TaskCategory(id: 'kat-1', ad: 'Temizlik', aktif: true)]),
        ),
        scanOutboxProvider.overrideWith(() => _FakeOutbox(const [])),
        currentUserRoleProvider.overrideWith((ref) async => role),
      ],
      child: l10nApp(const TaskDetailScreen(task: _gorev), locale: locale),
    );

Widget _tirTakipEkrani(Locale locale) => ProviderScope(
      overrides: [
        patrolApiProvider.overrideWithValue(
          _FakePatrolApi(me: _pencere(), gecmis: _gecmisSayfa),
        ),
        scanOutboxProvider.overrideWith(() => _FakeOutbox(const [])),
        currentUserRoleProvider.overrideWith((ref) async => UserRole.yonetici),
      ],
      child: l10nApp(const PatrolTrackingScreen(), locale: locale),
    );

Widget _kategoriEkrani(Locale locale) => ProviderScope(
      overrides: [
        taskCategoryApiProvider.overrideWithValue(
          _FakeTaskCategoryApi(const [
            TaskCategory(id: 'kat-1', ad: 'Temizlik', aktif: true),
            TaskCategory(id: 'kat-2', ad: 'Teknik', aktif: true),
          ]),
        ),
      ],
      child: l10nApp(const TaskCategoriesScreen(), locale: locale),
    );

Widget _daireKayitlariEkrani(Locale locale) => ProviderScope(
      overrides: [
        kargoApiProvider.overrideWithValue(_FakeKargoApi([
          Kargo(
            id: 'kg1',
            unitId: 'u1',
            unitNo: 'A-12',
            firma: 'Aras Kargo',
            durum: KargoDurum.bekliyor,
            kaydedenUserId: 'g1',
            createdAt: _simdi.subtract(const Duration(hours: 2)),
          ),
        ])),
      ],
      child: l10nApp(
        const UnitAccessRecordsScreen(unitId: 'u1', kind: 'kargo'),
        locale: locale,
      ),
    );

// SUNUCU verisi: cevrilmemesi DOGRU olan metinler.
const _veri = {
  'Ana Kapı', 'Otopark', 'Havuz', 'Gece devriyesi', 'Havuz temizliği',
  // Baslik BUYUK harfe cevrilerek cizilir (`baslikBuyuk`, dile duyarli):
  // ayni VERI iki bicimde ekrana gelir, ikisi de allowlist'te olmali.
  'HAVUZ TEMIZLIĞI', 'HAVUZ TEMİZLİĞİ',
  '04A2B3C4D5', '04FFEE1122', 'Temizlik', 'Teknik', 'Aras Kargo', 'A-12',
};

void main() {
  testWidgets('SAHA: Turlarim ekrani (bes eksen)', (tester) async {
    await tumEksenlerSurusu(tester, (dil) => _turlarimEkrani(Locale(dil)),
        veri: _veri);
  });

  testWidgets('SAHA: Turlarim — CEVRIMDISI kuyruk bindirmesi (bes eksen)',
      (tester) async {
    // Bekleyen okutmalar "gonderiliyor" olarak nokta listesine BINDIRILIR;
    // bu dal yalniz kuyruk DOLUYKEN cizilir (tur 36'da hic olculmemisti).
    await tumEksenlerSurusu(
        tester, (dil) => _turlarimEkrani(Locale(dil), kuyruk: _kuyruk),
        veri: _veri);
  });

  testWidgets('SAHA: NFC okutma ekrani (bes eksen)', (tester) async {
    await tumEksenlerSurusu(tester, (dil) => _nfcEkrani(Locale(dil)),
        veri: _veri);
  });

  testWidgets('SAHA: cevrimdisi kuyruk ekrani (bes eksen)', (tester) async {
    await tumEksenlerSurusu(tester, (dil) => _kuyrukEkrani(Locale(dil)),
        veri: _veri);
  });

  testWidgets('SAHA: gorev detayi + tamamlama (bes eksen)', (tester) async {
    await tumEksenlerSurusu(tester, (dil) => _gorevDetayEkrani(Locale(dil)),
        veri: _veri);
  });

  testWidgets('SAHA: Turlarim GECMIS sekmesi (bes eksen)', (tester) async {
    // Ikinci sekme yalniz DOKUNULUNCA cizilir; `patrol_history_view` bu
    // yuzden hic olculmemisti (tur 36). Sekme ikonla secilir — dilden
    // bagimsiz.
    await tumEksenlerSurusu(
      tester,
      (dil) => _turlarimEkrani(Locale(dil)),
      veri: _veri,
      hazirla: (t) async {
        final sekme = find.byType(Tab);
        if (sekme.evaluate().length > 1) {
          await t.tap(sekme.at(1));
          await t.pump();
          await t.pump(const Duration(milliseconds: 400));
        }
      },
    );
  });

  testWidgets('SAHA: tur takip ekrani (bes eksen)', (tester) async {
    await tumEksenlerSurusu(tester, (dil) => _tirTakipEkrani(Locale(dil)),
        veri: _veri);
  });

  testWidgets('SAHA: gorev kategorileri ekrani (bes eksen)', (tester) async {
    await tumEksenlerSurusu(tester, (dil) => _kategoriEkrani(Locale(dil)),
        veri: _veri);
  });

  testWidgets('SAHA: daire kayitlari (kargo) ekrani (bes eksen)',
      (tester) async {
    await tumEksenlerSurusu(tester, (dil) => _daireKayitlariEkrani(Locale(dil)),
        veri: _veri);
  });
}
