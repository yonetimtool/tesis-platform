// (P142) KARO ADI, GITTIGI EKRANIN ADIYLA AYNI OLMALI.
//
// Kerem'in kurali: "kullanici bir karoya basinca adindan bekledigi yere
// gitmeli." Olculen sey tam bu — AYNI ROTAYA giden butun karolar AYNI adi
// tasimali. Farkli adlar, kullaniciya ayni ekrani farkli sey sanmasi
// icin dort ayri kapi acar.
//
// OLCUM (duzeltmeden once): `/complaints`e DORT adla giriliyordu
// ("Sikayet / Oneri", "Geri Bildirim", "Gurultu Sikayeti",
// "Talep / Arıza") ve `sikayetler` adli karo BINA SEMASINA gidiyordu.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/features/home/data/home_repository.dart';
import 'package:mobile/src/features/home/domain/home_kart_id.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/home/domain/home_varyant.dart';
import 'package:mobile/src/features/home/presentation/module_card_spec.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  test('AYNI ROTAYA giden karolar AYNI adi tasir', () {
    // Rota -> gorulen adlar kumesi (hem sayacli kart hem modul karosu).
    final adlar = <String, Set<String>>{};
    final taban = MockHomeRepository();
    for (final v in HomeVaryant.values) {
      for (final k in taban.hizliErisim(v)) {
        if (k.rota == null) continue;
        adlar.putIfAbsent(k.rota!, () => {}).add(kartBasligi(l10n, k.id));
      }
    }
    for (final e in HomeMenuEntry.values) {
      final spec = moduleCardSpec(e);
      adlar.putIfAbsent(spec.route, () => {}).add(moduleBaslik(l10n, e));
    }

    // (P142) BILINEN CAKISMALAR — KEREM'IN KARARINI BEKLIYOR.
    //
    // Kerem "karo adi ile gittigi ekranin adi ayni olacak" kuralini
    // onayladi ve ORNEK olarak sikayet ailesini vermisti. Bu kilit yazilinca
    // AYNI KUSURUN ON ROTADA DAHA oldugu cikti. Her biri icin dogru
    // kanonik adi SECMEK bir urun karari (or. `/reports` "Raporlar" mi
    // "Aylik Raporlar" mi) ve uydurulmadi.
    //
    // Liste BILEREK burada: yeni bir cakisma eklenirse test duser, ama
    // bilinenler tur tur kapatilir. Kapatildikca bu listeden SILINIR.
    // (P144) BEKLEYEN LISTE BOSALDI. On rotanin hepsi kanonik ada
    // baglandi ve kanonik ad EKRANIN KENDI BASLIGIDIR (Kerem'in karari) —
    // "kullanici bir karoya basinca adindan bekledigi yere gitmeli".
    // Liste bilerek DURUYOR: yeni bir cakisma cikarsa once burada
    // gerekcesiyle kaydedilir, sessizce gecistirilmez.
    const bekleyen = <String>{};

    final cakisan = <String>[];
    adlar.forEach((rota, kume) {
      if (kume.length > 1 && !bekleyen.contains(rota)) {
        cakisan.add('$rota -> ${kume.join(" | ")}');
      }
    });
    expect(cakisan, isEmpty,
        reason: 'ayni ekrana farkli adlarla giriliyor:\n${cakisan.join("\n")}');
  });

  test('SIKAYET AILESI birlestirildi (Kerem onayi)', () {
    // Onaylanan degisiklik: `/complaints`e giden HEPSI ekranin kendi adini
    // ("Talep / Arıza") kullanir; `sikayetler` karosu gittigi ekranin adi
    // olan "Sikayet Haritasi"na donusur.
    expect(kartBasligi(l10n, HomeKartId.geriBildirim), 'Talep / Arıza');
    expect(kartBasligi(l10n, HomeKartId.gurultuSikayeti), 'Talep / Arıza');
    expect(kartBasligi(l10n, HomeKartId.talepAriza), 'Talep / Arıza');
    expect(moduleBaslik(l10n, HomeMenuEntry.complaints), 'Talep / Arıza');
    expect(kartBasligi(l10n, HomeKartId.sikayetler), 'Şikayet Haritası');
  });

  test('TARAMA gercekten karo okuyor (vakum degil)', () {
    // P136 dersi: yokluk iddialari bos kume uzerinde her zaman dogrudur.
    final taban = MockHomeRepository();
    expect(taban.hizliErisim(HomeVaryant.yonetici), isNotEmpty);
    expect(HomeMenuEntry.values.length, greaterThan(20));
  });
}
