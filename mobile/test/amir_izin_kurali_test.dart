// (P143) `auth.md` §4a — AMIRIN ERISIMI, IKI YONDE.
//
// Kural (baglayici, contracts/auth.md §4a):
//   ACIK : tur/vardiya/kontrol noktasi, tarama raporu, kamera, pano,
//          bildirimler, ARAC GECISI VE IHLAL OKUMA, POST /scans
//   KAPALI: sakin listesi, aidat/finans, kargo, ziyaretci, rezervasyon,
//          tesis ayarlari.  Gerekce KVKK: "dis bir sirketin personeline
//          sakin kisisel verisi acmak savunulamaz."
//
// KOD IKI YONDE DE AYRISMISTI:
//   (a) menu, ACIK denilen uc ekrani vermiyordu (vardiya, ihlal, arac
//       gecisi) — amir bunlari izgarasina koyamiyordu;
//   (b) ana ekranin KART listesi, KAPALI denilen kargo ve ziyaretciyi
//       gosteriyordu — cunku amir kart duzenini `security` ile paylasiyor.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/data/home_repository.dart';
import 'package:mobile/src/features/home/domain/home_izgara.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/home/domain/home_varyant.dart';
import 'package:mobile/src/features/home/presentation/izgara_koprusu.dart';
import 'package:mobile/src/features/home/presentation/module_card_spec.dart';

void main() {
  final amirMenu = izgaraSecenekleri(UserRole.guvenlikAmiri).toSet();

  group('(P143) ACIK olanlar menude VAR', () {
    for (final g in [
      HomeMenuEntry.vardiyalar,
      HomeMenuEntry.ihlaller,
      HomeMenuEntry.aracGecis,
      HomeMenuEntry.patrol,
    ]) {
      test(g.name, () => expect(amirMenu, contains(g)));
    }
  });

  group('(P143) KAPALI olanlar menude YOK', () {
    for (final g in [
      HomeMenuEntry.kargo,
      HomeMenuEntry.visitors,
      HomeMenuEntry.rezervasyon,
      HomeMenuEntry.myDues,
      HomeMenuEntry.financialSummary,
      HomeMenuEntry.sakinler,
    ]) {
      test(g.name, () => expect(amirMenu, isNot(contains(g))));
    }
  });

  test('(P143) ANA EKRAN KARTLARI da kurala uyar — KVKK sizintisi YOK', () {
    // Kart duzeni `security` ile PAYLASILIYOR; suzgec olmasaydi kargo ve
    // ziyaretci amirin ana ekraninda gorunurdu.
    final taban = MockHomeRepository();
    final kartlar = rolunKartlari(
        taban.hizliErisim(HomeVaryant.gorevli), UserRole.guvenlikAmiri);
    final rotalar = kartlar.map((k) => k.rota).toSet();
    expect(rotalar, isNot(contains(moduleCardSpec(HomeMenuEntry.kargo).route)));
    expect(rotalar, isNot(contains(moduleCardSpec(HomeMenuEntry.visitors).route)));
    // Ve kart listesi BOSALMADI (suzgec her seyi silmesin).
    expect(kartlar, isNotEmpty);
  });

  test('(P143) GUVENLIK etkilenmedi — kargo/ziyaretci ONDA DURUYOR', () {
    // Suzgec role gore calisir; ortak duzeni paylasan `security` kaybetmez.
    final taban = MockHomeRepository();
    final kartlar = rolunKartlari(
        taban.hizliErisim(HomeVaryant.gorevli), UserRole.security);
    final rotalar = kartlar.map((k) => k.rota).toSet();
    expect(rotalar, contains(moduleCardSpec(HomeMenuEntry.kargo).route));
    expect(rotalar, contains(moduleCardSpec(HomeMenuEntry.visitors).route));
  });

  test('(P143) MENUDE TEMSIL EDILMEYEN kart DOKUNULMADAN kalir', () {
    // Suzgec muhafazakar: izin bilgisi olmayan karti sessizce silmez.
    final taban = MockHomeRepository();
    final ham = taban.hizliErisim(HomeVaryant.yonetici);
    final suzulmus = rolunKartlari(ham, UserRole.yonetici);
    expect(suzulmus.length, ham.length,
        reason: 'yoneticinin kartlari elenmemeli');
  });
}
