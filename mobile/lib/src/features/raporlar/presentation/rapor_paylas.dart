import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/ui/olustur_paylas.dart';
import '../domain/rapor_dosya_turu.dart';

/// Paylasim dikisi — testte sahtelenir (platform kanali ve gecici dizin
/// eklentisi yok). Uretimde sistem paylasimi + uygulamanin gecici dizini.
class RaporPaylasimDikisi {
  const RaporPaylasimDikisi({this.paylasici, this.geciciDizin});
  final Paylasici? paylasici;
  final Future<Directory> Function()? geciciDizin;
}

final raporPaylasimDikisiProvider = Provider<RaporPaylasimDikisi>(
  (_) => const RaporPaylasimDikisi(),
);


/// Baytlari ureten isi calistirir ve paylas menusunu acar.
Future<bool> raporuPaylas(
  BuildContext context,
  WidgetRef ref, {
  required Future<({Uint8List baytlar, String dosyaAdi})> Function() uret,
  String? konu,
}) {
  final dikis = ref.read(raporPaylasimDikisiProvider);
  Future<PaylasimDosyasi> olustur() async {
    final d = await uret();
    return PaylasimDosyasi(
      baytlar: d.baytlar,
      dosyaAdi: d.dosyaAdi,
      mimeTuru: raporMimeTuru(d.dosyaAdi),
    );
  }

  final paylasici = dikis.paylasici;
  final dizin = dikis.geciciDizin ?? getTemporaryDirectory;
  return paylasici == null
      ? olusturVePaylas(context, olustur: olustur, konu: konu, geciciDizin: dizin)
      : olusturVePaylas(
          context, olustur: olustur, konu: konu, paylasici: paylasici, geciciDizin: dizin);
}
