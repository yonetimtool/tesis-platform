import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// (P249 §3b) SES KAYDI — basili tut, konus, birak.
///
/// Arayuz ince tutuldu: ekran yalniz "basla / bitir / iptal" bilir; testte
/// sahtelenir. Bicim sunucuyla AYNI: AAC (m4a), mono, 32 kbps — 60 sn
/// ~240 KB, sunucu 1 MB ustunu reddeder.
abstract class SesKaydedici {
  Future<bool> izinVarMi();
  Future<void> basla();

  /// Kaydi bitirir, ses baytlarini doner (bos ya da hata -> null).
  Future<Uint8List?> bitir();
  Future<void> iptal();
}

class RecordSesKaydedici implements SesKaydedici {
  final _kayit = AudioRecorder();
  String? _yol;

  @override
  Future<bool> izinVarMi() => _kayit.hasPermission();

  @override
  Future<void> basla() async {
    final dizin = await getTemporaryDirectory();
    _yol = '${dizin.path}/sesli-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _kayit.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 22050,
        numChannels: 1,
      ),
      path: _yol!,
    );
  }

  @override
  Future<Uint8List?> bitir() async {
    final yol = await _kayit.stop() ?? _yol;
    if (yol == null) return null;
    final dosya = File(yol);
    if (!await dosya.exists()) return null;
    final baytlar = await dosya.readAsBytes();
    // GECICI DOSYA SILINIR: ses kisisel veridir; cihazda kopyasi kalmasin.
    await dosya.delete();
    return baytlar.isEmpty ? null : baytlar;
  }

  @override
  Future<void> iptal() async {
    await _kayit.cancel();
  }
}

final sesKaydediciProvider = Provider<SesKaydedici>((ref) => RecordSesKaydedici());
