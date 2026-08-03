/// Platform'a HİÇ dokunmayan video controller taklidi.
///
/// `kamera_oynatici_test.dart` içindeki özel taklitlerin PAYLAŞILAN hâli:
/// gerileme kilidi (`kamera_oynatma_gerileme_test.dart`) aynı davranışa
/// ihtiyaç duyuyor ve ikinci bir kopya, iki taklidin zamanla ayrışması
/// demekti.
library;

import 'dart:ui' show Size;
import 'package:video_player/video_player.dart';

class SahteVideoController extends VideoPlayerController {
  SahteVideoController({this.basarili = true})
      : super.networkUrl(Uri.parse('https://sahte/x.m3u8'));

  final bool basarili;

  /// `initialize()` çağrıldı mı (oynatıcı gerçekten kuruldu mu).
  bool hazirlandi = false;

  /// `dispose()` çağrıldı mı (sızıntı / erken atılma ölçümü).
  bool atildi = false;

  @override
  Future<void> initialize() async {
    hazirlandi = true;
    if (!basarili) throw Exception('yayına ulaşılamadı');
    value = value.copyWith(
      isInitialized: true,
      duration: const Duration(minutes: 1),
      size: const Size(1280, 720),
    );
  }

  @override
  Future<void> play() async => value = value.copyWith(isPlaying: true);

  @override
  Future<void> pause() async => value = value.copyWith(isPlaying: false);

  @override
  Future<void> setLooping(bool looping) async {}

  @override
  // super.dispose() PLATFORMA gider (sahtede kanal yok) — bilerek çağrılmaz.
  // ignore: must_call_super
  Future<void> dispose() async {
    atildi = true;
  }
}
