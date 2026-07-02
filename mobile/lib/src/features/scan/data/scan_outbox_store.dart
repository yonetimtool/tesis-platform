import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/outbox_entry.dart';

/// Outbox'in KALICI deposu — uygulama belgeler dizininde tek JSON dosyasi
/// (`scan_outbox.json`). Liste sirasi = FIFO sirasi.
///
/// Depo secimi gerekcesi (sqflite/hive/drift yerine dosya-tabanli JSON):
/// kuyruk kucuk (onlarca kayit), erisim tek-yazarli ve her degisimde tum
/// liste yazilir; iliskisel sorgu/indeks gerekmez. Dosya + atomik yeniden
/// adlandirma (once `.tmp`, sonra rename) yarim yazimda eski gecerli halin
/// korunmasini saglar. Ek native bagimlilik/codegen yuku yoktur;
/// shared_preferences ise buyukce listeler ve atomiklik icin uygun degildir.
class ScanOutboxStore {
  ScanOutboxStore({Future<File> Function()? resolveFile})
      : _resolveFile = resolveFile ?? _defaultFile;

  final Future<File> Function() _resolveFile;

  /// Yazimlari serilestiren kilit zinciri: eszamanli [save] cagrilari
  /// (enqueue + pump ayni anda persist edebilir) sirayla diske iner; aksi
  /// halde `.tmp` + rename adimlar birbirinin dosyasini kapabilir.
  Future<void> _writeLock = Future.value();

  static Future<File> _defaultFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/scan_outbox.json');
  }

  /// Kayitli kuyrugu yukler. Dosya yoksa bos liste; dosya bozuksa veri
  /// sessizce silinmez — `.corrupt` olarak kenara alinir ve bos donulur.
  Future<List<OutboxEntry>> load() async {
    final file = await _resolveFile();
    if (!await file.exists()) return const [];
    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final list = decoded['entries'] as List<dynamic>;
      return list
          .map((e) => OutboxEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('ScanOutboxStore: bozuk dosya, kenara aliniyor: $e');
      try {
        await file.rename('${file.path}.corrupt');
      } catch (_) {/* kenara alinamadiysa da uygulama acilabilsin */}
      return const [];
    }
  }

  /// Kuyrugun tamamini atomik yazar: once gecici dosyaya, sonra rename.
  /// Boylece yazim ortasinda kapanma/kilitlenme eski gecerli dosyayi bozamaz.
  /// Cagri anindaki liste aninda serilestirilir (snapshot), yazim ise kilit
  /// zinciri uzerinden sirayla yapilir.
  Future<void> save(List<OutboxEntry> entries) {
    final payload = jsonEncode({
      'version': 1,
      'entries': entries.map((e) => e.toJson()).toList(),
    });
    final write = _writeLock.then((_) => _write(payload));
    _writeLock = write.catchError((_) {/* zinciri kirma */});
    return write;
  }

  Future<void> _write(String payload) async {
    final file = await _resolveFile();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(payload, flush: true);
    await tmp.rename(file.path);
  }
}

final scanOutboxStoreProvider = Provider<ScanOutboxStore>((ref) {
  return ScanOutboxStore();
});
