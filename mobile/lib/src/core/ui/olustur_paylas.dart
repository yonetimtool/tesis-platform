/// (P253 §B, plan §2.3) "OLUSTUR VE PAYLAS" — rapor, makbuz, ekstre, PDF.
///
/// Telefonda "indir" bir dosyayi bir klasore birakip unutturur; dogru hareket
/// dosyayi olusturup sistem PAYLAS menusunu acmak (WhatsApp, e-posta,
/// Drive, Dosyalar). Ayni bilesen makbuz PDF'i, tatbikat raporu, karar PDF'i
/// ve rapor Excel'i icin kullanilir.
///
/// AKIS: ilerleme penceresi -> `olustur()` baytlari getirir -> gecici
/// dizine yazilir -> paylas menusu. Hata kullaniciya cumleyle soylenir
/// (sessiz dusme yok); iptal (kullanici menuyu kapatti) hata DEGILDIR.
///
/// BAGIMLILIK: `share_plus` (BSD-3). Boyut olcumu `docs/P253-kararlar.md`.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../i18n/l10n.dart';

class PaylasimDosyasi {
  const PaylasimDosyasi({
    required this.baytlar,
    required this.dosyaAdi,
    required this.mimeTuru,
  });

  final Uint8List baytlar;

  /// Yalniz ad (yol degil). Ayirac ve `..` temizlenir.
  final String dosyaAdi;
  final String mimeTuru;
}

/// Paylasimi yapan dikis — testte sahtelenir (platform kanali yok).
typedef Paylasici = Future<void> Function(XFile dosya, String? konu, Rect? konum);

Future<void> _sistemPaylasimi(XFile dosya, String? konu, Rect? konum) async {
  await SharePlus.instance.share(ShareParams(
    files: [dosya],
    subject: konu,
    sharePositionOrigin: konum,
  ));
}

/// Gecici dosya adi: dizin ayiraci ve ust dizin atlamasi kaldirilir.
String guvenliDosyaAdi(String ad) {
  final temiz = ad.replaceAll(RegExp(r'[\\/]'), '_').replaceAll('..', '_').trim();
  return temiz.isEmpty ? 'dosya' : temiz;
}

/// Dosyayi olusturur ve paylas menusunu acar. Basariliysa `true`.
Future<bool> olusturVePaylas(
  BuildContext context, {
  required Future<PaylasimDosyasi> Function() olustur,
  String? konu,
  Paylasici paylasici = _sistemPaylasimi,
  Future<Directory> Function() geciciDizin = getTemporaryDirectory,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  // iPad paylas menusu bir CIKIS NOKTASI ister; yoksa cokuyor.
  final kutu = context.findRenderObject() as RenderBox?;
  final konum = kutu == null ? null : kutu.localToGlobal(Offset.zero) & kutu.size;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        key: const Key('paylas-hazirlaniyor'),
        content: Row(
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: 16),
            Expanded(child: Text(l10n.paylasHazirlaniyor)),
          ],
        ),
      ),
    ),
  );

  XFile? dosya;
  try {
    final d = await olustur();
    final dizin = await geciciDizin();
    final yol = '${dizin.path}/${guvenliDosyaAdi(d.dosyaAdi)}';
    await File(yol).writeAsBytes(d.baytlar, flush: true);
    dosya = XFile(yol, mimeType: d.mimeTuru, name: guvenliDosyaAdi(d.dosyaAdi));
  } catch (_) {
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(l10n.paylasHata)));
    return false;
  }
  navigator.pop();
  try {
    await paylasici(dosya, konu, konum);
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.paylasHata)));
    return false;
  }
  return true;
}
