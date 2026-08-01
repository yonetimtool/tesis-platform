// (P82) MOBIL ROL ENUM'U SUNUCUYLA ORTUSUR — capraz bag.
//
// P80 ayni bagi panelde kurdu. Mobilde bedeli daha agir: rol yalnizca
// menu doldurmaz, EKRAN SECER (`HomeGate`) ve yetkiyi belirler. Sunucu
// yeni bir rol eklerse ve bu enum guncellenmezse `fromClaim` sessizce
// `UserRole.unknown` doner — kullanici giris yapar ama uygulama onu
// TANIMAZ. P35'te tam bu sinif olculmustu: guvenlik amiri `HomeGate`in
// hicbir dalina uymayip splash'ta KILITLI kalmisti.
//
// `unknown` sunucuda YOKTUR ve olmamalidir: o, istemcinin "bu rolu
// bilmiyorum" demek icin kullandigi yerel bir degerdir. Bag onu bilerek
// disarida tutar ve bu istisna asagida GEREKCELIDIR.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';

/// `backend/app/models.py` icindeki `USER_ROLE = ENUM(...)` degerleri.
List<String> _sunucuRolleri() {
  final dosya = File('../backend/app/models.py');
  expect(dosya.existsSync(), isTrue, reason: 'models.py bulunamadi');
  final kaynak = dosya.readAsStringSync();
  final blok = RegExp(r'USER_ROLE = ENUM\(([\s\S]*?)name=').firstMatch(kaynak);
  expect(blok, isNotNull, reason: 'USER_ROLE blogu bulunamadi');
  final govde = blok!
      .group(1)!
      .split('\n')
      .where((l) => !RegExp(r'^\s*#').hasMatch(l)) // yorumlar deger degil
      .join('\n');
  return RegExp(r'"([a-z_]+)"')
      .allMatches(govde)
      .map((m) => m.group(1)!)
      .toList();
}

void main() {
  test('UserRole.wire degerleri = backend USER_ROLE degerleri', () {
    final sunucu = _sunucuRolleri()..sort();
    final istemci = UserRole.values
        .map((r) => r.wire)
        .where((w) => w != 'unknown') // yerel geri dusus; sunucuda yok
        .toList()
      ..sort();
    expect(istemci, sunucu);
  });

  test('`unknown` sunucuda YOKTUR (istisna gercekten istisna)', () {
    // Istisnanin kendisi de olculur: sunucuya bir gun `unknown` eklenirse
    // yukaridaki `where` gercek bir rolu sessizce eler ve bag korlesir.
    expect(_sunucuRolleri(), isNot(contains('unknown')));
  });
}
