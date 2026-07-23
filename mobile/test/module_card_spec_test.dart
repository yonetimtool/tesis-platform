import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/home/presentation/module_card_spec.dart';
import 'package:mobile/src/routing/app_router.dart';

void main() {
  group('moduleCardSpec — menu girisi -> kart sunumu (ikon/baslik/renk/rota)',
      () {
    test('TUM girisler icin spec vardir: baslik dolu + rota "/" ile baslar '
        '(eksik case Dart derleyicisinde yakalanir)', () {
      for (final entry in HomeMenuEntry.values) {
        final spec = moduleCardSpec(entry);
        expect(spec.title.trim(), isNotEmpty, reason: entry.name);
        expect(spec.route, startsWith('/'), reason: entry.name);
      }
    });

    test('somut esleme: Aidatım -> /my-dues, Kargo -> /kargo', () {
      expect(moduleCardSpec(HomeMenuEntry.myDues).title, 'Aidatım');
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
