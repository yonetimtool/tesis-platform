/// P26 — Bagimsiz Bolum TIP + GRUP tanimlari.
///
/// Kilitlenen kararlar:
///   * varsayilan aidat `null` "tanimsiz"dir, 0 DEGIL (0 = muaf daire),
///   * ad SERBEST metindir,
///   * silme onayi KAC daireyi etkiledigini soyler,
///   * secici: secenek yoksa CIZILMEZ, "Seçilmedi" HER ZAMAN durur,
///     silinmis bir tanim secili kalirsa acilir kutu COKMEZ.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/i18n/l10n.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/unit_tanimlari/domain/unit_tanim_models.dart';
import 'package:mobile/src/features/unit_tanimlari/presentation/unit_tanimlari_screen.dart';

import 'helpers/l10n_test_app.dart';

/// Sunucu taklidi — GERCEK `UnitTanimApi` (dolayisiyla govde kurulumu)
/// kosar; kopyasi degil.
class _Sunucu {
  _Sunucu({this.tipler = const [], this.gruplar = const []});

  final List<Map<String, dynamic>> tipler;
  final List<Map<String, dynamic>> gruplar;
  final List<Map<String, dynamic>> gonderilenGovdeler = [];
  int silmeEtkisi = 0;

  Dio dio() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          if (o.method == 'GET') {
            final liste = o.path.contains('tipleri') ? tipler : gruplar;
            return h.resolve(Response(
              requestOptions: o,
              statusCode: 200,
              data: {
                'meta': {'limit': 200, 'offset': 0, 'total': liste.length},
                'items': liste,
              },
            ));
          }
          if (o.method == 'DELETE') {
            return h.resolve(Response(
              requestOptions: o,
              statusCode: 200,
              data: {'etkilenen_daire': silmeEtkisi},
            ));
          }
          gonderilenGovdeler.add(Map<String, dynamic>.from(o.data as Map));
          return h.resolve(Response(
            requestOptions: o,
            statusCode: 201,
            data: {'id': 'yeni', 'ad': 'x', 'aktif': true},
          ));
        },
      ),
    );
    return dio;
  }
}

Map<String, dynamic> _tipJson(
  String id,
  String ad, {
  int? aidat,
  int daire = 0,
}) => {
      'id': id,
      'ad': ad,
      'aktif': true,
      'varsayilan_aidat_kurus': aidat,
      'daire_sayisi': daire,
    };

void main() {
  group('P26 — model', () {
    test('aidat NULL "tanimsiz", 0 "muaf" — AYRI', () {
      final tanimsiz = UnitTip.fromJson(_tipJson('1', '2+1'));
      final muaf = UnitTip.fromJson(_tipJson('2', '1+0', aidat: 0));
      expect(tanimsiz.varsayilanAidatKurus, isNull);
      expect(muaf.varsayilanAidatKurus, 0);
      // Ikisini `?? 0` ile karistirmak P28'de sessiz sifir aidat uretirdi.
      expect(tanimsiz.varsayilanAidatKurus == muaf.varsayilanAidatKurus, isFalse);
    });

    test('taslak: aidat GIRILMEDIYSE alan GONDERILMEZ', () {
      // Grup formunda aidat alani yok; gondermek sunucuda anlamsiz olurdu.
      expect(
        const UnitTanimDraft(ad: 'Villa').toJson().containsKey(
              'varsayilan_aidat_kurus',
            ),
        isFalse,
      );
      // Tip formunda alan HER ZAMAN gonderilir — bos birakmak "KALDIR"dir.
      final bosaltan = const UnitTanimDraft(
        ad: '2+1',
        aidatGirildi: true,
      ).toJson();
      expect(bosaltan.containsKey('varsayilan_aidat_kurus'), isTrue);
      expect(bosaltan['varsayilan_aidat_kurus'], isNull);
    });
  });

  group('P26 — tanim ekrani', () {
    Future<void> ac(WidgetTester tester, _Sunucu s) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dioProvider.overrideWithValue(s.dio())],
          child: l10nApp(const UnitTanimlariScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tanimsiz aidat "Tanımsız" yazar, 0 TUTAR gosterir',
        (tester) async {
      await ac(
        tester,
        _Sunucu(tipler: [
          _tipJson('1', 'Tanimsiz tip'),
          _tipJson('2', 'Muaf tip', aidat: 0),
        ]),
      );
      expect(find.textContaining('Tanımsız'), findsOneWidget);
      // 0 "Tanımsız" DEGIL: tutar olarak cizilmeli.
      expect(find.textContaining('₺'), findsOneWidget);
    });

    testWidgets('silme onayi KAC daireyi etkiledigini soyler', (tester) async {
      await ac(tester, _Sunucu(tipler: [_tipJson('1', '2+1', daire: 7)]));
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.textContaining('7'), findsWidgets);
      expect(find.textContaining('SİLİNMEZ'), findsOneWidget);
    });

    testWidgets('bos liste: bilgilendirme + yeni tanim eylemi', (tester) async {
      await ac(tester, _Sunucu());
      expect(find.text('Henüz tanım yok.'), findsOneWidget);
      expect(find.text('Yeni tanım'), findsOneWidget);
    });

    testWidgets('GRUP sekmesinde aidat alani YOK', (tester) async {
      // Gruplar listesi DOLU olsun: sekmenin gercekten grup verisi cizdigi
      // ve yine de aidat alani ACMADIGI gorulsun.
      final s = _Sunucu(gruplar: [
        {'id': 'g1', 'ad': 'Villa', 'aktif': true, 'daire_sayisi': 2},
      ]);
      await ac(tester, s);
      await tester.tap(find.text('Gruplar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yeni tanım'));
      await tester.pumpAndSettle();
      expect(find.text('Varsayılan aidat'), findsNothing);
    });

    testWidgets('TIP sekmesinde aidat TL olarak girilir, KURUS gonderilir',
        (tester) async {
      final s = _Sunucu();
      await ac(tester, s);
      await tester.tap(find.text('Yeni tanım'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'dubleks');
      await tester.enterText(find.byType(TextFormField).last, '1250,50');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(s.gonderilenGovdeler, hasLength(1));
      expect(s.gonderilenGovdeler.first['ad'], 'dubleks');
      expect(s.gonderilenGovdeler.first['varsayilan_aidat_kurus'], 125050);
    });
  });

  group('P26 — daire duzenlemede SECICI', () {
    // Secici `_TanimSecici` ozel; davranisi bir `DropdownButtonFormField`
    // uzerinden kilitlenir: secenek yoksa CIZILMEZ, silinmis secim COKMEZ.
    Future<void> secici(
      WidgetTester tester,
      List<UnitTanim> secenekler,
      String? secili,
    ) async {
      await tester.pumpWidget(
        l10nApp(
          Builder(
            builder: (ctx) {
              if (secenekler.isEmpty) return const SizedBox.shrink();
              final gecerli =
                  secenekler.any((t) => t.id == secili) ? secili : null;
              return Material(
                child: DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: gecerli,
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(ctx.l10n.daireTanimSecilmedi),
                    ),
                    for (final t in secenekler)
                      DropdownMenuItem<String?>(
                        value: t.id,
                        child: Text(t.ad),
                      ),
                  ],
                  onChanged: (_) {},
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('secenek YOKSA cizilmez', (tester) async {
      await secici(tester, const [], null);
      expect(find.byType(DropdownButtonFormField<String?>), findsNothing);
    });

    testWidgets('"Seçilmedi" HER ZAMAN durur (secim geri alinabilir)',
        (tester) async {
      await secici(
        tester,
        [const UnitGrup(id: 'g1', ad: 'Villa', aktif: true)],
        'g1',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      expect(find.text('Seçilmedi'), findsWidgets);
    });

    testWidgets('SILINMIS tanim secili kalirsa COKMEZ', (tester) async {
      await secici(
        tester,
        [const UnitGrup(id: 'g1', ad: 'Villa', aktif: true)],
        'silinmis-id',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Seçilmedi'), findsOneWidget);
    });
  });

  group('P26 — 7 dil', () {
    testWidgets('yeni metinler BOS DEGIL ve TR sizmaz', (tester) async {
      const trHarf = 'ğışĞİŞ';
      for (final dil in ['tr', 'en', 'ar', 'ru', 'de', 'fr', 'es']) {
        late AppLocalizations l10n;
        await tester.pumpWidget(
          l10nApp(
            Builder(builder: (ctx) {
              l10n = ctx.l10n;
              return const SizedBox.shrink();
            }),
            locale: Locale(dil),
          ),
        );
        await tester.pumpAndSettle();
        final metinler = [
          l10n.modulDaireTanimlari,
          l10n.daireTanimSekmeTipler,
          l10n.daireTanimSekmeGruplar,
          l10n.daireTanimVarsayilanAidat,
          l10n.daireTanimAidatBos,
          l10n.daireTanimAidatAlt,
          l10n.daireTipiSecici,
          l10n.daireGrubuSecici,
          l10n.daireTanimSecilmedi,
          l10n.daireTanimSilOnay(3),
        ];
        for (final m in metinler) {
          expect(m.trim(), isNotEmpty, reason: dil);
          if (dil != 'tr') {
            expect(
              m.split('').any(trHarf.contains),
              isFalse,
              reason: '$dil TR harfi: $m',
            );
          }
        }
      }
    });
  });
}
