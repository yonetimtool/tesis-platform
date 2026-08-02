import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/i18n/l10n.dart';
import '../domain/camera_models.dart';
import '../domain/yayin_hatasi.dart';
import '../../../core/ui/merkez_diyalog.dart';
import 'yayin_hatasi_metni.dart';

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
  /// HAZIRLANMA UST SINIRI.
  ///
  /// iOS'ta `AVPlayerItem.status` `.unknown`ta TAKILI KALABILIR: CDN
  /// yanit vermiyorsa ya da varyant listesi cozulemiyorsa AVFoundation
  /// ne `readyToPlay` ne de HATA uretir. Eklenti de o zaman
  /// `initialize()`in Future'ini HIC tamamlamaz. Ust sinir olmadan ekran
  /// SONSUZA KADAR donen gostergede kalirdi — ve "yeniden dene" dugmesi
  /// YALNIZ hata ekraninda oldugu icin kullanicinin cikistan baska yolu
  /// olmazdi. (Android'de ExoPlayer bu durumda hata uretiyor; belirti bu
  /// yuzden iOS'a ozgu gorunuyor.)
  static const _hazirlanmaSiniri = Duration(seconds: 15);

  VideoPlayerController? _controller;

  /// Hata NEDENI (metin degil!): cumle cizim aninda aktif dilden okunur —
  /// boylece dil degisince ekrandaki hata metni de degisir. `null` = hata yok.
  YayinHatasi? _hataNedeni;

  /// Platformun HAM hata metni — YALNIZ hata ayiklama yapiminda gosterilir.
  ///
  /// Neden: "yayin acilamadi" cumlesi kullaniciya yeter ama CIHAZDA TEsHIS
  /// koymaya yetmez; AVFoundation'in kendi mesaji (kodek, 403, ATS...)
  /// tek ayirt edici bilgidir. Yayin yapiminda GIZLENIR: son kullaniciya
  /// ic ayrinti gostermek hem gurultu hem bilgi sizintisidir.
  String? _hamHata;

  bool _hazirlaniyor = true;

  /// AYNI ANDA TEK OYNATICI. "Yeniden dene" arka arkaya basildiginda
  /// birden cok `initialize()` ucusta olabilir; kusak numarasi, GECIKMIS
  /// olanin sonucunu YOK SAYMAYI saglar. Aksi halde eski cagri yeni
  /// controller'i EZER ve ezilen `AVPlayer` HIC atilmazdi — iOS'ta bu,
  /// ses oturumunu tutan bir hayalet oynatici birakir (NFC turundaki
  /// asili oturum hatasinin ayni sinifi).
  int _kusak = 0;

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

  /// TEST KAPISI — es zamanli yeniden denemeyi kurmak icin.
  ///
  /// Uretimde kullanilmaz: "yeniden dene" dugmesi zaten `_baslat`i cagirir
  /// ama gosterge ekranindayken dugme YOKTUR; es zamanlilik ancak
  /// buradan kurulabilir.
  @visibleForTesting
  void baslatTest() => _baslat();

  Future<void> _baslat() async {
    final kusak = ++_kusak;
    setState(() {
      _hazirlaniyor = true;
      _hataNedeni = null;
      _hamHata = null;
    });
    // Yeniden denemede ONCEKI controller atilir (sizinti yok).
    final eski = _controller;
    _controller = null;
    eski?.removeListener(_controllerDegisti);
    await eski?.dispose();

    // RESTREAM ONCELIKLI (P17): gecit varsa oynatici ONU calar; kameranin
    // kendi rtsp adresi oynatilamaz ama kayitta KORUNUR.
    // ADRES ONCE COZULUR (P25b): eskiden `Uri.parse` `try` blogunun DISINDA
    // cagriliyordu ve bosluk/satir sonu tasiyan bir adres, ekrana hic
    // ulasmadan YAKALANMAMIS bir `FormatException` firlatiyordu.
    final adres = widget.kamera.oynatilacakUrl.trim();
    if (widget.controllerYapici == null && !adresOynatilabilirMi(adres)) {
      setState(() {
        _controller = null;
        _hazirlaniyor = false;
        _hataNedeni = YayinHatasi.adresBozuk;
      });
      return;
    }

    final c =
        widget.controllerYapici?.call(widget.kamera) ??
        VideoPlayerController.networkUrl(Uri.parse(adres));
    try {
      // UST SINIR: bkz. [_hazirlanmaSiniri]. iOS'ta yanit vermeyen bir
      // yayin ne hazir ne hatali olur; sinir olmadan gosterge sonsuza
      // kadar donerdi.
      await c.initialize().timeout(_hazirlanmaSiniri);
      // ESKIMIS CAGRI: bu arada yeniden denenmisse sonucu YOK SAY ve
      // controller'i AT — yoksa hayalet oynatici kalirdi.
      if (!mounted || kusak != _kusak) {
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
    } catch (hata) {
      await c.dispose();
      if (!mounted || kusak != _kusak) return;
      setState(() {
        _controller = null;
        _hazirlaniyor = false;
        // Neden ADRESTEN + platform hatasindan turetilir; tek bir genel
        // cumle kullaniciyi yanlis ise yolluyordu (bkz. YayinHatasi).
        _hataNedeni = hata is TimeoutException
            ? YayinHatasi.ulasilamadi
            : yayinHatasiCoz(adres, hata);
        // Platformun/istisnanin KENDI metni. `TimeoutException` zaten
        // sureyi tasir ("TimeoutException after 0:00:15.000000"), yani
        // elle cumle kurmaya gerek yok — kurmak, cizim katmanina
        // enterpolasyonlu sabit metin sokmak olurdu (i18n kilidi bunu
        // hakli olarak reddetti).
        _hamHata = '$hata';
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
  ///
  /// HAZIRLIK SONRASI HATA BURADA YAKALANIR — eskiden HIC yakalanmiyordu.
  /// `video_player`in hata dinleyicisi, hata `initialize()` TAMAMLANDIKTAN
  /// SONRA gelirse Future'i degil YALNIZCA `value`yu isaretler
  /// (`VideoPlayerValue.erroneous`). HLS'te tipik akis tam olarak budur:
  /// ana liste yuklenir, oynatici "hazir" olur, sonra varyant/parca ya da
  /// kodek reddedilir. Eski kod yalniz `try/catch`e bakiyordu; boyle bir
  /// hatada ekran SIYAH kalir, uzerinde oynat ikonu durur ve kullaniciya
  /// HICBIR sey soylenmezdi — "yeniden dene" dugmesi de gorunmezdi.
  void _controllerDegisti() {
    if (!mounted) return;
    final c = _controller;
    if (c != null && c.value.hasError && _hataNedeni == null) {
      final mesaj = c.value.errorDescription;
      _controller = null;
      c.removeListener(_controllerDegisti);
      // Atma BEKLENMEZ: dinleyici icindeyiz ve cizim gecikmemeli.
      c.dispose();
      setState(() {
        _hazirlaniyor = false;
        _hataNedeni = yayinHatasiCoz(widget.kamera.oynatilacakUrl.trim(), mesaj);
        _hamHata = mesaj;
      });
      return;
    }
    setState(() {});
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
    final l10n = context.l10n;
    final neden = _hataNedeni;
    if (neden != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_outlined,
              color: Colors.white54,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.kameraYayinAcilamadi,
              key: const Key('kamera-hata'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              yayinHatasiMetni(l10n, neden),
              key: const Key('kamera-hata-neden'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            // PLATFORMUN HAM MESAJI — YALNIZ hata ayiklama yapiminda.
            //
            // Cihazda teshis koymanin tek ayirt edici bilgisi budur:
            // AVFoundation "cannot decode" mi diyor, 403 mu, ATS mi?
            // Yayin yapiminda gizlenir (son kullaniciya ic ayrinti
            // gostermek hem gurultu hem sizinti olurdu). Metin
            // PLATFORMDAN gelir, cevrilmez ve cevrilmemelidir.
            if (kDebugMode && _hamHata != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                _hamHata!,
                key: const Key('kamera-hata-ham'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _baslat,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.ortakYenidenDene),
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
    // `InkWell` (ciplak `GestureDetector` DEGIL): kendi `Focus`unu kurar,
    // yani harici klavye/anahtar erisimi ile de oynat/durdur yapilabilir
    // (tur 33). Dalga efekti video uzerinde istenmedigi icin kapatildi;
    // gorunum aynen korunur.
    return InkWell(
      onTap: _oynatDurdur,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio == 0
                  ? 16 / 9
                  : c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
          ),
          // Duraklatildiginda buyuk oynat ikonu (dokun → devam).
          if (!c.value.isPlaying)
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0x8C000000),
                shape: BoxShape.circle,
              ),
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
    return merkezSayfaAc<void>(
      context,
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
                Text(
                  context.l10n.kameraTurEtiket(kamera.tur.label),
                  style: metin.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(context.l10n.kameraRtspBilgi, style: metin.bodySmall),
          ],
        ),
      ),
    );
  }
}
