/// (P233 §4) E-POSTA KAPSAM KİLİDİ — kendi e-posta alanını kuran ekran
/// BAŞARISIZLIKTIR.
///
/// Ölçülen durum: sunucu `EmailStr` ile yerel>64, toplam>254 ve bozuk
/// biçimi ZATEN reddediyordu. Kural vardı; eksik olan kuralın KULLANICIYA
/// SÖYLENMESİYDİ. Ekranların doğrulaması ya yoktu (sakin) ya da her ekranın
/// KENDİ regex'iydi (personel, kayıt) — ve o regex'ler uzunluk sınırlarını
/// bilmiyordu, yani sunucunun reddettiği bir adres ekranda geçerli
/// görünüyordu.
///
/// Kural: `lib/src/features` altında e-posta alanı KURULMAZ; hepsi
/// `core/ui/eposta_alani_widget.dart`taki `EpostaAlani`ya bağlanır.
///
/// TEK MUAFİYET: GİRİŞ EKRANI. Orada alan "e-posta VEYA telefon" taşıyan
/// TEK kimlik alanıdır (P205 §1) ve kimlik türünü sunucu çözer; e-posta
/// biçim denetimi uygulamak, telefonuyla giren kullanıcıyı engellerdi.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

String _yorumsuz(String s) => s
    .split('\n')
    .map((l) => l.replaceFirst(RegExp(r'\s*//.*$'), ''))
    .join('\n');

/// E-posta alanını KENDİ kuran dosyalar.
///
/// Mantık AYRI fonksiyonda: kasıtlı kusurlu bir örnekle sınanabilsin diye.
List<String> epostaIhlalleri(String kaynak, String yol) {
  if (yol.contains('core/ui/eposta_')) return const [];
  // GİRİŞ EKRANI MUAF — gerekçe dosya başında.
  if (yol.contains('auth/presentation/login_screen.dart')) return const [];
  // (P248 §2) GIRIS KIMLIK ALANI ortak telefon bileseninin KIMLIK kipine
  // tasindi (tek alan: e-posta VEYA telefon). Oradaki `emailAddress`
  // klavyesi girisin tek alaninindir, bir form e-posta alani degil.
  if (yol.contains('core/ui/telefon_alani_widget.dart')) return const [];
  final temiz = _yorumsuz(kaynak);
  final bulgular = <String>[];
  for (final m in RegExp(r'TextInputType\.emailAddress').allMatches(temiz)) {
    final satir = temiz.substring(0, m.start).split('\n').length;
    bulgular.add('$yol:$satir  kendi e-posta alanini kuruyor');
  }
  return bulgular;
}

void main() {
  test('DEDEKTOR: tarama KASITLI kusuru gorur', () {
    expect(
      epostaIhlalleri(
        'TextFormField(keyboardType: TextInputType.emailAddress)',
        'lib/src/features/x/ornek.dart',
      ),
      hasLength(1),
    );
    expect(
      epostaIhlalleri(
        'keyboardType: TextInputType.emailAddress',
        'lib/src/core/ui/eposta_alani_widget.dart',
      ),
      isEmpty,
    );
    expect(
      epostaIhlalleri(
        'keyboardType: TextInputType.emailAddress',
        'lib/src/features/auth/presentation/login_screen.dart',
      ),
      isEmpty,
    );
    expect(
      epostaIhlalleri(
        '// ornek: TextInputType.emailAddress',
        'lib/src/features/x/ornek.dart',
      ),
      isEmpty,
    );
  });

  test('HIC BIR EKRAN kendi e-posta alanini kurmuyor', () {
    final bulgular = <String>[];
    for (final f in _kaynaklar()) {
      bulgular.addAll(epostaIhlalleri(f.readAsStringSync(), f.path));
    }
    expect(bulgular, isEmpty,
        reason: 'E-posta alani ELLE kurulmus. `EpostaAlani` kullanin:\n'
            '${bulgular.join('\n')}');
  });

  test('EN AZ UC alan paylasilan widgeti kullaniyor', () {
    // Sayı, taramanin GERCEKTEN bir seye baktiginin kaniti: sakin,
    // personel, kayit.
    var alan = 0;
    for (final f in _kaynaklar()) {
      if (f.path.contains('core/ui/eposta_')) continue;
      alan += RegExp(r'EpostaAlani\(')
          .allMatches(_yorumsuz(f.readAsStringSync()))
          .length;
    }
    expect(alan, greaterThanOrEqualTo(3), reason: 'bulunan: $alan');
  });

  test('YEREL REGEX KALMADI (uzunluk sinirlarini bilmeyen kopya kural)', () {
    // P233 §4'te iki ekranda ayni regex vardi; birini silip otekini
    // unutmak bu turun en olasi kusuruydu.
    final kalanlar = <String>[];
    for (final f in _kaynaklar()) {
      if (f.path.contains('core/ui/eposta')) continue;
      final temiz = _yorumsuz(f.readAsStringSync());
      if (temiz.contains(r"[^@\s]+@[^@\s]+")) kalanlar.add(f.path);
    }
    expect(kalanlar, isEmpty, reason: kalanlar.join('\n'));
  });
}
