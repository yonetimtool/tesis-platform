/// TUR 34 — AG GORSELI TAKLIDI (`Image.network` testte gercekten yuklensin).
///
/// NEDEN: widget testinde `HttpClient` her istege **400** doner. Yani
/// `Image.network` HER ZAMAN hata dalina duser ve fotografli ekranlarin
/// GERCEK hali (yuklenmis gorsel + uzerindeki kaplamalar, kucuk resim
/// izgarasi, silme/yeniden-dene dugmeleri) hicbir suruste cizilmez. Tur 33
/// bu kor noktayi bulmustu: klavyeyle ulasilamayan alti oge yalnizca
/// fotografli veriyle ciziliyordu ve surus onlara hic ugramamisti.
///
/// SINIR: taklit gorsel 1x1 SAYDAM bir PNG'dir. "Fotograf uzerindeki metin"
/// kontrasti bu yolla OLCULEMEZ — gercek fotografin rengi keyfidir, sabit
/// bir renk secmek yanlis guven verirdi. Olculen sey: fotografli DUZENIN
/// kendisi (tasma, odak, semantik etiket, koyu tema).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1x1 saydam PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Test suresince tum `Image.network` istekleri 1x1 PNG ile yanitlanir.
/// `addTearDown` ile eski `HttpOverrides` geri konur.
void gorselTaklidi() {
  final eski = HttpOverrides.current;
  HttpOverrides.global = _TaklitOverrides();
  // `NetworkImage` izolasyon basina TEK bir PAYLASILAN HttpClient tutar ve
  // onu ILK kullanimda yaratir. Ayni dosyadaki daha onceki bir test gorsel
  // istediyse o istemci TAKLITSIZ dogmustur ve `HttpOverrides` sonradan
  // degisse bile artik kullanilmaz. Flutter'in test kancasi bu paylasilan
  // istemciyi ATLAR — tek basina gecip TAM SUITTE dusen surusun sebebi buydu.
  //
  // BU KANCA TEST GOVDESI BITMEDEN GERI ALINMALIDIR: cerceve, govde biter
  // bitmez `debugAssertAllPaintingVarsUnset` ile denetler ve `addTearDown`
  // O DENETIMDEN SONRA kosar. Bu yuzden kapatma [gorselTaklidiKapat] ile
  // ACIKCA yapilir (bkz. `fotografliSurus`in `finally`si).
  debugNetworkImageHttpClientProvider = () => _TaklitClient();
  // GORSEL ONBELLEGI IZOLASYON BOYUNCA ORTAKTIR. Ayni dosyadaki daha onceki
  // bir test ayni URL'yi taklit YOKKEN cizdiyse onbellekte BASARISIZ kayit
  // kalir; taklit kurulsa bile gorsel bir daha istenmez ve surus "fotograf
  // cizilmedi" ile duser. (Tek basina kosunca gecip TAM SUITTE dusmesinin
  // sebebi buydu — zamanlama degil, onbellek.)
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
  addTearDown(() {
    HttpOverrides.global = eski;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
}

/// [gorselTaklidi] kancasini geri alir — test govdesi bitmeden cagrilmalidir.
void gorselTaklidiKapat() {
  debugNetworkImageHttpClientProvider = null;
}

class _TaklitOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _TaklitClient();
}

class _TaklitClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _TaklitIstek();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _TaklitIstek();

  @override
  void close({bool force = false}) {}

  // Gorsel yuklemenin kullanmadigi her sey: sessizce gecistirilmez, bilerek
  // patlar — testin ag'a BASKA bir yoldan cikmadigini garanti eder.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('taklit HttpClient: ${invocation.memberName}');
}

class _TaklitIstek implements HttpClientRequest {
  @override
  final HttpHeaders headers = _TaklitBasliklar();

  @override
  Future<HttpClientResponse> close() async => _TaklitYanit();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TaklitBasliklar implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TaklitYanit extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _png.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(Uint8List.fromList(_png)).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
