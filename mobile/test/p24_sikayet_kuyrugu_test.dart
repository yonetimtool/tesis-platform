/// P24 — sikayet TRIYAJ kuyrugu: "Yeni / Okunmamis" sekmesi + rozet.
///
/// Kilitlenen davranislar:
///   * rozet SUNUCU toplamindan gelir (sayfa uzunlugundan degil),
///   * okundu isaretleme satiri "Yeni"den DUSURUR ama "Tümü"de BIRAKIR,
///   * ayni satir iki kez isaretlenirse rozet EKSIYE dusmez (idempotent),
///   * istek DUSERSE rozet azalmaz (iyimser guncelleme YOK),
///   * rozet SIFIRKEN cizilmez.
///
/// Testler API'yi Dio araciligiyla taklit eder — denetleyicinin GERCEK kodu
/// (suzgec parametreleri dahil) kosar; kopyasi degil (tur 79 dersi).
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/unit_complaints/domain/unit_complaint_models.dart';
import 'package:mobile/src/features/unit_complaints/presentation/sikayet_kuyrugu_controller.dart';
import 'package:mobile/src/features/unit_complaints/presentation/sikayet_kuyrugu_screen.dart';

import 'helpers/l10n_test_app.dart';

Map<String, dynamic> _kayit(String id, {required bool okundu}) => {
      'id': id,
      'target_unit_id': 'u-$id',
      'unit_no': 'A$id',
      'kategori': 'gurultu',
      'notlar': null,
      'durum': 'acik',
      'created_at': '2026-07-30T10:00:00Z',
      'okundu': okundu,
    };

/// Sunucu taklidi — okuma durumunu GERCEKTEN tutar, boylece `okunmamis`
/// suzgeci istemci tarafinda dogru gonderilmezse test duser.
class _SahteSunucu {
  _SahteSunucu({
    required this.tumKayitlar,
    Set<String> okunanlar = const {},
    this.okunduHata = false,
  }) : okunanlar = {...okunanlar};  // DEGISTIRILEBILIR kopya (const set yazilamaz)

  final List<String> tumKayitlar;
  final Set<String> okunanlar;
  final bool okunduHata;
  int okunduCagrisi = 0;
  final List<Object?> gonderilenSuzgecler = [];

  Dio dio() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path == '/unit-complaints') {
            final okunmamis = options.queryParameters['okunmamis'];
            gonderilenSuzgecler.add(okunmamis);
            final ids = tumKayitlar.where((id) {
              if (okunmamis == true) return !okunanlar.contains(id);
              if (okunmamis == false) return okunanlar.contains(id);
              return true;
            }).toList();
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'meta': {'limit': 200, 'offset': 0, 'total': ids.length},
                  'items': [
                    for (final id in ids)
                      _kayit(id, okundu: okunanlar.contains(id)),
                  ],
                },
              ),
            );
          }
          if (options.path.endsWith('/okundu')) {
            okunduCagrisi++;
            if (okunduHata) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 500,
                    data: {'code': 'internal', 'message': 'patladi'},
                  ),
                ),
              );
            }
            final id = options.path.split('/')[2];
            okunanlar.add(id);
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: _kayit(id, okundu: true),
              ),
            );
          }
          return handler.next(options);
        },
      ),
    );
    return dio;
  }
}

ProviderContainer _kap(_SahteSunucu sunucu) {
  final kap = ProviderContainer(
    overrides: [dioProvider.overrideWithValue(sunucu.dio())],
  );
  addTearDown(kap.dispose);
  return kap;
}

Future<SikayetKuyruguState> _yuklenmis(
  ProviderContainer kap,
) async {
  kap.listen(sikayetKuyruguControllerProvider, (_, __) {});
  await kap.read(sikayetKuyruguControllerProvider.notifier).refresh();
  return kap.read(sikayetKuyruguControllerProvider);
}

void main() {
  group('P24 — kuyruk durumu', () {
    test('YENI sekmesi sunucudan okunmamis=true ile gelir', () async {
      final sunucu = _SahteSunucu(
        tumKayitlar: ['1', '2', '3'],
        okunanlar: {'2'},
      );
      final durum = await _yuklenmis(_kap(sunucu));

      expect(durum.yeni.map((c) => c.id), ['1', '3']);
      expect(durum.tumu.map((c) => c.id), ['1', '2', '3']);
      expect(durum.okunmamisSayisi, 2, reason: 'rozet sunucu toplami');
      // Istemci suzmemeli: iki AYRI cagri gitmis olmali.
      expect(sunucu.gonderilenSuzgecler, containsAll(<Object?>[true, null]));
    });

    test('okundu: YENI listesinden duser, TUMU listesinde KALIR', () async {
      final sunucu = _SahteSunucu(tumKayitlar: ['1', '2']);
      final kap = _kap(sunucu);
      await _yuklenmis(kap);
      final ctrl = kap.read(sikayetKuyruguControllerProvider.notifier);

      expect(await ctrl.okunduIsaretle('1'), isTrue);
      final durum = kap.read(sikayetKuyruguControllerProvider);
      expect(durum.yeni.map((c) => c.id), ['2']);
      expect(durum.tumu.map((c) => c.id), ['1', '2'], reason: 'arsiv degil');
      expect(durum.tumu.firstWhere((c) => c.id == '1').okundu, isTrue);
      expect(durum.okunmamisSayisi, 1);
    });

    test('IDEMPOTENT: ikinci isaretleme rozeti EKSIYE dusurmez', () async {
      final sunucu = _SahteSunucu(tumKayitlar: ['1']);
      final kap = _kap(sunucu);
      await _yuklenmis(kap);
      final ctrl = kap.read(sikayetKuyruguControllerProvider.notifier);

      await ctrl.okunduIsaretle('1');
      await ctrl.okunduIsaretle('1');
      expect(kap.read(sikayetKuyruguControllerProvider).okunmamisSayisi, 0);
      expect(sunucu.okunduCagrisi, 2, reason: 'ikinci cagri da gitmeli');
    });

    test('istek DUSERSE rozet azalmaz (iyimser guncelleme YOK)', () async {
      final sunucu = _SahteSunucu(tumKayitlar: ['1', '2'], okunduHata: true);
      final kap = _kap(sunucu);
      await _yuklenmis(kap);
      final ctrl = kap.read(sikayetKuyruguControllerProvider.notifier);

      expect(await ctrl.okunduIsaretle('1'), isFalse);
      final durum = kap.read(sikayetKuyruguControllerProvider);
      expect(durum.okunmamisSayisi, 2, reason: 'sunucu reddetti, rozet durmali');
      expect(durum.yeni.map((c) => c.id), ['1', '2']);
    });
  });

  group('P24 — kuyruk ekrani', () {
    Future<void> ac(WidgetTester tester, _SahteSunucu sunucu) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dioProvider.overrideWithValue(sunucu.dio())],
          child: l10nApp(const SikayetKuyruguScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('rozet okunmamis SAYISINI gosterir', (tester) async {
      await ac(tester, _SahteSunucu(tumKayitlar: ['1', '2', '3'],
          okunanlar: {'3'}));
      expect(find.text('Yeni'), findsOneWidget);
      expect(find.text('2'), findsOneWidget, reason: 'rozet sayisi');
    });

    testWidgets('okunmamis YOKKEN rozet CIZILMEZ', (tester) async {
      await ac(tester, _SahteSunucu(tumKayitlar: ['1'], okunanlar: {'1'}));
      expect(find.text('Yeni'), findsOneWidget);
      expect(find.text('0'), findsNothing, reason: 'bos rozet yanlis sinyal');
      expect(find.text('Okunmamış şikayet yok.'), findsOneWidget);
    });

    testWidgets('okundu dokunmasi satiri kuyruktan DUSURUR ve rozeti azaltir',
        (tester) async {
      await ac(tester, _SahteSunucu(tumKayitlar: ['1', '2']));
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Okundu işaretle'), findsNWidgets(2));

      await tester.tap(find.text('Okundu işaretle').first);
      await tester.pumpAndSettle();

      expect(find.text('Okundu işaretle'), findsNWidgets(1));
      expect(find.text('1'), findsOneWidget, reason: 'rozet 1e dustu');
    });

    testWidgets('TUMU sekmesi okunani da gosterir ve eylem TASIMAZ',
        (tester) async {
      await ac(tester, _SahteSunucu(tumKayitlar: ['1', '2'], okunanlar: {'1'}));
      await tester.tap(find.text('Tümü'));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNWidgets(2));
      expect(find.text('Okundu işaretle'), findsNothing,
          reason: '"Tümü" bir is kuyrugu degil');
    });

    testWidgets('okundu dokunma hedefi 48 dp', (tester) async {
      await ac(tester, _SahteSunucu(tumKayitlar: ['1']));
      final boy = tester.getSize(find.byType(TextButton).first).height;
      expect(boy, greaterThanOrEqualTo(48.0));
    });
  });
}
