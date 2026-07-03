/// Demirbas zimmet modulunun domain modelleri — `contracts/openapi.yaml`
/// Asset (acik_zimmet dahil) / AcikZimmet / AssetCheckout /
/// Checkout-CheckinRequest semalarina uyar.
///
/// VERI YOLU (§13 bulgulari KAPANDI — README §13):
///   * UID→asset: `GET /assets?nfc_tag_uid=...` TEK istek (tenant icinde
///     unique → 0/1 sonuc). Istemci UID indeksi kaldirildi.
///   * "Kimde": Asset yanitindaki `acik_zimmet` alanindan (alan_user_id +
///     alan_user_ad + alinma_zamani). History taramasi kaldirildi.
///   * "Uzerimdekiler": `GET /assets?checked_out_by=me` TEK istek.
///   * History varsayilan DESC (en yeni once) → son N dogrudan ilk sayfa.
///   * checkout: 201 yeni / 200 idempotent / 409 "zaten zimmetli" (yaris);
///     checkin: 200 / 409 "acik zimmet yok" / 403 sahiplik (yalniz sahibi
///     veya admin kapatabilir). Idempotency-Key her ikisinde ZORUNLU;
///     `nfc_tag_uid` verilirse asset ile eslesmeli (422).
library;

/// AssetKategori semasi. [bilinmiyor] sozlesme disi degerler icin fallback.
enum AssetKategori { ekipman, arac, alet, diger, bilinmiyor }

AssetKategori assetKategoriFromJson(String? value) => switch (value) {
      'ekipman' => AssetKategori.ekipman,
      'arac' => AssetKategori.arac,
      'alet' => AssetKategori.alet,
      'diger' => AssetKategori.diger,
      _ => AssetKategori.bilinmiyor,
    };

/// AssetDurum semasi. [bilinmiyor] sozlesme disi degerler icin fallback.
enum AssetDurum { musait, zimmetli, bakimda, bilinmiyor }

AssetDurum assetDurumFromJson(String? value) => switch (value) {
      'musait' => AssetDurum.musait,
      'zimmetli' => AssetDurum.zimmetli,
      'bakimda' => AssetDurum.bakimda,
      _ => AssetDurum.bilinmiyor,
    };

/// Asset yanitindaki ACIK zimmet ozeti (AcikZimmet semasi) — "kimde"
/// sorusunun tek-istek cevabi (§13 #2/#5 kapanisi).
class AcikZimmet {
  const AcikZimmet({
    required this.alanUserId,
    required this.alanUserAd,
    required this.alinmaZamani,
  });

  final String alanUserId;
  final String alanUserAd;
  final DateTime alinmaZamani;

  factory AcikZimmet.fromJson(Map<String, dynamic> json) => AcikZimmet(
        alanUserId: json['alan_user_id'] as String,
        alanUserAd: json['alan_user_ad'] as String? ?? '',
        alinmaZamani:
            DateTime.parse(json['alinma_zamani'] as String).toUtc(),
      );
}

/// `GET /assets` ogesi (Asset semasi).
class Asset {
  const Asset({
    required this.id,
    required this.ad,
    required this.kategori,
    required this.durum,
    required this.aktif,
    this.nfcTagUid,
    this.aciklama,
    this.acikZimmet,
  });

  final String id;
  final String ad;
  final AssetKategori kategori;

  /// Demirbasin uzerindeki NFC etiketi (tenant icinde benzersiz; olmayabilir).
  final String? nfcTagUid;

  final AssetDurum durum;
  final String? aciklama;
  final bool aktif;

  /// Acik zimmet ozeti; zimmetli degilse null.
  final AcikZimmet? acikZimmet;

  Asset copyWith({AssetDurum? durum}) => Asset(
        id: id,
        ad: ad,
        kategori: kategori,
        durum: durum ?? this.durum,
        aktif: aktif,
        nfcTagUid: nfcTagUid,
        aciklama: aciklama,
        acikZimmet: acikZimmet,
      );

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
        id: json['id'] as String,
        ad: json['ad'] as String? ?? '',
        kategori: assetKategoriFromJson(json['kategori'] as String?),
        nfcTagUid: json['nfc_tag_uid'] as String?,
        durum: assetDurumFromJson(json['durum'] as String?),
        aciklama: json['aciklama'] as String?,
        aktif: json['aktif'] as bool? ?? true,
        acikZimmet: json['acik_zimmet'] is Map
            ? AcikZimmet.fromJson(
                Map<String, dynamic>.from(json['acik_zimmet'] as Map),
              )
            : null,
      );
}

/// Zimmet kaydi (AssetCheckout semasi). `birakma_zamani` NULL → hala
/// uzerinde (ACIK zimmet).
class AssetCheckout {
  const AssetCheckout({
    required this.id,
    required this.assetId,
    required this.alanUserId,
    required this.almaZamani,
    this.alanUserAd,
    this.birakmaZamani,
    this.notlar,
  });

  final String id;
  final String assetId;
  final String alanUserId;

  /// Alan kullanicinin adi (§13 #5; eski kayitlarda bos olabilir).
  final String? alanUserAd;

  final DateTime almaZamani;
  final DateTime? birakmaZamani;
  final String? notlar;

  bool get isOpen => birakmaZamani == null;

  factory AssetCheckout.fromJson(Map<String, dynamic> json) => AssetCheckout(
        id: json['id'] as String,
        assetId: json['asset_id'] as String,
        alanUserId: json['alan_user_id'] as String,
        alanUserAd: json['alan_user_ad'] as String?,
        almaZamani: DateTime.parse(json['alma_zamani'] as String).toUtc(),
        birakmaZamani: json['birakma_zamani'] == null
            ? null
            : DateTime.parse(json['birakma_zamani'] as String).toUtc(),
        notlar: json['notlar'] as String?,
      );
}

/// Islem turu: al (checkout) / birak (checkin).
enum AssetActionTip { alma, birakma }

/// `POST /assets/{id}/checkout|checkin` istek govdesi + Idempotency-Key.
///
/// Anahtar, aksiyona BASILDIGI anda sabitlenen (tip, assetId, islemAni)
/// uclusunden deterministik turetilir: cift dokunus / ag hatasi sonrasi
/// tekrar AYNI istegi atar → backend 200-idempotent ile yutar.
class AssetActionDraft {
  const AssetActionDraft._({
    required this.tip,
    required this.assetId,
    required this.islemAni,
    this.nfcTagUid,
  });

  factory AssetActionDraft.checkout({
    required String assetId,
    required DateTime islemAni,
    String? nfcTagUid,
  }) =>
      AssetActionDraft._(
        tip: AssetActionTip.alma,
        assetId: assetId,
        islemAni: islemAni,
        nfcTagUid: nfcTagUid,
      );

  factory AssetActionDraft.checkin({
    required String assetId,
    required DateTime islemAni,
    String? nfcTagUid,
  }) =>
      AssetActionDraft._(
        tip: AssetActionTip.birakma,
        assetId: assetId,
        islemAni: islemAni,
        nfcTagUid: nfcTagUid,
      );

  final AssetActionTip tip;
  final String assetId;

  /// Aksiyon butonuna basilan an (UTC) — anahtarin parcasi.
  final DateTime islemAni;

  /// Okutulan etiket — verilirse backend asset'inkiyle eslesmesini dogrular.
  final String? nfcTagUid;

  String get idempotencyKey =>
      'asset-${tip.name}|$assetId|${islemAni.toUtc().toIso8601String()}';

  Map<String, dynamic> toJson() => {'nfc_tag_uid': ?nfcTagUid};
}

/// Islem sonucu: checkout 201 yeni / 200 idempotent tekrar. Checkin'de
/// backend HEP 200 dondurdugu icin ayrim yoktur ([wasDuplicate] false kalir).
class AssetActionResult {
  const AssetActionResult({required this.checkout, this.wasDuplicate = false});

  final AssetCheckout checkout;
  final bool wasDuplicate;
}

/// Okutulan demirbasin kullaniciya gore durumu (durum makinesi).
enum ZimmetVerdict {
  /// Musait — "Zimmetine al" gosterilir.
  kimsedeDegil,

  /// Acik zimmet BENDE — "Birak / iade et" gosterilir.
  sende,

  /// Baskasinin uzerinde — yalnizca bilgi (zorla alma YOK; o birakmali).
  baskasinda,

  /// Bakimda — aksiyon yok.
  bakimda,
}

/// Sunucu durumu + acik zimmet ozeti + benim kimligimden karar uretir.
/// `zimmetli` ama `acik_zimmet` null geldiyse TEMKINLI davranilir
/// (baskasinda say — yanlis "al" butonu gostermekten iyidir).
ZimmetVerdict zimmetVerdict({
  required Asset asset,
  required AcikZimmet? acikZimmet,
  required String? myUserId,
}) {
  switch (asset.durum) {
    case AssetDurum.bakimda:
      return ZimmetVerdict.bakimda;
    case AssetDurum.musait:
      return ZimmetVerdict.kimsedeDegil;
    case AssetDurum.zimmetli:
    case AssetDurum.bilinmiyor:
      if (acikZimmet != null &&
          myUserId != null &&
          acikZimmet.alanUserId == myUserId) {
        return ZimmetVerdict.sende;
      }
      return ZimmetVerdict.baskasinda;
  }
}
