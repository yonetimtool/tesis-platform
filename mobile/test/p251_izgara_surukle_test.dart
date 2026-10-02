/// (P251 §11) ANA EKRAN IZGARASI — BASILI TUT, SURUKLE, BIRAK.
///
/// Olculen:
///   * kart sirasi -> kayit adlari -> kart sirasi GIDIS-DONUS kayipsiz
///     (menusuz varsayilan kartlar `kart:` ile korunur, her rolde),
///   * uzun basis + surukleme yeni sirayi bildirir; kisa dokunus karti acar,
///   * Buyuk modda (2 sutun) da calisir,
///   * ekran okuyucu "Yukari tasi / Asagi tasi" eylemleri ayni sonucu verir,
///   * kayit HESAPTA: eski cihaz kaydi hesaba tasinir; yazma basarisizsa
///     cihazda bekler.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/gorunum/gorunum_modu.dart';
import 'package:mobile/src/core/network/dio_provider.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/data/token_storage.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/data/home_repository.dart';
import 'package:mobile/src/features/home/data/izgara_tercihi.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/home/domain/home_varyant.dart';
import 'package:mobile/src/features/home/domain/home_view_models.dart';
import 'package:mobile/src/features/home/presentation/izgara_koprusu.dart';
import 'package:mobile/src/features/home/presentation/widgets/hizli_erisim.dart';

import 'helpers/bellek_depo.dart';
import 'helpers/l10n_test_app.dart';

const _taban = MockHomeRepository();

String _k(HizliErisimKart k) => '${k.id.name}|${k.rota}';

List<HizliErisimKart> _varsayilan(UserRole rol) => izgaraKartlariKayittan(
    null, null, rol, homeVaryantForRole(rol), _taban);

Future<List<List<HizliErisimKart>>> _izgara(
  WidgetTester tester,
  List<HizliErisimKart> kartlar, {
  GorunumModu mod = GorunumModu.standart,
  List<HizliErisimKart>? acilan,
}) async {
  final bildirimler = <List<HizliErisimKart>>[];
  await tester.pumpWidget(l10nApp(Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: HizliErisimIzgarasi(
          kartlar: kartlar,
          mod: mod,
          onSec: (k) => acilan?.add(k),
          onSiraDegisti: bildirimler.add,
        ),
      ),
    ),
  )));
  await tester.pumpAndSettle();
  return bildirimler;
}

Finder _kart(HizliErisimKart k) => find.byKey(ValueKey('izgara-${_k(k)}'));

Future<void> _surukle(WidgetTester tester, Finder kaynak, Finder hedef) async {
  final g = await tester.startGesture(tester.getCenter(kaynak));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  final son = tester.getCenter(hedef);
  for (var i = 1; i <= 8; i++) {
    final bas = tester.getCenter(kaynak);
    await g.moveTo(Offset.lerp(bas, son, i / 8)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await tester.pumpAndSettle();
}

void main() {
  group('kayit <-> kart gidis-donus', () {
    for (final rol in UserRole.values.where((r) => r != UserRole.unknown)) {
      test('${rol.name}: varsayilan ve TERS sira kayipsiz', () {
        final kartlar = _varsayilan(rol);
        final adlar = kartlardanIzgara(kartlar, rol);
        final geri = izgaraKartlariKayittan(
            adlar, null, rol, homeVaryantForRole(rol), _taban);
        expect(geri.map(_k), kartlar.map(_k));

        final ters = kartlardanIzgara(kartlar.reversed.toList(), rol);
        final geriTers = izgaraKartlariKayittan(
            ters, null, rol, homeVaryantForRole(rol), _taban);
        expect(geriTers.map(_k), kartlar.reversed.map(_k));
      });
    }

    test('menusuz varsayilan kart `kart:` ile saklanir (sakin)', () {
      final adlar = kartlardanIzgara(_varsayilan(UserRole.resident), UserRole.resident);
      expect(adlar, contains('${izgaraKartOneki}sikayetlerim'));
    });

    test('rolun goremedigi ad ve bilinmeyen kart cizilmez', () {
      final kartlar = izgaraKartlariKayittan(
          ['financialSummary', 'kart:yokBoyleKart', 'announcements'],
          null, UserRole.resident, HomeVaryant.sakin, _taban);
      expect(kartlar.map((k) => k.rota), ['/announcements']);
    });
  });

  group('surukle-birak', () {
    testWidgets('uzun bas + surukle: yeni sira bildirilir', (tester) async {
      final kartlar = _varsayilan(UserRole.yonetici);
      final bildirim = await _izgara(tester, kartlar);
      await _surukle(tester, _kart(kartlar[0]), _kart(kartlar[2]));
      expect(bildirim, hasLength(1));
      expect(bildirim.single.map(_k).take(3),
          [_k(kartlar[1]), _k(kartlar[2]), _k(kartlar[0])]);
      expect(bildirim.single, hasLength(kartlar.length));
    });

    testWidgets('kisa dokunus karti ACAR, sirayi degistirmez', (tester) async {
      final kartlar = _varsayilan(UserRole.yonetici);
      final acilan = <HizliErisimKart>[];
      final bildirim = await _izgara(tester, kartlar, acilan: acilan);
      await tester.tap(_kart(kartlar[1]));
      await tester.pumpAndSettle();
      expect(acilan.map(_k), [_k(kartlar[1])]);
      expect(bildirim, isEmpty);
    });

    testWidgets('hedef disinda birakilirsa sira GERI alinir', (tester) async {
      final kartlar = _varsayilan(UserRole.yonetici);
      final bildirim = await _izgara(tester, kartlar);
      final g = await tester.startGesture(tester.getCenter(_kart(kartlar[0])));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      await g.moveTo(const Offset(5, 590));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(bildirim, isEmpty);
    });

    testWidgets('Buyuk mod (2 sutun, 4 karo) da surukler', (tester) async {
      final kartlar = _varsayilan(UserRole.yonetici);
      final bildirim = await _izgara(tester, kartlar, mod: GorunumModu.buyuk);
      expect(_kart(kartlar[4]), findsNothing);
      await _surukle(tester, _kart(kartlar[3]), _kart(kartlar[0]));
      expect(bildirim.single.map(_k).take(5), [
        _k(kartlar[3]), _k(kartlar[0]), _k(kartlar[1]), _k(kartlar[2]), _k(kartlar[4]),
      ]);
    });
  });

  testWidgets('ekran okuyucu: Yukari tasi / Asagi tasi', (tester) async {
    final h = tester.ensureSemantics();
    final kartlar = _varsayilan(UserRole.resident);
    final bildirim = await _izgara(tester, kartlar);

    void eylem(HizliErisimKart k, String etiket) {
      final dugum = tester.getSemantics(_kart(k));
      final kimlik = CustomSemanticsAction.getIdentifier(
          CustomSemanticsAction(label: etiket));
      expect(dugum.getSemanticsData().customSemanticsActionIds, contains(kimlik));
      dugum.owner!.performAction(dugum.id, SemanticsAction.customAction, kimlik);
    }

    // Ilk kartta "Yukari" yok, sonuncuda "Asagi" yok.
    final ilk = tester.getSemantics(_kart(kartlar.first)).getSemanticsData();
    expect(ilk.customSemanticsActionIds, isNot(contains(
        CustomSemanticsAction.getIdentifier(
            const CustomSemanticsAction(label: 'Yukarı taşı')))));

    eylem(kartlar[0], 'Aşağı taşı');
    await tester.pumpAndSettle();
    expect(bildirim.last.map(_k).take(2), [_k(kartlar[1]), _k(kartlar[0])]);
    h.dispose();
  });

  group('kayit hesapta', () {
    Future<(ProviderContainer, _Sunucu, BellekDepo)> kur({
      List<String>? hesapta,
      Map<String, String>? cihazda,
      bool yazmaBozuk = false,
    }) async {
      final sunucu = _Sunucu(hesapta, yazmaBozuk: yazmaBozuk);
      final depo = BellekDepo(cihazda);
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
        ..httpClientAdapter = sunucu;
      final kap = ProviderContainer(overrides: [
        dioProvider.overrideWithValue(dio),
        secureStorageProvider.overrideWithValue(depo),
        currentUserRoleProvider.overrideWith((ref) async => UserRole.yonetici),
      ]);
      kap.listen(izgaraTercihiProvider, (_, _) {}, fireImmediately: true);
      await kap.read(currentUserRoleProvider.future);
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      return (kap, sunucu, depo);
    }

    test('hesaptaki sira okunur', () async {
      final (kap, _, _) = await kur(hesapta: ['otopark', 'announcements']);
      addTearDown(kap.dispose);
      expect(kap.read(izgaraTercihiProvider), ['otopark', 'announcements']);
    });

    test('eski CIHAZ kaydi hesaba tasinir ve cihazdan silinir', () async {
      final (kap, sunucu, depo) = await kur(cihazda: {
        'ui.home_izgara.yonetici': jsonEncode(['complaints', 'otopark']),
      });
      addTearDown(kap.dispose);
      expect(sunucu.yazilan, [
        ['complaints', 'otopark'],
      ]);
      expect(depo.kutu.containsKey('ui.home_izgara.yonetici'), isFalse);
      expect(kap.read(izgaraTercihiProvider), ['complaints', 'otopark']);
    });

    test('siraKaydet hesaba yazar; ag yoksa cihazda bekler', () async {
      final (kap, sunucu, _) = await kur();
      addTearDown(kap.dispose);
      await kap.read(izgaraTercihiProvider.notifier).siraKaydet(['tasks', 'kart:raporlar']);
      expect(sunucu.yazilan.last, ['tasks', 'kart:raporlar']);

      final (kap2, _, depo2) = await kur(yazmaBozuk: true);
      addTearDown(kap2.dispose);
      await kap2.read(izgaraTercihiProvider.notifier).siraKaydet(['tasks']);
      expect(jsonDecode(depo2.kutu['ui.home_izgara.yonetici']!), ['tasks']);
      expect(kap2.read(izgaraTercihiProvider), ['tasks']);
    });

    test('duzenleme ekraninin kaydi AYNI kayda gider', () async {
      final (kap, sunucu, _) = await kur();
      addTearDown(kap.dispose);
      await kap.read(izgaraTercihiProvider.notifier).kaydet(
          [HomeMenuEntry.announcements, HomeMenuEntry.otopark]);
      expect(sunucu.yazilan.last, ['announcements', 'otopark']);
    });
  });
}

class _Sunucu implements HttpClientAdapter {
  _Sunucu(this.kayit, {this.yazmaBozuk = false});
  List<String>? kayit;
  final bool yazmaBozuk;
  final yazilan = <List<String>?>[];

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<Uint8List>? r, Future<void>? c) async {
    expect(o.path, '/me/ana-ekran-izgarasi');
    if (o.method == 'PUT') {
      if (yazmaBozuk) {
        throw DioException.connectionError(requestOptions: o, reason: 'ag yok');
      }
      final l = (o.data as Map)['secili'] as List?;
      kayit = l?.cast<String>();
      yazilan.add(kayit);
    }
    return ResponseBody.fromString(jsonEncode({'secili': kayit}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
