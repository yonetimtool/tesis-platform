/// TUR 61 — AG GORSELLERINDE COZME SINIRI (bellek).
///
/// Envanterin (tur 49, E maddesi) son performans satiri: "buyuk fotografin
/// bellek etkisi". Olcum yapildi ve sonuc net: `lib/src` icindeki **17** ag
/// gorseli cagrisinin HICBIRI cozme siniri vermiyordu. 40x40 dp'lik avatar da
/// 96 dp'lik liste minyaturu de sunucudan gelen fotografi TAM COZUNURLUKTE
/// bellege aciyordu; 4000x3000'lik bir JPEG ~48 MB RGBA tutar.
///
/// Hicbir surus bunu goremezdi: gorsel taklidi (tur 34) minik bir PNG servis
/// ediyor, yani cozme boyutu hic zorlanmiyor. Kusur olcum degil KOD OKUMAYLA
/// bulundu — bu yuzden kural da kodda kilitlenir.
///
/// Iki denetim:
///  1. STATIK: `Image.network(` cagrisi `cacheWidth`/`cacheHeight` vermeli;
///     `NetworkImage(` ya `ResizeImage`/`sinirliGorsel` ile sarilmali.
///  2. CALISMA ANI: `Image.network(..., cacheWidth:)` iceride `ResizeImage`
///     uretir. Yani agactaki her ag gorseli saglayicisinin `ResizeImage`
///     oldugunu dogrulamak, sinirin GERCEKTEN uygulandiginin kanitidir.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/ui/gorsel_cozme.dart';

/// `lib/src` altindaki tum dart dosyalari.
List<File> _kaynaklar() {
  final out = <File>[];
  void yuru(Directory d) {
    for (final e in d.listSync()) {
      if (e is Directory) {
        yuru(e);
      } else if (e is File && e.path.endsWith('.dart')) {
        out.add(e);
      }
    }
  }

  yuru(Directory('lib/src'));
  return out;
}

/// `//` yorumlarini sil (yorumdaki ornek kod bulgu sayilmasin).
String _yorumsuz(String s) => s
    .split('\n')
    .map((l) => l.replaceFirst(RegExp(r'\s*//.*$'), ''))
    .join('\n');

/// Bir kaynak dosyanin ihlallerini dondurur (bos liste = kural saglanmis).
///
/// Mantik AYRI bir fonksiyonda: boylece kasitli kusurlu bir ornekle
/// sinanabiliyor. Tur 59'un dersi — depoda ihlal kalmadigi icin "gecen" bir
/// tarama, calistigini KANITLAMAZ.
List<String> gorselIhlalleri(String kaynak, String yol) {
  final bulgular = <String>[];
  final temiz = _yorumsuz(kaynak);
  for (final m in RegExp(r'Image\.network\(').allMatches(temiz)) {
    final bas = m.end;
    var derinlik = 1, i = bas;
    while (i < temiz.length && derinlik > 0) {
      if (temiz[i] == '(') derinlik++;
      if (temiz[i] == ')') derinlik--;
      i++;
    }
    final govde = temiz.substring(bas, i);
    if (govde.contains('cacheWidth') || govde.contains('cacheHeight')) continue;
    final satir = temiz.substring(0, m.start).split('\n').length;
    bulgular.add('$yol:$satir  cozme siniri YOK');
  }
  for (final m in RegExp(r'NetworkImage\(').allMatches(temiz)) {
    final onek = temiz.substring((m.start - 60).clamp(0, m.start), m.start);
    if (onek.contains('sinirliGorsel(') || onek.contains('ResizeImage(')) {
      continue;
    }
    final satir = temiz.substring(0, m.start).split('\n').length;
    bulgular.add('$yol:$satir  NetworkImage sarilmamis');
  }
  return bulgular;
}

void main() {
  test('DEDEKTOR: tarama KASITLI kusuru gorur', () {
    // 1) Sinirsiz `Image.network` → bulgu.
    expect(
      gorselIhlalleri("Image.network(url, width: 96);", 'ornek.dart'),
      hasLength(1),
    );
    // 2) Sinirli olan → bulgu YOK.
    expect(
      gorselIhlalleri(
        "Image.network(url, width: 96, cacheWidth: cozmeSiniri(context, 96));",
        'ornek.dart',
      ),
      isEmpty,
    );
    // 3) Sarilmamis `NetworkImage` → bulgu.
    expect(
      gorselIhlalleri("backgroundImage: NetworkImage(url),", 'ornek.dart'),
      hasLength(1),
    );
    // 4) Sarilmis olan → bulgu YOK.
    expect(
      gorselIhlalleri(
        "backgroundImage: sinirliGorsel(context, NetworkImage(url), 40),",
        'ornek.dart',
      ),
      isEmpty,
    );
    // 5) YORUMDAKI ornek kod bulgu sayilmaz.
    expect(
      gorselIhlalleri("// ornek: Image.network(url)", 'ornek.dart'),
      isEmpty,
    );
  });

  test('STATIK: her Image.network cozme siniri verir', () {
    final bulgular = <String>[];
    for (final f in _kaynaklar()) {
      bulgular.addAll(gorselIhlalleri(f.readAsStringSync(), f.path));
    }
    expect(
      bulgular,
      isEmpty,
      reason:
          'Ag gorselleri bellekte TAM COZUNURLUKTE aciliyor. `cozmeSiniri` / '
          '`sinirliGorsel` kullanin:\n${bulgular.join("\n")}',
    );
  });

  testWidgets('DEDEKTOR: cacheWidth GERCEKTEN ResizeImage uretir', (
    tester,
  ) async {
    // Bu, statik taramanin gecerlilik kanitidir: `cacheWidth` vermenin cozme
    // boyutunu gercekten sinirladigini (yani kuralin anlamli oldugunu) gosterir.
    late int? sinir;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            sinir = cozmeSiniri(context, 96);
            return Image.network(
              'https://ornek/foto.jpg',
              width: 96,
              height: 72,
              cacheWidth: sinir,
              cacheHeight: cozmeSiniri(context, 72),
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
    final gorsel = tester.widget<Image>(find.byType(Image));
    expect(gorsel.image, isA<ResizeImage>());
    final rz = gorsel.image as ResizeImage;
    expect(rz.width, sinir);
    // Sinirsiz hali ResizeImage URETMEZ — kural gercekten ayirt ediyor.
    await tester.pumpWidget(
      MaterialApp(
        home: Image.network(
          'https://ornek/foto.jpg',
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
    expect(tester.widget<Image>(find.byType(Image)).image, isNot(isA<ResizeImage>()));
  });

  testWidgets('cozmeSiniri piksel yogunluguyla carpar', (tester) async {
    for (final dpr in [1.0, 2.0, 3.0]) {
      late int? px;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(devicePixelRatio: dpr),
          child: Builder(
            builder: (context) {
              px = cozmeSiniri(context, 96);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(px, (96 * dpr).round(), reason: 'dpr=$dpr');
    }
    // Olcu yoksa sinir da yok (tam ekran goruntuleyici gibi durumlar).
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          expect(cozmeSiniri(context, null), isNull);
          expect(cozmeSiniri(context, 0), isNull);
          return const SizedBox.shrink();
        },
      ),
    );
  });
}
