// TUR 23 — mobil sozlugu 7 dilde "gozle sur".
//
// Panel tarafinda (tur 21) paneli gercekten calistirip URETILEN HTML'i
// incelemek, statik taramanin goremedigi UC Turkce paragrafi ortaya
// cikarmisti. Mobilde karsiligi budur: ARB dosyalarini degil, gen-l10n'un
// URETTIGI `AppLocalizations` nesnesini 7 dilde yukleyip ciktiya bakariz.
//
// Neden ARB'ye bakmak yetmez: gen-l10n araya girer (ICU cogul secimi,
// placeholder sirasi, kacis dizileri). Bir anahtar ARB'de dogru gorunup
// uretilen sinifta bos/bozuk cikabilir.
//
// Kilitlenen dort sey:
//   1. HICBIR dilde anahtar eksik degil (ARB kume karsilastirmasi),
//   2. Turkce'ye OZGU harf baska dile sizmamis,
//   3. "TR kopyasi" supheleri BILINEN listeyle sinirli (circir),
//   4. uretilen sinif her dilde CALISIYOR ve bos metin dondurmuyor.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';

const _diller = ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es'];

/// YALNIZ Turkcede bulunan harfler. `ç/ö/ü` KASITLI olarak disarida:
/// Almanca/Fransizca metinlerde de gecerler (bkz. ag_hatasi_i18n_test.dart).
final _trHarf = RegExp('[ğışĞİŞ]');

/// Yer tutucular cikarilinca geriye HARF kalmayan sablonlar (orn. "UID: {uid}",
/// "{dolu} / {kapasite}"): 7 dilde AYNI olmalari DOGRUDUR. Ayrica dillerde
/// gercekten ortusen sozcukler ("Online", "Test", "Profil"...).
///
/// Bu liste bir CIRCIR: yeni bir anahtar yanlislikla Turkce kopyalanirsa
/// listede olmadigi icin test kirilir. Buyutmek BILINCLI bir karardir.
const _tumKopyaIstisnalari = {
  'anaOnline', 'ayarlarTema', 'demAldiBirakti', 'devriyeUidEtiket',
  'entegTest', 'entegTestBasarisiz', 'entegUrl', 'gorevKamera',
  'kabukProfil', 'nfcUidSatir', 'otoparkDoluKapasite', 'profilTelefon',
  'rezSlotAralik', 'seffafNet', 'vardiyaSaatAraligi',
};

Map<String, dynamic> _arb(String dil) => jsonDecode(
      File('lib/l10n/app_$dil.arb').readAsStringSync(),
    ) as Map<String, dynamic>;

/// Sablondan yer tutucular cikinca geriye anlamli metin kaliyor mu?
bool _cevrilecekSozcukVar(String s) =>
    s.replaceAll(RegExp(r'\{\w+\}'), '').replaceAll(RegExp(r'[\s.:—\-·()/•→–]'), '')
        .isNotEmpty;

void main() {
  final sozlukler = {for (final d in _diller) d: _arb(d)};
  final trSozluk = sozlukler['tr']!;
  final anahtarlar = trSozluk.keys.where((k) => !k.startsWith('@')).toList();

  test('7 dilin ANAHTAR KUMESI ayni (eksik/fazla yok)', () {
    expect(anahtarlar, isNotEmpty);
    for (final dil in _diller) {
      final k = sozlukler[dil]!.keys.where((k) => !k.startsWith('@')).toSet();
      expect(k.difference(anahtarlar.toSet()), isEmpty, reason: '$dil fazla');
      expect(anahtarlar.toSet().difference(k), isEmpty, reason: '$dil eksik');
    }
  });

  test('Turkce harf baska dile SIZMAMIS', () {
    for (final dil in _diller) {
      if (dil == 'tr') continue;
      for (final a in anahtarlar) {
        final v = sozlukler[dil]![a] as String;
        expect(_trHarf.hasMatch(v), isFalse, reason: '$dil/$a: $v');
      }
    }
  });

  test('TR KOPYASI supheleri bilinen listeyle SINIRLI (circir)', () {
    final supheli = <String>{};
    for (final dil in _diller) {
      if (dil == 'tr') continue;
      for (final a in anahtarlar) {
        final tr = trSozluk[a] as String;
        if (sozlukler[dil]![a] == tr && _cevrilecekSozcukVar(tr)) {
          supheli.add(a);
        }
      }
    }
    // Yeni bir anahtar cevrilmeden birakilirsa burada gorunur.
    expect(supheli.difference(_tumKopyaIstisnalari), isEmpty);
  });

  test('URETILEN SINIF 7 dilde calisiyor ve bos metin dondurmuyor', () async {
    // ARB dogru gorunup gen-l10n ciktisi bozuk olabilir; asil sozlesme budur.
    for (final dil in _diller) {
      final l10n = await AppLocalizations.delegate.load(Locale(dil));
      // Parametresiz, farkli modullerden ornek anahtarlar.
      final ornekler = <String>[
        l10n.ortakKaydet,
        l10n.ortakBeklenmeyenHata,
        l10n.kabukProfil,
        l10n.hataSunucuyaUlasilamadi,
        l10n.akisKargoTeslimEdildi,
        l10n.seffafYuklenemedi,
      ];
      for (final m in ornekler) {
        expect(m.trim(), isNotEmpty, reason: dil);
      }
      // Parametreli: yer tutucu ARTIK metinde kalmamali.
      final param = l10n.gorevDaireEtiket('A-12');
      expect(param, contains('A-12'), reason: dil);
      expect(param, isNot(contains('{')), reason: dil);
    }
  });

  test('ICU cogul: ru/ar dallari FARKLI metin uretir', () async {
    // Cogul kurallari dile ozgudur (ru: one/few/many, ar: zero/two/few/many).
    // Tek bir dal yazilip digerleri kopyalanirsa sayilar yanlis okunur.
    for (final dil in ['ru', 'ar']) {
      final l10n = await AppLocalizations.delegate.load(Locale(dil));
      final metinler = {
        for (final n in [0, 1, 2, 5, 11, 100]) l10n.sayacDaire(n),
      };
      expect(metinler.length, greaterThan(2), reason: '$dil cogul dallari');
    }
  });
}
