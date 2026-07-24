import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../domain/camera_models.dart';

/// Tam ekran canli yayin (WP-F MVP) — HLS/MJPEG URL'sini oynatir.
/// Baglanti kurulamazsa kullaniciya acik mesaj (cokme yok).
class CameraPlayerScreen extends StatefulWidget {
  const CameraPlayerScreen({super.key, required this.kamera});

  final Camera kamera;

  @override
  State<CameraPlayerScreen> createState() => _CameraPlayerScreenState();
}

class _CameraPlayerScreenState extends State<CameraPlayerScreen> {
  late final VideoPlayerController _controller;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.kamera.streamUrl))
          ..initialize().then((_) {
            if (mounted) setState(() => _controller.play());
          }).catchError((Object e) {
            if (mounted) setState(() => _hata = 'Yayına bağlanılamadı');
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.kamera.ad)),
      backgroundColor: Colors.black,
      body: Center(
        child: _hata != null
            ? Text(_hata!, style: const TextStyle(color: Colors.white70))
            : _controller.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(),
      ),
    );
  }
}
