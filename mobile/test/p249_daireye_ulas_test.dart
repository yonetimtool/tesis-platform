/// (P249 §3) GUVENLIKTEN DAIREYE ULASMA — mobil.
///
/// Olculen: guvenlik daireyi secer, onay ister (ONAY dairenin sakinlerine
/// `onay_iste: true` ile gider), basili tutup birakinca ses GONDERILIR,
/// telefon YALNIZ izinli sakin icin gorunur ve numara ekranda yazilmaz;
/// sakin bekleyen talebe Onayla/Reddet der.
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/call/data/call_launcher.dart';
import 'package:mobile/src/features/daireye_ulas/data/daireye_ulas_api.dart';
import 'package:mobile/src/features/daireye_ulas/data/ses_kaydedici.dart';
import 'package:mobile/src/features/daireye_ulas/presentation/daireye_ulas_ekrani.dart';
import 'package:mobile/src/features/visitors/data/visitor_api.dart';
import 'package:mobile/src/features/visitors/domain/visitor_models.dart';
import 'package:mobile/src/features/visitors/presentation/visitors_screen.dart';

import 'helpers/l10n_test_app.dart';

Visitor _v({String durum = 'bekliyor'}) => Visitor.fromJson({
      'id': 'v1', 'unit_id': 'u1', 'unit_no': 'A-1', 'ziyaretci_ad': 'Kurye Ali',
      'kaydeden_user_id': 'g', 'target_resident_user_id': 's1',
      'created_at': '2026-09-29T10:00:00Z', 'onay_durum': durum,
    });

class _SahteVisitorApi extends VisitorApi {
  _SahteVisitorApi() : super(Dio());
  final taslaklar = <VisitorDraft>[];
  final onaylar = <bool>[];

  @override
  Future<List<DaireArama>> daireAra(String q) async => [
        DaireArama.fromJson(const {
          'id': 'u1', 'no': 'A-1', 'blok': 'A',
          'sakinler': [{'user_id': 's1', 'ad': 'Ayşe'}, {'user_id': 's2', 'ad': 'Can'}],
        }),
      ];

  @override
  Future<Visitor> create(VisitorDraft draft) async {
    taslaklar.add(draft);
    return _v();
  }

  @override
  Future<Visitor> getir(String id) async => _v();

  @override
  Future<Visitor> onay(String id, {required bool onayla}) async {
    onaylar.add(onayla);
    return _v(durum: onayla ? 'onaylandi' : 'reddedildi');
  }
}

class _SahteUlasApi extends DaireyeUlasApi {
  _SahteUlasApi() : super(Dio());
  final sesler = <int>[];
  final telefonlar = <String>[];

  @override
  Future<DaireUlas> daire(String unitId) async => DaireUlas.fromJson(const {
        'unit_id': 'u1', 'daire': 'A-1',
        'sakinler': [
          {'user_id': 's1', 'ad': 'Ayşe', 'telefonla_aranabilir': true},
          {'user_id': 's2', 'ad': 'Can', 'telefonla_aranabilir': false},
        ],
      });

  @override
  Future<String> telefon(String unitId, String userId) async {
    telefonlar.add(userId);
    return '+905551234567';
  }

  @override
  Future<void> sesGonder(String unitId, Uint8List ses, int sureMs) async {
    sesler.add(sureMs);
  }
}

class _SahteKaydedici implements SesKaydedici {
  @override
  Future<bool> izinVarMi() async => true;
  @override
  Future<void> basla() async {}
  @override
  Future<Uint8List?> bitir() async => Uint8List.fromList(List.filled(100, 1));
  @override
  Future<void> iptal() async {}
}

class _SahteArayici implements CallLauncher {
  final aranan = <String>[];
  @override
  Future<bool> dial(String telUri) async {
    aranan.add(telUri);
    return true;
  }
}

void main() {
  testWidgets('GUVENLIK: daire sec -> onay iste -> ses gonder -> izinli sakini ara',
      (tester) async {
    final vApi = _SahteVisitorApi();
    final uApi = _SahteUlasApi();
    final arayici = _SahteArayici();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        visitorApiProvider.overrideWithValue(vApi),
        daireyeUlasApiProvider.overrideWithValue(uApi),
        sesKaydediciProvider.overrideWithValue(_SahteKaydedici()),
        callLauncherProvider.overrideWithValue(arayici),
        currentUserRoleProvider.overrideWith((ref) async => UserRole.security),
      ],
      child: l10nApp(const DaireyeUlasEkrani()),
    ));
    await tester.enterText(find.byKey(const Key('ulas-daire-ara')), 'A-1');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ulas-sonuc-u1')));
    await tester.pumpAndSettle();

    // 1. ONAY
    await tester.enterText(find.byKey(const Key('ulas-ziyaretci-ad')), 'Kurye Ali');
    await tester.tap(find.byKey(const Key('ulas-onay-iste')));
    await tester.pump();
    expect(vApi.taslaklar.single.onayIste, isTrue);
    expect(vApi.taslaklar.single.toJson()['onay_iste'], isTrue);

    // 2. SES — basili tut, birak.
    final ses = find.byKey(const Key('ulas-ses-kaydet'));
    await tester.ensureVisible(ses);
    final g = await tester.startGesture(tester.getCenter(ses));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));
    await g.up();
    await tester.pump();
    await tester.pump();
    expect(uApi.sesler, hasLength(1));

    // 3. TELEFON — yalniz izinli sakin; numara YAZILMAZ.
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ulas-telefon-s1')), findsOneWidget);
    expect(find.byKey(const Key('ulas-telefon-s2')), findsNothing);
    expect(find.textContaining('5551234567'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('ulas-telefon-s1')));
    await tester.tap(find.byKey(const Key('ulas-telefon-s1')));
    await tester.pumpAndSettle();
    expect(uApi.telefonlar, ['s1']);
    expect(arayici.aranan.single, contains('5551234567'));
    // Onay yoklama zamanlayicisini durdur (ekran kapanir).
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('SAKIN bekleyen talebe ONAYLA der', (tester) async {
    final vApi = _SahteVisitorApi();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        visitorApiProvider.overrideWithValue(vApi),
        currentUserRoleProvider.overrideWith((ref) async => UserRole.resident),
      ],
      child: l10nApp(Scaffold(body: ZiyaretciOnaySatiri(visitor: _v()))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ziyaret-onayla-v1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ziyaret-onayla-v1')));
    await tester.pump();
    expect(vApi.onaylar, [true]);
  });

  testWidgets('GUVENLIK onay dugmesi GORMEZ, durumu gorur', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        visitorApiProvider.overrideWithValue(_SahteVisitorApi()),
        currentUserRoleProvider.overrideWith((ref) async => UserRole.security),
      ],
      child: l10nApp(Scaffold(body: ZiyaretciOnaySatiri(visitor: _v(durum: 'reddedildi')))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ziyaret-onayla-v1')), findsNothing);
    expect(find.byKey(const Key('ziyaret-onay-durum-v1')), findsOneWidget);
  });
}
