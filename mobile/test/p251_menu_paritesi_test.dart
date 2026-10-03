/// (P251 §8) WEB <-> MOBIL MENU PARITESI — MOBIL TARAFI KILIDI.
///
/// Tek kaynak `contracts/menu-paritesi.tsv` (web kilidi:
/// `admin-web/tests/p251-menu-paritesi.test.ts`). Bir girisin grubu ya
/// da adi degisirse, tabloda olmayan bir giris eklenirse ya da tablodaki
/// bir giris menuden kalkarsa bu test duser — iki yuzey bir daha
/// kendiliginden ayrisamaz. Bilincli fark tabloya GEREKCESIYLE yazilir.
///
/// Ad karsilastirmasi TURKCE metinle (anahtar ayni olsa da metin ayrisabilir).
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/gen/app_localizations.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/bilgisayardan/presentation/bilgisayardan_screen.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';

class _Satir {
  _Satir(List<String> p)
      : kapsam = p[0],
        grup = p[1],
        web = p[2],
        mobil = p[3],
        ad = p[4],
        durum = p[5];
  final String kapsam, grup, web, mobil, ad, durum;
}

List<_Satir> _tablo() {
  final ham = File('../contracts/menu-paritesi.tsv').readAsLinesSync();
  final satirlar = ham.where((l) => l.trim().isNotEmpty && !l.startsWith('#')).toList();
  // Baslik test DISINDA okunur (main govdesi); expect burada kullanilamaz.
  if (satirlar.first != 'kapsam\tgrup\tweb\tmobil\tad\tdurum\tgerekce') {
    throw StateError('menu-paritesi.tsv basligi degisti: ${satirlar.first}');
  }
  return [for (final l in satirlar.skip(1)) _Satir(l.split('\t'))];
}

void main() {
  final tablo = _tablo();
  final tr = lookupAppLocalizations(const Locale('tr'));
  final girisler = {for (final e in HomeMenuEntry.values) e.name: e};

  test('tablo okunuyor ve bos degil (olcum bosa dusmesin)', () {
    expect(tablo.where((s) => s.kapsam == 'yonetici').length, greaterThan(40));
  });

  test('tablodaki her mobil ad gercek bir HomeMenuEntry', () {
    final bilinmeyen = [
      for (final s in tablo)
        if (s.mobil != '-' && !girisler.containsKey(s.mobil)) s.mobil,
    ];
    expect(bilinmeyen, isEmpty);
  });

  // (P253 Asama 2) `denetci` kapsami: mobil denetci SALT OKUMA menusu.
  for (final (kapsam, rol) in [
    ('yonetici', UserRole.yonetici),
    ('sakin', UserRole.resident),
    ('denetci', UserRole.denetci),
  ]) {
    test('$kapsam: mobil menu tabloyla BIREBIR (grup + Turkce ad)', () {
      final beklenen = tablo.where((s) => s.kapsam == kapsam && s.mobil != '-').toList();
      final menu = homeMenuForRole(rol);
      final fark = <String>[];
      for (final e in menu) {
        final s = beklenen.where((b) => b.mobil == e.name).firstOrNull;
        if (s == null) {
          fark.add('tabloda yok: ${e.name} (${moduleBaslik(tr, e)}) — '
              'contracts/menu-paritesi.tsv\'ye ekleyin');
          continue;
        }
        if (homeMenuGrubu(e).name != s.grup) {
          fark.add('${e.name}: grup mobil=${homeMenuGrubu(e).name} tablo=${s.grup}');
        }
        if (moduleBaslik(tr, e) != s.ad) {
          fark.add('${e.name}: ad mobil="${moduleBaslik(tr, e)}" tablo="${s.ad}"');
        }
      }
      for (final s in beklenen) {
        if (!menu.any((e) => e.name == s.mobil)) fark.add('menude yok: ${s.mobil} (${s.ad})');
      }
      expect(fark, isEmpty);
    });
  }

  test('"Bilgisayardan yapilanlar" tablodaki yalniz-web satirlarinin TAMAMI', () {
    final beklenen = {
      for (final s in tablo)
        if (s.kapsam == 'yonetici' && s.durum == 'yalniz_web') s.web,
    };
    expect(webIslemleri.map((w) => w.webRota).toSet(), beklenen);
    // Grup da tabloyla ayni (liste bolumlere gore cizilir).
    for (final w in webIslemleri) {
      final s = tablo.firstWhere((x) => x.web == w.webRota && x.kapsam == 'yonetici');
      expect(w.grup.name, s.grup, reason: w.webRota);
      expect(w.ad(tr), s.ad, reason: w.webRota);
    }
  });

  test('GRUP BASLIKLARI tabloyla ayni (contracts/menu-gruplari.tsv)', () {
    final satirlar = File('../contracts/menu-gruplari.tsv')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
        .skip(1)
        .toList();
    expect(satirlar, hasLength(7));
    for (final l in satirlar) {
      final [grup, baslik] = l.split('\t');
      final g = HomeMenuGrup.values.byName(grup);
      expect(homeMenuGrupBasligi(tr, g), baslik, reason: grup);
    }
  });

  test('grup sirasi web ile ayni', () {
    expect(HomeMenuGrup.values.map((g) => g.name).toList(),
        ['guvenlik', 'tesis', 'finans', 'iletisim', 'kisiler', 'tanimlar', 'yonetim']);
  });
}
