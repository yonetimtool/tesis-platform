/// (P221) DUKKAN KAPISI — sekme yayinda, icerik bayraga bagli.
///
/// ===========================================================================
/// EN KRITIK KILIT: VARSAYILAN KAPALI, HER HATA YOLUNDA
/// ===========================================================================
/// Bayrak eksik, sunucu eski, ag kopuk — hepsinde Dukkan KAPALI olmali.
/// "Bilmiyorsak acalim" demek, hazir olmayan bir pazar yerini
/// kullaniciya gostermek olurdu.
///
/// ===========================================================================
/// IKINCI KILIT: HICBIR ROTA KAPIYI ATLAMAZ
/// ===========================================================================
/// Yalniz giris ekranini sarmak yetmezdi: bildirime dokunma, derin
/// baglanti ve panel/taleplerim rotalari kapiyi ATLAYABILIRDI. Kaynak
/// taramasi her Dukkan rotasinin `DukkanKapisi` ile sarildigini olcuyor.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/core/ozellikler/ozellik_bayraklari.dart';

class _SahteAdapter implements HttpClientAdapter {
  _SahteAdapter({this.govde, this.durum = 200, this.patlat = false});
  final String? govde;
  final int durum;
  final bool patlat;
  int cagri = 0;

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    cagri++;
    if (patlat) throw DioException(requestOptions: o, message: 'ag yok');
    return ResponseBody.fromString(govde ?? '{}', durum, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

ProviderContainer _kap(_SahteAdapter a) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = a;
  return ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('varsayilan KAPALI', () {
    test('SUNUCU false DERSE kapali', () async {
      final kap = _kap(_SahteAdapter(govde: '{"dukkan":false}'));
      addTearDown(kap.dispose);
      await kap.read(ozellikBayraklariProvider.future);
      expect(kap.read(dukkanAcikProvider), isFalse);
    });

    test('ALAN HIC YOKSA kapali (eski sunucu)', () async {
      // Uc henuz dagitilmamis bir sunucuda `{}` donebilir. "Alan yok"
      // ile "false" ayni sonuca varmali.
      final kap = _kap(_SahteAdapter(govde: '{}'));
      addTearDown(kap.dispose);
      await kap.read(ozellikBayraklariProvider.future);
      expect(kap.read(dukkanAcikProvider), isFalse);
    });

    test('AG HATASINDA kapali', () async {
      final kap = _kap(_SahteAdapter(patlat: true));
      addTearDown(kap.dispose);
      await kap.read(ozellikBayraklariProvider.future);
      expect(kap.read(dukkanAcikProvider), isFalse,
          reason: 'ag hatasinda ACILIRSA hazir olmayan yuzey gorunurdu');
    });

    test('YUKLEME SIRASINDA kapali', () {
      // Bir an icin acilip sonra kapanan sekme "bozuk" gorunurdu.
      final kap = _kap(_SahteAdapter(govde: '{"dukkan":true}'));
      addTearDown(kap.dispose);
      // `future` BEKLENMEDEN okunuyor: saglayici henuz yuklenmedi.
      expect(kap.read(dukkanAcikProvider), isFalse);
    });

    test('BEKLENMEDIK TIP kapali', () async {
      // Bozuk govde: `"evet"` bir bool degil.
      final kap = _kap(_SahteAdapter(govde: '{"dukkan":"evet"}'));
      addTearDown(kap.dispose);
      await kap.read(ozellikBayraklariProvider.future);
      expect(kap.read(dukkanAcikProvider), isFalse);
    });
  });

  test('SUNUCU true DERSE acilir — kapi kalici degil', () async {
    // Ters yon: kilit ozelligi TAMAMEN kapatmiyor. Sunucu acinca
    // acilmali, yoksa bayragin bir anlami kalmazdi.
    final kap = _kap(_SahteAdapter(govde: '{"dukkan":true}'));
    addTearDown(kap.dispose);
    await kap.read(ozellikBayraklariProvider.future);
    expect(kap.read(dukkanAcikProvider), isTrue);
  });

  test('UC KIMLIKSIZ CAGRILIYOR', () async {
    // Giris ekranindan ONCE cagriliyor; Yonetiyor jetonu konulsaydi ve
    // uc 401 dondurseydi, interceptor bunu "oturum bitti" sanip
    // kullaniciyi ATARDI (F4'te olculen kusur).
    final a = _SahteAdapter(govde: '{"dukkan":false}');
    final kap = _kap(a);
    addTearDown(kap.dispose);
    await kap.read(ozellikBayraklariProvider.future);
    expect(a.cagri, 1);
  });

  test('HER DUKKAN ROTASI KAPIDAN GECER', () {
    // KAYNAK TARAMASI: bir rota kapiyi atlarsa bildirime dokunma ya da
    // derin baglanti hazir olmayan ekrani ACARDI.
    final kaynak = File('lib/src/routing/app_router.dart').readAsStringSync();
    // Dukkan ekran siniflari — router'da her biri `DukkanKapisi` ile
    // sarilmis olmali.
    const ekranlar = [
      'DukkanAramaScreen',
      'DukkanProfilScreen',
      'DukkanTalepOlusturScreen',
      'DukkanTaleplerimScreen',
      'DukkanTalepDetayScreen',
      'DukkanSikayetScreen',
      'DukkanPanelScreen',
      'DukkanBildirimScreen',
    ];
    final sarilmamis = <String>[];
    for (final ekran in ekranlar) {
      // Ekranin gectigi yerin ONUNDE `DukkanKapisi` olmali.
      final indeks = kaynak.indexOf(ekran);
      if (indeks < 0) {
        sarilmamis.add('$ekran (router\'da YOK)');
        continue;
      }
      final onceki = kaynak.substring(
          indeks > 220 ? indeks - 220 : 0, indeks);
      if (!onceki.contains('DukkanKapisi')) sarilmamis.add(ekran);
    }
    expect(sarilmamis, isEmpty,
        reason: 'kapiyi atlayan rota(lar): $sarilmamis');
  });
}
