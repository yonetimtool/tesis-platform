/// (P251 §8) KISILER — TEK GIRIS, ROLE GORE SEKMELER (web `/kisiler` ikizi).
///
/// Olculen:
///   * yonetici/admin: Sakinler · Personel · Yoneticiler ve denetciler ·
///     Davetler sekmeleri,
///   * guvenlik amiri: YALNIZ Personel (sekme seridi bile cizilmez),
///   * sakin ve saha: hic (menude Kisiler yok),
///   * adresten gelen sekme (`/kisiler?sekme=davetler`) dogru sekmeyi acar
///     — eski `/davetler` derin baglantisi buraya yonlenir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/davetler/data/davet_yonetim_api.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/kisiler/domain/kisiler_sekmeleri.dart';
import 'package:mobile/src/features/kisiler/presentation/kisiler_screen.dart';
import 'package:mobile/src/features/residents/data/residents_api.dart';
import 'package:mobile/src/features/staff/data/staff_api.dart';

import 'helpers/l10n_test_app.dart';

Widget _kisiler(UserRole rol, {KisilerSekmesi? ilk}) => ProviderScope(
      overrides: [
        currentUserRoleProvider.overrideWith((ref) async => rol),
        fieldStaffProvider.overrideWith((ref) async => const <StaffMember>[]),
        yonetimListesiProvider.overrideWith((ref) async => const <StaffMember>[]),
        residentsProvider.overrideWith((ref) async => const []),
        davetListesiProvider.overrideWith((ref) async => const DavetListesi(items: [])),
      ],
      child: l10nApp(KisilerScreen(ilkSekme: ilk)),
    );

void main() {
  test('sekmeler role gore', () {
    expect(kisilerSekmeleri(UserRole.yonetici), KisilerSekmesi.values);
    expect(kisilerSekmeleri(UserRole.admin), KisilerSekmesi.values);
    expect(kisilerSekmeleri(UserRole.guvenlikAmiri), [KisilerSekmesi.personel]);
    for (final r in [UserRole.resident, UserRole.security, UserRole.tesisGorevlisi, UserRole.denetci]) {
      expect(kisilerSekmeleri(r), isEmpty, reason: '$r');
    }
  });

  test('Kisiler menude: yonetici + amir; sakin modunda/sakinde YOK', () {
    expect(homeMenuForRole(UserRole.yonetici), contains(HomeMenuEntry.kisiler));
    expect(homeMenuForRole(UserRole.guvenlikAmiri), contains(HomeMenuEntry.kisiler));
    expect(homeMenuForRole(UserRole.resident), isNot(contains(HomeMenuEntry.kisiler)));
    expect(homeMenuForRole(UserRole.security), isNot(contains(HomeMenuEntry.kisiler)));
  });

  test('adresten sekme cozumu', () {
    expect(kisilerSekmesiCoz('davetler'), KisilerSekmesi.davetler);
    expect(kisilerSekmesiCoz('olmayan'), isNull);
    expect(kisilerSekmesiCoz(null), isNull);
  });

  testWidgets('YONETICI: dort sekme; adresteki sekme acilir', (tester) async {
    await tester.pumpWidget(_kisiler(UserRole.yonetici, ilk: KisilerSekmesi.davetler));
    await tester.pumpAndSettle();
    for (final s in KisilerSekmesi.values) {
      expect(find.byKey(Key('kisiler-sekme-${s.name}')), findsOneWidget, reason: s.name);
    }
    final kontrol = DefaultTabController.of(
        tester.element(find.byKey(const Key('kisiler-sekme-davetler'))));
    expect(kontrol.index, KisilerSekmesi.values.indexOf(KisilerSekmesi.davetler));
    expect(tester.takeException(), isNull);
  });

  testWidgets('GUVENLIK AMIRI: tek sekme (Personel), sekme seridi YOK', (tester) async {
    await tester.pumpWidget(_kisiler(UserRole.guvenlikAmiri));
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsNothing);
    expect(find.byKey(const Key('kisiler-sekme-sakinler')), findsNothing);
    // Personel govdesi (bos durum) cizildi.
    expect(find.textContaining('Henüz saha personeli yok'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
