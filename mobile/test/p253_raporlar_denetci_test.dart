/// (P253 Asama 2) RAPORLAR + DENETCI MOBIL YUZEYI — kilitler.
///
///  * Katalogdaki her alanin mobil karsiligi var (backend kaynagi taranir).
///  * Rapor merkezi: goster govdesi, hafif rapor Excel -> paylas, agir
///    rapor -> kuyruk -> Islerim -> hazir -> indir -> paylas.
///  * Gorev gecmisi CSV (ISTEMCI /reports/tasks): sayfali cekim, ayni
///    sutunlar, formul enjeksiyonu kacisi.
///  * Icra: salt okuma liste + durum suzgeci.
///  * Denetci: menu, ana ekran, yazma dugmesi YOK.
///
/// Taklit HTTP ADAPTORUNDE: govdeyi kuran katman da olculur.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/gen/app_localizations.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/auth/domain/user_role.dart';
import 'package:mobile/src/features/home/domain/home_menu.dart';
import 'package:mobile/src/features/raporlar/data/rapor_motoru_api.dart';
import 'package:mobile/src/features/raporlar/domain/rapor_motoru_models.dart';
import 'package:mobile/src/features/raporlar/presentation/icra_screen.dart';
import 'package:mobile/src/features/raporlar/presentation/rapor_merkezi_screen.dart';
import 'package:mobile/src/features/raporlar/presentation/rapor_paylas.dart';
import 'package:share_plus/share_plus.dart';

import 'helpers/l10n_test_app.dart';

/// Yol + metot -> yanit. Govde ve sorgu kaydedilir.
class _Adaptor implements HttpClientAdapter {
  _Adaptor(this.yanit);
  final ResponseBody Function(RequestOptions o) yanit;
  final List<RequestOptions> istekler = [];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    istekler.add(o);
    return yanit(o);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object v, {int durum = 200}) => ResponseBody.fromString(
      jsonEncode(v),
      durum,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );

ResponseBody _bayt(List<int> b, {String? ad}) => ResponseBody.fromBytes(b, 200, headers: {
      Headers.contentTypeHeader: ['application/octet-stream'],
      if (ad != null) 'content-disposition': ['attachment; filename="$ad"'],
    });

const _katalog = {
  'kategoriler': ['listeler', 'ekstreler', 'dokumler'],
  'items': [
    {
      'kod': 'borc_alacak',
      'baslik': 'Borç-Alacak Listesi',
      'aciklama': 'Dönem başı / bakiye',
      'kategori': 'listeler',
      'alanlar': ['baslangic', 'bitis', 'listeleme_tipi', 'ismi_goster'],
      'agir': true,
    },
    {
      'kod': 'kasa_ekstresi',
      'baslik': 'Kasa Ekstresi',
      'aciklama': 'Kasa bazında hareket dökümü',
      'kategori': 'ekstreler',
      'alanlar': ['kasa_id', 'baslangic', 'bitis', 'min_tutar_kurus'],
      'agir': false,
    },
  ],
};

class _Dunya {
  _Dunya() {
    adaptor = _Adaptor(_yanitla);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = adaptor;
    final depo = Dio()..httpClientAdapter = adaptor;
    api = RaporMotoruApi(dio, depoDio: depo);
  }

  late final _Adaptor adaptor;
  late final RaporMotoruApi api;
  final paylasilan = <String>[];
  final paylasilanBaytlar = <List<int>>[];
  String isDurumu = 'bekliyor';
  int isSorgu = 0;

  List<RequestOptions> yol(String metot, String yol) =>
      [for (final o in adaptor.istekler) if (o.method == metot && o.path == yol) o];

  ResponseBody _yanitla(RequestOptions o) {
    final p = o.path;
    if (p == 'https://depo.test/rapor.xlsx') return _bayt([9, 9, 9]);
    if (p == '/raporlar/katalog') return _json(_katalog);
    if (p == '/raporlar/isler') {
      isSorgu++;
      return _json([
        {
          'id': 'is-1', 'kod': 'borc_alacak', 'bicim': 'excel', 'durum': isDurumu,
          'dosya_adi': isDurumu == 'hazir' ? 'borc_alacak.xlsx' : null, 'hata': null,
          'created_at': '2026-10-03T09:00:00Z', 'biten_at': null,
        },
      ]);
    }
    if (p == '/raporlar/isler/is-1/indir') {
      return _json({'url': 'https://depo.test/rapor.xlsx', 'dosya_adi': 'borc_alacak.xlsx'});
    }
    if (p == '/raporlar/borc_alacak/kuyruk') {
      return _json({
        'id': 'is-1', 'kod': 'borc_alacak', 'bicim': 'excel', 'durum': 'bekliyor',
        'created_at': '2026-10-03T09:00:00Z',
      }, durum: 202);
    }
    if (p == '/raporlar/kasa_ekstresi' && o.queryParameters['bicim'] == 'tablo') {
      return _json({
        'kod': 'kasa_ekstresi',
        'baslik': 'Kasa Ekstresi',
        'sutunlar': [
          {'anahtar': 'aciklama', 'baslik': 'Açıklama', 'tip': 'metin'},
          {'anahtar': 'tutar', 'baslik': 'Tutar', 'tip': 'kurus'},
        ],
        'satirlar': [
          {'aciklama': 'Asansör bakımı', 'tutar': 125000},
        ],
      });
    }
    if (p == '/raporlar/kasa_ekstresi') return _bayt([1, 2, 3], ad: 'kasa-ekstresi.xlsx');
    if (p == '/kasalar') {
      return _json({'items': [{'id': 'k-1', 'ad': 'Merkez Kasa'}]});
    }
    if (p == '/finans/icra-dosyalari') {
      final durum = o.queryParameters['durum'];
      return _json({
        'meta': {'total': 1, 'limit': 200, 'offset': 0},
        'items': [
          if (durum == null || durum == 'avukatta')
            {
              'id': 'i-1', 'dosya_no': '2026/12', 'user_id': 'u-1', 'user_ad': 'Ahmet YILMAZ',
              'durum': 'avukatta', 'avukat': 'Av. Ayşe', 'acik_borc_kurus': 350000,
              'veris_tarihi': '2026-09-01', 'created_at': '2026-09-01T00:00:00Z',
            },
        ],
      });
    }
    if (p == '/task-completions') {
      final offset = o.queryParameters['offset'] as int;
      // 200 + 1 satir: iki sayfa.
      final adet = offset == 0 ? 200 : 1;
      return _json({
        'meta': {'total': 201, 'limit': 200, 'offset': offset},
        'ozet': {'toplam': 201, 'kategoriler': []},
        'items': [
          for (var i = 0; i < adet; i++)
            {
              'id': 't-$offset-$i', 'task_id': 'x', 'task_adi': i == 0 ? '=HYPERLINK("x")' : 'Çöp',
              'kategori_ad': 'Temizlik', 'tamamlayan_user_id': 'u-1',
              'tamamlanma_zamani': '2026-10-01T08:00:00Z', 'foto_var': true,
              'nfc_dogrulandi': false, 'notlar': 'not, virgüllü',
            },
        ],
      });
    }
    if (p == '/users') return _json({'items': [{'id': 'u-1', 'ad': 'Ahmet YILMAZ'}]});
    return _json({'items': []});
  }

  Widget uygulama(Widget ekran, {UserRole rol = UserRole.yonetici}) => ProviderScope(
        overrides: [
          raporMotoruApiProvider.overrideWithValue(api),
          currentUserRoleProvider.overrideWith((ref) async => rol),
          raporPaylasimDikisiProvider.overrideWithValue(RaporPaylasimDikisi(
            geciciDizin: () async => Directory.systemTemp.createTempSync('rpr'),
            paylasici: (XFile f, String? konu, Rect? konum) async {
              paylasilan.add(f.name);
              paylasilanBaytlar.add(File(f.path).readAsBytesSync());
            },
          )),
        ],
        child: l10nApp(ekran),
      );
}

/// Sahte zamani ilerletir (Dio zamanlayicilari) VE gercek G/C'ye (gecici
/// dosya yazimi) firsat verir — ikisi de gerekiyor.
Future<void> _pump(WidgetTester t, {int tur = 8}) async {
  for (var i = 0; i < tur; i++) {
    await t.pump(const Duration(milliseconds: 30));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  }
}

void main() {
  test('KATALOGDAKI HER ALANIN mobil tanimi var (backend kaynagi taranir)', () {
    final kaynak = File('../backend/app/routers/rapor_motoru.py').readAsStringSync();
    final alanlar = <String>{};
    for (final blok in kaynak.split('KatalogKaydi(').skip(1)) {
      final m = RegExp(r'\(\s*((?:"[a-z_]+"\s*,?\s*)+)\)').firstMatch(blok);
      if (m == null) continue;
      alanlar.addAll(RegExp(r'"([a-z_]+)"').allMatches(m.group(1)!).map((x) => x.group(1)!));
    }
    expect(alanlar.length, greaterThan(15), reason: 'tarama bosa dusmesin');
    expect(alanlar.where((a) => !alanTanimlari.containsKey(a)).toList(), isEmpty,
        reason: 'Katalog bu alani istiyor ama mobil formu CIZEMEZ');
  });

  test('govdeyeCevir: false GONDERILIR, bos dusulur, TL -> kurus', () {
    final g = govdeyeCevir({
      'ismi_goster': false,
      'blok': '',
      'min_tutar_kurus': '1.250,50',
      'baslangic_yil': '2026',
      'gelir_gider_tanim_idler': <String>[],
      'listeleme_tipi': 'borclu',
    });
    expect(g, {'ismi_goster': false, 'min_tutar_kurus': 125050, 'baslangic_yil': 2026, 'listeleme_tipi': 'borclu'});
  });

  test('CSV hucresi web ile ayni: formul kacisi, saf sayi korunur, virgul tirnaklanir', () {
    expect(csvHucre('=HYPERLINK("x")'), '"\'=HYPERLINK(""x"")"');
    expect(csvHucre('-12,50'), '"-12,50"');
    expect(csvHucre('@abc'), "'@abc");
    expect(csvHucre('düz'), 'düz');
  });

  testWidgets('GOSTER: govde varsayilanlarla gider, tablo kart olarak cizilir (kurus -> TL)',
      (t) async {
    final d = _Dunya();
    await t.pumpWidget(d.uygulama(const RaporMerkeziScreen()));
    await _pump(t);
    expect(find.text('Kasa Ekstresi'), findsOneWidget);
    await t.tap(find.byKey(const Key('rpr-kart-kasa_ekstresi')));
    await _pump(t);
    expect(find.byKey(const Key('rpr-agir-uyari')), findsNothing);
    await t.tap(find.byKey(const Key('rpr-goster')));
    await _pump(t);
    final istek = d.yol('POST', '/raporlar/kasa_ekstresi').single;
    expect(istek.queryParameters['bicim'], 'tablo');
    final govde = istek.data as Map;
    expect(govde['baslangic'], '${DateTime.now().year}-01-01');
    expect(govde.containsKey('kasa_id'), isFalse, reason: 'secilmeyen alan GONDERILMEZ');
    expect(find.byKey(const Key('rpr-tablo')), findsOneWidget);
    expect(find.text('Asansör bakımı'), findsOneWidget);
    expect(find.textContaining('1.250'), findsOneWidget);
  });

  testWidgets('HAFIF rapor Excel: dosya uretilir ve sunucunun dosya adiyla PAYLASILIR',
      (t) async {
    final d = _Dunya();
    await t.pumpWidget(d.uygulama(const RaporMerkeziScreen()));
    await _pump(t);
    await t.tap(find.byKey(const Key('rpr-kart-kasa_ekstresi')));
    await _pump(t);
    await t.tap(find.byKey(const Key('rpr-excel')));
    await _pump(t);
    expect(d.yol('POST', '/raporlar/kasa_ekstresi').single.queryParameters['bicim'], 'excel');
    expect(d.paylasilan, ['kasa-ekstresi.xlsx']);
    expect(d.paylasilanBaytlar.single, [1, 2, 3]);
  });

  testWidgets('AGIR rapor: kuyruga -> Islerim -> hazir olunca bildirir -> indir -> paylas',
      (t) async {
    final d = _Dunya();
    await t.pumpWidget(d.uygulama(
      const RaporMerkeziScreen(tazelemeAraligi: Duration(milliseconds: 50)),
    ));
    await _pump(t);
    await t.tap(find.byKey(const Key('rpr-kart-borc_alacak')));
    await _pump(t);
    expect(find.byKey(const Key('rpr-agir-uyari')), findsOneWidget);
    await t.tap(find.byKey(const Key('rpr-excel')));
    await _pump(t);
    final kuyruk = d.yol('POST', '/raporlar/borc_alacak/kuyruk').single;
    expect(kuyruk.queryParameters['bicim'], 'excel');
    expect((kuyruk.data as Map)['ismi_goster'], true);
    expect(d.yol('POST', '/raporlar/borc_alacak'), isEmpty, reason: 'agir rapor senkron ucu cagirmaz');
    // Islerim sekmesi: is bekliyor; is hazir olunca tazeleme yakalar.
    final once = d.isSorgu;
    d.isDurumu = 'hazir';
    for (var i = 0; i < 10 && find.byKey(const Key('rpr-is-indir-is-1')).evaluate().isEmpty; i++) {
      await _pump(t, tur: 3);
    }
    await _pump(t, tur: 2);
    expect(d.isSorgu, greaterThan(once), reason: 'bekleyen is varken liste tazelenir');
    expect(find.text('Rapor hazır: borc_alacak.xlsx'), findsOneWidget);
    await t.tap(find.byKey(const Key('rpr-is-indir-is-1')));
    await _pump(t);
    expect(d.yol('GET', '/raporlar/isler/is-1/indir'), hasLength(1));
    expect(d.paylasilan, ['borc_alacak.xlsx']);
    expect(d.paylasilanBaytlar.single, [9, 9, 9]);
  });

  testWidgets('GOREV GECMISI CSV: tum sayfalar, web sutunlari, tamamlayan adi, formul kacisi',
      (t) async {
    final d = _Dunya();
    await t.pumpWidget(d.uygulama(const RaporMerkeziScreen()));
    await _pump(t);
    await t.scrollUntilVisible(find.byKey(const Key('rpr-gorev-gecmisi')), 200,
        scrollable: find.byType(Scrollable).at(1));
    await t.tap(find.byKey(const Key('rpr-gorev-gecmisi')));
    await _pump(t);
    await t.tap(find.byKey(const Key('gg-paylas')));
    await _pump(t);
    expect(d.yol('GET', '/task-completions'), hasLength(2), reason: 'iki sayfa');
    expect(d.paylasilan, ['gorev-gecmisi.csv']);
    final metin = utf8.decode(d.paylasilanBaytlar.single.skip(3).toList());
    final satirlar = metin.trim().split('\n');
    expect(satirlar.first, 'Görev,Tip,Tamamlayan,Zaman,Foto,NFC,Not');
    expect(satirlar, hasLength(202));
    expect(satirlar[1], startsWith('"\'=HYPERLINK(""x"")",Temizlik,Ahmet YILMAZ,'));
    expect(satirlar[1], endsWith(',var,Hayır,"not, virgüllü"'));
  });

  testWidgets('ICRA: salt okuma liste + durum suzgeci sunucuya gider', (t) async {
    final d = _Dunya();
    await t.pumpWidget(d.uygulama(const IcraScreen()));
    await _pump(t);
    expect(find.textContaining('2026/12'), findsOneWidget);
    expect(find.textContaining('3.500'), findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('icra-suzgec-kapandi')));
    await t.tap(find.byKey(const Key('icra-suzgec-kapandi')));
    await _pump(t);
    expect(d.yol('GET', '/finans/icra-dosyalari').last.queryParameters['durum'], 'kapandi');
    expect(find.textContaining('2026/12'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing, reason: 'salt okuma');
  });

  test('DENETCI menusu: yalniz salt okuma girisleri', () {
    expect(homeMenuForRole(UserRole.denetci),
        [HomeMenuEntry.reports, HomeMenuEntry.transparency, HomeMenuEntry.icra, HomeMenuEntry.bakim]);
    expect(UserRole.denetci.canPublishTransparency, isFalse);
    expect(UserRole.denetci.canViewTransparency, isTrue);
  });

  testWidgets('DENETCI rapor merkezi: aylik ozet (yonetim uclari) ve gorev gecmisi YOK',
      (t) async {
    final d = _Dunya();
    await t.pumpWidget(d.uygulama(const RaporMerkeziScreen(), rol: UserRole.denetci));
    await _pump(t);
    expect(find.text('Kasa Ekstresi'), findsOneWidget);
    expect(find.byKey(const Key('rpr-aylik')), findsNothing);
    expect(find.byKey(const Key('rpr-gorev-gecmisi')), findsNothing);
  });

  test('TR metinler web sozluguyle ayni (rapor alanlari)', () {
    final tr = lookupAppLocalizations(const Locale('tr'));
    expect(alanTanimlari['ismi_goster']!.etiket(tr), 'Ad sütunu');
    expect(alanTanimlari['listeleme_tipi']!.secenekler.first.etiket(tr), 'Borçlular');
  });
}
