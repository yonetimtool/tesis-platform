// P38 — anket domaini: TEK OY ve SONUC GIZLILIGI istemcide de tutulur.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/anket/domain/anket_models.dart';

Map<String, dynamic> _json({
  bool acik = true,
  bool? oyVerdim,
  int? toplam,
  int? oy,
}) => {
      'id': 'a1',
      'baslik': 'Otopark düzeni',
      'aciklama': null,
      'acik': acik,
      'oy_verdim': oyVerdim,
      'toplam_oy': toplam,
      'secenekler': [
        {'id': 's1', 'metin': 'Evet', 'sira': 0, 'oy': oy},
        {'id': 's2', 'metin': 'Hayır', 'sira': 1, 'oy': oy},
      ],
    };

void main() {
  test('ACIK ve oy vermemis -> oy verilebilir', () {
    expect(Anket.fromJson(_json(oyVerdim: false)).oyVerilebilir, isTrue);
  });

  test('OY VERILMISSE buton HIC cizilmez (oy DEGISTIRILEMEZ)', () {
    // Sunucu 409 dondurup kullaniciya hata gostermek yerine, yapilamayacak
    // seyi hic teklif etmiyoruz.
    expect(Anket.fromJson(_json(oyVerdim: true)).oyVerilebilir, isFalse);
  });

  test('KAPALI ankette oy verilemez', () {
    expect(
      Anket.fromJson(_json(acik: false, oyVerdim: false)).oyVerilebilir,
      isFalse,
    );
  });

  test('PUBLIC yanit (oy_verdim null) oy TEKLIF ETMEZ', () {
    // Kimliksiz ziyaretci oy veremez; null'i "vermedi" sayip buton cizmek,
    // dokununca giris ekranina atmak olurdu.
    final a = Anket.fromJson(_json(oyVerdim: null));
    expect(a.oyVerdim, isNull);
    expect(a.oyVerilebilir, isTrue,
        reason: 'model KURALI tasir; ekran ayrica rol kapisina bakar');
  });

  test('ACIK ankette SONUC YOK (surusel etki)', () {
    final a = Anket.fromJson(_json(oyVerdim: true));
    expect(a.sonucVar, isFalse);
    expect(a.secenekler.every((s) => s.oy == null), isTrue);
  });

  test('KAPANINCA sonuc gelir ve gosterilir', () {
    final a = Anket.fromJson(_json(acik: false, toplam: 7, oy: 3));
    expect(a.sonucVar, isTrue);
    expect(a.toplamOy, 7);
    expect(a.secenekler.first.oy, 3);
  });

  test('bozuk/eksik yanit COKMEZ', () {
    final a = Anket.fromJson({'id': 'x', 'baslik': 'B'});
    expect(a.acik, isFalse);
    expect(a.secenekler, isEmpty);
    expect(a.sonucVar, isFalse);
  });
}
