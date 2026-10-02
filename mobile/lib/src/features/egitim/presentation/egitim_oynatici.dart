/// (P250 §4) Eğitim videosu OYNATICISI — YouTube IFrame API.
///
/// PAKET: `youtube_player_iframe`. Seçim gerekçesi:
///   * YouTube'un RESMÎ IFrame Player API'sini bir WebView içinde çalıştırır;
///     `ENDED` dahil oynatıcı durumları Dart akışına gelir — "video bitince
///     izlendi" ancak bu olayla yapılabilir.
///   * `privacyEnhancedMode`: oynatıcı `youtube-nocookie.com` üzerinden
///     yerleşir (web ile aynı gizlilik kararı, KVKK).
///   * Cihaz yatay çevrilince TAM EKRAN (paket içi, `autoFullScreen`).
///   * Oynatıcı hata kodlarını (100/101/150) ayrı verir: gizli ya da
///     yerleştirmesi kapalı video anlaşılır uyarıyla gösterilir.
/// Alternatif `youtube_player_flutter` aynı iş için eski bir oynatıcı
/// sarmalayıcısı kullanıyor ve nocookie seçeneği yok.
///
/// SOYUTLAMA: test ortamında WebView yok. Ekran oynatıcıyı bir SAĞLAYICI
/// üzerinden kurar; testler sahte bir kurucu verir ve `ENDED`/hata
/// olaylarını elle tetikler.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// `kapali`: gizli / silinmiş / yerleştirmeye kapalı (100, 101, 150).
/// `genel`: diğer oynatıcı hataları. `erisilemiyor`: YouTube'a ulaşılamadı.
typedef OynaticiHatasi = String;

typedef OynaticiKurucu =
    Widget Function({
      required String videoId,
      required VoidCallback onBitti,
      required void Function(OynaticiHatasi tur) onHata,
    });

final egitimOynaticiProvider = Provider<OynaticiKurucu>(
  (ref) =>
      ({required videoId, required onBitti, required onHata}) =>
          _YoutubeOynatici(
            key: ValueKey(videoId),
            videoId: videoId,
            onBitti: onBitti,
            onHata: onHata,
          ),
);

class _YoutubeOynatici extends StatefulWidget {
  const _YoutubeOynatici({
    super.key,
    required this.videoId,
    required this.onBitti,
    required this.onHata,
  });

  final String videoId;
  final VoidCallback onBitti;
  final void Function(OynaticiHatasi tur) onHata;

  @override
  State<_YoutubeOynatici> createState() => _YoutubeOynaticiState();
}

class _YoutubeOynaticiState extends State<_YoutubeOynatici> {
  late final YoutubePlayerController _ktrl =
      YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        params: const YoutubePlayerParams(
          privacyEnhancedMode: true,
          // Videonun sonunda başka kanalların önerileri olmasın (rel=0'ın
          // paketteki karşılığı: öneriler yalnız aynı kanaldan).
          strictRelatedVideos: true,
          showFullscreenButton: true,
          playsInline: true,
        ),
      );
  StreamSubscription<YoutubePlayerValue>? _abone;
  PlayerState? _onceki;
  Timer? _zaman;

  @override
  void initState() {
    super.initState();
    // YOUTUBE ERISILEMIYORSA (ag kisitli): oynatici hic hazir olmaz ve
    // hata da uretmez. Bu surede hicbir durum gelmezse anlasilir mesaj.
    _zaman = Timer(const Duration(seconds: 15), () {
      if (_onceki == null || _onceki == PlayerState.unknown) {
        widget.onHata('erisilemiyor');
      }
    });
    _abone = _ktrl.stream.listen((v) {
      if (v.playerState == PlayerState.ended && _onceki != PlayerState.ended) {
        widget.onBitti();
      }
      _onceki = v.playerState;
      if (v.error != YoutubeError.none) {
        final kapali =
            v.error == YoutubeError.videoNotFound ||
            v.error == YoutubeError.notEmbeddable ||
            v.error == YoutubeError.sameAsNotEmbeddable ||
            v.error == YoutubeError.sameAsNotEmbeddable2;
        widget.onHata(kapali ? 'kapali' : 'genel');
      }
    });
  }

  @override
  void dispose() {
    _zaman?.cancel();
    _abone?.cancel();
    _ktrl.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => YoutubePlayer(controller: _ktrl);
}
