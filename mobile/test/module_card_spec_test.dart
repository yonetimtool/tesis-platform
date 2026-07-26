import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/gen/app_localizations.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/home/presentation/module_card_spec.dart';
import 'package:mobile/src/routing/app_router.dart';

late AppLocalizations trL10n;

void main() {
  setUpAll(() async {
    trL10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  group('moduleCardSpec — menu girisi -> kart sunumu (ikon/renk/rota) + '
      'BASLIK dile gore', () {
    test('TUM girisler icin spec + BASLIK vardir; rota "/" ile baslar '
        '(eksik case Dart derleyicisinde yakalanir)', () {
      for (final entry in HomeMenuEntry.values) {
        final spec = moduleCardSpec(entry);
        // Baslik artik SPEC'te degil: kimlikten (enum) dile gore cozulur.
        expect(moduleBaslik(trL10n, entry).trim(), isNotEmpty,
            reason: entry.name);
        expect(spec.route, startsWith('/'), reason: entry.name);
      }
    });

    test('somut esleme: Aidatım -> /my-dues, Kargo -> /kargo', () {
      expect(moduleBaslik(trL10n, HomeMenuEntry.myDues), 'Aidatım');
      expect(moduleCardSpec(HomeMenuEntry.myDues).route, AppRoutes.myDues);
      expect(moduleCardSpec(HomeMenuEntry.kargo).route, AppRoutes.kargo);
    });

    test('gorev-YONETIMI rotasi "yonetim" gorunumu query\'sini tasir', () {
      expect(
        moduleCardSpec(HomeMenuEntry.taskTracking).route,
        '${AppRoutes.tasks}?gorunum=yonetim',
      );
    });
  });
}
