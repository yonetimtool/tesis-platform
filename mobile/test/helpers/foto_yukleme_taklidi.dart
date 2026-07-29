/// TUR 39 — FOTOGRAF YUKLEME YOLU icin taklitler.
///
/// Tur 34 fotografi GOSTERMEYI olctu; YUKLEMEYI degil. Yukleme yolu uc ayri
/// durum cizer ve hicbiri surulmemisti:
///   * YUKLENIYOR — ilerleme gostergesi + dugmeler pasif,
///   * HATA — hata metni + "Tekrar yukle",
///   * YUKLENDI — onay ikonu + onizleme.
///
/// Bu dosya iki taklit verir: gercek bir dosya donduren [TaklitSecici] ve
/// yuklemeyi istege gore basaran / dusuren / ASKIDA BIRAKAN api davranisi
/// icin [YuklemeDavranisi].
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

/// 1x1 saydam PNG (gorsel taklidiyle ayni icerik).
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Testin suresince yasayan GERCEK bir dosya yolu dondurur.
///
/// `Image.file` yolu okur: sahte bir yol verirsek ekran hata dalina duser ve
/// "yuklendi" hali hic cizilmez. Bu yuzden gercek gecici dosya yazilir.
String taklitFotoDosyasi() {
  final dizin = Directory.systemTemp.createTempSync('surus_foto');
  final dosya = File('${dizin.path}/surus.png')..writeAsBytesSync(_png);
  addTearDown(() {
    if (dizin.existsSync()) dizin.deleteSync(recursive: true);
  });
  return dosya.path;
}

/// `ImagePicker` taklidi — kullanici hep ayni dosyayi secmis gibi davranir.
/// [iptal] true ise kullanici vazgecmis olur (secim yok).
class TaklitSecici implements ImagePicker {
  TaklitSecici(this.yol, {this.iptal = false});

  final String yol;
  final bool iptal;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async =>
      iptal ? null : XFile(yol);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('taklit secici: ${invocation.memberName}');
}

/// Yukleme api'sinin nasil davranacagi.
enum YuklemeDavranisi {
  /// Presign + PUT basarili → "yuklendi" hali.
  basarili,

  /// PUT hata verir → hata metni + "Tekrar yukle" hali.
  hata,

  /// PUT hic tamamlanmaz → "yukleniyor" hali (ilerleme gostergesi).
  askida,
}

/// [YuklemeDavranisi.askida] icin: hicbir zaman tamamlanmayan gelecek.
Future<T> askidaKal<T>() => Completer<T>().future;
