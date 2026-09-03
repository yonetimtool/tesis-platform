/// (P207 §2) KANAL KIMLIKLERI SUNUCU ILE MOBILDE AYNI MI?
///
/// ===========================================================================
/// BU KILIT NEDEN BURADA (BACKEND'DE DEGIL)
/// ===========================================================================
/// Ayni kilit `backend/tests/test_p207_push_kanal.py` icinde de var ama
/// orada mobil kaynak dosyalar YOK (api konteyneri yalniz backend'i
/// tasiyor) ve test kendini ATLIYOR. Flutter testleri ise depo kokunde
/// kosuyor: iki dosya da BURADA okunabiliyor.
///
/// ===========================================================================
/// AYRISMA NEDEN PAHALI
/// ===========================================================================
/// Kimlik ayrisirsa sunucu VAR OLMAYAN bir kanala gonderir. Android
/// bildirimi yine gosterir ama SESSIZ: yani kusur ekranda gorunmez,
/// yalnizca "sesli gelmesi gereken bildirim sessiz geldi" diye SAHADA
/// fark edilir.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `KANAL_KRITIK = "yonetio_kritik_v1"` gibi satirlardan degeri cikarir.
String? _pySabit(String kaynak, String ad) {
  final m = RegExp('$ad\\s*=\\s*"([^"]+)"').firstMatch(kaynak);
  return m?.group(1);
}

void main() {
  final backend = File('../backend/app/push_kanal.py');
  final kotlin = File(
    'android/app/src/main/kotlin/com/app/yonetiyor/MainActivity.kt',
  );
  final manifest = File('android/app/src/main/AndroidManifest.xml');

  test('KANAL KIMLIKLERI: sunucu ve mobil AYNI', () {
    expect(backend.existsSync(), isTrue, reason: 'backend kaynagi yok');
    expect(kotlin.existsSync(), isTrue, reason: 'MainActivity.kt yok');
    final py = backend.readAsStringSync();
    final kt = kotlin.readAsStringSync();

    for (final ad in ['KANAL_KRITIK', 'KANAL_GENEL', 'KANAL_SESSIZ']) {
      final deger = _pySabit(py, ad);
      expect(deger, isNotNull, reason: '$ad sunucuda bulunamadi');
      expect(kt.contains('"$deger"'), isTrue,
          reason: '$ad ($deger) MainActivity.kt icinde YOK');
    }
  });

  test('MANIFEST varsayilan kanali GENEL kanalla ayni', () {
    // Sunucu `channel_id` gondermezse (eski surum, teshis ucu) bildirim
    // Android'in isimsiz varsayilan kanalina duser ve SESSIZ olur.
    final genel = _pySabit(backend.readAsStringSync(), 'KANAL_GENEL');
    final xml = manifest.readAsStringSync();
    expect(xml.contains('default_notification_channel_id'), isTrue);
    expect(xml.contains(genel!), isTrue);
  });

  test('KANALLAR GERCEKTEN OLUSTURULUYOR (createNotificationChannel)', () {
    // FCM govdesindeki `channel_id` VAR OLAN bir kanali secer; kanali
    // OLUSTURMAZ. Olusturma satiri silinirse bildirimler yine sessiz
    // kalirdi ve kimlik karsilastirmasi bunu YAKALAYAMAZDI.
    final kt = kotlin.readAsStringSync();
    expect(kt.contains('createNotificationChannel'), isTrue);
    expect(RegExp('IMPORTANCE_HIGH').hasMatch(kt), isTrue,
        reason: 'kritik kanal IMPORTANCE_HIGH olmali');
    // SESSIZ kanalin sesi YOK: `setSound(null, null)`.
    expect(kt.contains('setSound(null, null)'), isTrue);
  });

  test('OZEL SES ADI iki tarafta AYNI', () {
    final py = backend.readAsStringSync();
    final ses = _pySabit(py, 'OZEL_SES_ADI');
    final kt = kotlin.readAsStringSync();
    expect(ses, isNotNull);
    expect(kt.contains('"$ses"'), isTrue,
        reason: 'ozel ses adi ($ses) MainActivity.kt ile ayrismis');
  });
}
