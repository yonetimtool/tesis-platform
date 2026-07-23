import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/domain/home_featured.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';

void main() {
  group('featuredMenuForRole / moreMenuForRole — "one cikan grid + Tum '
      'Moduller" bolunmesi', () {
    test('SOZLESME: her rolde featured + more, homeMenuForRole\'un sirali '
        'bir bolunmesidir (kesisim yok, birlesim tam, sira korunur)', () {
      for (final role in UserRole.values) {
        final full = homeMenuForRole(role);
        final featured = featuredMenuForRole(role);
        final more = moreMenuForRole(role);

        // Kesisim bos.
        expect(featured.toSet().intersection(more.toSet()), isEmpty,
            reason: '${role.wire}: featured/more cakisiyor');
        // Birlesim tam (ne eksik ne fazla).
        expect({...featured, ...more}, full.toSet(),
            reason: '${role.wire}: birlesim homeMenu ile ayni degil');
        expect(featured.length + more.length, full.length,
            reason: '${role.wire}: toplam sayi tutmuyor (tekrar var?)');
        // Ikisi de orijinal sirayi korur (full icindeki gorece sira).
        expect(featured, full.where(featured.contains).toList(),
            reason: '${role.wire}: featured sirasi bozuk');
        expect(more, full.where(more.contains).toList(),
            reason: '${role.wire}: more sirasi bozuk');
      }
    });

    test('one cikan kart sayilari referanslara uyar: yonetici 8, resident 8, '
        'security 5', () {
      expect(featuredMenuForRole(UserRole.yonetici), hasLength(8));
      expect(featuredMenuForRole(UserRole.resident), hasLength(8));
      expect(featuredMenuForRole(UserRole.security), hasLength(5));
    });

    test('referans sadakati: resident one cikanlar ziyaretci/kargo/aidat '
        'icerir', () {
      final f = featuredMenuForRole(UserRole.resident);
      expect(f, containsAll(const [
        HomeMenuEntry.visitors,
        HomeMenuEntry.kargo,
        HomeMenuEntry.myDues,
      ]));
    });

    test('referans sadakati: security one cikanlar ziyaretci/kargo/turlarim '
        'icerir (vardiya+kapi operasyonu)', () {
      final f = featuredMenuForRole(UserRole.security);
      expect(f, containsAll(const [
        HomeMenuEntry.visitors,
        HomeMenuEntry.kargo,
        HomeMenuEntry.patrol,
      ]));
    });

    test('referans sadakati: yonetici one cikanlar gorev/finans/rapor icerir',
        () {
      final f = featuredMenuForRole(UserRole.yonetici);
      expect(f, containsAll(const [
        HomeMenuEntry.taskTracking,
        HomeMenuEntry.financialSummary,
        HomeMenuEntry.reports,
      ]));
    });

    test('unknown: featured ve more bos (homeMenu bos)', () {
      expect(featuredMenuForRole(UserRole.unknown), isEmpty);
      expect(moreMenuForRole(UserRole.unknown), isEmpty);
    });
  });
}
