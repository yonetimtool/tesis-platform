/// (P121) IZGARA KARELERİNİN TAZELENME KAPSAMI.
///
/// Kerem ızgarada oynatıcı açmadan canlı görüntü istedi. **N video oynatıcı
/// otomatik oynatılmaz:** iOS eşzamanlı `AVPlayer` sayısını sınırlar
/// (altıncı-yedinci karo sessizce siyah kalırdı), ayrıca pil/ısı/bant
/// genişliği bedeli kabul edilemez. Bunun yerine karo **durağan kare**
/// gösterir ve kare belirli aralıklarla yenilenir.
///
/// KAPSAM DİSİPLİNİ ana ekrandan (`home_refresh.dart`) devralındı ve aynı
/// üç kuralı uygular:
///   1. Ekran **görünürken** sayaç çalışır (`RouteAware`; üstüne başka ekran
///      açılınca `didPushNext` ile **durur**, dönünce `didPopNext` ile
///      yeniden başlar).
///   2. Uygulama **arka plana** geçince durur, ön plana gelince başlar
///      (`WidgetsBindingObserver`).
///   3. `dispose`ta kesin durur.
///
/// Bunlar olmadan ızgara, kullanıcı başka bir ekrandayken bile dakikada
/// onlarca istek atardı — "canlı" görünen bir ekranın en sessiz pil hatası.
///
/// SAYAÇ BİR **NESİL** SAYISIDIR, zaman damgası değil: karo adresine
/// eklenerek önbelleği kırar ve testte deterministiktir (zaman damgası
/// olsaydı test aynı kareyi iki kez üretemezdi).
library;

import 'dart:async';

import 'package:flutter/material.dart';

/// Kare tazeleme aralığı.
///
/// 8 sn, istenen 5–10 sn bandının ortası. Aşağı çekmek istekleri doğrusal
/// artırır; yukarı çekmek "canlı" hissini kaybettirir. Sabit ve tek yerde:
/// karonun kendisi aralık seçemez, yoksa ekranda farklı hızda tazelenen
/// karolar olurdu.
const kareAraligi = Duration(seconds: 8);

/// Görünürlüğe bağlı nesil sayacı. [builder] her tazelemede yeni bir
/// `nesil` ile çağrılır.
class KareTazeleme extends StatefulWidget {
  const KareTazeleme({
    super.key,
    required this.builder,
    required this.rotaGozlemcisi,
    this.aralik = kareAraligi,
    this.etkin = true,
  });

  final Widget Function(BuildContext context, int nesil) builder;

  /// Ekranın bağlı olduğu navigator gözlemcisi ("üstüme ekran açıldı"
  /// sinyali). Ana ekranın gözlemcisi yeniden kullanılır.
  final RouteObserver<ModalRoute<void>> rotaGozlemcisi;

  final Duration aralik;

  /// Tazeleme hiç gerekmiyorsa (ör. kare çekebilen kamera YOK) sayaç
  /// kurulmaz — boş bir ızgara için zamanlayıcı çalıştırmak saf israftır.
  final bool etkin;

  @override
  State<KareTazeleme> createState() => KareTazelemeState();
}

@visibleForTesting
class KareTazelemeState extends State<KareTazeleme>
    with WidgetsBindingObserver, RouteAware {
  int _nesil = 0;
  Timer? _zamanlayici;
  ModalRoute<void>? _rota;

  /// Testin okuduğu durum: sayaç şu an çalışıyor mu?
  @visibleForTesting
  bool get calisiyor => _zamanlayici != null;

  @visibleForTesting
  int get nesil => _nesil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _baslat();
  }

  @override
  void didUpdateWidget(covariant KareTazeleme oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Kare çekebilen kamera sonradan eklenirse/kalkarsa sayaç uyum sağlar.
    if (widget.etkin != oldWidget.etkin) {
      widget.etkin ? _baslat() : _durdur();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rota = ModalRoute.of(context);
    if (rota is ModalRoute<void> && rota != _rota) {
      if (_rota != null) widget.rotaGozlemcisi.unsubscribe(this);
      _rota = rota;
      widget.rotaGozlemcisi.subscribe(this, rota);
    }
  }

  void _baslat() {
    if (!widget.etkin) return;
    _zamanlayici?.cancel();
    _zamanlayici = Timer.periodic(widget.aralik, (_) {
      if (!mounted) return;
      setState(() => _nesil++);
    });
  }

  void _durdur() {
    _zamanlayici?.cancel();
    _zamanlayici = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Ön plana dönüşte HEMEN bir kare tazele: kullanıcı ekrana baktığında
      // beklemeden güncel görüntüyü görsün (aksi halde 8 sn'ye kadar bayat
      // bir kareye bakardı).
      if (widget.etkin && mounted) setState(() => _nesil++);
      _baslat();
    } else {
      _durdur();
    }
  }

  /// Üstteki ekran kapandı → ızgaraya dönüldü.
  @override
  void didPopNext() {
    if (widget.etkin && mounted) setState(() => _nesil++);
    _baslat();
  }

  /// Üstüne başka ekran açıldı → ızgara görünmüyor, sayaç dursun.
  @override
  void didPushNext() => _durdur();

  @override
  void dispose() {
    _durdur();
    if (_rota != null) widget.rotaGozlemcisi.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _nesil);
}
