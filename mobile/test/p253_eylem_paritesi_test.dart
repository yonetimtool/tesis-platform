/// (P253 §B, plan §4.3) EYLEM PARITESI — mobil kilidi.
///
/// `contracts/eylem-paritesi.tsv` tek kaynak. Bu test:
///   * mobilin cagirdigi her (metot, yol) tabloda bir SOZLESME ucuna eslenir
///     ve o satir `mobil=+` der (yeni mobil cagri tabloya islenmeli);
///   * `mobil=+` diyen her satir mobilde GERCEKTEN cagrilir — "tabloya ayni
///     yazip yapmamak" kacagi kapanir;
///   * `planli:N` satiri, pubspec surumu o asamanin surumune ulastiginda hala
///     duruyorsa DUSER: "Asama N yayimlandi ama bu satir hala planli".
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/eylem_tarama.dart';

/// Plan §3: her asama kendi surumu.
const asamaSurumu = {1: '1.11.0', 2: '1.12.0', 3: '1.13.0'};

class _Satir {
  _Satir(this.metot, this.uc, this.web, this.mobil, this.durum);
  final String metot, uc, web, mobil, durum;
  String get anahtar => '$metot $uc';
}

List<_Satir> _tablo() {
  final satirlar = File('../contracts/eylem-paritesi.tsv')
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
      .toList();
  final ad = satirlar.first.split('\t');
  int i(String a) => ad.indexOf(a);
  return [
    for (final l in satirlar.skip(1))
      if (l.split('\t') case final p)
        _Satir(p[i('metot')], p[i('uc')], p[i('web')], p[i('mobil')], p[i('durum')]),
  ];
}

/// Web kilidiyle AYNI puan: sabit 2, degisken<->parametre 1, degisken<->sabit 0.
_Satir? esle(List<_Satir> satirlar, String metot, String yol) {
  final ys = yol.replaceFirst(RegExp(r'^/'), '').split('/');
  _Satir? en;
  var enPuan = -1;
  for (final s in satirlar) {
    if (s.metot != metot) continue;
    final os = s.uc.replaceFirst(RegExp(r'^/'), '').split('/');
    if (os.length != ys.length) continue;
    var puan = 0;
    var uyar = true;
    for (var i = 0; i < ys.length; i++) {
      final parametre = RegExp(r'^\{.+\}$').hasMatch(os[i]);
      if (ys[i] == os[i]) {
        puan += 2;
      } else if (ys[i] == '{x}' && parametre) {
        puan += 1;
      } else if (ys[i] == '{x}' || parametre) {
        continue;
      } else {
        uyar = false;
        break;
      }
    }
    if (uyar && puan > enPuan) {
      en = s;
      enPuan = puan;
    }
  }
  return en;
}

List<int> _surum(String s) => s.split('+').first.split('.').map(int.parse).toList();
bool _ulasti(String mevcut, String hedef) {
  final a = _surum(mevcut), b = _surum(hedef);
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return true;
}

void main() {
  final satirlar = _tablo();
  final uclar = mobilUclari();

  test('mobilin her cagrisi tabloda bir SOZLESME ucuna eslenir', () {
    final eslesmeyen = {
      for (final u in uclar)
        if (esle(satirlar, u.metot, u.yol) == null) '${u.metot} ${u.yol}  (${u.dosya})',
    };
    expect(eslesmeyen, isEmpty,
        reason: 'Mobil bu uca gidiyor ama sozlesmede/tabloda YOK');
  });

  test('mobilin cagirdigi her uc tabloda mobil=+', () {
    final eksik = <String>{};
    for (final u in uclar) {
      final s = esle(satirlar, u.metot, u.yol);
      if (s != null && s.mobil != '+') eksik.add('${s.anahtar}  (${u.dosya})');
    }
    expect(eksik, isEmpty,
        reason: "Mobile YENI bir cagri eklendi; contracts/eylem-paritesi.tsv'de "
            "mobil=+ yapin ve durumu guncelleyin (planli:N -> ayni).");
  });

  test('tabloda mobil=+ diyen her satir mobilde GERCEKTEN cagrilir', () {
    final bulunan = {
      for (final u in uclar)
        if (esle(satirlar, u.metot, u.yol) case final s?) s.anahtar,
    };
    final bayat = [
      for (final s in satirlar)
        if (s.metot != 'ISTEMCI' && s.mobil == '+' && !bulunan.contains(s.anahtar)) s.anahtar,
    ];
    expect(bayat, isEmpty, reason: 'Tablo mobil=+ diyor ama mobil bu ucu cagirmiyor');
  });

  test('asamasi yayimlanan planli satir KALMAZ', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final surum = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)!.group(1)!;
    final kalan = [
      for (final s in satirlar)
        if (RegExp(r'^planli:(\d)$').firstMatch(s.durum) case final m?)
          if (_ulasti(surum, asamaSurumu[int.parse(m.group(1)!)]!))
            '${s.anahtar} (${s.durum}, surum $surum)',
    ];
    expect(kalan, isEmpty,
        reason: 'Asama yayimlandi ama bu satirlar hala planli: yapin ya da gerekceyle tasiyin');
  });
}
