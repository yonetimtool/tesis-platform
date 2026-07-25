import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../domain/camera_models.dart';

/// Tam ekran canli yayin oynatici — HLS (`.m3u8`) ve MP4 icin.
///
/// PAKET KARARI: `video_player` (Flutter takim paketi) TEK BASINA kullanilir;
/// `chewie` EKLENMEDI. Gerekce: ihtiyacimiz olan kontrol seti kucuk
/// (oynat/durdur + hata + yeniden dene + yatay) ve chewie kendi tasarim
/// dilini (materyal kontrol cubugu, kendi renkleri) getirir — onaylanmis ana
/// ekran dilini bozar; ayrica ek bir bagimlilik yuzeyi olur. HLS her iki
/// platformda PLATFORM oynaticiyla calisir (Android ExoPlayer, iOS
/// AVPlayer) — ek yapilandirma gerektirmez.
///
/// RTSP bu ekrana HIC GELMEZ: sunucu `oynatilabilir=false` isaretler ve kart
/// dokunmasi bilgi kartini acar (bkz. [CameraBilgiSheet]).
class CameraPlayerScreen extends StatefulWidget {
  const CameraPlayerScreen({
    super.key,
    required this.kamera,
    @visibleForTesting this.controllerYapici,
  });

  final Camera kamera;

  /// Controller uretimi TESTTE degistirilebilir: widget testinde platform
  /// oynaticisi (ExoPlayer/AVPlayer) yoktur, `initialize()` yanit vermez.
  /// Uretimde null → [VideoPlayerController.networkUrl].
  final VideoPlayerController Function(Camera kamera)? controllerYapici;

  @override
  State<CameraPlayerScreen> createState() => _CameraPlayerScreenState();
}

class _CameraPlayerScreenState extends State<CameraPlayerScreen> {
  VideoPlayerController? _controller;

  /// Hata metni (null → hata yok). Ayri alan: controller ATILDIGINDA da
  /// mesaj ekranda kalsin.
  String? _hata;
  bool _hazirlaniyor = true;

  @override
  void initState() {
    super.initState();
    // Yatay izleme: bu ekran acikken her yon serbest (uygulama genelinde
    // dikey kilit varsa burada gecici olarak acilir), cikista geri alinir.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _baslat();
  }

  Future<void> _baslat() async {
    setState(() {
      _hazirlaniyor = true;
      _hata = null;
    });
    // Yeniden denemede ONCEKI controller atilir (sizinti yok).
    final eski = _controller;
    _controller = null;
    eski?.removeListener(_controllerDegisti);
    await eski?.dispose();

    final c = widget.controllerYapici?.call(widget.kamera) ??
        VideoPlayerController.networkUrl(Uri.parse(widget.kamera.streamUrl));
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setLooping(true);
      await c.play();
      c.addListener(_controllerDegisti);
      setState(() {
        _controller = c;
        _hazirlaniyor = false;
      });
    } catch (_) {
      await c.dispose();
      if (!mounted) return;
      setState(() {
        _controller = null;
        _hazirlaniyor = false;
        _hata = 'Yayın açılamadı';
      });
    }
  }

  /// Oynat/durdur. `setState` KULLANILMAZ: durum degisimini controller'in
  /// KENDISI bildirir ([_controllerDegisti]) — boylece platformdan gelen
  /// duraklama/tamponlama da ekrana yansir. (Ayrica `setState`'e Future donen
  /// bir geri cagrim vermek Flutter'da assertion hatasidir.)
  void _oynatDurdur() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
  }

  /// Controller degeri degisti (oynuyor/duraklatildi/tamponluyor) → yeniden ciz.
  void _controllerDegisti() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // Controller HER durumda atilir (hata/erken cikis dahil).
    _controller?.removeListener(_controllerDegisti);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.kamera.ad),
        // Konum varsa baslik altinda ikinci satir (kart ile ayni bilgi).
        bottom: widget.kamera.konum == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(18),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    widget.kamera.konum!,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
      ),
      body: Center(child: _govde(c)),
    );
  }

  Widget _govde(VideoPlayerController? c) {
    if (_hata != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined,
                color: Colors.white54, size: 44),
            const SizedBox(height: 12),
            Text(
              _hata!,
              key: const Key('kamera-hata'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kamera kapalı olabilir ya da ağ yayına ulaşamıyor.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _baslat,
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden dene'),
            ),
          ],
        ),
      );
    }
    if (c == null || _hazirlaniyor || !c.value.isInitialized) {
      return const CircularProgressIndicator(key: Key('kamera-yukleniyor'));
    }
    // Dokunma yuzeyi TUM govdedir (yalniz video dikdortgeni degil): siyah
    // kenarlara dokunmak da oynat/durdur yapar — telefonda yatay izlerken
    // video ekranin ortasinda kucuk bir seride dusebilir.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _oynatDurdur,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio:
                  c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
          ),
          // Duraklatildiginda buyuk oynat ikonu (dokun → devam).
          if (!c.value.isPlaying)
            const DecoratedBox(
              decoration:
                  BoxDecoration(color: Color(0x8C000000), shape: BoxShape.circle),
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.play_arrow, color: Colors.white, size: 40),
              ),
            ),
        ],
      ),
    );
  }
}

/// RTSP (oynatilamayan) kamera icin bilgi karti — oynatici YERINE acilir.
class CameraBilgiSheet extends StatelessWidget {
  const CameraBilgiSheet({super.key, required this.kamera});

  final Camera kamera;

  static Future<void> ac(BuildContext context, Camera kamera) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => CameraBilgiSheet(kamera: kamera),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metin = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kamera.ad, style: metin.titleMedium),
            if (kamera.konum != null) ...[
              const SizedBox(height: 4),
              Text(kamera.konum!, style: metin.bodyMedium),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.videocam_off_outlined, size: 20),
                const SizedBox(width: 8),
                Text('Tür: ${kamera.tur.label}', style: metin.bodyMedium),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'RTSP yayınlar şu an uygulama içinde oynatılamıyor. Kayıt '
              'sistemde tutuluyor; oynatma desteği ileride eklenecek.',
              style: metin.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
