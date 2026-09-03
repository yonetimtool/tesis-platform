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

/// Yorumlari atar — kural KODA dairdir. (Aciklama satirlarinda gecen
/// `getIdentifier` kelimesi, "kod getIdentifier kullaniyor" demek degil;
/// ilk yazimda test tam da bu yuzden yanlis yere kirmizi oldu.)
String _kodSadece(String kaynak) => kaynak
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), ' ')
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

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

    // (P208 §2) `KANAL_GURULTU` EKLENDI: gurultu uyarisinin kendi
    // kanali/sesi var (Android'de "ayni kanaldan farkli ses" yok).
    for (final ad in [
      'KANAL_KRITIK',
      'KANAL_GENEL',
      'KANAL_SESSIZ',
      'KANAL_GURULTU',
      // (P210) Vardiya hatirlatmasinin kendi kanali.
      'KANAL_VARDIYA',
    ]) {
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

  test('OZEL SES ADLARI iki tarafta AYNI', () {
    final py = backend.readAsStringSync();
    final kt = kotlin.readAsStringSync();
    for (final ad in ['OZEL_SES_ADI', 'GURULTU_SES_ADI', 'VARDIYA_SES_ADI']) {
      final ses = _pySabit(py, ad);
      expect(ses, isNotNull, reason: '$ad sunucuda yok');
      expect(kt.contains('"$ses"'), isTrue,
          reason: 'ses adi ($ses) MainActivity.kt ile ayrismis');
    }
  });

  test('(P210) SES DOSYALARI PAKETTE VAR', () {
    // `SES_HAZIR=True` demek "dosyalar var" demek. Dosya yoksa Android
    // sessizce sistem sesine duser (kod `getIdentifier`la ariyor) ve
    // iOS bildirimi SESSIZ calar — ikisi de ancak cihazda fark edilir.
    final py = File('../backend/app/push_kanal.py').readAsStringSync();
    expect(RegExp(r'SES_HAZIR\s*=\s*True').hasMatch(py), isTrue,
        reason: 'SES_HAZIR kapali ama dosyalar bekleniyor');
    for (final ad in ['OZEL_SES_ADI', 'GURULTU_SES_ADI', 'VARDIYA_SES_ADI']) {
      final ses = _pySabit(py, ad)!;
      expect(File('android/app/src/main/res/raw/$ses.ogg').existsSync(), isTrue,
          reason: 'Android ses dosyasi yok: $ses.ogg');
      expect(File('ios/Runner/$ses.caf').existsSync(), isTrue,
          reason: 'iOS ses dosyasi yok: $ses.caf');
    }
  });

  test('(P210) SESLER STATIK R.raw ILE — getIdentifier KUCULTUCUYE YEM', () {
    // OLCULEN KUSUR: dosyalar `res/raw/`e konuldu, release yapimi
    // sorunsuz gecti, AMA APK'DA YOKTULAR. Release'te KAYNAK KUCULTUCU
    // calisiyor ve `resources.getIdentifier(...)` bir CALISMA ZAMANI
    // dizgi aramasidir — kucultucu goremez, dosyalari "kullanilmiyor"
    // sayip atar. Kanit: `aapt2 dump resources` ciktisinda `raw` tipi
    // HIC YOKTU.
    //
    // Sessiz kusur: kod calisir, kanal olusur, bildirim gelir — yalniz
    // SES SISTEM SESIDIR. Ancak cihazda, kulakla fark edilir.
    final kt = _kodSadece(kotlin.readAsStringSync());
    expect(kt.contains('R.raw.yonetio_bildirim'), isTrue);
    expect(kt.contains('R.raw.yonetio_gurultu'), isTrue);
    expect(kt.contains('R.raw.yonetio_vardiya'), isTrue);
    expect(kt.contains('getIdentifier'), isFalse,
        reason: 'getIdentifier geri geldi: kucultucu sesleri APK\'dan atar');
  });

  test('(P210) KANAL KIMLIKLERI SURUMLU ve ESKI KUSAK SILINIYOR', () {
    // Android'de var olan kanalin sesi degistirilemez: ses eklenince
    // kimlik de degismeli, yoksa guncelleyen kullanicida ESKI (sessiz)
    // kanal kalir. Eski kusak silinmezse ayar ekraninda ayni ada sahip
    // IKI satir gorunur.
    final kt = kotlin.readAsStringSync();
    expect(kt.contains('"yonetio_kritik_v1"') &&
        kt.contains('deleteNotificationChannel'), isTrue,
        reason: 'eski _v1 kanallari silinmiyor');
    final py = backend.readAsStringSync();
    for (final ad in [
      'KANAL_KRITIK', 'KANAL_GENEL', 'KANAL_SESSIZ',
      'KANAL_GURULTU', 'KANAL_VARDIYA',
    ]) {
      expect(_pySabit(py, ad), endsWith('_v2'),
          reason: '$ad surumu yukseltilmemis');
    }
    // Manifest varsayilani da GENEL kanalla ayni surumde olmali.
    expect(manifest.readAsStringSync().contains(_pySabit(py, 'KANAL_GENEL')!),
        isTrue);
  });

  test('(P208/P210) HER OZEL KANAL KENDI SESIYLE olusturuluyor', () {
    // Kanal kimligi ayni olsa bile SES BAGLANMAMISSA bildirim kritik
    // kanaldan farksiz calar; kimlik karsilastirmasi bunu yakalamaz.
    final kt = kotlin.readAsStringSync();
    expect(kt.contains('setSound(sesUri(SES_GURULTU)'), isTrue,
        reason: 'gurultu kanalina kendi sesi baglanmamis');
    expect(kt.contains('setSound(sesUri(SES_VARDIYA)'), isTrue,
        reason: 'vardiya kanalina kendi sesi baglanmamis');
    expect(kt.contains('setSound(sesUri(SES_BILDIRIM)'), isTrue,
        reason: 'kritik kanala kendi sesi baglanmamis');
    final py = backend.readAsStringSync();
    for (final ad in ['GURULTU_SES_ADI', 'VARDIYA_SES_ADI']) {
      expect(kt.contains('"${_pySabit(py, ad)}"'), isTrue);
    }
  });
}
