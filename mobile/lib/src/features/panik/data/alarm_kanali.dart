import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// (P249 §1c) SOS ALARM KOPRUSU — `site.yonetio.app/alarm`.
///
/// Android (`MainActivity.kt` + `AlarmBildirimi.kt`) ve iOS
/// (`AppDelegate.swift`) AYNI kanal adini ve yontemleri tasir.
///
///   * `sustur` — "Gordum"/"Guvendeyim"/"Gidiyorum" denince o alarmin
///     bildirimini kaldirir. Android'de alarm sesi DONGUDE calar
///     (`FLAG_INSISTENT`); bu cagri olmadan kullanici karar verdikten
///     sonra da calmaya devam ederdi.
///   * `acilisAlarmi` — uygulama alarm bildiriminden mi acildi (Android:
///     yerel bildirim FCM'in `getInitialMessage`ine dusmez).
///   * `izinDurumu` — tam ekran izni, Rahatsiz Etmeyin erisimi, kritik
///     uyari (iOS): "SOS alarm ayarlari" karti bunu cizer.
///
/// HATALAR YUTULUR: kopru yoksa (test, masaustu, eski yapim) alarm
/// akisi SUNUCU tarafinda aynen surer; kopru bir EKTIR.
class AlarmKanali {
  AlarmKanali([MethodChannel? kanal])
      : _kanal = kanal ?? const MethodChannel('site.yonetio.app/alarm') {
    _kanal.setMethodCallHandler((cagri) async {
      if (cagri.method == 'alarmAcildi' && cagri.arguments is String) {
        _acilanlar.add(cagri.arguments as String);
      }
    });
  }

  final MethodChannel _kanal;
  final _acilanlar = StreamController<String>.broadcast();

  /// Uygulama ACIKKEN alarm bildirimine dokunuldu (Android `onNewIntent`).
  Stream<String> get acilanAlarmlar => _acilanlar.stream;

  Future<void> sustur(String panikId) async {
    try {
      await _kanal.invokeMethod<void>('sustur', {'panikId': panikId});
    } catch (e) {
      debugPrint('Alarm susturulamadi (kopru yok?): $e');
    }
  }

  Future<String?> acilisAlarmi() async {
    try {
      final id = await _kanal.invokeMethod<String>('acilisAlarmi');
      return (id == null || id.isEmpty) ? null : id;
    } catch (_) {
      return null;
    }
  }

  Future<AlarmIzinDurumu?> izinDurumu() async {
    try {
      final m = await _kanal.invokeMapMethod<String, dynamic>('izinDurumu');
      return m == null ? null : AlarmIzinDurumu.fromMap(m);
    } catch (_) {
      return null;
    }
  }

  Future<void> tamEkranAyari() => _ac('tamEkranAyari');
  Future<void> dndAyari() => _ac('dndAyari');
  Future<void> kanalAyari() => _ac('kanalAyari');

  Future<void> _ac(String yontem) async {
    try {
      await _kanal.invokeMethod<void>(yontem);
    } catch (e) {
      debugPrint('Ayar ekrani acilamadi ($yontem): $e');
    }
  }
}

/// Cihazin SOS alarmi icin izin durumu. Platforma gore alanlarin bir kismi
/// anlamsizdir; `null` "bu platformda sorulmaz" demektir.
class AlarmIzinDurumu {
  const AlarmIzinDurumu({
    required this.platform,
    this.bildirimAcik,
    this.tamEkran,
    this.tamEkranSorulur = false,
    this.dndErisimi,
    this.kanalAcik,
    this.kritikUyari,
    this.zamanHassas,
  });

  final String platform;
  final bool? bildirimAcik;
  final bool? tamEkran;
  final bool tamEkranSorulur;
  final bool? dndErisimi;
  final bool? kanalAcik;
  final bool? kritikUyari;
  final bool? zamanHassas;

  bool get android => platform == 'android';

  factory AlarmIzinDurumu.fromMap(Map<String, dynamic> m) => AlarmIzinDurumu(
        platform: (m['platform'] as String?) ?? '',
        bildirimAcik: m['bildirimAcik'] as bool?,
        tamEkran: m['tamEkran'] as bool?,
        tamEkranSorulur: (m['tamEkranSorulur'] as bool?) ?? false,
        dndErisimi: m['dndErisimi'] as bool?,
        kanalAcik: m['kanalAcik'] as bool?,
        kritikUyari: m['kritikUyari'] as bool?,
        zamanHassas: m['zamanHassas'] as bool?,
      );
}

final alarmKanaliProvider = Provider<AlarmKanali>((ref) => AlarmKanali());

/// (P249 §1c) ALARM BILDIRIMINDEN ACILIS — acilacak alarm kimligi.
///
/// Iki kaynak: soguk acilis (`acilisAlarmi`, bir kez) ve uygulama acikken
/// dokunus (`acilanAlarmlar`). `main.dart` bunu dinleyip alarm ekranina
/// gider.
final alarmAcilisProvider = StreamProvider<String>((ref) async* {
  final kanal = ref.watch(alarmKanaliProvider);
  final ilk = await kanal.acilisAlarmi();
  if (ilk != null) yield ilk;
  yield* kanal.acilanAlarmlar;
});
