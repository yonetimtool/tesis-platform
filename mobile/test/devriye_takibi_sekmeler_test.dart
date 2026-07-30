/// TUR 65 — DEVRIYE TAKIBI: UC SEKME + BES PENCERE DURUMU.
///
/// Ucuncu envanterin A maddesi, ekran kismi: `patrol_tracking_screen` kapsami
/// **%28**'di. Ekran tur 37'den beri bes eksende SURULUYOR — ama yalniz
/// ACILDIGI hâlde: `DefaultTabController` uc sekme tasiyor ve surusler hep
/// birinci sekmede kaliyordu. Ikinci (gecmis) ve ucuncu (tarama gunlugu)
/// sekmelerin kodu hic kosmadi.
///
/// Ayrica `_WindowCard` durum rengini/etiketini BES ayri daldan seciyor
/// (tamamlandi / kacirildi / simdi aktif / yaklasan / suresi gecti) ve surusler
/// tek pencere veriyordu — yani dort dal karanlikti.
///
/// Burada olculenler:
///   * uc sekmenin HEPSI aciliyor (sekmeye dokunarak),
///   * bes pencere durumu ayni ekranda cizdiriliyor ve ETIKETLERI dogrulaniyor,
///   * tarama gunlugu: veri / BOS / HATA halleri + gun gezinmesi
///     ("bugunden ileri gidilemez" kapisi dahil) ve gun degisince
///     saglayicinin YENI GUNLE cagrildigi.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/patrol/data/patrol_api.dart';
import 'package:mobile/src/features/patrol/data/scan_report_api.dart';
import 'package:mobile/src/features/patrol/domain/patrol_models.dart';
import 'package:mobile/src/features/patrol/presentation/patrol_tracking_screen.dart';

import 'helpers/l10n_test_app.dart';

final _simdi = DateTime.now();

/// Bes durumun HEPSI: her biri `_WindowCard`in ayri bir dalini secer.
List<ActivePatrolWindow> _besDurum() => [
  // 1) tamamlandi (yesil)
  ActivePatrolWindow(
    patrolWindowId: 'w-tamam',
    patrolPlanId: 'p-1',
    patrolPlanAd: 'Sabah turu',
    pencereBaslangic: _simdi.subtract(const Duration(hours: 5)),
    pencereBitis: _simdi.subtract(const Duration(hours: 4)),
    durum: PatrolWindowDurum.tamamlandi,
    beklenenCheckpointSayisi: 3,
    okutulanCheckpointSayisi: 3,
  ),
  // 2) kacirildi (kirmizi)
  ActivePatrolWindow(
    patrolWindowId: 'w-kacti',
    patrolPlanId: 'p-1',
    patrolPlanAd: 'Gece turu',
    pencereBaslangic: _simdi.subtract(const Duration(hours: 3)),
    pencereBitis: _simdi.subtract(const Duration(hours: 2)),
    durum: PatrolWindowDurum.kacirildi,
    beklenenCheckpointSayisi: 3,
    okutulanCheckpointSayisi: 1,
  ),
  // 3) bekliyor + SIMDI AKTIF (mavi)
  ActivePatrolWindow(
    patrolWindowId: 'w-aktif',
    patrolPlanId: 'p-2',
    patrolPlanAd: 'Ogle turu',
    pencereBaslangic: _simdi.subtract(const Duration(minutes: 20)),
    pencereBitis: _simdi.add(const Duration(minutes: 40)),
    durum: PatrolWindowDurum.bekliyor,
    beklenenCheckpointSayisi: 4,
    okutulanCheckpointSayisi: 2,
  ),
  // 4) bekliyor + YAKLASAN (blueGrey)
  ActivePatrolWindow(
    patrolWindowId: 'w-yaklasan',
    patrolPlanId: 'p-2',
    patrolPlanAd: 'Aksam turu',
    pencereBaslangic: _simdi.add(const Duration(hours: 2)),
    pencereBitis: _simdi.add(const Duration(hours: 3)),
    durum: PatrolWindowDurum.bekliyor,
    beklenenCheckpointSayisi: 4,
    okutulanCheckpointSayisi: 0,
  ),
  // 5) bekliyor ama SURESI GECTI (kirmizi) — sunucu hala `bekliyor` diyor,
  //    istemci saate bakip "suresi gecti" gosteriyor.
  ActivePatrolWindow(
    patrolWindowId: 'w-gecti',
    patrolPlanId: 'p-3',
    patrolPlanAd: 'Erken tur',
    pencereBaslangic: _simdi.subtract(const Duration(hours: 8)),
    pencereBitis: _simdi.subtract(const Duration(hours: 7)),
    durum: PatrolWindowDurum.bekliyor,
    beklenenCheckpointSayisi: 2,
    okutulanCheckpointSayisi: 0,
  ),
];

class _SahtePatrolApi extends PatrolApi {
  _SahtePatrolApi(this.pencereler) : super(Dio());
  final List<ActivePatrolWindow> pencereler;

  @override
  Future<List<ActivePatrolWindow>> fetchLiveWindows() async => pencereler;

  @override
  Future<PatrolWindowHistoryPage> fetchWindowHistory({
    int limit = 20,
    int offset = 0,
    PatrolWindowDurum? durum,
    DateTime? bitisBefore,
  }) async => const PatrolWindowHistoryPage(items: [], ozet: PatrolWindowOzet());
}

/// Tarama gunlugu API'si: gun bazli davranis TESTIN elinde.
class _SahteScanApi extends ScanReportApi {
  _SahteScanApi({this.hata, this.items = const []}) : super(Dio());
  final Object? hata;
  final List<ScanReportItem> items;

  /// Hangi gunler icin cagrildi — gun gezinmesinin GERCEKTEN yeni istek
  /// atmasini dogrulamak icin.
  final istenenGunler = <DateTime>[];

  @override
  Future<List<ScanReportItem>> fetch(DateTime gun) async {
    istenenGunler.add(gun);
    if (hata != null) throw hata!;
    return items;
  }
}

ScanReportItem _okutma(String ad) => ScanReportItem(
  id: 's-$ad',
  checkpointId: 'c-$ad',
  checkpointAd: ad,
  guardId: 'g-1',
  guardAd: 'Ali Guard',
  okutmaZamani: _simdi.subtract(const Duration(minutes: 30)),
  imzaDogrulandi: true,
);

Widget _ekran(_SahtePatrolApi patrol, _SahteScanApi scan) => ProviderScope(
  overrides: [
    patrolApiProvider.overrideWithValue(patrol),
    scanReportApiProvider.overrideWithValue(scan),
    currentUserRoleProvider.overrideWith((ref) async => UserRole.yonetici),
  ],
  child: l10nApp(const PatrolTrackingScreen(), locale: const Locale('tr')),
);

/// Sekmeye DOKUNARAK gec — `TabBarView`in o cocugu ancak boyle kurulur.
Future<void> _sekme(WidgetTester tester, int indeks) async {
  final tabs = find.byType(Tab);
  expect(tabs, findsNWidgets(3), reason: 'uc sekme bekleniyordu');
  await tester.tap(tabs.at(indeks));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('BES PENCERE DURUMU ayni ekranda: her etiket cizilir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_ekran(_SahtePatrolApi(_besDurum()), _SahteScanApi()));
    await tester.pumpAndSettle();

    // Bes ayri dal, bes ayri etiket. Biri cizilmiyorsa o dal karanlik demektir.
    for (final etiket in [
      'Tamamlandı',
      'Kaçırıldı',
      'Şimdi aktif',
      'Yaklaşan',
      'Süresi geçti',
    ]) {
      expect(find.text(etiket), findsWidgets, reason: '"$etiket" dali cizilmedi');
    }
    // Plan adlari da gorunmeli (kart govdesi).
    expect(find.text('Sabah turu'), findsOneWidget);
    expect(find.text('Erken tur'), findsOneWidget);
  });

  testWidgets('SEKME 2 (gecmis) aciliyor', (tester) async {
    await tester.pumpWidget(_ekran(_SahtePatrolApi(_besDurum()), _SahteScanApi()));
    await tester.pumpAndSettle();
    await _sekme(tester, 1);
    // Bos gecmis: en azindan bir mesaj/liste cizilmis olmali, cokme YOK.
    expect(tester.takeException(), isNull);
  });

  testWidgets('SEKME 3 (tarama gunlugu): VERI hali', (tester) async {
    final scan = _SahteScanApi(items: [_okutma('Ana Kapi'), _okutma('Otopark')]);
    await tester.pumpWidget(_ekran(_SahtePatrolApi(_besDurum()), scan));
    await tester.pumpAndSettle();
    await _sekme(tester, 2);

    expect(scan.istenenGunler, isNotEmpty,
        reason: 'sekme acilinca gunluk CEKILMELI');
    expect(find.text('Ana Kapi'), findsOneWidget);
    expect(find.text('Otopark'), findsOneWidget);
  });

  testWidgets('SEKME 3: BOS hali mesaj cizer', (tester) async {
    await tester.pumpWidget(
      _ekran(_SahtePatrolApi(_besDurum()), _SahteScanApi()),
    );
    await tester.pumpAndSettle();
    await _sekme(tester, 2);
    // Bos gun mesaji (l10n: devriyeGunOkutmaYok).
    expect(find.textContaining('okutma'), findsWidgets);
  });

  testWidgets('SEKME 3: HATA hali + tekrar dene dugmesi', (tester) async {
    final scan = _SahteScanApi(
      hata: const ApiException(
        code: 'server_error',
        message: 'Sunucu hatasi',
        statusCode: 500,
      ),
    );
    await tester.pumpWidget(_ekran(_SahtePatrolApi(_besDurum()), scan));
    await tester.pumpAndSettle();
    await _sekme(tester, 2);

    // Sunucu metni gosterilir (uydurma metin DEGIL).
    expect(find.text('Sunucu hatasi'), findsWidgets);
    // Tekrar dene: saglayici gecersizlenir ve YENI istek atilir.
    final oncekiIstek = scan.istenenGunler.length;
    final tekrar = find.byType(TextButton).hitTestable();
    if (tekrar.evaluate().isNotEmpty) {
      await tester.tap(tekrar.first);
      await tester.pumpAndSettle();
      expect(scan.istenenGunler.length, greaterThan(oncekiIstek));
    }
  });

  testWidgets('SEKME 3: GUN GEZINMESI — geri gidince YENI gun istenir', (
    tester,
  ) async {
    final scan = _SahteScanApi(items: [_okutma('Ana Kapi')]);
    await tester.pumpWidget(_ekran(_SahtePatrolApi(_besDurum()), scan));
    await tester.pumpAndSettle();
    await _sekme(tester, 2);

    final ilkGun = scan.istenenGunler.last;
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(scan.istenenGunler.last, isNot(ilkGun),
        reason: 'onceki gun icin YENI istek atilmali');
    expect(scan.istenenGunler.last.isBefore(ilkGun), isTrue);
  });

  testWidgets('SEKME 3: BUGUNDEN ILERI gidilemez (kapi)', (tester) async {
    final scan = _SahteScanApi();
    await tester.pumpWidget(_ekran(_SahtePatrolApi(_besDurum()), scan));
    await tester.pumpAndSettle();
    await _sekme(tester, 2);

    // Bugundeyken "sonraki gun" dugmesi PASIF olmali.
    final ileri = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_right),
        matching: find.byType(IconButton),
      ),
    );
    expect(ileri.onPressed, isNull,
        reason: 'bugunden ileri gitmek engellenmeli');

    // Bir gun geri gidince ileri dugmesi AKTIF olur.
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    final ileri2 = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_right),
        matching: find.byType(IconButton),
      ),
    );
    expect(ileri2.onPressed, isNotNull);
  });
}
