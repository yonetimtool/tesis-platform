/// (P252 §1) CALISMA BILGILERI — mobil personel formu, satir duzenlemesi ve
/// kisinin kendi profili.
///
///   * Yonetici personel eklerken ucret/odeme gunu AYNI `POST /users`
///     govdesinde (`calisma`) gider; bos birakilirsa `calisma` GITMEZ.
///   * Ucret var gun yok: istek ATILMAZ.
///   * Amir: formda bolum YOK, satirda "Calisma bilgileri" eylemi YOK ve
///     `/personel-kayitlari` hic cagrilmaz (ucret amire hic gelmez).
///   * Satir eylemi: bagli kart varsa PATCH (ikinci kart yok).
///   * Profil: saha personeli kendi ucretini ve son odemelerini gorur.
///
/// Taklit HTTP adapter'inda (P200 deseni): olculen sey TEL UZERINDEKI govde.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/staff/presentation/calisma_bilgileri.dart';
import 'package:mobile/src/features/staff/presentation/staff_screen.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/form_kaydir.dart';
import 'helpers/l10n_test_app.dart';
import 'helpers/sahte_jwt.dart';

const _personel = [
  {'id': 'g1', 'ad': 'Ali Guvenlik', 'role': 'security', 'is_active': true},
];

class _Tel implements HttpClientAdapter {
  final istekler = <({String yol, String metot, Map<String, dynamic> govde})>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final ham = options.data;
    istekler.add((
      yol: options.path,
      metot: options.method,
      govde: ham is Map<String, dynamic> ? Map.of(ham) : <String, dynamic>{},
    ));
    final Object govde = switch ((options.method, options.path)) {
      ('GET', '/users') => {
          'items': _personel,
          'meta': {'total': _personel.length},
        },
      ('POST', '/users') => {'id': 'yeni-1', 'personel_kayit_id': 'k9'},
      ('GET', '/kasalar') => {
          'items': [
            {'id': 'kasa1', 'ad': 'Merkez Kasa'},
          ],
        },
      ('GET', '/personel-kayitlari') => {
          'items': [
            {
              'id': 'k1', 'gorev': 'Güvenlik', 'maas_kurus': 2500000,
              'odeme_gunu': 5, 'kasa_id': 'kasa1', 'giris_tarihi': '2026-09-01',
            },
          ],
        },
      ('GET', '/personel/detay') => {
          'kart_id': 'k1', 'user_id': 'g1', 'ad': 'Ali Guvenlik', 'rol': 'security',
          'calisma': {
            'gorev': 'Güvenlik', 'maas_kurus': 2500000, 'odeme_gunu': 5,
            'kasa_id': 'kasa1', 'kasa_ad': 'Merkez Kasa', 'giris_tarihi': '2026-09-01',
            'aktif': true,
          },
          'odemeler': [
            {'id': 'h1', 'tarih': '2026-10-05', 'donem': '2026-10', 'tutar_kurus': 2500000,
             'tur': 'maas', 'durum': 'odendi', 'kasa_ad': 'Merkez Kasa'},
            {'id': 'h2', 'tarih': '2026-09-30', 'donem': null, 'tutar_kurus': 225000,
             'tur': 'mesai', 'durum': 'onay_bekliyor', 'kasa_ad': 'Merkez Kasa'},
          ],
          'bu_ay': {'vardiya_sayisi': 12, 'vardiya_saat': 144, 'devriye_tur': 30, 'okutma_sayisi': 240},
          'yil_odenen_kurus': 2500000,
        },
      ('GET', '/me/calisma') => {
          'calisma': {
            'gorev': 'Güvenlik', 'maas_kurus': 2500000, 'odeme_gunu': 5,
            'giris_tarihi': '2026-09-01',
            'odemeler': [
              {
                'id': 'h1', 'tarih': '2026-10-05', 'donem': '2026-10',
                'tutar_kurus': 2500000, 'tur': 'maas', 'durum': 'odendi',
              },
            ],
          },
        },
      _ => <String, dynamic>{},
    };
    return ResponseBody.fromString(
      jsonEncode(govde),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<_Tel> _sur(WidgetTester tester, String rol, Widget ekran) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  final tel = _Tel();
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = tel;
  final kap = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    secureStorageProvider.overrideWithValue(BellekDepo({
      'auth.access_token': sahteJwt({'role': rol, 'tenant_id': 't-1'}),
    })),
  ]);
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: kap, child: l10nApp(ekran)),
  );
  await tester.pumpAndSettle();
  return tel;
}

Future<void> _formuAc(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('personel-ad')), 'Ahmet');
  await tester.enterText(find.byKey(const Key('personel-soyad')), 'Yılmaz');
  await tester.enterText(find.byKey(const Key('personel-eposta')), 'ahmet@ornek.com');
}

Future<void> _kaydet(WidgetTester tester) async {
  await kaydetGorunsun(tester);
  await tester.tap(find.byType(FilledButton).last);
  await tester.pumpAndSettle();
}

Future<void> _sec<T>(WidgetTester tester, Key alan, String metin) async {
  await tester.ensureVisible(find.byKey(alan));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(alan));
  await tester.pumpAndSettle();
  await tester.tap(find.text(metin).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('YONETICI: ucret + gun + kasa hesapla AYNI istekte', (tester) async {
    final tel = await _sur(tester, 'yonetici', const StaffScreen());
    await _formuAc(tester);
    expect(find.byKey(const Key('calisma-bilgileri')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('calisma-ucret')), '25.000');
    await _sec<int?>(tester, const Key('calisma-gun'), '5');
    await _sec<String?>(tester, const Key('calisma-kasa'), 'Merkez Kasa');
    await _kaydet(tester);

    final post = tel.istekler.singleWhere((i) => i.yol == '/users' && i.metot == 'POST');
    expect(post.govde['calisma'], {
      'giris_tarihi': null,
      'gorev': null,
      'maas_kurus': 2500000,
      'odeme_gunu': 5,
      'kasa_id': 'kasa1',
      'iban': null,
      'notlar': null,
    });
  });

  testWidgets('YONETICI: bos birakilirsa yalniz hesap (`calisma` YOK)', (tester) async {
    final tel = await _sur(tester, 'yonetici', const StaffScreen());
    await _formuAc(tester);
    await _kaydet(tester);
    final post = tel.istekler.singleWhere((i) => i.yol == '/users' && i.metot == 'POST');
    expect(post.govde.containsKey('calisma'), isFalse);
  });

  testWidgets('YONETICI: ucret var gun yok -> istek ATILMAZ', (tester) async {
    final tel = await _sur(tester, 'yonetici', const StaffScreen());
    await _formuAc(tester);
    await tester.enterText(find.byKey(const Key('calisma-ucret')), '25000');
    await _kaydet(tester);
    expect(tel.istekler.where((i) => i.metot == 'POST'), isEmpty);
    expect(find.text('Ücret girildiyse ödeme günü de seçilmeli.'), findsOneWidget);
  });

  testWidgets('AMIR: formda bolum YOK, satirda eylem YOK, kart ucu cagrilmaz',
      (tester) async {
    final tel = await _sur(tester, 'guvenlik_amiri', const StaffScreen());
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Çalışma bilgileri'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await _formuAc(tester);
    expect(find.byKey(const Key('calisma-bilgileri')), findsNothing);
    await _kaydet(tester);
    final post = tel.istekler.singleWhere((i) => i.yol == '/users' && i.metot == 'POST');
    expect(post.govde.containsKey('calisma'), isFalse);
    expect(tel.istekler.any((i) => i.yol == '/personel-kayitlari'), isFalse);
    expect(tel.istekler.any((i) => i.yol == '/kasalar'), isFalse);
  });

  testWidgets('YONETICI satir eylemi: kart VARSA dolu acar ve PATCH', (tester) async {
    final tel = await _sur(tester, 'yonetici', const StaffScreen());
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çalışma bilgileri').last);
    await tester.pumpAndSettle();
    final kartIstegi =
        tel.istekler.singleWhere((i) => i.yol == '/personel-kayitlari');
    expect(kartIstegi.metot, 'GET');
    expect(find.text('25.000,00'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('calisma-ucret')), '26.000');
    final dugme = find.byKey(const Key('calisma-kaydet'));
    await tester.ensureVisible(dugme);
    await tester.pumpAndSettle();
    await tester.tap(dugme);
    await tester.pumpAndSettle();
    final patch = tel.istekler.singleWhere((i) => i.metot == 'PATCH');
    expect(patch.yol, '/personel-kayitlari/k1');
    expect(patch.govde['maas_kurus'], 2600000);
    expect(patch.govde['odeme_gunu'], 5);
    expect(tel.istekler.where((i) => i.metot == 'POST'), isEmpty);
  });

  testWidgets('PROFIL: personel kendi ucretini ve son odemesini gorur', (tester) async {
    await _sur(
      tester,
      'security',
      const Scaffold(body: SingleChildScrollView(child: BenimCalismamKarti())),
    );
    expect(find.text('Çalışma bilgilerim'), findsOneWidget);
    expect(find.text('₺25.000,00'), findsNWidgets(2));
    expect(find.text('Her ayın 5. günü'), findsOneWidget);
    expect(find.text('Maaş'), findsOneWidget);
  });

  testWidgets('YONETICI: satıra dokunma DETAYI açar (çalışma, bu ay, ödemeler)',
      (tester) async {
    final tel = await _sur(tester, 'yonetici', const StaffScreen());
    await tester.tap(find.text('Ali Guvenlik'));
    await tester.pumpAndSettle();
    expect(tel.istekler.any((i) => i.yol == '/personel/detay'), isTrue);
    expect(find.text('₺25.000,00'), findsWidgets);
    expect(find.text('Merkez Kasa'), findsOneWidget);
    expect(find.text('12 vardiya · 144 saat'), findsOneWidget);
    expect(find.text('30 devriye turu · 240 okutma'), findsOneWidget);
    expect(find.text('Maaş · 2026-10'), findsOneWidget);
    expect(find.textContaining('Onay bekliyor'), findsOneWidget);
  });

  testWidgets('AMIR: satıra dokunma detaya GİTMEZ', (tester) async {
    final tel = await _sur(tester, 'guvenlik_amiri', const StaffScreen());
    await tester.tap(find.text('Ali Guvenlik'));
    await tester.pumpAndSettle();
    expect(tel.istekler.any((i) => i.yol == '/personel/detay'), isFalse);
  });
}
