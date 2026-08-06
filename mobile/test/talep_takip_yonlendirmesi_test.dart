// (P146/P147) SAKININ TALEP/ARIZA YUZEYI: bildirme ve takip AYRI kapilar.
//
// P146'da bu dosya izgara karosunu olcuyordu ("karo `bildir` tasimasin").
// P147'de KARO KALKTI (Kerem: "geri bildirimi komple kaldir") ve yerini
// Bildirimler sayfasi aldi. Olcum SILINMEDI, ANLAMINI KORUYARAK tasindi:
//   * BILDIRME: "Bildir" menusunun talep girisi `?bildir=1` TASIR — form
//     acilmali; tasimazsa sakin talebi acamaz, sadece listeye bakar.
//   * TAKIP: sakinin izgarasinda `/complaints`e giden karo KALMADI; takip
//     Bildirimler satirindan yapiliyor (bkz. sakin_bildirim_yonlendirmesi).
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/features/home/data/home_repository.dart';
import 'package:mobile/src/features/home/domain/home_varyant.dart';
import 'package:mobile/src/features/home/presentation/resident_home_screen.dart';
import 'package:mobile/src/routing/app_router.dart';

void main() {
  final sakin = MockHomeRepository().hizliErisim(HomeVaryant.sakin);

  test('BILDIRME: "Bildir" girisi formu ACAR (`bildir=1` tasir)', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    final talep = sakinBildirGirisleri(l10n)
        .firstWhere((g) => g.route?.startsWith(AppRoutes.complaints) ?? false);
    expect(talep.route, contains('bildir=1'));
  });

  test('TAKIP: izgarada `/complaints`e giden karo KALMADI (P147)', () {
    expect(
      sakin.map((k) => k.rota).where((r) => r == AppRoutes.complaints),
      isEmpty,
      reason: 'takip artik Bildirimler sayfasindan yapiliyor',
    );
  });

  test('SILINDI: gurultu sikayeti karosu sakinin izgarasinda YOK', () {
    // (P145) `/complaints`e giden ikinci karoydu; ses sikayetinin takibi
    // Sikayet Haritasi'ndan yapiliyor.
    expect(
      sakin.map((k) => k.rota).contains('/gurultu'),
      isFalse,
    );
  });
}
