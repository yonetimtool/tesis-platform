/// (P249 §2) TATBIKAT — mobil yuzey.
///
/// Olculen: tatbikat alarmi tam ekranda "TATBIKAT" seridiyle cizilir;
/// yonetim planla dugmesini gorur, guvenlik gormez; zaman bos
/// birakilinca istek HEMEN baslatir (planlanan_at yok).
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/announcements/data/announcement_api.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/panik/data/alarm_kanali.dart';
import 'package:mobile/src/features/panik/data/panik_api.dart';
import 'package:mobile/src/features/panik/data/tatbikat_api.dart';
import 'package:mobile/src/features/panik/domain/panik_models.dart';
import 'package:mobile/src/features/panik/presentation/panik_gozcusu.dart';
import 'package:mobile/src/features/panik/presentation/tatbikat_ekrani.dart';

import 'helpers/l10n_test_app.dart';

class _SahteTatbikatApi extends TatbikatApi {
  _SahteTatbikatApi() : super(Dio());

  final planlar = <Map<String, Object?>>[];

  @override
  Future<List<Tatbikat>> liste() async => const [];

  @override
  Future<Tatbikat> planla({
    required String kategori,
    required String kapsam,
    String? blok,
    DateTime? planlananAt,
    bool duyuru = false,
    String? aciklama,
  }) async {
    planlar.add({
      'kategori': kategori,
      'kapsam': kapsam,
      'planlanan_at': planlananAt,
      'duyuru': duyuru,
    });
    return const Tatbikat(
      id: 't1', kategori: 'deprem', kapsam: 'site', durum: 'aktif', baslik: 'Deprem tatbikatı',
    );
  }
}

class _SahtePanikApi extends PanikApi {
  _SahtePanikApi(this.aktif) : super(Dio());
  final List<PanikAlarm> aktif;
  @override
  Future<List<PanikAlarm>> aktifler() async => aktif;
}

Widget _ekran(_SahteTatbikatApi api, UserRole rol) => ProviderScope(
      overrides: [
        tatbikatApiProvider.overrideWithValue(api),
        currentUserRoleProvider.overrideWith((ref) async => rol),
        duyuruBlokAdlariProvider.overrideWith((ref) async => const ['A']),
      ],
      child: l10nApp(const TatbikatEkrani()),
    );

void main() {
  testWidgets('TATBIKAT ALARMI seritle cizilir', (tester) async {
    final a = PanikAlarm.fromJson(const {
      'id': 'a1', 'tip': 'yonetici_anons', 'durum': 'acik', 'kategori': 'deprem',
      'toplu': true, 'tatbikat': true, 'baslik': 'TATBİKAT — DEPREM ALARMI',
      'talimat': ['ÇÖK, KAPAN, TUTUN.'],
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        panikApiProvider.overrideWithValue(_SahtePanikApi([a])),
        alarmKanaliProvider.overrideWithValue(AlarmKanali(const MethodChannel('t/a'))),
        currentUserIdProvider.overrideWith((ref) async => 'ben'),
      ],
      child: l10nApp(PanikGozcusu(child: const Scaffold(body: Text('alt')))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('panik-tatbikat-serit')), findsOneWidget);
    expect(find.text('TATBİKAT — DEPREM ALARMI'), findsOneWidget);
    expect(find.byKey(const Key('panik-guvendeyim')), findsOneWidget);
  });

  testWidgets('GUVENLIK planla dugmesini GORMEZ', (tester) async {
    await tester.pumpWidget(_ekran(_SahteTatbikatApi(), UserRole.security));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tatbikat-planla')), findsNothing);
  });

  testWidgets('YONETICI zaman bos -> HEMEN baslatir', (tester) async {
    final api = _SahteTatbikatApi();
    await tester.pumpWidget(_ekran(api, UserRole.yonetici));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tatbikat-planla')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('tatbikat-kaydet')));
    await tester.tap(find.byKey(const Key('tatbikat-kaydet')));
    await tester.pumpAndSettle();
    expect(api.planlar, hasLength(1));
    expect(api.planlar.single['planlanan_at'], isNull);
    expect(api.planlar.single['duyuru'], isFalse);
    expect(api.planlar.single['kategori'], 'deprem');
  });
}
