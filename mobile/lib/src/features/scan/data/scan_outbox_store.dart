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
  /// (enqueue + pump ayni anda persist edebilir) sirayla diske iner.
  ///
  /// Kilit ORNEK BASINADIR. Iki ornek ayni dosyaya yazarsa kilitler ayridir —
  /// eskiden bu bir VERI KAYBI yariciydi (asagidaki [_tmpDosya] notuna bakin);
  /// artik en kotu ihtimalle "son yazan kazanir" olur.
  Future<void> _writeLock = Future.value();

  /// Bu ORNEGE ozgu gecici dosya sayaci — bkz. [_tmpDosya].
  int _tmpSayac = 0;

  /// Ornek kimligi: ayni surecte iki store ayni tmp adini SECEMESIN.
  static int _ornekSayaci = 0;
  final int _ornekNo = ++_ornekSayaci;

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
      } catch (_) {
        /* kenara alinamadiysa da uygulama acilabilsin */
      }
      return const [];
    }
  }

  /// Kuyrugun tamamini atomik yazar: once gecici dosyaya, sonra rename.
  /// Boylece yazim ortasinda kapanma/kilitlenme eski gecerli dosyayi bozamaz.
  /// Cagri anindaki liste aninda serilestirilir (snapshot), yazim ise kilit
  /// zinciri uzerinden sirayla yapilir.
  /// [gecerliMi] verilirse yazim SIRAYA GIRDIKTEN sonra, dosyaya TASINMADAN
  /// hemen once bir kez daha sorulur. `false` donerse yazim IPTAL edilir
  /// (gecici dosya silinir, hedef dosyaya DOKUNULMAZ).
  ///
  /// NEDEN (P10): kilit zinciri yuzunden bir `save` cagrisi, cagiran kuyruk
  /// kapandiktan cok sonra diske inebilir. O an dosya artik YENI kuyrugundur;
  /// bayat veriyi uzerine yazmak kayit kaybettirir. Iptal kancasi bu
  /// "hayalet yazar"i kesin olarak durdurur — cagiranin `_persist()`
  /// basindaki denetimi TEK BASINA yetmez, cunku o denetim yazim SIRAYA
  /// GIRMEDEN once yapilir.
  Future<void> save(List<OutboxEntry> entries, {bool Function()? gecerliMi}) {
    final payload = jsonEncode({
      'version': 1,
      'entries': entries.map((e) => e.toJson()).toList(),
    });
    final write = _writeLock.then((_) => _write(payload, gecerliMi));
    _writeLock = write.catchError((_) {
      /* zinciri kirma */
    });
    return write;
  }

  Future<void> _write(String payload, [bool Function()? gecerliMi]) async {
    final file = await _resolveFile();
    final tmp = _tmpDosya(file);
    await tmp.writeAsString(payload, flush: true);
    if (gecerliMi != null && !gecerliMi()) {
      // Iptal: hedef dosyaya DOKUNMA, gecici dosyayi topla.
      try {
        await tmp.delete();
      } catch (_) {
        /* zaten yoksa sorun degil */
      }
      return;
    }
    await tmp.rename(file.path);
  }

  /// TEKIL gecici dosya adi — ayni dizine yazan HER YAZIM kendi `.tmp`sini
  /// kullanir.
  ///
  /// NEDEN (P10, olculdu): eski surum sabit `<dosya>.tmp` kullaniyordu. Ayni
  /// dosyaya yazan iki ornek (uygulamada oturum degisiminde, testte "yeni
  /// oturum" senaryosunda) SIRAYLA degil IC ICE calisir ve su dizilim
  /// olusur:
  ///
  ///   A: tmp.write(veriA)
  ///   B: tmp.write(veriB)      <- A'nin tmp'sini EZER
  ///   A: tmp.rename(dosya)     <- dosyaya B'NIN verisi yazilir (A sanir)
  ///   B: tmp.rename(dosya)     <- tmp artik yok: PathNotFoundException
  ///
  /// Yani ya SESSIZ VERI KAYBI (kuyruktan kayit dusuyordu) ya da yutulan bir
  /// istisna. Stres kosumunda ikisi de gozlendi. Tekil ad ile iki yazim
  /// birbirinin gecicisine dokunamaz; `rename` POSIX'te atomik oldugu icin
  /// dosya her an GECERLI bir surumdedir — yalnizca hangi surum oldugu
  /// zamanlamaya baglidir ("son yazan kazanir"), ki tek-yazarli normal
  /// kullanimda bu durum zaten olusmaz.
  File _tmpDosya(File file) =>
      File('${file.path}.$_ornekNo-${_tmpSayac++}.tmp');
}

final scanOutboxStoreProvider = Provider<ScanOutboxStore>((ref) {
  return ScanOutboxStore();
});
