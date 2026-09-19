/// (P243 §6d) ILK GIRIS TURU — MOBIL.
///
/// =========================================================================
/// OLCULEN SEY
/// =========================================================================
/// Brief: "Yöneticiye 3-4 ekranlık kısa tanıtım. Atlanabilir, bir kez
/// gösterilir, sonradan tekrar açılabilir."
///
/// "BIR KEZ" nerede tutuldugu bu turun asil karari. `KurulumHatirlatici`
/// kapatma karinini CIHAZDA tutar ve bu dogrudur — o bir "simdi degil"
/// tercihidir. TUR BASKA BIR SEY: bir kez ogrenilen bilgidir. Cihazda
/// tutulsaydi telefonda turu atlayan yonetici web panelinde onu YENIDEN
/// gorurdu. Bu dosya SUNUCUYA GIDILDIGINI olcer, pencerenin kapanmasini
/// degil.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/kurulum/presentation/ilk_giris_turu.dart';
import 'package:mobile/src/features/profile/data/profile_api.dart';
import 'package:mobile/src/features/profile/domain/profile.dart';

import 'helpers/l10n_test_app.dart';

class _SahteProfilApi extends ProfileApi {
  _SahteProfilApi() : super(Dio());

  int yazma = 0;

  @override
  Future<void> turGoruldu() async => yazma += 1;
}

Widget _ekran({
  required UserRole rol,
  required bool turGoruldu,
  required _SahteProfilApi api,
}) {
  final profil = Profile(
    ad: 'A',
    role: rol.name,
    aranabilir: false,
    turGoruldu: turGoruldu,
  );
  return ProviderScope(
    overrides: [
      currentUserRoleProvider.overrideWith((ref) async => rol),
      profileProvider.overrideWith((ref) async => profil),
      profileApiProvider.overrideWithValue(api),
    ],
    child: l10nApp(const IlkGirisTuru(child: Scaffold(body: Text('ana')))),
  );
}

void main() {
  testWidgets('YENI YONETICIYE acilir ve DORT EKRAN gezilir', (tester) async {
    final api = _SahteProfilApi();
    await tester.pumpWidget(
      _ekran(rol: UserRole.yonetici, turGoruldu: false, api: api),
    );
    await tester.pumpAndSettle();

    expect(find.text('Önce bloklar ve daireler'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    // Ilk ekranda "Geri" YOK: gidilecek bir yer yok.
    expect(find.text('Geri'), findsNothing);

    for (final beklenen in [
      'Kişiler davetle girer',
      'Aidat ve tahsilat, hazır olunca',
      'Kurulum sihirbazı yanınızda',
    ]) {
      await tester.tap(find.text('İleri'));
      await tester.pumpAndSettle();
      expect(find.text(beklenen), findsOneWidget, reason: beklenen);
    }
    // Son ekranda "İleri" degil "Başlayalım".
    expect(find.text('İleri'), findsNothing);
    expect(find.text('Başlayalım'), findsOneWidget);

    await tester.tap(find.text('Başlayalım'));
    await tester.pumpAndSettle();
    expect(api.yazma, 1);
  });

  testWidgets('ATLAMAK da "gordu"dur — SUNUCUYA yazilir', (tester) async {
    // Aksi hâlde "atla" dugmesi bir sonraki girisde HICBIR SEY yapmamis
    // olurdu: kullanici her acilista ayni pencereyle karsilasirdi.
    final api = _SahteProfilApi();
    await tester.pumpWidget(
      _ekran(rol: UserRole.yonetici, turGoruldu: false, api: api),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turu atla'));
    await tester.pumpAndSettle();
    expect(api.yazma, 1);
    expect(find.text('Önce bloklar ve daireler'), findsNothing);
  });

  testWidgets('TURU GOREN kullaniciya BIR DAHA acilmaz', (tester) async {
    final api = _SahteProfilApi();
    await tester.pumpWidget(
      _ekran(rol: UserRole.yonetici, turGoruldu: true, api: api),
    );
    await tester.pumpAndSettle();
    expect(find.text('Önce bloklar ve daireler'), findsNothing);
    expect(api.yazma, 0);
  });

  testWidgets('SAKINE acilmaz (tur kurulumu anlatiyor)', (tester) async {
    final api = _SahteProfilApi();
    await tester.pumpWidget(
      _ekran(rol: UserRole.resident, turGoruldu: false, api: api),
    );
    await tester.pumpAndSettle();
    expect(find.text('Önce bloklar ve daireler'), findsNothing);
  });

  test('turGoruldu SUNUCUDAN cozulur, cihazdan degil', () {
    // Alan `tur_goruldu_at` damgasindan turer: cihaz deposunda bir bayrak
    // olsaydi web ile mobil ayni kullanici icin farkli cevap verirdi.
    expect(
      Profile.fromJson({
        'ad': 'A',
        'role': 'yonetici',
        'tur_goruldu_at': '2026-09-01T10:00:00Z',
      }).turGoruldu,
      isTrue,
    );
    expect(
      Profile.fromJson({
        'ad': 'A',
        'role': 'yonetici',
        'tur_goruldu_at': null,
      }).turGoruldu,
      isFalse,
    );
  });
}
