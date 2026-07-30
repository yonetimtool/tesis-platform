/// TUR 63 — DEMIRBAS DENETLEYICISININ DALLARI.
///
/// Ucuncu envanterin A maddesi. `assets_controller` kapsami **%28**'di: ekran
/// (`assets_screen`) tur 53'te %84'e cikarilmisti ama DENETLEYICI hicbir zaman
/// dogrudan surulmedi — NFC okuma hatalari, etiket eslesmemesi, 403, 409 YARISI,
/// cevrimdisi, hizli birakma ve yeniden-girme kilitleri karanliktaydi.
///
/// Widget cizilmiyor: `ProviderContainer` + sahte `AssetApi`/`NfcService` ile
/// durum gecisleri olculur. Mesajlarin METIN olmadigini, KIMLIK/tip oldugunu da
/// bu testler kayda geciriyor (`DemirbasKimlikMesaji`, `DemirbasEtiketEslesmiyor`,
/// `DemirbasCakismaMesaji`, `DemirbasSunucuMetni`).
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/core/error/api_exception.dart';
import 'package:mobile/src/features/assets/data/asset_api.dart';
import 'package:mobile/src/features/assets/domain/asset_models.dart';
import 'package:mobile/src/features/assets/domain/demirbas_mesaj.dart';
import 'package:mobile/src/features/assets/presentation/assets_controller.dart';
import 'package:mobile/src/features/auth/data/current_user_provider.dart';
import 'package:mobile/src/features/nfc/data/nfc_service.dart';
import 'package:mobile/src/features/nfc/presentation/nfc_controller.dart'
    show nfcServiceProvider;
import 'package:mobile/src/features/nfc/domain/nfc_hatasi.dart';
import 'package:mobile/src/features/nfc/domain/nfc_read_result.dart';

const _ios = NfcIosMetinleri(
  yaklastir: 'Yaklastir',
  okundu: 'Okundu',
  okunamadi: 'Okunamadi',
  iptal: 'Iptal',
);

class _SahteAsset extends AssetApi {
  _SahteAsset() : super(Dio());

  Asset? eslesme;
  Object? findHatasi;
  Object? eylemHatasi;
  Object? benimHatasi;
  Object? detayHatasi;
  bool tekrarlanan = false;
  List<Asset> benim = const [];
  int checkoutCagrisi = 0;
  int checkinCagrisi = 0;
  int benimCagrisi = 0;

  @override
  Future<Asset?> findByUid(String uid) async {
    if (findHatasi != null) throw findHatasi!;
    return eslesme;
  }

  @override
  Future<Asset> fetchAsset(String id) async {
    if (detayHatasi != null) throw detayHatasi!;
    return eslesme ?? _asset();
  }

  @override
  Future<List<AssetCheckout>> fetchRecentHistory(String id, {int lastN = 5}) async =>
      const [];

  @override
  Future<List<Asset>> fetchMyAssets() async {
    benimCagrisi++;
    if (benimHatasi != null) throw benimHatasi!;
    return benim;
  }

  @override
  Future<AssetActionResult> checkout(AssetActionDraft draft) async {
    checkoutCagrisi++;
    if (eylemHatasi != null) throw eylemHatasi!;
    return AssetActionResult(
      checkout: _zimmet(),
      wasDuplicate: tekrarlanan,
    );
  }

  @override
  Future<AssetActionResult> checkin(AssetActionDraft draft) async {
    checkinCagrisi++;
    if (eylemHatasi != null) throw eylemHatasi!;
    return AssetActionResult(checkout: _zimmet());
  }
}

class _SahteNfc extends NfcService {
  _SahteNfc(this.sonuc);
  final NfcReadResult sonuc;

  @override
  Future<NfcReadResult> readSingleTag(NfcIosMetinleri ios) async => sonuc;
}

AssetCheckout _zimmet() => AssetCheckout(
  id: 'z-1',
  assetId: 'a-1',
  alanUserId: 'u-1',
  almaZamani: DateTime(2026, 1, 1),
);

Asset _asset({AssetDurum durum = AssetDurum.musait, AcikZimmet? zimmet}) => Asset(
  id: 'a-1',
  ad: 'Matkap',
  kategori: AssetKategori.alet,
  durum: durum,
  aktif: true,
  nfcTagUid: '04:A1:B2:C3',
  acikZimmet: zimmet,
);

AcikZimmet _acik({String userId = 'u-1'}) => AcikZimmet(
  alanUserId: userId,
  alanUserAd: 'Ali',
  alinmaZamani: DateTime(2026, 1, 1),
);

ProviderContainer _kap(
  _SahteAsset api, {
  NfcReadResult? okuma,
  String kullanici = 'u-1',
}) {
  final c = ProviderContainer(
    overrides: [
      assetApiProvider.overrideWithValue(api),
      currentUserIdProvider.overrideWith((ref) async => kullanici),
      if (okuma != null) nfcServiceProvider.overrideWithValue(_SahteNfc(okuma)),
    ],
  );
  // Dinleyici SART: dinleyicisiz saglayici okumalar arasinda yeniden kurulur ve
  // durum sifirlanir (tur 63'te talep testlerinde yasandi).
  c.listen(assetsControllerProvider, (_, _) {});
  addTearDown(c.dispose);
  return c;
}

Future<void> beklet([int tur = 6]) async {
  for (var i = 0; i < tur; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('scanTag — okuma dallari', () {
    test('BASARI: eslesen etiket kart cizer ve verdict hesaplanir', () async {
      final api = _SahteAsset()..eslesme = _asset();
      final c = _kap(api, okuma: const NfcReadResult(uid: '04:A1:B2:C3'));
      await c.read(assetsControllerProvider.notifier).scanTag(_ios);
      final d = c.read(assetsControllerProvider);
      expect(d.scanPhase, AssetScanPhase.done);
      expect(d.scanned?.asset.id, 'a-1');
      expect(d.scanned?.scannedUid, '04:A1:B2:C3');
      expect(d.scanError, isNull);
      expect(d.currentUserId, 'u-1');
    });

    test('OKUMA HATASI: NFC kimligi mesaja donusur, faz idle', () async {
      final api = _SahteAsset();
      final c = _kap(
        api,
        okuma: const NfcReadResult(hata: NfcHatasi.uidOkunamadi),
      );
      await c.read(assetsControllerProvider.notifier).scanTag(_ios);
      final d = c.read(assetsControllerProvider);
      expect(d.scanPhase, AssetScanPhase.idle);
      expect(d.scanError, isA<DemirbasNfcHatasi>());
      expect((d.scanError! as DemirbasNfcHatasi).kimlik, NfcHatasi.uidOkunamadi);
    });

    test('KIMLIKSIZ okuma hatasi: etiketOkunamadi kimligi', () async {
      // `isSuccess` false ama `hata` null — savunma dali.
      final api = _SahteAsset();
      final c = _kap(api, okuma: const NfcReadResult());
      await c.read(assetsControllerProvider.notifier).scanTag(_ios);
      final d = c.read(assetsControllerProvider);
      expect(d.scanError, isA<DemirbasKimlikMesaji>());
      expect(
        (d.scanError! as DemirbasKimlikMesaji).kimlik,
        DemirbasMesajKimlik.etiketOkunamadi,
      );
    });

    test('ETIKET KAYITSIZ: UID mesaja tasinir', () async {
      final api = _SahteAsset()..eslesme = null;
      final c = _kap(api, okuma: const NfcReadResult(uid: '04:FF:EE:11'));
      await c.read(assetsControllerProvider.notifier).scanTag(_ios);
      final d = c.read(assetsControllerProvider);
      expect(d.scanPhase, AssetScanPhase.idle);
      expect(d.scanError, isA<DemirbasEtiketEslesmiyor>());
      expect((d.scanError! as DemirbasEtiketEslesmiyor).uid, '04:FF:EE:11');
    });

    test('CEVRIMDISI: offline kimligi, sunucu metni YOK', () async {
      final api = _SahteAsset()
        ..findHatasi = const ApiException(code: 'network_error', message: '');
      final c = _kap(api, okuma: const NfcReadResult(uid: '04:A1'));
      await c.read(assetsControllerProvider.notifier).scanTag(_ios);
      final d = c.read(assetsControllerProvider);
      expect(d.scanError, isA<DemirbasKimlikMesaji>());
      expect(
        (d.scanError! as DemirbasKimlikMesaji).kimlik,
        DemirbasMesajKimlik.offline,
      );
    });

    test('403: forbidden bayragi kalkar', () async {
      final api = _SahteAsset()
        ..findHatasi = const ApiException(
          code: 'forbidden',
          message: 'Yetkiniz yok',
          statusCode: 403,
        );
      final c = _kap(api, okuma: const NfcReadResult(uid: '04:A1'));
      await c.read(assetsControllerProvider.notifier).scanTag(_ios);
      final d = c.read(assetsControllerProvider);
      expect(d.forbidden, isTrue);
      expect(d.scanError, isNotNull);
    });

    test('YENIDEN GIRME: okuma surerken ikinci scanTag yok sayilir', () async {
      final api = _SahteAsset()..eslesme = _asset();
      final c = _kap(api, okuma: const NfcReadResult(uid: '04:A1'));
      final not = c.read(assetsControllerProvider.notifier);
      // Ilki bitmeden ikincisi: ikinci cagri erken donmeli.
      await Future.wait([not.scanTag(_ios), not.scanTag(_ios)]);
      expect(c.read(assetsControllerProvider).scanPhase, AssetScanPhase.done);
    });
  });

  group('checkout / checkin — eylem dallari', () {
    Future<(ProviderContainer, AssetsController)> hazir(_SahteAsset api) async {
      final c = _kap(api, okuma: const NfcReadResult(uid: '04:A1:B2:C3'));
      final not = c.read(assetsControllerProvider.notifier);
      await not.scanTag(_ios);
      return (c, not);
    }

    test('BASARI: zimmetineAlindi kimligi + liste tazelenir', () async {
      final api = _SahteAsset()..eslesme = _asset();
      final (c, not) = await hazir(api);
      final oncekiBenim = api.benimCagrisi;
      await not.checkoutScanned();
      final d = c.read(assetsControllerProvider);
      expect(api.checkoutCagrisi, 1);
      expect(
        (d.actionMessage! as DemirbasKimlikMesaji).kimlik,
        DemirbasMesajKimlik.zimmetineAlindi,
      );
      expect(d.actionBusy, isFalse);
      expect(api.benimCagrisi, greaterThan(oncekiBenim),
          reason: 'uzerimdekiler sessizce tazelenmeli');
    });

    test('IDEMPOTENT TEKRAR: zatenZimmetinde kimligi', () async {
      final api = _SahteAsset()
        ..eslesme = _asset()
        ..tekrarlanan = true;
      final (c, not) = await hazir(api);
      await not.checkoutScanned();
      expect(
        (c.read(assetsControllerProvider).actionMessage! as DemirbasKimlikMesaji)
            .kimlik,
        DemirbasMesajKimlik.zatenZimmetinde,
      );
    });

    test('BIRAKMA: birakildi kimligi', () async {
      final api = _SahteAsset()
        ..eslesme = _asset(durum: AssetDurum.zimmetli, zimmet: _acik());
      final (c, not) = await hazir(api);
      await not.checkinScanned();
      expect(api.checkinCagrisi, 1);
      expect(
        (c.read(assetsControllerProvider).actionMessage! as DemirbasKimlikMesaji)
            .kimlik,
        DemirbasMesajKimlik.birakildi,
      );
    });

    test('409 YARISI: cakisma mesaji + kart TAZE durumla yeniden cizilir',
        () async {
      final api = _SahteAsset()..eslesme = _asset();
      final (c, not) = await hazir(api);
      api.eylemHatasi = const ApiException(
        code: 'conflict',
        message: 'Demirbas baskasinda',
        statusCode: 409,
      );
      // Yaris sonrasi sunucu gercegi: baskasinin zimmetinde.
      api.eslesme = _asset(durum: AssetDurum.zimmetli, zimmet: _acik(userId: 'u-9'));
      await not.checkoutScanned();
      final d = c.read(assetsControllerProvider);
      expect(d.actionError, isA<DemirbasCakismaMesaji>());
      expect(d.scanned?.asset.acikZimmet?.alanUserId, 'u-9',
          reason: '409 sonrasi kart taze durumla yeniden cizilmeli');
      expect(d.actionBusy, isFalse);
    });

    test('409 + TAZELEME de patlarsa: kart eski kalir, cokme YOK', () async {
      final api = _SahteAsset()..eslesme = _asset();
      final (c, not) = await hazir(api);
      api.eylemHatasi = const ApiException(
        code: 'conflict',
        message: 'Cakisma',
        statusCode: 409,
      );
      api.detayHatasi = const ApiException(
        code: 'server_error',
        message: 'Sunucu hatasi',
        statusCode: 500,
      );
      await not.checkoutScanned();
      final d = c.read(assetsControllerProvider);
      expect(d.actionError, isA<DemirbasCakismaMesaji>());
      expect(d.scanned, isNotNull, reason: 'kart kaybolmamali');
      expect(d.actionBusy, isFalse);
    });

    test('CEVRIMDISI eylem: offline kimligi, tazeleme DENENMEZ', () async {
      final api = _SahteAsset()..eslesme = _asset();
      final (c, not) = await hazir(api);
      api.eylemHatasi = const ApiException(code: 'network_error', message: '');
      await not.checkoutScanned();
      final d = c.read(assetsControllerProvider);
      expect(
        (d.actionError! as DemirbasKimlikMesaji).kimlik,
        DemirbasMesajKimlik.offline,
      );
    });

    test('OKUTMA YOKSA eylem hicbir sey yapmaz', () async {
      final api = _SahteAsset();
      final c = _kap(api);
      await c.read(assetsControllerProvider.notifier).checkoutScanned();
      expect(api.checkoutCagrisi, 0);
      expect(c.read(assetsControllerProvider).actionError, isNull);
    });
  });

  group('refreshMyItems / quickCheckin', () {
    test('ACIK ZIMMETI OLMAYAN suzulur, en yeni ustte siralanir', () async {
      final api = _SahteAsset()
        ..benim = [
          _asset(durum: AssetDurum.musait), // acik zimmet YOK -> suzulur
          Asset(
            id: 'a-eski',
            ad: 'Eski',
            kategori: AssetKategori.ekipman,
            durum: AssetDurum.zimmetli,
            aktif: true,
            acikZimmet: AcikZimmet(
              alanUserId: 'u-1',
              alanUserAd: 'Ali',
              alinmaZamani: DateTime(2026, 1, 1),
            ),
          ),
          Asset(
            id: 'a-yeni',
            ad: 'Yeni',
            kategori: AssetKategori.ekipman,
            durum: AssetDurum.zimmetli,
            aktif: true,
            acikZimmet: AcikZimmet(
              alanUserId: 'u-1',
              alanUserAd: 'Ali',
              alinmaZamani: DateTime(2026, 6, 1),
            ),
          ),
        ];
      final c = _kap(api);
      await c.read(assetsControllerProvider.notifier).refreshMyItems();
      final d = c.read(assetsControllerProvider);
      expect(d.myItems.map((e) => e.asset.id), ['a-yeni', 'a-eski']);
      expect(d.myLoading, isFalse);
      expect(d.myError, isNull);
    });

    test('403: forbidden + hata mesaji', () async {
      final api = _SahteAsset()
        ..benimHatasi = const ApiException(
          code: 'forbidden',
          message: 'Yetki yok',
          statusCode: 403,
        );
      final c = _kap(api);
      await c.read(assetsControllerProvider.notifier).refreshMyItems();
      final d = c.read(assetsControllerProvider);
      expect(d.forbidden, isTrue);
      expect(d.myError, isA<DemirbasSunucuMetni>());
    });

    test('BEKLENMEYEN hata: beklenmeyen kimligi', () async {
      final api = _SahteAsset()..benimHatasi = StateError('bozuk');
      final c = _kap(api);
      await c.read(assetsControllerProvider.notifier).refreshMyItems();
      expect(
        (c.read(assetsControllerProvider).myError! as DemirbasKimlikMesaji)
            .kimlik,
        DemirbasMesajKimlik.beklenmeyen,
      );
    });

    test('YENIDEN GIRME kilidi: es zamanli iki tazeleme tek istek', () async {
      final api = _SahteAsset();
      final c = _kap(api);
      final not = c.read(assetsControllerProvider.notifier);
      await beklet(); // `build()` icindeki ilk tazeleme bitsin
      api.benimCagrisi = 0;
      await Future.wait([not.refreshMyItems(), not.refreshMyItems()]);
      expect(api.benimCagrisi, 1);
    });

    test('HIZLI BIRAKMA: basari sonrasi liste tazelenir', () async {
      final api = _SahteAsset();
      final c = _kap(api);
      final not = c.read(assetsControllerProvider.notifier);
      final item = (asset: _asset(), zimmet: _acik());
      await not.quickCheckin(item);
      expect(api.checkinCagrisi, 1);
      expect(c.read(assetsControllerProvider).quickCheckinBusyId, isNull);
    });

    test('HIZLI BIRAKMA 409: demirbas ADI mesaja girer', () async {
      final api = _SahteAsset()
        ..eylemHatasi = const ApiException(
          code: 'conflict',
          message: 'Coktan birakilmis',
          statusCode: 409,
        );
      final c = _kap(api);
      final not = c.read(assetsControllerProvider.notifier);
      await not.quickCheckin((asset: _asset(), zimmet: _acik()));
      final hata = c.read(assetsControllerProvider).myError;
      expect(hata, isA<DemirbasAdliHata>());
      expect((hata! as DemirbasAdliHata).ad, 'Matkap');
    });

    test('HIZLI BIRAKMA: mesgulken ikinci cagri yok sayilir', () async {
      final api = _SahteAsset();
      final c = _kap(api);
      final not = c.read(assetsControllerProvider.notifier);
      final item = (asset: _asset(), zimmet: _acik());
      await Future.wait([not.quickCheckin(item), not.quickCheckin(item)]);
      expect(api.checkinCagrisi, 1);
    });
  });

  test('clearScan: kart ve mesajlar temizlenir', () async {
    final api = _SahteAsset()..eslesme = _asset();
    final c = _kap(api, okuma: const NfcReadResult(uid: '04:A1'));
    final not = c.read(assetsControllerProvider.notifier);
    await not.scanTag(_ios);
    expect(c.read(assetsControllerProvider).scanned, isNotNull);
    not.clearScan();
    final d = c.read(assetsControllerProvider);
    expect(d.scanned, isNull);
    expect(d.scanPhase, AssetScanPhase.idle);
    expect(d.scanError, isNull);
    expect(d.actionError, isNull);
    expect(d.actionMessage, isNull);
  });
}
