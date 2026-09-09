/// (P220 §2/§3) MOBIL BILDIRIM — TOPLU ISLEM, SEKME, ARAMA.
///
/// ===========================================================================
/// EN KRITIK KILIT: ROZET ANINDA TAZELENIR
/// ===========================================================================
/// P190'da web'de olculen kusur: toplu okundu deyince LISTE guncelleniyor
/// ama ust bardaki SAYI dusmuyordu — cunku rozet AYRI bir sorgudan
/// besleniyor (`unreadNotificationCountProvider`). Ayni tuzak mobilde de
/// var ve bu dosya ucunde de (toplu okundu / tumunu okundu / toplu sil)
/// rozetin tazelendigini olcuyor.
///
/// ===========================================================================
/// TAKLIT HTTP KATMANINDA (P200 DERSI)
/// ===========================================================================
/// `NotificationsApi` degil `Dio` taklit ediliyor: boylece govde, yol ve
/// metot GERCEKTEN olculuyor. API sinifini taklit etmek, tam da yazdigim
/// katmani atlardi.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/notifications/data/notifications_controller.dart';

/// Istek/yanit sinirina konan taklit: hangi yola, hangi govdeyle gidildi.
class _Kayit {
  _Kayit(this.metot, this.yol, this.govde, this.sorgu);
  final String metot;
  final String yol;
  final dynamic govde;
  final Map<String, dynamic>? sorgu;
}

class _SahteAdapter implements HttpClientAdapter {
  _SahteAdapter(this.yanitlar);

  /// yol -> yanit govdesi
  final Map<String, Map<String, dynamic>> yanitlar;
  final List<_Kayit> istekler = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? _,
      Future<void>? __) async {
    istekler.add(_Kayit(options.method, options.path, options.data,
        options.queryParameters));
    final govde = yanitlar[options.path] ?? const {'items': [], 'meta': {}};
    return ResponseBody.fromString(
      _json(govde),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _json(Object? o) {
  // `dart:convert` yerine elle: test govdeleri kucuk ve sabit.
  return const JsonEncoderKisayol().cevir(o);
}

class JsonEncoderKisayol {
  const JsonEncoderKisayol();
  String cevir(Object? o) => _yaz(o);
  String _yaz(Object? o) {
    if (o == null) return 'null';
    if (o is num || o is bool) return '$o';
    if (o is String) return '"${o.replaceAll('"', r'\"')}"';
    if (o is List) return '[${o.map(_yaz).join(',')}]';
    if (o is Map) {
      return '{${o.entries.map((e) => '"${e.key}":${_yaz(e.value)}').join(',')}}';
    }
    return '"$o"';
  }
}

ProviderContainer _kap(_SahteAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter;
  return ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
}

/// Saglayiciyi CANLI tutar.
///
/// `notificationsProvider` `autoDispose`: dinleyici yoksa okuma biter
/// bitmez atiliyor ve `ref.invalidate` firlatiyor. Gercek uygulamada
/// ekran onu `watch` ediyor; testte de ayni kosulu kurmak gerekiyor,
/// yoksa olculen sey urun degil test kurulumu olurdu.
void _canliTut(ProviderContainer kap) {
  final abone = kap.listen(notificationsProvider, (_, _) {});
  addTearDown(abone.close);
}

Map<String, dynamic> _bildirim(String id, {bool okundu = false}) => {
      'id': id,
      'tip': 'kacirilan_tur',
      'mesaj': 'A blok turu kacirildi',
      'okundu': okundu,
      'created_at': '2026-09-08T10:00:00Z',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SEKME sunucuya `okundu` olarak gider — varsayilan OKUNMAMIS',
      () async {
    final a = _SahteAdapter({
      '/notifications': {
        'items': [_bildirim('n1')],
        'meta': {'limit': 50, 'offset': 0, 'total': 1},
      },
    });
    final kap = _kap(a);
    addTearDown(kap.dispose);
    _canliTut(kap);

    await kap.read(notificationsProvider.future);
    // VARSAYILAN OKUNMAMIS: bildirim listesinin yanitlamasi gereken soru
    // "neyi kacirdim".
    expect(a.istekler.first.sorgu?['okundu'], false);

    kap.read(bildirimSuzgeciProvider.notifier).sekme(true);
    await kap.read(notificationsProvider.future);
    expect(a.istekler.last.sorgu?['okundu'], true);
  });

  test('ARAMA sunucuya gider — ve 2 karakterden kisa ise GITMEZ', () async {
    final a = _SahteAdapter({
      '/notifications': {
        'items': const [],
        'meta': {'limit': 50, 'offset': 0, 'total': 0},
      },
    });
    final kap = _kap(a);
    addTearDown(kap.dispose);

    kap.read(bildirimSuzgeciProvider.notifier).ara('k');
    await kap.read(notificationsProvider.future);
    // Tek harf: taranan satirlarin neredeyse tamamiyla eslesir, arama
    // sayilmaz.
    expect(a.istekler.last.sorgu?.containsKey('q'), false);

    kap.read(bildirimSuzgeciProvider.notifier).ara('kargo');
    await kap.read(notificationsProvider.future);
    expect(a.istekler.last.sorgu?['q'], 'kargo');
  });

  test('TOPLU OKUNDU dogru uca, dogru govdeyle gider', () async {
    final a = _SahteAdapter({
      '/notifications': {
        'items': [_bildirim('n1'), _bildirim('n2')],
        'meta': {'limit': 50, 'offset': 0, 'total': 2},
      },
      '/notifications/toplu-okundu': {'etkilenen': 2},
    });
    final kap = _kap(a);
    addTearDown(kap.dispose);
    _canliTut(kap);
    await kap.read(notificationsProvider.future);

    final n = await kap
        .read(notificationsProvider.notifier)
        .topluOkundu(['n1', 'n2']);
    expect(n, 2);
    final istek =
        a.istekler.lastWhere((x) => x.yol == '/notifications/toplu-okundu');
    expect(istek.metot, 'POST');
    expect(istek.govde['ids'], ['n1', 'n2']);
    expect(istek.govde['okundu'], true);
  });

  test('TOPLU SIL dogru uca gider', () async {
    final a = _SahteAdapter({
      '/notifications': {
        'items': [_bildirim('n1')],
        'meta': {'limit': 50, 'offset': 0, 'total': 1},
      },
      '/notifications/toplu-sil': {'etkilenen': 1},
    });
    final kap = _kap(a);
    addTearDown(kap.dispose);
    _canliTut(kap);
    await kap.read(notificationsProvider.future);

    final n = await kap.read(notificationsProvider.notifier).topluSil(['n1']);
    expect(n, 1);
    final istek =
        a.istekler.lastWhere((x) => x.yol == '/notifications/toplu-sil');
    expect(istek.metot, 'POST');
    expect(istek.govde['ids'], ['n1']);
  });

  test('TUMUNU OKUNDU dogru uca gider', () async {
    final a = _SahteAdapter({
      '/notifications': {
        'items': [_bildirim('n1')],
        'meta': {'limit': 50, 'offset': 0, 'total': 1},
      },
      '/notifications/tumunu-okundu': {'etkilenen': 7},
    });
    final kap = _kap(a);
    addTearDown(kap.dispose);
    _canliTut(kap);
    await kap.read(notificationsProvider.future);

    final n = await kap.read(notificationsProvider.notifier).tumunuOkundu();
    expect(n, 7);
    expect(
      a.istekler.any((x) => x.yol == '/notifications/tumunu-okundu'),
      isTrue,
    );
  });

  group('ROZET ANINDA TAZELENIR (P190 dersi)', () {
    /// Rozet AYRI bir sorgudan besleniyor; toplu islemden sonra o sorgu
    /// yeniden kosmazsa sayi bayat kalir. Kusurun web'deki hali buydu.
    Future<void> olc(
      String uc,
      Future<int> Function(NotificationsController) islem,
    ) async {
      final a = _SahteAdapter({
        '/notifications': {
          'items': [_bildirim('n1')],
          'meta': {'limit': 50, 'offset': 0, 'total': 3},
        },
        uc: {'etkilenen': 1},
      });
      final kap = _kap(a);
      addTearDown(kap.dispose);
      _canliTut(kap);

      // ==============================================================
      // ROZET SAGLAYICISI DA CANLI TUTULUYOR — VE BU SART
      // ==============================================================
      // ILK YAZIMDA TUTULMUYORDU ve test SAHTE YESILDI: rozet
      // saglayicisi `autoDispose`, dinleyicisi olmayinca okuma biter
      // bitmez atiliyor ve ikinci okuma zaten YENIDEN sorguluyordu.
      // Yani `invalidate` cagrilmasa da sayac artiyordu.
      //
      // Kirma denemesinde farkettim: rozet tazelemesini KALDIRDIM ve
      // test YINE GECTI. Olculen sey urun degil, autoDispose'un
      // kendisiydi.
      //
      // Dinleyici tutulunca saglayici canli kalir ve ikinci sorgu
      // ANCAK acik bir `invalidate` ile olusur.
      final rozetAbone =
          kap.listen(unreadNotificationCountProvider, (_, _) {});
      addTearDown(rozetAbone.close);

      // Rozet bir kez okunur (ilk sorgu).
      await kap.read(unreadNotificationCountProvider.future);
      final oncekiSayi = a.istekler
          .where((x) => x.yol == '/notifications' && x.sorgu?['limit'] == 1)
          .length;
      expect(oncekiSayi, 1);

      await islem(kap.read(notificationsProvider.notifier));

      // Saglayici gecersiz kilindiysa YENIDEN okundugunda ikinci sorgu
      // gider. `invalidate` tembel oldugu icin okuyarak zorluyoruz.
      await kap.read(unreadNotificationCountProvider.future);
      final sonrakiSayi = a.istekler
          .where((x) => x.yol == '/notifications' && x.sorgu?['limit'] == 1)
          .length;
      expect(sonrakiSayi, oncekiSayi + 1,
          reason: 'rozet tazelenmedi — sayi bayat kalirdi ($uc)');
    }

    test('toplu okundu', () => olc('/notifications/toplu-okundu',
        (c) => c.topluOkundu(['n1'])));
    test('tumunu okundu', () => olc('/notifications/tumunu-okundu',
        (c) => c.tumunuOkundu()));
    test('toplu sil', () => olc('/notifications/toplu-sil',
        (c) => c.topluSil(['n1'])));
  });
}
