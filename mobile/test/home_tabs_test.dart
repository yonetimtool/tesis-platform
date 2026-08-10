import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/gen/app_localizations.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/domain/home_tabs.dart';

late AppLocalizations trL10n;

void main() {
  setUpAll(() async {
    // Testler TR'ye sabit (mevcut metin beklentileri korunur).
    trL10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  group('fabLabelForRole — merkez FAB etiketi (referans alt-bar)', () {
    test('resident: "Talep / Bildir" (site-sakini.jpeg)', () {
      expect(fabLabelForRole(trL10n, UserRole.resident), 'Talep / Bildir');
    });

    test('resident DISI tum roller: "Olay Bildir" (yonetici/gorevli.jpeg)', () {
      for (final role in [
        UserRole.admin,
        UserRole.yonetici,
        UserRole.security,
        UserRole.tesisGorevlisi,
      ]) {
        expect(fabLabelForRole(trL10n, role), 'Olay Bildir', reason: role.wire);
      }
    });
  });

  group('homeShellSlots — 5 yuvali alt-bar dizilimi (referans)', () {
    test('tam olarak 5 yuva; merkez (index 2) FAB, digerleri destinasyon', () {
      final slots = homeShellSlots(trL10n, UserRole.yonetici);
      expect(slots, hasLength(5));
      expect(slots[2].kind, HomeSlotKind.fab);
      for (final i in [0, 1, 3, 4]) {
        expect(slots[i].kind, HomeSlotKind.destination, reason: 'yuva $i');
      }
    });

    test('UC yuva rolden BAGIMSIZ: Ana Sayfa / Bildirimler / Ayarlar', () {
      for (final role in UserRole.values) {
        final labels = homeShellSlots(trL10n, role).map((s) => s.label).toList();
        expect(labels[0], 'Ana Sayfa', reason: role.wire);
        expect(labels[1], 'Bildirimler', reason: role.wire);
        expect(labels[2], fabLabelForRole(trL10n, role), reason: role.wire);
        expect(labels[4], 'Ayarlar', reason: role.wire);
      }
    });

    test('DORDUNCU yuva ROLE GORE: yonetici Raporlar · sakin Seffaflik · '
        'saha Gorevlerim', () {
      // (P154 / Asama 7.2) Bu test eskiden "etiketler rolden BAGIMSIZ"
      // diyordu ve dogruydu — brief o sozlesmeyi bilerek degistirdi.
      //
      // Eski hâlde sakin `/transparency`e gidiyor ama yuva "Raporlar"
      // diyordu (tiklanan sey ile gorulen sey ayni ad DEGILDI), saha
      // rolleri ise bir "yakinda" bildirimi aliyordu — bes yuvanin biri
      // onlar icin HICBIR ISE YARAMIYORDU.
      String dord(UserRole r) => homeShellSlots(trL10n, r)[3].label;
      expect(dord(UserRole.yonetici), 'Raporlar');
      expect(dord(UserRole.admin), 'Raporlar');
      expect(dord(UserRole.resident), 'Şeffaflık');
      expect(dord(UserRole.security), 'Görevlerim');
      expect(dord(UserRole.tesisGorevlisi), 'Görevlerim');
    });

    test('dorduncu yuvanin KIMLIGI de degisir (rota cozumu ona bakar)', () {
      // Etiket degisip kimlik ayni kalsaydi, rota cozumu uc ekranda ayri
      // `switch` yazmayi gerektirirdi ve biri unutuldugunda yuva yanlis
      // yere giderdi.
      expect(dorduncuYuva(UserRole.resident), HomeSlotId.seffaflik);
      expect(dorduncuYuva(UserRole.security), HomeSlotId.gorevlerim);
      expect(dorduncuYuva(UserRole.tesisGorevlisi), HomeSlotId.gorevlerim);
      expect(dorduncuYuva(UserRole.yonetici), HomeSlotId.raporlar);
    });

    test('merkez FAB etiketi role gore (homeBildirLabel ile ayni sozlesme)',
        () {
      expect(homeShellSlots(trL10n, UserRole.resident)[2].label, 'Talep / Bildir');
      expect(homeShellSlots(trL10n, UserRole.security)[2].label, 'Olay Bildir');
    });
  });
}
