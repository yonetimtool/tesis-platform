/// (P123 · P233 §3) KAPSAM KİLİDİ — kendi telefon alanını kuran ekran
/// BAŞARISIZLIKTIR.
///
/// P123'te kural "her telefon alanı `TelefonBicimlendirici` kullanmalı"ydı.
/// P233 §3'te bu YETMEDİĞİ ÖLÇÜLDÜ: ülke kodu seçicisi eklenirken yedi
/// ekranın her birine ELLE dropdown koymak gerekiyordu ve sekizinci ekran
/// onu unutacaktı — unutulan ekran, numarayı ülkesiz kaydeden ekran olur.
///
/// Kural artık DAHA SERT: `lib/src/features` altında telefon alanı KURULMAZ.
/// Telefon girilen her yer `core/ui/telefon_alani_widget.dart`taki
/// `TelefonAlani`ya bağlanır; biçimlendirme, ülke kodu, uzunluk sınırı ve
/// hata metni oradan gelir.
///
/// Kapsam **koda bakılarak** ölçülür: böyle bir göç her zaman aynı biçimde
/// eksik kalır (yedi alandan altısı taşınır, yedincisi gözden kaçar) ve
/// hiçbir davranış testi düşmez — çünkü o ekran zaten "çalışıyordur".
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

/// Telefon alanını KENDİ kuran dosyalar.
///
/// Mantık AYRI bir fonksiyonda: böylece kasıtlı kusurlu bir örnekle
/// sınanabiliyor. Depoda ihlal kalmadığı için "geçen" bir tarama,
/// çalıştığını KANITLAMAZ (deponun tur 59 dersi).
List<String> telefonIhlalleri(String kaynak, String yol) {
  // Paylaşılan alanın KENDİSİ muaf — kuralı uygulayan yer orası.
  if (yol.contains('core/ui/telefon_')) return const [];
  final temiz = _yorumsuz(kaynak);
  final bulgular = <String>[];
  for (final desen in [
    'TextInputType.phone',
    'TelefonBicimlendirici',
    // (P248 §2) Telefon otomatik doldurmasi da ancak kendi telefon
    // alanini kuran bir ekranda olur.
    'AutofillHints.telephoneNumber',
  ]) {
    for (final m in RegExp(RegExp.escape(desen)).allMatches(temiz)) {
      final satir = temiz.substring(0, m.start).split('\n').length;
      bulgular.add('$yol:$satir  kendi telefon alanini kuruyor ($desen)');
    }
  }
  // (P248 §2) ETIKETI TELEFON OLAN DUZ ALAN: klavyesi `phone` olmasa da
  // (`TextInputType.text`/varsayilan) telefon ISTEYEN bir alan. Rakamlar
  // bitisik, sinirsiz, ulke kodu secilemez — kullanicinin bildirdigi
  // kusurun ta kendisi. `labelText: l10n.xxxTelefonyyy` deseni.
  for (final m in RegExp(
    r'labelText:\s*[A-Za-z0-9_]+\.[A-Za-z_]*(?:[Tt]elefon|[Pp]hone|[Gg]sm)[A-Za-z_]*',
  ).allMatches(temiz)) {
    final satir = temiz.substring(0, m.start).split('\n').length;
    bulgular.add('$yol:$satir  etiketi telefon olan duz alan');
  }
  return bulgular;
}

void main() {
  _girisKilidi();
  test('DEDEKTOR: tarama KASITLI kusuru gorur', () {
    // 1) Kendi alanini kuran ekran → bulgu.
    expect(
      telefonIhlalleri(
        'TextFormField(keyboardType: TextInputType.phone, decoration: x)',
        'lib/src/features/x/ornek.dart',
      ),
      hasLength(1),
    );
    // 2) Bicimlendiriciyi elle takan ekran DA bulgu — P123'te yeterliydi,
    //    P233'te degil: ulke kodu secicisi gelmez.
    expect(
      telefonIhlalleri(
        'inputFormatters: const [TelefonBicimlendirici()]',
        'lib/src/features/x/ornek.dart',
      ),
      hasLength(1),
    );
    // 3) Paylasilan alan MUAF.
    expect(
      telefonIhlalleri(
        'keyboardType: TextInputType.phone',
        'lib/src/core/ui/telefon_alani_widget.dart',
      ),
      isEmpty,
    );
    // 4) (P248 §2) Etiketi telefon olan DUZ alan (klavye `phone` degil).
    expect(
      telefonIhlalleri(
        'TextField(decoration: InputDecoration(labelText: l10n.firmaTelefon))',
        'lib/src/features/x/ornek.dart',
      ),
      hasLength(1),
    );
    expect(
      telefonIhlalleri(
        'autofillHints: const [AutofillHints.telephoneNumber]',
        'lib/src/features/x/ornek.dart',
      ),
      hasLength(1),
    );
    // 5) ORTAK WIDGET'A etiket vermek ihlal DEGIL.
    expect(
      telefonIhlalleri(
        'TelefonAlani(ktrl: k, etiket: l10n.profilTelefon)',
        'lib/src/features/x/ornek.dart',
      ),
      isEmpty,
    );
    // 6) YORUMDAKI ornek bulgu sayilmaz.
    expect(
      telefonIhlalleri(
        '// ornek: TextInputType.phone',
        'lib/src/features/x/ornek.dart',
      ),
      isEmpty,
    );
  });

  test('HIC BIR EKRAN kendi telefon alanini kurmuyor', () {
    final bulgular = <String>[];
    for (final f in _kaynaklar()) {
      bulgular.addAll(telefonIhlalleri(f.readAsStringSync(), f.path));
    }
    expect(
      bulgular,
      isEmpty,
      reason: 'Telefon alani ELLE kurulmus. `TelefonAlani` widgetini '
          'kullanin:\n${bulgular.join('\n')}',
    );
  });

  test('EN AZ SEKIZ alan paylasilan widgeti kullaniyor', () {
    // Kapsam kilidinin en sinsi bozulma bicimi: desen degisir, tarama
    // hicbir sey bulamaz ve "gecti" der. Sayi, taramanin GERCEKTEN bir
    // seye baktiginin kanitidir. Yedi = sakin(ekle+duzenle), personel,
    // dis hizmet, kayit, profil, dukkan.
    var alan = 0;
    for (final f in _kaynaklar()) {
      if (f.path.contains('core/ui/telefon_')) continue;
      alan += RegExp(r'TelefonAlani\(')
          .allMatches(_yorumsuz(f.readAsStringSync()))
          .length;
    }
    // (P248 §2) SEKIZ: + giris ekraninin kimlik alani (kimlik kipi).
    expect(alan, greaterThanOrEqualTo(8),
        reason: 'telefon alani sayisi beklenenden az — tarama bir seyi '
            'kaciriyor olabilir (bulunan: $alan)');
  });
}

/// (P248 §2) GIRIS EKRANININ kimlik alani ORTAK widget'in kimlik kipi.
///
/// Giris alani klavyesi `emailAddress` oldugu icin yukaridaki desenlerin
/// hicbirine takilmaz; kendi `TextFormField`ine geri donerse ulke kodu
/// yine secilemez olur. Bu yuzden AYRICA kilitli.
void _girisKilidi() {
  test('giris ekrani kimlik alani TelefonAlani(kimlik: true)', () {
    final k = _yorumsuz(File(
      'lib/src/features/auth/presentation/login_screen.dart',
    ).readAsStringSync());
    expect(RegExp(r'TelefonAlani\([^;]*?kimlik:\s*true').hasMatch(k), isTrue);
    expect(k.contains("Key('giris-kimlik')"), isTrue);
  });
}
