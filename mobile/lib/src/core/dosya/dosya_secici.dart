/// (P253 Asama 2) ORTAK DOSYA SECICI — telefondaki dosyalardan (PDF, gorsel).
///
/// Kullananlar: dokuman yukleme (bugun); Asama 3'te Excel ice aktarim ve
/// banka ekstresi. Paket (`file_picker` 13.1.0, arm64 APK +23,5 KB,
/// olculdu) TEK YERDEN cagrilir: ekranlar [DosyaSecici] arayuzunu kullanir,
/// testler [dosyaSeciciProvider]i taklitle degistirir.
///
/// UZANTI SUZGECI SUNUCU KURALIDIR: secici yalniz sunucunun kabul ettigi
/// turleri gosterir. Kabul etmeyecegi bir dosyayi sectirip yukleme
/// sonunda 422 dondurmek, kullaniciya bosa bekletmek olurdu.
library;

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Secilen dosya — bayt + ad + icerik turu.
class SecilenDosya {
  const SecilenDosya({required this.baytlar, required this.ad, required this.icerikTipi});
  final Uint8List baytlar;
  final String ad;
  final String icerikTipi;
}

/// Uzanti -> icerik turu. Bilinmeyen uzanti `application/octet-stream`.
const Map<String, String> uzantiTurleri = {
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'csv': 'text/csv',
};

String icerikTipiOf(String ad) {
  final nokta = ad.lastIndexOf('.');
  final uz = nokta < 0 ? '' : ad.substring(nokta + 1).toLowerCase();
  return uzantiTurleri[uz] ?? 'application/octet-stream';
}

abstract class DosyaSecici {
  /// Vazgecilirse null. [uzantilar] noktasiz ve kucuk harf (`pdf`).
  Future<SecilenDosya?> sec({required List<String> uzantilar});
}

class FilePickerSecici implements DosyaSecici {
  const FilePickerSecici();

  @override
  Future<SecilenDosya?> sec({required List<String> uzantilar}) async {
    final secilen = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: uzantilar);
    if (secilen.isEmpty) return null;
    final f = secilen.first;
    return SecilenDosya(baytlar: await f.readAsBytes(), ad: f.name, icerikTipi: icerikTipiOf(f.name));
  }
}

final dosyaSeciciProvider = Provider<DosyaSecici>((ref) => const FilePickerSecici());
