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
  'dukkanWhatsapp',
  // P8: gercek KOGNAT'lar — ceviri unutulmasi degil.
  //   Kamera: tr == de ("Kamera"), fr "Caméra", ru "Камера" AYRI.
  //   Manuel: tr == fr ("Manuel"), de "Manuell", es "Manual" AYRI.
  'ihlalKaynakKamera', 'ihlalKaynakManuel',
  // (DUKKAN F3) "WhatsApp" bir MARKA ADIDIR ve latin alfabesi kullanan
  // dillerde AYNI yazilir; cevirmek markayi tanınmaz kilardi. Arapca
  // karsiligi ZATEN farkli ("واتساب") — yani ceviri unutulmasi degil,
  // gercek bir kognat.
  // (P167 ek) "KB" bir BIRIM KISALTMASIDIR (kilobayt) ve tr/en/ar/ru/de/es
  // hepsinde ayni yazilir; yalniz Fransizca "Ko" kullanir ve o ZATEN
  // farkli. Cevirmek, dosya boyutunu tanimadigi bir birimle gostermek
  // olurdu.
  'dokumanBoyutKb',
  // (P233 §3) `5XX XXX XX XX` bir KALIPTIR, cumle degil: rakam duzenini
  // gosterir ve her dilde ayni okunur. Cevirmek, ornegin Rusca bir "5XX"
  // uydurmak demek olurdu. Panel ikizi `admin-web/tests/i18n.test.ts`te
  // ayni istisna var.
  'telefonUlusalYerTutucu',
  // (P240 §1) "SOS" ULUSLARARASI BIR ISARETTIR, cumle degil.
  //
  // Dugme ust barda duruyor ve genisligi DILDEN BAGIMSIZ olmali:
  // ilk yazimda "ACİL"/"طوارئ" kullanildi ve Arapca ana ekran ust bari
  // 4 px TASTI (`home_i18n` kilidi yakaladi). "SOS" yedi dilde de uc
  // karakter ve herkesce taninir; cevirmek tasmayi geri getirirdi.
  'panikKisa',
  // (P240 §2) "Port" bir AG TERIMIDIR ve Almanca/Fransizca/Ispanyolca'da
  // da AYNI yazilir (de. "Port", fr. "Port", es. "Puerto" — o farkli).
  // Ceviri unutmasi degil KOGNAT; panel ikizinde de ayni istisna var.
  'diyafonPort',
  // (P230 §3) ARAMA KAYNAK ADLARI — gercek KOGNATLAR, ceviri unutmasi
  // DEGIL. Rusca ve Arapca karsiliklari ZATEN farkli:
  //   Plan   : tr/en/de/fr/es ayni; ru "План",    ar "خطة"
  //   Firma  : tr/de ayni;       ru "Компания", ar "شركة"
  //   Kamera : tr/de ayni;       ru "Камера",   ar "كاميرا"
  // Almanca'yi "Unternehmen"e cevirmek dogru olmazdi: "Firma" Almanca'da
  // da kullanilan bir sozcuk ve kisa etiket icin dogal olan o.
  'aramaKaynakPlan', 'aramaKaynakFirma', 'aramaKaynakKamera',
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
