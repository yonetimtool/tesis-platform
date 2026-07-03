import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/assets/domain/asset_models.dart';

/// Demirbas zimmet modulunun domain modelleri — `contracts/openapi.yaml`
/// Asset / AssetCheckout / CheckoutRequest / CheckinRequest semalarina uyar.
void main() {
  group('Asset.fromJson', () {
    test('tum alanlar eslenir', () {
      final a = Asset.fromJson({
        'id': 'a-1',
        'ad': 'Cim bicme makinesi',
        'kategori': 'ekipman',
        'nfc_tag_uid': '04:AA:BB:CC:DD:EE',
        'durum': 'zimmetli',
        'aciklama': 'Depo 2',
        'aktif': true,
        'created_at': '2026-07-01T08:00:00Z',
      });
      expect(a.id, 'a-1');
      expect(a.ad, 'Cim bicme makinesi');
      expect(a.kategori, AssetKategori.ekipman);
      expect(a.durum, AssetDurum.zimmetli);
      expect(a.nfcTagUid, '04:AA:BB:CC:DD:EE');
    });

    test('bilinmeyen kategori/durum guvenli fallback (cokme yok)', () {
      final a = Asset.fromJson({
        'id': 'a-2',
        'ad': 'X',
        'kategori': 'robot',
        'durum': 'kayip',
        'aktif': true,
        'created_at': '2026-07-01T08:00:00Z',
      });
      expect(a.kategori, AssetKategori.bilinmiyor);
      expect(a.durum, AssetDurum.bilinmiyor);
    });
  });

  test('AssetCheckout.fromJson: birakma_zamani null → acik zimmet', () {
    final acik = AssetCheckout.fromJson({
      'id': 'c-1',
      'asset_id': 'a-1',
      'alan_user_id': 'user-2',
      'alma_zamani': '2026-07-03T08:00:00Z',
      'birakma_zamani': null,
      'idempotency_key': 'k',
      'created_at': '2026-07-03T08:00:00Z',
    });
    expect(acik.isOpen, isTrue);
    expect(acik.alanUserId, 'user-2');
    expect(acik.almaZamani, DateTime.utc(2026, 7, 3, 8));

    final kapali = AssetCheckout.fromJson({
      'id': 'c-2',
      'asset_id': 'a-1',
      'alan_user_id': 'user-2',
      'alma_zamani': '2026-07-03T08:00:00Z',
      'birakma_zamani': '2026-07-03T10:00:00Z',
      'idempotency_key': 'k2',
      'created_at': '2026-07-03T08:00:00Z',
    });
    expect(kapali.isOpen, isFalse);
    expect(kapali.birakmaZamani, DateTime.utc(2026, 7, 3, 10));
  });

  group('AssetActionDraft', () {
    final an = DateTime.utc(2026, 7, 3, 12, 0);

    test('idempotency key islem aninda sabit; alma/birakma ayri anahtar '
        'uretir', () {
      final alma = AssetActionDraft.checkout(
        assetId: 'a-1',
        islemAni: an,
        nfcTagUid: '04:AA:BB:CC:DD:EE',
      );
      final birakma = AssetActionDraft.checkin(
        assetId: 'a-1',
        islemAni: an,
        nfcTagUid: '04:AA:BB:CC:DD:EE',
      );
      expect(alma.idempotencyKey, isNot(birakma.idempotencyKey));
      // Ayni parametrelerle deterministik (retry ayni istegi atar).
      expect(
        AssetActionDraft.checkout(assetId: 'a-1', islemAni: an).idempotencyKey,
        alma.idempotencyKey,
      );
      expect(alma.idempotencyKey.length, greaterThanOrEqualTo(8));
      expect(alma.idempotencyKey.length, lessThanOrEqualTo(200));
    });

    test('toJson yalnizca dolu alanlar (Checkout/CheckinRequest)', () {
      expect(
        AssetActionDraft.checkout(assetId: 'a-1', islemAni: an).toJson(),
        isEmpty,
      );
      expect(
        AssetActionDraft.checkout(
          assetId: 'a-1',
          islemAni: an,
          nfcTagUid: '04:AA',
        ).toJson(),
        {'nfc_tag_uid': '04:AA'},
      );
    });
  });

  test('findOpenCheckout: listedeki acik zimmeti bulur (yoksa null)', () {
    AssetCheckout co(String id, {DateTime? birakma}) => AssetCheckout(
          id: id,
          assetId: 'a-1',
          alanUserId: 'u-1',
          almaZamani: DateTime.utc(2026, 7, 3, 8),
          birakmaZamani: birakma,
        );
    expect(findOpenCheckout([]), isNull);
    expect(
      findOpenCheckout([co('c1', birakma: DateTime.utc(2026, 7, 3, 9))]),
      isNull,
    );
    expect(
      findOpenCheckout([
        co('c1', birakma: DateTime.utc(2026, 7, 3, 9)),
        co('c2'),
      ])?.id,
      'c2',
    );
  });

  group('zimmetVerdict — durum makinesi', () {
    final asset = Asset(
      id: 'a-1',
      ad: 'Matkap',
      kategori: AssetKategori.alet,
      durum: AssetDurum.musait,
      aktif: true,
    );
    final open = AssetCheckout(
      id: 'c-1',
      assetId: 'a-1',
      alanUserId: 'user-1',
      almaZamani: DateTime.utc(2026, 7, 3, 8),
    );

    test('musait → kimsedeDegil (acik zimmet olmasa da)', () {
      expect(
        zimmetVerdict(asset: asset, openCheckout: null, myUserId: 'user-1'),
        ZimmetVerdict.kimsedeDegil,
      );
    });

    test('zimmetli + acik zimmet bende → sende', () {
      expect(
        zimmetVerdict(
          asset: asset.copyWith(durum: AssetDurum.zimmetli),
          openCheckout: open,
          myUserId: 'user-1',
        ),
        ZimmetVerdict.sende,
      );
    });

    test('zimmetli + acik zimmet baskasinda → baskasinda', () {
      expect(
        zimmetVerdict(
          asset: asset.copyWith(durum: AssetDurum.zimmetli),
          openCheckout: open,
          myUserId: 'user-99',
        ),
        ZimmetVerdict.baskasinda,
      );
    });

    test('zimmetli ama acik zimmet cozulemedi → baskasinda (temkinli)', () {
      expect(
        zimmetVerdict(
          asset: asset.copyWith(durum: AssetDurum.zimmetli),
          openCheckout: null,
          myUserId: 'user-1',
        ),
        ZimmetVerdict.baskasinda,
      );
    });

    test('bakimda → bakimda (aksiyon yok)', () {
      expect(
        zimmetVerdict(
          asset: asset.copyWith(durum: AssetDurum.bakimda),
          openCheckout: null,
          myUserId: 'user-1',
        ),
        ZimmetVerdict.bakimda,
      );
    });
  });

  test('buildUidIndex + lookupByUid: buyuk/kucuk harf duyarsiz eslesme', () {
    final assets = [
      Asset(
        id: 'a-1',
        ad: 'Matkap',
        kategori: AssetKategori.alet,
        durum: AssetDurum.musait,
        aktif: true,
        nfcTagUid: '04:AA:BB:CC:DD:EE',
      ),
      Asset(
        id: 'a-2',
        ad: 'UID\'siz',
        kategori: AssetKategori.diger,
        durum: AssetDurum.musait,
        aktif: true,
      ),
    ];
    final index = buildUidIndex(assets);
    expect(index.length, 1); // UID'siz asset indekse girmez
    expect(lookupByUid(index, '04:aa:bb:cc:dd:ee')?.id, 'a-1');
    expect(lookupByUid(index, ' 04:AA:BB:CC:DD:EE '), isNotNull);
    expect(lookupByUid(index, 'FF:FF'), isNull);
  });
}
