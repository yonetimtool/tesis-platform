/// Ana ekranin CANLI VERI yenilemesi — "53 daire" gibi bayat sayaclarin
/// kaynagi tek bir eksikti: ana ekran bir kez yuklenip bir daha sorulmuyordu.
///
/// DORT TETIKLEYICI (hepsi ayni yenileme fonksiyonunu cagirir):
///   1. Baska bir ekrandan ANA EKRANA DONUS — `RouteAware.didPopNext`
///      ([homeRouteObserver] router'a `observers` ile takilir).
///   2. Uygulama ON PLANA gelme — `WidgetsBindingObserver.didChangeAppLifecycleState`.
///   3. ASAGI CEKIP yenileme — [HomeGovde.onYenile] (uc varyantta da bagli).
///   4. PERIYODIK yumusak yenileme — ana ekran gorunurken [_aralik] (45 sn):
///      YALNIZ sayaclar + akis; video/agir liste yok. Arka planda ve baska
///      ekran ustteyken zamanlayici DURUR (pil/veri).
///
/// TITREME YOK: yenileme `ref.invalidate` iledir. Riverpod yeniden hesaplarken
/// ONCEKI degeri korur (`AsyncValue.hasValue` true kalir) ve ana ekranin
/// `durum()`/`sayac()` yardimcilari veriyi once okur — iskelet YALNIZ ilk
/// yuklemede gorunur.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ProviderOrFamily (invalidate hedef tipi) flutter_riverpod 3'te misc.dart'ta.
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../announcements/data/announcement_api.dart';
import '../../budget/data/budget_api.dart';
import '../../cameras/data/cameras_api.dart';
import '../../complaints/data/complaint_api.dart';
import '../../dues/data/dues_api.dart';
import '../../etkinlik/data/etkinlik_api.dart';
import '../../kargo/data/kargo_api.dart';
import '../../notifications/data/notifications_controller.dart';
import '../../shifts/data/shifts_api.dart';
import '../../site_kurali/data/site_kurali_api.dart';
import '../../tenant/data/tenant_api.dart';
import '../../visitors/data/visitor_api.dart';
import '../../weather/data/weather_api.dart';
import '../data/activity_api.dart';
import '../data/home_api.dart';
import '../domain/home_varyant.dart';

/// Ana ekranin bagli oldugu navigator gozlemcisi — "ekrana geri donuldu"
/// sinyali icin. `GoRouter(observers: [homeRouteObserver])` ile takilir.
final homeRouteObserver = RouteObserver<ModalRoute<void>>();

/// Periyodik yumusak yenileme araligi (30–60 sn bandinin ortasi).
const _aralik = Duration(seconds: 45);

/// SAYAC + AKIS saglayicilari (yumusak yenileme kumesi). Rol'un ekraninda
/// izlenmeyen saglayici da listede olabilir: dinleyicisi olmayan
/// `autoDispose` saglayiciyi invalidate etmek istek URETMEZ.
List<ProviderOrFamily> _sayacProviderlari(HomeVaryant varyant) => [
      // Akis (tek uc, tum roller) + vardiya (saatle degisir).
      sonHareketlerProvider,
      shiftsProvider,
      unreadNotificationCountProvider,
      switch (varyant) {
        HomeVaryant.gorevli || HomeVaryant.tesisGorevlisi =>
          aktifGorevSayisiProvider,
        HomeVaryant.sakin => kendiDaireSikayetSayisiProvider,
        HomeVaryant.yonetici => toplamDaireSayisiProvider,
      },
      ...switch (varyant) {
        HomeVaryant.gorevli => [
            kargoListProvider,
            icerdekiZiyaretciSayisiProvider,
            bugunkuAracGirisSayisiProvider,
            yeniIhlalSayisiProvider,
            uzerimdekiZimmetSayisiProvider,
          ],
        HomeVaryant.tesisGorevlisi => [
            uzerimdekiZimmetSayisiProvider,
            acikSikayetSayisiProvider,
            yaklasanEtkinlikSayisiProvider,
          ],
        HomeVaryant.sakin => [
            kargoListProvider,
            visitorsListProvider,
            acikSikayetSayisiProvider,
            kendiGurultuSikayetSayisiProvider,
            myDuesProvider,
          ],
        HomeVaryant.yonetici => [
            aktifGorevSayisiProvider,
            acikSikayetSayisiProvider,
            acikDaireSikayetSayisiProvider,
            yeniIhlalSayisiProvider,
            otoparkDolulukProvider,
            financialSummaryProvider,
          ],
      },
    ];

/// TAM yenileme = sayaclar + daha agir/nadir degisen icerik (hava, tesis adi,
/// kamera listesi, duyuru/kural/etkinlik bolumleri).
List<ProviderOrFamily> _tamProviderlar(HomeVaryant varyant) => [
      ..._sayacProviderlari(varyant),
      weatherProvider,
      tenantSettingsProvider,
      camerasProvider,
      // (P213 §4) Ana ekran bandi AYRI saglayicidan besleniyor; tazeleme
      // listesine eklenmezse "asagi cek" bandi guncellemezdi.
      anaEkranKameralariProvider,
      sonDuyurularProvider,
      if (varyant == HomeVaryant.sakin) ...[
        anaEkranKurallariProvider,
        yaklasanEtkinliklerProvider,
      ],
    ];

/// Ana ekran verisini yeniler. [sadeceSayac] true → periyodik yumusak
/// yenileme (sayac + akis); false → tam yenileme (donus/on plan/pull).
///
/// Donen Future, akis saglayicisi yeniden yuklenince tamamlanir — bu sayede
/// asagi-cekme gostergesi veri gelene kadar dondugu gibi kalir.
Future<void> homeVerisiniYenile(
  WidgetRef ref,
  HomeVaryant varyant, {
  bool sadeceSayac = false,
}) async {
  final hedefler =
      sadeceSayac ? _sayacProviderlari(varyant) : _tamProviderlar(varyant);
  for (final p in hedefler) {
    ref.invalidate(p);
  }
  try {
    // Temsilci bekleme: akis her uc varyantta da izlenir.
    await ref.read(sonHareketlerProvider.future);
  } catch (_) {
    // Yenileme hatasi ekrani DUSURMEZ; bolum kendi hata durumunu gosterir.
  }
}

/// Ana ekrani sarmalar ve dort tetikleyiciyi kurar (govdeye dokunmaz).
class HomeCanliVeri extends ConsumerStatefulWidget {
  const HomeCanliVeri({
    super.key,
    required this.varyant,
    required this.child,
  });

  final HomeVaryant varyant;
  final Widget child;

  @override
  ConsumerState<HomeCanliVeri> createState() => _HomeCanliVeriState();
}

class _HomeCanliVeriState extends ConsumerState<HomeCanliVeri>
    with WidgetsBindingObserver, RouteAware {
  Timer? _zamanlayici;
  ModalRoute<void>? _rota;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _zamanlayiciBaslat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rota = ModalRoute.of(context);
    if (rota is ModalRoute<void> && rota != _rota) {
      if (_rota != null) homeRouteObserver.unsubscribe(this);
      _rota = rota;
      homeRouteObserver.subscribe(this, rota);
    }
  }

  void _zamanlayiciBaslat() {
    _zamanlayici?.cancel();
    _zamanlayici = Timer.periodic(_aralik, (_) {
      // Yumusak: yalniz sayac + akis (video/agir liste yok).
      homeVerisiniYenile(ref, widget.varyant, sadeceSayac: true);
    });
  }

  void _zamanlayiciDurdur() {
    _zamanlayici?.cancel();
    _zamanlayici = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // (2) On plana donus: tam yenileme + zamanlayici tekrar.
      homeVerisiniYenile(ref, widget.varyant);
      _zamanlayiciBaslat();
    } else {
      // Arka planda zamanlayici DURUR (pil/veri).
      _zamanlayiciDurdur();
    }
  }

  /// (1) Ustteki ekran kapandi → ana ekrana donuldu.
  @override
  void didPopNext() {
    homeVerisiniYenile(ref, widget.varyant);
    _zamanlayiciBaslat();
  }

  /// Ana ekranin ustune baska ekran acildi → gorunmuyor, zamanlayici dursun.
  @override
  void didPushNext() => _zamanlayiciDurdur();

  @override
  void dispose() {
    _zamanlayiciDurdur();
    if (_rota != null) homeRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
