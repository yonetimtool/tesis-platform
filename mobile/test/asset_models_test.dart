import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/features/assets/domain/asset_models.dart';

/// Demirbas zimmet modulunun domain modelleri — `contracts/openapi.yaml`
/// Asset (acik_zimmet dahil) / AssetCheckout / Checkout-CheckinRequest
/// semalarina uyar. (§13 bulgulari kapandiktan sonraki SADE akis: UID cozumu
/// ve acik zimmet SUNUCUDAN gelir; istemci indeksi/history taramasi yok.)
void main() {
  group('Asset.fromJson', () {
    test('acik_zimmet null → kimsede degil', () {
      final a = Asset.fromJson({
        'id': 'a-1',
        'ad': 'Cim bicme makinesi',
        'kategori': 'ekipman',
        'nfc_tag_uid': '04:AA:BB:CC:DD:EE',
        'durum': 'musait',
        'aciklama': 'Depo 2',
        'aktif': true,
        'acik_zimmet': null,
        'created_at': '2026-07-01T08:00:00Z',
      });
      expect(a.id, 'a-1');
      expect(a.kategori, AssetKategori.ekipman);
      expect(a.durum, AssetDurum.musait);
      expect(a.acikZimmet, isNull);
    });

    test('acik_zimmet dolu → sahibi ad + id + zamanla gelir (§13 #2/#5)', () {
      final a = Asset.fromJson({
        'id': 'a-1',
        'ad': 'Matkap',
        'kategori': 'alet',
        'durum': 'zimmetli',
        'aktif': true,
        'acik_zimmet': {
          'alan_user_id': 'user-2',
          'alan_user_ad': 'Ahmet',
          'alinma_zamani': '2026-07-03T08:00:00Z',
        },
        'created_at': '2026-07-01T08:00:00Z',
      });
      expect(a.acikZimmet, isNotNull);
      expect(a.acikZimmet!.alanUserId, 'user-2');
      expect(a.acikZimmet!.alanUserAd, 'Ahmet');
      expect(a.acikZimmet!.alinmaZamani, DateTime.utc(2026, 7, 3, 8));
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

  test('AssetCheckout.fromJson: alan_user_ad eslenir; birakma_zamani null → '
      'acik zimmet', () {
    final acik = AssetCheckout.fromJson({
      'id': 'c-1',
      'asset_id': 'a-1',
      'alan_user_id': 'user-2',
      'alan_user_ad': 'Ahmet',
      'alma_zamani': '2026-07-03T08:00:00Z',
      'birakma_zamani': null,
      'idempotency_key': 'k',
      'created_at': '2026-07-03T08:00:00Z',
    });
    expect(acik.isOpen, isTrue);
    expect(acik.alanUserAd, 'Ahmet');

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
    expect(kapali.alanUserAd, isNull); // ad opsiyonel — eski kayitlar
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

  group('zimmetVerdict — durum makinesi (acik_zimmet sunucudan)', () {
    final asset = Asset(
      id: 'a-1',
      ad: 'Matkap',
      kategori: AssetKategori.alet,
      durum: AssetDurum.musait,
      aktif: true,
    );
    final zimmet = AcikZimmet(
      alanUserId: 'user-1',
      alanUserAd: 'Guard A',
      alinmaZamani: DateTime.utc(2026, 7, 3, 8),
    );

    test('musait → kimsedeDegil', () {
      expect(
        zimmetVerdict(asset: asset, acikZimmet: null, myUserId: 'user-1'),
        ZimmetVerdict.kimsedeDegil,
      );
    });

    test('zimmetli + acik zimmet bende → sende', () {
      expect(
        zimmetVerdict(
          asset: asset.copyWith(durum: AssetDurum.zimmetli),
          acikZimmet: zimmet,
          myUserId: 'user-1',
        ),
        ZimmetVerdict.sende,
      );
    });

    test('zimmetli + acik zimmet baskasinda → baskasinda', () {
      expect(
        zimmetVerdict(
          asset: asset.copyWith(durum: AssetDurum.zimmetli),
          acikZimmet: zimmet,
          myUserId: 'user-99',
        ),
        ZimmetVerdict.baskasinda,
      );
    });

    test('zimmetli ama acik_zimmet null geldi → baskasinda (temkinli)', () {
      expect(
        zimmetVerdict(
          asset: asset.copyWith(durum: AssetDurum.zimmetli),
          acikZimmet: null,
          myUserId: 'user-1',
        ),
        ZimmetVerdict.baskasinda,
      );
    });

    test('bakimda → bakimda (aksiyon yok)', () {
      expect(
        zimmetVerdict(
          asset: asset.copyWith(durum: AssetDurum.bakimda),
          acikZimmet: null,
          myUserId: 'user-1',
        ),
        ZimmetVerdict.bakimda,
      );
    });
  });
}
