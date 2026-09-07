import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';

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
