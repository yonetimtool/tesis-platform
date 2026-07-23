import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/domain/home_tabs.dart';

void main() {
  group('homeBildirLabel — merkez FAB etiketi (referans alt-bar)', () {
    test('resident: "Talep / Bildir" (site-sakini.jpeg)', () {
      expect(homeBildirLabel(UserRole.resident), 'Talep / Bildir');
    });

    test('resident DISI tum roller: "Olay Bildir" (yonetici/gorevli.jpeg)', () {
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.security,
        UserRole.tesisGorevlisi,
      ]) {
        expect(homeBildirLabel(role), 'Olay Bildir', reason: role.wire);
      }
    });
  });

  group('homeShellSlots — 5 yuvali alt-bar dizilimi (referans)', () {
    test('tam olarak 5 yuva; merkez (index 2) FAB, digerleri destinasyon', () {
      final slots = homeShellSlots(UserRole.yonetici);
      expect(slots, hasLength(5));
      expect(slots[2].kind, HomeSlotKind.fab);
      for (final i in [0, 1, 3, 4]) {
        expect(slots[i].kind, HomeSlotKind.destination, reason: 'yuva $i');
      }
    });

    test('destinasyon etiketleri sabit sirada: Ana Sayfa/Bildirimler/'
        'Raporlar/Ayarlar (rolden bagimsiz)', () {
      for (final role in UserRole.values) {
        final labels = homeShellSlots(role).map((s) => s.label).toList();
        expect(
          labels,
          ['Ana Sayfa', 'Bildirimler', homeBildirLabel(role), 'Raporlar',
              'Ayarlar'],
          reason: role.wire,
        );
      }
    });

    test('merkez FAB etiketi role gore (homeBildirLabel ile ayni sozlesme)',
        () {
      expect(homeShellSlots(UserRole.resident)[2].label, 'Talep / Bildir');
      expect(homeShellSlots(UserRole.security)[2].label, 'Olay Bildir');
    });
  });
}
