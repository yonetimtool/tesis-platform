// TUR 15 — `/activity` satirlari KIMLIK tasir, metin istemcide uretilir.
//
// ONCESI: 13 SQL kaynagi `baslik`/`alt_metin` alanlarini TURKCE uretiyordu
// ("Kargo Teslim Edildi", "Daire A-12 — ₺1.250,00"). Istemci onlari aynen
// gosterdigi icin Arapca arayuzde de Turkce goruntuleniyordu ve §15 sayaci
// bunu GORMUYORDU (metin istemci kaynaginda degil, sunucudaydi).
//
// Kilitlenen sozlesme:
//   1. baslik = `baslik_kimlik`ten cozulur; `tur` TEK BASINA yetmez
//      (talep -> acildi / is emri / cozuldu / reddedildi),
//   2. alt metin `veri`den kurulur — VERI (daire no, firma, plaka) cevrilmez,
//      KIMLIK (sikayet kategorisi) cevrilir,
//   3. para ve saat ISTEMCIDE bicimlenir (sunucu "₺1.250,00" gondermez),
//   4. opsiyonel alanin YOKLUGU bicimi degistirir (SQL COALESCE'unun yerine),
//   5. bilinmeyen kimlik satiri DUSURMEZ — deprecated sunucu metnine duser.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/features/home/domain/activity_models.dart';
import 'package:mobile/src/features/home/presentation/akis_metinleri.dart';

const _diller = ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es'];

/// YALNIZ Turkcede bulunan harfler (`ç/ö/ü` disarida: Almanca/Fransizca da
/// kullanir — bkz. `ag_hatasi_i18n_test.dart`).
final _trHarf = RegExp('[ğışĞİŞ]');

ActivityItem _olay(
  ActivityTur tur,
  AkisBaslik kimlik, {
  Map<String, dynamic> veri = const {},
  String sunucuBaslik = '',
  String? sunucuAltMetin,
}) =>
    ActivityItem(
      id: 'x:1',
      tur: tur,
      baslikKimlik: kimlik,
      veri: veri,
      sunucuBaslik: sunucuBaslik,
      sunucuAltMetin: sunucuAltMetin,
      zaman: DateTime(2026, 7, 25, 9, 47),
      kaynakId: '1',
    );

Future<AppLocalizations> _l10n(String dil) =>
    AppLocalizations.delegate.load(Locale(dil));

void main() {
  test('TUM baslik kimlikleri 7 dilde karsilik bulur', () async {
    for (final dil in _diller) {
      final l10n = await _l10n(dil);
      for (final kimlik in AkisBaslik.values) {
        if (kimlik == AkisBaslik.bilinmeyen) continue;
        final metin = akisBaslikMetni(
          l10n,
          _olay(ActivityTur.kargo, kimlik),
        );
        expect(metin.trim(), isNotEmpty, reason: '$dil / $kimlik');
        if (dil != 'tr') {
          expect(_trHarf.hasMatch(metin), isFalse, reason: '$dil/$kimlik: $metin');
        }
      }
    }
  });

  test('ayni TUR, farkli DURUM -> farkli baslik (tur tek basina yetmez)',
      () async {
    final l10n = await _l10n('en');
    final basliklar = {
      for (final k in [
        AkisBaslik.talepAcik,
        AkisBaslik.talepIsEmri,
        AkisBaslik.talepCozuldu,
        AkisBaslik.talepReddedildi,
      ])
        akisBaslikMetni(l10n, _olay(ActivityTur.talep, k))
    };
    expect(basliklar, hasLength(4));
  });

  test('baslik dile gore DEGISIR, kimlik degismez', () async {
    final tr = await _l10n('tr');
    final ar = await _l10n('ar');
    final olay = _olay(ActivityTur.kargoTeslim, AkisBaslik.kargoTeslim);
    expect(akisBaslikMetni(tr, olay), 'Kargo Teslim Edildi');
    expect(akisBaslikMetni(ar, olay), isNot('Kargo Teslim Edildi'));
    expect(olay.baslikKimlik, AkisBaslik.kargoTeslim);
  });

  group('alt metin — VERI cevrilmez, KIMLIK cevrilir', () {
    test('kargo: firma + daire (veri) her dilde AYNEN gecer', () async {
      final olay = _olay(ActivityTur.kargo, AkisBaslik.kargo,
          veri: const {'firma': 'Mng Kargo', 'daire': 'A-12'});
      for (final dil in _diller) {
        final metin = akisAltMetni(await _l10n(dil), dil, olay)!;
        expect(metin, contains('Mng Kargo'), reason: dil);
        expect(metin, contains('A-12'), reason: dil);
      }
    });

    test('daire sikayeti: KATEGORI kimligi dile gore cevrilir', () async {
      final olay = _olay(ActivityTur.daireSikayeti, AkisBaslik.daireSikayeti,
          veri: const {'daire': 'B-3', 'kategori': 'gurultu'});
      final tr = akisAltMetni(await _l10n('tr'), 'tr', olay)!;
      final en = akisAltMetni(await _l10n('en'), 'en', olay)!;
      expect(tr, contains('Gürültü'));
      expect(en, isNot(contains('Gürültü')));
      // Daire no VERI: iki dilde de aynen durur.
      expect(tr, contains('B-3'));
      expect(en, contains('B-3'));
    });

    test('aidat: para ISTEMCIDE bicimlenir (kurus -> TL, Arapcada LTR izole)',
        () async {
      final olay = _olay(ActivityTur.aidatOdeme, AkisBaslik.aidatOdeme,
          veri: const {'daire': 'A-1', 'tutar_kurus': 125000});
      // TL + Turkce gruplama HER dilde (para politikasi §15).
      for (final dil in _diller) {
        expect(akisAltMetni(await _l10n(dil), dil, olay), contains('1.250,00'),
            reason: dil);
      }
      // Arapcada tutar LTR izolasyonuyla (U+2068) sarilir — ters gorunmesin.
      expect(akisAltMetni(await _l10n('ar'), 'ar', olay), contains('\u2068'));
      expect(akisAltMetni(await _l10n('tr'), 'tr', olay), isNot(contains('\u2068')));
    });

    test('alarm: pencere SAATI istemcide bicimlenir', () async {
      final olay = _olay(ActivityTur.alarm, AkisBaslik.alarmKacirilanTur,
          veri: const {
            'plan': 'Gece devriyesi',
            'baslangic': '2026-07-25T19:00:00Z',
            'bitis': '2026-07-25T20:00:00Z',
          });
      final metin = akisAltMetni(await _l10n('tr'), 'tr', olay)!;
      expect(metin, contains('Gece devriyesi'));
      expect(metin, contains('–')); // saat araligi kuruldu
      // Sunucunun eski Turkce cumlesi ("Kacirilan tur: pencere <iso>...") YOK.
      expect(metin, isNot(contains('pencere')));
    });

    test('OPSIYONEL alanin yoklugu bicimi degistirir (COALESCE yerine)',
        () async {
      final l10n = await _l10n('tr');
      String? alt(Map<String, dynamic> veri) => akisAltMetni(
          l10n, 'tr', _olay(ActivityTur.aracGiris, AkisBaslik.aracGiris, veri: veri));

      expect(alt(const {'plaka': '34ABC'}), '34ABC');
      expect(alt(const {'plaka': '34ABC', 'daire': 'A-1'}), '34ABC — Daire A-1');
      expect(alt(const {'plaka': '34ABC', 'tanim': 'beyaz'}), '34ABC (beyaz)');
      expect(alt(const {'plaka': '34ABC', 'daire': 'A-1', 'tanim': 'beyaz'}),
          '34ABC — Daire A-1 (beyaz)');
    });

    test('veri YOKSA uydurma metin uretilmez', () async {
      final l10n = await _l10n('tr');
      expect(
        akisAltMetni(l10n, 'tr', _olay(ActivityTur.kargo, AkisBaslik.kargo)),
        isNull,
      );
    });
  });

  test('BILINMEYEN kimlik: satir dusmez, deprecated sunucu metnine duser',
      () async {
    final l10n = await _l10n('en');
    final olay = _olay(
      ActivityTur.bilinmeyen,
      AkisBaslik.bilinmeyen,
      sunucuBaslik: 'Yepyeni Olay',
      sunucuAltMetin: 'detay',
    );
    expect(akisBaslikMetni(l10n, olay), 'Yepyeni Olay');
    expect(akisAltMetni(l10n, 'en', olay), 'detay');
  });
}
