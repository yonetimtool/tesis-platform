/// TUR 79 (P3) — YONETICI ILETISIM MODELLERI.
///
/// Seri kapanirken kalan sifir-kapsamli dosyalardan biri (0/12). Cozumleme
/// hatasi burada SESSIZ degildir — dizin ekrani bos doner — ama iki nokta
/// ozellikle kirilgan: `telefon` BILEREK acik doner (auth.md hizmet-rolu
/// istisnasi) ve `yoneticiler` alani sunucudan HIC gelmeyebilir.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/yonetici_iletisim/domain/yonetici_iletisim_models.dart';

void main() {
  test('YoneticiKart: telefon ACIK gelir (gizlenmez)', () {
    final k = YoneticiKart.fromJson({
      'user_id': 'u1',
      'ad_soyad': 'Ayse Yonetici',
      'telefon': '+905551112233',
    });
    expect(k.userId, 'u1');
    expect(k.adSoyad, 'Ayse Yonetici');
    expect(k.telefon, '+905551112233');
  });

  test('YoneticiKart: telefon null olabilir', () {
    final k = YoneticiKart.fromJson({'user_id': 'u2', 'ad_soyad': 'Mehmet'});
    expect(k.telefon, isNull);
  });

  test('YoneticiIletisim: liste + yonetim e-postasi', () {
    final y = YoneticiIletisim.fromJson({
      'yoneticiler': [
        {'user_id': 'u1', 'ad_soyad': 'Ayse', 'telefon': '+905551112233'},
        {'user_id': 'u2', 'ad_soyad': 'Mehmet', 'telefon': null},
      ],
      'yonetim_email': 'yonetim@acme.test',
    });
    expect(y.yoneticiler, hasLength(2));
    expect(y.yoneticiler[1].telefon, isNull);
    expect(y.yonetimEmail, 'yonetim@acme.test');
  });

  test('YoneticiIletisim: alanlar HIC gelmezse bos liste (tipe dusmez)', () {
    final y = YoneticiIletisim.fromJson(const {});
    expect(y.yoneticiler, isEmpty);
    expect(y.yonetimEmail, isNull);
  });

  test('YoneticiIletisim: yoneticiler null gelirse bos liste', () {
    final y = YoneticiIletisim.fromJson(const {'yoneticiler': null});
    expect(y.yoneticiler, isEmpty);
  });

  test('const kurucu: dogrudan kurulum', () {
    const y = YoneticiIletisim(
      yoneticiler: [YoneticiKart(userId: 'u9', adSoyad: 'Zeynep')],
    );
    expect(y.yoneticiler.single.adSoyad, 'Zeynep');
    expect(y.yonetimEmail, isNull);
  });
}
