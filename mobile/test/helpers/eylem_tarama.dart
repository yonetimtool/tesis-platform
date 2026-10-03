/// (P253 §B, plan §4.3) MOBIL EYLEM TARAMASI — uygulamanin backend'de
/// neyi cagirabildigi, KAYNAKTAN.
///
/// Cozulen bicimler:
///   * dogrudan: `_dio.get<...>('/yol/$id', ...)` (alici `_dio`, `dio`,
///     `rawDio`);
///   * sabit: `static const _uc = '/x'; _dio.put(_uc, ...)`;
///   * sarmalayici: bir islev parametresini `_dio.<metot>(param` olarak
///     iletiyorsa (`_liste(String yol)` -> GET), o isleve DIZE argumanla
///     yapilan cagrilar o metodu tasir;
///   * acik metot: `_yaz('PATCH', '/x/$id', ...)`;
///   * genel defter (P253 Asama 2): `DefterTanimi(... uc: '/x' ...)` →
///     GET/POST `/x`, PATCH/DELETE `/x/{x}`.
/// Yol normallestirme web taramasiyla AYNI: parametre `{x}`, sorgu yok.
library;

import 'dart:io';

class MobilUcu {
  const MobilUcu(this.metot, this.yol, this.dosya);
  final String metot;
  final String yol;
  final String dosya;
}

final _metotlar = {'get', 'post', 'put', 'patch', 'delete'};
/// Alici adi ONEMSIZ: `_dio.get(`, `rawDio.post(`, `ref.read(dioProvider).get(`.
/// Yalniz `/` ile baslayan dize ya da bilinen sabit argumanli cagrilar sayilir.
final _alici = RegExp(r"\.\s*(get|post|put|patch|delete)\s*(?:<[^()]*?>)?\s*\(\s*", dotAll: true);

/// `'...'` ya da `"..."` dizesi (Dart enterpolasyonu `$x` / `${...}`).
final _dize = RegExp(r"""^(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")""");

String yolNormalle(String ham) {
  var y = StringBuffer();
  for (var i = 0; i < ham.length; i++) {
    final c = ham[i];
    if (c == r'$' && i + 1 < ham.length && ham[i + 1] == '{') {
      var d = 0;
      for (i = i + 1; i < ham.length; i++) {
        if (ham[i] == '{') d++;
        if (ham[i] == '}') {
          d--;
          if (d == 0) break;
        }
      }
      y.write('{x}');
    } else if (c == r'$') {
      var j = i + 1;
      while (j < ham.length && RegExp(r'[A-Za-z0-9_]').hasMatch(ham[j])) {
        j++;
      }
      y.write('{x}');
      i = j - 1;
    } else {
      y.write(c);
    }
  }
  var s = y.toString().split('?').first;
  s = s.replaceAll(RegExp(r'([^/{])\{x\}$'), r'$1');
  s = s.replaceAll(RegExp(r'/+$'), '');
  return s.isEmpty ? '/' : s;
}

String? _dizeBas(String metin) {
  final m = _dize.firstMatch(metin);
  if (m == null) return null;
  final d = m.group(1) ?? m.group(2)!;
  return d.startsWith('/') ? d : null;
}

/// Konumu iceren islevin adi ve parametre adlari.
({String ad, List<String> paramlar})? _icindekiIslev(String dosya, int konum) {
  final once = dosya.substring(0, konum);
  final imza = RegExp(r'(\w+)\s*\(([^()]*)\)\s*(?:async\s*)?(?:\{|=>)').allMatches(once).lastOrNull;
  if (imza == null) return null;
  final paramlar = imza.group(2)!
      .split(',')
      .map((e) => e.trim().replaceAll(RegExp(r'[{}\[\]]'), '').split(RegExp(r'\s+')).last)
      .toList();
  return (ad: imza.group(1)!, paramlar: paramlar);
}

/// `ad` isleve `sira`ncil argumanla gecilen dize degerleri. Arguman bir
/// degiskense ve cagiranin parametresiyse BIR KATMAN DAHA yukari cikilir.
/// Ozel (`_` ile baslayan) adlar yalniz kendi dosyasinda aranir — iki
/// dosyada ayni adli `_eylem` olabilir (panik, diyafon).
Set<String> _argDegerleri(String ad, int sira, String dosyaYolu, Map<String, String> tumu, int derinlik) {
  final out = <String>{};
  if (derinlik > 3) return out;
  final kapsam = ad.startsWith('_') ? {dosyaYolu: tumu[dosyaYolu]!} : tumu;
  for (final e in kapsam.entries) {
    for (final m in RegExp(r'\b' + ad + r'\(([^()]*)\)').allMatches(e.value)) {
      final arg = m.group(1)!.split(',');
      if (arg.length <= sira) continue;
      final a = arg[sira].trim();
      final d = RegExp(r"^'([a-z][a-z0-9-]*)'$").firstMatch(a);
      if (d != null) {
        out.add(d.group(1)!);
        continue;
      }
      if (!RegExp(r'^\w+$').hasMatch(a)) continue;
      final ust = _icindekiIslev(e.value, m.start);
      if (ust == null || ust.ad == ad) continue;
      final usira = ust.paramlar.indexOf(a);
      if (usira >= 0) out.addAll(_argDegerleri(ust.ad, usira, e.key, tumu, derinlik + 1));
    }
  }
  return out;
}

/// Yolun SON parcasi icinde bulundugu islevin bir parametresiyse
/// (`/panik/$id/$eylem`) o islevin cagrilarindaki dize argumanlariyla
/// acilir (`_eylem(id, 'gordum')` -> `/panik/{x}/gordum`).
List<String> _eylemAcilimi(String dosyaYolu, int konum, String ham, Map<String, String> tumu) {
  final son = RegExp(r'\$(\w+)$').firstMatch(ham);
  if (son == null) return [ham];
  final islev = _icindekiIslev(tumu[dosyaYolu]!, konum);
  if (islev == null) return [ham];
  final sira = islev.paramlar.indexOf(son.group(1)!);
  if (sira < 0) return [ham];
  final degerler = _argDegerleri(islev.ad, sira, dosyaYolu, tumu, 0);
  if (degerler.isEmpty) return [ham];
  final kok = ham.substring(0, son.start);
  return [for (final d in degerler) '$kok$d'];
}

List<MobilUcu> mobilUclari({String kok = 'lib'}) {
  final out = <MobilUcu>[];
  final dosyalar = Directory(kok)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/'))
      .toList();
  final tumu = {for (final f in dosyalar) f.path: f.readAsStringSync()};
  for (final f in dosyalar) {
    final s = tumu[f.path]!;
    // (P253 Asama 2) GENEL DEFTER: `DefterTanimi(... uc: '/kasalar' ...)`
    // blogundaki literal uc, genel defter ekraninin YAPABILDIGI dort
    // islemle acilir (liste, ekle, duzenle, sil) — web `genelAcilim`in
    // ikizi. Yol degiskenle cagrildigi icin (`_dio.get(uc`) dogrudan
    // taramaya gorunmez; tanim literal kaldigi surece burasi gorur.
    for (final m in RegExp(r'\bDefterTanimi\(').allMatches(s)) {
      var i = m.end;
      var derinlik = 1;
      while (i < s.length && derinlik > 0) {
        if (s[i] == '(') derinlik++;
        if (s[i] == ')') derinlik--;
        i++;
      }
      final blok = s.substring(m.end, i);
      final uc = RegExp(r"\buc:\s*'(/[^']*)'").firstMatch(blok)?.group(1);
      if (uc == null) continue;
      out.add(MobilUcu('GET', yolNormalle(uc), f.path));
      out.add(MobilUcu('POST', yolNormalle(uc), f.path));
      out.add(MobilUcu('PATCH', yolNormalle('$uc/{x}'), f.path));
      out.add(MobilUcu('DELETE', yolNormalle('$uc/{x}'), f.path));
    }
    // Genel defter tanimi dio icermez; kural bu suzgecten ONCE.
    if (!s.contains('dio')) continue;
    // Dosyadaki sabit yollar: `const _uc = '/x'`.
    final sabitler = <String, String>{};
    for (final m in RegExp(r"""const\s+(\w+)\s*=\s*('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")""").allMatches(s)) {
      final d = _dizeBas(m.group(2)!);
      if (d != null) sabitler[m.group(1)!] = d;
    }
    // Sarmalayicilar: param -> metot.
    final sarmalayici = <String, String>{};
    for (final m in RegExp(r'(\w+)\s*(?:<[^>()]*>)?\s*\(\s*(?:String\s+(\w+)|\{?\s*required\s+String\s+(\w+))[\s\S]{0,300}?\)\s*(?:async\s*)?(?:=>|\{)', dotAll: true).allMatches(s)) {
      final ad = m.group(1)!;
      final param = m.group(2) ?? m.group(3)!;
      final govde = s.substring(m.end, (m.end + 1500).clamp(0, s.length));
      final c = RegExp(r"\b(?:_dio|dio)\.(get|post|put|patch|delete)\s*(?:<[^()]*?>)?\s*\(\s*" + param + r"\b", dotAll: true).firstMatch(govde);
      if (c != null && !_metotlar.contains(ad)) sarmalayici[ad] = c.group(1)!.toUpperCase();
    }
    void ekle(String metot, String ham) => out.add(MobilUcu(metot, yolNormalle(ham), f.path));

    for (final m in _alici.allMatches(s)) {
      final sonra = s.substring(m.end);
      final d = _dizeBas(sonra);
      if (d != null) {
        for (final y in _eylemAcilimi(f.path, m.start, d, tumu)) {
          ekle(m.group(1)!.toUpperCase(), y);
        }
        continue;
      }
      final id = RegExp(r'^(\w+)\b').firstMatch(sonra)?.group(1);
      if (id != null && sabitler.containsKey(id)) ekle(m.group(1)!.toUpperCase(), sabitler[id]!);
    }
    for (final e in sarmalayici.entries) {
      for (final m in RegExp(r'\b' + e.key + r"\s*\(\s*").allMatches(s)) {
        final d = _dizeBas(s.substring(m.end));
        if (d != null) ekle(e.value, d);
      }
    }
    for (final m in RegExp(r"""\w+\(\s*'(GET|POST|PUT|PATCH|DELETE)'\s*,\s*""").allMatches(s)) {
      final d = _dizeBas(s.substring(m.end));
      if (d != null) ekle(m.group(1)!, d);
    }
  }
  return out;
}
