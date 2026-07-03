/// Demirbas zimmet modulunun domain modelleri — `contracts/openapi.yaml`
/// Asset / AssetCheckout / CheckoutRequest / CheckinRequest semalarina uyar.
///
/// SOZLESME NOTLARI (dogrulandi, uydurma yok — detay README §13):
///   * `GET /assets`'ta `nfc_tag_uid` aramasi YOK → UID→asset cozumu
///     istemcide: aktif liste cekilir, normalize UID indeksiyle eslestirilir
///     ([buildUidIndex]/[lookupByUid]).
///   * Asset semasinda "KIMDE" bilgisi YOK (yalnizca durum enum'u) → acik
///     zimmet `GET /assets/{id}/history`'den bulunur (birakma_zamani NULL).
///     History `alma_zamani` ASC sirali (backend dogrulandi) → acik kayit
///     SON sayfadadir.
///   * "Uzerimdekiler" filtresi YOK (`checked_out_by=me` gibi) → istemcide
///     zimmetli asset'lerin acik zimmetleri taranarak suzulur.
///   * checkout: 201 yeni / 200 idempotent / 409 "zaten zimmetli" (yaris);
///     checkin: HEP 200 (kapatma + idempotent tekrar ayni kod) / 409 "acik
///     zimmet yok". Her ikisinde Idempotency-Key ZORUNLU; `nfc_tag_uid`
///     verilirse asset ile eslesmeli (422).
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
  });

  final String id;
  final String ad;
  final AssetKategori kategori;

  /// Demirbasin uzerindeki NFC etiketi (tenant icinde benzersiz; olmayabilir).
  final String? nfcTagUid;

  final AssetDurum durum;
  final String? aciklama;
  final bool aktif;

  Asset copyWith({AssetDurum? durum}) => Asset(
        id: id,
        ad: ad,
        kategori: kategori,
        durum: durum ?? this.durum,
        aktif: aktif,
        nfcTagUid: nfcTagUid,
        aciklama: aciklama,
      );

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
        id: json['id'] as String,
        ad: json['ad'] as String? ?? '',
        kategori: assetKategoriFromJson(json['kategori'] as String?),
        nfcTagUid: json['nfc_tag_uid'] as String?,
        durum: assetDurumFromJson(json['durum'] as String?),
        aciklama: json['aciklama'] as String?,
        aktif: json['aktif'] as bool? ?? true,
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
    this.birakmaZamani,
    this.notlar,
  });

  final String id;
  final String assetId;
  final String alanUserId;
  final DateTime almaZamani;
  final DateTime? birakmaZamani;
  final String? notlar;

  bool get isOpen => birakmaZamani == null;

  factory AssetCheckout.fromJson(Map<String, dynamic> json) => AssetCheckout(
        id: json['id'] as String,
        assetId: json['asset_id'] as String,
        alanUserId: json['alan_user_id'] as String,
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

/// Listedeki ACIK zimmeti dondurur (en fazla bir tane olabilir; yoksa null).
AssetCheckout? findOpenCheckout(List<AssetCheckout> history) {
  for (final co in history) {
    if (co.isOpen) return co;
  }
  return null;
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

/// Sunucu durumu + acik zimmet + benim kimligimden karar uretir.
/// `zimmetli` ama acik kayit cozulemediyse TEMKINLI davranilir
/// (baskasinda say — yanlis "al" butonu gostermekten iyidir).
ZimmetVerdict zimmetVerdict({
  required Asset asset,
  required AssetCheckout? openCheckout,
  required String? myUserId,
}) {
  switch (asset.durum) {
    case AssetDurum.bakimda:
      return ZimmetVerdict.bakimda;
    case AssetDurum.musait:
      return ZimmetVerdict.kimsedeDegil;
    case AssetDurum.zimmetli:
    case AssetDurum.bilinmiyor:
      if (openCheckout != null &&
          myUserId != null &&
          openCheckout.alanUserId == myUserId) {
        return ZimmetVerdict.sende;
      }
      return ZimmetVerdict.baskasinda;
  }
}

String _normalizeUid(String uid) => uid.trim().toUpperCase();

/// Aktif asset listesinden normalize-UID → asset indeksi kurar (UID'siz
/// asset'ler girmez). `GET /assets`'ta UID aramasi olmadigi icin etiket
/// cozumu bu indeksle istemcide yapilir.
Map<String, Asset> buildUidIndex(List<Asset> assets) => {
      for (final a in assets)
        if (a.nfcTagUid != null && a.nfcTagUid!.trim().isNotEmpty)
          _normalizeUid(a.nfcTagUid!): a,
    };

/// Okutulan UID'yi indekste arar (buyuk/kucuk harf ve bosluk duyarsiz).
Asset? lookupByUid(Map<String, Asset> index, String uid) =>
    index[_normalizeUid(uid)];
