/// (P240 §4) ENTEGRASYON SAGLIGI — mobil yuzey.
///
/// EN ONEMLI OLCUM: "Kontrol et" ile "Test" AYRI UCLARA gider. Tek
/// dugmeye indirmek, `megaphone` kanalinda "kontrol edeyim" diyen
/// yoneticiye siteye ANONS YAPTIRIRDI.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/integrations/data/integration_api.dart';
import 'package:mobile/src/features/integrations/domain/integration_models.dart';
import 'package:mobile/src/features/integrations/presentation/integrations_screen.dart';

import 'helpers/l10n_test_app.dart';

class _SahteApi extends IntegrationApi {
  _SahteApi(this.kayitlar) : super(Dio());

  List<Integration> kayitlar;
  final List<String> cagrilar = [];

  // DENETLEYICI `fetchAll`/`fetchPresets` CAGIRIYOR (`list`/`presets`
  // DEGIL): ilk yazimda yanlis metotlar sahtelendi ve ekran BOS
  // kaldi — test "widget yok" diye dustu, bilesen degil TAKLIT hataliydi.
  @override
  Future<List<Integration>> fetchAll() async {
    cagrilar.add('list');
    return kayitlar;
  }

  @override
  Future<List<IntegrationPreset>> fetchPresets() async => const [];

  @override
  Future<TriggerResult> trigger(String id,
      {String message = '', String title = ''}) async {
    cagrilar.add('trigger');
    return const TriggerResult(ok: true, status: 200);
  }

  @override
  Future<Integration> saglikKontrol(String id) async {
    cagrilar.add('saglik');
    return kayitlar.first;
  }
}

Integration _ent({
  String saglik = 'bilinmiyor',
  String? hataKod,
  DateTime? sonBasarili,
}) =>
    Integration(
      id: 'i1',
      ad: 'Diyafon',
      channelType: 'smarthome',
      endpointUrl: 'https://cihaz.ornek.com/hook',
      httpMethod: 'POST',
      authType: 'none',
      authSecretSet: false,
      payloadTemplate: '',
      aktif: true,
      saglik: saglik,
      sonHataKod: hataKod,
      sonBasariliAt: sonBasarili,
    );

Widget _ekran(_SahteApi api) => ProviderScope(
      overrides: [integrationApiProvider.overrideWithValue(api)],
      child: l10nApp(const IntegrationsScreen()),
    );

void main() {
  testWidgets('YENI entegrasyon "bilinmiyor" — HATA DEGIL', (tester) async {
    // "Henuz olculmedi" ile "kopuk" ayni sey degil.
    final api = _SahteApi([_ent()]);
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();

    final metin =
        tester.widget<Text>(find.byKey(const Key('enteg-saglik-i1'))).data ?? '';
    expect(metin, 'Bilinmiyor');
  });

  testWidgets('HATA SEBEBI ANLASILIR DILDE — ham kimlik EKRANDA YOK',
      (tester) async {
    final api = _SahteApi([
      _ent(saglik: 'hata', hataKod: 'entegrasyon_baglanti_yok'),
    ]);
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();

    final metin =
        tester.widget<Text>(find.byKey(const Key('enteg-saglik-i1'))).data ?? '';
    expect(metin, contains('ulaşılamıyor'));
    expect(metin, isNot(contains('entegrasyon_baglanti_yok')));
  });

  testWidgets('SON ILETISIM YOKSA acikca soylenir', (tester) async {
    // Bos birakmak "hic olmadi" ile "uzun zaman once"yi karistirirdi.
    final api = _SahteApi([_ent()]);
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();

    final metin = tester
            .widget<Text>(find.byKey(const Key('enteg-son-iletisim-i1')))
            .data ??
        '';
    expect(metin, contains('Henüz'));
  });

  testWidgets('KONTROL ET saglik ucunu cagirir, TETIK UCUNU CAGIRMAZ',
      (tester) async {
    final api = _SahteApi([_ent()]);
    await tester.pumpWidget(_ekran(api));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('enteg-saglik-kontrol-i1')));
    await tester.tap(find.byKey(const Key('enteg-saglik-kontrol-i1')));
    await tester.pumpAndSettle();

    expect(api.cagrilar, contains('saglik'));
    // MEGAFON SUSMALI.
    expect(api.cagrilar, isNot(contains('trigger')));
  });
}
