import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/akis_hatasi.dart';
import '../../../core/error/api_exception.dart';
import '../../../core/i18n/l10n.dart';
import '../data/cameras_api.dart' show canliYayinBasliklari;
import '../data/kamera_kayit_api.dart';
import '../domain/camera_models.dart';
import '../domain/yayin_hatasi.dart';
import 'yayin_hatasi_metni.dart';

/// Oynatici controller ureticisi — TESTTE degistirilir (platform oynaticisi
/// widget testinde yoktur). Adres ve basliklar AYNEN verilir ki test
/// oynaticiya giden URL'i ve `Authorization` basligini olcebilsin.
typedef KayitControllerYapici = VideoPlayerController Function(
    Uri adres, Map<String, String> basliklar);

/// (P248 §1-kamera) GECMIS KAYIT OYNATICI.
///
/// =====================================================================
/// KIMLIK: `Authorization: Bearer` BASLIGI (canli oynaticiyla AYNI yol)
/// =====================================================================
/// Sunucu HLS vekili (`/cameras/{id}/kayit/<yol>/<dosya>`) normal API
/// yetkisi ister (`_KAYIT_IZLEYICI`). Olculdu (dev, gercek MediaMTX +
/// testcam): playlist -> varyant listesi -> init.mp4 -> seg*.mp4 zincirinin
/// HER halkasi yalniz bu baslikla 200, basliksiz 401.
///
/// iOS: `video_player_avfoundation` basliklari
/// `AVURLAssetHTTPHeaderFieldsKey` ile AVURLAsset'e verir; AVFoundation bu
/// basliklari ASSET'IN yaptigi TUM HTTP isteklerine (alt listeler +
/// segmentler) uygular. Canli kamera P190'dan beri AYNI yolla oynuyor;
/// imzali URL/cerez icin sunucu degisikligi GEREKMEDI. (Cihazda
/// dogrulanmasi ayrica gerekli — bu turda olculemedi.)
///
/// =====================================================================
/// SARMA NEDEN "YENIDEN OYNAT" ILE
/// =====================================================================
/// Zincir NVR -> zaman aralikli RTSP -> MediaMTX -> HLS. MediaMTX bunu
/// CANLI (kayan pencereli, `#EXT-X-ENDLIST`siz) bir liste olarak yayinlar
/// — olculdu: 2 sn'lik segmentlerle kisa bir pencere. Oynaticinin kendi
/// sarma cubugu bu yuzden araligin tamamini GEZEMEZ. Ileri/geri sarma,
/// secilen noktadan `POST .../kayit/oynat` ile YENI bir oturum acar (web
/// oynaticisi da sarma sunmuyor). Her yeniden acma sunucuda AYRI bir
/// denetim satiri birakir — bu dogru: amir o ani ayrica acmistir.
///
/// JETON OMRU: erisim jetonu 15 dk yasar ve oynaticiya BASLIKTA sabit
/// verilir; uzun izlemede segment istekleri 401 alir. Oynatma sonrasi
/// hata geldiginde ekran KALDIGI ANDAN bir kez kendiliginden yeniden acar
/// (`oynat` cagrisi Dio uzerinden gider, jeton orada tazelenir).
class KayitOynaticiScreen extends ConsumerStatefulWidget {
  const KayitOynaticiScreen({
    super.key,
    required this.kamera,
    required this.aralikBas,
    required this.aralikBit,
    this.tokenOkuyucu,
    this.controllerYapici,
  });

  final Camera kamera;
  final DateTime aralikBas;
  final DateTime aralikBit;
  final Future<String?> Function()? tokenOkuyucu;

  /// Uretimde null -> `VideoPlayerController.networkUrl`. Liste ekrani
  /// testte sahte controller'i buradan gecirir.
  final KayitControllerYapici? controllerYapici;

  @override
  ConsumerState<KayitOynaticiScreen> createState() =>
      _KayitOynaticiScreenState();
}

class _KayitOynaticiScreenState extends ConsumerState<KayitOynaticiScreen> {
  /// Sunucu playlist'i kaynak hazirlanana kadar 40 sn'ye kadar BEKLETIR
  /// (`_CANLI_HAZIRLIK_BUTCESI`; NVR oturumu acmak canli kameradan hizli
  /// degil). Ustune pay: 45 sn. Canli oynaticinin 15 sn'si burada ilk
  /// dokunusu HER ZAMAN dusururdu.
  static const _hazirlanmaSiniri = Duration(seconds: 45);

  /// Bu kadar duraklatildiktan sonra "devam" KALDIGI ANDAN yeniden acar:
  /// MediaMTX'in kayan penceresi kisa, beklemis oynatici canli ucuna
  /// ATLARDI (kayittaki zaman sessizce kayardi).
  static const _uzunDuraklama = Duration(seconds: 10);

  static const _adim = Duration(minutes: 1);

  VideoPlayerController? _controller;
  bool _hazirlaniyor = true;
  String? _apiHatasi;
  YayinHatasi? _yayinHatasi;
  String? _hamHata;
  String _adres = '';

  /// Su anki oturumun BASLADIGI kayit ani (sarma bunu degistirir).
  late DateTime _oturumBas;
  DateTime? _duraklatmaAni;
  bool _otomatikDenendi = false;
  int _kusak = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _oturumBas = widget.aralikBas;
    _baslat(widget.aralikBas);
  }

  /// Oynatilan kayit ani = oturum baslangici + oynatici konumu (araliga
  /// kirpilir).
  DateTime get _an {
    final c = _controller;
    final t = _oturumBas.add(c?.value.position ?? Duration.zero);
    if (t.isAfter(widget.aralikBit)) return widget.aralikBit;
    return t;
  }

  /// Sarma hedefi araliga kirpilir; bitise cok yakin bir baslangic
  /// sunucuda `bit <= bas` (422) olurdu — son 10 sn'ye izin verilmez.
  DateTime _kirp(DateTime t) {
    final son = widget.aralikBit.subtract(const Duration(seconds: 10));
    if (t.isBefore(widget.aralikBas)) return widget.aralikBas;
    if (t.isAfter(son)) {
      return son.isBefore(widget.aralikBas) ? widget.aralikBas : son;
    }
    return t;
  }

  Future<void> _baslat(DateTime bas, {bool otomatik = false}) async {
    final kusak = ++_kusak;
    if (!otomatik) _otomatikDenendi = false;
    final eski = _controller;
    _controller = null;
    eski?.removeListener(_degisti);
    setState(() {
      _hazirlaniyor = true;
      _apiHatasi = null;
      _yayinHatasi = null;
      _hamHata = null;
      _oturumBas = bas;
      _duraklatmaAni = null;
    });
    await eski?.dispose();

    final String yol;
    try {
      yol = await ref
          .read(kameraKayitApiProvider)
          .oynat(widget.kamera.id, bas, widget.aralikBit);
    } on ApiException catch (e) {
      if (!mounted || kusak != _kusak) return;
      setState(() {
        _hazirlaniyor = false;
        _apiHatasi = apiHataMetni(context.l10n, e);
      });
      return;
    }
    // Jeton `oynat` cagrisindan SONRA okunur: Dio o cagrida gerekirse
    // jetonu tazeledi, yani oynaticiya en taze jeton gider.
    final token = await widget.tokenOkuyucu?.call();
    if (!mounted || kusak != _kusak) return;
    _adres = AppConfig.apiBaseUrl + yol;
    final uri = Uri.parse(_adres);
    final basliklar = canliYayinBasliklari(token);
    final c = widget.controllerYapici?.call(uri, basliklar) ??
        VideoPlayerController.networkUrl(uri, httpHeaders: basliklar);
    try {
      await c.initialize().timeout(_hazirlanmaSiniri);
      if (!mounted || kusak != _kusak) {
        await c.dispose();
        return;
      }
      await c.play();
      c.addListener(_degisti);
      setState(() {
        _controller = c;
        _hazirlaniyor = false;
      });
    } catch (hata) {
      await c.dispose();
      if (!mounted || kusak != _kusak) return;
      setState(() {
        _hazirlaniyor = false;
        _yayinHatasi = hata is TimeoutException
            ? YayinHatasi.ulasilamadi
            : yayinHatasiCoz(_adres, hata);
        _hamHata = '$hata';
      });
    }
  }

  void _degisti() {
    if (!mounted) return;
    final c = _controller;
    if (c == null) return;
    if (c.value.hasError) {
      final an = _an;
      final mesaj = c.value.errorDescription;
      c.removeListener(_degisti);
      _controller = null;
      c.dispose();
      // HAZIRLIK SONRASI HATA: tipik sebep jetonun dolmasi (segment 401)
      // ya da ag kopmasi. BIR KEZ kaldigi andan yeniden acilir; ikinci
      // kez dusen oturum kullaniciya hata olarak gosterilir.
      if (!_otomatikDenendi) {
        _otomatikDenendi = true;
        _baslat(_kirp(an), otomatik: true);
        return;
      }
      setState(() {
        _hazirlaniyor = false;
        _yayinHatasi = yayinHatasiCoz(_adres, mesaj);
        _hamHata = mesaj;
      });
      return;
    }
    // Bir dakika saglikli oynadiysa otomatik yeniden deneme hakki geri
    // gelir (15 dk'lik jeton her dolusunda bir kez gerekir).
    if (_otomatikDenendi && c.value.position > const Duration(minutes: 1)) {
      _otomatikDenendi = false;
    }
    setState(() {});
  }

  void _oynatDurdur() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      _duraklatmaAni = DateTime.now();
      c.pause();
      return;
    }
    final d = _duraklatmaAni;
    if (d != null && DateTime.now().difference(d) > _uzunDuraklama) {
      _baslat(_kirp(_an));
      return;
    }
    _duraklatmaAni = null;
    c.play();
  }

  void _sar(Duration fark) => _baslat(_kirp(_an.add(fark)));

  @override
  void dispose() {
    _controller?.removeListener(_degisti);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.kamera.ad),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(18),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              l10n.kamKayitAralik(
                tarihSaatBicimi(widget.aralikBas, dil),
                tarihSaatBicimi(widget.aralikBit, dil),
              ),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: Center(child: _govde())),
            _kontroller(),
          ],
        ),
      ),
    );
  }

  Widget _govde() {
    final l10n = context.l10n;
    final apiHatasi = _apiHatasi;
    final yayinHatasi = _yayinHatasi;
    if (apiHatasi != null || yayinHatasi != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined,
                color: Colors.white54, size: 44),
            const SizedBox(height: 12),
            Text(
              l10n.kameraYayinAcilamadi,
              key: const Key('kayit-hata'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 4),
            // Sunucunun TANILI mesaji (NVR'a ulasilamadi, sablon gecersiz,
            // aralik genis...) oldugu gibi; yoksa oynatici hatasinin metni.
            Text(
              apiHatasi ?? yayinHatasiMetni(l10n, yayinHatasi!),
              key: const Key('kayit-hata-neden'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            if (kDebugMode && _hamHata != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                _hamHata!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('kayit-yeniden'),
              onPressed: () => _baslat(_kirp(_oturumBas)),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.ortakYenidenDene),
            ),
          ],
        ),
      );
    }
    final c = _controller;
    if (c == null || _hazirlaniyor || !c.value.isInitialized) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(key: Key('kayit-yukleniyor')),
          const SizedBox(height: 12),
          Text(l10n.kamKayitHazirlaniyor,
              style: const TextStyle(color: Colors.white70)),
        ],
      );
    }
    return InkWell(
      onTap: _oynatDurdur,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      child: Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
          child: VideoPlayer(c),
        ),
      ),
    );
  }

  Widget _kontroller() {
    final l10n = context.l10n;
    final dil = context.dilKodu;
    final c = _controller;
    final hazir = c != null && c.value.isInitialized && !_hazirlaniyor;
    final toplam = widget.aralikBit.difference(widget.aralikBas).inSeconds;
    final konum = _an
        .difference(widget.aralikBas)
        .inSeconds
        .clamp(0, toplam <= 0 ? 0 : toplam)
        .toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(saatBicimi(_an, dil),
                  key: const Key('kayit-an'),
                  style: const TextStyle(color: Colors.white70)),
              Expanded(
                child: Slider(
                  key: const Key('kayit-cubuk'),
                  value: konum,
                  max: toplam <= 0 ? 1 : toplam.toDouble(),
                  onChanged: hazir ? (_) {} : null,
                  // Birakildigi anda o noktadan YENI oturum (bkz. sinif notu).
                  onChangeEnd: hazir
                      ? (v) => _baslat(_kirp(widget.aralikBas
                          .add(Duration(seconds: v.round()))))
                      : null,
                ),
              ),
              Text(saatBicimi(widget.aralikBit, dil),
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const Key('kayit-geri'),
                tooltip: l10n.kamKayitGeri,
                color: Colors.white,
                onPressed: hazir ? () => _sar(-_adim) : null,
                icon: const Icon(Icons.replay),
              ),
              IconButton(
                key: const Key('kayit-oynat-durdur'),
                tooltip: (c?.value.isPlaying ?? false)
                    ? l10n.kamKayitDuraklat
                    : l10n.kamKayitOynat,
                color: Colors.white,
                iconSize: 40,
                onPressed: hazir ? _oynatDurdur : null,
                icon: Icon((c?.value.isPlaying ?? false)
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled),
              ),
              IconButton(
                key: const Key('kayit-ileri'),
                tooltip: l10n.kamKayitIleri,
                color: Colors.white,
                onPressed: hazir ? () => _sar(_adim) : null,
                icon: const Icon(Icons.forward),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
