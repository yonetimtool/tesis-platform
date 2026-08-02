/// P115 — DEMO MODU: "simüle okutma" YALNIZ denetim tesisinde.
///
/// Apple denetçisi fiziksel NFC etiketi okutamaz ve uygulamanın omurgası
/// (devriye turu) etiketle çalışır — yani denetçi onu HİÇ göremeden
/// reddedebilir. Simüle okutma bu boşluğu kapatır.
///
/// Ama bu, tur kaydının **kanıt değerini** askıya alan bir yoldur; bu
/// yüzden asıl ölçülen şey "çalışıyor mu" değil **"kapalıyken GÖRÜNMÜYOR
/// mu"**dur. Bayrak sunucudan gelir; istemcide tutulsaydı herhangi bir
/// kullanıcı gerçek bir tesiste sahte tur kaydı üretebilirdi.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/checkpoints/data/checkpoint_api.dart';
import 'package:mobile/src/features/checkpoints/presentation/checkpoints_screen.dart';
import 'package:mobile/src/features/scan/data/scan_api.dart';
import 'package:mobile/src/features/scan/domain/scan.dart';
import 'package:mobile/src/features/tenant/data/tenant_api.dart';
import 'package:mobile/src/features/tenant/domain/tenant_models.dart';

import 'helpers/l10n_test_app.dart';

class _SahteCheckpointApi extends CheckpointApi {
  _SahteCheckpointApi() : super(Dio());
  @override
  Future<List<Checkpoint>> list() async => [
        Checkpoint(id: 'cp-1', ad: 'Ana Kapı', nfcTagUid: 'DEMO-NFC-0001', aktif: true),
      ];
}

class _SahteTenantApi extends TenantApi {
  _SahteTenantApi(this.demo) : super(Dio());
  final bool demo;
  @override
  Future<TenantSettings> getSettings() async =>
      TenantSettings(tenantId: 't-1', ad: 'Demo', demoMod: demo);
}

class _SahteScanApi extends ScanApi {
  _SahteScanApi() : super(Dio());
  final gonderilen = <String>[];
  @override
  Future<ScanSubmitResult> submitSimule({
    required String checkpointId,
    required String idempotencyKey,
  }) async {
    gonderilen.add(checkpointId);
    return ScanSubmitResult(
      event: ScanEvent(
        id: 's-1',
        guardId: 'g-1',
        checkpointId: checkpointId,
        nfcTagUid: 'DEMO-NFC-0001',
        okutmaZamani: DateTime.utc(2026, 8, 2, 10),
        // SIMULE okutma GERCEK okutmadan ayirt edilebilir kalir.
        imzaDogrulandi: false,
      ),
      wasDuplicate: false,
    );
  }
}

Widget _ekran({required bool demo, ScanApi? scan}) => ProviderScope(
      overrides: [
        checkpointApiProvider.overrideWithValue(_SahteCheckpointApi()),
        tenantApiProvider.overrideWithValue(_SahteTenantApi(demo)),
        if (scan != null) scanApiProvider.overrideWithValue(scan),
      ],
      child: l10nApp(const CheckpointsScreen(), locale: const Locale('tr')),
    );

Future<void> _menuAc(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<String>).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('DEMO KAPALIYKEN simule okutma GORUNMEZ', (tester) async {
    // Asil olcum bu: gercek bir tesiste bu dugmenin bulunmasi, tur
    // kaydinin kanit degerini sifirlardi.
    await tester.pumpWidget(_ekran(demo: false));
    await tester.pumpAndSettle();
    await _menuAc(tester);
    expect(find.text('Simüle okutma'), findsNothing);
    expect(find.text('Düzenle'), findsOneWidget); // menu gercekten acildi
  });

  testWidgets('DEMO ACIKKEN gorunur ve SUNUCUYA gider', (tester) async {
    final scan = _SahteScanApi();
    await tester.pumpWidget(_ekran(demo: true, scan: scan));
    await tester.pumpAndSettle();
    await _menuAc(tester);
    expect(find.text('Simüle okutma'), findsOneWidget);

    await tester.tap(find.text('Simüle okutma'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(scan.gonderilen, ['cp-1']);
    expect(find.textContaining('Ana Kapı'), findsWidgets);
  });

  test('AYAR YUKLENMEDIYSE bayrak KAPALI sayilir', () {
    // Eski/bilinmeyen bir sunucuda alan hic gelmeyebilir. Varsayilanin
    // ACIK olmasi, olmayan bir uca dokunduran OLU bir dugme cizerdi.
    final ayar = TenantSettings.fromJson({'tenant_id': 't-1', 'ad': 'X'});
    expect(ayar.demoMod, isFalse);
  });
}
