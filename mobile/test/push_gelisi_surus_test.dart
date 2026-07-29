/// TUR 45 — PUSH BILDIRIMI GELISINI SUR.
///
/// Tur 36 envanterinin son acik maddesi. On planda gelen push FCM tarafindan
/// sistem tepsisine DUSURULMEZ: uygulama acikken kullaniciya gostermek
/// uygulamanin isidir. Tur 45'e kadar mesaj yalniz `PushState.sonBildirim`
/// alanina yaziliyor ve HICBIR EKRAN okumuyordu — bildirim geldiginde
/// kullanici hicbir sey gormuyor, zil rozeti de artmiyordu.
///
/// Bu dosya iki seyi olcer:
///   1. push GELINCE gorunur geri bildirim (SnackBar) cizilir mi,
///   2. o hal bes eksende saglam mi (dar ekran / yazi olcegi / okuyucu /
///      koyu tema / klavye).
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/presentation/widgets/home_shell.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';
import 'package:mobile/src/features/notifications/domain/notification_models.dart';
import 'package:mobile/src/features/push/domain/push_models.dart';
import 'package:mobile/src/features/push/presentation/push_registrar.dart';

import 'helpers/ekran_surus.dart';
import 'helpers/l10n_test_app.dart';

/// Push durumunu TESTIN kontrol ettigi sahte kayit ediciyi kurar: gercek
/// Firebase'e hic dokunulmaz.
class _FakeRegistrar extends PushRegistrar {
  _FakeRegistrar(this._ilk);
  final PushState _ilk;

  @override
  PushState build() => _ilk;
}

class _FakeNotificationsApi extends NotificationsApi {
  _FakeNotificationsApi(this.okunmamis) : super(Dio());
  final int okunmamis;

  /// Rozet ucunun KAC KEZ sorguldugu — push gelince TAZELENMELI.
  int cagriSayisi = 0;

  @override
  Future<NotificationPage> fetch({
    int limit = 50,
    int offset = 0,
    bool? okundu,
  }) async {
    cagriSayisi++;
    return NotificationPage(items: const [], total: okunmamis);
  }
}

const _push = PushMessageEvent(
  title: 'Kaçırılan tur',
  body: 'Gece devriyesi turu kaçırıldı (2 eksik kontrol noktası).',
);

/// Bos yuklu push: cizim katmani kendi cevrilmis metnini yazmali.
const _bosPush = PushMessageEvent();

/// Surus sirasinda push'u SONRADAN gonderebilmek icin son kurulan kabin
/// tutulur: `ref.listen` yalnizca DEGISIMDE tetiklenir, baslangic degeri
/// SnackBar acmaz (ilk denememde surus bu yuzden BOS kosuyordu).
ProviderContainer? _sonKap;

Widget _kabukCanli(Locale locale, {int okunmamis = 3}) {
  final kap = ProviderContainer(overrides: [
    notificationsApiProvider.overrideWithValue(_FakeNotificationsApi(okunmamis)),
    currentUserRoleProvider.overrideWith((ref) async => UserRole.security),
  ]);
  _sonKap = kap;
  addTearDown(kap.dispose);
  return UncontrolledProviderScope(
    container: kap,
    child: l10nApp(
      HomeShell(
        role: UserRole.security,
        currentIndex: 0,
        unreadCount: okunmamis,
        onDestinationSelected: (_) {},
        onBildir: () {},
        onModul: (_) {},
        body: const SizedBox.shrink(),
      ),
      locale: locale,
    ),
  );
}

/// Kurulu kabuga push GONDERIR (surus `hazirla` adimi).
Future<void> _pushGonder(WidgetTester tester, {PushMessageEvent? olay}) async {
  _sonKap!.read(pushRegistrarProvider.notifier).state = PushState(
    durum: PushDurum.hazir,
    sonBildirim: olay ?? _push,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  if (find.byType(SnackBar).evaluate().isEmpty) {
    throw StateError('push gonderildi ama SnackBar cizilmedi — surus bos kosar');
  }
}

Widget _kabuk(Locale locale, {PushMessageEvent? bildirim, int okunmamis = 3}) =>
    ProviderScope(
      overrides: [
        pushRegistrarProvider.overrideWith(
          () => _FakeRegistrar(PushState(
            durum: PushDurum.hazir,
            sonBildirim: bildirim,
          )),
        ),
        notificationsApiProvider
            .overrideWithValue(_FakeNotificationsApi(okunmamis)),
        currentUserRoleProvider.overrideWith((ref) async => UserRole.security),
      ],
      child: l10nApp(
        HomeShell(
          role: UserRole.security,
          currentIndex: 0,
          unreadCount: okunmamis,
          onDestinationSelected: (_) {},
          onBildir: () {},
          onModul: (_) {},
          body: const SizedBox.shrink(),
        ),
        locale: locale,
      ),
    );

/// SUNUCU verisi (push metni sunucudan gelir — cevrilmez).
const _veri = {'Kaçırılan tur', 'Gece devriyesi', 'kaçırıldı', 'eksik kontrol'};

void main() {
  testWidgets('DEDEKTOR: push GELINCE SnackBar cizilir, gelmezse cizilmez',
      (tester) async {
    // Once bildirimsiz: SnackBar YOK.
    await tester.pumpWidget(_kabuk(const Locale('tr')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SnackBar), findsNothing);

    // Sonra push GELIYOR (durum degisimi `ref.listen`i tetikler).
    final kap = ProviderContainer(overrides: [
      notificationsApiProvider.overrideWithValue(_FakeNotificationsApi(3)),
      currentUserRoleProvider.overrideWith((ref) async => UserRole.security),
    ]);
    addTearDown(kap.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: kap,
      child: l10nApp(
        HomeShell(
          role: UserRole.security,
          currentIndex: 0,
          unreadCount: 3,
          onDestinationSelected: (_) {},
          onBildir: () {},
          onModul: (_) {},
          body: const SizedBox.shrink(),
        ),
      ),
    ));
    await tester.pump();
    kap.read(pushRegistrarProvider.notifier).state = const PushState(
      durum: PushDurum.hazir,
      sonBildirim: _push,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SnackBar), findsOneWidget,
        reason: 'on planda gelen push kullaniciya HIC gosterilmiyor');
    expect(find.textContaining('Kaçırılan tur'), findsWidgets);
  });

  testWidgets('PUSH: gelis ROZET SAYACINI tazeler', (tester) async {
    // Rozet ayri bir uctan gelir; push gelince yeniden sorulmazsa sayi
    // kullanici baska bir ekrana gidip donene kadar ESKI kalir.
    final api = _FakeNotificationsApi(3);
    final kap = ProviderContainer(overrides: [
      notificationsApiProvider.overrideWithValue(api),
      currentUserRoleProvider.overrideWith((ref) async => UserRole.security),
    ]);
    addTearDown(kap.dispose);
    // Rozet ucunu izlemeye al (ekran da boyle yapar).
    final abone = kap.listen(unreadNotificationCountProvider, (_, _) {});
    addTearDown(abone.close);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: kap,
      child: l10nApp(HomeShell(
        role: UserRole.security,
        currentIndex: 0,
        unreadCount: 3,
        onDestinationSelected: (_) {},
        onBildir: () {},
        onModul: (_) {},
        body: const SizedBox.shrink(),
      )),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final oncesi = api.cagriSayisi;

    kap.read(pushRegistrarProvider.notifier).state =
        const PushState(durum: PushDurum.hazir, sonBildirim: _push);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(api.cagriSayisi, greaterThan(oncesi),
        reason: 'push gelince okunmamis sayaci yeniden sorulmuyor');
  });

  testWidgets('PUSH: bos yuklu bildirimde CEVRILMIS varsayilan metin',
      (tester) async {
    for (final (dil, beklenen) in [
      ('tr', 'Yeni bildirim'),
      ('en', 'New notification'),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_kabukCanli(Locale(dil)));
      await tester.pump();
      await _pushGonder(tester, olay: _bosPush);
      expect(find.text(beklenen), findsOneWidget,
          reason: '$dil: bos push yukunde varsayilan metin cevrilmemis');
    }
  });

  testWidgets('PUSH: bildirim gelmis kabuk (bes eksen)', (tester) async {
    await tumEksenlerSurusu(
      tester,
      (dil) => _kabukCanli(Locale(dil)),
      veri: _veri,
      // SnackBar acilis animasyonu suruyor: sabit kare pompalanir.
      bekleyen: true,
      // Push CIZIMDEN SONRA gonderilir; `hazirla` ayrica SnackBar'in
      // gercekten cizildigini DOGRULAR.
      hazirla: _pushGonder,
    );
  });

  testWidgets('PUSH: 99+ okunmamis rozetli kabuk (bes eksen)', (tester) async {
    // Rozet sayisi UC HANEYE cikinca zil ve alt bar yuvasi tasabilir —
    // seed'de hic bu kadar bildirim olmadigi icin olculmemisti.
    await tumEksenlerSurusu(
      tester,
      (dil) => _kabuk(Locale(dil), okunmamis: 128),
      veri: _veri,
    );
  });
}
