// (E2E 2026-09 / TESIS-16 + ANA-4) Mobil daire no onizlemesi sunucunun
// `daire_no_kanonik` kuralinin aynasi: yalniz rakam -> "{blok}-{no}".
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/building_map/domain/daire_no.dart';

void main() {
  test('yalniz rakam blok onekini alir', () {
    expect(daireNoOnizle('11', 'A'), 'A-11');
    expect(daireNoOnizle(' 7 ', 'B'), 'B-7');
  });
  test('onekli/harfli no aynen kalir', () {
    expect(daireNoOnizle('A-11', 'A'), 'A-11');
    expect(daireNoOnizle('B3', 'A'), 'B3');
  });
  test('bloksuz daireye dokunulmaz', () {
    expect(daireNoOnizle('12', null), '12');
  });
}
