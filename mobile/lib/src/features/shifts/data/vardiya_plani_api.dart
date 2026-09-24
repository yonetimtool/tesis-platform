/// (P203 §4) VARDIYA PLANI — mobil okuma.
///
/// ===========================================================================
/// MOBILDE OKUMA + BASIT DEGISIKLIK
/// ===========================================================================
/// Istek "mobilde EN AZINDAN goruntuleme ve basit degisiklik" diyor.
/// Sunucu okumayi saha rollerine de aciyor: "bir sonraki vardiyada kim
/// var" tam da sahanin sorusudur ve WEB YUZEYI onlara KAPALIDIR (P129:
/// saha rollerinin urunu mobil uygulamadir). Yani plani gorebilmelerinin
/// TEK yolu burasi.
///
/// YAZMA (atama/cikarma) sunucuda admin+yonetici ile sinirli; mobil
/// yonetici de o uclari cagirabilir.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/api_exception.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/vardiya_plani_models.dart';

class VardiyaPlaniApi {
  VardiyaPlaniApi(this._dio);

  final Dio _dio;

  Future<VardiyaHafta> hafta(DateTime baslangic, {int gun = 7}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/vardiya-plani',
        queryParameters: {
          'baslangic': _tarih(baslangic),
          'gun': gun,
        },
      );
      return VardiyaHafta.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (P205 §2) KISI x SAAT cizelgesi.
  ///
  /// MOBIL ARTIK BUNU KULLANIYOR: `GET /vardiya-plani` izgarasi
  /// SABLONA bagli slotlari doner ve SERBEST (sablonsuz) vardiyalar
  /// orada HIC GORUNMEZ — web'den hizli eklenen bir vardiya sahada
  /// gorunmezdi. Izgara ucu duruyor (varsayilan kadro tohumlamasi ona
  /// dayaniyor), ekran ondan koptu.
  Future<VardiyaCizelge> cizelge(DateTime baslangic, {int gun = 7}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/vardiya-plani/cizelge',
        queryParameters: {'baslangic': _tarih(baslangic), 'gun': gun},
      );
      return VardiyaCizelge.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (P205 §2) Tarih araligindaki HER GUN icin vardiya.
  ///
  /// `cakisanlariAtla` VARSAYILAN FALSE: cakisan gunler kullaniciya
  /// SORULMADAN atlanmaz (istegin acik sarti).
  Future<VardiyaTopluSonuc> topluEkle({
    required String userId,
    required DateTime baslangic,
    required DateTime bitis,
    required String baslangicSaat,
    required String bitisSaat,
    String? not,
    bool cakisanlariAtla = false,
    // (P229 §2) KEYFI GUN LISTESI. Verilirse sunucu araligi YOK SAYAR.
    // Aralik alanlari yine de gonderiliyor: sozlesmede ZORUNLU kaldilar
    // (yayindaki istemciler onlari gonderiyor) ve opsiyonel yapmak
    // eski surumleri kirardi.
    List<String>? gunler,
    // (P241 §2) MOLA / ROL / LOKASYON — web ile AYNI uc, ayni alanlar.
    int? molaDakika,
    String? vardiyaRolu,
    String? alan,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/vardiya-plani/toplu',
        data: {
          'user_id': userId,
          'baslangic_tarih': _tarih(baslangic),
          'bitis_tarih': _tarih(bitis),
          'gunler': gunler,
          'baslangic_saat': baslangicSaat,
          'bitis_saat': bitisSaat,
          'not_metni': not,
          'cakisanlari_atla': cakisanlariAtla,
          if (molaDakika != null && molaDakika > 0)
            'molalar': [
              {'tur': 'yasal', 'dakika': molaDakika},
            ],
          'vardiya_rolu': vardiyaRolu,
          'alan': alan,
        },
      );
      return VardiyaTopluSonuc.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (P232) COK GRUPLU PLAN — "pazartesi gunduz, sali-carsamba gece".
  ///
  /// `kalip-uygula` ucunu kullanir. Mobilde bu uc HIC CAGRILMIYORDU:
  /// yalniz `topluEkle` (tek aralik + tek saat) vardi, yani farkli
  /// gunlere farkli saat yazmanin tek yolu diyalogu defalarca acmakti —
  /// her seferinde AYRI bir parti, ayri onizleme, ayri catisma kontrolu.
  ///
  /// [kuru] true ise HICBIR SEY YAZILMAZ: yalnizca onizleme doner.
  Future<VardiyaKalipSonuc> kalipUygula({
    required List<VardiyaGunGrubu> gruplar,
    bool kuru = false,
    bool cakisanlariAtla = false,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/vardiya-plani/kalip-uygula',
        data: {
          'gruplar': [for (final g in gruplar) g.toJson()],
          'kuru': kuru,
          'cakisanlari_atla': cakisanlariAtla,
        },
      );
      return VardiyaKalipSonuc.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<VardiyaSimdi> simdi() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/vardiya-plani/simdi');
      return VardiyaSimdi.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Atamayi kaldir — SILMEZ, iptal isaretler. `not_metni` SORGUDA:
  /// DELETE govdesi bazi yiginlarda sessizce dusuyor ve sebep alani
  /// kaybolsaydi denetim kaydi "neden" sorusunu yanitlayamazdi.
  Future<void> cikar(String planId, {String? sebep}) async {
    try {
      await _dio.delete<Map<String, dynamic>>(
        '/vardiya-plani/$planId',
        queryParameters: {if (sebep != null && sebep.isNotEmpty) 'not_metni': sebep},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  static String _tarih(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ===================== (P241 §2) YAYIN / IZIN / MOLA ================== //

  /// Yayin dugmesindeki sayi.
  Future<({int bekleyen, int taslak, int degisen})> yayinOzeti(
    DateTime baslangic, {
    int gun = 7,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/vardiya-plani/yayin-ozeti',
        queryParameters: {'baslangic': _tarih(baslangic), 'gun': gun},
      );
      final d = res.data ?? const {};
      return (
        bekleyen: (d['bekleyen'] as num?)?.toInt() ?? 0,
        taslak: (d['taslak'] as num?)?.toInt() ?? 0,
        degisen: (d['degisen'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Donemin taslak/degismis satirlarini yayinla.
  Future<int> yayinla(DateTime baslangic, {int gun = 7}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/vardiya-plani/yayinla',
        queryParameters: {'baslangic': _tarih(baslangic), 'gun': gun},
      );
      return (res.data?['yayinlanan'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// (4857 md. 68) Onerilen ara dinlenme — SUNUCUDAN.
  ///
  /// Kademeleri istemcide yazmak, kanunu iki yuzeye kopyalamak olurdu.
  Future<int> molaOnerisi(String baslangicSaat, String bitisSaat) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/vardiya-plani/mola-onerisi',
        queryParameters: {
          'baslangic_saat': baslangicSaat,
          'bitis_saat': bitisSaat,
        },
      );
      return (res.data?['onerilen_dakika'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Izin kaydi/talebi olustur.
  ///
  /// YONETIM girerse sunucu DOGRUDAN onayli acar; personel kendisi icin
  /// girerse TALEP olur (karar sunucuda, istemci tahmin etmez).
  Future<Map<String, dynamic>> izinEkle({
    required String userId,
    required String tur,
    required String baslangic,
    required String bitis,
    bool tumGun = true,
    String? baslangicSaat,
    String? bitisSaat,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/vardiya-izin',
        data: {
          'user_id': userId,
          'tur': tur,
          'baslangic': baslangic,
          'bitis': bitis,
          'tum_gun': tumGun,
          'baslangic_saat': baslangicSaat,
          'bitis_saat': bitisSaat,
        },
      );
      return res.data ?? const {};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  // ===================== (P247 §1) DONGU (ROTASYON) ===================== //

  /// Kayitli kaliplar — dongu olanlar `adimlar` tasir.
  Future<List<VardiyaKalibi>> kaliplar() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/vardiya-plani/kaliplar');
      return (res.data?['items'] as List? ?? const [])
          .map((m) => VardiyaKalibi.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Dongu kalibi kaydet (hazir sablonlardan). Web'deki tanim ile AYNI uc.
  Future<VardiyaKalibi> donguKalibiOlustur({
    required String ad,
    required List<VardiyaDilim> dilimler,
    required List<List<int>> adimlar,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/vardiya-plani/kaliplar',
        data: {
          'ad': ad,
          'dilimler': [for (final d in dilimler) d.toJson()],
          'adimlar': adimlar,
        },
      );
      return VardiyaKalibi.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Donguyu ekibe ata. [kuru] true ise HICBIR SEY YAZILMAZ (onizleme);
  /// kaydetme AYNI uca `kuru=false` ile gider (P207 K1.4).
  Future<VardiyaDonguSonuc> donguUygula({
    required String kalipId,
    required DateTime baslangic,
    required List<String> kisiler,
    int kaydirma = 0,
    bool kuru = false,
    bool cakisanlariAtla = false,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/vardiya-plani/dongu-uygula',
        data: {
          'kalip_id': kalipId,
          'baslangic': _tarih(baslangic),
          'kisiler': kisiler,
          'kaydirma': kaydirma,
          'kuru': kuru,
          'cakisanlari_atla': cakisanlariAtla,
        },
      );
      return VardiyaDonguSonuc.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<VardiyaDonguAtama>> donguAtamalari() async {
    try {
      final res =
          await _dio.get<Map<String, dynamic>>('/vardiya-plani/dongu-atamalari');
      return (res.data?['items'] as List? ?? const [])
          .map((m) =>
              VardiyaDonguAtama.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Toplu islemi (dongu partisi dahil: satirlar + atamalar) geri al.
  Future<int> partiGeriAl(String partiId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/vardiya-plani/parti/$partiId/geri-al',
      );
      return (res.data?['iptal_edilen'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final vardiyaPlaniApiProvider =
    Provider<VardiyaPlaniApi>((ref) => VardiyaPlaniApi(ref.watch(dioProvider)));
