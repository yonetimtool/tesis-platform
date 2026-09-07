import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/dio_provider.dart';
import 'dukkan_oturum.dart';

/// (DUKKAN F3) Kamu arama ve profil ucları — KIMLIK GEREKTIRMEZ.
///
/// =========================================================================
/// NEDEN JETONSUZ
/// =========================================================================
/// Dukkan'in arama ve profil uclari `security: []`. Mobilde de jeton
/// gerekmiyor: sakin uygulamayi acar acmaz bolgesindeki ustalari
/// gorebilmeli. Once Dukkan hesabi actirmak, kullaniciyi urunun degerini
/// GORMEDEN bir kayit formuna sokmak olurdu.
///
/// Talep olusturma (F4) jeton ister; o zaman SSO koprusu devreye girer.

class DukkanIsletme {
  const DukkanIsletme({
    required this.ad,
    required this.slug,
    required this.telefon,
    required this.dogrulamaSeviyesi,
    required this.yorumSayisi,
    this.aciklama,
    this.whatsapp,
    this.ortalamaPuan,
    this.kategoriler = const [],
  });

  final String ad;
  final String slug;
  final String telefon;
  final int dogrulamaSeviyesi;
  final int yorumSayisi;
  final String? aciklama;
  final String? whatsapp;
  final double? ortalamaPuan;
  final List<String> kategoriler;

  factory DukkanIsletme.fromJson(Map<String, dynamic> j) => DukkanIsletme(
        ad: j['ad'] as String? ?? '',
        slug: j['slug'] as String? ?? '',
        telefon: j['telefon'] as String? ?? '',
        dogrulamaSeviyesi: (j['dogrulama_seviyesi'] as num?)?.toInt() ?? 0,
        yorumSayisi: (j['yorum_sayisi'] as num?)?.toInt() ?? 0,
        aciklama: j['aciklama'] as String?,
        whatsapp: j['whatsapp'] as String?,
        // Sunucu `numeric` donduruyor; JSON'da String olabilir.
        ortalamaPuan: j['ortalama_puan'] == null
            ? null
            : double.tryParse('${j['ortalama_puan']}'),
        kategoriler:
            ((j['kategoriler'] as List?) ?? const []).map((e) => '$e').toList(),
      );
}

class DukkanAramaSonucu {
  const DukkanAramaSonucu({required this.items, required this.toplam});

  final List<DukkanIsletme> items;
  final int toplam;

  factory DukkanAramaSonucu.fromJson(Map<String, dynamic> j) =>
      DukkanAramaSonucu(
        items: ((j['items'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(DukkanIsletme.fromJson)
            .toList(),
        toplam: (j['toplam'] as num?)?.toInt() ?? 0,
      );
}

class DukkanKategori {
  const DukkanKategori({required this.ad, required this.slug, required this.alt});

  final String ad;
  final String slug;
  final List<DukkanKategori> alt;

  factory DukkanKategori.fromJson(Map<String, dynamic> j) => DukkanKategori(
        ad: j['ad'] as String? ?? '',
        slug: j['slug'] as String? ?? '',
        alt: ((j['alt'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(DukkanKategori.fromJson)
            .toList(),
      );
}

class DukkanApi {
  DukkanApi(this._dio);

  /// Extension metotlari (F4 talep uclari) buradan erisiyor; 
  /// birakmak ayni dosyada bile extension'lardan gorunur olsa da,
  /// niyeti acikca belirtmek icin adlandirma korunuyor.
  final Dio _dio;

  Future<List<DukkanKategori>> kategoriler() async {
    final r = await _dio.get<Map<String, dynamic>>('/dukkan/kategori');
    return ((r.data?['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(DukkanKategori.fromJson)
        .toList();
  }

  /// Isletme aramasi. Konum HIYERARSIK: mahalle verilirse il+ilce zorunlu.
  Future<DukkanAramaSonucu> ara({
    String? il,
    String? ilce,
    String? mahalle,
    String? kategori,
    String? q,
    int sayfa = 1,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/dukkan/isletme-ara',
      queryParameters: <String, dynamic>{
        if (il != null && il.isNotEmpty) 'il': il,
        if (ilce != null && ilce.isNotEmpty) 'ilce': ilce,
        if (mahalle != null && mahalle.isNotEmpty) 'mahalle': mahalle,
        if (kategori != null && kategori.isNotEmpty) 'kategori': kategori,
        if (q != null && q.isNotEmpty) 'q': q,
        'sayfa': sayfa,
      },
    );
    return DukkanAramaSonucu.fromJson(r.data ?? const {});
  }

  Future<Map<String, dynamic>> profil(String slug) async {
    final r = await _dio.get<Map<String, dynamic>>('/dukkan/isletme-profil/$slug');
    return r.data ?? const {};
  }

  /// Il listesi — bolge seciciye.
  Future<List<Map<String, String>>> iller() async {
    final r = await _dio.get<Map<String, dynamic>>('/dukkan/lokasyon/il');
    return ((r.data?['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((e) => {'ad': '${e['ad']}', 'slug': '${e['slug']}'})
        .toList();
  }

  Future<List<Map<String, String>>> ilceler(String ilSlug) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/dukkan/lokasyon/il/$ilSlug/ilce',
    );
    return ((r.data?['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((e) => {'ad': '${e['ad']}', 'slug': '${e['slug']}'})
        .toList();
  }
}

final dukkanApiProvider =
    Provider<DukkanApi>((ref) => DukkanApi(ref.watch(dioProvider)));

final dukkanKategorilerProvider =
    FutureProvider.autoDispose<List<DukkanKategori>>(
  (ref) => ref.watch(dukkanApiProvider).kategoriler(),
);

final dukkanIllerProvider =
    FutureProvider.autoDispose<List<Map<String, String>>>(
  (ref) => ref.watch(dukkanApiProvider).iller(),
);

// ===================================================================== //
// (DUKKAN F4) TALEP — KIMLIK GEREKTIRIR
// ===================================================================== //
//
// F3 uclari kimliksizdi (arama/profil). Talep olusturmak DUKKAN JETONU
// ister. Mobilde kullanici Yonetiyor'a zaten girmis oldugu icin jeton
// SSO koprusunden aliniyor (`dukkan_oturum.dart`) — kullaniciyi ikinci
// bir kayit akisina sokmak, urunun degerini gorduktan sonra onu
// kaybetmek olurdu.

class DukkanTalep {
  const DukkanTalep({
    required this.id,
    required this.aciklama,
    required this.durum,
    required this.kategori,
    required this.mahalle,
    required this.ilce,
    required this.teklifSayisi,
    this.baslik,
  });

  final String id;
  final String aciklama;
  final String durum;
  final String kategori;
  final String mahalle;
  final String ilce;
  final int teklifSayisi;
  final String? baslik;

  factory DukkanTalep.fromJson(Map<String, dynamic> j) => DukkanTalep(
        id: '${j['id']}',
        aciklama: j['aciklama'] as String? ?? '',
        durum: j['durum'] as String? ?? '',
        kategori: '${j['kategori'] ?? ''}',
        mahalle: '${j['mahalle'] ?? ''}',
        ilce: '${j['ilce'] ?? ''}',
        teklifSayisi: (j['teklif_sayisi'] as num?)?.toInt() ?? 0,
        baslik: j['baslik'] as String?,
      );
}

class DukkanTeklif {
  const DukkanTeklif({
    required this.id,
    required this.durum,
    required this.isletmeAd,
    required this.isletmeTelefon,
    required this.dogrulamaSeviyesi,
    required this.yorumSayisi,
    this.tutarKurus,
    this.mesaj,
    this.ortalamaPuan,
  });

  final String id;
  final String durum;
  final String isletmeAd;
  final String isletmeTelefon;
  final int dogrulamaSeviyesi;
  final int yorumSayisi;
  final int? tutarKurus;
  final String? mesaj;
  final double? ortalamaPuan;

  factory DukkanTeklif.fromJson(Map<String, dynamic> j) => DukkanTeklif(
        id: '${j['id']}',
        durum: j['durum'] as String? ?? '',
        isletmeAd: j['isletme_ad'] as String? ?? '',
        isletmeTelefon: j['isletme_telefon'] as String? ?? '',
        dogrulamaSeviyesi: (j['dogrulama_seviyesi'] as num?)?.toInt() ?? 0,
        yorumSayisi: (j['yorum_sayisi'] as num?)?.toInt() ?? 0,
        // `null` = "yerinde gormem gerek" — 0 DEGIL. Ikisini karistirmak
        // ucretsiz is teklifi gostermek olurdu.
        tutarKurus: (j['tutar_kurus'] as num?)?.toInt(),
        mesaj: j['mesaj'] as String?,
        ortalamaPuan: j['ortalama_puan'] == null
            ? null
            : double.tryParse('${j['ortalama_puan']}'),
      );
}

extension DukkanTalepApi on DukkanApi {
  /// Dukkan jetonlu istek secenekleri.
  ///
  /// `extra[dukkanJetonu]` KRITIK: bu olmadan interceptor YONETIYOR
  /// jetonunu koyar, uc 401 doner ve interceptor bunu "oturum bitti"
  /// sanip kullaniciyi YONETIYOR'DAN ATARDI (bkz. auth_interceptor.dart).
  Options _dukkanSecenek(String jeton) =>
      Options(extra: {AuthInterceptor.dukkanJetonu: jeton});

  /// Talep olusturur. Doner: (talepId, eslesenIsletmeSayisi).
  ///
  /// `eslesenIsletme` SAYIYI tasir: kullanici talebinin KIMSEYE
  /// ulasmadigini ANINDA gormeli.
  Future<({String id, int eslesen})> talepOlustur({
    required String kategoriSlug,
    required String ilSlug,
    required String ilceSlug,
    required String mahalleSlug,
    required String aciklama,
    required String jeton,
    bool paylasAd = false,
    bool paylasTelefon = false,
    bool paylasAdres = false,
    String? acikAdres,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/dukkan/talep',
      options: _dukkanSecenek(jeton),
      data: <String, dynamic>{
        'kategori_slug': kategoriSlug,
        'il_slug': ilSlug,
        'ilce_slug': ilceSlug,
        'mahalle_slug': mahalleSlug,
        'aciklama': aciklama,
        'paylas_ad': paylasAd,
        'paylas_telefon': paylasTelefon,
        'paylas_adres': paylasAdres,
        // ADRES YALNIZ IZIN VARSA GONDERILIYOR. Sunucu da izin yoksa
        // saklamiyor; iki taraf da ayni kurali uyguluyor.
        if (paylasAdres && acikAdres != null && acikAdres.isNotEmpty)
          'acik_adres': acikAdres,
      },
    );
    return (
      id: '${r.data?['id']}',
      eslesen: (r.data?['eslesen_isletme'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<DukkanTalep>> taleplerim(String jeton) async {
    final r = await _dio.get<Map<String, dynamic>>('/dukkan/talep',
        options: _dukkanSecenek(jeton));
    return ((r.data?['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(DukkanTalep.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> talepDetay(String id, String jeton) async {
    final r = await _dio.get<Map<String, dynamic>>('/dukkan/talep/$id',
        options: _dukkanSecenek(jeton));
    return r.data ?? const {};
  }

  Future<List<DukkanTeklif>> teklifler(String talepId, String jeton) async {
    final r = await _dio.get<Map<String, dynamic>>(
        '/dukkan/talep/$talepId/teklifler', options: _dukkanSecenek(jeton));
    return ((r.data?['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(DukkanTeklif.fromJson)
        .toList();
  }

  Future<String> teklifKabul(String teklifId, String jeton) async {
    final r = await _dio.post<Map<String, dynamic>>(
        '/dukkan/teklif/$teklifId/kabul', options: _dukkanSecenek(jeton));
    return '${r.data?['is_id']}';
  }

  Future<void> isTamamlandi(String isId, String jeton) async {
    await _dio.post<Map<String, dynamic>>('/dukkan/is/$isId/tamamlandi',
        options: _dukkanSecenek(jeton));
  }

  Future<List<Map<String, String>>> mahalleler(
      String ilSlug, String ilceSlug) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/dukkan/lokasyon/il/$ilSlug/ilce/$ilceSlug/mahalle',
    );
    return ((r.data?['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((e) => {'id': '${e['id']}', 'ad': '${e['ad']}', 'slug': '${e['slug']}'})
        .toList();
  }
}

/// Taleplerim — Dukkan jetonu ONCE alinir (SSO koprusu).
///
/// Jeton alinamazsa hata YUKARI CIKAR (`DukkanOturumHatasi`): sessizce
/// bos liste dondurmek, kullaniciya "talebin yok" demek olurdu — oysa
/// sorun oturumdadir.
final dukkanTaleplerimProvider =
    FutureProvider.autoDispose<List<DukkanTalep>>((ref) async {
  final jeton = await ref.watch(dukkanOturumProvider).jetonAl();
  return ref.watch(dukkanApiProvider).taleplerim(jeton);
});

// ===================================================================== //
// (DUKKAN F5) YORUM VE SIKAYET
// ===================================================================== //

class DukkanYorum {
  const DukkanYorum({
    required this.id,
    required this.kaynak,
    required this.puan,
    this.metin,
    this.cevap,
  });

  final String id;
  /// 'platform' (dogrulanmis) | 'davet' (davetli)
  final String kaynak;
  final int puan;
  final String? metin;
  final String? cevap;

  bool get dogrulanmis => kaynak == 'platform';

  factory DukkanYorum.fromJson(Map<String, dynamic> j) => DukkanYorum(
        id: '${j['id']}',
        kaynak: j['kaynak'] as String? ?? 'davet',
        puan: (j['puan'] as num?)?.toInt() ?? 0,
        metin: j['metin'] as String?,
        cevap: j['cevap'] as String?,
      );
}

class DukkanYorumListesi {
  const DukkanYorumListesi({
    required this.items,
    required this.dogrulanmis,
    required this.davetli,
  });

  final List<DukkanYorum> items;
  final int dogrulanmis;
  final int davetli;

  factory DukkanYorumListesi.fromJson(Map<String, dynamic> j) =>
      DukkanYorumListesi(
        items: ((j['items'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(DukkanYorum.fromJson)
            .toList(),
        dogrulanmis: ((j['ozet'] as Map?)?['dogrulanmis'] as num?)?.toInt() ?? 0,
        davetli: ((j['ozet'] as Map?)?['davetli'] as num?)?.toInt() ?? 0,
      );
}

extension DukkanGuvenApi on DukkanApi {
  /// Isletmenin yayindaki yorumlari — KIMLIKSIZ.
  Future<DukkanYorumListesi> yorumlar(String slug) async {
    final r = await _dio
        .get<Map<String, dynamic>>('/dukkan/isletme-profil/$slug/yorum');
    return DukkanYorumListesi.fromJson(r.data ?? const {});
  }

  /// Dogrulanmis yorum yazar (Katman A). Dukkan jetonu gerekir.
  Future<void> yorumYaz({
    required String isId,
    required String jeton,
    required int puan,
    String? metin,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/dukkan/is/$isId/yorum',
      options: Options(extra: {AuthInterceptor.dukkanJetonu: jeton}),
      data: <String, dynamic>{
        'puan': puan,
        if (metin != null && metin.isNotEmpty) 'metin': metin,
      },
    );
  }

  /// Sikayet — KIMLIKSIZ.
  ///
  /// Jeton GONDERILMIYOR ve bu bilincli: dolandirilan bir kullanicinin
  /// Dukkan hesabi olmayabilir. Kimlik zorunlu olsaydi en cok duyulmasi
  /// gereken ses kesilirdi.
  Future<void> sikayetGonder({
    required String tip,
    required String metin,
    String? isletmeSlug,
    String? iletisim,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/dukkan/sikayet',
      data: <String, dynamic>{
        'tip': tip,
        'metin': metin,
        if (isletmeSlug != null && isletmeSlug.isNotEmpty)
          'isletme_slug': isletmeSlug,
        if (iletisim != null && iletisim.isNotEmpty) 'iletisim': iletisim,
      },
    );
  }
}

final dukkanYorumlarProvider =
    FutureProvider.autoDispose.family<DukkanYorumListesi, String>(
  (ref, slug) => ref.watch(dukkanApiProvider).yorumlar(slug),
);
