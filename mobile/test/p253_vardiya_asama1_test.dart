/// (P253 Asama 1) VARDIYA — web esitligi, mobil.
///
/// Hafta gezinmesi, haftayi doldur / haftadan kopyala + GERI AL, blok
/// duzenle, toplu cikar, sablon ekle/duzenle/sil, izin talepleri
/// (liste / onayla / reddet / sil), dongu sonlandir, kalip sil.
///
/// Taklit HTTP ADAPTORUNDE (P200 dersi): istek govdesini kuran katman da
/// testin icinden gecer.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/shifts/presentation/vardiya_hafta_islemleri.dart';
import 'package:mobile/src/features/shifts/presentation/vardiya_plani_screen.dart';
import 'package:mobile/src/features/shifts/presentation/vardiyalar_screen.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';
import 'helpers/sahte_jwt.dart';

typedef Istek = ({
  String yol,
  String metot,
  Map<String, dynamic> govde,
  Map<String, dynamic> sorgu,
});

class _Tel implements HttpClientAdapter {
  _Tel(this.rol);

  /// `VardiyalarScreen` rolu `/me/profile`dan okur (jetondan degil).
  final String rol;
  final istekler = <Istek>[];

  /// `haftayi-doldur` / `haftadan-kopyala` sonrasi cizelgede beliren satir.
  bool yeniSatir = false;

  Map<String, dynamic> _blok(String id, String tarih) => {
        'plan_id': id,
        'tarih': tarih,
        'baslar': '${tarih}T08:00:00',
        'biter': '${tarih}T20:00:00',
        'shift_ad': 'Gunduz',
        'gece_asiyor': false,
        'calisma_saat': 12.0,
        'mola_dakika': 0,
        'yayinlandi_at': '${tarih}T00:00:00',
      };

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final ham = o.data;
    istekler.add((
      yol: o.path,
      metot: o.method,
      govde: ham is Map<String, dynamic> ? Map.of(ham) : <String, dynamic>{},
      sorgu: Map.of(o.queryParameters),
    ));
    final bas = (o.queryParameters['baslangic'] as String?) ?? '2026-01-05';
    final Object govde = switch ((o.method, o.path)) {
      ('GET', '/vardiya-plani/cizelge') => {
          'baslangic': bas,
          'bitis': bas,
          'personel': [
            {
              'user_id': 'u-1',
              'ad': 'Ali Guvenlik',
              'rol': 'security',
              'toplam_saat': 12.0,
              'hedef_saat': 45.0,
              'izinler': <Object>[],
              'bloklar': [
                _blok('p-1', bas),
                if (yeniSatir) _blok('p-9', bas),
              ],
            },
          ],
        },
      ('GET', '/vardiya-plani/simdi') => {
          'gorevdeki_vardiya': null,
          'gorevdekiler': <Object>[],
          'sonraki_vardiya': null,
          'sonrakiler': <Object>[],
        },
      ('GET', '/me/profile') => {'ad': 'Yonetici', 'role': rol},
      ('GET', '/vardiya-plani/yayin-ozeti') => {'bekleyen': 0, 'taslak': 0, 'degisen': 0},
      ('POST', '/vardiya-plani/haftayi-doldur') => () {
          yeniSatir = true;
          return {'gunler': <Object>[]};
        }(),
      ('POST', '/vardiya-plani/haftadan-kopyala') => () {
          yeniSatir = true;
          return {
            'uygulandi': true,
            'eklenen': 1,
            'atlanan': 2,
            'gunler': <Object>[],
            'sebepler': ['cakisma', 'izin'],
          };
        }(),
      ('GET', '/vardiya-izin') => {
          'meta': {'limit': 200, 'offset': 0, 'total': 1},
          'items': [
            {
              'id': 'i-1',
              'user_id': 'u-1',
              'kisi_ad': 'Ali Guvenlik',
              'tur': 'yillik',
              'baslangic': '2026-01-07',
              'bitis': '2026-01-08',
              'tum_gun': true,
              'durum': 'onay_bekliyor',
            },
          ],
        },
      ('GET', '/shifts') => {
          'items': [
            {
              'id': 's-1',
              'ad': 'Gunduz',
              'baslangic_saat': '08:00',
              'bitis_saat': '16:00',
              'gun_tipi': 'her_gun',
              'personel': <Object>[],
            },
          ],
        },
      ('POST', '/shifts') || ('PATCH', '/shifts/s-1') => {
          'id': 's-1',
          'ad': 'Gece',
          'baslangic_saat': '22:00',
          'bitis_saat': '06:00',
          'gun_tipi': 'her_gun',
        },
      _ => <String, dynamic>{},
    };
    return ResponseBody.fromString(jsonEncode(govde), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}

  List<Istek> yazma() => [for (final i in istekler) if (i.metot != 'GET') i];
}

Future<_Tel> _sur(
  WidgetTester tester, {
  String rol = 'yonetici',
  Widget ekran = const VardiyaPlaniScreen(),
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final tel = _Tel(rol);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  final kap = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    secureStorageProvider.overrideWithValue(BellekDepo({
      'auth.access_token': sahteJwt({'role': rol, 'tenant_id': 't-1', 'sub': 'u-1'}),
    })),
  ]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: kap, child: l10nApp(ekran)),
  );
  await tester.pumpAndSettle();
  return tel;
}

Future<void> _dokun(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  final buHafta = haftaBasi(DateTime.now());

  testWidgets('HAFTA GEZINMESI: sonraki hafta cizelgesi istenir', (tester) async {
    final tel = await _sur(tester);
    await _dokun(tester, find.byKey(const Key('vardiya-hafta-sonraki')));
    final son = tel.istekler.lastWhere((i) => i.yol == '/vardiya-plani/cizelge');
    expect(son.sorgu['baslangic'], tarihMetni(buHafta.add(const Duration(days: 7))));
    expect(find.text(haftaEtiketi(buHafta.add(const Duration(days: 7)))), findsOneWidget);
  });

  testWidgets('HAFTAYI DOLDUR + GERI AL yalniz YENI satiri cikarir', (tester) async {
    final tel = await _sur(tester);
    await _dokun(tester, find.byKey(const Key('vardiya-haftayi-doldur')));
    final doldur = tel.istekler.singleWhere((i) => i.yol == '/vardiya-plani/haftayi-doldur');
    expect(doldur.metot, 'POST');
    expect(doldur.sorgu['baslangic'], tarihMetni(buHafta));
    expect(find.text('1 vardiya eklendi'), findsOneWidget);
    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    final silinen = [
      for (final i in tel.istekler)
        if (i.metot == 'DELETE') i.yol,
    ];
    expect(silinen, ['/vardiya-plani/p-9']);
  });

  testWidgets('HAFTADAN KOPYALA: govde + temizle uyarisi + sebepler + geri al',
      (tester) async {
    final tel = await _sur(tester);
    await _dokun(tester, find.byKey(const Key('vardiya-haftadan-kopyala')));
    expect(find.text(haftaEtiketi(buHafta.subtract(const Duration(days: 7)))),
        findsOneWidget, reason: 'varsayilan kaynak: onceki hafta');
    expect(find.byKey(const Key('vardiya-kopya-temizle-uyari')), findsNothing);
    await _dokun(tester, find.byKey(const Key('vardiya-kopya-temizle')));
    expect(find.byKey(const Key('vardiya-kopya-temizle-uyari')), findsOneWidget);
    await _dokun(tester, find.byKey(const Key('vardiya-kopya-uygula')));
    final k = tel.istekler.singleWhere((i) => i.yol == '/vardiya-plani/haftadan-kopyala');
    expect(k.govde, {
      'kaynak_baslangic': tarihMetni(buHafta.subtract(const Duration(days: 7))),
      'hedef_baslangic': tarihMetni(buHafta),
      'hedefi_temizle': true,
    });
    expect(find.textContaining('1 vardiya kopyalandı, 2 atlandı'), findsOneWidget);
    expect(find.textContaining('çakışma'), findsOneWidget);
    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    expect([for (final i in tel.yazma()) if (i.metot == 'DELETE') i.yol],
        ['/vardiya-plani/p-9']);
  });

  testWidgets('BLOK DUZENLE: PATCH govdesi web ile ayni alanlar', (tester) async {
    final tel = await _sur(tester);
    await _dokun(tester, find.byKey(const Key('vardiya-blok-p-1')));
    await _dokun(tester, find.byKey(const Key('vardiya-duzenle-kaydet')));
    final p = tel.istekler.singleWhere((i) => i.metot == 'PATCH');
    expect(p.yol, '/vardiya-plani/p-1');
    expect(p.govde, {
      'tarih': tarihMetni(buHafta),
      'baslangic_saat': '08:00',
      'bitis_saat': '20:00',
    });
  });

  testWidgets('TOPLU CIKAR: uzun bas -> sec -> sebep -> DELETE', (tester) async {
    final tel = await _sur(tester);
    await tester.longPress(find.byKey(const Key('vardiya-blok-p-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coklu-secim-ust')), findsOneWidget);
    await _dokun(tester, find.text('Seçilenleri çıkar'));
    expect(find.textContaining('geri alınamaz'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('vardiya-toplu-sebep')), 'hastalik');
    await _dokun(tester, find.byKey(const Key('vardiya-toplu-onayla')));
    final d = tel.istekler.singleWhere((i) => i.metot == 'DELETE');
    expect(d.yol, '/vardiya-plani/p-1');
    expect(d.sorgu['not_metni'], 'hastalik');
    expect(find.byKey(const Key('coklu-secim-ust')), findsNothing);
  });

  testWidgets('SAHA ROLU: toplu araclar yok, blok dokunusu duzenleme acmaz',
      (tester) async {
    final tel = await _sur(tester, rol: 'security');
    expect(find.byKey(const Key('vardiya-haftayi-doldur')), findsNothing);
    expect(find.byKey(const Key('vardiya-haftadan-kopyala')), findsNothing);
    expect(find.byKey(const Key('vardiya-izin-talepleri')), findsOneWidget);
    await _dokun(tester, find.byKey(const Key('vardiya-blok-p-1')));
    expect(find.byKey(const Key('vardiya-duzenle-kaydet')), findsNothing);
    expect(tel.yazma(), isEmpty);
  });

  testWidgets('AMIR plan yazma araclarini gorur (sunucu _YAZAR)', (tester) async {
    await _sur(tester, rol: 'guvenlik_amiri');
    expect(find.byKey(const Key('vardiya-haftayi-doldur')), findsOneWidget);
  });

  testWidgets('IZIN TALEPLERI: bekleyen liste, onayla / reddet / sil', (tester) async {
    final tel = await _sur(tester);
    await _dokun(tester, find.byKey(const Key('vardiya-izin-talepleri')));
    final liste = tel.istekler.lastWhere((i) => i.yol == '/vardiya-izin');
    expect(liste.sorgu['durum'], 'onay_bekliyor');
    expect(find.byKey(const Key('izin-i-1')), findsOneWidget);
    await _dokun(tester, find.byKey(const Key('izin-onayla-i-1')));
    await _dokun(tester, find.byKey(const Key('izin-reddet-i-1')));
    await _dokun(tester, find.byKey(const Key('izin-sil-i-1')));
    await _dokun(tester, find.byKey(const Key('izin-sil-onayla')));
    expect([for (final i in tel.yazma()) '${i.metot} ${i.yol}'], [
      'POST /vardiya-izin/i-1/onayla',
      'POST /vardiya-izin/i-1/reddet',
      'DELETE /vardiya-izin/i-1',
    ]);
    // Suzgec "tumu" -> durum gonderilmez.
    await _dokun(tester, find.byKey(const Key('izin-suzgec-tumu')));
    expect(tel.istekler.lastWhere((i) => i.yol == '/vardiya-izin').sorgu
        .containsKey('durum'), isFalse);
  });

  testWidgets('IZIN: personel karar dugmesi gormez, kendi bekleyenini siler',
      (tester) async {
    await _sur(tester, rol: 'security');
    await _dokun(tester, find.byKey(const Key('vardiya-izin-talepleri')));
    expect(find.byKey(const Key('izin-onayla-i-1')), findsNothing);
    expect(find.byKey(const Key('izin-sil-i-1')), findsOneWidget);
  });

  testWidgets('SABLON: ekle / duzenle / sil govdeleri', (tester) async {
    final tel = await _sur(tester, ekran: const VardiyalarScreen());
    await _dokun(tester, find.byKey(const Key('vardiya-sablon-ekle')));
    expect(tester.widget<FilledButton>(find.byKey(const Key('vardiya-sablon-kaydet'))).onPressed,
        isNull, reason: 'adsiz sablon kaydedilmez');
    await tester.enterText(find.byKey(const Key('vardiya-sablon-ad')), 'Gece');
    await tester.pump();
    await _dokun(tester, find.byKey(const Key('vardiya-sablon-kaydet')));
    final post = tel.istekler.singleWhere((i) => i.metot == 'POST');
    expect(post.yol, '/shifts');
    expect(post.govde, {
      'ad': 'Gece',
      'baslangic_saat': '08:00',
      'bitis_saat': '16:00',
      'gun_tipi': 'her_gun',
    });
    expect(find.text('Şablon kaydedildi'), findsOneWidget);

    await _dokun(tester, find.byKey(const Key('vardiya-sablon-s-1')));
    await _dokun(tester, find.byKey(const Key('vardiya-sablon-kaydet')));
    expect(tel.istekler.singleWhere((i) => i.metot == 'PATCH').yol, '/shifts/s-1');

    await _dokun(tester, find.byKey(const Key('vardiya-sablon-s-1')));
    await _dokun(tester, find.byKey(const Key('vardiya-sablon-sil')));
    await _dokun(tester, find.byKey(const Key('vardiya-sablon-sil-onayla')));
    expect(tel.istekler.singleWhere((i) => i.metot == 'DELETE').yol, '/shifts/s-1');
  });

  testWidgets('SABLON: saha rolu ekle dugmesi gormez', (tester) async {
    await _sur(tester, rol: 'security', ekran: const VardiyalarScreen());
    expect(find.byKey(const Key('vardiya-sablon-ekle')), findsNothing);
  });
}
