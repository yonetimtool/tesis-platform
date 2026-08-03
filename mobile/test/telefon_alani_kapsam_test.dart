/// (P123) KAPSAM KİLİDİ — maskesiz kalan bir telefon alanı BAŞARISIZLIKTIR.
///
/// Görev açıkça şunu istedi: tek bir paylaşılan biçimlendirici yazılsın ve
/// **bütün** çağrı yerleri ona taşınsın. Böyle bir göç her zaman aynı
/// biçimde eksik kalır: altı alandan beşi taşınır, altıncısı gözden kaçar
/// ve hiçbir test düşmez — çünkü o ekran zaten "çalışıyordur", yalnız
/// gruplama ve sınır yoktur. Kusur ancak sahada, yanlış kaydedilmiş bir
/// numarayla ortaya çıkar.
///
/// Bu yüzden kapsam **koda bakılarak** ölçülür: `TextInputType.phone`
/// kullanan her alan, `TelefonBicimlendirici` de kullanmak ZORUNDADIR.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `lib/src` altındaki tüm dart dosyaları.
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

/// `//` yorumlarını siler (yorumdaki örnek kod bulgu sayılmasın).
String _yorumsuz(String s) => s
    .split('\n')
    .map((l) => l.replaceFirst(RegExp(r'\s*//.*$'), ''))
    .join('\n');

/// Bir dosyadaki telefon alanı ihlalleri.
///
/// Mantık AYRI bir fonksiyonda: böylece kasıtlı kusurlu bir örnekle
/// sınanabiliyor. Depoda ihlal kalmadığı için "geçen" bir tarama,
/// çalıştığını KANITLAMAZ (deponun tur 59 dersi).
List<String> telefonIhlalleri(String kaynak, String yol) {
  final temiz = _yorumsuz(kaynak);
  final bulgular = <String>[];
  for (final m in RegExp(r'TextInputType\.phone').allMatches(temiz)) {
    // Alanın gövdesi: `TextInputType.phone`ın çevresindeki ~600 karakter.
    // Bir `TextFormField` bloğu pratikte bundan kısadır.
    final bas = (m.start - 300).clamp(0, temiz.length);
    final son = (m.end + 600).clamp(0, temiz.length);
    final pencere = temiz.substring(bas, son);
    if (pencere.contains('TelefonBicimlendirici')) continue;
    final satir = temiz.substring(0, m.start).split('\n').length;
    bulgular.add('$yol:$satir  telefon alani MASKESIZ');
  }
  return bulgular;
}

void main() {
  test('DEDEKTOR: tarama KASITLI kusuru gorur', () {
    // 1) Maskesiz alan → bulgu.
    expect(
      telefonIhlalleri(
        'TextFormField(keyboardType: TextInputType.phone, decoration: x)',
        'ornek.dart',
      ),
      hasLength(1),
    );
    // 2) Maskeli alan → bulgu YOK.
    expect(
      telefonIhlalleri(
        'TextFormField(keyboardType: TextInputType.phone, '
        'inputFormatters: const [TelefonBicimlendirici()], decoration: x)',
        'ornek.dart',
      ),
      isEmpty,
    );
    // 3) YORUMDAKI ornek bulgu sayilmaz.
    expect(
      telefonIhlalleri('// ornek: TextInputType.phone', 'ornek.dart'),
      isEmpty,
    );
  });

  test('HER telefon alani paylasilan bicimlendiriciyi kullanir', () {
    final bulgular = <String>[];
    for (final f in _kaynaklar()) {
      bulgular.addAll(telefonIhlalleri(f.readAsStringSync(), f.path));
    }
    expect(
      bulgular,
      isEmpty,
      reason: 'Maskesiz telefon alani kaldi. `TelefonBicimlendirici` ekleyin:\n'
          '${bulgular.join('\n')}',
    );
  });

  test('EN AZ ALTI alan olculuyor (tarama bos kumeyi "temiz" saymasin)', () {
    // Kapsam kilidinin en sinsi bozulma bicimi: desen degisir, tarama
    // hicbir sey bulamaz ve "gecti" der. Sayi, taramanin GERCEKTEN bir
    // seye baktiginin kanitidir.
    var alan = 0;
    for (final f in _kaynaklar()) {
      alan += RegExp(r'TextInputType\.phone')
          .allMatches(_yorumsuz(f.readAsStringSync()))
          .length;
    }
    expect(alan, greaterThanOrEqualTo(6),
        reason: 'telefon alani sayisi beklenenden az — tarama bir seyi '
            'kaciriyor olabilir (bulunan: $alan)');
  });
}
