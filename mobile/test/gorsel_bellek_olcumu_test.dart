/// TUR 67 — GORSEL BELLEGININ GERCEK OLCUMU.
///
/// Ucuncu envanterin son acik kalemi: "Tur 61 cozme sinirini KODDA kilitledi;
/// gercek bir buyuk fotografla BELLEK olcumu yapilmadi (widget testinde taklit
/// gorsel minik PNG)." Envantere "gercek cihaz gerekir" diye yazmistim —
/// **yanlisti**. Cozme SUREC ICINDE olculebiliyor: Flutter'in gorsel onbellegi
/// (`PaintingBinding.instance.imageCache.currentSizeBytes`) cozulen goruntunun
/// KAC BAYT tuttugunu bildiriyor.
///
/// Iki engel vardi, ikisi de asildi:
///   1. `Picture.toImage` ile buyuk PNG uretmek BASSIZ testte kilitleniyor
///      (rasterizer yok). Cozum: PNG'yi ELLE kodlamak — IHDR + zlib IDAT +
///      IEND; rasterizer gerekmez, gercek COZUCU calisir.
///   2. Cozme `runAsync` icinde yapilmali; sahte zamanda gorsel akisi hic
///      tamamlanmiyor.
///
/// OLCULEN GERCEK (1200x800 tek renk PNG, 4,5 KB dosya):
///   ham cozum       : 3 840 000 bayt  (1200 * 800 * 4)
///   96x64 sinirli   :    24 576 bayt
/// Yani sinir **156 kat** bellek tasarrufu sagliyor. Tur 61 bunu yalnizca
/// "ResizeImage kuruldu mu" diye dogruluyordu; artik TASARRUF olculuyor.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/ui/gorsel_cozme.dart';

/// ELLE PNG kodlayici (rasterizer gerekmez).
///
/// Tek renk satir bir kez kurulup [y] kez tekrarlanir: piksel basina liste
/// ekleme yapan ilk surum 1200x800'de test SUREsini asiyordu.
Uint8List pngUret(int g, int y) {
  final satir = Uint8List(1 + g * 3)..[0] = 0; // filtre: none
  for (var x = 0; x < g; x++) {
    satir[1 + x * 3] = 0x33;
    satir[2 + x * 3] = 0x66;
    satir[3 + x * 3] = 0xAA;
  }
  final ham = Uint8List(satir.length * y);
  for (var s = 0; s < y; s++) {
    ham.setRange(s * satir.length, (s + 1) * satir.length, satir);
  }
  final sikistirilmis = ZLibCodec().encode(ham);

  Uint8List parca(String tur, List<int> veri) {
    final govde = <int>[...tur.codeUnits, ...veri];
    return Uint8List.fromList([
      ..._u32(veri.length),
      ...govde,
      ..._u32(_crc32(govde)),
    ]);
  }

  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG imzasi
    ...parca('IHDR', [..._u32(g), ..._u32(y), 8, 2, 0, 0, 0]), // 8-bit RGB
    ...parca('IDAT', sikistirilmis),
    ...parca('IEND', const []),
  ]);
}

List<int> _u32(int v) => [
  (v >> 24) & 0xFF,
  (v >> 16) & 0xFF,
  (v >> 8) & 0xFF,
  v & 0xFF,
];

int _crc32(List<int> veri) {
  var crc = 0xFFFFFFFF;
  for (final b in veri) {
    crc ^= b;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

/// [saglayici]yi COZ ve onbellekte kac bayt tuttugunu dondur.
Future<int> cozulenBayt(WidgetTester tester, ImageProvider saglayici) async {
  final onbellek = PaintingBinding.instance.imageCache;
  onbellek.clear();
  onbellek.clearLiveImages();
  // Tavan olcumu bozmasin (varsayilan 100 MB; buyuk gorsel sigmali).
  onbellek.maximumSizeBytes = 300 << 20;
  // `runAsync` SART: sahte zamanda gorsel akisi hic tamamlanmaz.
  await tester.runAsync(() async {
    final akis = saglayici.resolve(ImageConfiguration.empty);
    final tamam = Completer<void>();
    akis.addListener(
      ImageStreamListener(
        (_, _) => tamam.complete(),
        onError: (e, _) => tamam.completeError(e),
      ),
    );
    await tamam.future;
  });
  return onbellek.currentSizeBytes;
}

void main() {
  const g = 1200, y = 800;
  late Uint8List png;

  setUpAll(() => png = pngUret(g, y));

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets('HAM cozum: genislik * yukseklik * 4 bayt tutar', (tester) async {
    final bayt = await cozulenBayt(tester, MemoryImage(png));
    expect(bayt, g * y * 4,
        reason: 'sinirsiz cozum tam cozunurlukte RGBA tutar');
    // Dosya 5 KB'in altinda ama BELLEKTE ~3,8 MB: sikistirilmis boyut
    // aldatici. Kod okumakla degil OLCUMLE gorulur.
    expect(png.length, lessThan(20 * 1024));
  });

  testWidgets('SINIRLI cozum: 96x64 -> ~24 KB (156 kat tasarruf)', (
    tester,
  ) async {
    final ham = await cozulenBayt(tester, MemoryImage(png));
    final sinirli = await cozulenBayt(
      tester,
      ResizeImage(MemoryImage(png), width: 96, height: 64),
    );
    expect(sinirli, 96 * 64 * 4);
    expect(sinirli * 100, lessThan(ham),
        reason: 'sinir en az 100 kat tasarruf saglamali (olculen ~156)');
  });

  testWidgets('URUN YARDIMCISI: `sinirliGorsel` gercekten bellegi sinirlar', (
    tester,
  ) async {
    // Tur 61'in yardimcisi: avatar boyutu (56 dp) ile sarilmis saglayici.
    late ImageProvider sarilmis;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 2),
        child: Builder(
          builder: (context) {
            sarilmis = sinirliGorsel(context, MemoryImage(png), 56);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    final bayt = await cozulenBayt(tester, sarilmis);
    // 56 dp * dpr 2 = 112 px kare.
    expect(bayt, 112 * 112 * 4);
    expect(bayt, lessThan(g * y * 4 ~/ 50),
        reason: 'avatar icin ham cozumun ellide birinden az bellek');
  });

  testWidgets('cacheWidth ile `Image.memory` de sinirlanir', (tester) async {
    // `Image.network(..., cacheWidth:)` iceride `ResizeImage` uretir; ayni
    // mekanizma `Image.memory` icin de gecerli — urun kodundaki 17 cagrinin
    // dayandigi mekanizma boyle DAVRANISSAL olarak dogrulanir.
    late ImageProvider saglayici;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 1),
        child: Builder(
          builder: (context) {
            final w = Image.memory(png, cacheWidth: cozmeSiniri(context, 96));
            saglayici = w.image;
            return w;
          },
        ),
      ),
    );
    expect(saglayici, isA<ResizeImage>());
    final bayt = await cozulenBayt(tester, saglayici);
    // Yalniz genislik verildiginde yukseklik oran korunarak kuculur:
    // 1200x800 -> 96x64.
    expect(bayt, 96 * 64 * 4);
  });

  testWidgets('SINIRSIZ birakilirsa tasarruf YOK (gerekce nobetcisi)', (
    tester,
  ) async {
    // Kural gercekten gerekli mi? Sinirsiz saglayici tam cozunurluk tutuyorsa
    // evet. Bu test, tasarruf iddiasinin GEREKCESIDIR.
    final sinirsiz = await cozulenBayt(tester, MemoryImage(png));
    expect(sinirsiz, greaterThan(3 * 1024 * 1024),
        reason: '1200x800 sinirsiz cozum 3 MB ustu tutar');
  });
}
